// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ProductCatalogue} from "src/contracts/ProductCatalogue.sol";
import {Furnace} from "src/contracts/Furnace.sol";
import {Commons} from "src/contracts/libraries/Commons.sol";
import {Events} from "src/contracts/interfaces/Events.sol";
import {Errors} from "src/contracts/interfaces/Errors.sol";
import {IProductCatalogue} from "src/contracts/interfaces/IProductCatalogue.sol";
import {Base_Test} from "../../Base.t.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";

contract ProductCatalogueBaseTest is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        deployCiao();
    }

    function test_Happy_SetProduct() public {
        vm.expectEmit(address(productCatalogue));
        emit Events.ProductSet(
            defaults.usdcProductId(),
            defaults.usdcProduct().productType,
            defaults.usdcProduct().baseAsset,
            defaults.usdcProduct().quoteAsset,
            defaults.usdcProduct().takerFee,
            defaults.usdcProduct().makerFee,
            defaults.usdcProduct().isMakerRebate
        );
        productCatalogue.setProduct(defaults.usdcProductId(), defaults.usdcProduct());

        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .productType,
            defaults.usdcProduct().productType
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .baseAsset,
            defaults.usdcProduct().baseAsset
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .quoteAsset,
            defaults.usdcProduct().quoteAsset
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .isProductTradeable,
            true
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId()).makerFee,
            defaults.usdcProduct().makerFee
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId()).takerFee,
            defaults.usdcProduct().takerFee
        );

        assertTrue(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .productType == 1
        );
        assertFalse(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .productType == 0
        );
    }

    function test_Happy_SetProduct_MakerRebate() public {
        vm.expectEmit(address(productCatalogue));
        emit Events.ProductSet(
            defaults.usdcProductId(),
            defaults.usdcProduct().productType,
            defaults.usdcProduct().baseAsset,
            defaults.usdcProduct().quoteAsset,
            defaults.usdcProduct().takerFee,
            defaults.usdcProduct().makerFee,
            true
        );
        productCatalogue.setProduct(
            defaults.usdcProductId(),
            Structs.Product(
                defaults.usdcProduct().productType,
                defaults.usdcProduct().baseAsset,
                defaults.usdcProduct().quoteAsset,
                true,
                defaults.usdcProduct().takerFee,
                defaults.usdcProduct().makerFee,
                true
            )
        );

        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .productType,
            defaults.usdcProduct().productType
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .baseAsset,
            defaults.usdcProduct().baseAsset
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .quoteAsset,
            defaults.usdcProduct().quoteAsset
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .isProductTradeable,
            true
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId()).makerFee,
            defaults.usdcProduct().makerFee
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId()).takerFee,
            defaults.usdcProduct().takerFee
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .isMakerRebate,
            true
        );
        assertTrue(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .productType == 1
        );
        assertFalse(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .productType == 0
        );
    }

    function test_Fail_SetProductSame() public {
        uint32 usdcProductId = defaults.usdcProductId();
        Structs.Product memory product = defaults.usdcProduct();
        vm.expectEmit(address(productCatalogue));
        emit Events.ProductSet(
            defaults.usdcProductId(),
            defaults.usdcProduct().productType,
            defaults.usdcProduct().baseAsset,
            defaults.usdcProduct().quoteAsset,
            defaults.usdcProduct().takerFee,
            defaults.usdcProduct().makerFee,
            defaults.usdcProduct().isMakerRebate
        );
        productCatalogue.setProduct(defaults.usdcProductId(), defaults.usdcProduct());
        vm.expectRevert(bytes4(keccak256("ProductAlreadySet()")));
        productCatalogue.setProduct(usdcProductId, product);
    }

    function test_Fail_SetProduct_spot_pair_already_exists() public {
        uint32 usdcProductId = defaults.usdcProductId();
        Structs.Product memory product = defaults.usdcProduct();
        vm.expectEmit(address(productCatalogue));
        emit Events.ProductSet(
            12345,
            defaults.usdcProduct().productType,
            defaults.usdcProduct().baseAsset,
            defaults.usdcProduct().quoteAsset,
            defaults.usdcProduct().takerFee,
            defaults.usdcProduct().makerFee,
            defaults.usdcProduct().isMakerRebate
        );
        productCatalogue.setProduct(12345, defaults.usdcProduct());
        vm.expectRevert(bytes4(keccak256("SpotPairAlreadyExists()")));
        productCatalogue.setProduct(usdcProductId, product);
    }

    function test_Fail_SetProduct_BaseAsset_ZERO() public {
        vm.expectRevert(bytes4(keccak256("BaseAssetInvalid()")));
        productCatalogue.setProduct(
            1, Structs.Product(1, address(0), address(0), true, 1, 1, false)
        );
    }

    function test_Fail_SetProduct_id_zero() public {
        vm.expectRevert(bytes4(keccak256("ProductIdInvalid()")));
        productCatalogue.setProduct(
            0, Structs.Product(1, address(0), address(0), true, 1, 1, false)
        );
    }

    function test_Fail_SetProduct_MakerRebate_Too_Big() public {
        vm.expectRevert(bytes4(keccak256("MakerRebateFeeInvalid()")));
        productCatalogue.setProduct(
            1, Structs.Product(1, address(usdc), address(usdc), true, 1e8, 2e8, true)
        );
    }

    function test_Fail_SetProduct_QuoteAsset_ZERO() public {
        vm.expectRevert(bytes4(keccak256("QuoteAssetInvalid()")));
        productCatalogue.setProduct(
            1, Structs.Product(1, address(usdc), address(0), true, 1, 1, false)
        );
    }
     
    function test_Fail_SetProduct_QuoteAsset_Not_CoreCollateral() public {
        vm.expectRevert(bytes4(keccak256("QuoteAssetInvalid()")));
        productCatalogue.setProduct(
            1, Structs.Product(1, address(usdc), address(weth), true, 1, 1, false)
        );
    }

    function test_Fail_SetProduct_NotOwner() public {
        noop();
        vm.startPrank({msgSender: users.hackerman});
        Structs.Product memory product = defaults.usdcProduct();
        vm.expectRevert("UNAUTHORIZED");
        productCatalogue.setProduct(1, product);
    }

    function test_Happy_ChangeProductTradeability() public {
        validateAssets();
        vm.expectEmit(address(productCatalogue));
        emit Events.ProductTradeabilityChanged(defaults.usdcProductId(), false);
        productCatalogue.changeProductTradeability(defaults.usdcProductId(), false);

        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .productType,
            defaults.usdcProduct().productType
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .baseAsset,
            defaults.usdcProduct().baseAsset
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .quoteAsset,
            defaults.usdcProduct().quoteAsset
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .isProductTradeable,
            false
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId()).makerFee,
            defaults.usdcProduct().makerFee
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId()).takerFee,
            defaults.usdcProduct().takerFee
        );
        assertTrue(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .productType == 1
        );
        assertFalse(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .productType == 0
        );
    }

    function test_Fail_ChangeProductTradeability_Bad_Product() public {
        vm.expectRevert(bytes4(keccak256("ProductNotSet()")));
        productCatalogue.changeProductTradeability(100, true);
    }

    function test_Fail_ChangeProductTradeability_NotOwner() public {
        noop();
        vm.startPrank({msgSender: users.hackerman});
        vm.expectRevert("UNAUTHORIZED");
        productCatalogue.changeProductTradeability(1, true);
    }

    function test_Happy_ChangeFees() public {
        validateAssets();
        vm.expectEmit(address(productCatalogue));
        emit Events.ProductFeesChanged(defaults.usdcProductId(), 5e17, 3e17, false);
        productCatalogue.changeProductFees(defaults.usdcProductId(), 5e17, 3e17, false);

        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .productType,
            defaults.usdcProduct().productType
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .baseAsset,
            defaults.usdcProduct().baseAsset
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .quoteAsset,
            defaults.usdcProduct().quoteAsset
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .isProductTradeable,
            true
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId()).makerFee,
            3e17
        );
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId()).takerFee,
            5e17
        );
        assertFalse(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .isMakerRebate
        );
        assertTrue(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .productType == 1
        );
        assertFalse(
            IProductCatalogue(address(productCatalogue)).products(defaults.usdcProductId())
                .productType == 0
        );
    }

    function test_Fail_ChangeProductFees_Bad_Product() public {
        vm.expectRevert(bytes4(keccak256("ProductNotSet()")));
        productCatalogue.changeProductFees(100, 1e7, 2e8, false);
    }

    function test_Fail_ChangeProductFees_Maker_Rebate_Too_Big() public {
        validateAssets();
        vm.expectRevert(bytes4(keccak256("MakerRebateFeeInvalid()")));
        productCatalogue.changeProductFees(102, 1e8, 2e8, true);
    }

    function test_Fail_ChangeProductFee_NotOwner() public {
        noop();
        vm.startPrank({msgSender: users.hackerman});
        vm.expectRevert("UNAUTHORIZED");
        productCatalogue.changeProductFees(1, 1, 1, false);
    }

    function test_Happy_Set_Product_Base_Asset() public {
        validateAssets();
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.wethUsdcPerpProductId())
                .baseAsset,
            address(weth)
        );
        vm.expectEmit(address(productCatalogue));
        emit Events.ProductBaseAssetChanged(defaults.wethUsdcPerpProductId(), address(wbtc));
        productCatalogue.updateProductBaseAsset(defaults.wethUsdcPerpProductId(), address(wbtc));
        assertEq(
            IProductCatalogue(address(productCatalogue)).products(defaults.wethUsdcPerpProductId())
                .baseAsset,
            address(wbtc)
        );
    }

    function test_Fail_Set_Product_Base_Asset_unauth() public {
        validateAssets();
        uint32 id = defaults.wethUsdcPerpProductId();
        vm.startPrank({msgSender: users.hackerman});
        vm.expectRevert("UNAUTHORIZED");
        productCatalogue.updateProductBaseAsset(id, address(weth));
    }

    function test_Fail_Set_Product_Base_Asset_product_not_set() public {
        validateAssets();
        vm.expectRevert(bytes4(keccak256("ProductNotSet()")));
        productCatalogue.updateProductBaseAsset(23346312, address(weth));
    }

    function test_Fail_Set_Product_Base_Asset_zero_addr() public {
        validateAssets();
        uint32 id = defaults.wethUsdcPerpProductId();
        vm.expectRevert(bytes4(keccak256("BaseAssetInvalid()")));
        productCatalogue.updateProductBaseAsset(id, address(0));
    }

    function test_Fail_Set_Product_Base_Asset_invalid_id() public {
        validateAssets();
        uint32 id = 0;
        vm.expectRevert(bytes4(keccak256("ProductIdInvalid()")));
        productCatalogue.updateProductBaseAsset(id, address(weth));
    }

    function test_Fail_Set_Product_Base_Asset_spot_id() public {
        validateAssets();
        vm.expectRevert(bytes4(keccak256("ProductIdInvalid()")));
        productCatalogue.updateProductBaseAsset(1, address(weth));
    }
}
