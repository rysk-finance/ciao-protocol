// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.19;

/// @notice Interface for crucible
interface ICrucible {
    function updateFilledQuantity(
        bytes32 takerDigest,
        bytes32 makerDigest,
        uint128 quantity
    ) external;

    function filledQuantitys(bytes32 digest) external view returns (uint128);

    function getOpenPositionIds(
        address subAccount
    ) external view returns (uint256[] memory);
}
