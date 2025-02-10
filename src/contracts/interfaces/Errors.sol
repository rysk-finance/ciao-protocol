// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.8.19;

interface Errors {
    // Ciao Errors
    ///////////////

    error NoAssetsToWithdraw();
    error BalanceInsufficient();
    error DepositQuantityInvalid();
    error WithdrawQuantityInvalid();
    error SubAccountHasPositions();

    // OrderDispatch Errors
    ////////////////////////

    error TxIdInvalid();
    error SideInvalid();
    error PriceInvalid();
    error ProductInvalid();
    error OrderCheckFailed();
    error SignatureInvalid();
    error ProductIdMismatch();
    error SubAccountHealthy();
    error NoCoreCollateralDebt();
    error OrderByteLengthInvalid();
    error AdminApprovedSignerFalse();

    // ProductCatalogue Errors
    ///////////////////////////

    error ProductNotSet();
    error ProductIdInvalid();
    error BaseAssetInvalid();
    error QuoteAssetInvalid();
    error ProductAlreadySet();
    error MakerRebateFeeInvalid();
    error SpotPairAlreadyExists();

    // Furnace Errors
    ///////////////////////////

    error InvalidArrayLength();

    // AddressManifest Errors
    ///////////////////////////

    error SenderInvalid();
    error DigestedAlready();

    // Liquidation Errors
    ///////////////////////////

    error LiquidatedTooMuch();
    error InvalidLiquidation();
    error LiquidatePerpsFirst();
    error NoPositionExistsForId();
    error AccountNotLiquidatable();
    error InvalidLiquidationSize();
    error LiquidateNakedPerpsFirst();
    error LiquidatorBelowInitialHealth();
    error LiquidatorCanNotBeLiquidatee();
    error CanNotLiquidateCoreCollateral();
    error InvalidLiquidateFeeFractionValue();
}
