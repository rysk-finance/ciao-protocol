// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

//     ______
//    / ____/_  ___________  ____ _________
//   / /_  / / / / ___/ __ \/ __ `/ ___/ _ \
//  / __/ / /_/ / /  / / / / /_/ / /__/  __/
// /_/    \__,_/_/  /_/ /_/\__,_/\___/\___/
/////////////////////////////////////////////

/// @notice Contract for consolidation all margin checking and position adding logic
contract MockFurnace {
    mapping(address => bool) public hasActivePosition;

    mapping(uint32 => ProductRiskWeights) public productRiskWeights;

    mapping(address => ProductRiskWeights) public spotRiskWeights;

    struct ProductRiskWeights {
        uint64 initialLongWeight;
        uint64 initialShortWeight;
        uint64 maintenanceLongWeight;
        uint64 maintenanceShortWeight;
    }

    function setHasActivePosition(
        address subAccount,
        bool _hasActivePosition
    ) external {
        hasActivePosition[subAccount] = _hasActivePosition;
    }

    function doesSubAccountHaveActivePositions(
        address subAccount
    ) external view returns (bool) {
        return hasActivePosition[subAccount];
    }

    function setProductRiskWeight(
        uint32 productId,
        ProductRiskWeights calldata newProductRiskWeights
    ) external {
        // TODO: add access control
        productRiskWeights[productId] = newProductRiskWeights;
    }
}
