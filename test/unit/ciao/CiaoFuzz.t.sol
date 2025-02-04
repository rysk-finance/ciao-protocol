// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ciao} from "src/contracts/Ciao.sol";
import {Commons} from "src/contracts/libraries/Commons.sol";
import {Events} from "src/contracts/interfaces/Events.sol";
import {Errors} from "src/contracts/interfaces/Errors.sol";
import {Base_Test} from "../../Base.t.sol";

contract CiaoBaseTest is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        deployCiao();
    }

    function test_Deposit_Usdc_FuzzQuantity(uint128 quantity) public {
        validateAssets();
        usdc.approve(address(ciao), quantity);
        address subAccount = Commons.getSubAccount(users.gov, 1);
        if (quantity > 0 && quantity <= usdc.balanceOf(users.gov)) {
            expectCallToTransferFrom(users.gov, address(ciao), quantity);
            vm.expectEmit(address(ciao));
            emit Events.BalanceChanged(
                subAccount,
                address(usdc),
                int256(ciao.balances(subAccount, address(usdc))),
                int256(ciao.balances(subAccount, address(usdc))) +
                    int256(Commons.convertToE18(quantity, usdc.decimals()))
            );
            vm.expectEmit(address(ciao));
            emit Events.Deposit(users.gov, 1, address(usdc), quantity);
        }
        if (quantity == 0) {
            vm.expectRevert(bytes4(keccak256("DepositQuantityInvalid()")));
            ciao.deposit(users.gov, 1, quantity, address(usdc));
            return;
        }
        if (quantity > usdc.balanceOf(users.gov)) {
            vm.expectRevert("TRANSFER_FROM_FAILED");
            ciao.deposit(users.gov, 1, quantity, address(usdc));
            return;
        }
        ciao.deposit(users.gov, 1, quantity, address(usdc));
        assertEq(
            ciao.balances(subAccount, address(usdc)),
            Commons.convertToE18(quantity, usdc.decimals())
        );
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(usdc)));
        assertEq(
            ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0),
            address(usdc)
        );
        assertEq(ciao.subAccountAssetSetLength(subAccount), 1);
        address[] memory subAccountAssets = ciao.getSubAccountAssets(
            subAccount
        );
        assertEq(subAccountAssets[0], address(usdc));
        assertEq(subAccountAssets.length, 1);
    }

    function test_Deposit_Usdc_FuzzSubAccount(uint8 subAccountId) public {
        validateAssets();
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        address subAccount;
        if (subAccountId < 256) {
            subAccount = Commons.getSubAccount(users.gov, subAccountId);
            expectCallToTransferFrom(
                users.gov,
                address(ciao),
                defaults.usdcDepositQuantity()
            );
            vm.expectEmit(address(ciao));
            emit Events.BalanceChanged(
                subAccount,
                address(usdc),
                int256(ciao.balances(subAccount, address(usdc))),
                int256(ciao.balances(subAccount, address(usdc))) +
                    int256(
                        Commons.convertToE18(
                            defaults.usdcDepositQuantity(),
                            usdc.decimals()
                        )
                    )
            );
            vm.expectEmit(address(ciao));
            emit Events.Deposit(
                users.gov,
                subAccountId,
                address(usdc),
                defaults.usdcDepositQuantity()
            );
        } else {
            vm.expectRevert(bytes4(keccak256("SubAccountInvalid()")));
            ciao.deposit(users.gov, subAccountId, 1, address(usdc));
            return;
        }
        ciao.deposit(
            users.gov,
            subAccountId,
            defaults.usdcDepositQuantity(),
            address(usdc)
        );
        assertEq(
            ciao.balances(subAccount, address(usdc)),
            Commons.convertToE18(
                defaults.usdcDepositQuantity(),
                usdc.decimals()
            )
        );
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(usdc)));
        assertEq(
            ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0),
            address(usdc)
        );
        assertEq(ciao.subAccountAssetSetLength(subAccount), 1);
        address[] memory subAccountAssets = ciao.getSubAccountAssets(
            subAccount
        );
        assertEq(subAccountAssets[0], address(usdc));
        assertEq(subAccountAssets.length, 1);
    }

    function test_Withdraw_Full_Usdc_FuzzQuantity(uint128 quantity) public {
        depositAssetsToCiao();
        address subAccount = Commons.getSubAccount(users.alice, 1);
        address asset = address(usdc);
        uint256 balanceBefore = ciao.balances(subAccount, address(usdc));
        if (
            quantity > 0 &&
            quantity <=
            Commons.convertFromE18(
                ciao.balances(subAccount, address(usdc)),
                usdc.decimals()
            )
        ) {
            emit Events.RequestWithdrawal(users.alice, 1, asset, quantity);
            ciao.requestWithdrawal(1, quantity, asset);
            (uint256 _quantity, uint256 _requestTimestamp) = ciao
                .withdrawalReceipts(subAccount, asset);
            assertEq(
                Commons.convertToE18(quantity, usdc.decimals()),
                _quantity
            );
            assertEq(block.timestamp, _requestTimestamp);
            vm.warp(block.timestamp + 86400);
            expectCallToTransfer(users.alice, quantity);
            vm.expectEmit(address(ciao));
            emit Events.BalanceChanged(
                subAccount,
                address(usdc),
                int256(ciao.balances(subAccount, address(usdc))),
                int256(ciao.balances(subAccount, address(usdc))) -
                    int256(Commons.convertToE18(quantity, usdc.decimals()))
            );
            vm.expectEmit(address(ciao));
            emit Events.ExecuteWithdrawal(
                users.alice,
                1,
                address(usdc),
                quantity
            );
        } else {
            vm.expectRevert(bytes4(keccak256("WithdrawQuantityInvalid()")));
            ciao.requestWithdrawal(1, quantity, asset);
            return;
        }
        vm.startPrank(users.gov);
        ciao.executeWithdrawal(users.alice, 1, quantity, address(usdc));
        if (
            quantity == Commons.convertFromE18(balanceBefore, usdc.decimals())
        ) {
            assertEq(ciao.balances(subAccount, address(usdc)), 0);
            assertFalse(
                ciao.isAssetInSubAccountAssetSet(subAccount, address(usdc))
            );
            assertEq(
                ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0),
                address(weth)
            );
            assertEq(ciao.subAccountAssetSetLength(subAccount), 1);
        } else {
            assertEq(
                ciao.balances(subAccount, address(usdc)),
                balanceBefore - Commons.convertToE18(quantity, usdc.decimals())
            );
            assertTrue(
                ciao.isAssetInSubAccountAssetSet(subAccount, address(usdc))
            );
            assertEq(
                ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0),
                address(usdc)
            );
            assertEq(
                ciao.assetAtIndexInSubAccountAssetSet(subAccount, 1),
                address(weth)
            );
            assertEq(ciao.subAccountAssetSetLength(subAccount), 2);
        }
    }

    function test_Withdraw_Full_Weth_FuzzQuantity(uint256 quantity) public {
        depositAssetsToCiao();
        address subAccount = Commons.getSubAccount(users.alice, 1);
        address asset = address(weth);
        uint256 balanceBefore = ciao.balances(subAccount, address(weth));
        if (
            quantity > 0 && quantity <= ciao.balances(subAccount, address(weth))
        ) {
            emit Events.RequestWithdrawal(users.alice, 1, asset, quantity);
            ciao.requestWithdrawal(1, quantity, asset);
            (uint256 _quantity, uint256 _requestTimestamp) = ciao
                .withdrawalReceipts(subAccount, asset);
            assertEq(quantity, _quantity);
            assertEq(block.timestamp, _requestTimestamp);
            vm.warp(block.timestamp + 86400);
            expectCallToTransferToken(weth, users.alice, quantity);
            vm.expectEmit(address(ciao));
            emit Events.BalanceChanged(
                subAccount,
                address(weth),
                int256(ciao.balances(subAccount, address(weth))),
                int256(ciao.balances(subAccount, address(weth))) -
                    int256(quantity)
            );
            vm.expectEmit(address(ciao));
            emit Events.ExecuteWithdrawal(
                users.alice,
                1,
                address(weth),
                quantity
            );
        } else {
            vm.expectRevert(bytes4(keccak256("WithdrawQuantityInvalid()")));
            ciao.requestWithdrawal(1, quantity, asset);
            return;
        }
        vm.startPrank(users.gov);
        ciao.executeWithdrawal(users.alice, 1, quantity, address(weth));
        if (quantity == balanceBefore) {
            assertEq(ciao.balances(subAccount, address(weth)), 0);
            assertFalse(
                ciao.isAssetInSubAccountAssetSet(subAccount, address(weth))
            );
            assertEq(
                ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0),
                address(weth)
            );
            assertEq(ciao.subAccountAssetSetLength(subAccount), 1);
        } else {
            assertEq(
                ciao.balances(subAccount, address(weth)),
                balanceBefore - quantity
            );
            assertTrue(
                ciao.isAssetInSubAccountAssetSet(subAccount, address(weth))
            );
            assertEq(
                ciao.assetAtIndexInSubAccountAssetSet(subAccount, 1),
                address(weth)
            );
            assertEq(ciao.subAccountAssetSetLength(subAccount), 2);
        }
    }

    function testFuzz_Settle_Core_Collateral(
        int120 quantity1,
        int120 quantity2,
        int120 quantity3
    ) public {
        validateAssets();

        address subAccount = Commons.getSubAccount(users.alice, 1);
        if (quantity1 != 0) {
            vm.expectEmit(address(ciao));
            emit Events.BalanceChanged(
                subAccount,
                address(usdc),
                int256(ciao.balances(subAccount, address(usdc))) -
                    int256(ciao.coreCollateralDebt(subAccount)),
                int256(ciao.balances(subAccount, address(usdc))) -
                    int256(ciao.coreCollateralDebt(subAccount)) +
                    quantity1
            );
            ciao.settleCoreCollateral(subAccount, quantity1);
        }
        if (quantity2 != 0) {
            vm.expectEmit(address(ciao));
            emit Events.BalanceChanged(
                subAccount,
                address(usdc),
                int256(ciao.balances(subAccount, address(usdc))) -
                    int256(ciao.coreCollateralDebt(subAccount)),
                int256(ciao.balances(subAccount, address(usdc))) -
                    int256(ciao.coreCollateralDebt(subAccount)) +
                    quantity2
            );
            ciao.settleCoreCollateral(subAccount, quantity2);
        }
        if (quantity3 != 0) {
            vm.expectEmit(address(ciao));
            emit Events.BalanceChanged(
                subAccount,
                address(usdc),
                int256(ciao.balances(subAccount, address(usdc))) -
                    int256(ciao.coreCollateralDebt(subAccount)),
                int256(ciao.balances(subAccount, address(usdc))) -
                    int256(ciao.coreCollateralDebt(subAccount)) +
                    quantity3
            );
            ciao.settleCoreCollateral(subAccount, quantity3);
        }

        int256 expectedQuantity = int256(quantity1) +
            int256(quantity2) +
            int256(quantity3);
        uint256 expectedBalance = expectedQuantity > 0
            ? uint256(expectedQuantity)
            : 0;
        uint256 expectedDebt = expectedQuantity > 0
            ? 0
            : uint256(-expectedQuantity);

        assertEq(ciao.balances(subAccount, address(usdc)), expectedBalance);
        assertEq(ciao.coreCollateralDebt(subAccount), expectedDebt);
    }
}
