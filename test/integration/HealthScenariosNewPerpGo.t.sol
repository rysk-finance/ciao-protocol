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
        furnace.setSpotRiskWeight(
            address(weth),
            Structs.ProductRiskWeights(0, 0, 0, 0)
        );
        furnace.setSpreadPenalty(address(weth), 1e18, 1e18);
        takerOrder = Structs.Order(
            users.dan,
            1,
            102,
            false,
            uint8(0),
            uint8(1),
            2,
            2150e18,
            10e18,
            1
        );
        makerOrder = Structs.Order(
            users.alice,
            1,
            102,
            true,
            uint8(0),
            uint8(1),
            2,
            2150e18,
            10e18,
            1
        );
        orderDispatch.setTxFees(0, 0);
    }

    function test_Happy_calculateSubaccountHealth_new_perp_pos_long() public {
        addressManifest.updateAddressInManifest(4, users.gov);
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            0,
            0,
            false
        );
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            0,
            0,
            false
        );
        uint256 usdcSpotQuantity = 0;
        uint256 wethSpotQuantity = 0;
        uint256 wbtcSpotQuantity = 0;
        uint256 wethSpotPrice = 2100e18;
        uint256 wbtcSpotPrice = 29650e18;
        uint256 wethUsdcPerpPrice = 2150e18;
        uint256 wbtcUsdcPerpPrice = 31000e18;
        int256 wbtcCumFunding = -20e18;
        int256 wethCumFunding = 50e18;

        setUserPositions(
            users.alice,
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
        bytes memory payload = abi.encodePacked(
            perpIds[0],
            cumFundings[0],
            perpIds[1],
            cumFundings[1]
        );
        perpCrucible.updateCumulativeFundings(payload);
        addressManifest.updateAddressInManifest(4, address(orderDispatch));
        constructMatchOrderPayload();
        orderDispatch.ingresso(transaction);

        int256 maintenance = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            false
        );
        int256 initial = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            true
        );

        assertEq(maintenance, 98931450000000000000000);
        assertEq(initial, 97856450000000000000000);

        maintenance = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.dan, 1),
            false
        );
        initial = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.dan, 1),
            true
        );

        assertEq(maintenance, 98914250000000000000000);
        assertEq(initial, 97839250000000000000000);
    }

    function test_Happy_calculateSubaccountHealth_new_perp_pos_long_nothing_prior()
        public
    {
        addressManifest.updateAddressInManifest(4, users.gov);
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            0,
            0,
            false
        );
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            0,
            0,
            false
        );
        uint256 usdcSpotQuantity = 0;
        uint256 wethSpotQuantity = 0;
        uint256 wbtcSpotQuantity = 0;
        uint256 wethSpotPrice = 2100e18;
        uint256 wbtcSpotPrice = 29650e18;
        uint256 wethUsdcPerpPrice = 2150e18;
        uint256 wbtcUsdcPerpPrice = 31000e18;
        int256 wbtcCumFunding = -20e18;
        int256 wethCumFunding = 50e18;

        setUserPositions(
            users.alice,
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
        bytes memory payload = abi.encodePacked(
            perpIds[0],
            cumFundings[0],
            perpIds[1],
            cumFundings[1]
        );
        perpCrucible.updateCumulativeFundings(payload);
        addressManifest.updateAddressInManifest(4, address(orderDispatch));
        constructWithdrawPayload(
            users.alice,
            1,
            address(usdc),
            defaults.usdcDepositQuantity(),
            "alice"
        );
        orderDispatch.ingresso(transaction);
        constructWithdrawPayload(
            users.dan,
            1,
            address(usdc),
            defaults.usdcDepositQuantity(),
            "dan"
        );
        orderDispatch.ingresso(transaction);
        constructMatchOrderPayload();
        orderDispatch.ingresso(transaction);

        int256 maintenance = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            false
        );
        int256 initial = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            true
        );

        assertEq(maintenance, -1068550000000000000000);
        assertEq(initial, -2143550000000000000000);

        maintenance = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.dan, 1),
            false
        );
        initial = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.dan, 1),
            true
        );
        assertEq(maintenance, -1085750000000000000000);
        assertEq(initial, -2160750000000000000000);
    }

    function test_Happy_calculateSubaccountHealth_leaks_core_collat_debt()
        public
    {
        addressManifest.updateAddressInManifest(4, users.gov);
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            0,
            0,
            false
        );
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            0,
            0,
            false
        );
        uint256 usdcSpotQuantity = 0;
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
        bytes memory payload = abi.encodePacked(
            perpIds[0],
            cumFundings[0],
            perpIds[1],
            cumFundings[1]
        );
        perpCrucible.updateCumulativeFundings(payload);
        addressManifest.updateAddressInManifest(4, address(orderDispatch));
        constructWithdrawPayload(
            users.dan,
            1,
            address(usdc),
            defaults.usdcDepositQuantity(),
            "dan"
        );
        orderDispatch.ingresso(transaction);

        constructMatchOrderPayload();
        orderDispatch.ingresso(transaction);

        int256 maintenance = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.dan, 1),
            false
        );
        int256 initial = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.dan, 1),
            true
        );

        assertEq(maintenance, -1085750000000000000000);
        assertEq(initial, -2160750000000000000000);
    }

    function test_Happy_calculateSubaccountHealth_perp_pos_long_again() public {
        addressManifest.updateAddressInManifest(4, users.gov);
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            2000e18,
            5e18,
            true
        );
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            0,
            0,
            false
        );
        uint256 usdcSpotQuantity = 0;
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
        ethPerpPos = Structs.NewPosition(2000e18, 5e18, false);
        wbtcCumFunding = 0;
        wethCumFunding = 0;
        setUserPositions(
            users.dan,
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
        // update funding snapshots
        uint32[] memory perpIds = new uint32[](2);
        perpIds[0] = defaults.wbtcUsdcPerpProductId();
        perpIds[1] = defaults.wethUsdcPerpProductId();
        int256[] memory cumFundings = new int256[](2);
        cumFundings[0] = -1e17;
        cumFundings[1] = -1e17;
        bytes memory payload = abi.encodePacked(
            perpIds[0],
            cumFundings[0],
            perpIds[1],
            cumFundings[1]
        );
        perpCrucible.updateCumulativeFundings(payload);
        addressManifest.updateAddressInManifest(4, address(orderDispatch));
        constructMatchOrderPayload();
        orderDispatch.ingresso(transaction);

        int256 maintenance = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            false
        );
        int256 initial = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            true
        );

        assertEq(maintenance, 99144450000000000000000);
        assertEq(initial, 97531950000000000000000);

        maintenance = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.dan, 1),
            false
        );
        initial = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.dan, 1),
            true
        );

        assertEq(maintenance, 97626250000000000000000);
        assertEq(initial, 96013750000000000000000);
    }

    function test_Happy_calculateSubaccountHealth_perp_pos_no_flip() public {
        addressManifest.updateAddressInManifest(4, users.gov);
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            2000e18,
            5e18,
            true
        );
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            0,
            0,
            false
        );
        uint256 usdcSpotQuantity = 0;
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
        bytes memory payload = abi.encodePacked(
            perpIds[0],
            cumFundings[0],
            perpIds[1],
            cumFundings[1]
        );
        perpCrucible.updateCumulativeFundings(payload);
        addressManifest.updateAddressInManifest(4, address(orderDispatch));
        makerOrder.isBuy = false;
        takerOrder.isBuy = true;
        makerOrder.quantity = 2e18;
        takerOrder.quantity = 2e18;
        constructMatchOrderPayload();
        orderDispatch.ingresso(transaction);

        int256 maintenance = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            false
        );
        int256 initial = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            true
        );

        assertEq(maintenance, 100429290000000000000000);
        assertEq(initial, 100106790000000000000000);
    }

    function test_Happy_calculateSubaccountHealth_perp_pos_no_flip_short()
        public
    {
        addressManifest.updateAddressInManifest(4, users.gov);
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            2000e18,
            5e18,
            false
        );
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            0,
            0,
            false
        );
        uint256 usdcSpotQuantity = 0;
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
        bytes memory payload = abi.encodePacked(
            perpIds[0],
            cumFundings[0],
            perpIds[1],
            cumFundings[1]
        );
        perpCrucible.updateCumulativeFundings(payload);
        addressManifest.updateAddressInManifest(4, address(orderDispatch));
        makerOrder.isBuy = true;
        takerOrder.isBuy = false;
        makerOrder.quantity = 2e18;
        takerOrder.quantity = 2e18;
        constructMatchOrderPayload();
        orderDispatch.ingresso(transaction);

        int256 maintenance = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            false
        );
        int256 initial = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            true
        );

        assertEq(maintenance, 98928290000000000000000);
        assertEq(initial, 98605790000000000000000);
    }

    function test_Happy_calculateSubaccountHealth_perp_pos_flip() public {
        addressManifest.updateAddressInManifest(4, users.gov);
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            2000e18,
            5e18,
            true
        );
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            0,
            0,
            false
        );
        uint256 usdcSpotQuantity = 0;
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
        bytes memory payload = abi.encodePacked(
            perpIds[0],
            cumFundings[0],
            perpIds[1],
            cumFundings[1]
        );
        perpCrucible.updateCumulativeFundings(payload);
        addressManifest.updateAddressInManifest(4, address(orderDispatch));
        makerOrder.isBuy = false;
        takerOrder.isBuy = true;
        makerOrder.quantity = 11e18;
        takerOrder.quantity = 11e18;
        constructMatchOrderPayload();
        orderDispatch.ingresso(transaction);

        int256 maintenance = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            false
        );
        int256 initial = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            true
        );

        assertEq(maintenance, 100112595000000000000000);
        assertEq(initial, 99467595000000000000000);
    }

    function test_Happy_calculateSubaccountHealth_perp_pos_flip_short() public {
        addressManifest.updateAddressInManifest(4, users.gov);
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            2000e18,
            5e18,
            false
        );
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            0,
            0,
            false
        );
        uint256 usdcSpotQuantity = 0;
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
        bytes memory payload = abi.encodePacked(
            perpIds[0],
            cumFundings[0],
            perpIds[1],
            cumFundings[1]
        );
        perpCrucible.updateCumulativeFundings(payload);
        addressManifest.updateAddressInManifest(4, address(orderDispatch));
        makerOrder.isBuy = true;
        takerOrder.isBuy = false;
        makerOrder.quantity = 11e18;
        takerOrder.quantity = 11e18;
        constructMatchOrderPayload();
        orderDispatch.ingresso(transaction);

        int256 maintenance = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            false
        );
        int256 initial = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            true
        );

        assertEq(maintenance, 98611595000000000000000);
        assertEq(initial, 97966595000000000000000);
    }
}
