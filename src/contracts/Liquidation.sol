// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "./libraries/Commons.sol";
import "./libraries/BasicMath.sol";
import "./libraries/AccessControl.sol";

import "./interfaces/Events.sol";
import "./interfaces/Errors.sol";
import "./interfaces/Structs.sol";

//     __    _             _     __      __  _
//    / /   (_)___ ___  __(_)___/ /___ _/ /_(_)___  ____
//   / /   / / __ `/ / / / / __  / __ `/ __/ / __ \/ __ \
//  / /___/ / /_/ / /_/ / / /_/ / /_/ / /_/ / /_/ / / / /
// /_____/_/\__, /\__,_/_/\__,_/\__,_/\__/_/\____/_/ /_/
//            /_/
///////////////////////////////////////////////////////////

/// @notice Contract for handling balance transfer liquidations
///         Mk 0.0.0
contract Liquidation is AccessControl {
    using BasicMath for uint256;

    // Governance Variables
    //////////////////////////////////////

    /// @notice fraction of liquidation profits that are redirected to the insurance fund
    uint256 public liquidationFeeFraction = 0;

    /// @notice variables for calculating the price at which assets are liquidated
    uint256 public liqPriceNumerator = 4e18;
    uint256 public liqPriceDenominator = 5e18;

    /// @notice maintenance health below which a subAccount can be liquidated
    /// @dev used to account for any latency between user's health dropping negative and a liquidation being pushed to chain
    uint256 public liquidationHealthBuffer = 10e18;

    enum LiquidationMode {
        SPREAD,
        SPOT,
        PERP
    }

    constructor(address _addressManifest) {
        __AccessControl_init(_addressManifest);
    }

    // External - Access Controlled
    //////////////////////////////////////

    function setLiquidationFeeFraction(uint256 _liquidationFeeFraction) external {
        _isAdmin();
        if (_liquidationFeeFraction >= 1e18) {
            revert Errors.InvalidLiquidateFeeFractionValue();
        }
        liquidationFeeFraction = _liquidationFeeFraction;
        emit Events.LiquidationFeeFractionSet(_liquidationFeeFraction);
    }

    function setLiqPriceNumerator(uint256 _liqPriceNumerator) external {
        _isAdmin();
        liqPriceNumerator = _liqPriceNumerator;
        emit Events.LiqPriceNumeratorSet(_liqPriceNumerator);
    }

    function setLiqPriceDenominator(uint256 _liqPriceDenominator) external {
        _isAdmin();
        liqPriceDenominator = _liqPriceDenominator;
        emit Events.LiqPriceDenominatorSet(_liqPriceDenominator);
    }

    function setLiquidationHealthBuffer(uint256 _liquidationHealthBuffer) external {
        _isAdmin();
        liquidationHealthBuffer = _liquidationHealthBuffer;
        emit Events.LiquidationHealthBufferSet(_liquidationHealthBuffer);
    }

    /// @notice liquidates a position on a subAccount whos maintenance health is below zero
    /// @notice // order for liquidating:
    ///   perps
    ///   spreads
    ///   spot assets > usdc
    /// @param txn struct containing the following properties:
    /// -- liquidator: the EOA address of the user taking on the liquidated position
    /// -- liquidatorSubAccountId: the ID of the liquidator's subAccount assuming the risk
    /// -- liquidatee: the EOA address of the user getting liquidated
    /// -- liquidateeSubAccountId: the ID of the liquidatee's underwater subAccount
    /// -- liquidationMode: type of position to liquidate
    /// -- productId: the ID of the position (nb. for spreads this is the perp ID)
    /// -- quantity: quantity of the position to liquidate, denominated in base asset quantity/num. contracts
    /// -- nonce: unique number
    function liquidateSubAccount(Structs.LiquidateSubAccount calldata txn, bool noRecentDeposit)
        external
    {
        _isOrderDispatch();
        address liquidatorSubAccount =
            Commons.getSubAccount(txn.liquidator, txn.liquidatorSubAccountId);
        address liquidateeSubAccount =
            Commons.getSubAccount(txn.liquidatee, txn.liquidateeSubAccountId);
        if (liquidatorSubAccount == liquidateeSubAccount) {
            revert Errors.LiquidatorCanNotBeLiquidatee();
        }
        if (noRecentDeposit) {
            // check liquidatee is below maintenance health
            if (
                _furnace().getSubAccountHealth(liquidateeSubAccount, false)
                    >= int256(liquidationHealthBuffer)
            ) revert Errors.AccountNotLiquidatable();
        }
        if (txn.liquidationMode == uint8(LiquidationMode.SPREAD)) {
            // liquidating spread
            // must not have any naked perp positions open (those not part of a spread)
            // if naked perp positions exist, liquidate those first
            if (_userHasNakedPerps(liquidateeSubAccount)) {
                revert Errors.LiquidateNakedPerpsFirst();
            }
            _liquidateSpread(txn);
        } else if (txn.liquidationMode == uint8(LiquidationMode.SPOT)) {
            // user must not have any perp positions open at all.
            // even those that are part of a spread
            // if perp positions exist, liquidate those first
            if (_perpCrucible().getOpenPositionIds(liquidateeSubAccount).length > 0) {
                revert Errors.LiquidatePerpsFirst();
            }
            _liquidateSpot(txn);
        } else if (txn.liquidationMode == uint8(LiquidationMode.PERP)) {
            _liquidateNakedPerp(txn);
        } else {
            revert Errors.InvalidLiquidation();
        }

        // -- check liquidator can safely assume the risk
        if (_furnace().getSubAccountHealth(liquidatorSubAccount, true) < 0) {
            revert Errors.LiquidatorBelowInitialHealth();
        }
    }

    // Internal
    //////////////////////////////////////

    /// @notice validates some properties before calling _handleSpotLiquidation
    function _liquidateSpot(Structs.LiquidateSubAccount calldata txn) internal {
        address spotAssetAddress = _productCatalogue().productIdToBaseAsset(txn.productId);
        uint256 spotBalance = _ciao().balances(
            Commons.getSubAccount(txn.liquidatee, txn.liquidateeSubAccountId), spotAssetAddress
        );
        // can not liquidate core collateral
        if (txn.productId == 1) revert Errors.CanNotLiquidateCoreCollateral();
        _validateLiquidationQuantity(spotBalance, txn.quantity);
        _handleSpotLiquidation(txn, spotAssetAddress, false);
    }

    /// @notice validates some properties then liquidates spot and perp components separately
    /// @dev calls _handleSpotLiquidation(), _handlePerpLiquidation() with isPartOfSpread == true
    function _liquidateSpread(Structs.LiquidateSubAccount calldata txn) internal {
        address liquidateeSubAccount =
            Commons.getSubAccount(txn.liquidatee, txn.liquidateeSubAccountId);
        Structs.PositionState memory perpPos =
            _perpCrucible().subAccountPositions(txn.productId, liquidateeSubAccount);
        address spotAssetAddress = _productCatalogue().productIdToBaseAsset(txn.productId);
        uint256 spotBalance = _ciao().balances(liquidateeSubAccount, spotAssetAddress);
        _validateLiquidationQuantity(perpPos.quantity, txn.quantity);
        _validateLiquidationQuantity(spotBalance, txn.quantity);
        _handleSpotLiquidation(txn, spotAssetAddress, true);
        _handlePerpLiquidation(txn, perpPos.isLong, true);
    }

    /// @notice validates some properties before calling _handlePerpLiquidation
    function _liquidateNakedPerp(Structs.LiquidateSubAccount calldata txn) internal {
        Structs.PositionState memory perpPos = _getSingleNakedPerpPosition(
            txn.productId, Commons.getSubAccount(txn.liquidatee, txn.liquidateeSubAccountId)
        );
        _validateLiquidationQuantity(perpPos.quantity, txn.quantity);
        _handlePerpLiquidation(txn, perpPos.isLong, false);
    }

    /// @notice liquidates a spot asset into coreCollateralAsset at the calculated liquidation price
    /// @notice liquidation price is calculated differently if part of a spread
    /// @notice funnels a portion of the liquidation profits into the insurance fund
    function _handleSpotLiquidation(
        Structs.LiquidateSubAccount calldata txn,
        address spotAssetAddress,
        bool isPartOfSpread
    ) internal {
        address liquidatorSubAccount =
            Commons.getSubAccount(txn.liquidator, txn.liquidatorSubAccountId);
        address liquidateeSubAccount =
            Commons.getSubAccount(txn.liquidatee, txn.liquidateeSubAccountId);
        uint32 spotProductId = _productCatalogue().baseAssetQuoteAssetSpotIds(
            spotAssetAddress, _ciao().coreCollateralAddress()
        );
        Structs.LiquidationVars memory vars;
        vars.oraclePrice = _furnace().prices(spotProductId);
        if (isPartOfSpread) {
            vars.liquidationPrice = _getSpreadLiquidationPrice(
                spotAssetAddress,
                vars.oraclePrice,
                true // isSpot
            );
        } else {
            vars.liquidationPrice = _getLiquidationPrice(
                spotProductId,
                vars.oraclePrice,
                true // is long by default for spot
            );
        }
        vars.liquidationPayment = vars.liquidationPrice.mul(txn.quantity);
        vars.liquidationFees =
            (vars.oraclePrice - vars.liquidationPrice).mul(liquidationFeeFraction).mul(txn.quantity);
        ICiao ciao = _ciao();
        ciao.incrementFee(ciao.coreCollateralAddress(), vars.liquidationFees, ciao.insurance());
        ciao.updateBalance(
            liquidateeSubAccount,
            liquidatorSubAccount,
            txn.quantity,
            vars.liquidationPayment,
            txn.productId,
            false,
            0,
            0,
            0
        );
        ciao.settleCoreCollateral(liquidatorSubAccount, -int256(vars.liquidationFees));

        emit Events.Liquidated(
            liquidatorSubAccount,
            liquidateeSubAccount,
            1, // spot
            spotProductId,
            txn.quantity,
            vars.liquidationPrice,
            vars.liquidationFees
        );
    }

    /// @notice liquidates perp position at the calculated liquidation price
    /// @notice liquidation price is calculated differently if part of a spread
    /// @notice funnels a portion of the liquidation profits into the insurance fund
    function _handlePerpLiquidation(
        Structs.LiquidateSubAccount calldata txn,
        bool isLong,
        bool isPartOfSpread
    ) internal {
        address liquidatorSubAccount =
            Commons.getSubAccount(txn.liquidator, txn.liquidatorSubAccountId);
        address liquidateeSubAccount =
            Commons.getSubAccount(txn.liquidatee, txn.liquidateeSubAccountId);
        Structs.LiquidationVars memory vars;
        vars.oraclePrice = _furnace().prices(txn.productId);

        if (isPartOfSpread) {
            vars.liquidationPrice = _getSpreadLiquidationPrice(
                _productCatalogue().productIdToBaseAsset(txn.productId),
                vars.oraclePrice,
                false // isSpot
            );
        } else {
            vars.liquidationPrice = _getLiquidationPrice(txn.productId, vars.oraclePrice, isLong);
        }

        vars.liquidationPayment = vars.liquidationPrice.mul(txn.quantity);
        vars.liquidationFees = (
            isLong
                ? (vars.oraclePrice - vars.liquidationPrice)
                : (vars.liquidationPrice - vars.oraclePrice)
        ).mul(liquidationFeeFraction).mul(txn.quantity);
        ICiao ciao = _ciao();
        ciao.incrementFee(ciao.coreCollateralAddress(), vars.liquidationFees, ciao.insurance());
        (int256 liquidatorPnl, int256 liquidateePnl) = _perpCrucible().updatePosition(
            liquidatorSubAccount, // taker
            liquidateeSubAccount, // maker
            txn.productId,
            Structs.NewPosition(vars.liquidationPrice, txn.quantity, !isLong)
        );
        ciao.settleCoreCollateral(
            liquidatorSubAccount, liquidatorPnl - int256(vars.liquidationFees)
        );
        ciao.settleCoreCollateral(liquidateeSubAccount, liquidateePnl);
        emit Events.Liquidated(
            liquidatorSubAccount,
            liquidateeSubAccount,
            2,
            txn.productId,
            txn.quantity,
            vars.liquidationPrice,
            vars.liquidationFees
        );
    }

    /// @notice validates that the liquidation quantity is above zero and not more than the liquidatee's pos size
    function _validateLiquidationQuantity(uint256 existingPosSize, uint256 liquidationQuantity)
        internal
        pure
    {
        if (existingPosSize == 0) revert Errors.NoPositionExistsForId();
        if (liquidationQuantity == 0 || liquidationQuantity > existingPosSize) {
            revert Errors.InvalidLiquidationSize();
        }
    }

    function _getLiquidationPrice(uint32 productId, uint256 oraclePrice, bool isLong)
        internal
        view
        returns (uint256 liquidationPrice)
    {
        uint64 weight = isLong
            ? _furnace().getProductRiskWeights(productId).maintenanceLongWeight
            : _furnace().getProductRiskWeights(productId).maintenanceShortWeight;
        return oraclePrice.mul(weight + liqPriceNumerator).div(liqPriceDenominator);
    }

    function _getSpreadLiquidationPrice(
        address spotComponentAddress,
        uint256 oraclePrice,
        bool isSpot
    ) internal view returns (uint256 liquidationPrice) {
        uint64 spreadPenalty = _furnace().getSpreadPenalty(spotComponentAddress).maintenance;
        if (isSpot) {
            return oraclePrice.mul(1e18 - spreadPenalty);
        } else {
            // is short perp component, liquidate at a higher price
            return oraclePrice.mul(1e18 + spreadPenalty);
        }
    }

    /// @notice checks for perp positions that are not part of a spread
    ///         i.e, short perp collateralised with long spot asset
    function _userHasNakedPerps(address subAccount) internal view returns (bool) {
        uint256[] memory perpPositionIds = _perpCrucible().getOpenPositionIds(subAccount);

        uint256 numPerpPositions = perpPositionIds.length;
        if (numPerpPositions == 0) return false;
        for (uint256 i = 0; i < numPerpPositions; i++) {
            Structs.PositionState memory perpPos =
                _getSingleNakedPerpPosition(uint32(perpPositionIds[i]), subAccount);
            if (perpPos.quantity == 0) continue;
            return true;
        }
        return false;
    }

    function _getSingleNakedPerpPosition(uint32 perpId, address subAccount)
        internal
        view
        returns (Structs.PositionState memory)
    {
        Structs.PositionState memory perpPosition =
            _perpCrucible().subAccountPositions(uint32(perpId), subAccount);
        if (!perpPosition.isLong) {
            // if short, get spot balance to determine spread quantity
            address spotAssetAddress = _productCatalogue().productIdToBaseAsset(perpId);

            uint256 spotBalance = _ciao().balances(subAccount, spotAssetAddress);
            if (_furnace().getSpotRiskWeights(spotAssetAddress).maintenanceLongWeight == 0) {
                // invalid as spread
                spotBalance = 0;
            }
            if (_furnace().getSpreadPenalty(spotAssetAddress).maintenance == 1e18) {
                // invalid as spread
                spotBalance = 0;
            }
            if (perpPosition.quantity > spotBalance) {
                perpPosition.quantity = perpPosition.quantity - spotBalance;
            } else {
                perpPosition.quantity = 0;
            }
        }
        return perpPosition;
    }
}
