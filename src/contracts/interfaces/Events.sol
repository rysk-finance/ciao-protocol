// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.8.19;

import "./Structs.sol";

interface Events {
    // Ciao Events
    ////////////////////////

    event Deposit(
        address indexed account, uint8 indexed subAccountId, address indexed asset, uint256 quantity
    );
    event RequestWithdrawal(
        address indexed account, uint8 indexed subAccountId, address indexed asset, uint256 quantity
    );
    event ExecuteWithdrawal(
        address indexed account, uint8 indexed subAccountId, address indexed asset, uint256 quantity
    );
    event BalanceChanged(
        address indexed subAccount, address indexed asset, int256 balanceBefore, int256 balanceAfter
    );

    event FeeRecipientChanged(address feeRecipient);
    event InsuranceChanged(address insurance);
    event MinDepositAmountChanged(address asset, uint256 minDepositAmount);
    event CoreCollateralAddressChanged(address coreCollateralAddress);

    // OrderDispatch Events
    //////////////////////////////////////

    event OrderMatched(bytes32 takerDigest, bytes32 makerDigest);
    event TxFeeChanged(uint8 action, uint256 txFee);

    // AddressManifest Events
    //////////////////////////////////////

    event ManifestUpdated(uint256 indexed id, address indexed newAddress);
    event SignerApprovalUpdated(
        address indexed account,
        uint8 indexed subAccountId,
        address indexed approvedSigner,
        bool isApproved
    );
    event OperatorUpdated(address operator);
    event AdminUpdated(address admin);

    // Product Catalogue Events
    ////////////////////////////

    event ProductTradeabilityChanged(uint32 indexed productId, bool isProductTradeable);
    event ProductFeesChanged(
        uint32 indexed productId, uint256 takerFee, uint256 makerFee, bool isMakerRebate
    );
    event ProductSet(
        uint32 indexed productId,
        uint8 indexed productType,
        address indexed baseAsset,
        address quoteAsset,
        uint128 takerFee,
        uint128 makerFee,
        bool isMakerRebate
    );
    event BaseAssetQuoteAssetSpotIdSet(
        address indexed baseAsset, address indexed quoteAsset, uint32 productId
    );

    // Furnace Events
    //////////////////////////////////////
    event RiskWeightsSet(
        uint32 indexed productId,
        uint64 initialLongWeight,
        uint64 initialShortWeight,
        uint64 maintenanceLongWeight,
        uint64 maintenanceShortWeight
    );

    event SpotRiskWeightsSet(
        address indexed spotAsset,
        uint64 initialLongWeight,
        uint64 initialShortWeight,
        uint64 maintenanceLongWeight,
        uint64 maintenanceShortWeight
    );

    event SpreadPenaltySet(address indexed spotAsset, uint64 initial, uint64 maintenance);
    event BaseAssetQuotePerpSet(address indexed spotAddress, uint32 productId);

    // Liquidation Events
    //////////////////////////////////////

    event RequiresDispatchCallSet(bool requiresDispatchCall);
    event Liquidated( // for a spread this is the perpId
        address liquidator,
        address liquidatee,
        uint8 mode,
        uint32 productId,
        uint256 quantity,
        uint256 liquidationPrice,
        uint256 liquidationFees
    );
    event LiqPriceNumeratorSet(uint256 liqPriceNumerator);
    event LiqPriceDenominatorSet(uint256 liqPriceDenominator);
    event LiquidationFeeFractionSet(uint256 liquidationFeeFraction);

    // Perp Crucible Events
    //////////////////////////////////////

    event PerpPositionUpdated(
        address indexed subAccount,
        uint32 indexed productId,
        Structs.PositionState posBefore,
        Structs.PositionState posAfter
    );
}
