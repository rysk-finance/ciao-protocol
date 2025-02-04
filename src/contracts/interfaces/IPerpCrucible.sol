// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.19;

import "./ICrucible.sol";
import "./Structs.sol";

/// @notice Interface for crucible
interface IPerpCrucible is ICrucible {
    function subAccountPositions(uint32 productId, address subAccount)
        external
        view
        returns (Structs.PositionState memory);

    function currentCumFunding(uint32 productId) external view returns (int256);

    function updatePosition(
        address makerSubAccount,
        address takerSubAccount,
        uint32 productId,
        Structs.NewPosition memory makerPosition
    ) external returns (int256 makerRealisedPnl, int256 takerRealisedPnl);

    function updateCumulativeFundings(bytes memory fundingData) external;
}
