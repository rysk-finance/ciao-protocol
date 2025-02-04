// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "src/contracts/Liquidation.sol";
import "src/contracts/libraries/MarginDirective.sol";

contract MockLiquidation is Liquidation {
    constructor(address _a) Liquidation(_a) {}

    // Internal
    //////////////////////////////////////

    function getLiquidationPrice(
        uint32 productId,
        uint256 oraclePrice,
        bool isLong
    ) external view returns (uint256 liquidationPrice) {
        return _getLiquidationPrice(productId, oraclePrice, isLong);
    }

    function getSpreadLiquidationPrice(
        address spotComponentAddress,
        uint256 oraclePrice,
        bool isSpot
    ) external view returns (uint256 liquidationPrice) {
        return
            _getSpreadLiquidationPrice(
                spotComponentAddress,
                oraclePrice,
                isSpot
            );
    }
}
