// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AddressManifest} from "src/contracts/AddressManifest.sol";
import {Events} from "src/contracts/interfaces/Events.sol";
import {Commons} from "src/contracts/libraries/Commons.sol";
import {Base_Test} from "../../Base.t.sol";

contract AddressManifestBaseTest is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        deployAddressManifest();
        addressManifest.setRequiresDispatchCall(false);
    }

    function test_Happy_UpdateManifest() public {
        vm.expectEmit(address(addressManifest));
        emit Events.ManifestUpdated(uint256(1), users.recipient);
        addressManifest.updateAddressInManifest(uint256(1), users.recipient);
        assertEq(addressManifest.manifest(1), users.recipient);
    }

    function test_Happy_SetRequireDispatchCall() public {
        vm.expectEmit(address(addressManifest));
        emit Events.RequiresDispatchCallSet(true);
        addressManifest.setRequiresDispatchCall(true);
        assertEq(addressManifest.requiresDispatchCall(), true);
    }

    function test_Fail_Hackerman_SetRequireDispatchCall() public {
        vm.startPrank(users.hackerman);
        vm.expectRevert("UNAUTHORIZED");
        addressManifest.setRequiresDispatchCall(false);
    }

    function test_Happy_UpdateManifestTwiceOnSameId() public {
        vm.expectEmit(address(addressManifest));
        emit Events.ManifestUpdated(uint256(1), users.recipient);
        addressManifest.updateAddressInManifest(uint256(1), users.recipient);
        assertEq(addressManifest.manifest(1), users.recipient);
        vm.expectEmit(address(addressManifest));
        emit Events.ManifestUpdated(uint256(1), users.alice);
        addressManifest.updateAddressInManifest(uint256(1), users.alice);
        assertEq(addressManifest.manifest(1), users.alice);
    }

    function test_Happy_UpdateManifestTwice() public {
        vm.expectEmit(address(addressManifest));
        emit Events.ManifestUpdated(uint256(1), users.recipient);
        addressManifest.updateAddressInManifest(uint256(1), users.recipient);
        assertEq(addressManifest.manifest(1), users.recipient);
        vm.expectEmit(address(addressManifest));
        emit Events.ManifestUpdated(uint256(2), users.alice);
        addressManifest.updateAddressInManifest(uint256(2), users.alice);
        assertEq(addressManifest.manifest(2), users.alice);
    }

    function test_Fail_UpdateManifestWithNotOwner() public {
        vm.expectEmit(address(addressManifest));
        emit Events.ManifestUpdated(uint256(1), users.recipient);
        addressManifest.updateAddressInManifest(uint256(1), users.recipient);
        assertEq(addressManifest.manifest(1), users.recipient);

        vm.startPrank({msgSender: users.hackerman});
        vm.expectRevert("UNAUTHORIZED");
        addressManifest.updateAddressInManifest(uint256(1), users.recipient);
    }

    function test_Happy_ApproveSigner() public {
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(users.gov, uint8(1), users.alice, true);
        addressManifest.approveSigner(users.gov, uint8(1), users.alice, true);
        address subAccount = Commons.getSubAccount(users.gov, 1);
        assertTrue(addressManifest.approvedSigners(subAccount, users.alice));
    }

    function test_Happy_DisApproveSigner() public {
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(users.gov, uint8(1), users.alice, true);
        addressManifest.approveSigner(users.gov, uint8(1), users.alice, true);
        address subAccount = Commons.getSubAccount(users.gov, 1);
        assertTrue(addressManifest.approvedSigners(subAccount, users.alice));
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(users.gov, uint8(1), users.alice, false);
        addressManifest.approveSigner(users.gov, uint8(1), users.alice, false);
        subAccount = Commons.getSubAccount(users.gov, 1);
        assertFalse(addressManifest.approvedSigners(subAccount, users.alice));
    }

    function test_Happy_ApproveSignerOnDiffSubAccounts() public {
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(users.gov, uint8(1), users.alice, true);
        addressManifest.approveSigner(users.gov, uint8(1), users.alice, true);
        address subAccount = Commons.getSubAccount(users.gov, 1);
        assertTrue(addressManifest.approvedSigners(subAccount, users.alice));
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(users.gov, uint8(2), users.alice, true);
        addressManifest.approveSigner(users.gov, uint8(2), users.alice, true);
        subAccount = Commons.getSubAccount(users.gov, 2);
        assertTrue(addressManifest.approvedSigners(subAccount, users.alice));
    }

    function test_Fail_MismatchedAccount() public {
        vm.expectRevert(bytes4(keccak256("SenderInvalid()")));
        addressManifest.approveSigner(users.alice, uint8(1), users.hackerman, true);
    }

    function test_Fail_Cant_ApproveSigner_If_Dispatch_Call() public {
        addressManifest.setRequiresDispatchCall(true);
        vm.expectRevert(bytes4(keccak256("SenderInvalid()")));
        addressManifest.approveSigner(users.gov, uint8(1), users.alice, true);
    }
}
