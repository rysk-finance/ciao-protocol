// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/contracts/libraries/Commons.sol";
import {Events} from "src/contracts/interfaces/Events.sol";
import {IProductCatalogue} from "src/contracts/interfaces/IProductCatalogue.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "src/contracts/libraries/BasicMath.sol";
import {Base_Test} from "../../Base.t.sol";
import {OrderDispatchBase} from "./OrderDispatchBase.t.sol";
import "forge-std/console.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";

contract OrderDispatchMatcherBaseTest is OrderDispatchBase {
    using MessageHashUtils for bytes32;

    function setUp() public virtual override {
        OrderDispatchBase.setUp();
        deployOrderDispatch();
        takerOrder = Structs.Order(
            users.dan,
            1,
            102,
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
            102,
            false,
            uint8(0),
            uint8(1),
            2,
            1000e18,
            uint128(defaults.wethDepositQuantity()),
            1
        );
        (takeru1pid, makeru2pid, fa1) = getPerpBalances(
            102,
            Commons.getSubAccount(users.dan, 1),
            Commons.getSubAccount(users.alice, 1)
        );
        (bcu1, bcu2, bcf) = getCoreCollatBalances(
            Commons.getSubAccount(users.dan, 1),
            Commons.getSubAccount(users.alice, 1)
        );
        uint32[] memory setPricesProductIds = new uint32[](4);
        setPricesProductIds[0] = defaults.wbtcProductId();
        setPricesProductIds[1] = defaults.wethProductId();
        setPricesProductIds[2] = defaults.wbtcUsdcPerpProductId();
        setPricesProductIds[3] = defaults.wethUsdcPerpProductId();

        uint256[] memory setPricesValues = new uint256[](4);
        setPricesValues[0] = 10000e18;
        setPricesValues[1] = 1000e18;
        setPricesValues[2] = 10000e18;
        setPricesValues[3] = 100e18;
        bytes memory payload = abi.encodePacked(
            uint8(1),
            setPricesProductIds[0],
            setPricesValues[0],
            setPricesProductIds[1],
            setPricesValues[1],
            setPricesProductIds[2],
            setPricesValues[2],
            setPricesProductIds[3],
            setPricesValues[3]
        );
        transaction.push(payload);
        orderDispatch.ingresso(transaction);
        transaction.pop();
    }

    function test_Happy_Match_Order_Sig() public {
        ensureBalanceChangeEventsPerpMatch(
            0,
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price
        );
        (bytes32 takerHash, bytes32 makerHash) = constructMatchOrderPayload();
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(takerHash), takerOrder.quantity);
        assertEq(perpCrucible.filledQuantitys(makerHash), makerOrder.quantity);
        assertPerpBalanceChange(takerOrder.quantity, true, 102);
        assertCoreCollatFeeChange(
            0,
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price,
            1
        );
    }

    function test_Happy_Match_Order_Sig_Maker_Long() public {
        makerOrder.isBuy = true;
        takerOrder.isBuy = false;
        ensureBalanceChangeEventsPerpMatch(
            0,
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price
        );
        (bytes32 takerHash, bytes32 makerHash) = constructMatchOrderPayload();
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(takerHash), takerOrder.quantity);
        assertEq(perpCrucible.filledQuantitys(makerHash), makerOrder.quantity);
        assertPerpBalanceChange(takerOrder.quantity, false, 102);
        assertCoreCollatFeeChange(
            0,
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price,
            1
        );
    }

    function test_Happy_Match_Order_partial_for_maker() public {
        makerOrder.price = 100e18;
        takerOrder.price = 110e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 4);
        takerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsPerpMatch(
            0,
            takerOrder.productId,
            uint256(defaults.wethDepositQuantity() / 4),
            makerOrder.price
        );
        (bytes32 takerHash, bytes32 makerHash) = constructMatchOrderPayload();
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(takerHash), wethDeposit);
        assertEq(perpCrucible.filledQuantitys(makerHash), wethDeposit);
        assertPerpBalanceChange(
            uint256(defaults.wethDepositQuantity() / 4),
            true,
            102
        );
        assertCoreCollatFeeChange(
            0,
            takerOrder.productId,
            uint256(defaults.wethDepositQuantity() / 4),
            makerOrder.price,
            1
        );
        // complete the fill for the maker
        wethDeposit = uint256((defaults.wethDepositQuantity() * 3) / 4);
        takerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsPerpMatch(
            0,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        (takerHash, makerHash) = constructMatchOrderPayload();
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(takerHash), wethDeposit);
        assertEq(
            perpCrucible.filledQuantitys(makerHash),
            defaults.wethDepositQuantity()
        );
        assertPerpBalanceChange(defaults.wethDepositQuantity(), true, 102);
        assertCoreCollatFeeChange(
            0,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price,
            1
        );
    }

    function test_Happy_Match_Order_partial_for_taker() public {
        orderDispatch.setTxFees(0, 0);
        makerOrder.price = 100e18;
        takerOrder.price = 110e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 5);
        makerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsPerpMatch(
            0,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        (bytes32 takerHash, bytes32 makerHash) = constructMatchOrderPayload();
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(takerHash), wethDeposit);
        assertEq(perpCrucible.filledQuantitys(makerHash), wethDeposit);
        assertPerpBalanceChange(
            uint256(defaults.wethDepositQuantity() / 5),
            true,
            102
        );
        assertCoreCollatFeeChange(
            0,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price,
            1
        );
        // complete the fill for the maker
        wethDeposit = uint256((defaults.wethDepositQuantity() * 4) / 5);
        makerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsPerpMatch(
            0,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        (takerHash, makerHash) = constructMatchOrderPayload();
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(
            perpCrucible.filledQuantitys(takerHash),
            defaults.wethDepositQuantity()
        );
        assertEq(perpCrucible.filledQuantitys(makerHash), wethDeposit);
        assertPerpBalanceChange(defaults.wethDepositQuantity(), true, 102);
        assertCoreCollatFeeChange(
            0,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price,
            1
        );
    }

    function test_Happy_Batch_Match_Order_partial_for_taker_multiple_makers()
        public
    {
        makerOrder.price = 100e18;
        takerOrder.price = 110e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 4);
        ensureBalanceChangeEventsPerpMatch(
            0,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        makerOrder.quantity = uint128(wethDeposit);
        (bytes32 takerHash, bytes32 makerHash) = constructMatchOrderPayload();
        makerOrder.nonce = 2;
        (, , bytes32 makerHash2) = appendMakerOrderPayload();
         makerOrder.nonce = 3;
        (, , bytes32 makerHash3) = appendMakerOrderPayload();
         makerOrder.nonce = 4;
        (, , bytes32 makerHash4) = appendMakerOrderPayload();
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash2);
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash3);
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash4);
        orderDispatch.ingresso(transaction);
        
        assertEq(perpCrucible.filledQuantitys(takerHash), wethDeposit * 4);
        assertEq(perpCrucible.filledQuantitys(makerHash), wethDeposit);
        assertEq(perpCrucible.filledQuantitys(makerHash2), wethDeposit);
        assertEq(perpCrucible.filledQuantitys(makerHash3), wethDeposit);
        assertEq(perpCrucible.filledQuantitys(makerHash4), wethDeposit);

        assertPerpBalanceChange(wethDeposit * 4, true, 102);
        assertCoreCollatFeeChange(
            0,
            takerOrder.productId,
            wethDeposit * 4,
            makerOrder.price,
            1
        );
    }

    function test_Happy_Batch_Match_Order_partial_for_maker_multiple_takers()
        public
    {
        makerOrder.price = 100e18;
        takerOrder.price = 110e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 2);
        takerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsPerpMatch(
            0,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        (bytes32 takerHash, bytes32 makerHash) = constructMatchOrderPayload();
        takerOrder.nonce = 2;
        (bytes32 takerHash2, ) = appendMatchOrderPayload();
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash2, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(makerHash), wethDeposit * 2);
        assertEq(perpCrucible.filledQuantitys(takerHash), wethDeposit);
        assertEq(perpCrucible.filledQuantitys(takerHash2), wethDeposit);
        assertPerpBalanceChange(wethDeposit * 2, true, 102);
        assertCoreCollatFeeChange(
            0,
            takerOrder.productId,
            wethDeposit * 2,
            makerOrder.price,
            2
        );
    }

    function test_Happy_Match_Order_partial_for_maker_too_much() public {
        makerOrder.price = 100e18;
        takerOrder.price = 110e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 4);
        takerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsPerpMatch(
            0,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        (bytes32 takerHash, bytes32 makerHash) = constructMatchOrderPayload();
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(takerHash), wethDeposit);
        assertEq(perpCrucible.filledQuantitys(makerHash), wethDeposit);
        assertPerpBalanceChange(wethDeposit, true, 102);
        // complete the fill for the maker
        wethDeposit = uint256(defaults.wethDepositQuantity());
        takerOrder.quantity = uint128(wethDeposit);
        (takerHash, makerHash) = constructMatchOrderPayload();
        ensureBalanceChangeEventsPerpMatch(
            0,
            takerOrder.productId,
            (wethDeposit * 3) / 4,
            makerOrder.price
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(
            perpCrucible.filledQuantitys(takerHash),
            (wethDeposit * 3) / 4
        );
        assertEq(
            perpCrucible.filledQuantitys(makerHash),
            defaults.wethDepositQuantity()
        );
        assertPerpBalanceChange(wethDeposit, true, 102);
        assertCoreCollatFeeChange(
            0,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price,
            2
        );
    }

    function test_Happy_Match_Order_maker_BUY_maker_price_more_than_taker()
        public
    {
        makerOrder.isBuy = true;
        takerOrder.isBuy = false;
        makerOrder.price = 110e18;
        takerOrder.price = 100e18;
        ensureBalanceChangeEventsPerpMatch(
            0,
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price
        );
        (bytes32 takerHash, bytes32 makerHash) = constructMatchOrderPayload();
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(takerHash), takerOrder.quantity);
        assertEq(perpCrucible.filledQuantitys(makerHash), makerOrder.quantity);
        assertPerpBalanceChange(takerOrder.quantity, false, 102);
        assertCoreCollatFeeChange(
            0,
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price,
            1
        );
    }

    function test_Happy_Match_Order_taker_BUY_taker_price_more_than_maker()
        public
    {
        makerOrder.isBuy = false;
        takerOrder.isBuy = true;
        makerOrder.price = 100e18;
        takerOrder.price = 110e18;
        ensureBalanceChangeEventsPerpMatch(
            0,
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price
        );
        (bytes32 takerHash, bytes32 makerHash) = constructMatchOrderPayload();
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(takerHash), takerOrder.quantity);
        assertEq(perpCrucible.filledQuantitys(makerHash), makerOrder.quantity);
        assertPerpBalanceChange(takerOrder.quantity, true, 102);
        assertCoreCollatFeeChange(
            0,
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price,
            1
        );
    }
}
