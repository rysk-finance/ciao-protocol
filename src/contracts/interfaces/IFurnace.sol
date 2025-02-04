// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.19;

import "./Structs.sol";

/// @notice Interface for the furnace
interface IFurnace {
    function getSubAccountHealth(address subAccount, bool isInitial)
        external
        view
        returns (int256);
    function setPrices(bytes calldata priceData) external;

    function baseAssetQuotePerpIds(address spotAddress) external view returns (uint32);

    function prices(uint32 productId) external view returns (uint256);

    function getSpreadPenalty(address spotAddress)
        external
        view
        returns (Structs.SpreadPenalties memory);

    function getSpotRiskWeights(address spotAddress)
        external
        view
        returns (Structs.ProductRiskWeights memory);

    function getProductRiskWeights(uint32 productId)
        external
        view
        returns (Structs.ProductRiskWeights memory);
}
