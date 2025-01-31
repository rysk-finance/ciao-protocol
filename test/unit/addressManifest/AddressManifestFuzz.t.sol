// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AddressManifest} from "src/contracts/AddressManifest.sol";
import {Events} from "src/contracts/interfaces/Events.sol";
import {Base_Test} from "../../Base.t.sol";

contract AddressManifestBaseTest is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        deployAddressManifest();
    }

    function test_Happy_UpdateManifestFuzzId(uint256 id) public {
        vm.expectEmit(address(addressManifest));
        emit Events.ManifestUpdated(id, users.recipient);
        addressManifest.updateAddressInManifest(id, users.recipient);
        assertEq(addressManifest.manifest(id), users.recipient);
    }

    function test_Happy_UpdateManifestFuzzAddress(address newAddress) public {
        vm.expectEmit(address(addressManifest));
        emit Events.ManifestUpdated(1, newAddress);
        addressManifest.updateAddressInManifest(1, newAddress);
        assertEq(addressManifest.manifest(1), newAddress);
    }

    function test_Happy_UpdateManifestFuzzAddressAndId(address newAddress, uint256 id) public {
        vm.expectEmit(address(addressManifest));
        emit Events.ManifestUpdated(id, newAddress);
        addressManifest.updateAddressInManifest(id, newAddress);
        assertEq(addressManifest.manifest(id), newAddress);
    }

    function test_Fail_UpdateManifestWithNotOwnerFuzzSender(address hackerman) public {
        vm.expectEmit(address(addressManifest));
        emit Events.ManifestUpdated(uint256(1), users.recipient);
        addressManifest.updateAddressInManifest(uint256(1), users.recipient);
        assertEq(addressManifest.manifest(1), users.recipient);

        vm.startPrank({msgSender: hackerman});
        if (hackerman == users.gov) {
            return;
        }
        vm.expectRevert("UNAUTHORIZED");
        addressManifest.updateAddressInManifest(uint256(1), users.recipient);
    }
}
