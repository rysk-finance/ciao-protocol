// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/contracts/libraries/Commons.sol";
import {Events} from "src/contracts/interfaces/Events.sol";
import {IProductCatalogue} from "src/contracts/interfaces/IProductCatalogue.sol";
import {Ciao} from "src/contracts/Ciao.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "src/contracts/libraries/BasicMath.sol";
import {Base_Test} from "../../Base.t.sol";
import {OrderDispatchBase} from "./OrderDispatchBase.t.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";

contract OrderDispatchWithdrawBaseTest is OrderDispatchBase {
    using MessageHashUtils for bytes32;

    function setUp() public virtual override {
        OrderDispatchBase.setUp();
        deployOrderDispatch();
        approval = Structs.ApproveSigner(users.alice, 1, users.keeper, true, uint64(1));
        takerOrder = Structs.Order(
            users.dan,
            1,
            2,
            true,
            uint8(0),
            uint8(1),
            2,
            1000e18,
            uint128(defaults.wethDepositQuantity()),
            1
        );
        makerOrder = Structs.Order(
            users.alice,
            1,
            2,
            false,
            uint8(0),
            uint8(1),
            2,
            1000e18,
            uint128(defaults.wethDepositQuantity()),
            1
        );
        (u1a1, u1a2, u2a1, u2a2, fa1, fa2) = getSpotBalances(
            Commons.getSubAccount(users.dan, 1),
            Commons.getSubAccount(users.alice, 1),
            address(usdc),
            address(weth)
        );
    }

    function test_Happy_Withdraw_Full_Usdc_No_Sig_But_Receipt() public {
        address subAccount = Commons.getSubAccount(users.alice, 1);
        uint256 quantity = defaults.usdcDepositQuantity();
        address asset = address(usdc);
        emit Events.RequestWithdrawal(users.alice, 1, asset, quantity);
        vm.startPrank(users.alice);
        ciao.requestWithdrawal(1, quantity, asset);
        (uint256 _quantity, uint256 _requestTimestamp) = ciao.withdrawalReceipts(subAccount, asset);
        assertEq(Commons.convertToE18(quantity, usdc.decimals()), _quantity);
        assertEq(block.timestamp, _requestTimestamp);
        expectCallToTransfer(users.alice, defaults.usdcDepositQuantity());
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc)))
                - int256(Commons.convertToE18(defaults.usdcDepositQuantity(), usdc.decimals()))
        );
        vm.expectEmit(address(ciao));
        emit Events.ExecuteWithdrawal(users.alice, 1, address(usdc), defaults.usdcDepositQuantity());
        constructWithdrawPayload(users.alice, 1, asset, quantity, "a");
        vm.startPrank(users.gov);
        orderDispatch.ingresso(transaction);
        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(usdc)));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0), address(usdc));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 1), address(weth));
        assertEq(ciao.subAccountAssetSetLength(subAccount), 2);
    }

    function test_Faul_Withdraw_Full_Usdc_No_Sig_But_Receipt_Incorrect_Amount_Under() public {
        address subAccount = Commons.getSubAccount(users.alice, 1);
        uint256 quantity = defaults.usdcDepositQuantity();
        address asset = address(usdc);
        emit Events.RequestWithdrawal(users.alice, 1, asset, quantity);
        vm.startPrank(users.alice);
        ciao.requestWithdrawal(1, quantity, asset);
        (uint256 _quantity, uint256 _requestTimestamp) = ciao.withdrawalReceipts(subAccount, asset);
        assertEq(Commons.convertToE18(quantity, usdc.decimals()), _quantity);
        assertEq(block.timestamp, _requestTimestamp);

        constructWithdrawPayload(users.alice, 1, asset, quantity - 1, "a");
        vm.startPrank(users.gov);
        vm.expectRevert(bytes4(keccak256("SignatureInvalid()")));
        orderDispatch.ingresso(transaction);

    }

    function test_Faul_Withdraw_Full_Usdc_No_Sig_But_Receipt_Incorrect_Amount_Over() public {
        address subAccount = Commons.getSubAccount(users.alice, 1);
        uint256 quantity = defaults.usdcDepositQuantity();
        address asset = address(usdc);
        emit Events.RequestWithdrawal(users.alice, 1, asset, quantity);
        vm.startPrank(users.alice);
        ciao.requestWithdrawal(1, quantity, asset);
        (uint256 _quantity, uint256 _requestTimestamp) = ciao.withdrawalReceipts(subAccount, asset);
        assertEq(Commons.convertToE18(quantity, usdc.decimals()), _quantity);
        assertEq(block.timestamp, _requestTimestamp);

        constructWithdrawPayload(users.alice, 1, asset, quantity + 1, "a");
        vm.startPrank(users.gov);
        vm.expectRevert(bytes4(keccak256("SignatureInvalid()")));
        orderDispatch.ingresso(transaction);

    }

    function test_Fail_cant_reuse_signature() public {
        address subAccount = Commons.getSubAccount(users.alice, 1);
        uint256 Quantity = defaults.usdcDepositQuantity();
        address asset = address(usdc);
        expectCallToTransfer(users.alice, defaults.usdcDepositQuantity());
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc)))
                - int256(Commons.convertToE18(defaults.usdcDepositQuantity(), usdc.decimals()))
        );
        vm.expectEmit(address(ciao));
        emit Events.ExecuteWithdrawal(users.alice, 1, address(usdc), defaults.usdcDepositQuantity());
        constructWithdrawPayload(users.alice, 1, asset, Quantity, "alice");
        orderDispatch.ingresso(transaction);
        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(usdc)));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0), address(usdc));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 1), address(weth));
        assertEq(ciao.subAccountAssetSetLength(subAccount), 2);
        vm.expectRevert(bytes4(keccak256("DigestedAlready()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Happy_Withdraw_Full_Usdc_No_Sig_No_Receipt() public {
        uint256 quantity = defaults.usdcDepositQuantity();
        address asset = address(usdc);
        constructWithdrawPayload(users.alice, 1, asset, quantity, "a");
        vm.expectRevert(bytes4(keccak256("SignatureInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Happy_Withdraw_Full_Usdc() public {
        address subAccount = Commons.getSubAccount(users.alice, 1);
        uint256 quantity = defaults.usdcDepositQuantity();
        address asset = address(usdc);
        expectCallToTransfer(users.alice, defaults.usdcDepositQuantity());
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc)))
                - int256(Commons.convertToE18(defaults.usdcDepositQuantity(), usdc.decimals()))
        );
        vm.expectEmit(address(ciao));
        emit Events.ExecuteWithdrawal(users.alice, 1, address(usdc), defaults.usdcDepositQuantity());
        constructWithdrawPayload(users.alice, 1, asset, quantity, "alice");
        orderDispatch.ingresso(transaction);
        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(usdc)));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0), address(usdc));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 1), address(weth));
        assertEq(ciao.subAccountAssetSetLength(subAccount), 2);
    }

    function test_Happy_Withdraw_Full_Usdc_With_Withdrawal_Fee() public {
        address subAccount = Commons.getSubAccount(users.alice, 1);
        uint256 quantity = defaults.usdcDepositQuantity();
        address asset = address(usdc);
        ciao.setWithdrawalFee(asset, 1e6);
        uint256 fee = ciao.withdrawalFees(asset);
        expectCallToTransfer(users.alice, defaults.usdcDepositQuantity() - fee);
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc)))
                - int256(Commons.convertToE18(defaults.usdcDepositQuantity(), usdc.decimals()))
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            ciao.feeRecipient(),
            address(usdc),
            0,
            int256(Commons.convertToE18(fee, usdc.decimals()))
        );
        vm.expectEmit(address(ciao));
        emit Events.ExecuteWithdrawal(users.alice, 1, address(usdc), defaults.usdcDepositQuantity());
        constructWithdrawPayload(users.alice, 1, asset, quantity, "alice");
        orderDispatch.ingresso(transaction);
        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertEq(
            ciao.balances(ciao.feeRecipient(), address(usdc)),
            Commons.convertToE18(fee, usdc.decimals())
        );
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(usdc)));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0), address(usdc));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 1), address(weth));
        assertEq(ciao.subAccountAssetSetLength(subAccount), 2);
    }

    function test_Fail_Withdraw_0() public {
        constructWithdrawPayload(users.alice, 1, address(weth), 0, "alice");
        vm.expectRevert(bytes4(keccak256("WithdrawQuantityInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Withdraw_less_then_withdrawal_fee() public {
        ciao.setWithdrawalFee(address(weth), 1e15);
        constructWithdrawPayload(users.alice, 1, address(weth), 1e14, "alice");
        vm.expectRevert(bytes4(keccak256("WithdrawQuantityInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Withdraw_TooMuch() public {
        uint256 quantity = defaults.wethDepositQuantity() + 1;
        constructWithdrawPayload(users.alice, 1, address(weth), quantity, "alice");
        vm.expectRevert(bytes4(keccak256("WithdrawQuantityInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Happy_Withdraw_Full_Weth() public {
        address subAccount = Commons.getSubAccount(users.alice, 1);
        uint256 quantity = defaults.wethDepositQuantity();
        address asset = address(weth);
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
        constructWithdrawPayload(users.alice, 1, asset, quantity, "alice");
        orderDispatch.ingresso(transaction);
        assertEq(ciao.balances(subAccount, asset), 0);
        assertFalse(ciao.isAssetInSubAccountAssetSet(subAccount, asset));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0), address(usdc));
        assertEq(ciao.subAccountAssetSetLength(subAccount), 1);
    }

    function test_Happy_Withdraw_Partial() public {
        address subAccount = Commons.getSubAccount(users.alice, 1);
        uint256 quantity = defaults.usdcDepositQuantity() / 2;
        address asset = address(usdc);
        expectCallToTransfer(users.alice, defaults.usdcDepositQuantity() / 2);
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc)))
                - int256(Commons.convertToE18(quantity, usdc.decimals()))
        );
        vm.expectEmit(address(ciao));
        emit Events.ExecuteWithdrawal(users.alice, 1, asset, quantity);
        constructWithdrawPayload(users.alice, 1, asset, quantity, "alice");
        orderDispatch.ingresso(transaction);
        assertEq(
            ciao.balances(subAccount, address(usdc)),
            Commons.convertToE18(defaults.usdcDepositQuantity(), usdc.decimals()) / 2
        );
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(usdc)));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0), address(usdc));
        assertEq(ciao.subAccountAssetSetLength(subAccount), 2);
    }

    function test_Happy_Withdraw_Multiple() public {
        address subAccount = Commons.getSubAccount(users.alice, 1);
        uint256 quantity = defaults.usdcDepositQuantity();
        address asset = address(usdc);
        expectCallToTransfer(users.alice, defaults.usdcDepositQuantity());
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc)))
                - int256(Commons.convertToE18(quantity, usdc.decimals()))
        );
        vm.expectEmit(address(ciao));
        emit Events.ExecuteWithdrawal(users.alice, 1, address(usdc), defaults.usdcDepositQuantity());
        constructWithdrawPayload(users.alice, 1, asset, quantity, "alice");
        orderDispatch.ingresso(transaction);
        assertEq(ciao.balances(subAccount, address(usdc)), 0);
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(usdc)));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0), address(usdc));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 1), address(weth));
        assertEq(ciao.subAccountAssetSetLength(subAccount), 2);
        quantity = defaults.wethDepositQuantity();
        asset = address(weth);
        expectCallToTransferToken(weth, users.alice, defaults.wethDepositQuantity());
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(weth),
            int256(ciao.balances(subAccount, address(weth))),
            int256(ciao.balances(subAccount, address(weth))) - int256(quantity)
        );
        vm.expectEmit(address(ciao));
        emit Events.ExecuteWithdrawal(users.alice, 1, address(weth), defaults.wethDepositQuantity());
        constructWithdrawPayload(users.alice, 1, asset, quantity, "alice");
        orderDispatch.ingresso(transaction);
        assertEq(ciao.balances(subAccount, address(weth)), 0);
        assertFalse(ciao.isAssetInSubAccountAssetSet(subAccount, address(weth)));
        assertEq(ciao.subAccountAssetSetLength(subAccount), 1);
    }

    function test_Fail_Bad_Payload_Shape() public {
        constructWithdrawPayload(users.gov, 0, address(usdc), defaults.usdcDepositQuantity(), "gov");
        transaction[0] = abi.encodePacked(transaction[0], uint8(0));
        vm.expectRevert(bytes4(keccak256("OrderByteLengthInvalid()")));
        orderDispatch.ingresso(transaction);
    }
}
