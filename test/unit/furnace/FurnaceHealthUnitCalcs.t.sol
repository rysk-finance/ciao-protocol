// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MockFurnaceUnitTest} from "../../mocks/MockFurnaceUnitTest.sol";
import {Base_Test} from "../../Base.t.sol";

contract FurnaceHealthUnitCalcsTest is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        deployMockFurnaceUnitTest();
    }

    function test_Happy_calculateInitialSpreadHealth() public {
        int256 health1 = mockFurnaceUnitTest.calculateSpreadHealth(
            defaults.wbtcSpreadPenalty().initial, // initial
            314e17,
            3531099e16, // $35310.99 spot price
            3525881e16, // $35258.81 perp price,
            3814323e16, // $38143.23 perp entry price
            defaults.profitableLong().initCumFunding,
            defaults.profitableLong().currentCumFunding
        );
        assertEq(health1, 1177177084284000000000000);

        int256 health2 = mockFurnaceUnitTest.calculateSpreadHealth(
            defaults.wbtcSpreadPenalty().initial, // initial
            885e15,
            9328969e16, // $93289.69 spot price
            9333903e16, // $93339.03 perp price,
            7998711e16, // $79987.11 perp entry price
            defaults.unprofitableLong().initCumFunding,
            defaults.unprofitableLong().currentCumFunding
        );

        assertEq(health2, 69093263879850000000000);

        int256 health3 = mockFurnaceUnitTest.calculateSpreadHealth(
            defaults.wethSpreadPenalty().initial, // initial
            1e18,
            3200e18, // $3200.00 spot price
            3201e18, // $3201.00 perp price,
            3000e18, // $3000.00 perp entry price
            defaults.unprofitableLong().initCumFunding,
            defaults.unprofitableLong().currentCumFunding
        );

        assertEq(health3, 2902986810000000000000);

        int256 health4 = mockFurnaceUnitTest.calculateSpreadHealth(
            defaults.wethSpreadPenalty().initial, // initial
            168723e16,
            592013e16, // $5920.13 spot price
            590241e16, // $5902.41 perp price,
            599212e16, // $5992.12 perp entry price
            defaults.unprofitableShort().initCumFunding,
            defaults.unprofitableShort().currentCumFunding
        );

        assertEq(health4, 9840727992183300000000000);
    }

    function test_Happy_calculateMaintenanceSpreadHealth() public {
        int256 health1 = mockFurnaceUnitTest.calculateSpreadHealth(
            defaults.wbtcSpreadPenalty().maintenance, // maintenance
            314e17,
            3531099e16, // $35310.99 spot price
            3525881e16, // $35258.81 perp price,
            3814323e16, // $38143.23 perp entry price
            defaults.profitableLong().initCumFunding,
            defaults.profitableLong().currentCumFunding
        );
        assertEq(health1, 1188256542884000000000000);

        int256 health2 = mockFurnaceUnitTest.calculateSpreadHealth(
            defaults.wbtcSpreadPenalty().maintenance, // maintenance
            885e15,
            9328969e16, // $93289.69 spot price
            9333903e16, // $93339.03 perp price,
            7998711e16, // $79987.11 perp entry price
            defaults.unprofitableLong().initCumFunding,
            defaults.unprofitableLong().currentCumFunding
        );

        assertEq(health2, 69919095965850000000000);

        int256 health3 = mockFurnaceUnitTest.calculateSpreadHealth(
            defaults.wethSpreadPenalty().maintenance, // maintenance
            1e18,
            3200e18, // $3200.00 spot price
            3201e18, // $3201.00 perp price,
            3000e18, // $3000.00 perp entry price
            defaults.unprofitableLong().initCumFunding,
            defaults.unprofitableLong().currentCumFunding
        );

        assertEq(health3, 2950994310000000000000);

        int256 health4 = mockFurnaceUnitTest.calculateSpreadHealth(
            defaults.wethSpreadPenalty().maintenance, // maintenance
            168723e16,
            592013e16, // $5920.13 spot price
            590241e16, // $5902.41 perp price,
            599212e16, // $5992.12 perp entry price
            defaults.unprofitableShort().initCumFunding,
            defaults.unprofitableShort().currentCumFunding
        );

        assertEq(health4, 9990333073414800000000000);
    }

    function test_Happy_calculateSpotHealth() public {
        int256 health1 = mockFurnaceUnitTest.calculateSpotHealth(
            defaults.wbtcRiskWeights().initialLongWeight, // initial
            314e17,
            3531099e16 // $35310.99 spot price
        );
        assertEq(health1, 887012068800000000000000);

        int256 health2 = mockFurnaceUnitTest.calculateSpotHealth(
            defaults.wethRiskWeights().initialLongWeight, // initial
            10000e16,
            1000000e16 // $10000.00 spot price
        );
        assertEq(health2, 800000000000000000000000);

        int256 health3 = mockFurnaceUnitTest.calculateSpotHealth(
            defaults.wbtcRiskWeights().maintenanceLongWeight, // maintenance
            51702e16,
            13501902e16 // $135019.02 spot price
        );
        assertEq(health3, 62826780348360000000000000);

        int256 health4 = mockFurnaceUnitTest.calculateSpotHealth(
            defaults.wethRiskWeights().maintenanceLongWeight, // maintenance
            10000e16,
            1000000e16 // $10000.00 spot price
        );
        assertEq(health4, 900000000000000000000000);
    }
}
