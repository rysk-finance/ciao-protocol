// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.19;

import "./Structs.sol";

/// @notice Interface for liquidation
interface ILiquidation {
    function liquidateSubAccount(Structs.LiquidateSubAccount calldata txn, bool noRecentDeposit)
        external;

    function liquidationHealthBuffer() external returns (uint256);
}
