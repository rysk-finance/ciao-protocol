// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Furnace} from "src/contracts/Furnace.sol";
import {PerpCrucible} from "src/contracts/crucible/perp-crucible/PerpCrucible.sol";
import {Commons} from "src/contracts/libraries/Commons.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";
import {OrderDispatchBase} from "../unit/orderDispatch/OrderDispatchBase.t.sol";

contract FurnaceSubaccountHealthTest is OrderDispatchBase {
    function setUp() public virtual override {
        OrderDispatchBase.setUp();
        deployOrderDispatch();
        furnace.setSpotRiskWeight(address(weth), Structs.ProductRiskWeights(0, 0, 0, 0));
        furnace.setSpreadPenalty(address(weth), 1e18, 1e18);
    }

    function test_Happy_calculateSubaccountHealth_withdrawal_no_debt() public {
        addressManifest.updateAddressInManifest(4, users.gov);
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
        addressManifest.updateAddressInManifest(4, address(orderDispatch));
        constructWithdrawPayload(users.alice, 1, address(usdc), 50000e6, "alice");
        orderDispatch.ingresso(transaction);

        int256 maintenance =
            furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), false);
        int256 initial = furnace.getSubAccountHealth(Commons.getSubAccount(users.alice, 1), true);

        assertEq(maintenance, 59113200e15);
        assertEq(initial, 55475700e15);
    }
}
