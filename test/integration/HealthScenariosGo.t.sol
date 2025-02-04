// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Furnace} from "src/contracts/Furnace.sol";
import {PerpCrucible} from "src/contracts/crucible/perp-crucible/PerpCrucible.sol";
import {Commons} from "src/contracts/libraries/Commons.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";
import {Base_Test} from "../Base.t.sol";

contract FurnaceSubaccountHealthTest is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        deployCiao();
    }

    function test_Happy_calculateSubaccountHealth_Only_Spot() public {
        validateAssets();
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(0, 0, false);
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(0, 0, false);
        uint256 usdcSpotQuantity = 10000e6;
        uint256 wethSpotQuantity = 0;
        uint256 wbtcSpotQuantity = 0;
        uint256 wethSpotPrice = 2100e18;
        uint256 wbtcSpotPrice = 29650e18;
        uint256 wethUsdcPerpPrice = 2150e18;
        uint256 wbtcUsdcPerpPrice = 29700e18;
        int256 wbtcCumFunding = -20e18;
        int256 wethCumFunding = 50e18;

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
        ciao.settleCoreCollateral(Commons.getSubAccount(users.alice, 1), 0e18);
        // update funding snapshots
        uint32[] memory perpIds = new uint32[](2);
        perpIds[0] = defaults.wbtcUsdcPerpProductId();
        perpIds[1] = defaults.wethUsdcPerpProductId();
        int256[] memory cumFundings = new int256[](2);
        cumFundings[0] = -1e17;
        cumFundings[1] = -1e17;
        bytes memory payload =
            abi.encodePacked(perpIds[0], cumFundings[0], perpIds[1], cumFundings[1]);
        perpCrucible.updateCumulativeFundings(payload);

        int256 maintenance =
            furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), false);
        int256 initial = furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), true);

        assertEq(maintenance, 10000e18);
        assertEq(initial, 10000e18);
    }

    function test_Happy_calculateSubaccountHealth_only_eth_perp_long_profit() public {
        validateAssets();
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(2000e18, 5e18, true);
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(0e18, 0e18, false);
        uint256 usdcSpotQuantity = 10000e6;
        uint256 wethSpotQuantity = 0;
        uint256 wbtcSpotQuantity = 0;
        uint256 wethSpotPrice = 2100e18;
        uint256 wbtcSpotPrice = 29650e18;
        uint256 wethUsdcPerpPrice = 2150e18;
        uint256 wbtcUsdcPerpPrice = 29700e18;
        int256 wbtcCumFunding = -20e18;
        int256 wethCumFunding = 50e18;

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
        ciao.settleCoreCollateral(Commons.getSubAccount(users.alice, 1), 0e18);
        // update funding snapshots
        uint32[] memory perpIds = new uint32[](2);
        perpIds[0] = defaults.wbtcUsdcPerpProductId();
        perpIds[1] = defaults.wethUsdcPerpProductId();
        int256[] memory cumFundings = new int256[](2);
        cumFundings[0] = -1e17;
        cumFundings[1] = -1e17;
        bytes memory payload =
            abi.encodePacked(perpIds[0], cumFundings[0], perpIds[1], cumFundings[1]);
        perpCrucible.updateCumulativeFundings(payload);

        int256 maintenance =
            furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), false);
        int256 initial = furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), true);

        assertEq(maintenance, 10213e18);
        assertEq(initial, 9675500e15);
    }

    function test_Happy_calculateSubaccountHealth_only_eth_perp_long_loss() public {
        validateAssets();
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(2000e18, 5e18, true);
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(0e18, 0e18, false);
        uint256 usdcSpotQuantity = 10000e6;
        uint256 wethSpotQuantity = 0;
        uint256 wbtcSpotQuantity = 0;
        uint256 wethSpotPrice = 2100e18;
        uint256 wbtcSpotPrice = 29650e18;
        uint256 wethUsdcPerpPrice = 1900e18;
        uint256 wbtcUsdcPerpPrice = 29700e18;
        int256 wbtcCumFunding = -20e18;
        int256 wethCumFunding = 50e18;

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
        ciao.settleCoreCollateral(Commons.getSubAccount(users.alice, 1), 0e18);
        // update funding snapshots
        uint32[] memory perpIds = new uint32[](2);
        perpIds[0] = defaults.wbtcUsdcPerpProductId();
        perpIds[1] = defaults.wethUsdcPerpProductId();
        int256[] memory cumFundings = new int256[](2);
        cumFundings[0] = -1e17;
        cumFundings[1] = -1e17;
        bytes memory payload =
            abi.encodePacked(perpIds[0], cumFundings[0], perpIds[1], cumFundings[1]);
        perpCrucible.updateCumulativeFundings(payload);

        int256 maintenance =
            furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), false);
        int256 initial = furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), true);

        assertEq(maintenance, 9025500e15);
        assertEq(initial, 8550500e15);
    }

    function test_Happy_calculateSubaccountHealth_only_eth_perp_short_profit() public {
        validateAssets();
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(2000e18, 5e18, false);
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(0e18, 0e18, false);
        uint256 usdcSpotQuantity = 10000e6;
        uint256 wethSpotQuantity = 0;
        uint256 wbtcSpotQuantity = 0;
        uint256 wethSpotPrice = 2100e18;
        uint256 wbtcSpotPrice = 29650e18;
        uint256 wethUsdcPerpPrice = 1900e18;
        uint256 wbtcUsdcPerpPrice = 29700e18;
        int256 wbtcCumFunding = -20e18;
        int256 wethCumFunding = 50e18;

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
        ciao.settleCoreCollateral(Commons.getSubAccount(users.alice, 1), 0e18);
        // update funding snapshots
        uint32[] memory perpIds = new uint32[](2);
        perpIds[0] = defaults.wbtcUsdcPerpProductId();
        perpIds[1] = defaults.wethUsdcPerpProductId();
        int256[] memory cumFundings = new int256[](2);
        cumFundings[0] = -1e17;
        cumFundings[1] = -1e17;
        bytes memory payload =
            abi.encodePacked(perpIds[0], cumFundings[0], perpIds[1], cumFundings[1]);
        perpCrucible.updateCumulativeFundings(payload);

        int256 maintenance =
            furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), false);
        int256 initial = furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), true);

        assertEq(maintenance, 10024500e15);
        assertEq(initial, 9549500e15);
    }

    function test_Happy_calculateSubaccountHealth_only_eth_perp_short_loss() public {
        validateAssets();
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(2000e18, 5e18, false);
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(0e18, 0e18, false);
        uint256 usdcSpotQuantity = 10000e6;
        uint256 wethSpotQuantity = 0;
        uint256 wbtcSpotQuantity = 0;
        uint256 wethSpotPrice = 2100e18;
        uint256 wbtcSpotPrice = 29650e18;
        uint256 wethUsdcPerpPrice = 2150e18;
        uint256 wbtcUsdcPerpPrice = 29700e18;
        int256 wbtcCumFunding = -20e18;
        int256 wethCumFunding = 50e18;

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
        ciao.settleCoreCollateral(Commons.getSubAccount(users.alice, 1), 0e18);
        // update funding snapshots
        uint32[] memory perpIds = new uint32[](2);
        perpIds[0] = defaults.wbtcUsdcPerpProductId();
        perpIds[1] = defaults.wethUsdcPerpProductId();
        int256[] memory cumFundings = new int256[](2);
        cumFundings[0] = -1e17;
        cumFundings[1] = -1e17;
        bytes memory payload =
            abi.encodePacked(perpIds[0], cumFundings[0], perpIds[1], cumFundings[1]);
        perpCrucible.updateCumulativeFundings(payload);

        int256 maintenance =
            furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), false);
        int256 initial = furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), true);

        assertEq(maintenance, 8712e18);
        assertEq(initial, 8174500e15);
    }

    function test_Happy_calculateSubaccountHealth_only_eth_perp_long_profit_btc_profit() public {
        validateAssets();
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(2000e18, 5e18, true);
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(30000e18, 2e18, true);
        uint256 usdcSpotQuantity = 10000e6;
        uint256 wethSpotQuantity = 0;
        uint256 wbtcSpotQuantity = 0;
        uint256 wethSpotPrice = 2100e18;
        uint256 wbtcSpotPrice = 29650e18;
        uint256 wethUsdcPerpPrice = 2150e18;
        uint256 wbtcUsdcPerpPrice = 31000e18;
        int256 wbtcCumFunding = -20e18;
        int256 wethCumFunding = 50e18;

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
        ciao.settleCoreCollateral(Commons.getSubAccount(users.alice, 1), 0e18);
        // update funding snapshots
        uint32[] memory perpIds = new uint32[](2);
        perpIds[0] = defaults.wbtcUsdcPerpProductId();
        perpIds[1] = defaults.wethUsdcPerpProductId();
        int256[] memory cumFundings = new int256[](2);
        cumFundings[0] = -1e17;
        cumFundings[1] = -1e17;
        bytes memory payload =
            abi.encodePacked(perpIds[0], cumFundings[0], perpIds[1], cumFundings[1]);
        perpCrucible.updateCumulativeFundings(payload);

        int256 maintenance =
            furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), false);
        int256 initial = furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), true);

        assertEq(maintenance, 9113200e15);
        assertEq(initial, 5475700e15);
    }

    function test_Happy_calculateSubaccountHealth_only_eth_perp_long_profit_btc_loss() public {
        validateAssets();
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(2000e18, 5e18, true);
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(30000e18, 2e18, false);
        uint256 usdcSpotQuantity = 10000e6;
        uint256 wethSpotQuantity = 0;
        uint256 wbtcSpotQuantity = 0;
        uint256 wethSpotPrice = 2100e18;
        uint256 wbtcSpotPrice = 29650e18;
        uint256 wethUsdcPerpPrice = 2150e18;
        uint256 wbtcUsdcPerpPrice = 31000e18;
        int256 wbtcCumFunding = -20e18;
        int256 wethCumFunding = 50e18;

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
        ciao.settleCoreCollateral(Commons.getSubAccount(users.alice, 1), 0e18);
        // update funding snapshots
        uint32[] memory perpIds = new uint32[](2);
        perpIds[0] = defaults.wbtcUsdcPerpProductId();
        perpIds[1] = defaults.wethUsdcPerpProductId();
        int256[] memory cumFundings = new int256[](2);
        cumFundings[0] = -1e17;
        cumFundings[1] = -1e17;
        bytes memory payload =
            abi.encodePacked(perpIds[0], cumFundings[0], perpIds[1], cumFundings[1]);
        perpCrucible.updateCumulativeFundings(payload);

        int256 maintenance =
            furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), false);
        int256 initial = furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), true);

        assertEq(maintenance, 5112800e15);
        assertEq(initial, 1475300e15);
    }
}
