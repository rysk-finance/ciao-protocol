// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/utils/cryptography/EIP712Upgradeable.sol";

import "./libraries/Parser.sol";
import "./libraries/Commons.sol";
import "./libraries/BasicMath.sol";
import "./libraries/AccessControl.sol";

import "./interfaces/ICiao.sol";
import "./interfaces/Events.sol";
import "./interfaces/Errors.sol";
import "./interfaces/Structs.sol";
import "./interfaces/IFurnace.sol";
import "./interfaces/ICrucible.sol";
import "./interfaces/ILiquidation.sol";
import "./interfaces/IPerpCrucible.sol";
import "./interfaces/IProductCatalogue.sol";

//    ____           __          ____  _                  __       __
//   / __ \_________/ /__  _____/ __ \(_)________  ____ _/ /______/ /_
//  / / / / ___/ __  / _ \/ ___/ / / / / ___/ __ \/ __ `/ __/ ___/ __ \
// / /_/ / /  / /_/ /  __/ /  / /_/ / (__  ) /_/ / /_/ / /_/ /__/ / / /
// \____/_/   \__,_/\___/_/  /_____/_/____/ .___/\__,_/\__/\___/_/ /_/
//                                       /_/
////////////////////////////////////////////////////////////////////////

/// @notice Contract for routing orders from the off chain engine to the protocol
///         Mk 0.0.0
contract OrderDispatch is EIP712Upgradeable, AccessControl {
    // Governance Variables
    //////////////////////////////////////

    /// @notice mapping of product type to manifest index for appropriate crucible
    mapping(uint8 => uint8) public instrumentToCrucible;
    /// @notice fee mapping for various transaction types
    mapping(uint8 => uint256) public txFees;

    // Constants and Immutables
    //////////////////////////////////////

    string constant APPROVE_SIGNER =
        "ApproveSigner(address account,uint8 subAccountId,address approvedSigner,bool isApproved,uint64 nonce)";

    string constant DEPOSIT =
        "Deposit(address account,uint8 subAccountId,address asset,uint256 quantity,uint64 nonce)";

    string constant WITHDRAW =
        "Withdraw(address account,uint8 subAccountId,address asset,uint128 quantity,uint64 nonce)";

    string constant LIQUIDATE_SUB_ACCOUNT =
        "LiquidateSubAccount(address liquidator,uint8 liquidatorSubAccountId,address liquidatee,uint8 liquidateeSubAccountId,uint8 liquidationMode,uint32 productId,uint128 quantity,uint64 nonce)";

    string constant ORDER =
        "Order(address account,uint8 subAccountId,uint32 productId,bool isBuy,uint8 orderType,uint8 timeInForce,uint64 expiration,uint128 price,uint128 quantity,uint64 nonce)";

    uint8 private constant MATCH_ORDER_TX_FEE_INDEX = 0;

    function initialize(address _addressManifest) external initializer {
        __EIP712_init("ciao", "0.0.0");
        __AccessControl_init(_addressManifest);
        addressManifest = IAddressManifest(_addressManifest);
        instrumentToCrucible[1] = 6;
        instrumentToCrucible[2] = 7;
    }

    enum Action {
        MatchOrder,
        UpdateProductPrice,
        Deposit,
        ApproveSigner,
        ExecuteWithdrawal,
        ForceSwap,
        Liquidate,
        UpdateCumulativeFunding,
        AutoDeleverage
    }

    // External - Access Controlled
    //////////////////////////////////////

    function setTxFees(uint8 action, uint256 _fee) external {
        require(msg.sender == addressManifest.admin(), "UNAUTHORIZED");
        txFees[action] = _fee;
        emit Events.TxFeeChanged(action, _fee);
    }

    /// @notice Allows admin to approve a signer on user's behalf while bypassing ingresso
    ///         Can only be used to set `isApproved` to true
    /// @dev Accessable by Admin
    /// @param approval struct containing user's addresss, subaccount, and approved signer address
    /// @param signature user's signature to be verified
    function approveSignerAdmin(Structs.ApproveSigner calldata approval, bytes calldata signature)
        external
    {
        _isAdmin();
        if (approval.isApproved == false) revert Errors.AdminApprovedSignerFalse();
        bytes32 digest = getApprovalDigest(approval);
        addressManifest.checkInDigestAsUsed(digest);
        address recoveredSigner = ECDSA.recover(digest, signature);
        if ((recoveredSigner == address(0)) || recoveredSigner != approval.account) {
            revert Errors.SignatureInvalid();
        }
        addressManifest.approveSigner(
            approval.account, approval.subAccountId, approval.approvedSigner, true
        );
    }

    /// @notice The primary entrypoint for all action routing from the off-chain system
    ///         the actions come in a big byte array that is parsed in this function to
    ///         retrieve all the action data for a given batch of orders to process.
    /// @dev function can only be accessed by the operator
    function ingresso(bytes[] calldata payload) external {
        // make sure the sender is the operator
        require(msg.sender == addressManifest.operator(), "UNAUTHORIZED");
        uint256 length = payload.length;
        for (uint256 i; i < length; i++) {
            Action txId = Action(uint8(payload[i][0]));
            if (txId == Action.MatchOrder) {
                matchOrder(payload[i][1:]);
            } else if (txId == Action.UpdateProductPrice) {
                updateProductPrice(payload[i][1:]);
            } else if (txId == Action.Deposit) {
                deposit(payload[i][1:]);
            } else if (txId == Action.ApproveSigner) {
                approveSigner(payload[i][1:]);
            } else if (txId == Action.ExecuteWithdrawal) {
                withdraw(payload[i][1:]);
            } else if (txId == Action.ForceSwap) {
                forceSwap(payload[i][1:]);
            } else if (txId == Action.Liquidate) {
                liquidate(payload[i][1:]);
            } else if (txId == Action.UpdateCumulativeFunding) {
                updateCumulativeFunding(payload[i][1:]);
            } else if (txId == Action.AutoDeleverage) {
                autoDeleverage((payload[i][1:]));
            } else {
                revert Errors.TxIdInvalid();
            }
        }
    }

    /// @notice function for depositing into Ciao
    /// @dev function can only be accessed by the operator
    function deposit(bytes calldata payload) internal {
        (Structs.Deposit memory depo, bytes memory depositSig) = Parser.parseDepositBytes(payload);
        bytes32 digest = getDepositDigest(depo);
        addressManifest.checkInDigestAsUsed(digest);
        if (!checkSignature(depo.account, depo.subAccountId, digest, depositSig)) {
            revert Errors.SignatureInvalid();
        }
        ICiao(Commons.ciao(address(addressManifest))).deposit(
            depo.account, depo.subAccountId, depo.quantity, depo.asset
        );
    }

    /// @notice function for withdraw from Ciao
    /// @dev function can only be accessed by the operator
    function withdraw(bytes calldata payload) internal {
        (Structs.Withdraw memory withdrawal, bytes memory withdrawSig) =
            Parser.parseWithdrawBytes(payload);
        bytes32 digest = getWithdrawDigest(withdrawal);
        addressManifest.checkInDigestAsUsed(digest);
        ICiao ciao = ICiao(Commons.ciao(address(addressManifest)));
        // if we have a valid signature then withdraw using that
        // if not check for the existence of a withdrawal receipt
        if (!checkSignature(withdrawal.account, withdrawal.subAccountId, digest, withdrawSig)) {
            if (
                ciao.withdrawalReceipts(
                    Commons.getSubAccount(withdrawal.account, withdrawal.subAccountId),
                    withdrawal.asset
                ).quantity < withdrawal.quantity
            ) revert Errors.SignatureInvalid();
        }
        ciao.executeWithdrawal(
            withdrawal.account,
            withdrawal.subAccountId,
            uint256(withdrawal.quantity),
            withdrawal.asset
        );
    }

    /// @notice function for updating product prices
    /// @dev function can only be accessed by the operator
    function updateProductPrice(bytes calldata payload) internal {
        bytes memory _payload = payload;
        IFurnace(Commons.furnace(address(addressManifest))).setPrices(_payload);
    }

    /// @notice function for updating product cumulative funding
    /// @dev function can only be accessed by the operator
    function updateCumulativeFunding(bytes calldata payload) internal {
        bytes memory _payload = payload;
        IPerpCrucible(Commons.perpCrucible(address(addressManifest))).updateCumulativeFundings(
            _payload
        );
    }

    /// @notice function for force swapping in the case that a user has core collateral debt
    ///         or are in a position to be liquidated, in which case a swap is executed on their
    ///         behalf to rectify their margin issues.
    /// @dev function can only be accessed by the operator
    function forceSwap(bytes calldata payload) internal {
        bool coreCollatSwapOrLiquidationSwap = uint8(payload[0]) == 1;
        uint64 offchainDepositCount = uint64(bytes8(payload[1:9]));
        Structs.MatchedOrder memory forceMatchedOrder =
            abi.decode(payload[9:], (Structs.MatchedOrder));
        // get the taker order digest and check the signature
        Structs.SingleMatchedOrder memory order;
        // we dont conduct a signature check on the taker
        (order.taker,) = Parser.parseOrderBytes(forceMatchedOrder.taker, true);
        order.takerDigest = getOrderDigest(order.taker);
        address takerSubAccount =
            Commons.getSubAccount(order.taker.account, order.taker.subAccountId);
        bool recentDeposit = offchainDepositCount
            < ICiao(Commons.ciao(address(addressManifest))).depositCount(takerSubAccount);
        if (coreCollatSwapOrLiquidationSwap) {
            // if theres a core collateral tag then we check for core collateral debt on the taker
            if (
                ICiao(Commons.ciao(address(addressManifest))).coreCollateralDebt(takerSubAccount)
                    > 0 || recentDeposit
            ) {
                // if there is debt or recent deposit then we execute the swap as ordered
                _matchOrder(false, forceMatchedOrder, order);
            } else {
                revert Errors.NoCoreCollateralDebt();
            }
        } else {
            // if theres a liquidation request then we check if their health is below maintenance
            if (
                IFurnace(Commons.furnace(address(addressManifest))).getSubAccountHealth(
                    takerSubAccount, false
                )
                    < int256(
                        ILiquidation(Commons.liquidation(address(addressManifest)))
                            .liquidationHealthBuffer()
                    ) || recentDeposit
            ) {
                // if the health is below buffer then we execute the swap as ordered
                _matchOrder(false, forceMatchedOrder, order);
            } else {
                revert Errors.SubAccountHealthy();
            }
        }
    }

    /// @notice function for unwinding an unhealthy position as a last resort before insolvency.
    ///         Used after attempts to force-swap, then liquidate position using the insurance fund fail,
    ///         and account equity drops below a safe threshold.
    ///         Closes the position with most healthy traders who have open positions on the opposite side.
    /// @dev function can only be accessed by the operator
    /// @dev no signature checks for taker or maker since this is a last resort.
    function autoDeleverage(bytes calldata payload) internal {
        Structs.MatchedOrder memory forceMatchedOrder = abi.decode(payload, (Structs.MatchedOrder));
        // get the taker order
        Structs.SingleMatchedOrder memory order;
        // no signature checks for ADL
        (order.taker,) = Parser.parseOrderBytes(forceMatchedOrder.taker, true);
        order.takerDigest = getOrderDigest(order.taker);
        _matchOrder(true, forceMatchedOrder, order);
    }

    /// @notice function for liquidating a sub account
    /// @dev function can only be accessed by the operator
    function liquidate(bytes calldata payload) internal {
        (
            Structs.LiquidateSubAccount memory liqui,
            bytes memory liquidateSig,
            uint64 offchainDepositCount
        ) = Parser.parseLiquidateBytes(payload);
        bytes32 digest = getLiquidateDigest(liqui);
        addressManifest.checkInDigestAsUsed(digest);
        if (!checkSignature(liqui.liquidator, liqui.liquidatorSubAccountId, digest, liquidateSig)) {
            revert Errors.SignatureInvalid();
        }
        bool noRecentDeposit = false;
        if (
            offchainDepositCount
                >= ICiao(Commons.ciao(address(addressManifest))).depositCount(
                    Commons.getSubAccount(liqui.liquidatee, liqui.liquidateeSubAccountId)
                )
        ) {
            noRecentDeposit = true;
        }
        ILiquidation(Commons.liquidation(address(addressManifest))).liquidateSubAccount(
            liqui, noRecentDeposit
        );
    }

    /// @notice function for approving a signer
    /// @dev function can only be accessed by the operator
    function approveSigner(bytes calldata payload) internal {
        (Structs.ApproveSigner memory approval, bytes memory approvalSig) =
            Parser.parseApprovedSignerBytes(payload);
        bytes32 digest = getApprovalDigest(approval);
        addressManifest.checkInDigestAsUsed(digest);
        address recoveredSigner = ECDSA.recover(digest, approvalSig);
        if ((recoveredSigner == address(0)) || recoveredSigner != approval.account) {
            revert Errors.SignatureInvalid();
        }
        addressManifest.approveSigner(
            approval.account, approval.subAccountId, approval.approvedSigner, approval.isApproved
        );
    }

    /// @notice function for matching an order
    /// @dev function can only be accessed by the operator
    function matchOrder(bytes calldata payload) internal {
        Structs.MatchedOrder memory orders = abi.decode(payload, (Structs.MatchedOrder));
        // get the taker order digest and check the signature
        Structs.SingleMatchedOrder memory order;
        bytes memory takerSig;
        (order.taker, takerSig) = Parser.parseOrderBytes(orders.taker, false);
        order.takerDigest = getOrderDigest(order.taker);
        if (
            !checkSignature(
                order.taker.account, order.taker.subAccountId, order.takerDigest, takerSig
            )
        ) revert Errors.SignatureInvalid();
        _matchOrder(false, orders, order);
    }

    // Getters
    //////////////////////////////////////

    /// @notice function to check a account corresponds to the signature of a given order digest
    /// @dev uses ECDSA, to get the digest you can use getDigest with the Order struct
    /// @param account the trader of the order, should correspond to the signer
    /// @param subAccountId the subAccount to check for an approvedSigner for
    /// @param digest the hashed version of the order
    /// @param signature the EIP712 signature corresponding to the order, signed by the trader
    function checkSignature(
        address account,
        uint8 subAccountId,
        bytes32 digest,
        bytes memory signature
    ) public view returns (bool) {
        address recoveredSigner = ECDSA.recover(digest, signature);
        if ((recoveredSigner != address(0)) && recoveredSigner == account) {
            return true;
        } else {
            return addressManifest.approvedSigners(
                Commons.getSubAccount(account, subAccountId), recoveredSigner
            );
        }
    }

    /// @notice function to create the digest or hashed version of the order, used for signature validation and storage keys
    /// @param order the order struct that contains details of the order
    function getOrderDigest(Structs.Order memory order) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(bytes(ORDER)),
                    order.account,
                    order.subAccountId,
                    order.productId,
                    order.isBuy,
                    order.orderType,
                    order.timeInForce,
                    order.expiration,
                    order.price,
                    order.quantity,
                    order.nonce
                )
            )
        );
    }

    /// @notice function to create the digest or hashed version of the approvedSigner, used for signature validation and storage keys
    /// @param approval the order struct that contains details of the order
    function getApprovalDigest(Structs.ApproveSigner memory approval)
        public
        view
        returns (bytes32)
    {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(bytes(APPROVE_SIGNER)),
                    approval.account,
                    approval.subAccountId,
                    approval.approvedSigner,
                    approval.isApproved,
                    approval.nonce
                )
            )
        );
    }

    /// @notice function to create the digest or hashed version of the liquidateSubAccount, used for signature validation and storage keys
    /// @param liquidation the order struct that contains details of the order
    function getLiquidateDigest(Structs.LiquidateSubAccount memory liquidation)
        public
        view
        returns (bytes32)
    {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(bytes(LIQUIDATE_SUB_ACCOUNT)),
                    liquidation.liquidator,
                    liquidation.liquidatorSubAccountId,
                    liquidation.liquidatee,
                    liquidation.liquidateeSubAccountId,
                    liquidation.liquidationMode,
                    liquidation.productId,
                    liquidation.quantity,
                    liquidation.nonce
                )
            )
        );
    }

    /// @notice function to create the digest or hashed version of the deposit, used for signature validation and storage keys
    /// @param depo the order struct that contains details of the order
    function getDepositDigest(Structs.Deposit memory depo) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(bytes(DEPOSIT)),
                    depo.account,
                    depo.subAccountId,
                    depo.asset,
                    depo.quantity,
                    depo.nonce
                )
            )
        );
    }

    /// @notice function to create the digest or hashed version of the withdrawal, used for signature validation and storage keys
    /// @param withdrawal the order struct that contains details of the order
    function getWithdrawDigest(Structs.Withdraw memory withdrawal) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(bytes(WITHDRAW)),
                    withdrawal.account,
                    withdrawal.subAccountId,
                    withdrawal.asset,
                    uint128(withdrawal.quantity),
                    withdrawal.nonce
                )
            )
        );
    }

    /// @notice function to handle the perp position quantity if the trade is of reduce only type
    /// @notice the trade quantity should become the smallest of the user position (depending on if it is the taker or maker) or the given baseQuantity
    function _quantityIfReduceOnly(
        address takerSubAccount,
        address makerSubAccount,
        Structs.SingleMatchedOrder memory order,
        IPerpCrucible crucible,
        uint256 baseQuantity
    ) internal view returns (uint256) {
        if (order.taker.orderType >= 3 && order.taker.orderType <= 7) {
            Structs.PositionState memory position =
                crucible.subAccountPositions(order.taker.productId, takerSubAccount);
            baseQuantity = BasicMath.min(baseQuantity, position.quantity);
        }
        if (order.maker.orderType >= 3 && order.maker.orderType <= 7) {
            Structs.PositionState memory position =
                crucible.subAccountPositions(order.maker.productId, makerSubAccount);
            baseQuantity = BasicMath.min(baseQuantity, position.quantity);
        }
        return baseQuantity;
    }

    // Internal
    //////////////////////////////////////

    function _matchOrder(
        bool isAdl, // only set to true in the case of an ADL
        Structs.MatchedOrder memory orders,
        Structs.SingleMatchedOrder memory order
    ) internal {
        uint256 makerLength = orders.makers.length;
        uint128 takerQuantityRemaining;
        for (uint256 j; j < makerLength; j++) {
            bytes memory makerSig;
            // get the maker order digest and check the maker signature (if not an ADL)
            (order.maker, makerSig) = Parser.parseOrderBytes(orders.makers[j], isAdl);
            order.makerDigest = getOrderDigest(order.maker);
            if (!isAdl) {
                if (
                    !checkSignature(
                        order.maker.account, order.maker.subAccountId, order.makerDigest, makerSig
                    )
                ) revert Errors.SignatureInvalid();
            }
            (address takerSubAccount, address makerSubAccount, Structs.Product memory product) =
                _getOrderDetails(order);
            ICrucible crucible = ICrucible(
                Commons.crucible(
                    address(addressManifest), instrumentToCrucible[product.productType]
                )
            );
            // get the actual quantitys, accounting for any partial fills, this can never go below 0, if it does the order check will fail
            takerQuantityRemaining =
                order.taker.quantity - crucible.filledQuantitys(order.takerDigest);
            order.maker.quantity -= crucible.filledQuantitys(order.makerDigest);
            if (!_checkOrder(order.taker) || !_checkOrder(order.maker)) {
                revert Errors.OrderCheckFailed();
            }
            // - make sure the orders are a buy and sell
            if (order.maker.isBuy == order.taker.isBuy) {
                revert Errors.SideInvalid();
            }
            // - make sure if the maker isBuy is to buy that the price is higher for the maker
            // - make sure if the maker isBuy is to sell that the price is lower for the maker
            if (order.maker.isBuy) {
                if (order.maker.price < order.taker.price) {
                    revert Errors.PriceInvalid();
                }
            } else {
                if (order.maker.price > order.taker.price) {
                    revert Errors.PriceInvalid();
                }
            }
            // compute quantitys for the trade
            uint256 baseQuantity = BasicMath.min(takerQuantityRemaining, order.maker.quantity);
            if (product.productType == 1) {
                _matchSpotOrder(
                    Structs.OrderMatchParams(
                        takerSubAccount,
                        makerSubAccount,
                        baseQuantity,
                        order.maker.productId,
                        order.taker.isBuy,
                        order.maker.price,
                        crucible.filledQuantitys(order.takerDigest) == 0,
                        isAdl
                    )
                );
            } else if (product.productType == 2) {
                baseQuantity = _quantityIfReduceOnly(
                    takerSubAccount,
                    makerSubAccount,
                    order,
                    IPerpCrucible(address(crucible)),
                    baseQuantity
                );
                _matchPerpOrder(
                    Structs.OrderMatchParams(
                        takerSubAccount,
                        makerSubAccount,
                        baseQuantity,
                        order.maker.productId,
                        order.taker.isBuy,
                        order.maker.price,
                        crucible.filledQuantitys(order.takerDigest) == 0,
                        isAdl
                    )
                );
            } else {
                revert Errors.ProductInvalid();
            }
            // handle filled quantitys
            crucible.updateFilledQuantity(
                order.takerDigest, order.makerDigest, uint128(baseQuantity)
            );
            // emit event to show order matched
            emit Events.OrderMatched(order.takerDigest, order.makerDigest);
        }
    }

    /// @notice function for matching and registering a spot order
    /// @param o orderMatchParams struct containing the details to create the order
    function _matchSpotOrder(Structs.OrderMatchParams memory o) internal {
        // - handle the balance transfers and state changes
        // - compute the quantitys based on the maker price
        uint256 quoteQuantity = BasicMath.mul(o.baseQuantity, o.executionPrice);
        // - for charging the fee we deduct the quantity from the balance update from both sides
        Structs.Product memory product = IProductCatalogue(
            Commons.productCatalogue(address(addressManifest))
        ).products(o.productId);
        uint256 takerFee;
        uint256 makerFee;
        uint256 sequencerFee;
        if (!o.isAdl) {
            if (o.takerIsBuy) {
                takerFee = BasicMath.mul(o.baseQuantity, product.takerFee);
                makerFee = BasicMath.mul(quoteQuantity, product.makerFee);
            } else {
                takerFee = BasicMath.mul(quoteQuantity, product.takerFee);
                makerFee = BasicMath.mul(o.baseQuantity, product.makerFee);
            }
            // add the sequencer fee for the taker denominated in quote
            if (o.isFirstTime) {
                sequencerFee = txFees[MATCH_ORDER_TX_FEE_INDEX];
            }
        }
        ICiao(Commons.ciao(address(addressManifest))).updateBalance(
            o.takerSubAccount,
            o.makerSubAccount,
            o.baseQuantity,
            quoteQuantity,
            o.productId,
            o.takerIsBuy,
            takerFee,
            makerFee,
            sequencerFee
        );
    }

    function _matchPerpOrder(Structs.OrderMatchParams memory o) internal {
        Structs.NewPosition memory makerPos =
            Structs.NewPosition(o.executionPrice, o.baseQuantity, !o.takerIsBuy);
        ICiao ciao = ICiao(Commons.ciao(address(addressManifest)));
        (int256 takerRealisedPnl, int256 makerRealisedPnl) = IPerpCrucible(
            Commons.perpCrucible(address(addressManifest))
        ).updatePosition(o.takerSubAccount, o.makerSubAccount, o.productId, makerPos);
        // calculate the fee to be charged to each isBuy then decrement the maker and taker realisedPnl
        Structs.Product memory product = IProductCatalogue(
            Commons.productCatalogue(address(addressManifest))
        ).products(o.productId);
        int256 takerFee;
        int256 makerFee;
        if (!o.isAdl) {
            uint256 notional = BasicMath.mul(o.baseQuantity, o.executionPrice);
            takerFee = int256(BasicMath.mul(notional, product.takerFee));
            makerFee = int256(BasicMath.mul(notional, product.makerFee));
            if (o.isFirstTime) {
                takerFee += int256(txFees[MATCH_ORDER_TX_FEE_INDEX]);
            }
            if (product.isMakerRebate) {
                makerFee = -makerFee;
            }
        }
        // update base asset balance with realised realisedPnl including funding
        ciao.settleCoreCollateral(o.takerSubAccount, takerRealisedPnl - takerFee);
        ciao.settleCoreCollateral(o.makerSubAccount, makerRealisedPnl - makerFee);
        // we know this potential subtraction is safe as it is enforced that the
        // makerFee cannot be larger than the takerFee size when the products get created
        ciao.incrementFee(product.quoteAsset, uint256(takerFee + makerFee), ciao.feeRecipient());
    }

    function _checkOrder(Structs.Order memory order) internal pure returns (bool) {
        return order.quantity > 0 && order.price > 0;
    }

    function _getOrderDetails(Structs.SingleMatchedOrder memory order)
        internal
        view
        returns (address, address, Structs.Product memory)
    {
        // get the sub accounts for the accounts
        address takerSubAccount =
            Commons.getSubAccount(order.taker.account, order.taker.subAccountId);
        address makerSubAccount =
            Commons.getSubAccount(order.maker.account, order.maker.subAccountId);
        if (order.maker.productId != order.taker.productId) {
            revert Errors.ProductIdMismatch();
        }
        // we need to get the class of the instrument
        Structs.Product memory product = IProductCatalogue(
            Commons.productCatalogue(address(addressManifest))
        ).products(order.maker.productId);
        if (product.productType == 0) revert Errors.ProductNotSet();
        return (takerSubAccount, makerSubAccount, product);
    }
}
