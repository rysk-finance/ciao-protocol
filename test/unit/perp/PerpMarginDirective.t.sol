// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MarginDirective} from "src/contracts/libraries/MarginDirective.sol";
import {Furnace} from "src/contracts/Furnace.sol";
import {Base_Test} from "../../Base.t.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";

contract MarginDirectiveTest is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        deployMarginDirective();
    }

    function test_Happy_getPerpMaintenanceMarginHealth() public {
        int256 health1 = marginDirective.getPerpMarginHealth(
            false, // maintenance
            defaults.assetRiskWeights(),
            defaults.profitableLong().quantity,
            defaults.profitableLong().avgEntryPrice,
            defaults.profitableLong().isLong,
            defaults.profitableLong().markPrice,
            defaults.profitableLong().initCumFunding,
            defaults.profitableLong().currentCumFunding
        );
        assertEq(health1, 797206160000000000000);

        int256 health2 = marginDirective.getPerpMarginHealth(
            false, // maintenance
            defaults.assetRiskWeights(),
            defaults.unprofitableLong().quantity,
            defaults.unprofitableLong().avgEntryPrice,
            defaults.unprofitableLong().isLong,
            defaults.unprofitableLong().markPrice,
            defaults.unprofitableLong().initCumFunding,
            defaults.unprofitableLong().currentCumFunding
        );
        assertEq(health2, -8631853385200000000000);

        int256 health3 = marginDirective.getPerpMarginHealth(
            false, // maintenance
            defaults.assetRiskWeights(),
            defaults.profitableShort().quantity,
            defaults.profitableShort().avgEntryPrice,
            defaults.profitableShort().isLong,
            defaults.profitableShort().markPrice,
            defaults.profitableShort().initCumFunding,
            defaults.profitableShort().currentCumFunding
        );
        assertEq(health3, 209033448700000000000);

        int256 health4 = marginDirective.getPerpMarginHealth(
            false, // maintenance
            defaults.assetRiskWeights(),
            defaults.unprofitableShort().quantity,
            defaults.unprofitableShort().avgEntryPrice,
            defaults.unprofitableShort().isLong,
            defaults.unprofitableShort().markPrice,
            defaults.unprofitableShort().initCumFunding,
            defaults.unprofitableShort().currentCumFunding
        );
        assertEq(health4, -6131250958800000000000);
    }

    function test_Happy_getPerpInitialMarginHealth() public {
        int256 health1 = marginDirective.getPerpMarginHealth(
            true, // initial
            defaults.assetRiskWeights(),
            defaults.initialLong().quantity,
            defaults.initialLong().avgEntryPrice,
            defaults.initialLong().isLong,
            defaults.initialLong().markPrice,
            0,
            0
        );
        assertEq(health1, -140384424630000000000000);

        int256 health2 = marginDirective.getPerpMarginHealth(
            true,
            defaults.assetRiskWeights(),
            defaults.initialShort().quantity,
            defaults.initialShort().avgEntryPrice,
            defaults.initialShort().isLong,
            defaults.initialShort().markPrice,
            0,
            0
        );
        assertEq(health2, -139731145440000000000000);
    }

    function test_Happy_getPerpPayoff() public {
        int256 health1 = getPerpPayoff(
            defaults.profitableLong().quantity,
            defaults.profitableLong().avgEntryPrice,
            defaults.profitableLong().isLong,
            defaults.profitableLong().markPrice,
            defaults.profitableLong().initCumFunding,
            defaults.profitableLong().currentCumFunding
        );
        assertEq(health1, 2538641960000000000000);

        int256 health2 = getPerpPayoff(
            defaults.unprofitableLong().quantity,
            defaults.unprofitableLong().avgEntryPrice,
            defaults.unprofitableLong().isLong,
            defaults.unprofitableLong().markPrice,
            defaults.unprofitableLong().initCumFunding,
            defaults.unprofitableLong().currentCumFunding
        );
        assertEq(health2, -3601044305200000000000);

        int256 health3 = getPerpPayoff(
            defaults.profitableShort().quantity,
            defaults.profitableShort().avgEntryPrice,
            defaults.profitableShort().isLong,
            defaults.profitableShort().markPrice,
            defaults.profitableShort().initCumFunding,
            defaults.profitableShort().currentCumFunding
        );
        assertEq(health3, 244036218700000000000);

        int256 health4 = getPerpPayoff(
            defaults.unprofitableShort().quantity,
            defaults.unprofitableShort().avgEntryPrice,
            defaults.unprofitableShort().isLong,
            defaults.unprofitableShort().markPrice,
            defaults.unprofitableShort().initCumFunding,
            defaults.unprofitableShort().currentCumFunding
        );
        assertEq(health4, -46814254800000000000);
    }
}
