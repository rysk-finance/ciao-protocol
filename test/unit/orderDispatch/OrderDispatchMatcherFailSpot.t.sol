// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/contracts/libraries/Commons.sol";
import {Events} from "src/contracts/interfaces/Events.sol";
import {IProductCatalogue} from "src/contracts/interfaces/IProductCatalogue.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "src/contracts/libraries/BasicMath.sol";
import {Base_Test} from "../../Base.t.sol";
import {OrderDispatchBase} from "./OrderDispatchBase.t.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";

contract OrderDispatchMatcherBaseTest is OrderDispatchBase {
    using MessageHashUtils for bytes32;

    function setUp() public virtual override {
        OrderDispatchBase.setUp();
        deployOrderDispatch();
        takerOrder = Structs.Order(
            users.dan,
            1,
            2,
            true,
            uint8(0),
            uint8(1),
            2,
            1000e18,
            uint128(defaults.wethDepositQuantity()),
            1
        );
        makerOrder = Structs.Order(
            users.alice,
            1,
            2,
            false,
            uint8(0),
            uint8(1),
            2,
            1000e18,
            uint128(defaults.wethDepositQuantity()),
            1
        );
    }

    function test_Fail_Match_Order_Not_Operator() public {
        vm.startPrank(users.alice);
        constructMatchOrderPayload();
        vm.expectRevert("UNAUTHORIZED");
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Match_Order_Taker_Bad_Quantity() public {
        takerOrder.quantity = 0;
        constructMatchOrderPayload();
        vm.expectRevert(bytes4(keccak256("OrderCheckFailed()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Match_Order_Maker_Bad_Quantity() public {
        makerOrder.quantity = 0;
        constructMatchOrderPayload();
        vm.expectRevert(bytes4(keccak256("OrderCheckFailed()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Match_Order_Taker_Bad_Price() public {
        takerOrder.price = 0;
        constructMatchOrderPayload();
        vm.expectRevert(bytes4(keccak256("OrderCheckFailed()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Match_Order_Maker_Bad_Price() public {
        makerOrder.price = 0;
        constructMatchOrderPayload();
        vm.expectRevert(bytes4(keccak256("OrderCheckFailed()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Match_Order_Same_Side_BUY() public {
        makerOrder.isBuy = true;
        takerOrder.isBuy = true;
        constructMatchOrderPayload();
        vm.expectRevert(bytes4(keccak256("SideInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Match_Order_Same_Side_SELL() public {
        makerOrder.isBuy = false;
        takerOrder.isBuy = false;
        constructMatchOrderPayload();
        vm.expectRevert(bytes4(keccak256("SideInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Match_Order_Product_Id_Invalid() public {
        takerOrder.productId = 6969;
        makerOrder.productId = 6969;
        constructMatchOrderPayload();
        vm.expectRevert(bytes4(keccak256("ProductNotSet()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Match_Order_Product_Id_Mismatch() public {
        takerOrder.productId = 1;
        makerOrder.productId = 2;
        constructMatchOrderPayload();
        vm.expectRevert(bytes4(keccak256("ProductIdMismatch()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Match_Order_maker_BUY_maker_price_less_than_spot()
        public
    {
        makerOrder.isBuy = true;
        takerOrder.isBuy = false;
        makerOrder.price = 1e18;
        takerOrder.price = 1.1e18;
        constructMatchOrderPayload();
        vm.expectRevert(bytes4(keccak256("PriceInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Match_Order_taker_BUY_maker_price_more_than_spot()
        public
    {
        makerOrder.isBuy = false;
        takerOrder.isBuy = true;
        makerOrder.price = 1.1e18;
        takerOrder.price = 1e18;
        constructMatchOrderPayload();
        vm.expectRevert(bytes4(keccak256("PriceInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Match_Order_Product_Id_Bad_Type() public {
        productCatalogue.setProduct(
            10,
            Structs.Product(
                5,
                address(weth),
                address(usdc),
                true,
                5e16,
                3e16,
                false
            )
        );
        takerOrder.productId = 10;
        makerOrder.productId = 10;
        constructMatchOrderPayload();
        vm.expectRevert();
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Match_Order_attempt_reuse_signature() public {
        makerOrder.isBuy = false;
        takerOrder.isBuy = true;
        makerOrder.price = 100e18;
        takerOrder.price = 110e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity());
        takerOrder.quantity = uint128(wethDeposit);
        (bytes32 takerHash, bytes32 makerHash) = constructMatchOrderPayload();
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(spotCrucible.filledQuantitys(takerHash), wethDeposit);
        assertEq(spotCrucible.filledQuantitys(makerHash), wethDeposit);
        vm.expectRevert(bytes4(keccak256("OrderCheckFailed()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Match_Order_Sig_Bad_Taker() public {
        (bytes memory takerSig, ) = makeOrderSig(takerOrder, "alice");
        (bytes memory makerSig, ) = makeOrderSig(makerOrder, "alice");
        makerOrderArrBytes.push(
            abi.encodePacked(
                makerOrder.account,
                makerOrder.subAccountId,
                makerOrder.productId,
                makerOrder.isBuy,
                makerOrder.orderType,
                makerOrder.timeInForce,
                makerOrder.expiration,
                makerOrder.price,
                makerOrder.quantity,
                makerOrder.nonce,
                makerSig
            )
        );
        takerOrderBytes = abi.encodePacked(
            takerOrder.account,
            takerOrder.subAccountId,
            takerOrder.productId,
            takerOrder.isBuy,
            takerOrder.orderType,
            takerOrder.timeInForce,
            takerOrder.expiration,
            takerOrder.price,
            takerOrder.quantity,
            takerOrder.nonce,
            takerSig
        );
        makerSigs.push(makerSig);
        transaction.push(
            abi.encodePacked(
                uint8(0),
                abi.encode(
                    Structs.MatchedOrder(takerOrderBytes, makerOrderArrBytes)
                )
            )
        );
        vm.expectRevert(bytes4(keccak256("SignatureInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Match_Order_Sig_Bad_Maker() public {
        (bytes memory takerSig, ) = makeOrderSig(takerOrder, "dan");
        (bytes memory makerSig, ) = makeOrderSig(makerOrder, "dan");
        makerOrderArrBytes.push(
            abi.encodePacked(
                makerOrder.account,
                makerOrder.subAccountId,
                makerOrder.productId,
                makerOrder.isBuy,
                makerOrder.orderType,
                makerOrder.timeInForce,
                makerOrder.expiration,
                makerOrder.price,
                makerOrder.quantity,
                makerOrder.nonce,
                makerSig
            )
        );
        takerOrderBytes = abi.encodePacked(
            takerOrder.account,
            takerOrder.subAccountId,
            takerOrder.productId,
            takerOrder.isBuy,
            takerOrder.orderType,
            takerOrder.timeInForce,
            takerOrder.expiration,
            takerOrder.price,
            takerOrder.quantity,
            takerOrder.nonce,
            takerSig
        );
        makerSigs.push(makerSig);
        transaction.push(
            abi.encodePacked(
                uint8(0),
                abi.encode(
                    Structs.MatchedOrder(takerOrderBytes, makerOrderArrBytes)
                )
            )
        );
        vm.expectRevert(bytes4(keccak256("SignatureInvalid()")));
        orderDispatch.ingresso(transaction);
    }
}
