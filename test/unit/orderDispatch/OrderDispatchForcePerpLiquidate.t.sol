// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/contracts/libraries/Commons.sol";
import {Events} from "src/contracts/interfaces/Events.sol";
import {IProductCatalogue} from "src/contracts/interfaces/IProductCatalogue.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "src/contracts/libraries/BasicMath.sol";
import {Base_Test} from "../../Base.t.sol";
import {OrderDispatchBase} from "./OrderDispatchBase.t.sol";
import "src/contracts/crucible/perp-crucible/PerpCrucible.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";

import "forge-std/console.sol";

contract OrderDispatchMatcherBaseTest is OrderDispatchBase {
    using MessageHashUtils for bytes32;

    int256 hb;
    int256 hbi;

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
            103,
            Commons.getSubAccount(users.dan, 1),
            Commons.getSubAccount(users.alice, 1)
        );
        (bcu1, bcu2, bcf) = getCoreCollatBalances(
            Commons.getSubAccount(users.dan, 1),
            Commons.getSubAccount(users.alice, 1)
        );
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
        assertPerpBalanceChange(takerOrder.quantity, true, 103);
        assertCoreCollatFeeChange(
            0,
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price,
            1
        );
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
            103,
            Commons.getSubAccount(users.dan, 1),
            Commons.getSubAccount(users.alice, 1)
        );
        hb = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.dan, 1),
            false
        );
        hbi = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.dan, 1),
            true
        );
    }

    function confirmPerps(uint256 quantity) public {
        (
            Structs.PositionState memory _takeru1pid,
            Structs.PositionState memory _makeru2pid,

        ) = getPerpBalances(
                103,
                Commons.getSubAccount(users.dan, 1),
                Commons.getSubAccount(users.alice, 1)
            );
        assertTrue(_takeru1pid.isLong);
        assertEq(takeru1pid.quantity - _takeru1pid.quantity, quantity);
        assertFalse(_makeru2pid.isLong);
        assertEq(makeru2pid.quantity - _makeru2pid.quantity, quantity);
    }

    function test_Happy_Match_Order_Sig_deposits_match() public {
        makerOrder.price = 8400e18;
        takerOrder.price = 8350e18;
        takerOrder.quantity = takerOrder.quantity / 10;
        makerOrder.quantity = makerOrder.quantity / 10;
        ensureBalanceChangeEventsPerpMatch(
            BasicMath.mul(1600e18, defaults.wethDepositQuantity() / 10),
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            0,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(takerHash), takerOrder.quantity);
        assertEq(perpCrucible.filledQuantitys(makerHash), makerOrder.quantity);
        confirmPerps(takerOrder.quantity);
        assertCoreCollatFeeChange(
            BasicMath.mul(1600e18, defaults.wethDepositQuantity() / 10),
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price,
            1
        );
        assertGt(
            furnace.getSubAccountHealth(
                Commons.getSubAccount(users.dan, 1),
                false
            ),
            hb
        );
    }

    function test_Happy_Match_Order_Sig_offchain_deposit_greater() public {
        makerOrder.price = 8400e18;
        takerOrder.price = 8350e18;
        takerOrder.quantity = takerOrder.quantity / 10;
        makerOrder.quantity = makerOrder.quantity / 10;
        ensureBalanceChangeEventsPerpMatch(
            BasicMath.mul(1600e18, defaults.wethDepositQuantity() / 10),
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            0,
            liquidateeDepositCount + 1
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(takerHash), takerOrder.quantity);
        assertEq(perpCrucible.filledQuantitys(makerHash), makerOrder.quantity);
        confirmPerps(takerOrder.quantity);
        assertCoreCollatFeeChange(
            BasicMath.mul(1600e18, defaults.wethDepositQuantity() / 10),
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price,
            1
        );
        assertGt(
            furnace.getSubAccountHealth(
                Commons.getSubAccount(users.dan, 1),
                false
            ),
            hb
        );
    }

    function test_Fail_Liquidate_too_much() public {
        makerOrder.price = 8400e18;
        takerOrder.price = 8350e18;
        takerOrder.quantity = takerOrder.quantity;
        makerOrder.quantity = makerOrder.quantity;
        ensureBalanceChangeEventsPerpMatch(
            BasicMath.mul(1600e18, defaults.wethDepositQuantity()),
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            0,
            liquidateeDepositCount
        );
        vm.expectRevert(bytes4(keccak256("LiquidatedTooMuch()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Happy_Liquidate_too_much_but_recent_deposit() public {
        makerOrder.price = 8400e18;
        takerOrder.price = 8350e18;
        takerOrder.quantity = takerOrder.quantity;
        makerOrder.quantity = makerOrder.quantity;
        ensureBalanceChangeEventsPerpMatch(
            BasicMath.mul(1600e18, defaults.wethDepositQuantity()),
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            0,
            liquidateeDepositCount - 1
        );
        orderDispatch.ingresso(transaction);
        assertGt(
            furnace.getSubAccountHealth(
                Commons.getSubAccount(users.dan, 1),
                true
            ),
            0
        );
    }

    function test_Happy_Liquidate_too_much_but_recent_deposit_in_same_tx()
        public
    {
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        vm.startPrank(users.dan);
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        vm.stopPrank();
        vm.startPrank(users.gov);
        address subAccount = Commons.getSubAccount(users.dan, 1);
        expectCallToTransferFrom(
            users.dan,
            address(ciao),
            defaults.usdcDepositQuantity()
        );

        constructDepositPayload(
            users.dan,
            1,
            defaults.usdcDepositQuantity(),
            address(usdc),
            "dan"
        );

        makerOrder.price = 8400e18;
        takerOrder.price = 8350e18;
        takerOrder.quantity = takerOrder.quantity;
        makerOrder.quantity = makerOrder.quantity;
        (bytes32 takerHash, bytes32 makerHash) = appendForceSwapPayload(
            0,
            liquidateeDepositCount
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc))) +
                int256(
                    Commons.convertToE18(
                        defaults.usdcDepositQuantity(),
                        usdc.decimals()
                    )
                )
        );
        vm.expectEmit(address(ciao));
        emit Events.Deposit(
            users.dan,
            1,
            address(usdc),
            defaults.usdcDepositQuantity()
        );

        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        vm.startPrank(users.gov);

        orderDispatch.ingresso(transaction);
        assertGt(
            furnace.getSubAccountHealth(
                Commons.getSubAccount(users.dan, 1),
                true
            ),
            0
        );
    }

    function test_Happy_Match_Order_partial_for_maker() public {
        makerOrder.price = 8400e18;
        takerOrder.price = 8350e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 10);
        takerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsPerpMatch(
            BasicMath.mul(1600e18, wethDeposit),
            takerOrder.productId,
            uint256(defaults.wethDepositQuantity() / 10),
            makerOrder.price
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            0,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(takerHash), wethDeposit);
        assertEq(perpCrucible.filledQuantitys(makerHash), wethDeposit);
        confirmPerps(wethDeposit);
        assertCoreCollatFeeChange(
            BasicMath.mul(1600e18, wethDeposit),
            takerOrder.productId,
            uint256(defaults.wethDepositQuantity() / 10),
            makerOrder.price,
            1
        );
        // complete the fill for the maker
        wethDeposit = uint256((defaults.wethDepositQuantity() * 2) / 10);
        takerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsPerpMatch(
            BasicMath.mul(1600e18, wethDeposit),
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        (takerHash, makerHash) = constructForceSwapPayload(
            0,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(takerHash), wethDeposit);
        assertEq(
            perpCrucible.filledQuantitys(makerHash),
            (defaults.wethDepositQuantity() * 3) / 10
        );
        confirmPerps((defaults.wethDepositQuantity() * 3) / 10);
        assertCoreCollatFeeChange(
            BasicMath.mul(1600e18, wethDeposit),
            takerOrder.productId,
            wethDeposit,
            makerOrder.price,
            1
        );
        assertGt(
            furnace.getSubAccountHealth(
                Commons.getSubAccount(users.dan, 1),
                false
            ),
            hb
        );
    }

    function test_Happy_Match_Order_partial_for_taker() public {
        orderDispatch.setTxFees(0, 0);
        makerOrder.price = 8400e18;
        takerOrder.price = 8350e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 10);
        makerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsPerpMatch(
            BasicMath.mul(1600e18, wethDeposit),
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            0,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(takerHash), wethDeposit);
        assertEq(perpCrucible.filledQuantitys(makerHash), wethDeposit);
        confirmPerps(wethDeposit);
        assertCoreCollatFeeChange(
            BasicMath.mul(1600e18, wethDeposit),
            takerOrder.productId,
            wethDeposit,
            makerOrder.price,
            1
        );
        // complete the fill for the maker
        wethDeposit = uint256((defaults.wethDepositQuantity() * 2) / 10);
        makerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsPerpMatch(
            BasicMath.mul(1600e18, wethDeposit),
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        (takerHash, makerHash) = constructForceSwapPayload(
            0,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(
            perpCrucible.filledQuantitys(takerHash),
            (defaults.wethDepositQuantity() * 3) / 10
        );
        assertEq(perpCrucible.filledQuantitys(makerHash), wethDeposit);
        confirmPerps((defaults.wethDepositQuantity() * 3) / 10);
        assertCoreCollatFeeChange(
            BasicMath.mul(1600e18, wethDeposit),
            takerOrder.productId,
            wethDeposit,
            makerOrder.price,
            1
        );
        assertGt(
            furnace.getSubAccountHealth(
                Commons.getSubAccount(users.dan, 1),
                false
            ),
            hb
        );
    }

    function test_Happy_Batch_Match_Order_partial_for_taker_multiple_makers()
        public
    {
        makerOrder.price = 8400e18;
        takerOrder.price = 8350e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 5);
        ensureBalanceChangeEventsPerpMatch(
            BasicMath.mul(1600e18, wethDeposit),
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        makerOrder.quantity = uint128(wethDeposit);
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            0,
            liquidateeDepositCount
        );
        makerOrder.nonce = 2;
        (, bytes32 makerHash2) = appendForceSwapMakerPayload(
            0,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash2);

        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(takerHash), wethDeposit * 2);
        assertEq(perpCrucible.filledQuantitys(makerHash), wethDeposit);
        assertEq(perpCrucible.filledQuantitys(makerHash2), wethDeposit);
        confirmPerps(wethDeposit * 2);
        assertCoreCollatFeeChange(
            BasicMath.mul(1600e18, wethDeposit * 2),
            takerOrder.productId,
            wethDeposit * 2,
            makerOrder.price,
            1
        );
        assertGt(
            furnace.getSubAccountHealth(
                Commons.getSubAccount(users.dan, 1),
                false
            ),
            hb
        );
    }

    function test_Fail_Batch_Match_Order_partial_for_maker_multiple_takers_makes_healthy()
        public
    {
        makerOrder.price = 8400e18;
        takerOrder.price = 8350e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 2);
        takerOrder.quantity = uint128(wethDeposit);
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        constructForceSwapPayload(0, liquidateeDepositCount);
        takerOrder.nonce = 2;
        appendForceSwapPayload(0, liquidateeDepositCount);
        vm.expectRevert(bytes4(keccak256("SubAccountHealthy()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Happy_Batch_Match_Order_partial_for_maker_multiple_takers_makes_healthy_but_recent_deposit()
        public
    {
        makerOrder.price = 8400e18;
        takerOrder.price = 8350e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 2);
        takerOrder.quantity = uint128(wethDeposit);
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        constructForceSwapPayload(0, liquidateeDepositCount);
        takerOrder.nonce = 2;
        appendForceSwapPayload(0, liquidateeDepositCount - 1);
        orderDispatch.ingresso(transaction);
    }

    function test_Happy_Batch_Match_Order_partial_for_maker_multiple_takers()
        public
    {
        makerOrder.price = 8400e18;
        takerOrder.price = 8350e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 4);
        takerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsPerpMatch(
            BasicMath.mul(1600e18, wethDeposit),
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            0,
            liquidateeDepositCount
        );
        takerOrder.nonce = 2;
        (bytes32 takerHash2, ) = appendForceSwapPayload(
            0,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash2, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(makerHash), wethDeposit * 2);
        assertEq(perpCrucible.filledQuantitys(takerHash), wethDeposit);
        assertEq(perpCrucible.filledQuantitys(takerHash2), wethDeposit);
        confirmPerps(wethDeposit * 2);
        assertCoreCollatFeeChange(
            BasicMath.mul(1600e18, wethDeposit * 2),
            takerOrder.productId,
            wethDeposit * 2,
            makerOrder.price,
            2
        );
        assertGt(
            furnace.getSubAccountHealth(
                Commons.getSubAccount(users.dan, 1),
                false
            ),
            hb
        );
    }

    function test_Happy_Match_Order_partial_for_maker_too_much() public {
        makerOrder.price = 8400e18;
        takerOrder.price = 8350e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 4);
        takerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsPerpMatch(
            BasicMath.mul(1600e18, wethDeposit),
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            0,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(takerHash), wethDeposit);
        assertEq(perpCrucible.filledQuantitys(makerHash), wethDeposit);
        confirmPerps(wethDeposit);
        // complete the fill for the maker
        wethDeposit = uint256(defaults.wethDepositQuantity());
        takerOrder.quantity = uint128(wethDeposit);
        (takerHash, makerHash) = constructForceSwapPayload(
            0,
            liquidateeDepositCount - 1
        ); // set count to below on chain value to skip health check
        ensureBalanceChangeEventsPerpMatch(
            BasicMath.mul(1600e18, (wethDeposit * 3) / 4),
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
        confirmPerps(wethDeposit);
        assertCoreCollatFeeChange(
            BasicMath.mul(1600e18, defaults.wethDepositQuantity()),
            takerOrder.productId,
            wethDeposit,
            makerOrder.price,
            2
        );
        assertGt(
            furnace.getSubAccountHealth(
                Commons.getSubAccount(users.dan, 1),
                false
            ),
            hb
        );
    }

    function test_Happy_Match_Order_maker_BUY_maker_price_more_than_taker()
        public
    {
        makerOrder.price = 8400e18;
        takerOrder.price = 8350e18;
        ensureBalanceChangeEventsPerpMatch(
            BasicMath.mul(1600e18, defaults.wethDepositQuantity()),
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            0,
            liquidateeDepositCount - 1
        ); // set count to below on chain value to skip health check
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(perpCrucible.filledQuantitys(takerHash), takerOrder.quantity);
        assertEq(perpCrucible.filledQuantitys(makerHash), makerOrder.quantity);
        confirmPerps(takerOrder.quantity);
        assertCoreCollatFeeChange(
            BasicMath.mul(1600e18, defaults.wethDepositQuantity()),
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price,
            1
        );
        assertGt(
            furnace.getSubAccountHealth(
                Commons.getSubAccount(users.dan, 1),
                false
            ),
            hb
        );
    }
}
