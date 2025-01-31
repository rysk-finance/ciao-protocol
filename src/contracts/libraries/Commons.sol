// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.8.19;

import "../interfaces/Errors.sol";
import "../interfaces/IAddressManifest.sol";

library Commons {
    function getSubAccount(address primary, uint8 subAccountId) internal pure returns (address) {
        return address(uint160(primary) ^ uint160(subAccountId));
    }

    // Basic Getters
    //////////////////////////////////////

    function perpCrucible(address addressManifest) external view returns (address) {
        return IAddressManifest(addressManifest).manifest(7);
    }

    function crucible(address addressManifest, uint8 index) external view returns (address) {
        return IAddressManifest(addressManifest).manifest(index);
    }

    /// @dev assumes decimals are coming in as e18
    function convertFromE18(uint256 value, uint256 decimals) internal pure returns (uint256) {
        if (decimals > 18) revert();
        return value / (10 ** (18 - decimals));
    }

    /// @dev converts from specified decimals to e18
    function convertToE18(uint256 value, uint256 decimals) internal pure returns (uint256) {
        if (decimals > 18) revert();
        return value * (10 ** (18 - decimals));
    }

    function ciao(address addressManifest) internal view returns (address) {
        return IAddressManifest(addressManifest).manifest(1);
    }

    function furnace(address addressManifest) internal view returns (address) {
        return IAddressManifest(addressManifest).manifest(2);
    }

    function productCatalogue(address addressManifest) internal view returns (address) {
        return IAddressManifest(addressManifest).manifest(3);
    }

    function liquidation(address addressManifest) internal view returns (address) {
        return IAddressManifest(addressManifest).manifest(5);
    }
}
