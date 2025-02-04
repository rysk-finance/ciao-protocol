// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.19;

import "../interfaces/Structs.sol";
import "../interfaces/IPerpCrucible.sol";

import "../libraries/Commons.sol";
import "../libraries/BasicMath.sol";
import "../libraries/EnumerableSet.sol";
import "../libraries/AccessControl.sol";
import "../libraries/MarginDirective.sol";

contract UserAndSystemStateReader is AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    using BasicMath for int;
    using BasicMath for uint;

    uint8 constant CORE_COLLATERAL_INDEX = 1;

    constructor(address _addressManifest) {
        __AccessControl_init(_addressManifest);
    }

    function getArrayShapes(
        address subAccount
    ) internal view returns (uint256 sl, uint256 spl, uint256 pl) {
        // first get list of spot assets being held
        address[] memory spotAssets = _ciao().getSubAccountAssets(subAccount);
        uint256 assetsLen = spotAssets.length;
        IPerpCrucible perpCrucible = IPerpCrucible(
            Commons.perpCrucible(address(addressManifest))
        );
        uint256[] memory perpPositionIds = perpCrucible.getOpenPositionIds(
            subAccount
        );
        // loop through the spot assets
        for (uint i = 0; i < assetsLen; i++) {
            // get the balances of spot positions
            uint256 spotBalance = _ciao().balances(subAccount, spotAssets[i]);
            uint32 spotProductId = _productCatalogue()
                .baseAssetQuoteAssetSpotIds(
                    spotAssets[i],
                    _ciao().coreCollateralAddress()
                );
            if (spotProductId == CORE_COLLATERAL_INDEX) {
                sl++;
                continue;
            }
            // check to see if a short perp position in that asset is held
            uint32 perpId = _furnace().baseAssetQuotePerpIds(spotAssets[i]);
            Structs.PositionState memory perpPos = perpCrucible
                .subAccountPositions(perpId, subAccount);
            // get any matching perp positions
            // calculate the quantities for spread, perp and spot and create those position structs
            if (perpPos.quantity > 0 && !perpPos.isLong) {
                uint256 spreadQuantity = BasicMath.min(
                    perpPos.quantity,
                    spotBalance
                );
                spl++;
                if (perpPos.quantity > spotBalance) {
                    pl++;
                }
                // reduce spot balance for remaining calculations
                spotBalance -= spreadQuantity;
                if (spotBalance > 0) {
                    sl++;
                }
                // remove this perp from the list of open perp positions since we have accounted for all remaining perp positions
                // this array will be iterated over when calculating perp healths, so we no longer need this ID
                for (uint j = 0; j < perpPositionIds.length; j++) {
                    if (perpId == uint32(perpPositionIds[j])) {
                        // remove this value from array
                        perpPositionIds[j] = 0;
                    }
                }
            } else {
                // add any individual spot positions
                sl++;
            }
        }
        // acquire perp positions, ignoring IDs that were found in spreads
        // these values will have been set to 0 above.
        for (uint i = 0; i < perpPositionIds.length; i++) {
            // if equals 0, means health has been accounted for in spreads
            if (perpPositionIds[i] == 0) continue;
            pl++;
        }
    }

    struct LoopState {
        uint256 spotBalance;
        uint32 spotProductId;
        uint256 spotPrice;
        uint32 perpId;
        uint256 spreadQuantity;
        int256 currentCumFunding;
        uint256 perpPrice;
        Structs.PositionState perpPos;
    }

    function acquireUserAndSystemState(
        address subAccount
    ) external view returns (Structs.UserAndSystemState memory) {
        // first get list of spot assets being held
        address[] memory spotAssets = _ciao().getSubAccountAssets(subAccount);
        IPerpCrucible perpCrucible = IPerpCrucible(
            Commons.perpCrucible(address(addressManifest))
        );
        uint256[] memory perpPositionIds = perpCrucible.getOpenPositionIds(
            subAccount
        );
        Structs.UserAndSystemState memory u;
        (uint256 spotLen, uint256 spreadLen, uint256 perpLen) = getArrayShapes(
            subAccount
        );
        u.spots = new Structs.SpotPosition[](spotLen);
        u.spreads = new Structs.SpreadPosition[](spreadLen);
        u.perps = new Structs.PerpPosition[](perpLen);
        spotLen = 0;
        spreadLen = 0;
        perpLen = 0;
        // loop through the spot assets
        for (uint i = 0; i < spotAssets.length; i++) {
            LoopState memory l;
            // get the balances of spot positions
            l.spotBalance = _ciao().balances(subAccount, spotAssets[i]);
            l.spotProductId = _productCatalogue().baseAssetQuoteAssetSpotIds(
                spotAssets[i],
                _ciao().coreCollateralAddress()
            );
            if (l.spotProductId == CORE_COLLATERAL_INDEX) {
                // get the balances of usdc and add it as a Structs.SpotPosition
                // get the coreCollateralDebt and add it
                u.coreCollateralDebt = _ciao().coreCollateralDebt(subAccount);
                u.coreCollateralAddress = spotAssets[i];
                u.spots[spotLen] = Structs.SpotPosition(
                    spotAssets[i],
                    l.spotBalance,
                    1,
                    _furnace().getSpotRiskWeights(spotAssets[i])
                );
                spotLen++;
                continue;
            }
            l.spotPrice = _furnace().prices(l.spotProductId);
            // check to see if a short perp position in that asset is held
            l.perpId = _furnace().baseAssetQuotePerpIds(spotAssets[i]);
            l.perpPos = perpCrucible.subAccountPositions(l.perpId, subAccount);
            // get any matching perp positions
            // calculate the quantities for spread, perp and spot and create those position structs
            if (l.perpPos.quantity > 0 && !l.perpPos.isLong) {
                l.spreadQuantity = BasicMath.min(
                    l.perpPos.quantity,
                    l.spotBalance
                );
                l.currentCumFunding = perpCrucible.currentCumFunding(l.perpId);
                l.perpPrice = _furnace().prices(l.perpId);
                u.spreads[spreadLen] = Structs.SpreadPosition(
                    l.spotPrice,
                    l.perpPrice,
                    l.currentCumFunding,
                    l.spreadQuantity,
                    l.perpPos,
                    _furnace().getSpreadPenalty(spotAssets[i])
                );
                spreadLen++;
                if (l.perpPos.quantity > l.spotBalance) {
                    l.perpPos.quantity -= l.spotBalance;
                    u.perps[perpLen] = Structs.PerpPosition(
                        l.perpId,
                        l.perpPos,
                        l.perpPrice,
                        l.currentCumFunding,
                        _furnace().getProductRiskWeights(l.perpId)
                    );
                    perpLen++;
                }
                // reduce spot balance for remaining calculations
                l.spotBalance -= l.spreadQuantity;
                if (l.spotBalance > 0) {
                    u.spots[spotLen] = Structs.SpotPosition(
                        spotAssets[i],
                        l.spotBalance,
                        l.spotPrice,
                        _furnace().getSpotRiskWeights(spotAssets[i])
                    );
                    spotLen++;
                }
                // remove this perp from the list of open perp positions since we have accounted for all remaining perp positions
                // this array will be iterated over when calculating perp healths, so we no longer need this ID
                for (uint j = 0; j < perpPositionIds.length; j++) {
                    if (l.perpId == uint32(perpPositionIds[j])) {
                        // remove this value from array
                        perpPositionIds[j] = 0;
                    }
                }
            } else {
                // add any individual spot positions
                u.spots[spotLen] = Structs.SpotPosition(
                    spotAssets[i],
                    l.spotBalance,
                    l.spotPrice,
                    _furnace().getSpotRiskWeights(spotAssets[i])
                );
                spotLen++;
            }
        }
        // acquire perp positions, ignoring IDs that were found in spreads
        // these values will have been set to 0 above.
        for (uint i = 0; i < perpPositionIds.length; i++) {
            // if equals 0, means health has been accounted for in spreads
            if (perpPositionIds[i] == 0) continue;
            Structs.PositionState memory perpPos = perpCrucible
                .subAccountPositions(uint32(perpPositionIds[i]), subAccount);
            uint perpPrice = _furnace().prices(uint32(perpPositionIds[i]));
            int currentCumFunding = perpCrucible.currentCumFunding(
                uint32(perpPositionIds[i])
            );
            u.perps[perpLen] = Structs.PerpPosition(
                perpPositionIds[i],
                perpPos,
                perpPrice,
                currentCumFunding,
                _furnace().getProductRiskWeights(uint32(perpPositionIds[i]))
            );
            perpLen++;
        }
        return u;
    }
}
