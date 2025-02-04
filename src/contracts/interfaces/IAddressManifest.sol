// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.19;

/// @notice Interface for the address manifest
interface IAddressManifest {
    function manifest(uint256 index) external view returns (address);
    function operator() external view returns (address);
    function admin() external view returns (address);
    function owner() external view returns (address);
    function approveSigner(address account, uint8 subAccountId, address approvedSigner, bool isApproved) external;
    function approvedSigners(address subAccount, address approvedSigner) external view returns (bool);
    function checkInDigestAsUsed(bytes32 digest) external;
}
