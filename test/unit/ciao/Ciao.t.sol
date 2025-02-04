// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ciao} from "src/contracts/Ciao.sol";
import {Commons} from "src/contracts/libraries/Commons.sol";
import {Events} from "src/contracts/interfaces/Events.sol";
import {Errors} from "src/contracts/interfaces/Errors.sol";
import {Base_Test} from "../../Base.t.sol";
import "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract CiaoBaseTest is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        deployCiao();
        address newCiaoImpl = address(new Ciao());
        ciaoProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(ciaoProxy)),
            newCiaoImpl,
            bytes("")
        );
        assertEq(
            address(
                uint160(
                    uint256(
                        vm.load(
                            address(ciaoProxy),
                            ERC1967Utils.IMPLEMENTATION_SLOT
                        )
                    )
                )
            ),
            newCiaoImpl
        );
    }

    function test_Happy_Deposit_Usdc() public {
        validateAssets();
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        address subAccount = Commons.getSubAccount(users.gov, 0);
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
            0,
            address(usdc),
            defaults.usdcDepositQuantity()
        );
        ciao.deposit(
            users.gov,
            0,
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
        assertEq(ciao.depositCount(subAccount), 1);
    }

    function test_Happy_ProxyAdmin_Can_Upgrade() public {
        address newCiaoImpl = address(new Ciao());
        ciaoProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(ciaoProxy)),
            newCiaoImpl,
            bytes("")
        );
        assertEq(
            address(
                uint160(
                    uint256(
                        vm.load(
                            address(ciaoProxy),
                            ERC1967Utils.IMPLEMENTATION_SLOT
                        )
                    )
                )
            ),
            newCiaoImpl
        );
    }

    function test_Happy_Deposit_Reduces_Usdc_Debt() public {
        validateAssets();
        int256 debtQuantity = -200e18;
        address subAccount = Commons.getSubAccount(users.gov, 0);
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc))) + debtQuantity
        );
        ciao.settleCoreCollateral(subAccount, debtQuantity);
        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertEq(ciao.coreCollateralDebt(subAccount), uint256(-debtQuantity));
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        expectCallToTransferFrom(
            users.gov,
            address(ciao),
            defaults.usdcDepositQuantity()
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))) -
                int256(ciao.coreCollateralDebt(subAccount)),
            int256(ciao.balances(subAccount, address(usdc))) -
                int256(ciao.coreCollateralDebt(subAccount)) +
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
            0,
            address(usdc),
            defaults.usdcDepositQuantity()
        );
        ciao.deposit(
            users.gov,
            0,
            defaults.usdcDepositQuantity(),
            address(usdc)
        );
        assertEq(
            ciao.balances(subAccount, address(usdc)),
            Commons.convertToE18(
                defaults.usdcDepositQuantity(),
                usdc.decimals()
            ) - (uint256(-debtQuantity))
        );
        assertEq(ciao.coreCollateralDebt(subAccount), 0);
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
        assertEq(ciao.depositCount(subAccount), 1);
    }

    function test_Happy_Deposit_Reduces_Usdc_Debt_But_Still_Debt() public {
        validateAssets();
        int256 debtQuantity = -1000e18;
        uint256 depositQuantity = 500 * 10 ** usdc.decimals();
        address subAccount = Commons.getSubAccount(users.gov, 0);
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc))) + debtQuantity
        );
        ciao.settleCoreCollateral(subAccount, debtQuantity);
        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertEq(ciao.coreCollateralDebt(subAccount), uint256(-debtQuantity));
        usdc.approve(address(ciao), depositQuantity);
        expectCallToTransferFrom(users.gov, address(ciao), depositQuantity);
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))) -
                int256(ciao.coreCollateralDebt(subAccount)),
            int256(ciao.balances(subAccount, address(usdc))) -
                int256(ciao.coreCollateralDebt(subAccount)) +
                int256(Commons.convertToE18(depositQuantity, usdc.decimals()))
        );
        vm.expectEmit(address(ciao));
        emit Events.Deposit(users.gov, 0, address(usdc), depositQuantity);
        ciao.deposit(users.gov, 0, depositQuantity, address(usdc));
        assertEq(ciao.depositCount(subAccount), 1);
        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertEq(ciao.coreCollateralDebt(subAccount), 500e18);
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

    function test_Fail_Deposit_Usdc_0() public {
        validateAssets();
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        vm.expectRevert(bytes4(keccak256("DepositQuantityInvalid()")));
        ciao.deposit(users.gov, 1, 0, address(usdc));
    }

    function test_Fail_Deposit_if_requires_dispatch_call() public {
        validateAssets();
        ciao.setRequiresDispatchCall(true);
        vm.startPrank(users.alice);
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        vm.expectRevert(bytes4(keccak256("SenderInvalid()")));
        ciao.deposit(users.alice, 1, 0, address(usdc));
    }

    function test_Fail_Hackerman_depositing_with_someone_else() public {
        validateAssets();
        vm.startPrank(users.hackerman);
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        vm.expectRevert(bytes4(keccak256("SenderInvalid()")));
        ciao.deposit(users.gov, 1, 0, address(usdc));
    }

    function test_Fail_Deposit_Usdc_InvalidProduct() public {
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        vm.expectRevert(bytes4(keccak256("ProductInvalid()")));
        ciao.deposit(users.gov, 1, 1, users.gov);
    }

    function test_Happy_Deposit_Weth() public {
        validateAssets();
        weth.approve(address(ciao), defaults.wethDepositQuantity());
        address subAccount = Commons.getSubAccount(users.gov, 1);
        expectCallToTransferFromToken(
            weth,
            users.gov,
            address(ciao),
            defaults.wethDepositQuantity()
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(weth),
            int256(ciao.balances(subAccount, address(weth))),
            int256(ciao.balances(subAccount, address(weth))) +
                int256(defaults.wethDepositQuantity())
        );
        vm.expectEmit(address(ciao));
        emit Events.Deposit(
            users.gov,
            1,
            address(weth),
            defaults.wethDepositQuantity()
        );
        ciao.deposit(
            users.gov,
            1,
            defaults.wethDepositQuantity(),
            address(weth)
        );
        assertEq(ciao.depositCount(subAccount), 1);
        assertEq(
            ciao.balances(subAccount, address(weth)),
            Commons.convertToE18(defaults.wethDepositQuantity(), 18)
        );
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(weth)));
        assertEq(
            ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0),
            address(weth)
        );
        assertEq(ciao.subAccountAssetSetLength(subAccount), 1);
    }

    function test_Happy_Deposit_Multiple() public {
        validateAssets();
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        address subAccount = Commons.getSubAccount(users.gov, 0);
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
            0,
            address(usdc),
            defaults.usdcDepositQuantity()
        );
        ciao.deposit(
            users.gov,
            0,
            defaults.usdcDepositQuantity(),
            address(usdc)
        );
        assertEq(ciao.depositCount(subAccount), 1);
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
        weth.approve(address(ciao), defaults.wethDepositQuantity());
        expectCallToTransferFromToken(
            weth,
            users.gov,
            address(ciao),
            defaults.wethDepositQuantity()
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(weth),
            int256(ciao.balances(subAccount, address(weth))),
            int256(ciao.balances(subAccount, address(weth))) +
                int256(defaults.wethDepositQuantity())
        );
        vm.expectEmit(address(ciao));
        emit Events.Deposit(
            users.gov,
            0,
            address(weth),
            defaults.wethDepositQuantity()
        );
        ciao.deposit(
            users.gov,
            0,
            defaults.wethDepositQuantity(),
            address(weth)
        );
        assertEq(ciao.depositCount(subAccount), 2);
        assertEq(
            ciao.balances(subAccount, address(weth)),
            Commons.convertToE18(defaults.wethDepositQuantity(), 18)
        );
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(weth)));
        assertEq(
            ciao.assetAtIndexInSubAccountAssetSet(subAccount, 1),
            address(weth)
        );
        assertEq(ciao.subAccountAssetSetLength(subAccount), 2);
    }

    function test_Happy_Withdraw_Full_Usdc() public {
        depositAssetsToCiao();
        address subAccount = Commons.getSubAccount(users.alice, 1);
        uint256 quantity = defaults.usdcDepositQuantity();
        address asset = address(usdc);
        vm.expectEmit(address(ciao));
        emit Events.RequestWithdrawal(users.alice, 1, asset, quantity);
        ciao.requestWithdrawal(1, quantity, asset);
        (uint256 _quantity, uint256 _requestTimestamp) = ciao
            .withdrawalReceipts(subAccount, asset);
        assertEq(Commons.convertToE18(quantity, usdc.decimals()), _quantity);
        assertEq(block.timestamp, _requestTimestamp);
        vm.warp(block.timestamp + 86400);
        expectCallToTransfer(users.alice, defaults.usdcDepositQuantity());
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc))) -
                int256(
                    Commons.convertToE18(
                        defaults.usdcDepositQuantity(),
                        usdc.decimals()
                    )
                )
        );
        vm.expectEmit(address(ciao));
        emit Events.ExecuteWithdrawal(
            users.alice,
            1,
            address(usdc),
            defaults.usdcDepositQuantity()
        );
        vm.startPrank(users.gov);
        ciao.executeWithdrawal(
            users.alice,
            1,
            defaults.usdcDepositQuantity(),
            address(usdc)
        );
        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(usdc)));
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

    function test_Fail_Withdraw_0() public {
        depositAssetsToCiaoAndSwitchGov();
        vm.expectRevert(bytes4(keccak256("WithdrawQuantityInvalid()")));
        ciao.executeWithdrawal(users.alice, 1, 0, address(weth));
    }

    function test_Fail_Withdraw_TooMuch() public {
        depositAssetsToCiaoAndSwitchGov();
        uint256 quantity = defaults.usdcDepositQuantity() + 1;
        vm.expectRevert(bytes4(keccak256("WithdrawQuantityInvalid()")));
        ciao.executeWithdrawal(users.alice, 1, quantity, address(usdc));
    }

    function test_Happy_Request_Withdraw() public {
        depositAssetsToCiao();
        address subAccount = Commons.getSubAccount(users.alice, 1);
        uint256 quantity = defaults.wethDepositQuantity();
        emit Events.RequestWithdrawal(users.alice, 1, address(usdc), quantity);
        ciao.requestWithdrawal(1, quantity, address(weth));
        (uint256 _quantity, uint256 _requestTimestamp) = ciao
            .withdrawalReceipts(subAccount, address(weth));
        assertEq(quantity, _quantity);
        assertEq(block.timestamp, _requestTimestamp);
    }

    function test_Fail_Request_Withdraw_When_Require_Dispatch_Call_On() public {
        depositAssetsToCiaoAndSwitchGov();
        ciao.setRequiresDispatchCall(true);
        vm.expectRevert(bytes4(keccak256("SenderInvalid()")));
        ciao.requestWithdrawal(1, 0, address(weth));
    }

    function test_Fail_Request_Withdraw_0_Quantity() public {
        depositAssetsToCiaoAndSwitchGov();
        vm.expectRevert(bytes4(keccak256("WithdrawQuantityInvalid()")));
        ciao.requestWithdrawal(1, 0, address(weth));
    }

    function test_Happy_Withdraw_Full_Weth() public {
        depositAssetsToCiao();
        address subAccount = Commons.getSubAccount(users.alice, 1);
        uint256 quantity = defaults.wethDepositQuantity();
        address asset = address(weth);
        vm.expectEmit(address(ciao));
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
            int256(ciao.balances(subAccount, address(weth))) - int256(quantity)
        );
        vm.expectEmit(address(ciao));
        emit Events.ExecuteWithdrawal(users.alice, 1, asset, quantity);
        vm.startPrank(users.gov);
        ciao.executeWithdrawal(users.alice, 1, quantity, asset);
        assertEq(ciao.balances(subAccount, asset), 0);
        assertFalse(ciao.isAssetInSubAccountAssetSet(subAccount, asset));
        assertEq(
            ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0),
            address(usdc)
        );
        assertEq(ciao.subAccountAssetSetLength(subAccount), 1);
    }

    function test_Happy_Withdraw_Partial() public {
        depositAssetsToCiao();
        address subAccount = Commons.getSubAccount(users.alice, 1);
        uint256 quantity = defaults.usdcDepositQuantity() / 2;
        address asset = address(usdc);
        vm.expectEmit(address(ciao));
        emit Events.RequestWithdrawal(users.alice, 1, asset, quantity);
        ciao.requestWithdrawal(1, quantity, asset);
        (uint256 _quantity, uint256 _requestTimestamp) = ciao
            .withdrawalReceipts(subAccount, asset);
        assertEq(Commons.convertToE18(quantity, usdc.decimals()), _quantity);
        assertEq(block.timestamp, _requestTimestamp);
        vm.warp(block.timestamp + 86400);
        expectCallToTransfer(users.alice, defaults.usdcDepositQuantity() / 2);
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc))) -
                int256(Commons.convertToE18(quantity, usdc.decimals()))
        );
        vm.expectEmit(address(ciao));
        emit Events.ExecuteWithdrawal(users.alice, 1, asset, quantity);
        vm.startPrank(users.gov);
        ciao.executeWithdrawal(users.alice, 1, quantity, asset);
        assertEq(
            ciao.balances(subAccount, address(usdc)),
            Commons.convertToE18(
                defaults.usdcDepositQuantity(),
                usdc.decimals()
            ) / 2
        );
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(usdc)));
        assertEq(
            ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0),
            address(usdc)
        );
        assertEq(ciao.subAccountAssetSetLength(subAccount), 2);
    }

    function test_Happy_Withdraw_Multiple() public {
        depositAssetsToCiao();
        address subAccount = Commons.getSubAccount(users.alice, 1);
        uint256 quantity = defaults.usdcDepositQuantity();
        address asset = address(usdc);
        vm.expectEmit(address(ciao));
        emit Events.RequestWithdrawal(users.alice, 1, asset, quantity);
        ciao.requestWithdrawal(1, quantity, asset);
        (uint256 _quantity, uint256 _requestTimestamp) = ciao
            .withdrawalReceipts(subAccount, asset);
        assertEq(Commons.convertToE18(quantity, usdc.decimals()), _quantity);
        assertEq(block.timestamp, _requestTimestamp);
        vm.warp(block.timestamp + 86400);
        expectCallToTransfer(users.alice, defaults.usdcDepositQuantity());
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
            defaults.usdcDepositQuantity()
        );
        vm.startPrank(users.gov);
        ciao.executeWithdrawal(
            users.alice,
            1,
            defaults.usdcDepositQuantity(),
            address(usdc)
        );
        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(usdc)));
        assertEq(
            ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0),
            address(usdc)
        );
        assertEq(
            ciao.assetAtIndexInSubAccountAssetSet(subAccount, 1),
            address(weth)
        );
        assertEq(ciao.subAccountAssetSetLength(subAccount), 2);
        vm.startPrank(users.alice);
        quantity = defaults.wethDepositQuantity();
        asset = address(weth);
        vm.expectEmit(address(ciao));
        emit Events.RequestWithdrawal(users.alice, 1, asset, quantity);
        ciao.requestWithdrawal(1, quantity, asset);
        (_quantity, _requestTimestamp) = ciao.withdrawalReceipts(
            subAccount,
            asset
        );
        assertEq(quantity, _quantity);
        assertEq(block.timestamp, _requestTimestamp);
        vm.warp(block.timestamp + 86400);
        expectCallToTransferToken(
            weth,
            users.alice,
            defaults.wethDepositQuantity()
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(weth),
            int256(ciao.balances(subAccount, address(weth))),
            int256(ciao.balances(subAccount, address(weth))) - int256(quantity)
        );
        vm.expectEmit(address(ciao));
        emit Events.ExecuteWithdrawal(
            users.alice,
            1,
            address(weth),
            defaults.wethDepositQuantity()
        );
        vm.startPrank(users.gov);
        ciao.executeWithdrawal(
            users.alice,
            1,
            defaults.wethDepositQuantity(),
            address(weth)
        );
        assertEq(ciao.balances(subAccount, address(weth)), 0);
        assertFalse(
            ciao.isAssetInSubAccountAssetSet(subAccount, address(weth))
        );
        assertEq(ciao.subAccountAssetSetLength(subAccount), 1);
    }

    function test_Happy_Settle_Positive_Core_Collateral_No_Debt() public {
        validateAssets();

        address subAccount = Commons.getSubAccount(users.alice, 1);
        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertEq(ciao.coreCollateralDebt(subAccount), 0);

        int256 quantity = 500e18;
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc))) + quantity
        );
        ciao.settleCoreCollateral(subAccount, quantity);

        assertEq(ciao.balances(subAccount, address(usdc)), 500e18);
        assertEq(ciao.coreCollateralDebt(subAccount), 0);
    }

    function test_Happy_Settle_Negative_Core_Collateral_No_Debt() public {
        validateAssets();

        address subAccount = Commons.getSubAccount(users.alice, 1);
        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertEq(ciao.coreCollateralDebt(subAccount), 0);

        int256 quantity = 500e18;
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc))) + quantity
        );
        ciao.settleCoreCollateral(subAccount, quantity);

        assertEq(ciao.balances(subAccount, address(usdc)), 500e18);
        assertEq(ciao.coreCollateralDebt(subAccount), 0);

        int256 quantity2 = -700e18;
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc))) + quantity2
        );
        ciao.settleCoreCollateral(subAccount, quantity2);

        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertEq(ciao.coreCollateralDebt(subAccount), 200e18);
    }

    function test_Happy_Settle_Negative_Core_Collateral_With_Debt() public {
        validateAssets();

        address subAccount = Commons.getSubAccount(users.alice, 1);
        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertEq(ciao.coreCollateralDebt(subAccount), 0);

        int256 quantity = -500e18;
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc))) + quantity
        );
        ciao.settleCoreCollateral(subAccount, quantity);

        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertEq(ciao.coreCollateralDebt(subAccount), 500e18);

        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))) -
                int256(ciao.coreCollateralDebt(subAccount)),
            int256(ciao.balances(subAccount, address(usdc))) -
                int256(ciao.coreCollateralDebt(subAccount)) +
                quantity
        );
        ciao.settleCoreCollateral(subAccount, quantity);

        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertEq(ciao.coreCollateralDebt(subAccount), 1000e18);
    }

    function test_Happy_Settle_Positive_Core_Collateral_With_Debt() public {
        validateAssets();

        address subAccount = Commons.getSubAccount(users.alice, 1);
        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertEq(ciao.coreCollateralDebt(subAccount), 0);

        int256 quantity = -500e18;
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc))) + quantity
        );
        ciao.settleCoreCollateral(subAccount, quantity);

        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertEq(ciao.coreCollateralDebt(subAccount), 500e18);

        int256 quantity2 = 700e18;
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

        assertEq(ciao.balances(subAccount, address(usdc)), 200e18);
        assertEq(ciao.coreCollateralDebt(subAccount), 0);
    }

    function test_Fail_SettleCoreCollateral_Not_Authorised() public {
        address subAccount = Commons.getSubAccount(users.alice, 1);
        vm.startPrank({msgSender: users.hackerman});
        vm.expectRevert("UNAUTHORIZED");
        ciao.settleCoreCollateral(subAccount, 1e18);
    }

    function test_Fail_IncrementFee_Not_Authorised() public {
        vm.startPrank({msgSender: users.hackerman});
        address recipient = ciao.feeRecipient();
        vm.expectRevert("UNAUTHORIZED");
        ciao.incrementFee(address(usdc), 1e18, recipient);
    }

    function test_Happy_Set_FeeRecipient() public {
        vm.expectEmit(address(ciao));
        emit Events.FeeRecipientChanged(users.gov);
        ciao.setFeeRecipient(users.gov);
        assertEq(ciao.feeRecipient(), users.gov);
    }

    function test_Fail_Set_FeeRecipientAddress_unauth() public {
        vm.expectRevert();
        ciao.setFeeRecipient(address(0));
        vm.startPrank({msgSender: users.hackerman});
        vm.expectRevert("UNAUTHORIZED");
        ciao.setFeeRecipient(address(0));
    }

    function test_Happy_Set_Insurance() public {
        vm.expectEmit(address(ciao));
        emit Events.InsuranceChanged(users.gov);
        ciao.setInsurance(users.gov);
        assertEq(ciao.insurance(), users.gov);
    }

    function test_Fail_Set_InsuranceAddress_unauth() public {
        vm.expectRevert();
        ciao.setInsurance(address(0));
        vm.startPrank({msgSender: users.hackerman});
        vm.expectRevert("UNAUTHORIZED");
        ciao.setInsurance(address(0));
    }

    function test_Fail_Withdraw_Invalid_Sender() public {
        depositAssetsToCiaoAndSwitchGov();
        uint256 quantity = defaults.wethDepositQuantity();
        vm.startPrank(users.hackerman);
        vm.expectRevert(bytes4(keccak256("SenderInvalid()")));
        ciao.executeWithdrawal(users.alice, 1, quantity, address(weth));
    }

    function test_Happy_Set_MinDepositAmount() public {
        vm.expectEmit(address(ciao));
        emit Events.MinDepositAmountChanged(address(usdc), 10e6);
        ciao.setMinDepositAmount(address(usdc), 10e6);
        assertEq(ciao.minDepositAmount(address(usdc)), 10e6);
    }

    function test_Fail_Deposit_Usdc_LessThanMin() public {
        validateAssets();
        ciao.setMinDepositAmount(address(usdc), 10e6);
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        vm.expectRevert(bytes4(keccak256("DepositQuantityInvalid()")));
        ciao.deposit(users.gov, 1, 5e6, address(usdc));
    }
}
