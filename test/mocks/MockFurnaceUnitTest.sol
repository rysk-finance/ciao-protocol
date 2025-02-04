// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "src/contracts/Furnace.sol";
import "src/contracts/libraries/MarginDirective.sol";

//     ______
//    / ____/_  ___________  ____ _________
//   / /_  / / / / ___/ __ \/ __ `/ ___/ _ \
//  / __/ / /_/ / /  / / / / /_/ / /__/  __/
// /_/    \__,_/_/  /_/ /_/\__,_/\___/\___/
/////////////////////////////////////////////

/// @notice Contract for consolidation all margin checking and position adding logic
contract MockFurnaceUnitTest is Furnace {
    constructor(address _addressManifest) Furnace(_addressManifest) {}

    function calculateSpreadHealth(
        uint256 spreadPenalty,
        uint256 quantity,
        uint256 spotPrice,
        uint256 perpPrice,
        uint256 perpEntryPrice,
        int256 initCumFunding,
        int256 currentCumFunding
    ) external pure returns (int256 health) {
        return MarginDirective._calculateSpreadHealth(
            spreadPenalty,
            quantity,
            spotPrice,
            perpPrice,
            perpEntryPrice,
            initCumFunding,
            currentCumFunding
        );
    }

    function calculateSpotHealth(uint256 weight, uint256 quantity, uint256 spotPrice)
        external
        pure
        returns (int256 health)
    {
        return MarginDirective._calculateSpotHealth(weight, quantity, spotPrice);
    }
}
