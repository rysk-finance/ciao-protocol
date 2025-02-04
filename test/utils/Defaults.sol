// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import "src/contracts/libraries/Commons.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";
import {IProductCatalogue} from "src/contracts/interfaces/IProductCatalogue.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";
import "src/contracts/libraries/Commons.sol";
import {OrderDispatch} from "src/contracts/OrderDispatch.sol";
import {Furnace} from "src/contracts/Furnace.sol";

/// @notice Contract containing some default values used for testing
contract Defaults {
    ERC20 private usdc;
    ERC20 private weth;
    ERC20 private wbtc;

    // constants
    uint256 public genesis = 1682899200; // May 1 2023

    function setAssets(ERC20 _usdc, ERC20 _weth, ERC20 _wbtc) public {
        usdc = _usdc;
        weth = _weth;
        wbtc = _wbtc;
        usdcDepositQuantity = Commons.convertFromE18(
            usdcDepositQuantityE18,
            usdc.decimals()
        );
    }

    function setWethDepositQuantity(uint256 quantity) external {
        wethDepositQuantity = quantity;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      product catalogue
    //////////////////////////////////////////////////////////////////////////*/

    uint32 public usdcProductId = 1;
    uint32 public wethProductId = 2;
    uint32 public wbtcProductId = 3;

    uint32 public wethUsdcPerpProductId = 102;
    uint32 public wbtcUsdcPerpProductId = 103;

    function usdcProduct() external view returns (Structs.Product memory) {
        return
            Structs.Product(
                1,
                address(usdc),
                address(usdc),
                true,
                5e16,
                3e16,
                false
            );
    }

    function wethProduct() external view returns (Structs.Product memory) {
        return
            Structs.Product(
                1,
                address(weth),
                address(usdc),
                true,
                5e16,
                3e16,
                false
            );
    }

    function wbtcProduct() external view returns (Structs.Product memory) {
        return
            Structs.Product(
                1,
                address(wbtc),
                address(usdc),
                true,
                5e16,
                3e16,
                false
            );
    }

    function wethUsdcPerpProduct()
        external
        view
        returns (Structs.Product memory)
    {
        return
            Structs.Product(
                2,
                address(weth),
                address(usdc),
                true,
                5e14, // 5 bps
                3e14, // 3 bps
                true
            );
    }

    function wbtcUsdcPerpProduct()
        external
        view
        returns (Structs.Product memory)
    {
        return
            Structs.Product(
                2,
                address(wbtc),
                address(usdc),
                true,
                5e14, // 5 bps
                3e14, // 3 bps
                true
            );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                        Furnace
    //////////////////////////////////////////////////////////////////////////*/

    function usdcRiskWeights()
        external
        pure
        returns (Structs.ProductRiskWeights memory)
    {
        return
            Structs.ProductRiskWeights(
                1000000000000000000,
                1000000000000000000,
                1000000000000000000,
                1000000000000000000
            );
    }

    function wethRiskWeights()
        external
        pure
        returns (Structs.ProductRiskWeights memory)
    {
        return
            Structs.ProductRiskWeights(
                800000000000000000, // initialLongweight 0.8
                1200000000000000000, // initialShortWeight 1.2
                900000000000000000, // maintenanceLongWeight 0.9
                1100000000000000000 // maintenanceShortWeight 1.1
            );
    }

    function wbtcRiskWeights()
        external
        pure
        returns (Structs.ProductRiskWeights memory)
    {
        return
            Structs.ProductRiskWeights(
                800000000000000000, // initialLongweight 0.8
                1200000000000000000, // initialShortWeight 1.2
                900000000000000000, // maintenanceLongWeight 0.9
                1100000000000000000 // maintenanceShortWeight 1.1
            );
    }

    function wethUsdcPerpRiskWeights()
        external
        pure
        returns (Structs.ProductRiskWeights memory)
    {
        return
            Structs.ProductRiskWeights(
                900000000000000000, // initialLongweight 0.9
                1100000000000000000, // initialShortWeight 1.1
                950000000000000000, // maintenanceLongWeight 0.95
                1050000000000000000 // maintenanceShortWeight 1.05
            );
    }

    function wbtcUsdcPerpRiskWeights()
        external
        pure
        returns (Structs.ProductRiskWeights memory)
    {
        return
            Structs.ProductRiskWeights(
                900000000000000000, // initialLongweight 0.9
                1100000000000000000, // initialShortWeight 1.1
                950000000000000000, // maintenanceLongWeight 0.95
                1050000000000000000 // maintenanceShortWeight 1.05
            );
    }

    function wbtcSpreadPenalty()
        external
        pure
        returns (Structs.SpreadPenalties memory)
    {
        return
            Structs.SpreadPenalties(
                20000000000000000, // 0.02 initial
                10000000000000000 // 0.01 maintenance
            );
    }

    function wethSpreadPenalty()
        external
        pure
        returns (Structs.SpreadPenalties memory)
    {
        return
            Structs.SpreadPenalties(
                30000000000000000, // 0.03 initial
                15000000000000000 // 0.015 maintenance
            );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      Ciao
    //////////////////////////////////////////////////////////////////////////*/

    uint256 public usdcDepositQuantity = 100_000e6;
    uint256 public usdcDepositQuantityE18 = 100_000e18;
    uint256 public wethDepositQuantity = 100e18;

    /*//////////////////////////////////////////////////////////////////////////
                                Perp Margin Directive
    //////////////////////////////////////////////////////////////////////////*/

    function assetRiskWeights()
        external
        pure
        returns (Structs.ProductRiskWeights memory)
    {
        return
            Structs.ProductRiskWeights(
                950000000000000000, // initialLongweight 0.95
                1050000000000000000, // initialShortWeight 1.05
                970000000000000000, // maintenanceLongWeight 0.97
                1030000000000000000 // maintenanceShortWeight 1.03
            );
    }

    struct PerpMaintenanceMarginDirectivePositionTemplate {
        uint256 quantity;
        uint256 avgEntryPrice;
        bool isLong;
        uint256 markPrice;
        int256 initCumFunding;
        int256 currentCumFunding;
    }

    struct PerpInitialMarginDirectivePositionTemplate {
        uint256 quantity;
        uint256 avgEntryPrice;
        bool isLong;
        uint256 markPrice; // likely very similar to avgEntryPrice
    }

    function profitableLong()
        external
        pure
        returns (PerpMaintenanceMarginDirectivePositionTemplate memory)
    {
        return
            PerpMaintenanceMarginDirectivePositionTemplate(
                34e18,
                1632620000000000000000, // $1632.62
                true,
                1707290000000000000000, // $1707.29
                52236050000000000000, // $52.23605 per contract
                52240110000000000000 // $52.24011 per contract
            );
    }

    function unprofitableLong()
        external
        pure
        returns (PerpMaintenanceMarginDirectivePositionTemplate memory)
    {
        return
            PerpMaintenanceMarginDirectivePositionTemplate(
                10492e16,
                1632620000000000000000, // $1632.62
                true,
                1598300000000000000000, // $1598.30
                -520600000000000000, // -$0.52060 per contract
                -518790000000000000 // -$0.51879 per contract
            );
    }

    function profitableShort()
        external
        pure
        returns (PerpMaintenanceMarginDirectivePositionTemplate memory)
    {
        return
            PerpMaintenanceMarginDirectivePositionTemplate(
                73e16,
                1932620000000000000000, // $1932.62
                false,
                1598300000000000000000, // $1598.30
                -520600000000000000, // -$0.52060 per contract
                -544410000000000000 // -$0.54441 per contract
            );
    }

    function unprofitableShort()
        external
        pure
        returns (PerpMaintenanceMarginDirectivePositionTemplate memory)
    {
        return
            PerpMaintenanceMarginDirectivePositionTemplate(
                10492e16,
                1932620000000000000000, // $1932.62
                false,
                1933040000000000000000, // $1933.04
                3520600000000000000, // 3.52060 per contract
                3494410000000000000 // 3.49441 per contract
            );
    }

    function initialLong()
        external
        pure
        returns (PerpInitialMarginDirectivePositionTemplate memory)
    {
        return
            PerpInitialMarginDirectivePositionTemplate(
                87162e16,
                3221990000000000000000, // $3221.99
                true,
                3222030000000000000000 // $3222.03
            );
    }

    function initialShort()
        external
        pure
        returns (PerpInitialMarginDirectivePositionTemplate memory)
    {
        return
            PerpInitialMarginDirectivePositionTemplate(
                87162e16,
                3221990000000000000000, // $3221.99
                false,
                3221240000000000000000 // $3221.24
            );
    }
}
