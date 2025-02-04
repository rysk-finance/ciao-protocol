// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Furnace} from "src/contracts/Furnace.sol";
import {Ciao} from "src/contracts/Ciao.sol";
import {PerpCrucible} from "src/contracts/crucible/perp-crucible/PerpCrucible.sol";
import {Commons} from "src/contracts/libraries/Commons.sol";
import {Base_Test} from "../../Base.t.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";

contract PerpCrucibleTest is Base_Test {
    address aliceSubAccount;
    address danSubAccount;

    struct initialPositionParams {
        uint256 usdcSpotQuantity;
        uint256 wbtcSpotQuantity;
        uint256 wethSpotPrice;
        uint256 wbtcSpotPrice;
        int256 wbtcCumFunding;
        int256 wethCumFunding;
    }

    struct updatePositionParams {
        int256 wbtcCumFunding;
        int256 wethCumFunding;
    }
    // set up account with these initial positions

    Structs.NewPosition initialEthPerpPos = Structs.NewPosition(2000e18, 10e18, true);

    Structs.NewPosition initialBtcPerpPos = Structs.NewPosition(30000e18, 2e18, false);

    function setUp() public virtual override {
        Base_Test.setUp();
        deployCiao();
        aliceSubAccount = Commons.getSubAccount(users.alice, 1);
        danSubAccount = Commons.getSubAccount(users.dan, 1);
    }

    function openAliceFirstPosMaker(
        Structs.NewPosition memory initialBtcPos,
        int256 initialBtcCumFunding,
        uint256 initialUsdcQuantity
    ) internal {
        vm.startPrank({msgSender: users.gov});
        // set funding snapshots
        uint32[] memory perpIds = new uint32[](1);
        perpIds[0] = defaults.wbtcUsdcPerpProductId();
        int256[] memory cumFundings = new int256[](1);
        cumFundings[0] = initialBtcCumFunding;
        bytes memory payload = abi.encodePacked(perpIds[0], cumFundings[0]);
        perpCrucible.updateCumulativeFundings(payload);

        // set position
        perpCrucible.updatePosition(
            address(0), aliceSubAccount, defaults.wbtcUsdcPerpProductId(), initialBtcPos
        );
        vm.stopPrank();
        if (initialUsdcQuantity > 0) {
            deal(address(usdc), users.alice, initialUsdcQuantity);
            vm.startPrank(users.alice);
            usdc.approve(address(ciao), initialUsdcQuantity);
            ciao.deposit(users.alice, 1, initialUsdcQuantity, address(usdc));
            vm.stopPrank();
        }
        vm.startPrank({msgSender: users.gov});
    }

    function openAliceFirstPosTaker(
        Structs.NewPosition memory initialBtcPos,
        int256 initialBtcCumFunding,
        uint256 initialUsdcQuantity
    ) internal {
        vm.startPrank({msgSender: users.gov});
        // set funding snapshots
        uint32[] memory perpIds = new uint32[](1);
        perpIds[0] = defaults.wbtcUsdcPerpProductId();
        int256[] memory cumFundings = new int256[](1);
        cumFundings[0] = initialBtcCumFunding;
        bytes memory payload = abi.encodePacked(perpIds[0], cumFundings[0]);
        perpCrucible.updateCumulativeFundings(payload);

        // set position
        perpCrucible.updatePosition(
            aliceSubAccount,
            address(0),
            defaults.wbtcUsdcPerpProductId(),
            Structs.NewPosition(
                initialBtcPos.executionPrice, initialBtcPos.quantity, !initialBtcPos.isLong
            )
        );
        vm.stopPrank();
        if (initialUsdcQuantity > 0) {
            deal(address(usdc), users.alice, initialUsdcQuantity);
            vm.startPrank(users.alice);
            usdc.approve(address(ciao), initialUsdcQuantity);
            ciao.deposit(users.alice, 1, initialUsdcQuantity, address(usdc));
            vm.stopPrank();
        }
        vm.startPrank({msgSender: users.gov});
    }

    function updateAlicePosMaker(Structs.NewPosition memory btcPos, int256 btcCumFunding)
        internal
    {
        // set funding snapshots
        uint32[] memory perpIds = new uint32[](1);
        perpIds[0] = defaults.wbtcUsdcPerpProductId();
        int256[] memory cumFundings = new int256[](1);
        cumFundings[0] = btcCumFunding;

        // set position
        perpCrucible.updatePosition(
            address(0), aliceSubAccount, defaults.wbtcUsdcPerpProductId(), btcPos
        );
    }

    function updateAlicePosTaker(Structs.NewPosition memory btcPos, int256 btcCumFunding)
        internal
    {
        // set funding snapshots
        uint32[] memory perpIds = new uint32[](1);
        perpIds[0] = defaults.wbtcUsdcPerpProductId();
        int256[] memory cumFundings = new int256[](1);
        cumFundings[0] = btcCumFunding;

        // set position
        perpCrucible.updatePosition(
            aliceSubAccount,
            address(0),
            defaults.wbtcUsdcPerpProductId(),
            Structs.NewPosition(btcPos.executionPrice, btcPos.quantity, !btcPos.isLong)
        );
    }

    function testFuzz_Happy_updateNewPositionMaker(
        uint120 initialBtcPosExecutionPrice,
        uint120 initialBtcPosQuantity,
        bool initialBtcPosIsLong,
        int120 initialBtcCumFunding,
        uint128 initialUsdcQuantity,
        Structs.NewPosition memory secondBtcPos,
        int120 secondBtcCumFunding,
        Structs.NewPosition memory thirdBtcPos,
        int120 thirdBtcCumFunding
    ) public {
        vm.assume(secondBtcPos.executionPrice < 10000000000000000e18);
        vm.assume(thirdBtcPos.executionPrice < 10000000000000000e18);

        vm.assume(secondBtcPos.quantity < 10000000000000000e18 && secondBtcPos.quantity > 0);
        vm.assume(thirdBtcPos.quantity < 10000000000000000e18 && thirdBtcPos.quantity > 0);

        validateAssets();

        Structs.NewPosition memory initialBtcPos = Structs.NewPosition(
            initialBtcPosExecutionPrice, initialBtcPosQuantity, initialBtcPosIsLong
        );

        openAliceFirstPosMaker(initialBtcPos, initialBtcCumFunding, initialUsdcQuantity);
        updateAlicePosMaker(secondBtcPos, secondBtcCumFunding);
        updateAlicePosMaker(thirdBtcPos, thirdBtcCumFunding);

        int256 expectedFinalBtcPosQuantity = (
            initialBtcPos.isLong ? int256(initialBtcPos.quantity) : -int256(initialBtcPos.quantity)
        ) + (secondBtcPos.isLong ? int256(secondBtcPos.quantity) : -int256(secondBtcPos.quantity))
            + (thirdBtcPos.isLong ? int256(thirdBtcPos.quantity) : -int256(thirdBtcPos.quantity));

        Structs.PositionState memory actualPos =
            perpCrucible.getSubAccountPosition(defaults.wbtcUsdcPerpProductId(), aliceSubAccount);
        assertEq(
            actualPos.quantity,
            expectedFinalBtcPosQuantity > 0
                ? uint256(expectedFinalBtcPosQuantity)
                : uint256(-expectedFinalBtcPosQuantity)
        );

        assertEq(expectedFinalBtcPosQuantity > 0, actualPos.isLong);
    }

    function testFuzz_Happy_updateNewPositionTaker(
        uint120 initialBtcPosExecutionPrice,
        uint120 initialBtcPosQuantity,
        bool initialBtcPosIsLong,
        int120 initialBtcCumFunding,
        uint128 initialUsdcQuantity,
        Structs.NewPosition memory secondBtcPos,
        int120 secondBtcCumFunding,
        Structs.NewPosition memory thirdBtcPos,
        int120 thirdBtcCumFunding
    ) public {
        vm.assume(secondBtcPos.executionPrice < 10000000000000000e18);
        vm.assume(thirdBtcPos.executionPrice < 10000000000000000e18);

        vm.assume(secondBtcPos.quantity < 10000000000000000e18 && secondBtcPos.quantity > 0);
        vm.assume(thirdBtcPos.quantity < 10000000000000000e18 && thirdBtcPos.quantity > 0);

        validateAssets();

        Structs.NewPosition memory initialBtcPos = Structs.NewPosition(
            initialBtcPosExecutionPrice, initialBtcPosQuantity, initialBtcPosIsLong
        );

        openAliceFirstPosTaker(initialBtcPos, initialBtcCumFunding, initialUsdcQuantity);
        updateAlicePosTaker(secondBtcPos, secondBtcCumFunding);
        updateAlicePosTaker(thirdBtcPos, thirdBtcCumFunding);

        int256 expectedFinalBtcPosQuantity = (
            initialBtcPos.isLong ? int256(initialBtcPos.quantity) : -int256(initialBtcPos.quantity)
        ) + (secondBtcPos.isLong ? int256(secondBtcPos.quantity) : -int256(secondBtcPos.quantity))
            + (thirdBtcPos.isLong ? int256(thirdBtcPos.quantity) : -int256(thirdBtcPos.quantity));

        Structs.PositionState memory actualPos =
            perpCrucible.getSubAccountPosition(defaults.wbtcUsdcPerpProductId(), aliceSubAccount);
        assertEq(
            actualPos.quantity,
            expectedFinalBtcPosQuantity > 0
                ? uint256(expectedFinalBtcPosQuantity)
                : uint256(-expectedFinalBtcPosQuantity)
        );

        assertEq(expectedFinalBtcPosQuantity > 0, actualPos.isLong);
    }

    function testFuzz_Happy_In_Out_Accounting(
        uint120 initialBtcPosExecutionPrice,
        uint120 initialBtcPosQuantity,
        bool initialBtcPosIsLong,
        int88 initialBtcCumFunding,
        uint120 secondBtcPosExecutionPrice,
        uint120 secondBtcPosQuantity,
        bool secondBtcPosIsLong,
        int88 secondBtcCumFunding
    ) public {
        vm.assume(initialBtcPosExecutionPrice < 10000000000000000e18);
        vm.assume(secondBtcPosExecutionPrice < 10000000000000000e18);
        vm.assume(initialBtcPosQuantity < 10000000000000000e18 && initialBtcPosQuantity > 0);
        vm.assume(secondBtcPosQuantity < 10000000000000000e18 && secondBtcPosQuantity > 0);

        vm.startPrank({msgSender: users.gov});
        // set funding snapshots
        uint32[] memory perpIds = new uint32[](1);
        perpIds[0] = defaults.wbtcUsdcPerpProductId();
        int256[] memory cumFundings = new int256[](1);
        cumFundings[0] = initialBtcCumFunding;
        bytes memory payload = abi.encodePacked(perpIds[0], cumFundings[0]);
        perpCrucible.updateCumulativeFundings(payload);

        // set initial position

        Structs.NewPosition memory initialBtcPos = Structs.NewPosition(
            initialBtcPosExecutionPrice, initialBtcPosQuantity, initialBtcPosIsLong
        );

        (int256 aliceRealisedPnl, int256 danRealisedPnl) = perpCrucible.updatePosition(
            aliceSubAccount, danSubAccount, defaults.wbtcUsdcPerpProductId(), initialBtcPos
        );
        assertEq(aliceRealisedPnl, 0);
        assertEq(danRealisedPnl, 0);

        // set second funding snapshots
        perpIds[0] = defaults.wbtcUsdcPerpProductId();
        cumFundings[0] = secondBtcCumFunding;
        payload = abi.encodePacked(perpIds[0], cumFundings[0]);
        perpCrucible.updateCumulativeFundings(payload);

        // set second position

        Structs.NewPosition memory secondBtcPos = Structs.NewPosition(
            secondBtcPosExecutionPrice, secondBtcPosQuantity, secondBtcPosIsLong
        );

        (aliceRealisedPnl, danRealisedPnl) = perpCrucible.updatePosition(
            aliceSubAccount, danSubAccount, defaults.wbtcUsdcPerpProductId(), secondBtcPos
        );

        assertEq(aliceRealisedPnl, -danRealisedPnl);
    }
}
