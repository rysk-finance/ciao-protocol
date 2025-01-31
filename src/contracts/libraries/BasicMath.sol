// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

/**
 * @notice Library for basic math
 */
library BasicMath {
    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev multiplies two e18 notation uint256 together, diving the result by 1e18
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * b) / 1e18;
    }

    /**
     * @dev multiplies two e18 notation ints together, diving the result by 1e18
     */
    function mul(int256 a, int256 b) internal pure returns (int256) {
        return (a * b) / 1e18;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * 1e18) / b;
    }
}
