// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ciao} from "src/contracts/Ciao.sol";
import {Commons} from "src/contracts/libraries/Commons.sol";
import {Events} from "src/contracts/interfaces/Events.sol";
import {Errors} from "src/contracts/interfaces/Errors.sol";
import {Base_Test} from "../../Base.t.sol";

contract CiaoUpdateBalanceBaseTest is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        deployCiao();
    }

    function test_Happy_Update_Balance_Full_Balance_Account_2() public {
        depositAssetsToCiaoAndSwitchGov();
        address subAccount1 = Commons.getSubAccount(users.alice, 1);
        address subAccount2 = Commons.getSubAccount(users.dan, 1);
        uint256 wethQuantity = defaults.wethDepositQuantity();
        uint256 usdcQuantity = defaults.usdcDepositQuantityE18();
        ensureBalanceChangeEventsSpotMatch(
            usdcQuantity, wethQuantity, false, defaults.wethProductId(), 0, 0
        );
        ciao.updateBalance(
            subAccount1,
            subAccount2,
            wethQuantity,
            usdcQuantity,
            defaults.wethProductId(),
            true,
            0,
            0,
            0
        );
        assertEq(ciao.balances(subAccount1, address(usdc)), 0);
        assertEq(ciao.balances(subAccount1, address(weth)), defaults.wethDepositQuantity() * 2);
        assertEq(ciao.balances(subAccount2, address(weth)), 0);
        assertEq(ciao.balances(subAccount2, address(usdc)), usdcQuantity * 2);
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount1, address(weth)));
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount2, address(usdc)));
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount1, address(usdc)));
        assertFalse(ciao.isAssetInSubAccountAssetSet(subAccount2, address(weth)));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount1, 1), address(weth));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount2, 0), address(usdc));
        assertEq(ciao.subAccountAssetSetLength(subAccount1), 2);
        assertEq(ciao.subAccountAssetSetLength(subAccount2), 1);
        address[] memory subAccount1Assets = ciao.getSubAccountAssets(subAccount1);
        assertEq(subAccount1Assets[0], address(usdc));
        assertEq(subAccount1Assets.length, 2);
        address[] memory subAccount2Assets = ciao.getSubAccountAssets(subAccount2);
        assertEq(subAccount2Assets[0], address(usdc));
        assertEq(subAccount2Assets.length, 1);
    }

    function test_Happy_Update_Balance_Full_Balance_Account_2_With_Debt() public {
        depositAssetsToCiaoAndSwitchGov();
        address subAccount1 = Commons.getSubAccount(users.alice, 1);
        address subAccount2 = Commons.getSubAccount(users.dan, 1);
        uint256 wethQuantity = defaults.wethDepositQuantity();
        uint256 usdcQuantity = defaults.usdcDepositQuantityE18();
        int256 debtQuantity = -200e18;
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount2,
            address(usdc),
            int256(ciao.balances(subAccount2, address(usdc))),
            int256(ciao.balances(subAccount2, address(usdc))) - int256(usdcQuantity) + debtQuantity
        );
        ciao.settleCoreCollateral(subAccount2, -int256(usdcQuantity) + debtQuantity);
        assertEq(ciao.balances(subAccount2, address(usdc)), 0);
        assertEq(ciao.coreCollateralDebt(subAccount2), uint256(-debtQuantity));
        ensureBalanceChangeEventsSpotMatch(
            usdcQuantity, wethQuantity, false, defaults.wethProductId(), 0, 0
        );
        ciao.updateBalance(
            subAccount1,
            subAccount2,
            wethQuantity,
            usdcQuantity,
            defaults.wethProductId(),
            true,
            0,
            0,
            0
        );
        assertEq(ciao.balances(subAccount1, address(usdc)), 0);
        assertEq(ciao.balances(subAccount1, address(weth)), defaults.wethDepositQuantity() * 2);
        assertEq(ciao.balances(subAccount2, address(weth)), 0);
        assertEq(ciao.balances(subAccount2, address(usdc)), usdcQuantity - (uint256(-debtQuantity)));
        assertEq(ciao.coreCollateralDebt(subAccount2), 0);
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount1, address(weth)));
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount2, address(usdc)));
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount1, address(usdc)));
        assertFalse(ciao.isAssetInSubAccountAssetSet(subAccount2, address(weth)));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount1, 0), address(usdc));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount1, 1), address(weth));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount2, 0), address(usdc));
        assertEq(ciao.subAccountAssetSetLength(subAccount1), 2);
        assertEq(ciao.subAccountAssetSetLength(subAccount2), 1);
        address[] memory subAccount1Assets = ciao.getSubAccountAssets(subAccount1);
        assertEq(subAccount1Assets[0], address(usdc));
        assertEq(subAccount1Assets[1], address(weth));
        assertEq(subAccount1Assets.length, 2);
        address[] memory subAccount2Assets = ciao.getSubAccountAssets(subAccount2);
        assertEq(subAccount2Assets[0], address(usdc));
        assertEq(subAccount2Assets.length, 1);
    }

    function test_Happy_Update_Balance_Partial_Balance_Account_2() public {
        depositAssetsToCiaoAndSwitchGov();
        address subAccount1 = Commons.getSubAccount(users.alice, 1);
        address subAccount2 = Commons.getSubAccount(users.dan, 1);
        uint256 wethQuantity = defaults.wethDepositQuantity() / 2;
        uint256 usdcQuantity = defaults.usdcDepositQuantityE18() / 2;
        ensureBalanceChangeEventsSpotMatch(
            usdcQuantity, wethQuantity, false, defaults.wethProductId(), 0, 0
        );
        ciao.updateBalance(
            subAccount1,
            subAccount2,
            wethQuantity,
            usdcQuantity,
            defaults.wethProductId(),
            true,
            0,
            0,
            0
        );
        assertEq(ciao.balances(subAccount1, address(usdc)), defaults.usdcDepositQuantityE18() / 2);
        assertEq(
            ciao.balances(subAccount1, address(weth)),
            (defaults.wethDepositQuantity() * 3e18) / 2e18
        );
        assertEq(ciao.balances(subAccount2, address(weth)), defaults.wethDepositQuantity() / 2);
        assertEq(
            ciao.balances(subAccount2, address(usdc)),
            (defaults.usdcDepositQuantityE18() * 3e18) / 2e18
        );
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount1, address(weth)));
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount2, address(usdc)));
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount1, address(usdc)));
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount2, address(weth)));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount1, 0), address(usdc));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount1, 1), address(weth));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount2, 0), address(usdc));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount2, 1), address(weth));
        assertEq(ciao.subAccountAssetSetLength(subAccount1), 2);
        assertEq(ciao.subAccountAssetSetLength(subAccount2), 2);
        address[] memory subAccount1Assets = ciao.getSubAccountAssets(subAccount1);
        assertEq(subAccount1Assets[0], address(usdc));
        assertEq(subAccount1Assets[1], address(weth));
        assertEq(subAccount1Assets.length, 2);
        address[] memory subAccount2Assets = ciao.getSubAccountAssets(subAccount2);
        assertEq(subAccount2Assets[0], address(usdc));
        assertEq(subAccount2Assets[1], address(weth));
        assertEq(subAccount2Assets.length, 2);
    }

    function test_Happy_Update_Balance_Partial_Balance_Account_1() public {
        depositAssetsToCiaoAndSwitchGov();
        address subAccount1 = Commons.getSubAccount(users.alice, 1);
        address subAccount2 = Commons.getSubAccount(users.dan, 1);
        uint256 wethQuantity = defaults.wethDepositQuantity() / 2;
        uint256 usdcQuantity = defaults.usdcDepositQuantityE18() / 2;
        ensureBalanceChangeEventsSpotMatch(
            usdcQuantity, wethQuantity, true, defaults.wethProductId(), 0, 0
        );
        ciao.updateBalance(
            subAccount1,
            subAccount2,
            wethQuantity,
            usdcQuantity,
            defaults.wethProductId(),
            false,
            0,
            0,
            0
        );
        assertEq(ciao.balances(subAccount2, address(usdc)), usdcQuantity);
        assertEq(
            ciao.balances(subAccount2, address(weth)),
            (defaults.wethDepositQuantity() * 3e18) / 2e18
        );
        assertEq(ciao.balances(subAccount1, address(weth)), defaults.wethDepositQuantity() / 2);
        assertEq(
            ciao.balances(subAccount1, address(usdc)),
            (defaults.usdcDepositQuantityE18() * 3e18) / 2e18
        );
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount2, address(weth)));
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount1, address(usdc)));
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount2, address(usdc)));
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount1, address(weth)));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount2, 0), address(usdc));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount2, 1), address(weth));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount1, 0), address(usdc));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount1, 1), address(weth));
        assertEq(ciao.subAccountAssetSetLength(subAccount2), 2);
        assertEq(ciao.subAccountAssetSetLength(subAccount1), 2);
        address[] memory subAccount2Assets = ciao.getSubAccountAssets(subAccount2);
        assertEq(subAccount2Assets[0], address(usdc));
        assertEq(subAccount2Assets[1], address(weth));
        assertEq(subAccount2Assets.length, 2);
        address[] memory subAccount1Assets = ciao.getSubAccountAssets(subAccount2);
        assertEq(subAccount1Assets[0], address(usdc));
        assertEq(subAccount1Assets[1], address(weth));
        assertEq(subAccount1Assets.length, 2);
    }

    function test_Happy_Update_Balance_Full_Balance_Account_1_With_Debt() public {
        depositAssetsToCiaoAndSwitchGov();
        address subAccount1 = Commons.getSubAccount(users.alice, 1);
        address subAccount2 = Commons.getSubAccount(users.dan, 1);
        uint256 wethQuantity = defaults.wethDepositQuantity();
        uint256 usdcQuantity = defaults.usdcDepositQuantityE18();
        int256 debtQuantity = -200e18;
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount1,
            address(usdc),
            int256(ciao.balances(subAccount1, address(usdc))),
            int256(ciao.balances(subAccount1, address(usdc))) - int256(usdcQuantity) + debtQuantity
        );
        ciao.settleCoreCollateral(subAccount1, -int256(usdcQuantity) + debtQuantity);
        assertEq(ciao.balances(subAccount1, address(usdc)), 0);
        assertEq(ciao.coreCollateralDebt(subAccount1), uint256(-debtQuantity));
        ensureBalanceChangeEventsSpotMatch(
            usdcQuantity, wethQuantity, true, defaults.wethProductId(), 0, 0
        );
        ciao.updateBalance(
            subAccount1,
            subAccount2,
            wethQuantity,
            usdcQuantity,
            defaults.wethProductId(),
            false,
            0,
            0,
            0
        );
        assertEq(ciao.balances(subAccount2, address(usdc)), 0);
        assertEq(ciao.balances(subAccount2, address(weth)), wethQuantity * 2);
        assertEq(ciao.balances(subAccount1, address(weth)), 0);
        assertEq(ciao.balances(subAccount1, address(usdc)), usdcQuantity - (uint256(-debtQuantity)));
        assertEq(ciao.coreCollateralDebt(subAccount1), 0);
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount2, address(weth)));
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount1, address(usdc)));
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount2, address(usdc)));
        assertFalse(ciao.isAssetInSubAccountAssetSet(subAccount1, address(weth)));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount2, 1), address(weth));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount1, 0), address(usdc));
        assertEq(ciao.subAccountAssetSetLength(subAccount2), 2);
        assertEq(ciao.subAccountAssetSetLength(subAccount1), 1);
        address[] memory subAccount2Assets = ciao.getSubAccountAssets(subAccount2);
        assertEq(subAccount2Assets[0], address(usdc));
        assertEq(subAccount2Assets.length, 2);
        address[] memory subAccount1Assets = ciao.getSubAccountAssets(subAccount1);
        assertEq(subAccount1Assets[0], address(usdc));
        assertEq(subAccount1Assets.length, 1);
    }

    function test_Fail_Update_Balance_Account_1_Insufficient() public {
        depositAssetsToCiaoAndSwitchGov();
        address subAccount1 = Commons.getSubAccount(users.alice, 1);
        address subAccount2 = Commons.getSubAccount(users.dan, 1);
        uint256 wethQuantity = defaults.wethDepositQuantity();
        uint256 usdcQuantity = defaults.usdcDepositQuantityE18();
        uint32 wethProductId = defaults.wethProductId();
        vm.expectRevert(bytes4(keccak256("BalanceInsufficient()")));
        ciao.updateBalance(
            subAccount1, subAccount2, wethQuantity, usdcQuantity + 1, wethProductId, true, 0, 0, 0
        );
    }

    function test_Fail_Update_Balance_Account_2_Insufficient() public {
        depositAssetsToCiaoAndSwitchGov();
        address subAccount1 = Commons.getSubAccount(users.alice, 1);
        address subAccount2 = Commons.getSubAccount(users.dan, 1);
        uint256 wethQuantity = defaults.wethDepositQuantity();
        uint256 usdcQuantity = defaults.usdcDepositQuantity();
        uint32 wethProductId = defaults.wethProductId();
        vm.expectRevert(bytes4(keccak256("BalanceInsufficient()")));
        ciao.updateBalance(
            subAccount1, subAccount2, wethQuantity + 1, usdcQuantity, wethProductId, true, 0, 0, 0
        );
    }

    function test_Fail_Update_Balance_Account_2_Insufficient_Sell() public {
        depositAssetsToCiaoAndSwitchGov();
        address subAccount1 = Commons.getSubAccount(users.alice, 1);
        address subAccount2 = Commons.getSubAccount(users.dan, 1);
        uint256 wethQuantity = defaults.wethDepositQuantity();
        uint256 usdcQuantity = defaults.usdcDepositQuantityE18();
        uint32 wethProductId = defaults.wethProductId();
        vm.expectRevert(bytes4(keccak256("BalanceInsufficient()")));
        ciao.updateBalance(
            subAccount1, subAccount2, wethQuantity + 1, usdcQuantity, wethProductId, false, 0, 0, 0
        );
    }

    function test_Fail_Update_Balance_Account_1_Insufficient_Sell() public {
        depositAssetsToCiaoAndSwitchGov();
        address subAccount1 = Commons.getSubAccount(users.alice, 1);
        address subAccount2 = Commons.getSubAccount(users.dan, 1);
        uint256 wethQuantity = defaults.wethDepositQuantity();
        uint256 usdcQuantity = defaults.usdcDepositQuantityE18();
        uint32 wethProductId = defaults.wethProductId();
        vm.expectRevert(bytes4(keccak256("BalanceInsufficient()")));
        ciao.updateBalance(
            subAccount1, subAccount2, wethQuantity, usdcQuantity + 1, wethProductId, false, 0, 0, 0
        );
    }

    function test_Fail_UpdateBalance_NotDispatch() public {
        depositAssetsToCiao();
        vm.expectRevert("UNAUTHORIZED");
        ciao.updateBalance(users.alice, users.dan, 1, 1, 3, true, 0, 0, 0);
    }
}
