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
            false,
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
            true,
            uint8(0),
            uint8(1),
            2,
            1000e18,
            uint128(defaults.wethDepositQuantity()),
            1
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        constructForceSwapPayload(1, liquidateeDepositCount);
        vm.expectRevert(bytes4(keccak256("NoCoreCollateralDebt()")));
        orderDispatch.ingresso(transaction);
        setupCoreCollateralDebt(-5000e18);
        (u1a1, u1a2, u2a1, u2a2, fa1, fa2) = getSpotBalances(
            Commons.getSubAccount(users.dan, 1),
            Commons.getSubAccount(users.alice, 1),
            address(usdc),
            address(weth)
        );
        (bcu1, bcu1, bcf) = getCoreCollatBalances(
            Commons.getSubAccount(users.dan, 1),
            Commons.getSubAccount(users.alice, 1)
        );
    }

    function test_Happy_Match_Order_Sig_Spot_deposit_counts_match() public {
        ensureBalanceChangeEventsSpotMatch(
            defaults.usdcDepositQuantityE18(),
            defaults.wethDepositQuantity(),
            false,
            takerOrder.productId,
            BasicMath.min(takerOrder.quantity, makerOrder.quantity),
            makerOrder.price
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            1,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(spotCrucible.filledQuantitys(takerHash), takerOrder.quantity);
        assertEq(spotCrucible.filledQuantitys(makerHash), makerOrder.quantity);
        assertSpotBalanceChange(
            defaults.usdcDepositQuantityE18(),
            defaults.wethDepositQuantity(),
            false,
            takerOrder.productId,
            BasicMath.min(takerOrder.quantity, makerOrder.quantity),
            makerOrder.price,
            orderDispatch.txFees(0)
        );
        assertGt(
            int256(
                ciao.balances(
                    Commons.getSubAccount(users.dan, 1),
                    address(usdc)
                )
            ) -
                int256(
                    ciao.coreCollateralDebt(Commons.getSubAccount(users.dan, 1))
                ),
            bcu1
        );
    }

    function test_Happy_Match_Order_Sig_Spot_offchain_deposit_count_greater()
        public
    {
        ensureBalanceChangeEventsSpotMatch(
            defaults.usdcDepositQuantityE18(),
            defaults.wethDepositQuantity(),
            false,
            takerOrder.productId,
            BasicMath.min(takerOrder.quantity, makerOrder.quantity),
            makerOrder.price
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            1,
            liquidateeDepositCount + 1
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(spotCrucible.filledQuantitys(takerHash), takerOrder.quantity);
        assertEq(spotCrucible.filledQuantitys(makerHash), makerOrder.quantity);
        assertSpotBalanceChange(
            defaults.usdcDepositQuantityE18(),
            defaults.wethDepositQuantity(),
            false,
            takerOrder.productId,
            BasicMath.min(takerOrder.quantity, makerOrder.quantity),
            makerOrder.price,
            orderDispatch.txFees(0)
        );
        assertGt(
            int256(
                ciao.balances(
                    Commons.getSubAccount(users.dan, 1),
                    address(usdc)
                )
            ) -
                int256(
                    ciao.coreCollateralDebt(Commons.getSubAccount(users.dan, 1))
                ),
            bcu1
        );
    }

    function test_Happy_Match_Order_partial_for_maker() public {
        makerOrder.price = 110e18;
        takerOrder.price = 100e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 4);
        takerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsSpotMatch(
            (wethDeposit * makerOrder.price) / 1e18,
            wethDeposit,
            false,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            1,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(spotCrucible.filledQuantitys(takerHash), wethDeposit);
        assertEq(spotCrucible.filledQuantitys(makerHash), wethDeposit);
        assertSpotBalanceChange(
            (wethDeposit * makerOrder.price) / 1e18,
            wethDeposit,
            false,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price,
            orderDispatch.txFees(0)
        );
        // complete the fill for the maker
        wethDeposit = uint256((defaults.wethDepositQuantity() * 3) / 4);
        takerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsSpotMatch(
            (wethDeposit * makerOrder.price) / 1e18,
            wethDeposit,
            false,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        (takerHash, makerHash) = constructForceSwapPayload(
            1,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(spotCrucible.filledQuantitys(takerHash), wethDeposit);
        assertEq(
            spotCrucible.filledQuantitys(makerHash),
            defaults.wethDepositQuantity()
        );
        assertSpotBalanceChange(
            (wethDeposit * makerOrder.price) / 1e18,
            wethDeposit,
            false,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price,
            orderDispatch.txFees(0)
        );
        assertGt(
            int256(
                ciao.balances(
                    Commons.getSubAccount(users.dan, 1),
                    address(usdc)
                )
            ) -
                int256(
                    ciao.coreCollateralDebt(Commons.getSubAccount(users.dan, 1))
                ),
            bcu1
        );
    }

    function test_Happy_Match_Order_partial_for_taker() public {
        orderDispatch.setTxFees(0, 0);
        makerOrder.price = 110e18;
        takerOrder.price = 100e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 5);
        makerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsSpotMatch(
            (wethDeposit * makerOrder.price) / 1e18,
            wethDeposit,
            false,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            1,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(spotCrucible.filledQuantitys(takerHash), wethDeposit);
        assertEq(spotCrucible.filledQuantitys(makerHash), wethDeposit);
        assertSpotBalanceChange(
            (wethDeposit * makerOrder.price) / 1e18,
            wethDeposit,
            false,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price,
            orderDispatch.txFees(0)
        );
        // complete the fill for the maker
        wethDeposit = uint256((defaults.wethDepositQuantity() * 4) / 5);
        makerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsSpotMatch(
            (wethDeposit * makerOrder.price) / 1e18,
            wethDeposit,
            false,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        (takerHash, makerHash) = constructForceSwapPayload(
            1,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(
            spotCrucible.filledQuantitys(takerHash),
            defaults.wethDepositQuantity()
        );
        assertEq(spotCrucible.filledQuantitys(makerHash), wethDeposit);
        assertSpotBalanceChange(
            (wethDeposit * makerOrder.price) / 1e18,
            wethDeposit,
            false,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price,
            orderDispatch.txFees(0)
        );
        assertGt(
            int256(
                ciao.balances(
                    Commons.getSubAccount(users.dan, 1),
                    address(usdc)
                )
            ) -
                int256(
                    ciao.coreCollateralDebt(Commons.getSubAccount(users.dan, 1))
                ),
            bcu1
        );
    }

    function test_Happy_Batch_Match_Order_partial_for_taker_multiple_makers()
        public
    {
        makerOrder.price = 110e18;
        takerOrder.price = 100e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 5);
        makerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsSpotMatch(
            (wethDeposit * makerOrder.price) / 1e18,
            wethDeposit,
            false,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            1,
            liquidateeDepositCount
        );
        makerOrder.nonce = 2;
        (, bytes32 makerHash2) = appendForceSwapMakerPayload(
            1,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash2);
        orderDispatch.ingresso(transaction);
        assertEq(spotCrucible.filledQuantitys(takerHash), wethDeposit * 2);
        assertEq(spotCrucible.filledQuantitys(makerHash), wethDeposit);
        assertEq(spotCrucible.filledQuantitys(makerHash2), wethDeposit);
        assertSpotBalanceChange(
            (wethDeposit * 2 * makerOrder.price) / 1e18,
            wethDeposit * 2,
            false,
            takerOrder.productId,
            wethDeposit * 2,
            makerOrder.price,
            orderDispatch.txFees(0)
        );
        assertGt(
            int256(
                ciao.balances(
                    Commons.getSubAccount(users.dan, 1),
                    address(usdc)
                )
            ) -
                int256(
                    ciao.coreCollateralDebt(Commons.getSubAccount(users.dan, 1))
                ),
            bcu1
        );
    }

    function test_Happy_Batch_Match_Order_partial_for_maker_multiple_takers()
        public
    {
        orderDispatch.setTxFees(0, 0);
        makerOrder.price = 110e18;
        takerOrder.price = 100e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 10);
        takerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsSpotMatch(
            (wethDeposit * makerOrder.price) / 1e18,
            wethDeposit,
            false,
            takerOrder.productId,
            wethDeposit,
            makerOrder.price
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            1,
            liquidateeDepositCount
        );
        takerOrder.nonce = 2;
        (bytes32 takerHash2, ) = appendForceSwapPayload(
            1,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash2, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(spotCrucible.filledQuantitys(makerHash), wethDeposit * 2);
        assertEq(spotCrucible.filledQuantitys(takerHash), wethDeposit);
        assertEq(spotCrucible.filledQuantitys(takerHash2), wethDeposit);
        assertSpotBalanceChange(
            (wethDeposit * 2 * makerOrder.price) / 1e18,
            wethDeposit * 2,
            false,
            takerOrder.productId,
            wethDeposit * 2,
            makerOrder.price,
            orderDispatch.txFees(0)
        );
        assertGt(
            int256(
                ciao.balances(
                    Commons.getSubAccount(users.dan, 1),
                    address(usdc)
                )
            ) -
                int256(
                    ciao.coreCollateralDebt(Commons.getSubAccount(users.dan, 1))
                ),
            bcu1
        );
    }

    function test_Fail_Batch_Match_Order_partial_for_maker_multiple_takers_overdoes_debt()
        public
    {
        orderDispatch.setTxFees(0, 0);
        makerOrder.price = 110e18;
        takerOrder.price = 100e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 2);
        takerOrder.quantity = uint128(wethDeposit);
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        constructForceSwapPayload(1, liquidateeDepositCount);
        takerOrder.nonce = 2;
        appendForceSwapPayload(1, liquidateeDepositCount);
        vm.expectRevert(bytes4(keccak256("NoCoreCollateralDebt()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Batch_Match_Order_partial_for_maker_multiple_takers_no_debt_but_recent_deposit()
        public
    {
        orderDispatch.setTxFees(0, 0);
        makerOrder.price = 110e18;
        takerOrder.price = 100e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 2);
        takerOrder.quantity = uint128(wethDeposit);
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        constructForceSwapPayload(1, liquidateeDepositCount);
        takerOrder.nonce = 2;
        appendForceSwapPayload(1, liquidateeDepositCount - 1);
        orderDispatch.ingresso(transaction);
    }

    function test_Happy_Match_Order_partial_for_maker_too_much() public {
        orderDispatch.setTxFees(0, 0);
        makerOrder.price = 110e18;
        takerOrder.price = 100e18;
        uint256 wethDeposit = uint256(defaults.wethDepositQuantity() / 4);
        takerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsSpotMatch(
            (wethDeposit * makerOrder.price) / 1e18,
            wethDeposit,
            false,
            takerOrder.productId,
            BasicMath.min(takerOrder.quantity, makerOrder.quantity),
            makerOrder.price
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            1,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(spotCrucible.filledQuantitys(takerHash), wethDeposit);
        assertEq(spotCrucible.filledQuantitys(makerHash), wethDeposit);
        // complete the fill for the maker
        wethDeposit = uint256(defaults.wethDepositQuantity());
        takerOrder.quantity = uint128(wethDeposit);
        ensureBalanceChangeEventsSpotMatch(
            (((wethDeposit * 3) / 4) * makerOrder.price) / 1e18,
            (wethDeposit * 3) / 4,
            false,
            takerOrder.productId,
            (wethDeposit * 3) / 4,
            makerOrder.price
        );
        (takerHash, makerHash) = constructForceSwapPayload(
            1,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(
            spotCrucible.filledQuantitys(takerHash),
            (wethDeposit * 3) / 4
        );
        assertEq(
            spotCrucible.filledQuantitys(makerHash),
            defaults.wethDepositQuantity()
        );
        assertSpotBalanceChange(
            (wethDeposit * makerOrder.price) / 1e18,
            wethDeposit,
            false,
            takerOrder.productId,
            BasicMath.min(takerOrder.quantity, makerOrder.quantity),
            makerOrder.price,
            orderDispatch.txFees(0)
        );
        assertGt(
            int256(
                ciao.balances(
                    Commons.getSubAccount(users.dan, 1),
                    address(usdc)
                )
            ) -
                int256(
                    ciao.coreCollateralDebt(Commons.getSubAccount(users.dan, 1))
                ),
            bcu1
        );
    }

    function test_Happy_Match_Order_maker_BUY_maker_price_more_than_taker()
        public
    {
        makerOrder.price = 110e18;
        takerOrder.price = 100e18;
        ensureBalanceChangeEventsSpotMatch(
            (defaults.wethDepositQuantity() * makerOrder.price) / 1e18,
            defaults.wethDepositQuantity(),
            false,
            takerOrder.productId,
            BasicMath.min(takerOrder.quantity, makerOrder.quantity),
            makerOrder.price
        );
        uint64 liquidateeDepositCount = ciao.depositCount(
            Commons.getSubAccount(users.dan, 1)
        );
        (bytes32 takerHash, bytes32 makerHash) = constructForceSwapPayload(
            1,
            liquidateeDepositCount
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(spotCrucible.filledQuantitys(takerHash), takerOrder.quantity);
        assertEq(spotCrucible.filledQuantitys(makerHash), makerOrder.quantity);
        assertSpotBalanceChange(
            (defaults.wethDepositQuantity() * makerOrder.price) / 1e18,
            defaults.wethDepositQuantity(),
            false,
            takerOrder.productId,
            BasicMath.min(takerOrder.quantity, makerOrder.quantity),
            makerOrder.price,
            orderDispatch.txFees(0)
        );
        assertGt(
            int256(
                ciao.balances(
                    Commons.getSubAccount(users.dan, 1),
                    address(usdc)
                )
            ) -
                int256(
                    ciao.coreCollateralDebt(Commons.getSubAccount(users.dan, 1))
                ),
            bcu1
        );
    }
}
