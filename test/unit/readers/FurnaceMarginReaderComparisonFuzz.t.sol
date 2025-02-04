// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Furnace} from "src/contracts/Furnace.sol";
import {PerpCrucible} from "src/contracts/crucible/perp-crucible/PerpCrucible.sol";
import {Commons} from "src/contracts/libraries/Commons.sol";
import {Base_Test} from "../../Base.t.sol";
import {MarginReader} from "src/contracts/readers/MarginReader.sol";
import {UserAndSystemStateReader} from "src/contracts/readers/UserAndSystemStateReader.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";

contract FurnaceSubaccountHealthTestFuzz is Base_Test {
    MarginReader public marginReader;
    UserAndSystemStateReader public userAndSystemStateReader;

    function setUp() public virtual override {
        Base_Test.setUp();
        deployCiao();
        marginReader = new MarginReader();
        userAndSystemStateReader = new UserAndSystemStateReader(
            address(addressManifest)
        );
    }

    function testFuzz_Happy_calculateSubaccountHealth(
        Structs.NewPosition memory ethPerpPos,
        Structs.NewPosition memory btcPerpPos,
        uint256 usdcSpotQuantity,
        uint256 wethSpotQuantity,
        uint256 wbtcSpotQuantity,
        uint256 wethSpotPrice,
        uint256 wbtcSpotPrice,
        uint256 wethUsdcPerpPrice,
        uint256 wbtcUsdcPerpPrice,
        int256 wbtcCumFunding,
        int256 wethCumFunding
    ) public {
        validateAssets();
        vm.assume(usdcSpotQuantity < 10000000000000000e18);
        vm.assume(wethSpotQuantity < 10000000000000000e18);
        vm.assume(wbtcSpotQuantity < 10000000000000000e8); // wbtc is e8
        vm.assume(ethPerpPos.executionPrice < 10000000000000000e18);
        vm.assume(ethPerpPos.quantity < 10000000000000000e18);
        vm.assume(btcPerpPos.quantity < 10000000000000000e18);

        vm.assume(btcPerpPos.executionPrice < 10000000000000000e18);

        vm.assume(wethSpotPrice < 10000000000000000e18);
        vm.assume(wbtcSpotPrice < 10000000000000000e18);
        vm.assume(wethUsdcPerpPrice < 10000000000000000e18);
        vm.assume(wbtcUsdcPerpPrice < 10000000000000000e18);
        vm.assume(
            wethCumFunding < 10000000000000000e18 &&
                wethCumFunding > -10000000000000000e18
        );
        vm.assume(
            wbtcCumFunding < 10000000000000000e18 &&
                wbtcCumFunding > -10000000000000000e18
        );

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

        int256 furnaceHealth = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            false
        );
        Structs.UserAndSystemState memory u = userAndSystemStateReader
            .acquireUserAndSystemState(Commons.getSubAccount(users.alice, 1));
        int256 marginReaderHealth = marginReader.getSubAccountMargin(false, u);
        assertEq(furnaceHealth, marginReaderHealth);
        assertEq(furnace.prices(defaults.wbtcProductId()), wbtcSpotPrice);
        assertEq(furnace.prices(defaults.wethProductId()), wethSpotPrice);
        assertEq(
            furnace.prices(defaults.wbtcUsdcPerpProductId()),
            wbtcUsdcPerpPrice
        );
        assertEq(
            furnace.prices(defaults.wethUsdcPerpProductId()),
            wethUsdcPerpPrice
        );
        assertEq(
            perpCrucible.currentCumFunding(defaults.wbtcUsdcPerpProductId()),
            wbtcCumFunding
        );
        assertEq(
            perpCrucible.currentCumFunding(defaults.wethUsdcPerpProductId()),
            wethCumFunding
        );

        assertEq(
            ciao.balances(Commons.getSubAccount(users.alice, 1), address(wbtc)),
            wbtcSpotQuantity * 1e10
        );
        assertEq(
            ciao.balances(Commons.getSubAccount(users.alice, 1), address(weth)),
            wethSpotQuantity
        );
    }
}
