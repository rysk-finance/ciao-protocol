// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/contracts/interfaces/Errors.sol";
import "src/contracts/interfaces/Events.sol";

import {Furnace} from "src/contracts/Furnace.sol";
import {Ciao} from "src/contracts/Ciao.sol";
import {PerpCrucible} from "src/contracts/crucible/perp-crucible/PerpCrucible.sol";
import {Commons} from "src/contracts/libraries/Commons.sol";
import {Base_Test} from "../../Base.t.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";

import "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract PerpCrucibleTest is Base_Test {
    address aliceSubAccount;

    // set up account with these initial positions
    Structs.NewPosition initialEthPerpPos =
        Structs.NewPosition(2000e18, 10e18, true);

    Structs.NewPosition initialBtcPerpPos =
        Structs.NewPosition(30000e18, 2e18, false);

    function setUp() public virtual override {
        Base_Test.setUp();
        deployCiao();
        aliceSubAccount = Commons.getSubAccount(users.alice, 1);
        // // spoof order dispatch address to bypass access control on updatePosition()
        // addressManifest.updateAddressInManifest(4, users.gov);
        address newPerpCrucibleImpl = address(new PerpCrucible());
        perpCrucibleProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(perpCrucibleProxy)),
            newPerpCrucibleImpl,
            bytes("")
        );
        assertEq(
            address(
                uint160(
                    uint256(
                        vm.load(
                            address(perpCrucibleProxy),
                            ERC1967Utils.IMPLEMENTATION_SLOT
                        )
                    )
                )
            ),
            newPerpCrucibleImpl
        );
    }

    function test_Happy_ProxyAdmin_Can_Upgrade() public {
        address newPerpCrucibleImpl = address(new PerpCrucible());
        perpCrucibleProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(perpCrucibleProxy)),
            newPerpCrucibleImpl,
            bytes("")
        );
        assertEq(
            address(
                uint160(
                    uint256(
                        vm.load(
                            address(perpCrucibleProxy),
                            ERC1967Utils.IMPLEMENTATION_SLOT
                        )
                    )
                )
            ),
            newPerpCrucibleImpl
        );
    }

    function test_Happy_updateNewPosition() public {
        validateAssets();
        uint256 usdcSpotQuantity = 500 * 10 ** usdc.decimals(); // 500 usdc
        uint256 wethSpotQuantity = 32e18; // 32
        uint256 wbtcSpotQuantity = 42e8; //4.2
        uint256 wethSpotPrice = 2100e18;
        uint256 wbtcSpotPrice = 29650e18;
        uint256 wethUsdcPerpPrice = 2150e18;
        uint256 wbtcUsdcPerpPrice = 29700e18;
        int256 wbtcCumFunding = -201e17;
        int256 wethCumFunding = 499e17;

        setAlicePositions(
            wbtcCumFunding,
            wethCumFunding,
            initialEthPerpPos,
            initialBtcPerpPos,
            usdcSpotQuantity,
            wethSpotQuantity,
            wbtcSpotQuantity,
            wethSpotPrice,
            wbtcSpotPrice,
            wethUsdcPerpPrice,
            wbtcUsdcPerpPrice
        );

        Structs.PositionState memory contractStateEth = perpCrucible
            .getSubAccountPosition(
                defaults.wethUsdcPerpProductId(),
                aliceSubAccount
            );

        Structs.PositionState memory contractStateBtc = perpCrucible
            .getSubAccountPosition(
                defaults.wbtcUsdcPerpProductId(),
                aliceSubAccount
            );
        assertEq(contractStateEth.avgEntryPrice, 2000e18);
        assertEq(contractStateEth.quantity, 10e18);
        assertEq(contractStateEth.isLong, true);
        assertEq(contractStateEth.initCumFunding, 499e17);
        assertTrue(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wethUsdcPerpProductId()
            )
        );

        assertEq(contractStateBtc.avgEntryPrice, 30000e18);
        assertEq(contractStateBtc.quantity, 2e18);
        assertEq(contractStateBtc.isLong, false);
        assertEq(contractStateBtc.initCumFunding, -201e17);
        assertTrue(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wbtcUsdcPerpProductId()
            )
        );

        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 500e18);
        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 0);
    }

    // --------------------------------------
    // ---- existing long position tests ----
    // --------------------------------------

    function test_Happy_addToExistingLongNoFundingToSettle() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            1850e18,
            30e18,
            true
        );

        uint32 perpId = defaults.wethUsdcPerpProductId();

        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                !initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(
                18875e17,
                40e18,
                !initialEthPerpPos.isLong,
                499e17
            )
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(
                18875e17,
                40e18,
                initialEthPerpPos.isLong,
                499e17
            )
        );

        perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            perpId,
            ethPerpPos
        );
        // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wethUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 18875e17);
        assertEq(contractStateAfter.quantity, 40e18);
        assertEq(contractStateAfter.isLong, true);
        assertEq(contractStateAfter.initCumFunding, 499e17);
        assertTrue(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wethUsdcPerpProductId()
            )
        );
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 500e18);
        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 0);
    }

    function test_Happy_addToExistingLongNegativeFundingToSettle() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            1850e18,
            30e18,
            true
        );

        // increment ETH funding rate by $0.3 (longs must pay shorts)
        setFundingRate(defaults.wethUsdcPerpProductId(), 3e17);

        uint32 perpId = defaults.wethUsdcPerpProductId();
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                !initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(
                18875e17,
                40e18,
                !initialEthPerpPos.isLong,
                502e17
            )
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(
                18875e17,
                40e18,
                initialEthPerpPos.isLong,
                502e17
            )
        );

        (, int256 aliceRealisedPnl) = perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            defaults.wethUsdcPerpProductId(),
            ethPerpPos
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            aliceSubAccount,
            address(usdc),
            int256(ciao.balances(aliceSubAccount, address(usdc))),
            int256(ciao.balances(aliceSubAccount, address(usdc))) +
                aliceRealisedPnl
        );
        ciao.settleCoreCollateral(aliceSubAccount, aliceRealisedPnl);
        // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wethUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 18875e17);
        assertEq(contractStateAfter.quantity, 40e18);
        assertEq(contractStateAfter.isLong, true);
        assertEq(contractStateAfter.initCumFunding, 502e17);
        assertTrue(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wethUsdcPerpProductId()
            )
        );
        // 500 + (-0.3 * 10)
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 497e18);

        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 0);
    }

    function test_Happy_addToExistingLongPositiveFundingToSettle() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            1850e18,
            30e18,
            true
        );

        // decrement ETH funding rate by $0.3 (shorts must pay longs)
        setFundingRate(defaults.wethUsdcPerpProductId(), -3e17);
        uint32 perpId = defaults.wethUsdcPerpProductId();
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                !initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(
                18875e17,
                40e18,
                !initialEthPerpPos.isLong,
                496e17
            )
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(
                18875e17,
                40e18,
                initialEthPerpPos.isLong,
                496e17
            )
        );
        (, int256 aliceRealisedPnl) = perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            defaults.wethUsdcPerpProductId(),
            ethPerpPos
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            aliceSubAccount,
            address(usdc),
            int256(ciao.balances(aliceSubAccount, address(usdc))),
            int256(ciao.balances(aliceSubAccount, address(usdc))) +
                aliceRealisedPnl
        );
        ciao.settleCoreCollateral(aliceSubAccount, aliceRealisedPnl);
        // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wethUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 18875e17);
        assertEq(contractStateAfter.quantity, 40e18);
        assertEq(contractStateAfter.isLong, true);
        assertEq(contractStateAfter.initCumFunding, 496e17);
        assertTrue(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wethUsdcPerpProductId()
            )
        );
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 503e18);

        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 0);
    }

    function test_Happy_closeExistingLongLoss() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            1900e18, // $100 down
            10e18,
            false
        );

        // increment ETH funding rate by $0.3 (longs must pay shorts)
        setFundingRate(defaults.wethUsdcPerpProductId(), 3e17);
        uint32 perpId = defaults.wethUsdcPerpProductId();
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                !initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(0, 0, false, 0)
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(0, 0, false, 0)
        );
        (, int256 aliceRealisedPnl) = perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            defaults.wethUsdcPerpProductId(),
            ethPerpPos
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            aliceSubAccount,
            address(usdc),
            int256(ciao.balances(aliceSubAccount, address(usdc))),
            int256(ciao.balances(aliceSubAccount, address(usdc))) +
                aliceRealisedPnl
        );
        ciao.settleCoreCollateral(aliceSubAccount, aliceRealisedPnl);
        // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wethUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 0);
        assertEq(contractStateAfter.quantity, 0);
        assertEq(contractStateAfter.isLong, false);
        assertEq(contractStateAfter.initCumFunding, 0);
        assertFalse(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wethUsdcPerpProductId()
            )
        );
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 0);
        // $1003 loss (-1k pnl - $3 funding)
        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 503e18);
    }

    function test_Happy_closeExistingLongProfit() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            3200e18, // 1200 up
            10e18,
            false
        );

        // increment ETH funding rate by $0.1 (longs must pay shorts)
        setFundingRate(defaults.wethUsdcPerpProductId(), 1e17);
        uint32 perpId = defaults.wethUsdcPerpProductId();
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                !initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(0, 0, false, 0)
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(0, 0, false, 0)
        );
        (, int256 aliceRealisedPnl) = perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            defaults.wethUsdcPerpProductId(),
            ethPerpPos
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            aliceSubAccount,
            address(usdc),
            int256(ciao.balances(aliceSubAccount, address(usdc))),
            int256(ciao.balances(aliceSubAccount, address(usdc))) +
                aliceRealisedPnl
        );
        ciao.settleCoreCollateral(aliceSubAccount, aliceRealisedPnl);
        // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wethUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 0);
        assertEq(contractStateAfter.quantity, 0);
        assertEq(contractStateAfter.isLong, false);
        assertEq(contractStateAfter.initCumFunding, 0);
        assertFalse(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wethUsdcPerpProductId()
            )
        );
        // $11999 profit (12k pnl - $1 funding)
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 12499e18);
        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 0);
    }

    function test_Happy_reduceExistingLongLoss() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            1700e18, // 300 down
            5e18,
            false
        );

        // increment ETH funding rate by $0.1 (longs must pay shorts)
        setFundingRate(defaults.wethUsdcPerpProductId(), 1e17);
        uint32 perpId = defaults.wethUsdcPerpProductId();
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                !initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(2000e18, 5e18, false, 50e18)
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(2000e18, 5e18, true, 50e18)
        );
        (, int256 aliceRealisedPnl) = perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            defaults.wethUsdcPerpProductId(),
            ethPerpPos
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            aliceSubAccount,
            address(usdc),
            int256(ciao.balances(aliceSubAccount, address(usdc))),
            int256(ciao.balances(aliceSubAccount, address(usdc))) +
                aliceRealisedPnl
        );
        ciao.settleCoreCollateral(aliceSubAccount, aliceRealisedPnl);
        // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wethUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 2000e18);
        assertEq(contractStateAfter.quantity, 5e18);
        assertEq(contractStateAfter.isLong, true);
        assertEq(contractStateAfter.initCumFunding, 50e18);
        assertTrue(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wethUsdcPerpProductId()
            )
        );
        // $1501 loss (-1.5k realised pnl - $1 funding)
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 0);
        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 1001e18);
    }

    function test_Happy_reduceExistingLongProfit() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            2020e18, // 20 up
            3e18,
            false
        );

        // decrement ETH funding rate by $0.1 (shorts must pay longs)
        setFundingRate(defaults.wethUsdcPerpProductId(), -1e17);
        uint32 perpId = defaults.wethUsdcPerpProductId();
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                !initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(2000e18, 7e18, false, 498e17)
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(2000e18, 7e18, true, 498e17)
        );
        (, int256 aliceRealisedPnl) = perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            defaults.wethUsdcPerpProductId(),
            ethPerpPos
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            aliceSubAccount,
            address(usdc),
            int256(ciao.balances(aliceSubAccount, address(usdc))),
            int256(ciao.balances(aliceSubAccount, address(usdc))) +
                aliceRealisedPnl
        );
        ciao.settleCoreCollateral(aliceSubAccount, aliceRealisedPnl);
        // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wethUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 2000e18);
        assertEq(contractStateAfter.quantity, 7e18);
        assertEq(contractStateAfter.isLong, true);
        assertEq(contractStateAfter.initCumFunding, 498e17);
        assertTrue(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wethUsdcPerpProductId()
            )
        );
        // $61 profit ($60 realised pnl + $1 funding)
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 561e18);
        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 0);
    }

    function test_Happy_flipExistingLongLoss() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            2034e18, // 34 up
            14e18,
            false
        );

        // increment ETH funding rate by 600 (longs must pay shorts)
        setFundingRate(defaults.wethUsdcPerpProductId(), 600e18);
        uint32 perpId = defaults.wethUsdcPerpProductId();
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                !initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(2034e18, 4e18, true, 6499e17)
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(2034e18, 4e18, false, 6499e17)
        );
        (, int256 aliceRealisedPnl) = perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            defaults.wethUsdcPerpProductId(),
            ethPerpPos
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            aliceSubAccount,
            address(usdc),
            int256(ciao.balances(aliceSubAccount, address(usdc))),
            int256(ciao.balances(aliceSubAccount, address(usdc))) +
                aliceRealisedPnl
        );
        ciao.settleCoreCollateral(aliceSubAccount, aliceRealisedPnl);
        // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wethUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 2034e18);
        assertEq(contractStateAfter.quantity, 4e18);
        assertEq(contractStateAfter.isLong, false);
        assertEq(contractStateAfter.initCumFunding, 6499e17);
        assertTrue(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wethUsdcPerpProductId()
            )
        );
        // $5660 loss ($340 realised pnl - $6000 funding)
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 0);
        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 5160e18);
    }

    function test_Happy_flipExistingLongProfit() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory ethPerpPos = Structs.NewPosition(
            1900e18, // 100 down
            431e17,
            false
        );

        // decrement ETH funding rate by 20 (shorts must pay longs)
        setFundingRate(defaults.wethUsdcPerpProductId(), -200e18);
        uint32 perpId = defaults.wethUsdcPerpProductId();
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                !initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(1900e18, 331e17, true, -1501e17)
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialEthPerpPos.executionPrice,
                initialEthPerpPos.quantity,
                initialEthPerpPos.isLong,
                499e17
            ),
            Structs.PositionState(1900e18, 331e17, false, -1501e17)
        );
        (, int256 aliceRealisedPnl) = perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            defaults.wethUsdcPerpProductId(),
            ethPerpPos
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            aliceSubAccount,
            address(usdc),
            int256(ciao.balances(aliceSubAccount, address(usdc))),
            int256(ciao.balances(aliceSubAccount, address(usdc))) +
                aliceRealisedPnl
        );
        ciao.settleCoreCollateral(aliceSubAccount, aliceRealisedPnl);
        // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wethUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 1900e18);
        assertEq(contractStateAfter.quantity, 331e17);
        assertEq(contractStateAfter.isLong, false);
        assertEq(contractStateAfter.initCumFunding, -1501e17);
        assertTrue(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wethUsdcPerpProductId()
            )
        );
        // $1000 profit (-$1000 realised pnl + $2000 funding)
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 1500e18);
        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 0);
    }

    // ----------------------------------------
    // ---- existing short position tests -----
    // ----------------------------------------

    function test_Happy_addToExistingShortNoFundingToSettle() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            33000e18,
            1e18,
            false
        );
        uint32 perpId = defaults.wbtcUsdcPerpProductId();
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                !initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(31000e18, 3e18, true, -201e17)
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(31000e18, 3e18, false, -201e17)
        );
        (, int256 aliceRealisedPnl) = perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            defaults.wbtcUsdcPerpProductId(),
            btcPerpPos
        );
        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 0);      
        ciao.settleCoreCollateral(aliceSubAccount, aliceRealisedPnl); // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wbtcUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 31000e18);
        assertEq(contractStateAfter.quantity, 3e18);
        assertEq(contractStateAfter.isLong, false);
        assertEq(contractStateAfter.initCumFunding, -201e17);
        assertTrue(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wbtcUsdcPerpProductId()
            )
        );
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 500e18);
        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 0);
    }

    function test_Happy_addToExistingShortNegativeFundingToSettle() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            42000e18,
            2e18,
            false
        );

        // decrement btc funding rate by $50 (shorts must pay longs)
        setFundingRate(defaults.wbtcUsdcPerpProductId(), -50e18);
        uint32 perpId = defaults.wbtcUsdcPerpProductId();
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                !initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(36000e18, 4e18, true, -701e17)
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(36000e18, 4e18, false, -701e17)
        );
        (, int256 aliceRealisedPnl) = perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            defaults.wbtcUsdcPerpProductId(),
            btcPerpPos
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            aliceSubAccount,
            address(usdc),
            int256(ciao.balances(aliceSubAccount, address(usdc))),
            int256(ciao.balances(aliceSubAccount, address(usdc))) +
                aliceRealisedPnl
        );
        ciao.settleCoreCollateral(aliceSubAccount, aliceRealisedPnl);
        // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wbtcUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 36000e18);
        assertEq(contractStateAfter.quantity, 4e18);
        assertEq(contractStateAfter.isLong, false);
        assertEq(contractStateAfter.initCumFunding, -701e17);
        assertTrue(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wbtcUsdcPerpProductId()
            )
        );

        // -$100 funding
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 400e18);

        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 0);
    }

    function test_Happy_addToExistingShortPositiveFundingToSettle() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            27000e18,
            6e18,
            false
        );

        // increment btc funding rate by $30 (longs must pay shorts)
        setFundingRate(defaults.wbtcUsdcPerpProductId(), 30e18);
        uint32 perpId = defaults.wbtcUsdcPerpProductId();
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                !initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(27750e18, 8e18, true, 99e17)
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(27750e18, 8e18, false, 99e17)
        );
        (, int256 aliceRealisedPnl) = perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            defaults.wbtcUsdcPerpProductId(),
            btcPerpPos
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            aliceSubAccount,
            address(usdc),
            int256(ciao.balances(aliceSubAccount, address(usdc))),
            int256(ciao.balances(aliceSubAccount, address(usdc))) +
                aliceRealisedPnl
        );
        ciao.settleCoreCollateral(aliceSubAccount, aliceRealisedPnl);
        // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wbtcUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 27750e18);
        assertEq(contractStateAfter.quantity, 8e18);
        assertEq(contractStateAfter.isLong, false);
        assertEq(contractStateAfter.initCumFunding, 99e17);
        assertTrue(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wbtcUsdcPerpProductId()
            )
        );
        // +$60 funding
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 560e18);

        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 0);
    }

    function test_Happy_closeExistingShortLoss() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            40000e18, // $10k down
            2e18,
            true
        );

        // increment btc funding rate by 0.0 (no funding accrued)
        setFundingRate(defaults.wbtcUsdcPerpProductId(), 0);
        uint32 perpId = defaults.wbtcUsdcPerpProductId();
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                !initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(0, 0, false, 0)
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(0, 0, false, 0)
        );
        (, int256 aliceRealisedPnl) = perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            defaults.wbtcUsdcPerpProductId(),
            btcPerpPos
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            aliceSubAccount,
            address(usdc),
            int256(ciao.balances(aliceSubAccount, address(usdc))),
            int256(ciao.balances(aliceSubAccount, address(usdc))) +
                aliceRealisedPnl
        );
        ciao.settleCoreCollateral(aliceSubAccount, aliceRealisedPnl);
        // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wbtcUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 0);
        assertEq(contractStateAfter.quantity, 0);
        assertEq(contractStateAfter.isLong, false);
        assertEq(contractStateAfter.initCumFunding, 0);
        assertFalse(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wbtcUsdcPerpProductId()
            )
        );
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 0);
        // 20k loss (-20k pnl)
        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 19500e18);
    }

    function test_Happy_closeExistingShortProfit() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            28000e18, // 2000 up
            2e18,
            true
        );

        // increment btc funding rate by $10 (longs must pay shorts)
        setFundingRate(defaults.wbtcUsdcPerpProductId(), 10e18);
        uint32 perpId = defaults.wbtcUsdcPerpProductId();
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                !initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(0, 0, false, 0)
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(0, 0, false, 0)
        );
        (, int256 aliceRealisedPnl) = perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            defaults.wbtcUsdcPerpProductId(),
            btcPerpPos
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            aliceSubAccount,
            address(usdc),
            int256(ciao.balances(aliceSubAccount, address(usdc))),
            int256(ciao.balances(aliceSubAccount, address(usdc))) +
                aliceRealisedPnl
        );
        ciao.settleCoreCollateral(aliceSubAccount, aliceRealisedPnl);
        // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wbtcUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 0);
        assertEq(contractStateAfter.quantity, 0);
        assertEq(contractStateAfter.isLong, false);
        assertEq(contractStateAfter.initCumFunding, 0);
        assertFalse(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wbtcUsdcPerpProductId()
            )
        );
        // $4020 profit (4000 pnl + 20 funding)
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 4520e18);
        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 0);
    }

    function test_Happy_reduceExistingShortLoss() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            32000e18, // 2000 down
            5e17,
            true
        );

        // increment btc funding rate by $0.5 (longs must pay shorts)
        setFundingRate(defaults.wbtcUsdcPerpProductId(), 5e17);
        uint32 perpId = defaults.wbtcUsdcPerpProductId();
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                !initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(30000e18, 15e17, true, -196e17)
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(30000e18, 15e17, false, -196e17)
        );
        (, int256 aliceRealisedPnl) = perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            defaults.wbtcUsdcPerpProductId(),
            btcPerpPos
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            aliceSubAccount,
            address(usdc),
            int256(ciao.balances(aliceSubAccount, address(usdc))),
            int256(ciao.balances(aliceSubAccount, address(usdc))) +
                aliceRealisedPnl
        );
        ciao.settleCoreCollateral(aliceSubAccount, aliceRealisedPnl);
        // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wbtcUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 30000e18);
        assertEq(contractStateAfter.quantity, 15e17);
        assertEq(contractStateAfter.isLong, false);
        assertEq(contractStateAfter.initCumFunding, -196e17);
        assertTrue(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wbtcUsdcPerpProductId()
            )
        );
        // $999 loss (-1k realised pnl + $1 funding)
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 0);
        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 499e18);
    }

    function test_Happy_reduceExistingShortProfit() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            25000e18, // 5000 up
            1e17,
            true
        );

        // decrement btc funding rate by $2 (shorts must pay longs)
        setFundingRate(defaults.wbtcUsdcPerpProductId(), -2e18);
        uint32 perpId = defaults.wbtcUsdcPerpProductId();
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                !initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(30000e18, 19e17, true, -221e17)
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(30000e18, 19e17, false, -221e17)
        );
        (, int256 aliceRealisedPnl) = perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            defaults.wbtcUsdcPerpProductId(),
            btcPerpPos
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            aliceSubAccount,
            address(usdc),
            int256(ciao.balances(aliceSubAccount, address(usdc))),
            int256(ciao.balances(aliceSubAccount, address(usdc))) +
                aliceRealisedPnl
        );
        ciao.settleCoreCollateral(aliceSubAccount, aliceRealisedPnl);
        // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wbtcUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 30000e18);
        assertEq(contractStateAfter.quantity, 19e17);
        assertEq(contractStateAfter.isLong, false);
        assertEq(contractStateAfter.initCumFunding, -221e17);
        assertTrue(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wbtcUsdcPerpProductId()
            )
        );
        // $496 profit ($500 realised pnl - $4 funding)
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 996e18);
        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 0);
    }

    function test_Happy_flipExistingShortLoss() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            30500e18, // 500 down
            7e18,
            true
        );

        // increment btc funding rate by $62 (longs must pay shorts)
        setFundingRate(defaults.wbtcUsdcPerpProductId(), 62e18);
        uint32 perpId = defaults.wbtcUsdcPerpProductId();
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                !initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(30500e18, 5e18, false, 419e17)
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(30500e18, 5e18, true, 419e17)
        );
        (, int256 aliceRealisedPnl) = perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            defaults.wbtcUsdcPerpProductId(),
            btcPerpPos
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            aliceSubAccount,
            address(usdc),
            int256(ciao.balances(aliceSubAccount, address(usdc))),
            int256(ciao.balances(aliceSubAccount, address(usdc))) +
                aliceRealisedPnl
        );
        ciao.settleCoreCollateral(aliceSubAccount, aliceRealisedPnl);
        // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wbtcUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 30500e18);
        assertEq(contractStateAfter.quantity, 5e18);
        assertEq(contractStateAfter.isLong, true);
        assertEq(contractStateAfter.initCumFunding, 419e17);
        assertTrue(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wbtcUsdcPerpProductId()
            )
        );
        // $876 loss (-$1000 realised pnl + $124 funding)
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 0);
        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 376e18);
    }

    function test_Happy_flipExistingShortProfit() public {
        // set initial position
        test_Happy_updateNewPosition();

        // update position
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            28500e18, // 1500 up
            10e18,
            true
        );

        // increment btc funding rate by 0.006 (longs must pay shorts)
        setFundingRate(defaults.wbtcUsdcPerpProductId(), 6e15);
        uint32 perpId = defaults.wbtcUsdcPerpProductId();
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            address(0),
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                !initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(28500e18, 8e18, false, -20094e15)
        );
        vm.expectEmit(address(perpCrucible));
        emit Events.PerpPositionUpdated(
            aliceSubAccount,
            perpId,
            Structs.PositionState(
                initialBtcPerpPos.executionPrice,
                initialBtcPerpPos.quantity,
                initialBtcPerpPos.isLong,
                -201e17
            ),
            Structs.PositionState(28500e18, 8e18, true, -20094e15)
        );
        (, int256 aliceRealisedPnl) = perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            defaults.wbtcUsdcPerpProductId(),
            btcPerpPos
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            aliceSubAccount,
            address(usdc),
            int256(ciao.balances(aliceSubAccount, address(usdc))),
            int256(ciao.balances(aliceSubAccount, address(usdc))) +
                aliceRealisedPnl
        );
        ciao.settleCoreCollateral(aliceSubAccount, aliceRealisedPnl);
        // get contract state after
        Structs.PositionState memory contractStateAfter = perpCrucible
            .getSubAccountPosition(
                defaults.wbtcUsdcPerpProductId(),
                aliceSubAccount
            );

        assertEq(contractStateAfter.avgEntryPrice, 28500e18);
        assertEq(contractStateAfter.quantity, 8e18);
        assertEq(contractStateAfter.isLong, true);
        assertEq(contractStateAfter.initCumFunding, -20094e15);
        assertTrue(
            perpCrucible.isPositionOpenForId(
                aliceSubAccount,
                defaults.wbtcUsdcPerpProductId()
            )
        );
        // $3000.012 profit ($3000 realised pnl + $0.012 funding)
        assertEq(ciao.balances(aliceSubAccount, address(usdc)), 3500012e15);
        assertEq(ciao.coreCollateralDebt(aliceSubAccount), 0);
    }

    function test_Happy_UpdateCumulativeFundings() public {
        int256 initFunding = perpCrucible.currentCumFunding(
            defaults.wbtcUsdcPerpProductId()
        );
        assertEq(initFunding, 0);

        // update funding snapshots
        uint32[] memory perpIds = new uint32[](2);
        perpIds[0] = defaults.wbtcUsdcPerpProductId();
        int256[] memory cumFundings = new int256[](2);
        cumFundings[0] = -1e17;
        bytes memory payload = abi.encodePacked(perpIds[0], cumFundings[0]);
        perpCrucible.updateCumulativeFundings(payload);

        int256 newFunding = perpCrucible.currentCumFunding(
            defaults.wbtcUsdcPerpProductId()
        );
        assertEq(newFunding, -1e17);
    }

    function test_Fail_UpdatePosition_Not_Authorised() public {
        Structs.NewPosition memory btcPerpPos = Structs.NewPosition(
            28500e18, // 1500 up
            10e18,
            true
        );
        uint32 wbtcUsdcPerpProductId = defaults.wbtcUsdcPerpProductId();
        vm.startPrank({msgSender: users.hackerman});
        vm.expectRevert("UNAUTHORIZED");
        perpCrucible.updatePosition(
            address(0),
            aliceSubAccount,
            wbtcUsdcPerpProductId,
            btcPerpPos
        );
    }

    function test_Fail_UpdateCumulativeFundings_Not_Authorised() public {
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
        vm.startPrank(users.hackerman);
        vm.expectRevert("UNAUTHORIZED");

        perpCrucible.updateCumulativeFundings(payload);
    }

    function test_Fail_UpdateFilledQuantitys_Not_Authorised() public {
        vm.startPrank(users.hackerman);
        vm.expectRevert("UNAUTHORIZED");

        perpCrucible.updateFilledQuantity(bytes32(0), bytes32(0), 0);
    }

    function test_Fail_UpdateCumulativeFundings_Invalid_Array_Length() public {
        // update funding snapshots
        uint32[] memory perpIds = new uint32[](1);
        perpIds[0] = defaults.wethUsdcPerpProductId();
        int256[] memory cumFundings = new int256[](2);
        cumFundings[0] = -1e17;
        cumFundings[1] = -1e17;
        bytes memory payload = abi.encodePacked(
            perpIds[0],
            cumFundings[0],
            cumFundings[1]
        );
        vm.expectRevert(bytes4(keccak256("OrderByteLengthInvalid()")));
        perpCrucible.updateCumulativeFundings(payload);
    }
}
