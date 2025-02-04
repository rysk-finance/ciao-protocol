// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.19;

import {MarginDirective} from "../../src/contracts/libraries/MarginDirective.sol";
import {Furnace} from "../../src/contracts/Furnace.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";

contract MockMarginDirective {
    function getPerpMarginHealth(
        bool isInitial,
        Structs.ProductRiskWeights calldata productRiskWeights,
        uint256 quantity,
        uint256 avgEntryPrice,
        bool isLong,
        uint256 markPrice,
        int256 initCumFunding,
        int256 currentCumFunding
    ) external pure returns (int256 health) {
        return MarginDirective.getPerpMarginHealth(
            isInitial,
            productRiskWeights,
            quantity,
            avgEntryPrice,
            isLong,
            markPrice,
            initCumFunding,
            currentCumFunding
        );
    }
}
