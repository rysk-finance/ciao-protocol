// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.19;

import "./BasicMath.sol";
import "../Furnace.sol";
import "../interfaces/Structs.sol";

library MarginDirective {
    using BasicMath for uint256;
    using BasicMath for int256;

    /// @notice Compute maintenance margin for a single position
    /// @param isInitial whether to calculate initial or maintenance health
    /// @param productRiskWeights weight risk parameters for the perp. all values e18
    /// @param quantity number of contracts. e18
    /// @param avgEntryPrice average entry price of the position
    /// @param isLong whether the position is an asset (long) or liability (short)
    /// @param markPrice Mark price for product
    /// @param initCumFunding cumulative funding value for market at time of position entry
    /// @param currentCumFunding cumulative funding value for market now
    /// @return health Maintenance health for position
    function getPerpMarginHealth(
        bool isInitial,
        Structs.ProductRiskWeights memory productRiskWeights,
        uint256 quantity,
        uint256 avgEntryPrice,
        bool isLong,
        uint256 markPrice,
        int256 initCumFunding,
        int256 currentCumFunding
    ) internal pure returns (int256 health) {
        // Case 1: long position
        // use maintenanceLongWeight
        // quantity * markPrice * weight - quantity * avgEntryPrice - (currentCumFunding - initCumFunding) * quantity
        // == quantity(markPrice * weight - avgEntryPrice - currentCumFunding + initCumFunding)
        if (isLong) {
            health = int256(quantity).mul(
                int256(
                    markPrice.mul(
                        isInitial
                            ? productRiskWeights.initialLongWeight
                            : productRiskWeights.maintenanceLongWeight
                    )
                ) -
                    int256(avgEntryPrice) -
                    currentCumFunding +
                    initCumFunding
            );
        }
        // Case 2: short position
        // use maintenanceShortWeight
        // quantity is flipped negative to represent short position
        // -quantity * markPrice * weight - (-quantity) * avgEntryPrice - (currentCumFunding - initCumFunding) * (-quantity)
        // == -quantity(markPrice * weight - avgEntryPrice - currentCumFunding + initCumFunding)
        else {
            health = -int256(quantity).mul(
                int256(
                    markPrice.mul(
                        isInitial
                            ? productRiskWeights.initialShortWeight
                            : productRiskWeights.maintenanceShortWeight
                    )
                ) -
                    int256(avgEntryPrice) -
                    currentCumFunding +
                    initCumFunding
            );
        }
    }

    /// @notice spotPrice * quantity - perpPrice * quantity + perpEntryPrice * quantity - spreadPenalty * (spotPrice * quantity + perpPrice * quantity) / 2 - (quantity * (initCumFunding - currentCumFunding))
    /// == quantity(spotPrice - perpPrice + perpEntryPrice - (initCumfunding - currentCumFunding) - spreadPenalty(spotPrice + perpPrice) / 2 )
    /// == quantity(spotPrice - perpPrice + perpEntryPrice + currentCumFunding - initCumFunding - spreadPenalty(spotPrice + perpPrice) / 2 )
    function _calculateSpreadHealth(
        uint256 spreadPenalty,
        uint256 quantity,
        uint256 spotPrice,
        uint256 perpPrice,
        uint256 perpEntryPrice,
        int256 initCumFunding,
        int256 currentCumFunding
    ) internal pure returns (int256 health) {
        return
            int256(quantity).mul(
                int(spotPrice) -
                    int(perpPrice) +
                    int(perpEntryPrice) +
                    currentCumFunding -
                    initCumFunding -
                    int(spreadPenalty.mul((spotPrice + perpPrice) / 2))
            );
    }

    function _calculateSpotHealth(
        uint256 weight,
        uint256 quantity,
        uint256 spotPrice
    ) internal pure returns (int256 health) {
        return int256(quantity.mul(weight).mul(spotPrice));
    }
}
