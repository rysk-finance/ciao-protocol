// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.19;

import "../interfaces/Structs.sol";

import "../libraries/MarginDirective.sol";

contract MarginReader {

    // for this version of the sub account margin function, we make the assumption that we have
    // already computed a subAccount's potential spread positions
    function getSubAccountMargin(
        bool isInitial,
        Structs.UserAndSystemState memory u
    ) external pure returns (int256 health) {
        // first we handle spots, this should have already had spreads deducted
        for (uint i = 0; i < u.spots.length; i++) {
            Structs.SpotPosition memory spot = u.spots[i];
            if (spot.spotRiskWeights.maintenanceLongWeight == 0) {
                // in this case the spot asset is not valid collateral and contributes no health
                continue;
            }
            // check if the spot asset is core collateral, if so handle for it
            if (spot.spotAsset == u.coreCollateralAddress) {
                health +=
                    int256(spot.spotBalance) -
                    int256(u.coreCollateralDebt);
                continue;
            }
            health += MarginDirective._calculateSpotHealth(
                isInitial
                    ? spot.spotRiskWeights.initialLongWeight
                    : spot.spotRiskWeights.maintenanceLongWeight,
                spot.spotBalance,
                spot.spotPrice
            );
        }
        // second we handle spreads
        for (uint i = 0; i < u.spreads.length; i++) {
            Structs.SpreadPosition memory spread = u.spreads[i];
            health += MarginDirective._calculateSpreadHealth(
                isInitial
                    ? spread.spreadPenalty.initial
                    : spread.spreadPenalty.maintenance,
                spread.spreadQuantity,
                spread.spotPrice,
                spread.perpPrice,
                spread.perpPos.avgEntryPrice,
                spread.perpPos.initCumFunding,
                spread.currentCumFunding
            );
        }
        // third we handle perps, this should have already had spreads deducted
        for (uint i = 0; i < u.perps.length; i++) {
            Structs.PerpPosition memory perp = u.perps[i];
            health += MarginDirective.getPerpMarginHealth(
                isInitial,
                perp.perpRiskWeights,
                perp.perpPosition.quantity,
                perp.perpPosition.avgEntryPrice,
                perp.perpPosition.isLong,
                perp.perpPrice,
                perp.perpPosition.initCumFunding,
                perp.currentCumFunding
            );
        }
    }
}
