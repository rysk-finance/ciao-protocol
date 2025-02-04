// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Furnace} from "src/contracts/Furnace.sol";
import {PerpCrucible} from "src/contracts/crucible/perp-crucible/PerpCrucible.sol";
import {Commons} from "src/contracts/libraries/Commons.sol";
import {Base_Test} from "../../Base.t.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";

contract FurnaceSubaccountHealthTestFuzz is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        deployCiao();
    }

    function testFuzz_Happy_calculateSubaccountHealth(
        Structs.NewPosition memory ethPerpPos,
        Structs.NewPosition memory btcPerpPos,
        uint88 usdcSpotQuantity,
        uint128 wethSpotQuantity,
        uint96 wbtcSpotQuantity,
        uint128 wethSpotPrice,
        uint96 wbtcSpotPrice,
        uint128 wethUsdcPerpPrice,
        uint128 wbtcUsdcPerpPrice,
        int80 wbtcCumFunding,
        int80 wethCumFunding
    ) public {
        validateAssets();

        vm.assume(ethPerpPos.executionPrice < 10000000000000000e18);
        vm.assume(ethPerpPos.quantity < 10000000000000000e18);
        vm.assume(btcPerpPos.quantity < 10000000000000000e18);

        vm.assume(btcPerpPos.executionPrice < 10000000000000000e18);

        setAlicePositions(
            wbtcCumFunding,
            wethCumFunding,
            ethPerpPos,
            btcPerpPos,
            usdcSpotQuantity,
            wethSpotQuantity,
            wbtcSpotQuantity,
            wethSpotPrice,
            wbtcSpotPrice,
            wethUsdcPerpPrice,
            wbtcUsdcPerpPrice
        );

        int256 maintenance =
            furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), false);

        int256 initial = furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), true);

        assertEq(furnace.prices(defaults.wbtcProductId()), wbtcSpotPrice);
        assertEq(furnace.prices(defaults.wethProductId()), wethSpotPrice);
        assertEq(furnace.prices(defaults.wbtcUsdcPerpProductId()), wbtcUsdcPerpPrice);
        assertEq(furnace.prices(defaults.wethUsdcPerpProductId()), wethUsdcPerpPrice);
        assertEq(perpCrucible.currentCumFunding(defaults.wbtcUsdcPerpProductId()), wbtcCumFunding);
        assertEq(perpCrucible.currentCumFunding(defaults.wethUsdcPerpProductId()), wethCumFunding);

        assertEq(
            ciao.balances(Commons.getSubAccount(users.alice, 1), address(usdc)),
            Commons.convertToE18(uint256(usdcSpotQuantity), usdc.decimals())
        );

        assertEq(
            ciao.balances(Commons.getSubAccount(users.alice, 1), address(wbtc)),
            Commons.convertToE18(uint256(wbtcSpotQuantity), wbtc.decimals())
        );
        assertEq(
            ciao.balances(Commons.getSubAccount(users.alice, 1), address(weth)), wethSpotQuantity
        );

        assertGe(maintenance, initial);
    }
}
