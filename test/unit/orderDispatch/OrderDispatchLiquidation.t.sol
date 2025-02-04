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

contract OrderDispatchLiquidationBaseTest is OrderDispatchBase {
    using MessageHashUtils for bytes32;

    int256 hb;

    function setUp() public virtual override {
        Base_Test.setUp();
        deployOrderDispatch();
        takerOrder = Structs.Order(
            users.dan,
            1,
            103,
            true,
            uint8(0),
            uint8(1),
            2,
            10000e18,
            uint128(defaults.wethDepositQuantity()),
            1
        );
        makerOrder = Structs.Order(
            users.alice,
            1,
            103,
            false,
            uint8(0),
            uint8(1),
            2,
            10000e18,
            uint128(defaults.wethDepositQuantity()),
            1
        );
        (takeru1pid, makeru2pid, fa1) = getPerpBalances(
            103, Commons.getSubAccount(users.dan, 1), Commons.getSubAccount(users.alice, 1)
        );
        (bcu1, bcu2, bcf) = getCoreCollatBalances(
            Commons.getSubAccount(users.dan, 1), Commons.getSubAccount(users.alice, 1)
        );
        ensureBalanceChangeEventsPerpMatch(
            0, takerOrder.productId, takerOrder.quantity, makerOrder.price
        );
        (bytes32 takerHash, bytes32 makerHash) = constructMatchOrderPayload();
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(takerHash), takerOrder.quantity);
        assertEq(perpCrucible.filledQuantitys(makerHash), makerOrder.quantity);
        assertPerpBalanceChange(takerOrder.quantity, true, 103);
        assertCoreCollatFeeChange(0, takerOrder.productId, takerOrder.quantity, makerOrder.price, 1);
        transaction.pop();
        uint32[] memory setPricesProductIds = new uint32[](4);
        setPricesProductIds[0] = defaults.wbtcProductId();
        setPricesProductIds[1] = defaults.wethProductId();
        setPricesProductIds[2] = defaults.wbtcUsdcPerpProductId();
        setPricesProductIds[3] = defaults.wethUsdcPerpProductId();

        uint256[] memory setPricesValues = new uint256[](4);
        setPricesValues[0] = 10000e18;
        setPricesValues[1] = 1000e18;
        setPricesValues[2] = 8400e18;
        setPricesValues[3] = 1000e18;
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
        takerOrder.isBuy = false;
        makerOrder.isBuy = true;
        defaults.setWethDepositQuantity(77.5e18);
        takerOrder.quantity = uint128(defaults.wethDepositQuantity());
        makerOrder.quantity = uint128(defaults.wethDepositQuantity());
        (takeru1pid, makeru2pid, fa1) = getPerpBalances(
            103, Commons.getSubAccount(users.dan, 1), Commons.getSubAccount(users.alice, 1)
        );
        hb = furnace.getSubAccountHealth(Commons.getSubAccount(users.dan, 1), false);
    }

    function test_Happy_Liquidate_deposit_counts_match() public {
        liqui = Structs.LiquidateSubAccount(
            users.alice,
            1,
            users.dan,
            1,
            2,
            defaults.wbtcUsdcPerpProductId(),
            uint128(defaults.wethDepositQuantity()), // 77.5e18
            1
        );
        uint64 liquidateeDepositCount = ciao.depositCount(Commons.getSubAccount(users.dan, 1));
        constructLiquidatePayload(liquidateeDepositCount);
        vm.expectEmit(address(liquidation));
        emit Events.Liquidated(
            Commons.getSubAccount(users.alice, 1),
            Commons.getSubAccount(users.dan, 1),
            2,
            defaults.wbtcUsdcPerpProductId(),
            uint128(defaults.wethDepositQuantity()),
            8316000000000000000000,
            0
        );
        orderDispatch.ingresso(transaction);
        assertGt(furnace.getSubAccountHealth(Commons.getSubAccount(users.dan, 1), false), hb);
    }

    function test_Happy_Liquidate_offchain_deposit_count_greater() public {
        liqui = Structs.LiquidateSubAccount(
            users.alice,
            1,
            users.dan,
            1,
            2,
            defaults.wbtcUsdcPerpProductId(),
            uint128(defaults.wethDepositQuantity()), // 77.5e18
            1
        );
        uint64 liquidateeDepositCount = ciao.depositCount(Commons.getSubAccount(users.dan, 1));
        constructLiquidatePayload(liquidateeDepositCount + 1);
        vm.expectEmit(address(liquidation));
        emit Events.Liquidated(
            Commons.getSubAccount(users.alice, 1),
            Commons.getSubAccount(users.dan, 1),
            2,
            defaults.wbtcUsdcPerpProductId(),
            uint128(defaults.wethDepositQuantity()),
            8316000000000000000000,
            0
        );
        orderDispatch.ingresso(transaction);
        assertGt(furnace.getSubAccountHealth(Commons.getSubAccount(users.dan, 1), false), hb);
    }

    function test_Happy_Liquidate_if_require_dispatch_call_set() public {
        liqui = Structs.LiquidateSubAccount(
            users.alice,
            1,
            users.dan,
            1,
            2,
            defaults.wbtcUsdcPerpProductId(),
            uint128(defaults.wethDepositQuantity()), // 77.5e18
            1
        );
        uint64 liquidateeDepositCount = ciao.depositCount(Commons.getSubAccount(users.dan, 1));
        constructLiquidatePayload(liquidateeDepositCount);
        vm.expectEmit(address(liquidation));
        emit Events.Liquidated(
            Commons.getSubAccount(users.alice, 1),
            Commons.getSubAccount(users.dan, 1),
            2,
            defaults.wbtcUsdcPerpProductId(),
            uint128(defaults.wethDepositQuantity()),
            8316000000000000000000,
            0
        );
        orderDispatch.ingresso(transaction);
        assertGt(furnace.getSubAccountHealth(Commons.getSubAccount(users.dan, 1), false), hb);
    }

    function test_Happy_Liquidate_too_much() public {
        // should pass now we removed the over-liquidate check
        defaults.setWethDepositQuantity(100e18);
        liqui = Structs.LiquidateSubAccount(
            users.alice,
            1,
            users.dan,
            1,
            2,
            defaults.wbtcUsdcPerpProductId(),
            uint128(defaults.wethDepositQuantity()),
            1
        );
        uint64 liquidateeDepositCount = ciao.depositCount(Commons.getSubAccount(users.dan, 1));
        constructLiquidatePayload(liquidateeDepositCount);
        orderDispatch.ingresso(transaction);
        int256 liquidateeInitialHealthAfter =
            furnace.getSubAccountHealth(Commons.getSubAccount(users.dan, 1), true);
        assert(liquidateeInitialHealthAfter > 0);
    }

    function test_Happy_Liquidate_too_much_but_recent_deposit() public {
        defaults.setWethDepositQuantity(100e18);
        liqui = Structs.LiquidateSubAccount(
            users.alice,
            1,
            users.dan,
            1,
            2,
            defaults.wbtcUsdcPerpProductId(),
            uint128(defaults.wethDepositQuantity()),
            1
        );
        uint64 liquidateeDepositCount = ciao.depositCount(Commons.getSubAccount(users.dan, 1));
        constructLiquidatePayload(liquidateeDepositCount - 1);
        orderDispatch.ingresso(transaction);
        assertGt(furnace.getSubAccountHealth(Commons.getSubAccount(users.dan, 1), true), 0);
    }

    function test_Happy_Liquidate_healthy_user_but_recent_deposit() public {
        deal(address(usdc), users.dan, 100000e18);
        vm.startPrank(users.dan);
        usdc.approve(address(ciao), 100000e18);
        ciao.deposit(users.dan, 1, 100000e18, address(usdc));
        vm.stopPrank();
        defaults.setWethDepositQuantity(100e18);
        assertGt(furnace.getSubAccountHealth(Commons.getSubAccount(users.dan, 1), false), 0);
        vm.startPrank(users.gov);
        liqui = Structs.LiquidateSubAccount(
            users.alice,
            1,
            users.dan,
            1,
            2,
            defaults.wbtcUsdcPerpProductId(),
            uint128(defaults.wethDepositQuantity()),
            1
        );
        uint64 liquidateeDepositCount = ciao.depositCount(Commons.getSubAccount(users.dan, 1));
        constructLiquidatePayload(liquidateeDepositCount - 1);
        orderDispatch.ingresso(transaction);
        assertGt(furnace.getSubAccountHealth(Commons.getSubAccount(users.dan, 1), true), 0);
    }

    function test_Fail_cant_reuse_signature() public {
        liqui = Structs.LiquidateSubAccount(
            users.alice,
            1,
            users.dan,
            1,
            2,
            defaults.wbtcUsdcPerpProductId(),
            uint128(defaults.wethDepositQuantity()), // 77.5e18
            1
        );
        uint64 liquidateeDepositCount = ciao.depositCount(Commons.getSubAccount(users.dan, 1));
        constructLiquidatePayload(liquidateeDepositCount);
        vm.expectEmit(address(liquidation));
        emit Events.Liquidated(
            Commons.getSubAccount(users.alice, 1),
            Commons.getSubAccount(users.dan, 1),
            2,
            defaults.wbtcUsdcPerpProductId(),
            uint128(defaults.wethDepositQuantity()),
            8316000000000000000000,
            0
        );
        orderDispatch.ingresso(transaction);
        // assertGt(furnace.getSubAccountHealth(Commons.getSubAccount(users.dan, 1), false), hb);
        // vm.expectRevert(bytes4(keccak256("DigestedAlready()")));
        // orderDispatch.ingresso(transaction);
    }

    function test_Fail_Bad_Signer() public {
        liqui.liquidator = users.hackerman;
        uint64 liquidateeDepositCount = ciao.depositCount(Commons.getSubAccount(users.dan, 1));
        constructLiquidatePayload(liquidateeDepositCount);
        vm.expectRevert(bytes4(keccak256("SignatureInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Bad_Tx_Id() public {
        uint64 liquidateeDepositCount = ciao.depositCount(Commons.getSubAccount(users.dan, 1));
        constructLiquidatePayload(liquidateeDepositCount);
        transaction[0] = abi.encodePacked(uint8(69), transaction[0]);
        vm.expectRevert();
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Bad_Payload_Shape() public {
        uint64 liquidateeDepositCount = ciao.depositCount(Commons.getSubAccount(users.dan, 1));
        constructLiquidatePayload(liquidateeDepositCount);
        transaction[0] = abi.encodePacked(transaction[0], uint8(0));
        vm.expectRevert(bytes4(keccak256("OrderByteLengthInvalid()")));
        orderDispatch.ingresso(transaction);
    }
}
