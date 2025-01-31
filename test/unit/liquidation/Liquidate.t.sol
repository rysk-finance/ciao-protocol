// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Base_Test} from "../../Base.t.sol";
import "src/contracts/libraries/BasicMath.sol";
import {Commons} from "src/contracts/libraries/Commons.sol";
import {MarginDirective} from "src/contracts/libraries/MarginDirective.sol";
import {Events} from "src/contracts/interfaces/Events.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";
import {PerpCrucible} from "src/contracts/crucible/perp-crucible/PerpCrucible.sol";
import {Liquidation} from "src/contracts/Liquidation.sol";

contract LiquidateTest is Base_Test {
    using BasicMath for uint256;

    address aliceSubAccount;
    address larrySubAccount;

    struct TestVars {
        Structs.NewPosition ethPerpPos;
        Structs.NewPosition btcPerpPos;
        address liquidator;
        address liquidatee;
        uint256 perpPrice;
        uint256 spotPrice;
        int256 liquidateeInitialHealthBefore;
        int256 liquidatorInitialHealthBefore;
        int256 liquidateeMaintenanceHealthBefore;
        int256 liquidateeInitialHealthAfter;
        int256 liquidatorInitialHealthAfter;
        uint128 liquidationQuantity;
        uint256 expectedLiquidationPrice;
        uint256 expectedLiquidationPrice2; // use for second leg of a spread
        uint256 coreCollateralDebtBefore;
        uint256 coreCollateralDebtAfter;
    }

    function setUp() public virtual override {
        Base_Test.setUp();
        deployCiao();
        aliceSubAccount = Commons.getSubAccount(users.alice, 1);
        larrySubAccount = Commons.getSubAccount(users.larry, 2); // use different subaccount id
        validateAssets();
        uint256 fraction = 0;

        vm.expectEmit(address(liquidation));
        emit Events.LiquidationFeeFractionSet(fraction);

        liquidation.setLiquidationFeeFraction(fraction);

        assertEq(liquidation.liquidationFeeFraction(), fraction);
    }

    function _depositLarrySpot(
        uint256 usdcSpotQuantity,
        uint256 wbtcSpotQuantity,
        uint256 wethSpotQuantity
    ) internal {
        if (usdcSpotQuantity > 0) {
            deal(address(usdc), users.larry, usdcSpotQuantity);
            vm.startPrank(users.larry);
            usdc.approve(address(ciao), usdcSpotQuantity);
            ciao.deposit(users.larry, 2, usdcSpotQuantity, address(usdc));
            vm.stopPrank();
        }
        if (wethSpotQuantity > 0) {
            deal(address(weth), users.larry, wethSpotQuantity);
            vm.startPrank(users.larry);
            weth.approve(address(ciao), wethSpotQuantity);
            ciao.deposit(users.larry, 2, wethSpotQuantity, address(weth));
            vm.stopPrank();
        }
        if (wbtcSpotQuantity > 0) {
            deal(address(wbtc), users.larry, wbtcSpotQuantity);
            vm.startPrank(users.larry);
            wbtc.approve(address(ciao), wbtcSpotQuantity);
            ciao.deposit(users.larry, 2, wbtcSpotQuantity, address(wbtc));
            vm.stopPrank();
        }
    }

    function test_Happy_LiquidateLongPerpPos() public {
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(2000e18, 10e18, true);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true);
        testVars.perpPrice = 1970e18;
        testVars.spotPrice = 2000e18;
        setAlicePositions(
            0, // wbtcCumFunding
            1e18, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            1000e6, // usdcSpotQuantity
            0, // wethSpotQuantity
            0, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPperpPrice
            0 // wbtcPerpPrice
        );
        // set funding snapshots
        bytes memory payload = abi.encodePacked(defaults.wethUsdcPerpProductId(), int256(2e18));
        perpCrucible.updateCumulativeFundings(payload);
        testVars.liquidateeInitialHealthBefore = furnace.getSubAccountHealth(aliceSubAccount, true);
        testVars.liquidateeMaintenanceHealthBefore =
            furnace.getSubAccountHealth(aliceSubAccount, false);

        assert(testVars.liquidateeMaintenanceHealthBefore > testVars.liquidateeInitialHealthBefore);

        assert(
            testVars.liquidateeMaintenanceHealthBefore
                < int256(liquidation.liquidationHealthBuffer())
        );

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);
        testVars.liquidationQuantity = 1e18;
        testVars.expectedLiquidationPrice = mockLiquidation.getLiquidationPrice(
            defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
        );

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );

        vm.expectEmit(address(liquidation));
        emit Events.Liquidated(
            larrySubAccount,
            aliceSubAccount,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            testVars.expectedLiquidationPrice,
            (testVars.perpPrice - testVars.expectedLiquidationPrice).mul(
                liquidation.liquidationFeeFraction()
            ).mul(testVars.liquidationQuantity)
        );
        liquidation.liquidateSubAccount(liquidationStruct, true);

        // ------ check state after liquidation ------

        Structs.PositionState memory alicePosAfter =
            perpCrucible.getSubAccountPosition(defaults.wethUsdcPerpProductId(), aliceSubAccount);

        Structs.PositionState memory larryPosAfter =
            perpCrucible.getSubAccountPosition(defaults.wethUsdcPerpProductId(), larrySubAccount);

        uint256 insuranceBalance = ciao.balances(ciao.insurance(), address(usdc));
        // check insurance contribution is right
        assertEq(
            insuranceBalance,
            uint256(testVars.liquidationQuantity).mul(
                (testVars.perpPrice - testVars.expectedLiquidationPrice).mul(
                    liquidation.liquidationFeeFraction()
                )
            )
        );

        testVars.liquidatorInitialHealthAfter = furnace.getSubAccountHealth(larrySubAccount, true);
        testVars.liquidateeInitialHealthAfter = furnace.getSubAccountHealth(aliceSubAccount, true);
        // larry's initial health should be above zero
        assert(testVars.liquidatorInitialHealthAfter > 0);
        // larry's health should be equal to initial usdc balance + perp health - fees paid to insurance
        assert(
            testVars.liquidatorInitialHealthAfter
                == int256(1000000e18) - int256(insuranceBalance)
                    + MarginDirective.getPerpMarginHealth(
                        true,
                        defaults.wethUsdcPerpRiskWeights(),
                        larryPosAfter.quantity,
                        larryPosAfter.avgEntryPrice,
                        testVars.ethPerpPos.isLong,
                        testVars.perpPrice,
                        0,
                        0
                    )
        );
        // alice's initialHealth should be 0 or less (if above she has been over-liquidated)
        assert(testVars.liquidateeInitialHealthAfter <= 0);
        // alice's initialHealth should have increased
        assert(testVars.liquidateeInitialHealthAfter > testVars.liquidateeInitialHealthBefore);
        // larrys avg entry price should be equal to the liquidation price
        assert(
            larryPosAfter.avgEntryPrice
                == mockLiquidation.getLiquidationPrice(
                    defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
                )
        );
        // alice's avg entry price should be unchanged
        assert(alicePosAfter.avgEntryPrice == testVars.ethPerpPos.executionPrice);
        // larry's pos size should be the liquidation quantity
        assert(larryPosAfter.quantity == testVars.liquidationQuantity);
        // larry's pos should be in same direction as alice's initial pos
        assert(larryPosAfter.isLong == testVars.ethPerpPos.isLong);
        // alice's pos size should be her initial pos size - liquidation quantity
        assert(
            alicePosAfter.quantity == testVars.ethPerpPos.quantity - testVars.liquidationQuantity
        );
        // alice's usdc holdings should have decreased by size * (entry price- liq price)
        assertEq(
            ciao.balances(aliceSubAccount, address(usdc)),
            1000e18
                - uint256(testVars.liquidationQuantity).mul(
                    testVars.ethPerpPos.executionPrice - testVars.expectedLiquidationPrice
                ) - uint256(testVars.ethPerpPos.quantity).mul(2e18)
        );
    }

    function test_Happy_LiquidateLongPerpPosLarryHasPos() public {
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(2000e18, 10e18, true);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true);
        testVars.perpPrice = 1970e18;
        testVars.spotPrice = 2000e18;
        setAlicePositions(
            0, // wbtcCumFunding
            1e18, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            1000e6, // usdcSpotQuantity
            0, // wethSpotQuantity
            0, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPperpPrice
            0 // wbtcPerpPrice
        );
        testVars.liquidateeInitialHealthBefore = furnace.getSubAccountHealth(aliceSubAccount, true);
        testVars.liquidateeMaintenanceHealthBefore =
            furnace.getSubAccountHealth(aliceSubAccount, false);
        assert(testVars.liquidateeMaintenanceHealthBefore > testVars.liquidateeInitialHealthBefore);

        assert(
            testVars.liquidateeMaintenanceHealthBefore
                < int256(liquidation.liquidationHealthBuffer())
        );

        _depositLarrySpot(1_000_000e6, 0, 0);
        vm.startPrank({msgSender: users.gov});
        perpCrucible.updatePosition(
            address(0),
            Commons.getSubAccount(users.larry, 2),
            defaults.wethUsdcPerpProductId(),
            Structs.NewPosition(2000e18, 5e17, false)
        );
        // set funding snapshots
        bytes memory payload = abi.encodePacked(defaults.wethUsdcPerpProductId(), int256(2e18));
        perpCrucible.updateCumulativeFundings(payload);
        // ------ start liquidation ------
        testVars.liquidationQuantity = 1e18;
        testVars.expectedLiquidationPrice = mockLiquidation.getLiquidationPrice(
            defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
        );

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );

        vm.expectEmit(address(liquidation));
        emit Events.Liquidated(
            larrySubAccount,
            aliceSubAccount,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            testVars.expectedLiquidationPrice,
            (testVars.perpPrice - testVars.expectedLiquidationPrice).mul(
                liquidation.liquidationFeeFraction()
            ).mul(testVars.liquidationQuantity)
        );
        liquidation.liquidateSubAccount(liquidationStruct, true);

        // ------ check state after liquidation ------

        Structs.PositionState memory alicePosAfter =
            perpCrucible.getSubAccountPosition(defaults.wethUsdcPerpProductId(), aliceSubAccount);

        Structs.PositionState memory larryPosAfter =
            perpCrucible.getSubAccountPosition(defaults.wethUsdcPerpProductId(), larrySubAccount);

        uint256 insuranceBalance = ciao.balances(ciao.insurance(), address(usdc));
        // check insurance contribution is right
        assertEq(
            insuranceBalance,
            uint256(testVars.liquidationQuantity).mul(
                (testVars.perpPrice - testVars.expectedLiquidationPrice).mul(
                    liquidation.liquidationFeeFraction()
                )
            )
        );
        testVars.liquidatorInitialHealthAfter = furnace.getSubAccountHealth(larrySubAccount, true);
        testVars.liquidateeInitialHealthAfter = furnace.getSubAccountHealth(aliceSubAccount, true);
        // larry's initial health should be above zero
        assert(testVars.liquidatorInitialHealthAfter > 0);
        // alice's initialHealth should be 0 or less (if above she has been over-liquidated)
        assert(testVars.liquidateeInitialHealthAfter <= 0);
        // alice's initialHealth should have increased
        assert(testVars.liquidateeInitialHealthAfter > testVars.liquidateeInitialHealthBefore);
        // larrys avg entry price should be equal to the liquidation price
        assert(
            larryPosAfter.avgEntryPrice
                == mockLiquidation.getLiquidationPrice(
                    defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
                )
        );
        // alice's avg entry price should be unchanged
        assert(alicePosAfter.avgEntryPrice == testVars.ethPerpPos.executionPrice);
        // larry's pos size should be the liquidation quantity
        assert(larryPosAfter.quantity == testVars.liquidationQuantity - 5e17);
        // larry's pos should be in same direction as alice's initial pos
        assert(larryPosAfter.isLong == testVars.ethPerpPos.isLong);
        // alice's pos size should be her initial pos size - liquidation quantity
        assert(
            alicePosAfter.quantity == testVars.ethPerpPos.quantity - testVars.liquidationQuantity
        );
        // alice's usdc holdings should have decreased by size * (entry price- liq price)
        assertEq(
            ciao.balances(aliceSubAccount, address(usdc)),
            1000e18
                - uint256(testVars.liquidationQuantity).mul(
                    testVars.ethPerpPos.executionPrice - testVars.expectedLiquidationPrice
                ) - uint256(testVars.ethPerpPos.quantity).mul(2e18)
        );
        // larry's usdc holdings should have decreased by size * (entry price- liq price)
        assertEq(
            ciao.balances(larrySubAccount, address(usdc)),
            1000000e18
                + uint256(5e17).mul(
                    testVars.ethPerpPos.executionPrice - testVars.expectedLiquidationPrice
                ) + uint256(5e17).mul(2e18)
        );
    }

    function test_Happy_LiquidateLongPerpPosHealthPositiveButBelowBuffer() public {
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(2000e18, 10e18, true);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true);
        testVars.perpPrice = 1970e18;
        testVars.spotPrice = 2000e18;
        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            1290e6, // usdcSpotQuantity
            0, // wethSpotQuantity
            0, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPperpPrice
            0 // wbtcPerpPrice
        );

        testVars.liquidateeInitialHealthBefore = furnace.getSubAccountHealth(aliceSubAccount, true);
        testVars.liquidateeMaintenanceHealthBefore =
            furnace.getSubAccountHealth(aliceSubAccount, false);
        assert(testVars.liquidateeMaintenanceHealthBefore > testVars.liquidateeInitialHealthBefore);

        assert(
            testVars.liquidateeMaintenanceHealthBefore
                < int256(liquidation.liquidationHealthBuffer())
        );

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);
        testVars.liquidationQuantity = 1e18;
        testVars.expectedLiquidationPrice = mockLiquidation.getLiquidationPrice(
            defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
        );

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );

        vm.expectEmit(address(liquidation));
        emit Events.Liquidated(
            larrySubAccount,
            aliceSubAccount,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            testVars.expectedLiquidationPrice,
            (testVars.perpPrice - testVars.expectedLiquidationPrice).mul(
                liquidation.liquidationFeeFraction()
            ).mul(testVars.liquidationQuantity)
        );
        liquidation.liquidateSubAccount(liquidationStruct, true);

        // ------ check state after liquidation ------

        Structs.PositionState memory alicePosAfter =
            perpCrucible.getSubAccountPosition(defaults.wethUsdcPerpProductId(), aliceSubAccount);

        Structs.PositionState memory larryPosAfter =
            perpCrucible.getSubAccountPosition(defaults.wethUsdcPerpProductId(), larrySubAccount);

        uint256 insuranceBalance = ciao.balances(ciao.insurance(), address(usdc));
        // check insurance contribution is right
        assertEq(
            insuranceBalance,
            uint256(testVars.liquidationQuantity).mul(
                (testVars.perpPrice - testVars.expectedLiquidationPrice).mul(
                    liquidation.liquidationFeeFraction()
                )
            )
        );

        testVars.liquidatorInitialHealthAfter = furnace.getSubAccountHealth(larrySubAccount, true);
        testVars.liquidateeInitialHealthAfter = furnace.getSubAccountHealth(aliceSubAccount, true);
        // larry's initial health should be above zero
        assert(testVars.liquidatorInitialHealthAfter > 0);
        // larry's health should be equal to initial usdc balance + perp health - fees paid to insurance
        assert(
            testVars.liquidatorInitialHealthAfter
                == int256(1000000e18) - int256(insuranceBalance)
                    + MarginDirective.getPerpMarginHealth(
                        true,
                        defaults.wethUsdcPerpRiskWeights(),
                        larryPosAfter.quantity,
                        larryPosAfter.avgEntryPrice,
                        testVars.ethPerpPos.isLong,
                        testVars.perpPrice,
                        0,
                        0
                    )
        );
        // alice's initialHealth should be 0 or less (if above she has been over-liquidated)
        assert(testVars.liquidateeInitialHealthAfter <= 0);
        // alice's initialHealth should have increased
        assert(testVars.liquidateeInitialHealthAfter > testVars.liquidateeInitialHealthBefore);
        // larrys avg entry price should be equal to the liquidation price
        assert(
            larryPosAfter.avgEntryPrice
                == mockLiquidation.getLiquidationPrice(
                    defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
                )
        );
        // alice's avg entry price should be unchanged
        assert(alicePosAfter.avgEntryPrice == testVars.ethPerpPos.executionPrice);
        // larry's pos size should be the liquidation quantity
        assert(larryPosAfter.quantity == testVars.liquidationQuantity);
        // larry's pos should be in same direction as alice's initial pos
        assert(larryPosAfter.isLong == testVars.ethPerpPos.isLong);
        // alice's pos size should be her initial pos size - liquidation quantity
        assert(
            alicePosAfter.quantity == testVars.ethPerpPos.quantity - testVars.liquidationQuantity
        );
        // alice's usdc holdings should have decreased by size * (entry price- liq price)
        assertEq(
            ciao.balances(aliceSubAccount, address(usdc)),
            1290e18
                - uint256(testVars.liquidationQuantity).mul(
                    testVars.ethPerpPos.executionPrice - testVars.expectedLiquidationPrice
                )
        );
    }

    function test_Happy_LiquidateShortPerpPos() public {
        furnace.setSpotRiskWeight(address(weth), Structs.ProductRiskWeights(0, 0, 0, 0));
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(2000e18, 10e18, false);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.perpPrice = 2040e18;
        testVars.spotPrice = 2000e18;
        setAlicePositions(
            0, // wbtcCumFunding
            1e18, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            1000e6, // usdcSpotQuantity
            50e18, // wethSpotQuantity
            0, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPperpPrice
            0 // wbtcPerpPrice
        );
        // set funding snapshots
        bytes memory payload = abi.encodePacked(defaults.wethUsdcPerpProductId(), int256(2e18));
        perpCrucible.updateCumulativeFundings(payload);
        testVars.liquidateeInitialHealthBefore = furnace.getSubAccountHealth(aliceSubAccount, true);

        testVars.liquidateeMaintenanceHealthBefore =
            furnace.getSubAccountHealth(aliceSubAccount, false);

        assert(testVars.liquidateeMaintenanceHealthBefore > testVars.liquidateeInitialHealthBefore);

        assert(
            testVars.liquidateeMaintenanceHealthBefore
                < int256(liquidation.liquidationHealthBuffer())
        );

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 12e17;
        testVars.expectedLiquidationPrice = mockLiquidation.getLiquidationPrice(
            defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
        );

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );

        vm.expectEmit(address(liquidation));
        emit Events.Liquidated(
            larrySubAccount,
            aliceSubAccount,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            testVars.expectedLiquidationPrice,
            (testVars.expectedLiquidationPrice - testVars.perpPrice).mul(
                liquidation.liquidationFeeFraction()
            ).mul(testVars.liquidationQuantity)
        );
        liquidation.liquidateSubAccount(liquidationStruct, true);

        // ------ check state after liquidation ------

        Structs.PositionState memory alicePosAfter =
            perpCrucible.getSubAccountPosition(defaults.wethUsdcPerpProductId(), aliceSubAccount);

        Structs.PositionState memory larryPosAfter =
            perpCrucible.getSubAccountPosition(defaults.wethUsdcPerpProductId(), larrySubAccount);

        uint256 insuranceBalance = ciao.balances(ciao.insurance(), address(usdc));
        // check insurance contribution is right
        assertEq(
            insuranceBalance,
            uint256(testVars.liquidationQuantity).mul(
                (testVars.expectedLiquidationPrice - testVars.perpPrice).mul(
                    liquidation.liquidationFeeFraction()
                )
            )
        );

        testVars.liquidatorInitialHealthAfter = furnace.getSubAccountHealth(larrySubAccount, true);

        testVars.liquidateeInitialHealthAfter = furnace.getSubAccountHealth(aliceSubAccount, true);

        // larry's initial health should be above zero
        assert(testVars.liquidatorInitialHealthAfter > 0);
        // larry's health should be equal to initial usdc balance + perp health - fees paid to insurance
        assert(
            testVars.liquidatorInitialHealthAfter
                == int256(1000000e18) - int256(insuranceBalance)
                    + MarginDirective.getPerpMarginHealth(
                        true,
                        defaults.wethUsdcPerpRiskWeights(),
                        larryPosAfter.quantity,
                        larryPosAfter.avgEntryPrice,
                        testVars.ethPerpPos.isLong,
                        testVars.perpPrice,
                        0,
                        0
                    )
        );
        // alice's initialHealth should be 0 or less (if above she has been over-liquidated)
        assert(testVars.liquidateeInitialHealthAfter <= 0);
        // alice's initialHealth should have increased
        assert(testVars.liquidateeInitialHealthAfter > testVars.liquidateeInitialHealthBefore);
        // larrys avg entry price should be equal to the liquidation price
        assert(
            larryPosAfter.avgEntryPrice
                == mockLiquidation.getLiquidationPrice(
                    defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
                )
        );
        // alice's avg entry price should be unchanged
        assert(alicePosAfter.avgEntryPrice == testVars.ethPerpPos.executionPrice);
        // larry's pos size should be the liquidation quantity
        assert(larryPosAfter.quantity == testVars.liquidationQuantity);
        // larry's pos should be in same direction as alice's initial pos
        assert(larryPosAfter.isLong == testVars.ethPerpPos.isLong);
        // alice's pos size should be her initial pos size - liquidation quantity
        assert(
            alicePosAfter.quantity == testVars.ethPerpPos.quantity - testVars.liquidationQuantity
        );
        // alice's usdc holdings should have decreased by size * (entry price- liq price)
        assertEq(
            ciao.balances(aliceSubAccount, address(usdc)),
            1000e18
                - uint256(testVars.liquidationQuantity).mul(
                    testVars.expectedLiquidationPrice - testVars.ethPerpPos.executionPrice
                ) + uint256(testVars.ethPerpPos.quantity).mul(2e18)
        );
    }

    function test_Happy_LiquidateShortPerpPosLarryHasPos() public {
        furnace.setSpotRiskWeight(address(weth), Structs.ProductRiskWeights(0, 0, 0, 0));
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(2000e18, 10e18, false);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.perpPrice = 2040e18;
        testVars.spotPrice = 2000e18;
        setAlicePositions(
            0, // wbtcCumFunding
            1e18, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            1000e6, // usdcSpotQuantity
            50e18, // wethSpotQuantity
            0, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPperpPrice
            0 // wbtcPerpPrice
        );
        testVars.liquidateeInitialHealthBefore = furnace.getSubAccountHealth(aliceSubAccount, true);

        testVars.liquidateeMaintenanceHealthBefore =
            furnace.getSubAccountHealth(aliceSubAccount, false);

        assert(testVars.liquidateeMaintenanceHealthBefore > testVars.liquidateeInitialHealthBefore);

        assert(
            testVars.liquidateeMaintenanceHealthBefore
                < int256(liquidation.liquidationHealthBuffer())
        );

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);
        perpCrucible.updatePosition(
            address(0),
            Commons.getSubAccount(users.larry, 2),
            defaults.wethUsdcPerpProductId(),
            Structs.NewPosition(2000e18, 10e18, false)
        );
        // set funding snapshots
        bytes memory payload = abi.encodePacked(defaults.wethUsdcPerpProductId(), int256(2e18));
        perpCrucible.updateCumulativeFundings(payload);
        testVars.liquidationQuantity = 12e17;
        testVars.expectedLiquidationPrice = mockLiquidation.getLiquidationPrice(
            defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
        );

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );

        vm.expectEmit(address(liquidation));
        emit Events.Liquidated(
            larrySubAccount,
            aliceSubAccount,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            testVars.expectedLiquidationPrice,
            (testVars.expectedLiquidationPrice - testVars.perpPrice).mul(
                liquidation.liquidationFeeFraction()
            ).mul(testVars.liquidationQuantity)
        );
        liquidation.liquidateSubAccount(liquidationStruct, true);

        // ------ check state after liquidation ------

        Structs.PositionState memory alicePosAfter =
            perpCrucible.getSubAccountPosition(defaults.wethUsdcPerpProductId(), aliceSubAccount);

        Structs.PositionState memory larryPosAfter =
            perpCrucible.getSubAccountPosition(defaults.wethUsdcPerpProductId(), larrySubAccount);

        uint256 insuranceBalance = ciao.balances(ciao.insurance(), address(usdc));
        // check insurance contribution is right
        assertEq(
            insuranceBalance,
            uint256(testVars.liquidationQuantity).mul(
                (testVars.expectedLiquidationPrice - testVars.perpPrice).mul(
                    liquidation.liquidationFeeFraction()
                )
            )
        );

        testVars.liquidatorInitialHealthAfter = furnace.getSubAccountHealth(larrySubAccount, true);

        testVars.liquidateeInitialHealthAfter = furnace.getSubAccountHealth(aliceSubAccount, true);

        // larry's initial health should be above zero
        assert(testVars.liquidatorInitialHealthAfter > 0);
        // alice's initialHealth should be 0 or less (if above she has been over-liquidated)
        assert(testVars.liquidateeInitialHealthAfter <= 0);
        // alice's initialHealth should have increased
        assert(testVars.liquidateeInitialHealthAfter > testVars.liquidateeInitialHealthBefore);
        assert(
            larryPosAfter.avgEntryPrice
                == (
                    (2000e18 * 10) + testVars.expectedLiquidationPrice.mul(testVars.liquidationQuantity)
                ).div(11.2e18)
        );
        // alice's avg entry price should be unchanged
        assert(alicePosAfter.avgEntryPrice == testVars.ethPerpPos.executionPrice);
        // larry's pos size should be the liquidation quantity
        assert(larryPosAfter.quantity == 10e18 + testVars.liquidationQuantity);
        // larry's pos should be in same direction as alice's initial pos
        assert(larryPosAfter.isLong == testVars.ethPerpPos.isLong);
        // alice's pos size should be her initial pos size - liquidation quantity
        assert(
            alicePosAfter.quantity == testVars.ethPerpPos.quantity - testVars.liquidationQuantity
        );
        // alice's usdc holdings should have decreased by size * (entry price- liq price)
        assertEq(
            ciao.balances(aliceSubAccount, address(usdc)),
            1000e18
                - uint256(testVars.liquidationQuantity).mul(
                    testVars.expectedLiquidationPrice - testVars.ethPerpPos.executionPrice
                ) + uint256(testVars.ethPerpPos.quantity).mul(2e18)
        );
        // larry's usdc holdings should have decreased by size * (entry price- liq price)
        assertEq(
            ciao.balances(larrySubAccount, address(usdc)), 1000000e18 + uint256(10e18).mul(2e18)
        );
    }

    function test_Happy_LiquidateShortPerpPosBecauseInvalidSpread() public {
        furnace.setSpreadPenalty(address(weth), 1e18, 1e18);
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(2000e18, 10e18, false);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.perpPrice = 2040e18;
        testVars.spotPrice = 2000e18;
        uint256 wethSpotBefore = 2e17;
        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            1000e6, // usdcSpotQuantity
            wethSpotBefore, // wethSpotQuantity
            0, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPerpPrice
            0 // wbtcPerpPrice
        );
        testVars.liquidateeInitialHealthBefore = furnace.getSubAccountHealth(aliceSubAccount, true);

        testVars.liquidateeMaintenanceHealthBefore =
            furnace.getSubAccountHealth(aliceSubAccount, false);

        assert(testVars.liquidateeMaintenanceHealthBefore > testVars.liquidateeInitialHealthBefore);

        assert(
            testVars.liquidateeMaintenanceHealthBefore
                < int256(liquidation.liquidationHealthBuffer())
        );

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 12e17;
        testVars.expectedLiquidationPrice = mockLiquidation.getLiquidationPrice(
            defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
        );

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );

        vm.expectEmit(address(liquidation));
        emit Events.Liquidated(
            larrySubAccount,
            aliceSubAccount,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            testVars.expectedLiquidationPrice,
            (testVars.expectedLiquidationPrice - testVars.perpPrice).mul(
                liquidation.liquidationFeeFraction()
            ).mul(testVars.liquidationQuantity)
        );
        liquidation.liquidateSubAccount(liquidationStruct, true);

        // ------ check state after liquidation ------

        Structs.PositionState memory alicePosAfter =
            perpCrucible.getSubAccountPosition(defaults.wethUsdcPerpProductId(), aliceSubAccount);

        Structs.PositionState memory larryPosAfter =
            perpCrucible.getSubAccountPosition(defaults.wethUsdcPerpProductId(), larrySubAccount);

        uint256 insuranceBalance = ciao.balances(ciao.insurance(), address(usdc));
        // check insurance contribution is right
        assertEq(
            insuranceBalance,
            uint256(testVars.liquidationQuantity).mul(
                (testVars.expectedLiquidationPrice - testVars.perpPrice).mul(
                    liquidation.liquidationFeeFraction()
                )
            )
        );

        testVars.liquidatorInitialHealthAfter = furnace.getSubAccountHealth(larrySubAccount, true);

        testVars.liquidateeInitialHealthAfter = furnace.getSubAccountHealth(aliceSubAccount, true);

        // larry's initial health should be above zero
        assert(testVars.liquidatorInitialHealthAfter > 0);
        // larry's health should be equal to initial usdc balance + perp health - fees paid to insurance
        assert(
            testVars.liquidatorInitialHealthAfter
                == int256(1000000e18) - int256(insuranceBalance)
                    + MarginDirective.getPerpMarginHealth(
                        true,
                        defaults.wethUsdcPerpRiskWeights(),
                        larryPosAfter.quantity,
                        larryPosAfter.avgEntryPrice,
                        testVars.ethPerpPos.isLong,
                        testVars.perpPrice,
                        0,
                        0
                    )
        );
        // alice's initialHealth should be 0 or less (if above she has been over-liquidated)
        assert(testVars.liquidateeInitialHealthAfter <= 0);
        // alice's initialHealth should have increased
        assert(testVars.liquidateeInitialHealthAfter > testVars.liquidateeInitialHealthBefore);
        // larrys avg entry price should be equal to the liquidation price
        assert(
            larryPosAfter.avgEntryPrice
                == mockLiquidation.getLiquidationPrice(
                    defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
                )
        );
        // alice's avg entry price should be unchanged
        assert(alicePosAfter.avgEntryPrice == testVars.ethPerpPos.executionPrice);
        // larry's pos size should be the liquidation quantity
        assert(larryPosAfter.quantity == testVars.liquidationQuantity);

        // larry's pos should be in same direction as alice's initial pos
        assert(larryPosAfter.isLong == testVars.ethPerpPos.isLong);
        // alice's pos size should be her initial pos size - liquidation quantity
        assert(
            alicePosAfter.quantity == testVars.ethPerpPos.quantity - testVars.liquidationQuantity
        );
        // alice's weth spot size should be the unchanged since it is not liquidating as a spread
        assertEq(ciao.balances(aliceSubAccount, address(weth)), wethSpotBefore);
        // alice's usdc holdings should have decreased by size * (entry price- liq price)
        assertEq(
            ciao.balances(aliceSubAccount, address(usdc)),
            1000e18
                - uint256(testVars.liquidationQuantity).mul(
                    testVars.expectedLiquidationPrice - testVars.ethPerpPos.executionPrice
                )
        );
    }

    function test_Happy_LiquidateSpread() public {
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(1000e18, 10e18, false);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.perpPrice = 3200e18;
        testVars.spotPrice = 1900e18;

        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            0, // usdcSpotQuantity
            11e18, // wethSpotQuantity
            0, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPperpPrice
            0 // wbtcPerpPrice
        );

        testVars.liquidateeInitialHealthBefore = furnace.getSubAccountHealth(aliceSubAccount, true);

        testVars.liquidateeMaintenanceHealthBefore =
            furnace.getSubAccountHealth(aliceSubAccount, false);

        assertGt(testVars.liquidateeMaintenanceHealthBefore, testVars.liquidateeInitialHealthBefore);

        assertLt(testVars.liquidateeMaintenanceHealthBefore, 0);

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 1e18;
        testVars.expectedLiquidationPrice = mockLiquidation.getSpreadLiquidationPrice(
            address(weth), testVars.perpPrice, testVars.ethPerpPos.isLong
        );

        testVars.expectedLiquidationPrice2 = mockLiquidation // spot
            .getSpreadLiquidationPrice(address(weth), testVars.spotPrice, true);

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            0,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );

        vm.expectEmit(address(liquidation));
        emit Events.Liquidated(
            larrySubAccount,
            aliceSubAccount,
            1,
            defaults.wethProductId(),
            testVars.liquidationQuantity,
            testVars.expectedLiquidationPrice2,
            (testVars.spotPrice - testVars.expectedLiquidationPrice2).mul(
                liquidation.liquidationFeeFraction()
            ).mul(testVars.liquidationQuantity)
        );
        vm.expectEmit(address(liquidation));
        emit Events.Liquidated(
            larrySubAccount,
            aliceSubAccount,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            testVars.expectedLiquidationPrice,
            (testVars.expectedLiquidationPrice - testVars.perpPrice).mul(
                liquidation.liquidationFeeFraction()
            ).mul(testVars.liquidationQuantity)
        );
        liquidation.liquidateSubAccount(liquidationStruct, true);

        // ------ check state after liquidation ------

        Structs.PositionState memory alicePosAfter =
            perpCrucible.getSubAccountPosition(defaults.wethUsdcPerpProductId(), aliceSubAccount);

        Structs.PositionState memory larryPosAfter =
            perpCrucible.getSubAccountPosition(defaults.wethUsdcPerpProductId(), larrySubAccount);

        uint256 insuranceBalance = ciao.balances(ciao.insurance(), address(usdc));

        // check insurance contribution is right
        assertEq(
            insuranceBalance,
            uint256(testVars.liquidationQuantity).mul(
                (
                    testVars.expectedLiquidationPrice - testVars.perpPrice + testVars.spotPrice
                        - testVars.expectedLiquidationPrice2
                ).mul(liquidation.liquidationFeeFraction())
            )
        );

        testVars.liquidatorInitialHealthAfter = furnace.getSubAccountHealth(larrySubAccount, true);
        testVars.liquidateeInitialHealthAfter = furnace.getSubAccountHealth(aliceSubAccount, true);

        // larry's initial health should be above zero
        assert(testVars.liquidatorInitialHealthAfter > 0);
        // larry's health should be equal to initial usdc balance - spot paid to liquidate - fees paid to insurance + spread health
        assertEq(
            testVars.liquidatorInitialHealthAfter,
            int256(1000000e18)
                - int256(testVars.expectedLiquidationPrice2.mul(testVars.liquidationQuantity))
                - int256(insuranceBalance)
                + MarginDirective._calculateSpreadHealth(
                    furnace.getSpreadPenalty(address(weth)).initial,
                    testVars.liquidationQuantity,
                    testVars.spotPrice,
                    testVars.perpPrice,
                    testVars.expectedLiquidationPrice,
                    0,
                    0
                )
        );

        // alice's initialHealth should be 0 or less (if above she has been over-liquidated)
        assertLe(testVars.liquidateeInitialHealthAfter, 0);
        // alice's initialHealth should have increased
        assertGe(testVars.liquidateeInitialHealthAfter, testVars.liquidateeInitialHealthBefore);
        // larrys avg entry price should be equal to the liquidation price
        assertEq(larryPosAfter.avgEntryPrice, testVars.expectedLiquidationPrice);
        // alice's avg entry price should be unchanged
        assertEq(alicePosAfter.avgEntryPrice, testVars.ethPerpPos.executionPrice);
        // larry's pos size should be the liquidation quantity
        assertEq(larryPosAfter.quantity, testVars.liquidationQuantity);
        // larry's pos should be in same direction as alice's initial pos
        assert(larryPosAfter.isLong == testVars.ethPerpPos.isLong);
        // alice's pos size should be her initial pos size - liquidation quantity
        assertEq(
            alicePosAfter.quantity, testVars.ethPerpPos.quantity - testVars.liquidationQuantity
        );

        // alice's usdc holdings should have decreased by size * (entry price- liq price) - liquidation price for spot
        assertEq(
            ciao.coreCollateralDebt(aliceSubAccount),
            uint256(testVars.liquidationQuantity).mul(
                testVars.expectedLiquidationPrice - testVars.ethPerpPos.executionPrice
                    - testVars.expectedLiquidationPrice2
            )
        );
        // alice's weth holdings should be reduced by liquidation quantity
        assertEq(
            ciao.balances(aliceSubAccount, address(weth)), 11e18 - testVars.liquidationQuantity
        );
        // larry's weth holdings should be increased by liquidation quantity
        assertEq(ciao.balances(larrySubAccount, address(weth)), testVars.liquidationQuantity);
    }

    function test_Happy_LiquidateSpot() public {
        // First we need to have the liquidatee incur debt
        ciao.settleCoreCollateral(aliceSubAccount, -10000e18);

        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.perpPrice = 3200e18;
        testVars.spotPrice = 2000e18;

        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            0, // usdcSpotQuantity
            5e18, // wethSpotQuantity
            0, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPperpPrice
            0 // wbtcPerpPrice
        );

        testVars.coreCollateralDebtBefore = ciao.coreCollateralDebt(aliceSubAccount);
        testVars.liquidateeInitialHealthBefore = furnace.getSubAccountHealth(aliceSubAccount, true);

        testVars.liquidateeMaintenanceHealthBefore =
            furnace.getSubAccountHealth(aliceSubAccount, false);

        assertGt(testVars.liquidateeMaintenanceHealthBefore, testVars.liquidateeInitialHealthBefore);

        assertLt(testVars.liquidateeMaintenanceHealthBefore, 0);

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 1e18;
        testVars.expectedLiquidationPrice =
            mockLiquidation.getLiquidationPrice(defaults.wethProductId(), testVars.spotPrice, true);

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            1,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );
        vm.expectEmit(address(liquidation));
        emit Events.Liquidated(
            larrySubAccount,
            aliceSubAccount,
            1,
            defaults.wethProductId(),
            testVars.liquidationQuantity,
            testVars.expectedLiquidationPrice,
            (testVars.spotPrice - testVars.expectedLiquidationPrice).mul(
                liquidation.liquidationFeeFraction()
            ).mul(testVars.liquidationQuantity)
        );
        liquidation.liquidateSubAccount(liquidationStruct, true);

        // ------ check state after liquidation ------

        uint256 aliceWethBalanceAfter = ciao.balances(aliceSubAccount, address(weth));

        uint256 larryWethBalanceAfter = ciao.balances(larrySubAccount, address(weth));

        uint256 insuranceBalance = ciao.balances(ciao.insurance(), address(usdc));
        // check insurance contribution is right
        assertEq(
            insuranceBalance,
            uint256(testVars.liquidationQuantity).mul(
                (testVars.spotPrice - testVars.expectedLiquidationPrice).mul(
                    liquidation.liquidationFeeFraction()
                )
            )
        );

        testVars.liquidatorInitialHealthAfter = furnace.getSubAccountHealth(larrySubAccount, true);
        testVars.liquidateeInitialHealthAfter = furnace.getSubAccountHealth(aliceSubAccount, true);
        testVars.coreCollateralDebtAfter = ciao.coreCollateralDebt(aliceSubAccount);

        // larry's initial health should be above zero
        assert(testVars.liquidatorInitialHealthAfter > 0);
        // larry's health should be equal to initial usdc balance - spot paid to liquidate - fees paid to insurance + received weth health
        assertEq(
            testVars.liquidatorInitialHealthAfter,
            int256(1000000e18)
                - int256(testVars.expectedLiquidationPrice.mul(testVars.liquidationQuantity))
                - int256(insuranceBalance)
                + MarginDirective._calculateSpotHealth(
                    furnace.getSpotRiskWeights(address(weth)).initialLongWeight,
                    testVars.liquidationQuantity,
                    testVars.spotPrice
                )
        );

        // alice's initialHealth should be 0 or less (if above she has been over-liquidated)
        assertLe(testVars.liquidateeInitialHealthAfter, 0);
        // alice's initialHealth should have increased
        assertGe(testVars.liquidateeInitialHealthAfter, testVars.liquidateeInitialHealthBefore);

        // alice's pos size should be decreased by liquidation mount
        assertEq(aliceWethBalanceAfter, 5e18 - testVars.liquidationQuantity);
        // alice's usdc size should be increased by liquidation price
        assertEq(
            ciao.coreCollateralDebt(aliceSubAccount), 10000e18 - testVars.expectedLiquidationPrice
        );

        // larry's pos size should be the liquidation quantity
        assertEq(larryWethBalanceAfter, testVars.liquidationQuantity);

        assertEq(
            testVars.coreCollateralDebtAfter,
            testVars.coreCollateralDebtBefore
                - testVars.expectedLiquidationPrice.mul(testVars.liquidationQuantity)
        );
    }

    function test_Fail_LiquidateSpotWithOpenPerp() public {
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(2000e18, 100e18, false);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.perpPrice = 2200e18;
        testVars.spotPrice = 2000e18;

        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            1000e6, // usdcSpotQuantity
            0, // wethSpotQuantity
            1e8, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            30000e18, // wbtcSpotPrice
            testVars.perpPrice, // wethPperpPrice
            0 // wbtcPerpPrice
        );

        testVars.liquidateeInitialHealthBefore = furnace.getSubAccountHealth(aliceSubAccount, true);

        testVars.liquidateeMaintenanceHealthBefore =
            furnace.getSubAccountHealth(aliceSubAccount, false);

        assert(testVars.liquidateeMaintenanceHealthBefore > testVars.liquidateeInitialHealthBefore);

        assert(
            testVars.liquidateeMaintenanceHealthBefore
                < int256(liquidation.liquidationHealthBuffer())
        );

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 1e18;
        testVars.expectedLiquidationPrice = mockLiquidation.getLiquidationPrice(
            defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
        );

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            1,
            defaults.wbtcProductId(),
            testVars.liquidationQuantity,
            0
        );
        vm.expectRevert(bytes4(keccak256("LiquidatePerpsFirst()")));
        liquidation.liquidateSubAccount(liquidationStruct, true);
    }

    function test_Fail_LiquidateSpreadWithOpenNakedPerp() public {
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(testVars.spotPrice, 100e18, false);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.perpPrice = 2400e18;
        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            0, // usdcSpotQuantity
            20e18, // wethSpotQuantity
            0, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPperpPrice
            0 // wbtcPerpPrice
        );

        testVars.liquidateeInitialHealthBefore = furnace.getSubAccountHealth(aliceSubAccount, true);
        testVars.liquidateeMaintenanceHealthBefore =
            furnace.getSubAccountHealth(aliceSubAccount, false);

        assert(testVars.liquidateeMaintenanceHealthBefore > testVars.liquidateeInitialHealthBefore);

        assert(
            testVars.liquidateeMaintenanceHealthBefore
                < int256(liquidation.liquidationHealthBuffer())
        );

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 1e18;
        testVars.expectedLiquidationPrice = mockLiquidation.getLiquidationPrice(
            defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
        );

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            0,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );
        vm.expectRevert(bytes4(keccak256("LiquidateNakedPerpsFirst()")));
        liquidation.liquidateSubAccount(liquidationStruct, true);
    }

    function test_Fail_LiquidateSpreadPositiveHealth() public {
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(2000e18, 100e18, false);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.perpPrice = 1900e18;
        testVars.spotPrice = 2000e18;
        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            0, // usdcSpotQuantity
            20e18, // wethSpotQuantity
            0, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPperpPrice
            0 // wbtcPerpPrice
        );

        testVars.liquidateeInitialHealthBefore = furnace.getSubAccountHealth(aliceSubAccount, true);
        testVars.liquidateeMaintenanceHealthBefore =
            furnace.getSubAccountHealth(aliceSubAccount, false);

        assert(testVars.liquidateeMaintenanceHealthBefore > testVars.liquidateeInitialHealthBefore);
        // alice health ABOVE zero
        assert(testVars.liquidateeMaintenanceHealthBefore > 0);

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 1e18;
        testVars.expectedLiquidationPrice = mockLiquidation.getLiquidationPrice(
            defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
        );

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            0,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );
        vm.expectRevert(bytes4(keccak256("AccountNotLiquidatable()")));
        liquidation.liquidateSubAccount(liquidationStruct, true);
    }

    function test_Fail_LiquidatorIsLiquidatee() public {
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(2000e18, 100e18, false);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.perpPrice = 1900e18;
        testVars.spotPrice = 20000e18;
        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            0, // usdcSpotQuantity
            20e18, // wethSpotQuantity
            0, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPperpPrice
            0 // wbtcPerpPrice
        );

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 1e18;

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.alice),
            1,
            address(users.alice),
            1,
            0,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );
        vm.expectRevert(bytes4(keccak256("LiquidatorCanNotBeLiquidatee()")));
        liquidation.liquidateSubAccount(liquidationStruct, true);
    }

    function test_Fail_CallerNotOrderDispatch() public {
        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.alice), 1, address(users.alice), 1, 0, 101, 1e18, 0
        );
        vm.startPrank(users.hackerman);
        vm.expectRevert("UNAUTHORIZED");
        liquidation.liquidateSubAccount(liquidationStruct, true);
    }

    function test_Happy_LiquidateTooMuch() public {
        // should pass now the check is removed
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(2000e18, 10e18, true);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.perpPrice = 1970e18;
        testVars.spotPrice = 2000e18;
        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            1000e6, // usdcSpotQuantity
            0, // wethSpotQuantity
            0, // wbtcSpotQuantity
            2000e18, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPperpPrice
            0 // wbtcPerpPrice
        );

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 10e18;
        testVars.expectedLiquidationPrice = mockLiquidation.getLiquidationPrice(
            defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
        );

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );
        liquidation.liquidateSubAccount(liquidationStruct, true);
        testVars.liquidateeInitialHealthAfter = furnace.getSubAccountHealth(aliceSubAccount, true);
        assert(testVars.liquidateeInitialHealthAfter > 0);
    }

    function test_Happy_LiquidateTooMuchButRecentDeposit() public {
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(2000e18, 10e18, true);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.perpPrice = 1970e18;
        testVars.spotPrice = 2000e18;
        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            1000e6, // usdcSpotQuantity
            0, // wethSpotQuantity
            0, // wbtcSpotQuantity
            2000e18, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPperpPrice
            0 // wbtcPerpPrice
        );

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 9e18;
        testVars.expectedLiquidationPrice = mockLiquidation.getLiquidationPrice(
            defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
        );

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );
        liquidation.liquidateSubAccount(liquidationStruct, false);

        // ------ check state after liquidation ------

        Structs.PositionState memory alicePosAfter =
            perpCrucible.getSubAccountPosition(defaults.wethUsdcPerpProductId(), aliceSubAccount);

        Structs.PositionState memory larryPosAfter =
            perpCrucible.getSubAccountPosition(defaults.wethUsdcPerpProductId(), larrySubAccount);

        uint256 insuranceBalance = ciao.balances(ciao.insurance(), address(usdc));
        // check insurance contribution is right
        assertEq(
            insuranceBalance,
            uint256(testVars.liquidationQuantity).mul(
                (testVars.perpPrice - testVars.expectedLiquidationPrice).mul(
                    liquidation.liquidationFeeFraction()
                )
            )
        );

        testVars.liquidatorInitialHealthAfter = furnace.getSubAccountHealth(larrySubAccount, true);
        testVars.liquidateeInitialHealthAfter = furnace.getSubAccountHealth(aliceSubAccount, true);
        // larry's initial health should be above zero
        assert(testVars.liquidatorInitialHealthAfter > 0);
        // larry's health should be equal to initial usdc balance + perp health - fees paid to insurance
        assert(
            testVars.liquidatorInitialHealthAfter
                == int256(1000000e18) - int256(insuranceBalance)
                    + MarginDirective.getPerpMarginHealth(
                        true,
                        defaults.wethUsdcPerpRiskWeights(),
                        larryPosAfter.quantity,
                        larryPosAfter.avgEntryPrice,
                        testVars.ethPerpPos.isLong,
                        testVars.perpPrice,
                        0,
                        0
                    )
        );
        // alice's initialHealth should be above 0 (she has been over-liquidated)
        assert(testVars.liquidateeInitialHealthAfter > 0);
        // alice's initialHealth should have increased
        assert(testVars.liquidateeInitialHealthAfter > testVars.liquidateeInitialHealthBefore);
        // larrys avg entry price should be equal to the liquidation price
        assert(
            larryPosAfter.avgEntryPrice
                == mockLiquidation.getLiquidationPrice(
                    defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
                )
        );
        // alice's avg entry price should be unchanged
        assert(alicePosAfter.avgEntryPrice == testVars.ethPerpPos.executionPrice);
        // larry's pos size should be the liquidation quantity
        assert(larryPosAfter.quantity == testVars.liquidationQuantity);
        // larry's pos should be in same direction as alice's initial pos
        assert(larryPosAfter.isLong == testVars.ethPerpPos.isLong);
        // alice's pos size should be her initial pos size - liquidation quantity
        assert(
            alicePosAfter.quantity == testVars.ethPerpPos.quantity - testVars.liquidationQuantity
        );
        // alice's usdc holdings should have decreased by size * (entry price- liq price)
        assertEq(
            ciao.balances(aliceSubAccount, address(usdc)),
            1000e18
                - uint256(testVars.liquidationQuantity).mul(
                    testVars.ethPerpPos.executionPrice - testVars.expectedLiquidationPrice
                )
        );
    }

    function test_Fail_LiquidatorInsufficientHealth() public {
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(2000e18, 10e18, true);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.perpPrice = 1970e18;
        testVars.spotPrice = 2000e18;
        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            1000e6, // usdcSpotQuantity
            0, // wethSpotQuantity
            0, // wbtcSpotQuantity
            2000e18, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPperpPrice
            0 // wbtcPerpPrice
        );

        _depositLarrySpot(10e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 1e18;
        testVars.expectedLiquidationPrice = mockLiquidation.getLiquidationPrice(
            defaults.wethUsdcPerpProductId(), testVars.perpPrice, testVars.ethPerpPos.isLong
        );

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );
        vm.expectRevert(bytes4(keccak256("LiquidatorBelowInitialHealth()")));
        liquidation.liquidateSubAccount(liquidationStruct, true);
    }

    function test_Fail_LiquidateCoreCollateral() public {
        // First we need to have the liquidatee incur debt
        ciao.settleCoreCollateral(aliceSubAccount, -10000e18);
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.perpPrice = 1970e18;
        testVars.spotPrice = 2000e18;
        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            1000e6, // usdcSpotQuantity
            0, // wethSpotQuantity
            0, // wbtcSpotQuantity
            0, // wethSpotPrice
            0, // wbtcSpotPrice
            0, // wethPperpPrice
            0 // wbtcPerpPrice
        );

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 1e18;

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            1,
            defaults.usdcProductId(),
            testVars.liquidationQuantity,
            0
        );
        vm.expectRevert(bytes4(keccak256("CanNotLiquidateCoreCollateral()")));
        liquidation.liquidateSubAccount(liquidationStruct, true);
    }

    function test_Fail_LiquidateAssetWithNoExistingPosition() public {
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(5000e18, 10e18, true);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.perpPrice = 1970e18;
        testVars.spotPrice = 2000e18;
        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            1000e6, // usdcSpotQuantity
            10e18, // wethSpotQuantity
            0, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPerpPrice
            0 // wbtcPerpPrice
        );

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 1e18;

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            2,
            defaults.wbtcUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );
        vm.expectRevert(bytes4(keccak256("NoPositionExistsForId()")));
        liquidation.liquidateSubAccount(liquidationStruct, true);
    }

    function test_Fail_LiquidateSpotAssetWithInvalidProductID() public {
        // First we need to have the liquidatee incur debt
        ciao.settleCoreCollateral(aliceSubAccount, -10000e18);
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.spotPrice = 2000e18;
        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            1000e6, // usdcSpotQuantity
            1e18, // wethSpotQuantity
            0, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            0, // wbtcSpotPrice
            0, // wethPerpPrice
            0 // wbtcPerpPrice
        );

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 1e18;

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            1,
            defaults.wbtcUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );
        vm.expectRevert(bytes4(keccak256("NoPositionExistsForId()")));
        liquidation.liquidateSubAccount(liquidationStruct, true);
    }

    function test_Fail_LiquidatePerpQuantityMoreThanPosSize() public {
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(5000e18, 10e18, true);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.spotPrice = 2000e18;
        testVars.perpPrice = 2000e18;
        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            1000e6, // usdcSpotQuantity
            1e18, // wethSpotQuantity
            0, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPerpPrice
            0 // wbtcPerpPrice
        );

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 11e18;

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );
        vm.expectRevert(bytes4(keccak256("InvalidLiquidationSize()")));
        liquidation.liquidateSubAccount(liquidationStruct, true);
    }

    function test_Fail_LiquidatePerpLiquidationSizeIsZero() public {
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(5000e18, 10e18, true);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.spotPrice = 2000e18;
        testVars.perpPrice = 2000e18;
        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            1000e6, // usdcSpotQuantity
            1e18, // wethSpotQuantity
            0, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPerpPrice
            0 // wbtcPerpPrice
        );

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 0;

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            2,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );
        vm.expectRevert(bytes4(keccak256("InvalidLiquidationSize()")));
        liquidation.liquidateSubAccount(liquidationStruct, true);
    }

    function test_Fail_LiquidateSpreadWhenPerpPartIsLong() public {
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(5000e18, 10e18, true);
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.spotPrice = 2000e18;
        testVars.perpPrice = 2000e18;
        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            1000e6, // usdcSpotQuantity
            1e18, // wethSpotQuantity
            0, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            0, // wbtcSpotPrice
            testVars.perpPrice, // wethPerpPrice
            0 // wbtcPerpPrice
        );

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 0;

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            0,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );
        vm.expectRevert(bytes4(keccak256("LiquidateNakedPerpsFirst()")));
        liquidation.liquidateSubAccount(liquidationStruct, true);
    }

    function test_Fail_LiquidateSpreadWithNoPerpSideOpen() public {
        // First we need to have the liquidatee incur debt
        ciao.settleCoreCollateral(aliceSubAccount, -10000e18);
        TestVars memory testVars;
        testVars.liquidator = larrySubAccount;
        testVars.liquidatee = aliceSubAccount;
        testVars.ethPerpPos = Structs.NewPosition(0, 0, true); // no pos
        testVars.btcPerpPos = Structs.NewPosition(0, 0, true); // no pos

        setAlicePositions(
            0, // wbtcCumFunding
            0, // wethCumFunding
            testVars.ethPerpPos,
            testVars.btcPerpPos,
            0, // usdcSpotQuantity
            20e18, // wethSpotQuantity
            0, // wbtcSpotQuantity
            testVars.spotPrice, // wethSpotPrice
            0, // wbtcSpotPrice
            0, // wethPperpPrice
            0 // wbtcPerpPrice
        );

        _depositLarrySpot(1_000_000e6, 0, 0);

        // ------ start liquidation ------
        vm.startPrank(users.gov);

        testVars.liquidationQuantity = 1e18;

        Structs.LiquidateSubAccount memory liquidationStruct = Structs.LiquidateSubAccount(
            address(users.larry),
            2,
            address(users.alice),
            1,
            0,
            defaults.wethUsdcPerpProductId(),
            testVars.liquidationQuantity,
            0
        );
        vm.expectRevert(bytes4(keccak256("NoPositionExistsForId()")));
        liquidation.liquidateSubAccount(liquidationStruct, true);
    }

    function test_Happy_setLiquidationFeeFraction() public {
        uint256 fraction = 5e17;

        vm.expectEmit(address(liquidation));
        emit Events.LiquidationFeeFractionSet(fraction);

        liquidation.setLiquidationFeeFraction(fraction);

        assertEq(liquidation.liquidationFeeFraction(), fraction);
    }

    function test_Fail_setLiquidationFeeFractionInvalidValue() public {
        uint256 fraction = 15e17;

        vm.expectRevert(bytes4(keccak256("InvalidLiquidateFeeFractionValue()")));

        liquidation.setLiquidationFeeFraction(fraction);
    }

    function test_Happy_setLiqPriceNumerator() public {
        uint256 numerator = 69e17;

        vm.expectEmit(address(liquidation));
        emit Events.LiqPriceNumeratorSet(numerator);
        liquidation.setLiqPriceNumerator(numerator);

        assertEq(liquidation.liqPriceNumerator(), numerator);
    }

    function test_Happy_setLiqPriceDenominator() public {
        uint256 denominator = 69e17;

        vm.expectEmit(address(liquidation));
        emit Events.LiqPriceDenominatorSet(denominator);
        liquidation.setLiqPriceDenominator(denominator);

        assertEq(liquidation.liqPriceDenominator(), denominator);
    }

    function test_Happy_setLiquidationHealthBuffer() public {
        vm.expectEmit(address(liquidation));
        emit Events.LiquidationHealthBufferSet(1000e18);
        liquidation.setLiquidationHealthBuffer(1000e18);
        assertEq(liquidation.liquidationHealthBuffer(), 1000e18);
    }

    function test_Fail_setLiquidationHealthBufferUnauth() public {
        vm.startPrank(users.hackerman);
        vm.expectRevert("UNAUTHORIZED");
        liquidation.setLiquidationHealthBuffer(1000e18);
    }
}
