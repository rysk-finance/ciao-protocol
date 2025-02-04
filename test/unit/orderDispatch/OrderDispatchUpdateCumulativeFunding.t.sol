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

contract OrderDispatchUpdateCumulativeFundingBaseTest is OrderDispatchBase {
    using MessageHashUtils for bytes32;

    function setUp() public virtual override {
        OrderDispatchBase.setUp();
        deployOrderDispatch();
        approval = Structs.ApproveSigner(users.alice, 1, users.keeper, true, uint64(1));
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
        (u1a1, u1a2, u2a1, u2a2, fa1, fa2) = getSpotBalances(
            Commons.getSubAccount(users.dan, 1),
            Commons.getSubAccount(users.alice, 1),
            address(usdc),
            address(weth)
        );
    }

    function test_Happy_Update_Single_CumulativeFunding() public {
        uint32[] memory setCumulativeFundingsProductIds = new uint32[](1);
        setCumulativeFundingsProductIds[0] = defaults.wbtcProductId();

        int256[] memory setCumulativeFundingsValues = new int256[](1);
        setCumulativeFundingsValues[0] = 100000e18;
        bytes memory payload = abi.encodePacked(
            uint8(7),
            setCumulativeFundingsProductIds[0],
            setCumulativeFundingsValues[0]
        );
        transaction.push(payload);
        orderDispatch.ingresso(transaction);
        assertEq(
            perpCrucible.currentCumFunding(defaults.wbtcProductId()),
            100000e18
        );
    }

    function test_Happy_Update_CumulativeFunding_Seperate() public {
        uint32[] memory setCumulativeFundingsProductIds = new uint32[](1);
        setCumulativeFundingsProductIds[0] = defaults.wbtcProductId();
        int256[] memory setCumulativeFundingsValues = new int256[](1);
        setCumulativeFundingsValues[0] = 100000e18;
        bytes memory payload = abi.encodePacked(
            uint8(7),
            setCumulativeFundingsProductIds[0],
            setCumulativeFundingsValues[0]
        );
        transaction.push(payload);
        setCumulativeFundingsProductIds[0] = defaults.wethProductId();
        setCumulativeFundingsValues[0] = 696969e18;
        payload = abi.encodePacked(
            uint8(7),
            setCumulativeFundingsProductIds[0],
            setCumulativeFundingsValues[0]
        );
        transaction.push(payload);
        orderDispatch.ingresso(transaction);
        assertEq(
            perpCrucible.currentCumFunding(defaults.wbtcProductId()),
            100000e18
        );
        assertEq(
            perpCrucible.currentCumFunding(defaults.wethProductId()),
            696969e18
        );
    }

    function test_Happy_Update_CumulativeFunding_Batch() public {
        uint32[] memory setCumulativeFundingsProductIds = new uint32[](3);
        setCumulativeFundingsProductIds[0] = defaults.wbtcProductId();
        setCumulativeFundingsProductIds[1] = defaults.wethProductId();
        setCumulativeFundingsProductIds[2] = defaults.wethUsdcPerpProductId();
        int256[] memory setCumulativeFundingsValues = new int256[](3);
        setCumulativeFundingsValues[0] = 100000e18;
        setCumulativeFundingsValues[1] = 696969e18;
        setCumulativeFundingsValues[2] = 69e18;
        bytes memory payload = abi.encodePacked(
            uint8(7),
            setCumulativeFundingsProductIds[0],
            setCumulativeFundingsValues[0],
            setCumulativeFundingsProductIds[1],
            setCumulativeFundingsValues[1],
            setCumulativeFundingsProductIds[2],
            setCumulativeFundingsValues[2]
        );
        transaction.push(payload);
        orderDispatch.ingresso(transaction);
        assertEq(
            perpCrucible.currentCumFunding(defaults.wbtcProductId()),
            100000e18
        );
        assertEq(
            perpCrucible.currentCumFunding(defaults.wethProductId()),
            696969e18
        );
        assertEq(
            perpCrucible.currentCumFunding(defaults.wethUsdcPerpProductId()),
            69e18
        );
    }

    function test_Happy_Update_CumulativeFunding_Batch_Multiple() public {
        uint32[] memory setCumulativeFundingsProductIds = new uint32[](4);
        setCumulativeFundingsProductIds[0] = defaults.wbtcProductId();
        setCumulativeFundingsProductIds[1] = defaults.wethProductId();
        setCumulativeFundingsProductIds[2] = defaults.wethUsdcPerpProductId();
        setCumulativeFundingsProductIds[3] = defaults.wbtcUsdcPerpProductId();
        int256[] memory setCumulativeFundingsValues = new int256[](4);
        setCumulativeFundingsValues[0] = 100000e18;
        setCumulativeFundingsValues[1] = 696969e18;
        setCumulativeFundingsValues[2] = 69e18;
        setCumulativeFundingsValues[3] = 697312e18;
        bytes memory payload = abi.encodePacked(
            uint8(7),
            setCumulativeFundingsProductIds[0],
            setCumulativeFundingsValues[0],
            setCumulativeFundingsProductIds[1],
            setCumulativeFundingsValues[1],
            setCumulativeFundingsProductIds[2],
            setCumulativeFundingsValues[2],
            setCumulativeFundingsProductIds[3],
            setCumulativeFundingsValues[3]
        );
        transaction.push(payload);
        setCumulativeFundingsProductIds[0] = defaults.wbtcProductId();
        setCumulativeFundingsProductIds[1] = defaults.wbtcUsdcPerpProductId();
        setCumulativeFundingsValues[0] = 100002e18;
        setCumulativeFundingsValues[1] = 100005e18;
        payload = abi.encodePacked(
            uint8(7),
            setCumulativeFundingsProductIds[0],
            setCumulativeFundingsValues[0],
            setCumulativeFundingsProductIds[1],
            setCumulativeFundingsValues[1]
        );
        transaction.push(payload);
        orderDispatch.ingresso(transaction);
        assertEq(
            perpCrucible.currentCumFunding(defaults.wbtcProductId()),
            200002e18
        );
        assertEq(
            perpCrucible.currentCumFunding(defaults.wethProductId()),
            696969e18
        );
        assertEq(
            perpCrucible.currentCumFunding(defaults.wethUsdcPerpProductId()),
            69e18
        );
        assertEq(
            perpCrucible.currentCumFunding(defaults.wbtcUsdcPerpProductId()),
            797317e18
        );
    }

    function test_Happy_Update_CumulativeFunding_Match_Order_Approve_Signer()
        public
    {
        uint32[] memory setCumulativeFundingsProductIds = new uint32[](1);
        setCumulativeFundingsProductIds[0] = defaults.wbtcProductId();

        int256[] memory setCumulativeFundingsValues = new int256[](1);
        setCumulativeFundingsValues[0] = 100000e18;
        bytes memory payload = abi.encodePacked(
            uint8(7),
            setCumulativeFundingsProductIds[0],
            setCumulativeFundingsValues[0]
        );
        transaction.push(payload);
        appendApproveSignerPayload("alice", 1);
        (bytes32 takerHash, bytes32 makerHash) = appendMatchOrderPayload();
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(
            approval.account,
            approval.subAccountId,
            approval.approvedSigner,
            approval.isApproved
        );
        ensureBalanceChangeEventsSpotMatch(
            defaults.usdcDepositQuantityE18(),
            defaults.wethDepositQuantity(),
            true,
            takerOrder.productId,
            BasicMath.min(takerOrder.quantity, makerOrder.quantity),
            makerOrder.price
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        address subAccount = Commons.getSubAccount(users.alice, 1);
        assertEq(
            perpCrucible.currentCumFunding(defaults.wbtcProductId()),
            100000e18
        );
        assertTrue(addressManifest.approvedSigners(subAccount, users.keeper));
        assertEq(spotCrucible.filledQuantitys(takerHash), takerOrder.quantity);
        assertEq(spotCrucible.filledQuantitys(makerHash), makerOrder.quantity);
        assertSpotBalanceChange(
            defaults.usdcDepositQuantityE18(),
            defaults.wethDepositQuantity(),
            true,
            takerOrder.productId,
            BasicMath.min(takerOrder.quantity, makerOrder.quantity),
            makerOrder.price,
            orderDispatch.txFees(0)
        );
    }

    function test_Fail_Pass_Nothing() public {
        bytes memory payload = abi.encodePacked(uint8(1), uint8(1));
        transaction.push(payload);
        vm.expectRevert(bytes4(keccak256("OrderByteLengthInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Pass_IncorrectLength_missing_price() public {
        uint32[] memory setCumulativeFundingsProductIds = new uint32[](1);
        setCumulativeFundingsProductIds[0] = defaults.wbtcProductId();

        int256[] memory setCumulativeFundingsValues = new int256[](1);
        setCumulativeFundingsValues[0] = 100000e18;
        bytes memory payload = abi.encodePacked(
            uint8(7),
            setCumulativeFundingsProductIds[0],
            setCumulativeFundingsValues[0],
            setCumulativeFundingsProductIds[0]
        );
        transaction.push(payload);
        vm.expectRevert(bytes4(keccak256("OrderByteLengthInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Pass_IncorrectLength_missing_product_id() public {
        uint32[] memory setCumulativeFundingsProductIds = new uint32[](1);
        setCumulativeFundingsProductIds[0] = defaults.wbtcProductId();

        int256[] memory setCumulativeFundingsValues = new int256[](1);
        setCumulativeFundingsValues[0] = 100000e18;
        bytes memory payload = abi.encodePacked(
            uint8(7),
            setCumulativeFundingsProductIds[0],
            setCumulativeFundingsValues[0],
            setCumulativeFundingsValues[0]
        );
        transaction.push(payload);
        vm.expectRevert(bytes4(keccak256("OrderByteLengthInvalid()")));
        orderDispatch.ingresso(transaction);
    }
}
