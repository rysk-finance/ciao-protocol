// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "./libraries/BasicMath.sol";

import "./interfaces/Events.sol";
import "./interfaces/Errors.sol";
import "./interfaces/Structs.sol";

import "./libraries/AccessControl.sol";
import "./libraries/MarginDirective.sol";

//     ______
//    / ____/_  ___________  ____ _________
//   / /_  / / / / ___/ __ \/ __ `/ ___/ _ \
//  / __/ / /_/ / /  / / / / /_/ / /__/  __/
// /_/    \__,_/_/  /_/ /_/\__,_/\___/\___/
/////////////////////////////////////////////

/// @notice Contract for calculating health of a given subaccount
///         Mk 0.0.0
contract Furnace is AccessControl {
    using BasicMath for int256;
    using BasicMath for uint256;

    /// @notice productId => ProductRiskWeights
    mapping(uint32 => Structs.ProductRiskWeights) public productRiskWeights;

    /// @notice spot address => ProductRiskWeights
    mapping(address => Structs.ProductRiskWeights) public spotRiskWeights;

    /// @notice spot asset address => productId
    mapping(address => uint32) public baseAssetQuotePerpIds;

    /// @notice spot asset address => spread penalty
    mapping(address => Structs.SpreadPenalties) public spreadPenalties;

    /// @notice productId => oracle price
    mapping(uint32 => uint256) public prices;

    // Constants
    //////////////////////////////////////

    uint8 constant CORE_COLLATERAL_INDEX = 1;

    constructor(address _addressManifest) {
        __AccessControl_init(_addressManifest);
    }

    // External - Access Controlled
    //////////////////////////////////////

    function setPrices(bytes memory priceData) external {
        // check that the caller is the order dispatch
        _isOrderDispatch();
        // look at the length of the byte array to determine how many prices are being updated
        if (priceData.length % 36 != 0) revert Errors.OrderByteLengthInvalid();
        uint256 priceDataLen = priceData.length;
        for (uint256 i; i < priceDataLen;) {
            uint32 productId;
            uint256 price;
            uint256 pidOffset = i + 4;
            uint256 priceOffset = i + 36;
            /// @solidity memory-safe-assembly
            assembly {
                productId := mload(add(priceData, pidOffset))
                price := mload(add(priceData, priceOffset))
            }
            prices[productId] = price;
            i += 36;
        }
    }

    function setProductRiskWeight(uint32 productId, Structs.ProductRiskWeights calldata newProductRiskWeights)
        external
    {
        _isAdmin();
        productRiskWeights[productId] = newProductRiskWeights;
        emit Events.RiskWeightsSet(
            productId,
            newProductRiskWeights.initialLongWeight,
            newProductRiskWeights.initialShortWeight,
            newProductRiskWeights.maintenanceLongWeight,
            newProductRiskWeights.maintenanceShortWeight
        );
    }

    function setSpotRiskWeight(address spotAsset, Structs.ProductRiskWeights calldata newSpotRiskWeights) external {
        _isAdmin();
        spotRiskWeights[spotAsset] = newSpotRiskWeights;
        emit Events.SpotRiskWeightsSet(
            spotAsset,
            newSpotRiskWeights.initialLongWeight,
            newSpotRiskWeights.initialShortWeight,
            newSpotRiskWeights.maintenanceLongWeight,
            newSpotRiskWeights.maintenanceShortWeight
        );
    }

    function setSpreadPenalty(address spotAsset, uint64 initial, uint64 maintenance) external {
        _isAdmin();
        spreadPenalties[spotAsset] = Structs.SpreadPenalties(initial, maintenance);
        emit Events.SpreadPenaltySet(spotAsset, initial, maintenance);
    }

    /// @param spotAddress address of the spot asset
    /// @param productId ID of the corresponding perp/base collateral contract
    function setBaseAssetQuotePerps(address spotAddress, uint32 productId) external {
        _isAdmin();
        baseAssetQuotePerpIds[spotAddress] = productId;
        emit Events.BaseAssetQuotePerpSet(spotAddress, productId);
    }

    // External - View
    //////////////////////////////////////

    /// @notice Primary health calculation function of the system, used
    ///         by the entire system to validate a given subaccount's margin health.
    /// @param subAccount the subAccount to calculate health for
    /// @param isInitial true if initial health, false if maintenance health
    /// @return health the initial or maintenance health of the subAccount
    function getSubAccountHealth(address subAccount, bool isInitial) public view returns (int256 health) {
        // initialise struct for temporary memory vars to stop Stack Too Deep
        Structs.SubAccountHealthVars memory tempVars;

        // first get list of spot assets being held
        tempVars.spotAssets = _ciao().getSubAccountAssets(subAccount);
        tempVars.assetsLen = tempVars.spotAssets.length;
        tempVars.perpCrucible = _perpCrucible();
        tempVars.perpPositionIds = tempVars.perpCrucible.getOpenPositionIds(subAccount);
        tempVars.numPerpPositions = tempVars.perpPositionIds.length;
        for (uint256 i = 0; i < tempVars.assetsLen; i++) {
            address spotAssetAddress = tempVars.spotAssets[i];
            uint32 spotProductId =
                _productCatalogue().baseAssetQuoteAssetSpotIds(spotAssetAddress, _ciao().coreCollateralAddress());
            uint256 spotBalance = _ciao().balances(subAccount, spotAssetAddress);
            if (spotProductId == CORE_COLLATERAL_INDEX) {
                health += int256(spotBalance) - int256(_ciao().coreCollateralDebt(subAccount));
                continue;
            }
            if (spotRiskWeights[spotAssetAddress].maintenanceLongWeight == 0) {
                // in this case the spot asset is not valid collateral and contributes no health
                continue;
            }
            uint256 spotPrice = prices[spotProductId];

            // check to see if any spread positions on this asset are held
            uint32 perpId = baseAssetQuotePerpIds[spotAssetAddress];
            Structs.PositionState memory perpPos = tempVars.perpCrucible.subAccountPositions(perpId, subAccount);

            uint256 spreadQuantity = spreadPenalties[spotAssetAddress].maintenance == 1e18
                ? 0
                : _subAccountSpreadQuantity(spotBalance, perpPos);
            if (spreadQuantity > 0) {
                // in this case, calculate health on the spread separately
                int256 currentCumFunding = tempVars.perpCrucible.currentCumFunding(perpId);
                uint256 perpPrice = prices[perpId];
                health += MarginDirective._calculateSpreadHealth(
                    isInitial
                        ? spreadPenalties[spotAssetAddress].initial
                        : spreadPenalties[spotAssetAddress].maintenance,
                    spreadQuantity,
                    spotPrice,
                    perpPrice,
                    perpPos.avgEntryPrice,
                    perpPos.initCumFunding,
                    currentCumFunding
                );
                // reduce perp and spot balances for further calculations
                perpPos.quantity -= spreadQuantity;
                spotBalance -= spreadQuantity;

                // calculate the health on the remaining perp position if there is any
                // will be calculated as zero if no short perp pos remains
                health += MarginDirective.getPerpMarginHealth(
                    isInitial,
                    productRiskWeights[perpId],
                    perpPos.quantity, // number of remaining perps to calculate health on
                    perpPos.avgEntryPrice,
                    false, // is not long
                    perpPrice,
                    perpPos.initCumFunding,
                    currentCumFunding
                );

                // reduce spot balance for remaining calculations
                // remove this perp from the list of open perp positions since we have accounted for all remaining perp balance health
                // this array will be iterated over when calculating perp healths, so we no longer need this ID
                for (uint256 j = 0; j < tempVars.numPerpPositions; j++) {
                    if (perpId == uint32(tempVars.perpPositionIds[j])) {
                        // remove this value from array
                        tempVars.perpPositionIds[j] = 0;
                    }
                }
            }
            health += MarginDirective._calculateSpotHealth(
                isInitial
                    ? spotRiskWeights[spotAssetAddress].initialLongWeight
                    : spotRiskWeights[spotAssetAddress].maintenanceLongWeight,
                spotBalance,
                spotPrice
            );
        }
        // calculate health on perp positions, ignoring IDs that were found in spreads
        // these values will have been set to 0 above.
        for (uint256 i = 0; i < tempVars.numPerpPositions; i++) {
            // if equals 0, means health has been accounted for in spreads
            if (tempVars.perpPositionIds[i] == 0) continue;
            Structs.PositionState memory perpPos =
                tempVars.perpCrucible.subAccountPositions(uint32(tempVars.perpPositionIds[i]), subAccount);

            uint256 perpPrice = prices[uint32(tempVars.perpPositionIds[i])];

            health += MarginDirective.getPerpMarginHealth(
                isInitial,
                productRiskWeights[uint32(tempVars.perpPositionIds[i])],
                perpPos.quantity, // number of remaining perps to calculate health on
                perpPos.avgEntryPrice,
                perpPos.isLong,
                perpPrice,
                perpPos.initCumFunding,
                tempVars.perpCrucible.currentCumFunding(uint32(tempVars.perpPositionIds[i]))
            );
        }
    }

    // Basic Getters
    //////////////////////////////////////

    function getSpreadPenalty(address spotAddress) external view returns (Structs.SpreadPenalties memory) {
        return (spreadPenalties[spotAddress]);
    }

    function getSpotRiskWeights(address spotAddress) external view returns (Structs.ProductRiskWeights memory) {
        return (spotRiskWeights[spotAddress]);
    }

    function getProductRiskWeights(uint32 productId) external view returns (Structs.ProductRiskWeights memory) {
        return (productRiskWeights[productId]);
    }

    // Internal
    //////////////////////////////////////

    function _subAccountSpreadQuantity(uint256 spotBalance, Structs.PositionState memory perpPos)
        public
        pure
        returns (uint256)
    {
        if (perpPos.quantity > 0 && !perpPos.isLong) {
            return BasicMath.min(perpPos.quantity, spotBalance);
        } else {
            return 0;
        }
    }
}
