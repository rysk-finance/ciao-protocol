// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/contracts/libraries/Commons.sol";

import {MarginDirective} from "src/contracts/libraries/MarginDirective.sol";
import {Furnace} from "src/contracts/Furnace.sol";
import {Base_Test} from "../../Base.t.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";

contract MarginDirectiveFuzzTest is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        deployMarginDirective();
    }

    function testFuzz_Happy_getPerpMaintenanceMarginHealth(
        Structs.ProductRiskWeights calldata productRiskWeights,
        uint96 quantity,
        uint96 avgEntryPrice,
        bool isLong,
        uint96 markPrice,
        int40 initCumFunding,
        int40 currentCumFunding
    ) public view {
        vm.assume(productRiskWeights.initialLongWeight < 2e18);
        vm.assume(productRiskWeights.initialShortWeight < 2e18);
        vm.assume(productRiskWeights.maintenanceLongWeight < 2e18);
        vm.assume(productRiskWeights.maintenanceShortWeight < 2e18);
        marginDirective.getPerpMarginHealth(
            false, // maintenance
            productRiskWeights,
            quantity,
            avgEntryPrice,
            isLong,
            markPrice,
            initCumFunding,
            currentCumFunding
        );
    }

    function testFuzz_Happy_getPerpInitialMarginHealth(
        Structs.ProductRiskWeights calldata productRiskWeights,
        uint96 quantity,
        uint96 avgEntryPrice,
        bool isLong,
        uint96 markPrice
    ) public view {
        vm.assume(productRiskWeights.initialLongWeight < 2e18);
        vm.assume(productRiskWeights.initialShortWeight < 2e18);
        vm.assume(productRiskWeights.maintenanceLongWeight < 2e18);
        vm.assume(productRiskWeights.maintenanceShortWeight < 2e18);
        marginDirective.getPerpMarginHealth(
            true, // initial
            productRiskWeights,
            quantity,
            avgEntryPrice,
            isLong,
            markPrice,
            0,
            0
        );
    }

    function testFuzz_Happy_getPerpPayoff(
        uint96 quantity,
        uint96 avgEntryPrice,
        bool isLong,
        uint96 markPrice,
        int40 initCumFunding,
        int40 currentCumFunding
    ) public view {
        getPerpPayoff(quantity, avgEntryPrice, isLong, markPrice, initCumFunding, currentCumFunding);
    }
}
