// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Furnace} from "src/contracts/Furnace.sol";
import {PerpCrucible} from "src/contracts/crucible/perp-crucible/PerpCrucible.sol";
import {Commons} from "src/contracts/libraries/Commons.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";
import {Base_Test} from "../../Base.t.sol";

contract FurnaceSubaccountHealthTest is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        deployCiao();
    }

    function test_Happy_calculateSubaccountHealth() public {
        validateAssets();

        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            2000e18,
            10e18,
            true
        );
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            30000e18,
            2e18,
            false
        );
        uint256 usdcSpotQuantity = 0;
        uint256 wethSpotQuantity = 32e18; // 32
        uint256 wbtcSpotQuantity = 42e7; //4.2
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

        int256 maintenanceHealth1 = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            false
        );

        int256 initialHealth1 = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            true
        );

        assertEq(maintenanceHealth1, 1789193e17);
        assertEq(initialHealth1, 1640078e17);
        assertGt(maintenanceHealth1, initialHealth1);
    }

    function test_Happy_calculateSubaccountHealthWithInvalidSpread() public {
        validateAssets();
        furnace.setSpreadPenalty(address(wbtc), 1e18, 1e18);

        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            2000e18,
            10e18,
            true
        );
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            30000e18,
            2e18,
            false
        );
        uint256 usdcSpotQuantity = 0;
        uint256 wethSpotQuantity = 32e18; // 32
        uint256 wbtcSpotQuantity = 42e7; //4.2
        uint216 wethSpotPrice = 2100e18;
        uint216 wbtcSpotPrice = 29650e18;
        uint216 wethUsdcPerpPrice = 2150e18;
        uint216 wbtcUsdcPerpPrice = 29700e18;
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

        int256 maintenanceHealth1 = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            false
        );

        int256 initialHealth1 = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            true
        );

        assertEq(maintenanceHealth1, 1706128e17);
        assertEq(initialHealth1, 1473948e17);
        assertGt(maintenanceHealth1, initialHealth1);
    }

    function test_Happy_calculateSubaccountHealth_With_Usdc() public {
        validateAssets();

        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            2000e18,
            10e18,
            true
        );
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            30000e18,
            2e18,
            false
        );
        uint256 usdcSpotQuantity = 1000 * 10 ** usdc.decimals();
        uint256 wethSpotQuantity = 32e18; // 32
        uint256 wbtcSpotQuantity = 42e7; //4.2
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

        int256 health1 = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            false
        );

        assertEq(health1, 1799193e17);
    }

    function test_Happy_calculateSubaccountHealth_With_Debt() public {
        validateAssets();

        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            2000e18,
            10e18,
            true
        );
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            30000e18,
            2e18,
            false
        );
        uint256 usdcSpotQuantity = 0;
        uint256 wethSpotQuantity = 32e18; // 32
        uint256 wbtcSpotQuantity = 42e7; //4.2
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
        ciao.settleCoreCollateral(
            Commons.getSubAccount(users.alice, 1),
            -200e18
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

        int256 health1 = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            false
        );

        assertEq(health1, 1787193e17);
    }

    function test_Happy_calculateSubaccountHealth2() public {
        validateAssets();

        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            2500e18,
            30e18,
            false
        );
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            29000e18,
            2e18,
            false
        );
        uint256 usdcSpotQuantity = 0;
        uint256 wethSpotQuantity = 20e18; // 20
        uint256 wbtcSpotQuantity = 0;
        uint256 wethSpotPrice = 2100e18;
        uint256 wbtcSpotPrice = 29500e18;
        uint256 wethUsdcPerpPrice = 2030e18;
        uint256 wbtcUsdcPerpPrice = 29000e18;
        int256 wbtcCumFunding = -20e18;
        int256 wethCumFunding = 0;

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

        // update funding snapshots
        uint32[] memory perpIds = new uint32[](2);
        perpIds[0] = defaults.wbtcUsdcPerpProductId();
        perpIds[1] = defaults.wethUsdcPerpProductId();
        int256[] memory cumFundings = new int256[](2);
        cumFundings[0] = 1e17;
        cumFundings[1] = -5e17;
        bytes memory payload = abi.encodePacked(
            perpIds[0],
            cumFundings[0],
            perpIds[1],
            cumFundings[1]
        );
        perpCrucible.updateCumulativeFundings(payload);

        int256 maintenanceHealth2 = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            false
        );

        int256 initialHealth2 = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            true
        );

        assertEq(maintenanceHealth2, 515507e17);
        assertEq(initialHealth2, 470162e17);
        assertGt(maintenanceHealth2, initialHealth2);
    }

    function test_Happy_calculateSubaccountHealth3() public {
        validateAssets();

        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            2000e18,
            10e18,
            true
        );
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            30000e18,
            2e18,
            false
        );
        uint256 usdcSpotQuantity = 0;
        uint256 wethSpotQuantity = 32e18; // 32
        uint256 wbtcSpotQuantity = 32e7; // 3.2
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

        int256 maintenanceHealth3 = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            false
        );

        int256 initialHealth3 = furnace.getSubAccountHealth(
            Commons.getSubAccount(users.alice, 1),
            true
        );

        assertEq(maintenanceHealth3, 1522343e17);
        assertEq(initialHealth3, 1402878e17);
        assertGt(maintenanceHealth3, initialHealth3);
    }

    function test_Fail_SetPriceNotAuthorised() public {
        uint32[] memory setPricesProductIds = new uint32[](4);
        setPricesProductIds[0] = defaults.wbtcProductId();
        setPricesProductIds[1] = defaults.wethProductId();
        setPricesProductIds[2] = defaults.wbtcUsdcPerpProductId();
        setPricesProductIds[3] = defaults.wethUsdcPerpProductId();

        uint256[] memory setPricesValues = new uint256[](4);
        setPricesValues[0] = 100000e18;
        setPricesValues[1] = 10000e18;
        setPricesValues[2] = 100000e18;
        setPricesValues[3] = 10000e18;
        bytes memory payload = abi.encodePacked(
            setPricesProductIds[0],
            setPricesValues[0],
            setPricesProductIds[1],
            setPricesValues[1],
            setPricesProductIds[2],
            setPricesValues[2],
            setPricesProductIds[3],
            setPricesValues[3]
        );
        vm.startPrank(users.hackerman);
        vm.expectRevert("UNAUTHORIZED");
        furnace.setPrices(payload);
    }

    function test_Fail_SetPriceDifferentArrayLength() public {
        uint32[] memory setPricesProductIds = new uint32[](2);
        setPricesProductIds[0] = defaults.wbtcProductId();
        setPricesProductIds[1] = defaults.wethProductId();

        uint256[] memory setPricesValues = new uint256[](4);
        setPricesValues[0] = 100000e18;
        setPricesValues[1] = 10000e18;
        setPricesValues[2] = 100000e18;
        setPricesValues[3] = 10000e18;
        bytes memory payload = abi.encodePacked(
            setPricesProductIds[0],
            setPricesValues[0],
            setPricesProductIds[1],
            setPricesValues[1],
            setPricesValues[2],
            setPricesValues[3]
        );
        vm.expectRevert(bytes4(keccak256("OrderByteLengthInvalid()")));
        furnace.setPrices(payload);
    }

    function test_Fail_SetSpreadPenaltyNotAuthorised() public {
        address btcSpot = address(wbtc);
        vm.startPrank(users.hackerman);
        vm.expectRevert("UNAUTHORIZED");

        furnace.setSpreadPenalty(btcSpot, 0, 0);
    }

    function test_Fail_SetSpotRiskWeightNotAuthorised() public {
        address btcSpot = address(wbtc);
        Structs.ProductRiskWeights memory weights = Structs.ProductRiskWeights(
            1e18,
            1e18,
            1e18,
            1e18
        );
        vm.startPrank(users.hackerman);
        vm.expectRevert("UNAUTHORIZED");

        furnace.setSpotRiskWeight(btcSpot, weights);
    }

    function test_Fail_setProductRiskWeightNotAuthorised() public {
        uint32 id = defaults.wbtcProductId();
        Structs.ProductRiskWeights memory weights = Structs.ProductRiskWeights(
            1e18,
            1e18,
            1e18,
            1e18
        );
        vm.startPrank(users.hackerman);
        vm.expectRevert("UNAUTHORIZED");

        furnace.setProductRiskWeight(id, weights);
    }

    function test_Fail_setBaseAssetQuotePerpsNotAuthorised() public {
        address btcSpot = address(wbtc);
        uint32 id = defaults.wbtcUsdcPerpProductId();

        vm.startPrank(users.hackerman);
        vm.expectRevert("UNAUTHORIZED");

        furnace.setBaseAssetQuotePerps(btcSpot, id);
    }

    function test_Happy_SetPrice() public {
        uint32[] memory setPricesProductIds = new uint32[](4);
        setPricesProductIds[0] = defaults.wbtcProductId();
        setPricesProductIds[1] = defaults.wethProductId();
        setPricesProductIds[2] = defaults.wbtcUsdcPerpProductId();
        setPricesProductIds[3] = defaults.wethUsdcPerpProductId();

        uint256[] memory setPricesValues = new uint256[](4);
        setPricesValues[0] = 100000e18;
        setPricesValues[1] = 10000e18;
        setPricesValues[2] = 100000e18;
        setPricesValues[3] = 10000e18;
        bytes memory payload = abi.encodePacked(
            setPricesProductIds[0],
            setPricesValues[0],
            setPricesProductIds[1],
            setPricesValues[1],
            setPricesProductIds[2],
            setPricesValues[2],
            setPricesProductIds[3],
            setPricesValues[3]
        );
        furnace.setPrices(payload);
        assertEq(furnace.prices(defaults.wbtcProductId()), 100000e18);
        assertEq(furnace.prices(defaults.wethProductId()), 10000e18);
        assertEq(furnace.prices(defaults.wbtcUsdcPerpProductId()), 100000e18);
        assertEq(furnace.prices(defaults.wethUsdcPerpProductId()), 10000e18);
    }

    function test_Happy_SetSpreadPenalty() public {
        address btcSpot = address(wbtc);

        furnace.setSpreadPenalty(btcSpot, 0, 0);
        (uint64 initial, uint64 maintenance) = furnace.spreadPenalties(btcSpot);
        assertEq(initial, 0);
        assertEq(maintenance, 0);
    }

    function test_Happy_SetSpotRiskWeight() public {
        address btcSpot = address(wbtc);
        Structs.ProductRiskWeights memory weights = Structs.ProductRiskWeights(
            69e16,
            69e16,
            69e16,
            69e16
        );

        furnace.setSpotRiskWeight(btcSpot, weights);
        (
            uint64 initialLongWeight,
            uint64 initialShortWeight,
            uint64 maintenanceLongWeight,
            uint64 maintenanceShortWeight
        ) = furnace.spotRiskWeights(btcSpot);

        assertEq(initialLongWeight, 69e16);
        assertEq(initialShortWeight, 69e16);
        assertEq(maintenanceLongWeight, 69e16);
        assertEq(maintenanceShortWeight, 69e16);
    }

    function test_Happy_setProductRiskWeight() public {
        uint32 id = defaults.wbtcProductId();
        Structs.ProductRiskWeights memory weights = Structs.ProductRiskWeights(
            69e16,
            69e16,
            69e16,
            69e16
        );

        furnace.setProductRiskWeight(id, weights);
        (
            uint64 initialLongWeight,
            uint64 initialShortWeight,
            uint64 maintenanceLongWeight,
            uint64 maintenanceShortWeight
        ) = furnace.productRiskWeights(id);

        assertEq(initialLongWeight, 69e16);
        assertEq(initialShortWeight, 69e16);
        assertEq(maintenanceLongWeight, 69e16);
        assertEq(maintenanceShortWeight, 69e16);
    }

    function test_Happy_setBaseAssetQuotePerps() public {
        address btcSpot = address(wbtc);
        uint32 id = 500;

        furnace.setBaseAssetQuotePerps(btcSpot, id);
        assertEq(furnace.baseAssetQuotePerpIds(btcSpot), 500);
    }
}
