// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/contracts/libraries/Commons.sol";
import {AddressManifest} from "src/contracts/AddressManifest.sol";
import {Events} from "src/contracts/interfaces/Events.sol";
import {IProductCatalogue} from "src/contracts/interfaces/IProductCatalogue.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "src/contracts/libraries/BasicMath.sol";
import {Base_Test} from "../../Base.t.sol";
import {OrderDispatchBase} from "./OrderDispatchBase.t.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";

contract OrderDispatchApproveSignerBaseTest is OrderDispatchBase {
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
            uint8(0),
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

    function test_Happy_Approve_Signer_Sig_alice_1_app_dan() public {
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(
            approval.account, approval.subAccountId, approval.approvedSigner, approval.isApproved
        );
        constructApproveSignerPayload("alice", 1);
        orderDispatch.ingresso(transaction);
        address subAccount = Commons.getSubAccount(users.alice, 1);
        assertTrue(addressManifest.approvedSigners(subAccount, users.keeper));
    }

    function test_Fail_Cannot_Reuse_Signature() public {
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(
            approval.account, approval.subAccountId, approval.approvedSigner, approval.isApproved
        );
        constructApproveSignerPayload("alice", 1);
        orderDispatch.ingresso(transaction);
        address subAccount = Commons.getSubAccount(users.alice, 1);
        assertTrue(addressManifest.approvedSigners(subAccount, users.keeper));
        vm.expectRevert(bytes4(keccak256("DigestedAlready()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Happy_Approve_Signer_Sig_alice_2_app_dan() public {
        approval.subAccountId = 2;
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(
            approval.account, approval.subAccountId, approval.approvedSigner, approval.isApproved
        );
        constructApproveSignerPayload("alice", 1);
        orderDispatch.ingresso(transaction);
        address subAccount = Commons.getSubAccount(users.alice, 2);
        assertTrue(addressManifest.approvedSigners(subAccount, users.keeper));
    }

    function test_Happy_Approve_Signer_multiple() public {
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(
            approval.account, approval.subAccountId, approval.approvedSigner, approval.isApproved
        );
        constructApproveSignerPayload("alice", 1);
        orderDispatch.ingresso(transaction);
        address subAccount = Commons.getSubAccount(users.alice, 1);
        assertTrue(addressManifest.approvedSigners(subAccount, users.keeper));
        approval.isApproved = false;
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(
            approval.account, approval.subAccountId, approval.approvedSigner, approval.isApproved
        );
        constructApproveSignerPayload("alice", 1);
        orderDispatch.ingresso(transaction);
        subAccount = Commons.getSubAccount(users.alice, 1);
        assertFalse(addressManifest.approvedSigners(subAccount, users.keeper));
    }

    function test_Fail_Approve_Signer_cant_approve_Signers() public {
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(
            approval.account, approval.subAccountId, approval.approvedSigner, approval.isApproved
        );
        constructApproveSignerPayload("alice", 1);
        orderDispatch.ingresso(transaction);
        address subAccount = Commons.getSubAccount(users.alice, 1);
        assertTrue(addressManifest.approvedSigners(subAccount, users.keeper));
        approval.isApproved = true;
        constructApproveSignerPayload("keeper", 2);
        vm.expectRevert(bytes4(keccak256("SignatureInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Happy_Approve_Signer_Batch() public {
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(
            approval.account, approval.subAccountId, approval.approvedSigner, approval.isApproved
        );
        constructApproveSignerPayload("alice", 1);
        approval.account = users.dan;
        approval.subAccountId = 2;
        approval.approvedSigner = users.gov;
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(
            approval.account, approval.subAccountId, approval.approvedSigner, approval.isApproved
        );
        appendApproveSignerPayload("dan", 1);
        orderDispatch.ingresso(transaction);
        address subAccount = Commons.getSubAccount(users.alice, 1);
        assertTrue(addressManifest.approvedSigners(subAccount, users.keeper));
        subAccount = Commons.getSubAccount(users.dan, 2);
        assertTrue(addressManifest.approvedSigners(subAccount, users.gov));
    }

    function test_Happy_Approve_Signer_Batch_true_false() public {
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(
            approval.account, approval.subAccountId, approval.approvedSigner, approval.isApproved
        );
        constructApproveSignerPayload("alice", 1);
        approval.account = users.dan;
        approval.subAccountId = 2;
        approval.approvedSigner = users.gov;
        approval.isApproved = false;
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(
            approval.account, approval.subAccountId, approval.approvedSigner, approval.isApproved
        );
        appendApproveSignerPayload("dan", 1);
        orderDispatch.ingresso(transaction);
        address subAccount = Commons.getSubAccount(users.alice, 1);
        assertTrue(addressManifest.approvedSigners(subAccount, users.keeper));
        subAccount = Commons.getSubAccount(users.dan, 2);
        assertFalse(addressManifest.approvedSigners(subAccount, users.gov));
    }

    function test_Happy_Approve_Signer_Batch_true_false_diff_acc() public {
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(
            approval.account, approval.subAccountId, approval.approvedSigner, approval.isApproved
        );
        constructApproveSignerPayload("alice", 1);
        approval.account = users.dan;
        approval.isApproved = false;
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(
            approval.account, approval.subAccountId, approval.approvedSigner, approval.isApproved
        );
        appendApproveSignerPayload("dan", 1);
        orderDispatch.ingresso(transaction);
        address subAccount = Commons.getSubAccount(users.alice, 1);
        assertTrue(addressManifest.approvedSigners(subAccount, users.keeper));
        subAccount = Commons.getSubAccount(users.dan, 1);
        assertFalse(addressManifest.approvedSigners(subAccount, users.keeper));
    }

    function test_Fail_Bad_Signer() public {
        approval.account = users.hackerman;
        constructApproveSignerPayload("alice", 1);
        vm.expectRevert(bytes4(keccak256("SignatureInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Bad_Tx_Id() public {
        constructApproveSignerPayload("alice", 1);
        transaction[0] = abi.encodePacked(uint8(69), transaction[0]);
        vm.expectRevert();
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Bad_Payload_Shape() public {
        constructApproveSignerPayload("alice", 1);
        transaction[0] = abi.encodePacked(transaction[0], uint8(0));
        vm.expectRevert(bytes4(keccak256("OrderByteLengthInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Happy_Approve_Signer_Match_Order() public {
        constructApproveSignerPayload("alice", 1);
        (bytes32 takerHash, bytes32 makerHash) = appendMatchOrderPayload();
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(
            approval.account, approval.subAccountId, approval.approvedSigner, approval.isApproved
        );
        ensureBalanceChangeEventsSpotMatch(
            defaults.usdcDepositQuantityE18(),
            defaults.wethDepositQuantity(),
            true,
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        address subAccount = Commons.getSubAccount(users.alice, 1);
        assertTrue(addressManifest.approvedSigners(subAccount, users.keeper));
        assertEq(spotCrucible.filledQuantitys(takerHash), takerOrder.quantity);
        assertEq(spotCrucible.filledQuantitys(makerHash), makerOrder.quantity);
        assertSpotBalanceChange(
            defaults.usdcDepositQuantityE18(),
            defaults.wethDepositQuantity(),
            true,
            takerOrder.productId,
            takerOrder.quantity,
            makerOrder.price,
            orderDispatch.txFees(0)
        );
    }

    function test_Happy_Approve_Signer_External() public {
        assertFalse(addressManifest.approvedSigners(users.alice, users.dan));
        vm.startPrank(users.gov);
        Structs.ApproveSigner memory approvalStruct =
            Structs.ApproveSigner(users.alice, 0, users.dan, true, 0);
        (bytes memory sig,) = makeApprovedSignerSig(approvalStruct, "alice");
        orderDispatch.approveSignerAdmin(approvalStruct, sig);
        assertTrue(addressManifest.approvedSigners(users.alice, users.dan));
    }

    function test_Happy_Approve_Signer_External_Diff_Subaccounts() public {
        assertFalse(addressManifest.approvedSigners(users.alice, users.dan));
        assertFalse(
            addressManifest.approvedSigners(Commons.getSubAccount(users.alice, 1), users.dan)
        );
        vm.startPrank(users.gov);
        Structs.ApproveSigner memory approvalStruct1 =
            Structs.ApproveSigner(users.alice, 0, users.dan, true, 0);
        Structs.ApproveSigner memory approvalStruct2 =
            Structs.ApproveSigner(users.alice, 1, users.dan, true, 1);
        (bytes memory sig1,) = makeApprovedSignerSig(approvalStruct1, "alice");
        (bytes memory sig2,) = makeApprovedSignerSig(approvalStruct2, "alice");
        orderDispatch.approveSignerAdmin(approvalStruct1, sig1);
        orderDispatch.approveSignerAdmin(approvalStruct2, sig2);
        assertTrue(addressManifest.approvedSigners(users.alice, users.dan));
        assertTrue(
            addressManifest.approvedSigners(Commons.getSubAccount(users.alice, 1), users.dan)
        );
    }

    function test_Fail_Approve_Signer_External_Invalid_Sig() public {
        assertFalse(addressManifest.approvedSigners(users.alice, users.dan));
        vm.startPrank(users.gov);
        Structs.ApproveSigner memory approvalStruct =
            Structs.ApproveSigner(users.alice, 0, users.dan, true, 0);
        (bytes memory sig,) = makeApprovedSignerSig(approvalStruct, "dan");
        vm.expectRevert(bytes4(keccak256("SignatureInvalid()")));
        orderDispatch.approveSignerAdmin(approvalStruct, sig);
        assertFalse(addressManifest.approvedSigners(users.alice, users.dan));
    }

    function test_Fail_Approve_Signer_External_Unauth() public {
        assertFalse(addressManifest.approvedSigners(users.alice, users.dan));
        Structs.ApproveSigner memory approvalStruct =
            Structs.ApproveSigner(users.alice, 0, users.dan, true, 0);
        (bytes memory sig,) = makeApprovedSignerSig(approvalStruct, "alice");
        vm.startPrank(users.alice);
        vm.expectRevert("UNAUTHORIZED");
        orderDispatch.approveSignerAdmin(approvalStruct, sig);
    }

    function test_Happy_Approve_Signer_External_Already_Approved() public {
        assertFalse(addressManifest.approvedSigners(users.alice, users.dan));
        Structs.ApproveSigner memory approvalStruct1 =
            Structs.ApproveSigner(users.alice, 0, users.dan, true, 0);
        Structs.ApproveSigner memory approvalStruct2 =
            Structs.ApproveSigner(users.alice, 0, users.dan, true, 1);
        (bytes memory sig1,) = makeApprovedSignerSig(approvalStruct1, "alice");
        (bytes memory sig2,) = makeApprovedSignerSig(approvalStruct2, "alice");
        orderDispatch.approveSignerAdmin(approvalStruct1, sig1);
        assertTrue(addressManifest.approvedSigners(users.alice, users.dan));
        orderDispatch.approveSignerAdmin(approvalStruct2, sig2);
        assertTrue(addressManifest.approvedSigners(users.alice, users.dan));
    }

    function test_Fail_Approve_Signer_External_Reuse_Nonce() public {
        assertFalse(addressManifest.approvedSigners(users.alice, users.dan));
        Structs.ApproveSigner memory approvalStruct =
            Structs.ApproveSigner(users.alice, 0, users.dan, true, 0);

        (bytes memory sig,) = makeApprovedSignerSig(approvalStruct, "alice");
        orderDispatch.approveSignerAdmin(approvalStruct, sig);
        assertTrue(addressManifest.approvedSigners(users.alice, users.dan));
        vm.expectRevert(bytes4(keccak256("DigestedAlready()")));
        orderDispatch.approveSignerAdmin(approvalStruct, sig);
    }

    function test_Fail_Approve_Signer_External_isApproved_false() public {
        assertFalse(addressManifest.approvedSigners(users.alice, users.dan));
        vm.startPrank(users.gov);
        Structs.ApproveSigner memory approvalStruct =
            Structs.ApproveSigner(users.alice, 0, users.dan, false, 0);
        (bytes memory sig,) = makeApprovedSignerSig(approvalStruct, "alice");
        vm.expectRevert(bytes4(keccak256("AdminApprovedSignerFalse()")));
        orderDispatch.approveSignerAdmin(approvalStruct, sig);
        assertFalse(addressManifest.approvedSigners(users.alice, users.dan));
    }
}
