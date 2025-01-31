// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.19;

import "./Structs.sol";

/// @notice Interface for the product catalogue
interface IProductCatalogue {
    function products(uint32 productId) external view returns (Structs.Product memory);

    function setProduct(uint32 productId, Structs.Product memory product) external;

    function productIdToBaseAsset(uint32 productId) external view returns (address);

    function baseAssetQuoteAssetSpotIds(address baseAsset, address quoteAsset)
        external
        view
        returns (uint32);
}
