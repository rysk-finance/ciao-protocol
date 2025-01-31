// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MockFurnaceUnitTest} from "../../mocks/MockFurnaceUnitTest.sol";
import {Base_Test} from "../../Base.t.sol";
import "src/contracts/libraries/BasicMath.sol";

contract FurnaceHealthUnitCalcsTestFuzz is Base_Test {
    using BasicMath for int256;
    using BasicMath for uint256;

    function setUp() public virtual override {
        Base_Test.setUp();
        deployMockFurnaceUnitTest();
    }

    function testFuzz_Happy_calculateInitialSpreadHealthBtc(
        uint120 quantity,
        uint120 spotPrice,
        uint120 perpPrice,
        uint120 perpEntryPrice,
        int88 initCumFunding,
        int88 currentCumFunding
    ) public view {
        vm.assume(quantity < 10000000000000000e18);
        vm.assume(spotPrice < 10000000000000000e18);
        vm.assume(uint256(quantity).mul(uint256(perpEntryPrice)) < 10000000000000000e18);
        vm.assume(perpPrice < 10000000000000000e18);
        vm.assume(perpEntryPrice < 10000000000000000e18);
        vm.assume(
            int256(initCumFunding) < 10000000000000000e18
                && int256(initCumFunding) > -10000000000000000e18
        );
        vm.assume(
            int256(currentCumFunding) < 10000000000000000e18
                && int256(currentCumFunding) > -10000000000000000e18
        );
        vm.assume(abs(int256(initCumFunding) - int256(currentCumFunding)) < 100000e18);

        mockFurnaceUnitTest.calculateSpreadHealth(
            defaults.wbtcSpreadPenalty().initial, // initial
            quantity,
            spotPrice, // $3200.00 spot price
            perpPrice, // $3201.00 perp price,
            perpEntryPrice, // $3000.00 perp entry price
            initCumFunding,
            currentCumFunding
        );
    }

    function testFuzz_Happy_calculateInitialSpreadHealthWeth(
        uint120 quantity,
        uint120 spotPrice,
        uint120 perpPrice,
        uint120 perpEntryPrice,
        int88 initCumFunding,
        int88 currentCumFunding
    ) public view {
        vm.assume(quantity < 10000000000000000e18);
        vm.assume(quantity < 10000000000000000e18);
        vm.assume(spotPrice < 10000000000000000e18);
        vm.assume(uint256(quantity).mul(uint256(perpEntryPrice)) < 10000000000000000e18);
        vm.assume(perpPrice < 10000000000000000e18);
        vm.assume(perpEntryPrice < 10000000000000000e18);
        vm.assume(
            int256(initCumFunding) < 10000000000000000e18
                && int256(initCumFunding) > -10000000000000000e18
        );
        vm.assume(
            int256(currentCumFunding) < 10000000000000000e18
                && int256(currentCumFunding) > -10000000000000000e18
        );
        vm.assume(abs(int256(initCumFunding) - int256(currentCumFunding)) < 100000e18);

        mockFurnaceUnitTest.calculateSpreadHealth(
            defaults.wethSpreadPenalty().initial, // initial
            quantity,
            spotPrice, // $3200.00 spot price
            perpPrice, // $3201.00 perp price,
            perpEntryPrice, // $3000.00 perp entry price
            initCumFunding,
            currentCumFunding
        );
    }

    function testFuzz_Happy_calculateMaintenanceSpreadHealthBtc(
        uint120 quantity,
        uint120 spotPrice,
        uint120 perpPrice,
        uint120 perpEntryPrice,
        int88 initCumFunding,
        int88 currentCumFunding
    ) public view {
        vm.assume(quantity < 10000000000000000e18);
        vm.assume(quantity < 10000000000000000e18);
        vm.assume(spotPrice < 10000000000000000e18);
        vm.assume(uint256(quantity).mul(uint256(perpEntryPrice)) < 10000000000000000e18);
        vm.assume(perpPrice < 10000000000000000e18);
        vm.assume(perpEntryPrice < 10000000000000000e18);
        vm.assume(
            int256(initCumFunding) < 10000000000000000e18
                && int256(initCumFunding) > -10000000000000000e18
        );
        vm.assume(
            int256(currentCumFunding) < 10000000000000000e18
                && int256(currentCumFunding) > -10000000000000000e18
        );
        vm.assume(abs(int256(initCumFunding) - int256(currentCumFunding)) < 100000e18);

        mockFurnaceUnitTest.calculateSpreadHealth(
            defaults.wbtcSpreadPenalty().maintenance, // maintenance
            quantity,
            spotPrice, // $3200.00 spot price
            perpPrice, // $3201.00 perp price,
            perpEntryPrice, // $3000.00 perp entry price
            initCumFunding,
            currentCumFunding
        );
    }

    function testFuzz_Happy_calculateMaintenanceSpreadHealthWeth(
        uint120 quantity,
        uint120 spotPrice,
        uint120 perpPrice,
        uint120 perpEntryPrice,
        int88 initCumFunding,
        int88 currentCumFunding
    ) public view {
        vm.assume(quantity < 10000000000000000e18);
        vm.assume(quantity < 10000000000000000e18);
        vm.assume(spotPrice < 10000000000000000e18);
        vm.assume(uint256(quantity).mul(uint256(perpEntryPrice)) < 10000000000000000e18);
        vm.assume(perpPrice < 10000000000000000e18);
        vm.assume(perpEntryPrice < 10000000000000000e18);
        vm.assume(
            int256(initCumFunding) < 10000000000000000e18
                && int256(initCumFunding) > -10000000000000000e18
        );
        vm.assume(
            int256(currentCumFunding) < 10000000000000000e18
                && int256(currentCumFunding) > -10000000000000000e18
        );
        vm.assume(abs(int256(initCumFunding) - int256(currentCumFunding)) < 100000e18);

        mockFurnaceUnitTest.calculateSpreadHealth(
            defaults.wethSpreadPenalty().maintenance, // maintenance
            quantity,
            spotPrice, // $3200.00 spot price
            perpPrice, // $3201.00 perp price,
            perpEntryPrice, // $3000.00 perp entry price
            initCumFunding,
            currentCumFunding
        );
    }
}
