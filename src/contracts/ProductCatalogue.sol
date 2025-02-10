pragma solidity >=0.8.19;

import "./interfaces/Events.sol";
import "./interfaces/Errors.sol";
import "./interfaces/Structs.sol";

import "./libraries/AccessControl.sol";

//     ____                 __           __  ______      __        __
//    / __ \_________  ____/ /_  _______/ /_/ ____/___ _/ /_____ _/ /___  ____ ___  _____
//   / /_/ / ___/ __ \/ __  / / / / ___/ __/ /   / __ `/ __/ __ `/ / __ \/ __ `/ / / / _ \
//  / ____/ /  / /_/ / /_/ / /_/ / /__/ /_/ /___/ /_/ / /_/ /_/ / / /_/ / /_/ / /_/ /  __/
// /_/   /_/   \____/\__,_/\__,_/\___/\__/\____/\__,_/\__/\__,_/_/\____/\__, /\__,_/\___/
//                                                                     /____/
///////////////////////////////////////////////////////////////////////////////////////////

/// @notice Contract for ground truth of protocol product offerings.
///         Mk 0.0.0
contract ProductCatalogue is AccessControl {
    // Governance Variables
    //////////////////////////////////////

    mapping(uint32 => Structs.Product) public products;

    // mapping of a given base asset and quote asset to a spot product id
    mapping(address => mapping(address => uint32)) public baseAssetQuoteAssetSpotIds;

    constructor(address _addressManifest) {
        __AccessControl_init(_addressManifest);
    }

    // External - Access Controlled
    //////////////////////////////////////

    /// @notice Set a product
    /// @param productId the id of the product to activate
    /// @param product the Product struct representing the details of the product
    function setProduct(uint32 productId, Structs.Product memory product) external {
        _isAdmin();
        if (productId == 0) revert Errors.ProductIdInvalid();
        if (product.baseAsset == address(0)) revert Errors.BaseAssetInvalid();
        if (product.quoteAsset == address(0)) revert Errors.QuoteAssetInvalid();
        if (products[productId].baseAsset != address(0)) revert Errors.ProductAlreadySet();
        if (product.isMakerRebate) {
            if (product.makerFee > product.takerFee) revert Errors.MakerRebateFeeInvalid();
        }
        products[productId] = product;
        emit Events.ProductSet(
            productId,
            product.productType,
            product.baseAsset,
            product.quoteAsset,
            product.takerFee,
            product.makerFee,
            product.isMakerRebate
        );
        if (product.productType == 1) {
        if (baseAssetQuoteAssetSpotIds[product.baseAsset][product.quoteAsset] != 0) revert Errors.SpotPairAlreadyExists();
            baseAssetQuoteAssetSpotIds[product.baseAsset][product.quoteAsset] = productId;
        }
        emit Events.BaseAssetQuoteAssetSpotIdSet(product.baseAsset, product.quoteAsset, productId);
    }

    /// @notice change the baseAsset of an existing product
    /// @dev used to allow updating of derivatives that do not have a native baseAsset contract address
    /// @param productId the id of the product to update
    /// @param baseAsset the new contract address of the base asset for the product
    function updateProductBaseAsset(uint32 productId, address baseAsset) external {
        _isAdmin();
        if (productId == 0) revert Errors.ProductIdInvalid();
        if (products[productId].productType == 1) revert Errors.ProductIdInvalid();
        if (baseAsset == address(0)) revert Errors.BaseAssetInvalid();
        if (products[productId].baseAsset == address(0)) revert Errors.ProductNotSet();
        products[productId].baseAsset = baseAsset;
        emit Events.ProductBaseAssetChanged(productId, baseAsset);
    }

    /// @notice Change the tradeability of an existing product
    /// @param productId the id of the product to change the product tradeability for
    /// @param isProductTradeable boolean of whether the product is tradeable or not
    function changeProductTradeability(uint32 productId, bool isProductTradeable) external {
        _isAdmin();
        if (products[productId].baseAsset == address(0)) revert Errors.ProductNotSet();
        products[productId].isProductTradeable = isProductTradeable;
        emit Events.ProductTradeabilityChanged(productId, isProductTradeable);
    }

    /// @notice Change the tradeability of an existing product
    /// @param productId the id of the product to change the market fee for
    /// @param takerFee the taker fee to change to
    /// @param makerFee the maker fee to change to
    /// @param isMakerRebate is the maker fee instead meant to be charged as a rebate
    function changeProductFees(
        uint32 productId,
        uint128 takerFee,
        uint128 makerFee,
        bool isMakerRebate
    ) external {
        _isAdmin();
        if (products[productId].baseAsset == address(0)) revert Errors.ProductNotSet();
        if (isMakerRebate) {
            if (makerFee > takerFee) revert Errors.MakerRebateFeeInvalid();
        }
        products[productId].takerFee = takerFee;
        products[productId].makerFee = makerFee;
        products[productId].isMakerRebate = isMakerRebate;
        emit Events.ProductFeesChanged(productId, takerFee, makerFee, isMakerRebate);
    }

    // Basic Getters
    //////////////////////////////////////

    function productIdToBaseAsset(uint32 productId) external view returns (address) {
        return products[productId].baseAsset;
    }
}
