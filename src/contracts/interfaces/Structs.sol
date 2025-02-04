// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.8.19;

import "./IPerpCrucible.sol";

library Structs {
    // Ciao Structs
    ///////////////////////////

    struct WithdrawalReceipt {
        uint256 quantity; // e18
        uint256 requestTimestamp;
    }

    // OrderDispatch Structs
    ///////////////////////////

    struct Deposit {
        address account;
        uint8 subAccountId;
        address asset;
        uint256 quantity;
        uint64 nonce;
    }

    struct Withdraw {
        address account;
        uint8 subAccountId;
        address asset;
        uint128 quantity;
        uint64 nonce;
    }

    struct ApproveSigner {
        address account;
        uint8 subAccountId;
        address approvedSigner;
        bool isApproved;
        uint64 nonce;
    }

    struct MatchedOrder {
        bytes taker;
        bytes[] makers;
    }

    struct SingleMatchedOrder {
        Order taker;
        bytes32 takerDigest;
        Order maker;
        bytes32 makerDigest;
    }

    // orderType:
    // 0: LIMIT, 1: LIMIT_MAKER, 2: MARKET, 3: STOP_LOSS, 4: STOP_LOSS_LIMIT, 5: TAKE_PROFIT, 6: TAKE_PROFIT_LIMIT
    // timeInForce:
    // 0: GTC, 1: IOC, 2: FOK
    struct Order {
        address account;
        uint8 subAccountId; // id of the sub account being used
        uint32 productId;
        bool isBuy; // 0 for sell, 1 for buy
        uint8 orderType;
        uint8 timeInForce;
        uint64 expiration;
        uint128 price;
        uint128 quantity;
        uint64 nonce;
    }

    struct LiquidateSubAccount {
        address liquidator;
        uint8 liquidatorSubAccountId;
        address liquidatee;
        uint8 liquidateeSubAccountId;
        uint8 liquidationMode;
        uint32 productId; // perp ID in case of spread
        uint128 quantity;
        uint64 nonce;
    }

    struct OrderMatchParams {
        address takerSubAccount;
        address makerSubAccount;
        uint256 baseQuantity;
        uint32 productId;
        bool takerIsBuy;
        uint128 executionPrice;
        bool isFirstTime;
    }

    // Furnace Structs
    ///////////////////////////

    /// @dev ProductRiskWeights values all denominated in e18
    struct ProductRiskWeights {
        uint64 initialLongWeight;
        uint64 initialShortWeight;
        uint64 maintenanceLongWeight;
        uint64 maintenanceShortWeight;
    }

    struct SpreadPenalties {
        uint64 initial;
        uint64 maintenance;
    }

    struct SubAccountHealthVars {
        address[] spotAssets;
        uint256 assetsLen;
        IPerpCrucible perpCrucible;
        uint256[] perpPositionIds;
        uint256 numPerpPositions;
    }

    // Liquidation Structs
    ///////////////////////////

    struct LiquidationVars {
        uint256 liquidationPrice;
        uint256 oraclePrice;
        uint256 liquidationPayment;
        uint256 liquidationFees;
    }

    // PerpCrucible Structs
    ///////////////////////////

    struct PositionState {
        uint256 avgEntryPrice;
        uint256 quantity;
        bool isLong;
        int256 initCumFunding;
    }

    struct NewPosition {
        uint256 executionPrice;
        uint256 quantity;
        bool isLong;
    }

    // ProductCatalogue Structs
    ////////////////////////////

    // each product represents an order book. for example, ETH/USDC spot market will have a different ID to ETH/BTC spot market.
    struct Product {
        uint8 productType; // 1 for spot, 2 for perp, 3 for move, 4 for option
        address baseAsset;
        address quoteAsset;
        bool isProductTradeable;
        uint128 takerFee;
        uint128 makerFee;
        bool isMakerRebate;
    }

    // Reader Structs
    //////////////////////////

    struct SpotPosition {
        address spotAsset;
        uint256 spotBalance;
        uint256 spotPrice;
        ProductRiskWeights spotRiskWeights;
    }
    struct PerpPosition {
        uint256 perpPositionId;
        PositionState perpPosition;
        uint256 perpPrice;
        int256 currentCumFunding;
        ProductRiskWeights perpRiskWeights;
    }
    struct SpreadPosition {
        uint256 spotPrice;
        uint256 perpPrice;
        int256 currentCumFunding;
        uint256 spreadQuantity;
        PositionState perpPos;
        SpreadPenalties spreadPenalty;
    }

    struct UserAndSystemState {
        uint256 coreCollateralDebt;
        address coreCollateralAddress;
        SpotPosition[] spots;
        PerpPosition[] perps;
        SpreadPosition[] spreads;
    }
}
