// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {Test, console2} from "forge-std/Test.sol";
import {OrderDispatch} from "src/contracts/OrderDispatch.sol";
import {Liquidation} from "src/contracts/Liquidation.sol";
import {AddressManifest} from "src/contracts/AddressManifest.sol";
import {MockMarginDirective} from "test/mocks/MockMarginDirective.sol";
import {MockFurnaceUnitTest} from "test/mocks/MockFurnaceUnitTest.sol";
import {SpotCrucible} from "src/contracts/crucible/spot-crucible/SpotCrucible.sol";
import {PerpCrucible} from "src/contracts/crucible/perp-crucible/PerpCrucible.sol";
import {ProductCatalogue} from "src/contracts/ProductCatalogue.sol";
import {Commons} from "src/contracts/libraries/Commons.sol";
import {Ciao} from "src/contracts/Ciao.sol";
import {Furnace} from "src/contracts/Furnace.sol";
import {MockFurnace} from "./mocks/MockFurnace.sol";
import {MockLiquidation} from "./mocks/MockLiquidation.sol";
import {Events} from "src/contracts/interfaces/Events.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";
import {IProductCatalogue} from "src/contracts/interfaces/IProductCatalogue.sol";
import {Types} from "./utils/Types.sol";
import {Defaults} from "./utils/Defaults.sol";
import "src/contracts/libraries/BasicMath.sol";
import "forge-std/console.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Test is Events, Types, Test {
    using BasicMath for int256;
    using BasicMath for uint256;
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;
    int256 public u1a1;
    uint256 public u1a2;
    int256 public u2a1;
    uint256 public u2a2;
    uint256 public fa1;
    uint256 public fa2;
    int256 bcu1;
    int256 bcu2;
    uint256 bcf;
    Structs.PositionState public takeru1pid;
    Structs.PositionState public makeru2pid;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ERC20 internal usdc;
    ERC20 internal weth;
    ERC20 internal wbtc;
    OrderDispatch internal orderDispatch;
    OrderDispatch internal orderDispatchImpl;
    Liquidation internal liquidation;
    MockLiquidation internal mockLiquidation;
    AddressManifest internal addressManifest;
    ProductCatalogue internal productCatalogue;
    Ciao internal ciao;
    Ciao internal ciaoImpl;
    TransparentUpgradeableProxy internal ciaoProxy;
    ProxyAdmin internal ciaoProxyAdmin;
    Furnace internal furnace;
    Defaults internal defaults;
    MockMarginDirective internal marginDirective;
    MockFurnaceUnitTest internal mockFurnaceUnitTest;
    SpotCrucible internal spotCrucible;
    SpotCrucible internal spotCrucibleImpl;
    TransparentUpgradeableProxy internal spotCrucibleProxy;
    ProxyAdmin internal spotCrucibleProxyAdmin;
    PerpCrucible internal perpCrucible;
    PerpCrucible internal perpCrucibleImpl;
    TransparentUpgradeableProxy internal perpCrucibleProxy;
    ProxyAdmin internal perpCrucibleProxyAdmin;
    TransparentUpgradeableProxy internal proxy;
    ProxyAdmin internal proxyAdmin;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Deploy the base test contracts.
        usdc = ERC20(new MockERC20("USDC Stablecoin", "USDC", 6));
        weth = ERC20(new MockERC20("WETH", "WETH", 18));
        wbtc = ERC20(new MockERC20("WBTC", "WBTC", 8));

        // Label the base test contracts.
        vm.label({account: address(usdc), newLabel: "USDC"});
        vm.label({account: address(weth), newLabel: "WETH"});
        vm.label({account: address(wbtc), newLabel: "WBTC"});

        // Create users for testing.
        users = Users({
            gov: createUser("gov"),
            alice: createUser("alice"),
            dan: createUser("dan"),
            larry: createUser("larry"), // liquidatoooor
            hackerman: createUser("hackerman"),
            keeper: createUser("keeper"),
            operator: createUser("operator"),
            recipient: createUser("recipient"),
            insurance: createUser("insurance")
        });

        defaults = new Defaults();
        defaults.setAssets(usdc, weth, wbtc);
        // Warp to May 1, 2023 at 00:00 GMT to provide a more realistic testing environment.
        vm.warp(defaults.genesis());
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({account: user, newBalance: 100 ether});
        deal({token: address(usdc), to: user, give: 1_000_000 * 10 ** usdc.decimals()});
        deal({token: address(weth), to: user, give: 1_000_000e18});
        deal({token: address(wbtc), to: user, give: 1_000_000e8});
        return user;
    }

    function deployCiaoProxy() internal {
        ciaoImpl = new Ciao();
        ciaoProxy = new TransparentUpgradeableProxy(
            address(ciaoImpl),
            users.gov,
            abi.encodeCall(
                Ciao.initialize,
                (address(addressManifest), address(usdc), users.operator, users.insurance)
            )
        );
        ciaoProxyAdmin = ProxyAdmin(
            address(uint160(uint256(vm.load(address(ciaoProxy), ERC1967Utils.ADMIN_SLOT))))
        );
        ciao = Ciao(address(ciaoProxy));
    }

    function deploySpotCrucibleProxy() internal {
        spotCrucibleImpl = new SpotCrucible();
        spotCrucibleProxy = new TransparentUpgradeableProxy(
            address(spotCrucibleImpl),
            users.gov,
            abi.encodeCall(SpotCrucible.initialize, address(addressManifest))
        );
        spotCrucibleProxyAdmin = ProxyAdmin(
            address(uint160(uint256(vm.load(address(spotCrucibleProxy), ERC1967Utils.ADMIN_SLOT))))
        );
        spotCrucible = SpotCrucible(address(spotCrucibleProxy));
    }

    function deployPerpCrucibleProxy() internal {
        perpCrucibleImpl = new PerpCrucible();
        perpCrucibleProxy = new TransparentUpgradeableProxy(
            address(perpCrucibleImpl),
            users.gov,
            abi.encodeCall(PerpCrucible.initialize, (address(addressManifest)))
        );
        perpCrucibleProxyAdmin = ProxyAdmin(
            address(uint160(uint256(vm.load(address(perpCrucibleProxy), ERC1967Utils.ADMIN_SLOT))))
        );
        perpCrucible = PerpCrucible(address(perpCrucibleProxy));
    }

    function deployOrderDispatch() internal {
        vm.startPrank({msgSender: users.gov});
        addressManifest = new AddressManifest();
        addressManifest.setOperator(users.gov);
        addressManifest.setAdmin(users.gov);
        deployCiaoProxy();
        vm.stopPrank();
        deployFurnace();
        productCatalogue = new ProductCatalogue(address(addressManifest));
        orderDispatchImpl = new OrderDispatch();
        orderDispatchImpl.initialize(address(addressManifest));
        proxy = new TransparentUpgradeableProxy(
            address(orderDispatchImpl),
            users.gov,
            abi.encodeCall(OrderDispatch.initialize, (address(addressManifest)))
        );
        proxyAdmin =
            ProxyAdmin(address(uint160(uint256(vm.load(address(proxy), ERC1967Utils.ADMIN_SLOT)))));

        orderDispatch = OrderDispatch(address(proxy));
        deploySpotCrucibleProxy();
        deployPerpCrucibleProxy();
        deployLiquidation();
        addressManifest.updateAddressInManifest(1, address(ciao));
        addressManifest.updateAddressInManifest(2, address(furnace));
        addressManifest.updateAddressInManifest(3, address(productCatalogue));
        addressManifest.updateAddressInManifest(4, address(orderDispatch));
        addressManifest.updateAddressInManifest(5, address(liquidation));
        addressManifest.updateAddressInManifest(6, address(spotCrucible));
        addressManifest.updateAddressInManifest(7, address(perpCrucible));
        vm.label({account: address(ciao), newLabel: "Ciao"});
        vm.label({account: address(furnace), newLabel: "MockFurnace"});
        vm.label({account: address(productCatalogue), newLabel: "ProductCatalogue"});
        vm.label({account: address(orderDispatch), newLabel: "OrderDispatch"});
        vm.label({account: address(spotCrucible), newLabel: "spotCrucible"});
        vm.label({account: address(perpCrucible), newLabel: "perpCrucible"});
        depositAssetsToCiaoAndSwitchGov();
        orderDispatch.setTxFees(0, 1e18);
    }

    function setAlicePositions(
        int256 wbtcCumFunding,
        int256 wethCumFunding,
        Structs.NewPosition memory ethPerpPos,
        Structs.NewPosition memory btcPerpPos,
        uint256 usdcSpotQuantity,
        uint256 wethSpotQuantity,
        uint256 wbtcSpotQuantity,
        uint256 wethSpotPrice,
        uint256 wbtcSpotPrice,
        uint256 wethUsdcPerpPrice,
        uint256 wbtcUsdcPerpPrice
    ) internal {
        vm.startPrank({msgSender: users.gov});
        // set funding snapshots
        bytes memory payload = abi.encodePacked(
            defaults.wbtcUsdcPerpProductId(),
            wbtcCumFunding,
            defaults.wethUsdcPerpProductId(),
            wethCumFunding
        );
        perpCrucible.updateCumulativeFundings(payload);

        // set positions
        if (ethPerpPos.quantity > 0) {
            perpCrucible.updatePosition(
                address(0),
                Commons.getSubAccount(users.alice, 1),
                defaults.wethUsdcPerpProductId(),
                ethPerpPos
            );
        }
        if (btcPerpPos.quantity > 0) {
            perpCrucible.updatePosition(
                address(0),
                Commons.getSubAccount(users.alice, 1),
                defaults.wbtcUsdcPerpProductId(),
                btcPerpPos
            );
        }
        vm.stopPrank();
        if (usdcSpotQuantity > 0) {
            deal(address(usdc), users.alice, usdcSpotQuantity);
            vm.startPrank(users.alice);
            usdc.approve(address(ciao), usdcSpotQuantity);
            ciao.deposit(users.alice, 1, usdcSpotQuantity, address(usdc));
            vm.stopPrank();
        }
        if (wethSpotQuantity > 0) {
            deal(address(weth), users.alice, wethSpotQuantity);
            vm.startPrank(users.alice);
            weth.approve(address(ciao), wethSpotQuantity);
            ciao.deposit(users.alice, 1, wethSpotQuantity, address(weth));
            vm.stopPrank();
        }
        if (wbtcSpotQuantity > 0) {
            deal(address(wbtc), users.alice, wbtcSpotQuantity);
            vm.startPrank(users.alice);
            wbtc.approve(address(ciao), wbtcSpotQuantity);
            ciao.deposit(users.alice, 1, wbtcSpotQuantity, address(wbtc));
            vm.stopPrank();
        }
        vm.startPrank({msgSender: users.gov});

        uint32[] memory setPricesProductIds = new uint32[](4);
        setPricesProductIds[0] = defaults.wbtcProductId();
        setPricesProductIds[1] = defaults.wethProductId();
        setPricesProductIds[2] = defaults.wbtcUsdcPerpProductId();
        setPricesProductIds[3] = defaults.wethUsdcPerpProductId();

        uint256[] memory setPricesValues = new uint256[](4);
        setPricesValues[0] = wbtcSpotPrice;
        setPricesValues[1] = wethSpotPrice;
        setPricesValues[2] = wbtcUsdcPerpPrice;
        setPricesValues[3] = wethUsdcPerpPrice;
        bytes memory pricePayload = abi.encodePacked(
            setPricesProductIds[0],
            setPricesValues[0],
            setPricesProductIds[1],
            setPricesValues[1],
            setPricesProductIds[2],
            setPricesValues[2],
            setPricesProductIds[3],
            setPricesValues[3]
        );
        furnace.setPrices(pricePayload);
    }

    function setUserPositions(
        address _user,
        int256 wbtcCumFunding,
        int256 wethCumFunding,
        Structs.NewPosition memory ethPerpPos,
        Structs.NewPosition memory btcPerpPos,
        uint256 usdcSpotQuantity,
        uint256 wethSpotQuantity,
        uint256 wbtcSpotQuantity,
        uint256 wethSpotPrice,
        uint256 wbtcSpotPrice,
        uint256 wethUsdcPerpPrice,
        uint256 wbtcUsdcPerpPrice
    ) internal {
        vm.startPrank({msgSender: users.gov});
        // set funding snapshots
        perpCrucible.updateCumulativeFundings(
            abi.encodePacked(
                defaults.wbtcUsdcPerpProductId(),
                wbtcCumFunding,
                defaults.wethUsdcPerpProductId(),
                wethCumFunding
            )
        );

        // set positions
        if (ethPerpPos.quantity > 0) {
            perpCrucible.updatePosition(
                address(0),
                Commons.getSubAccount(_user, 1),
                defaults.wethUsdcPerpProductId(),
                ethPerpPos
            );
        }
        if (btcPerpPos.quantity > 0) {
            perpCrucible.updatePosition(
                address(0),
                Commons.getSubAccount(_user, 1),
                defaults.wbtcUsdcPerpProductId(),
                btcPerpPos
            );
        }
        vm.stopPrank();
        if (usdcSpotQuantity > 0) {
            deal(address(usdc), _user, usdcSpotQuantity);
            vm.startPrank(_user);
            usdc.approve(address(ciao), usdcSpotQuantity);
            ciao.deposit(_user, 1, usdcSpotQuantity, address(usdc));
            vm.stopPrank();
        }
        if (wethSpotQuantity > 0) {
            deal(address(weth), _user, wethSpotQuantity);
            vm.startPrank(_user);
            weth.approve(address(ciao), wethSpotQuantity);
            ciao.deposit(_user, 1, wethSpotQuantity, address(weth));
            vm.stopPrank();
        }
        if (wbtcSpotQuantity > 0) {
            deal(address(wbtc), _user, wbtcSpotQuantity);
            vm.startPrank(_user);
            wbtc.approve(address(ciao), wbtcSpotQuantity);
            ciao.deposit(_user, 1, wbtcSpotQuantity, address(wbtc));
            vm.stopPrank();
        }
        vm.startPrank({msgSender: users.gov});

        uint32[] memory setPricesProductIds = new uint32[](4);
        setPricesProductIds[0] = defaults.wbtcProductId();
        setPricesProductIds[1] = defaults.wethProductId();
        setPricesProductIds[2] = defaults.wbtcUsdcPerpProductId();
        setPricesProductIds[3] = defaults.wethUsdcPerpProductId();

        uint256[] memory setPricesValues = new uint256[](4);
        setPricesValues[0] = wbtcSpotPrice;
        setPricesValues[1] = wethSpotPrice;
        setPricesValues[2] = wbtcUsdcPerpPrice;
        setPricesValues[3] = wethUsdcPerpPrice;
        bytes memory pricePayload = abi.encodePacked(
            setPricesProductIds[0],
            setPricesValues[0],
            setPricesProductIds[1],
            setPricesValues[1],
            setPricesProductIds[2],
            setPricesValues[2],
            setPricesProductIds[3],
            setPricesValues[3]
        );
        furnace.setPrices(pricePayload);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CIAO SHARED
    //////////////////////////////////////////////////////////////////////////*/

    function deployCiao() internal {
        vm.startPrank({msgSender: users.gov});
        addressManifest = new AddressManifest();
        addressManifest.setAdmin(users.gov);
        deployCiaoProxy();
        deployFurnace();
        productCatalogue = new ProductCatalogue(address(addressManifest));
        mockLiquidation = new MockLiquidation(address(addressManifest));
        deployLiquidation();
        deployPerpCrucibleProxy();
        addressManifest.updateAddressInManifest(1, address(ciao));
        addressManifest.updateAddressInManifest(2, address(furnace));
        addressManifest.updateAddressInManifest(3, address(productCatalogue));
        // set the gov as the order dispatch for testing
        addressManifest.updateAddressInManifest(4, users.gov);
        addressManifest.updateAddressInManifest(5, address(liquidation));
        addressManifest.updateAddressInManifest(7, address(perpCrucible));
        vm.label({account: address(addressManifest), newLabel: "AddressManifest"});
        vm.label({account: address(ciao), newLabel: "Ciao"});
        vm.label({account: address(furnace), newLabel: "Furnace"});
        vm.label({account: address(productCatalogue), newLabel: "ProductCatalogue"});
        vm.label({account: address(liquidation), newLabel: "Liquidation"});
        vm.label({account: address(perpCrucible), newLabel: "PerpCrucible"});
    }

    function validateAssets() public {
        productCatalogue.setProduct(defaults.usdcProductId(), defaults.usdcProduct());
        productCatalogue.setProduct(defaults.wethProductId(), defaults.wethProduct());
        productCatalogue.setProduct(defaults.wbtcProductId(), defaults.wbtcProduct());
        productCatalogue.setProduct(
            defaults.wethUsdcPerpProductId(), defaults.wethUsdcPerpProduct()
        );
        productCatalogue.setProduct(
            defaults.wbtcUsdcPerpProductId(), defaults.wbtcUsdcPerpProduct()
        );
    }

    function depositAssetsToCiao() public {
        validateAssets();
        vm.startPrank({msgSender: users.alice});
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        weth.approve(address(ciao), defaults.wethDepositQuantity());
        ciao.deposit(users.alice, 1, defaults.usdcDepositQuantity(), address(usdc));
        ciao.deposit(users.alice, 1, defaults.wethDepositQuantity(), address(weth));
        vm.startPrank({msgSender: users.dan});
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        weth.approve(address(ciao), defaults.wethDepositQuantity());
        ciao.deposit(users.dan, 1, defaults.usdcDepositQuantity(), address(usdc));
        ciao.deposit(users.dan, 1, defaults.wethDepositQuantity(), address(weth));
        vm.startPrank({msgSender: users.alice});
    }

    function depositAssetsToCiaoForAddresses(address user1, address user2) public {
        deal({token: address(usdc), to: user1, give: 1_000_000 * 10 ** usdc.decimals()});
        deal({token: address(weth), to: user1, give: 1_000_000e18});
        deal({token: address(wbtc), to: user1, give: 1_000_000e8});
        deal({token: address(usdc), to: user2, give: 1_000_000 * 10 ** usdc.decimals()});
        deal({token: address(weth), to: user2, give: 1_000_000e18});
        deal({token: address(wbtc), to: user2, give: 1_000_000e8});
        vm.startPrank({msgSender: user1});
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        weth.approve(address(ciao), defaults.wethDepositQuantity());
        ciao.deposit(user1, 1, defaults.usdcDepositQuantity(), address(usdc));
        ciao.deposit(user1, 1, defaults.wethDepositQuantity(), address(weth));
        vm.startPrank({msgSender: user2});
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        weth.approve(address(ciao), defaults.wethDepositQuantity());
        ciao.deposit(user2, 1, defaults.usdcDepositQuantity(), address(usdc));
        ciao.deposit(user2, 1, defaults.wethDepositQuantity(), address(weth));
        vm.startPrank({msgSender: users.gov});
    }

    function depositAssetsToCiaoAndSwitchGov() public {
        validateAssets();
        vm.startPrank({msgSender: users.alice});
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        weth.approve(address(ciao), defaults.wethDepositQuantity());
        ciao.deposit(users.alice, 1, defaults.usdcDepositQuantity(), address(usdc));
        ciao.deposit(users.alice, 1, defaults.wethDepositQuantity(), address(weth));
        vm.startPrank({msgSender: users.dan});
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        weth.approve(address(ciao), defaults.wethDepositQuantity());
        ciao.deposit(users.dan, 1, defaults.usdcDepositQuantity(), address(usdc));
        ciao.deposit(users.dan, 1, defaults.wethDepositQuantity(), address(weth));
        vm.startPrank({msgSender: users.alice});
        noop();
        vm.startPrank({msgSender: users.gov});
    }

    function setupCoreCollateralDebt(int256 debt) public {
        uint256 quantity = defaults.usdcDepositQuantity();
        address asset = address(usdc);

        vm.startPrank(users.gov);
        // temporarily switch the order dispatch to users.gov
        // give dan some debt
        addressManifest.updateAddressInManifest(4, users.gov);
        ciao.executeWithdrawal(users.dan, 1, quantity, asset);
        ciao.settleCoreCollateral(Commons.getSubAccount(users.dan, 1), debt);
        // temporarily switch the order dispatch to users.gov
        addressManifest.updateAddressInManifest(4, address(orderDispatch));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Address manifest shared
    //////////////////////////////////////////////////////////////////////////*/

    function deployAddressManifest() internal {
        vm.startPrank({msgSender: users.gov});
        addressManifest = new AddressManifest();
        vm.label({account: address(addressManifest), newLabel: "AddressManifest"});
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   Margin Directives shared
    //////////////////////////////////////////////////////////////////////////*/

    function deployMarginDirective() internal {
        vm.startPrank({msgSender: users.gov});
        marginDirective = new MockMarginDirective();
        vm.label({account: address(marginDirective), newLabel: "MockMarginDirective"});
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Product catalogue shared
    //////////////////////////////////////////////////////////////////////////*/

    function deployProductCatalogue() internal {
        vm.startPrank({msgSender: users.gov});
        productCatalogue = new ProductCatalogue(address(addressManifest));
        vm.label({account: address(productCatalogue), newLabel: "ProductCatalogue"});
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Furnace shared
    //////////////////////////////////////////////////////////////////////////*/

    function deployFurnace() internal {
        vm.startPrank({msgSender: users.gov});
        furnace = new Furnace(address(addressManifest));
        vm.label({account: address(furnace), newLabel: "Furnace"});
        furnace.setProductRiskWeight(defaults.usdcProductId(), defaults.usdcRiskWeights());
        furnace.setProductRiskWeight(defaults.wethProductId(), defaults.wethRiskWeights());
        furnace.setProductRiskWeight(defaults.wbtcProductId(), defaults.wbtcRiskWeights());
        furnace.setProductRiskWeight(
            defaults.wethUsdcPerpProductId(), defaults.wethUsdcPerpRiskWeights()
        );
        furnace.setProductRiskWeight(
            defaults.wbtcUsdcPerpProductId(), defaults.wbtcUsdcPerpRiskWeights()
        );
        furnace.setSpotRiskWeight(address(usdc), defaults.usdcRiskWeights());
        furnace.setSpotRiskWeight(address(weth), defaults.wethRiskWeights());
        furnace.setSpotRiskWeight(address(wbtc), defaults.wbtcRiskWeights());
        furnace.setBaseAssetQuotePerps(address(weth), defaults.wethUsdcPerpProductId());
        furnace.setBaseAssetQuotePerps(address(wbtc), defaults.wbtcUsdcPerpProductId());
        furnace.setSpreadPenalty(
            address(wbtc),
            defaults.wbtcSpreadPenalty().initial,
            defaults.wbtcSpreadPenalty().maintenance
        );
        furnace.setSpreadPenalty(
            address(weth),
            defaults.wethSpreadPenalty().initial,
            defaults.wethSpreadPenalty().maintenance
        );
    }

    function deployMockFurnaceUnitTest() internal {
        vm.startPrank({msgSender: users.gov});
        addressManifest = new AddressManifest();
        addressManifest.setAdmin(users.gov);
        mockFurnaceUnitTest = new MockFurnaceUnitTest(address(addressManifest));
        mockFurnaceUnitTest.setProductRiskWeight(
            defaults.usdcProductId(), defaults.usdcRiskWeights()
        );
        mockFurnaceUnitTest.setProductRiskWeight(
            defaults.wethProductId(), defaults.wethRiskWeights()
        );
        mockFurnaceUnitTest.setProductRiskWeight(
            defaults.usdcProductId(), defaults.usdcRiskWeights()
        );
        mockFurnaceUnitTest.setProductRiskWeight(
            defaults.wethUsdcPerpProductId(), defaults.wethUsdcPerpRiskWeights()
        );
        mockFurnaceUnitTest.setProductRiskWeight(
            defaults.wbtcUsdcPerpProductId(), defaults.wbtcUsdcPerpRiskWeights()
        );
        mockFurnaceUnitTest.setSpotRiskWeight(address(usdc), defaults.usdcRiskWeights());
        mockFurnaceUnitTest.setSpotRiskWeight(address(weth), defaults.wethRiskWeights());
        mockFurnaceUnitTest.setSpotRiskWeight(address(wbtc), defaults.wbtcRiskWeights());
        mockFurnaceUnitTest.setBaseAssetQuotePerps(address(weth), defaults.wethUsdcPerpProductId());
        mockFurnaceUnitTest.setBaseAssetQuotePerps(address(wbtc), defaults.wbtcUsdcPerpProductId());
        mockFurnaceUnitTest.setSpreadPenalty(
            address(wbtc),
            defaults.wbtcSpreadPenalty().initial,
            defaults.wbtcSpreadPenalty().maintenance
        );
        mockFurnaceUnitTest.setSpreadPenalty(
            address(weth),
            defaults.wethSpreadPenalty().initial,
            defaults.wethSpreadPenalty().maintenance
        );

        vm.label({account: address(mockFurnaceUnitTest), newLabel: "Furnace"});
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Liquidation shared
    //////////////////////////////////////////////////////////////////////////*/
    function deployLiquidation() internal {
        vm.startPrank({msgSender: users.gov});
        liquidation = new Liquidation(address(addressManifest));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Perp Crucible shared
    //////////////////////////////////////////////////////////////////////////*/

    function setFundingRate(uint32 perpId, int256 cumFunding) internal {
        uint32[] memory perpIds = new uint32[](1);
        perpIds[0] = perpId;
        int256[] memory cumFundings = new int256[](1);
        cumFundings[0] = cumFunding;
        bytes memory payload = abi.encodePacked(perpIds[0], cumFundings[0]);
        perpCrucible.updateCumulativeFundings(payload);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CALL EXPECTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Expects a call to {ERC20.transfer}.
    function expectCallToTransfer(address to, uint256 quantity) internal {
        vm.expectCall({callee: address(usdc), data: abi.encodeCall(ERC20.transfer, (to, quantity))});
    }

    /// @dev Expects a call to {ERC20.transfer}.
    function expectCallToTransferToken(ERC20 asset, address to, uint256 quantity) internal {
        vm.expectCall({callee: address(asset), data: abi.encodeCall(ERC20.transfer, (to, quantity))});
    }

    /// @dev Expects a call to {ERC20.transferFrom}.
    function expectCallToTransferFrom(address from, address to, uint256 quantity) internal {
        vm.expectCall({
            callee: address(usdc),
            data: abi.encodeCall(ERC20.transferFrom, (from, to, quantity))
        });
    }

    /// @dev Expects a call to {ERC20.transferFrom}.
    function expectCallToTransferFromToken(ERC20 asset, address from, address to, uint256 quantity)
        internal
    {
        vm.expectCall({
            callee: address(asset),
            data: abi.encodeCall(ERC20.transferFrom, (from, to, quantity))
        });
    }

    function getSpotBalances(address u1, address u2, address a1, address a2)
        public
        view
        returns (int256, uint256, int256, uint256, uint256, uint256)
    {
        return (
            int256(ciao.balances(u1, a1)) - int256(ciao.coreCollateralDebt(u1)),
            ciao.balances(u1, a2),
            int256(ciao.balances(u2, a1)) - int256(ciao.coreCollateralDebt(u2)),
            ciao.balances(u2, a2),
            ciao.balances(users.operator, a1),
            ciao.balances(users.operator, a2)
        );
    }

    function getCoreCollatBalances(address u1, address u2)
        public
        view
        returns (int256, int256, uint256)
    {
        return (
            int256(ciao.balances(u1, address(usdc))) - int256(ciao.coreCollateralDebt(u1)),
            int256(ciao.balances(u2, address(usdc))) - int256(ciao.coreCollateralDebt(u2)),
            ciao.balances(users.operator, address(usdc))
        );
    }

    function getPerpBalances(uint32 pid, address u1, address u2)
        public
        view
        returns (Structs.PositionState memory, Structs.PositionState memory, uint256)
    {
        return (
            perpCrucible.getSubAccountPosition(pid, u1),
            perpCrucible.getSubAccountPosition(pid, u2),
            ciao.balances(users.operator, address(usdc))
        );
    }

    // TODO: average entry price checks, initCumFundingCheck and isLong check and ciao balance checks
    function assertPerpBalanceChange(uint256 qdiff, bool isTakerLong, uint32 productId)
        public
        view
    {
        (Structs.PositionState memory _takeru1pid, Structs.PositionState memory _makeru2pid,) =
        getPerpBalances(
            productId, Commons.getSubAccount(users.dan, 1), Commons.getSubAccount(users.alice, 1)
        );

        if (isTakerLong) {
            assertTrue(_takeru1pid.isLong);
            assertEq(_takeru1pid.quantity - takeru1pid.quantity, qdiff);
            assertFalse(_makeru2pid.isLong);
            assertEq(_makeru2pid.quantity - makeru2pid.quantity, qdiff);
        } else {
            assertFalse(_takeru1pid.isLong);
            assertEq(_takeru1pid.quantity - takeru1pid.quantity, qdiff);
            assertTrue(_makeru2pid.isLong);
            assertEq(_makeru2pid.quantity - makeru2pid.quantity, qdiff);
        }
    }

    function assertCoreCollatFeeChange(
        uint256 a1diff,
        uint32 productId,
        uint256 baseQuantity,
        uint256 executionPrice,
        uint8 txCount
    ) public {
        (int256 _bcu1, int256 _bcu2, uint256 _bcf) = getCoreCollatBalances(
            Commons.getSubAccount(users.dan, 1), Commons.getSubAccount(users.alice, 1)
        );
        Structs.Product memory product = IProductCatalogue(
            Commons.productCatalogue(address(addressManifest))
        ).products(productId);
        uint256 notional = BasicMath.mul(baseQuantity, executionPrice);
        uint256 takerFee = BasicMath.mul(notional, product.takerFee);
        int256 makerFee = int256(BasicMath.mul(notional, product.makerFee));
        if (product.isMakerRebate) {
            makerFee = -makerFee;
        }
        assertEq(
            _bcf - bcf,
            uint256(int256(takerFee) + makerFee + int256(orderDispatch.txFees(0) * txCount))
        );
        assertEq(
            bcu1 - _bcu1,
            int256(a1diff) + int256(takerFee + orderDispatch.txFees(0) * txCount),
            "core collat user 1 off"
        );
        assertEq(int256(bcu2) - int256(_bcu2), -int256(a1diff) + makerFee, "core collat user 2 off");
        bcu1 = _bcu1;
        bcu2 = _bcu2;
        bcf = _bcf;
    }

    // no fees charged on ADL
    function assertCoreCollatFeeChangeADL(uint256 a1diff) public {
        (int256 _bcu1, int256 _bcu2, uint256 _bcf) = getCoreCollatBalances(
            Commons.getSubAccount(users.dan, 1), Commons.getSubAccount(users.alice, 1)
        );

        assertEq(_bcf - bcf, 0);
        assertEq(bcu1 - _bcu1, int256(a1diff), "core collat user 1 off");
        assertEq(int256(bcu2) - int256(_bcu2), -int256(a1diff), "core collat user 2 off");
        bcu1 = _bcu1;
        bcu2 = _bcu2;
        bcf = _bcf;
    }

    function assertSpotBalanceChange(
        uint256 a1diff,
        uint256 a2diff,
        bool isTakerLong,
        uint32 productId,
        uint256 baseQuantity,
        uint256 executionPrice,
        uint256 sequencerFee
    ) public {
        (int256 _u1a1, uint256 _u1a2, int256 _u2a1, uint256 _u2a2, uint256 _fa1, uint256 _fa2) =
        getSpotBalances(
            Commons.getSubAccount(users.dan, 1),
            Commons.getSubAccount(users.alice, 1),
            address(usdc),
            address(weth)
        );
        if (isTakerLong) {
            // user pays sequencer fee on top of a1diff
            assertEq(u1a1 - _u1a1, int256(a1diff) + int256(sequencerFee));
            // _fa1 - fa1 includes sequencer fee paid by u1, so deduct that from the expected value
            assertEq(_u2a1 - u2a1, int256(a1diff) - (int256(_fa1 - fa1) - int256(sequencerFee)));
            assertEq(_u1a2 - u1a2, a2diff - (_fa2 - fa2));
            assertEq(u2a2 - _u2a2, a2diff);
        } else {
            // _fa1 - fa1 includes the sequencer fee paid by u1
            assertEq(_u1a1 - u1a1, int256(a1diff) - (int256(_fa1 - fa1)));
            assertEq(u2a1 - _u2a1, int256(a1diff));
            assertEq(u1a2 - _u1a2, a2diff);
            assertEq(_u2a2 - u2a2, a2diff - (_fa2 - fa2));
        }
        _assertSpotFees(
            isTakerLong, productId, baseQuantity, executionPrice, _fa1, _fa2, sequencerFee
        );
        u1a1 = _u1a1;
        u1a2 = _u1a2;
        u2a1 = _u2a1;
        u2a2 = _u2a2;
        fa1 = _fa1;
        fa2 = _fa2;
    }

    function _assertSpotFees(
        bool isTakerLong,
        uint32 productId,
        uint256 baseQuantity,
        uint256 executionPrice,
        uint256 _fa1,
        uint256 _fa2,
        uint256 sequencerFee
    ) internal view {
        (,,,, uint256 takerFee, uint256 makerFee,) = productCatalogue.products(productId);
        if (isTakerLong) {
            assertEq(BasicMath.mul(baseQuantity, takerFee), _fa2 - fa2);
            assertEq(
                BasicMath.mul(BasicMath.mul(baseQuantity, executionPrice), makerFee) + sequencerFee,
                _fa1 - fa1
            );
        } else {
            assertEq(
                BasicMath.mul(BasicMath.mul(baseQuantity, executionPrice), takerFee) + sequencerFee,
                _fa1 - fa1
            );
            assertEq(BasicMath.mul(baseQuantity, makerFee), _fa2 - fa2);
        }
    }

    function _acquireBalanceDetails(
        uint256 quotediff,
        uint256 basediff,
        bool isTakerLong,
        uint32 productId,
        uint256 baseQuantity,
        uint256 executionPrice
    ) public view returns (SpotBalanceDetailsTemp memory s) {
        s.feeRecipient = users.operator;
        (, address baseAsset, address quoteAsset,, uint256 takerFee, uint256 makerFee,) =
            productCatalogue.products(productId);
        s.baseAsset = baseAsset;
        s.quoteAsset = quoteAsset;
        int256 _fb;
        int256 _fq;
        if (isTakerLong) {
            _fb = int256(BasicMath.mul(baseQuantity, takerFee));

            _fq = int256(BasicMath.mul(BasicMath.mul(baseQuantity, executionPrice), makerFee));
            s.longAccount = Commons.getSubAccount(users.dan, 1);
            s.shortAccount = Commons.getSubAccount(users.alice, 1);
        } else {
            _fb = int256(BasicMath.mul(baseQuantity, makerFee));
            _fq = int256(BasicMath.mul(BasicMath.mul(baseQuantity, executionPrice), takerFee));
            s.longAccount = Commons.getSubAccount(users.alice, 1);
            s.shortAccount = Commons.getSubAccount(users.dan, 1);
        }
        if (baseQuantity > 0) {
            s.sequencerFee = int256(orderDispatch.txFees(0));
        }
        s.longAccountBaseBalanceBefore = int256(ciao.balances(s.longAccount, s.baseAsset));
        s.longAccountBaseBalanceAfter = s.longAccountBaseBalanceBefore + int256(basediff) - _fb;
        s.longAccountQuoteBalanceBefore = int256(ciao.balances(s.longAccount, s.quoteAsset))
            - int256(ciao.coreCollateralDebt(s.longAccount));
        s.longAccountQuoteBalanceAfter = s.longAccountQuoteBalanceBefore - int256(quotediff);
        s.shortAccountBaseBalanceBefore = int256(ciao.balances(s.shortAccount, s.baseAsset));
        s.shortAccountBaseBalanceAfter = s.shortAccountBaseBalanceBefore - int256(basediff);
        s.shortAccountQuoteBalanceBefore = int256(ciao.balances(s.shortAccount, s.quoteAsset))
            - int256(ciao.coreCollateralDebt(s.shortAccount));
        s.shortAccountQuoteBalanceAfter = s.shortAccountQuoteBalanceBefore + int256(quotediff) - _fq;
        s.feeRecipientBaseBalanceBefore = int256(ciao.balances(s.feeRecipient, s.baseAsset));
        s.feeRecipientBaseBalanceAfter = s.feeRecipientBaseBalanceBefore + _fb;
        s.feeRecipientQuoteBalanceBefore = int256(ciao.balances(s.feeRecipient, s.quoteAsset));
        s.feeRecipientQuoteBalanceAfter = s.feeRecipientQuoteBalanceBefore + _fq;
    }

    function ensureBalanceChangeEventsSpotMatch(
        uint256 a1diff,
        uint256 a2diff,
        bool isTakerLong,
        uint32 productId,
        uint256 baseQuantity,
        uint256 executionPrice
    ) public {
        SpotBalanceDetailsTemp memory s = _acquireBalanceDetails(
            a1diff, a2diff, isTakerLong, productId, baseQuantity, executionPrice
        );
        // long account increment asset 1 gets the first emission
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            s.longAccount,
            s.baseAsset,
            s.longAccountBaseBalanceBefore,
            s.longAccountBaseBalanceAfter
        );
        // fee recipient asset 1 goes second
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            s.feeRecipient,
            s.baseAsset,
            s.feeRecipientBaseBalanceBefore,
            s.feeRecipientBaseBalanceAfter
        );
        // short account decrement asset 1 goes third
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            s.shortAccount,
            s.baseAsset,
            s.shortAccountBaseBalanceBefore,
            s.shortAccountBaseBalanceAfter
        );
        // short account increment asset 2 gets the fourth emission
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            s.shortAccount,
            s.quoteAsset,
            s.shortAccountQuoteBalanceBefore,
            s.shortAccountQuoteBalanceAfter
        );
        // fee recipient asset 2 goes fifth
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            s.feeRecipient,
            s.quoteAsset,
            s.feeRecipientQuoteBalanceBefore,
            s.feeRecipientQuoteBalanceAfter
        );
        // long account decrement asset 2 goes sixth
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            s.longAccount,
            s.quoteAsset,
            s.longAccountQuoteBalanceBefore,
            s.longAccountQuoteBalanceAfter
        );
        if (s.sequencerFee > 0) {
            // sequencer fee deduction goes 7th
            vm.expectEmit(address(ciao));
            emit Events.BalanceChanged(
                isTakerLong ? s.longAccount : s.shortAccount,
                s.quoteAsset,
                isTakerLong ? s.longAccountQuoteBalanceAfter : s.shortAccountQuoteBalanceAfter,
                (isTakerLong ? s.longAccountQuoteBalanceAfter : s.shortAccountQuoteBalanceAfter)
                    - s.sequencerFee
            );
            // fee recipient increment by sequencer fee last
            vm.expectEmit(address(ciao));
            emit Events.BalanceChanged(
                s.feeRecipient,
                s.quoteAsset,
                s.feeRecipientQuoteBalanceAfter,
                s.feeRecipientQuoteBalanceAfter + s.sequencerFee
            );
        }
    }

    function _acquirePerpQuoteDetails(
        uint256 a1diff,
        uint32 productId,
        uint256 baseQuantity,
        uint256 executionPrice,
        bool inclFees // false in case of ADL
    ) internal view returns (PerpBalanceDetailsTemp memory p) {
        Structs.Product memory product = IProductCatalogue(
            Commons.productCatalogue(address(addressManifest))
        ).products(productId);
        uint256 notional = BasicMath.mul(baseQuantity, executionPrice);
        int256 takerFee = inclFees
            ? int256(BasicMath.mul(notional, product.takerFee)) + int256(orderDispatch.txFees(0))
            : int256(0);
        int256 makerFee = inclFees ? int256(BasicMath.mul(notional, product.makerFee)) : int256(0);
        if (product.isMakerRebate) {
            makerFee = -makerFee;
        }
        p.quoteAsset = address(usdc);
        p.taker = Commons.getSubAccount(users.dan, 1);
        p.maker = Commons.getSubAccount(users.alice, 1);
        p.feeRecipient = users.operator;
        p.takerQuoteBalanceBefore =
            int256(ciao.balances(p.taker, p.quoteAsset)) - int256(ciao.coreCollateralDebt(p.taker));
        p.makerQuoteBalanceBefore =
            int256(ciao.balances(p.maker, p.quoteAsset)) - int256(ciao.coreCollateralDebt(p.maker));
        p.feeRecipientQuoteBalanceBefore = int256(ciao.balances(p.feeRecipient, p.quoteAsset));
        p.takerQuoteBalanceAfter = p.takerQuoteBalanceBefore - int256(a1diff) - takerFee;
        p.makerQuoteBalanceAfter = p.makerQuoteBalanceBefore + int256(a1diff) - makerFee;
        p.feeRecipientQuoteBalanceAfter = p.feeRecipientQuoteBalanceBefore + takerFee + makerFee;
    }

    function ensureBalanceChangeEventsPerpMatch(
        uint256 a1diff,
        uint32 productId,
        uint256 baseQuantity,
        uint256 executionPrice
    ) public {
        PerpBalanceDetailsTemp memory p =
            _acquirePerpQuoteDetails(a1diff, productId, baseQuantity, executionPrice, true);
        // taker settle asset 1 first
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            p.taker, p.quoteAsset, p.takerQuoteBalanceBefore, p.takerQuoteBalanceAfter
        );
        // maker settle asset 1 second
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            p.maker, p.quoteAsset, p.makerQuoteBalanceBefore, p.makerQuoteBalanceAfter
        );
        // fee recipient collects fee asset 1 last
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            p.feeRecipient,
            p.quoteAsset,
            p.feeRecipientQuoteBalanceBefore,
            p.feeRecipientQuoteBalanceAfter
        );
    }

    function ensureADLBalanceChangeEventsPerpMatch(
        uint256 a1diff,
        uint32 productId,
        uint256 baseQuantity,
        uint256 executionPrice
    ) public {
        PerpBalanceDetailsTemp memory p =
            _acquirePerpQuoteDetails(a1diff, productId, baseQuantity, executionPrice, false);
        // taker settle asset 1 first
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            p.taker, p.quoteAsset, p.takerQuoteBalanceBefore, p.takerQuoteBalanceAfter
        );
        // maker settle asset 1 second
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            p.maker, p.quoteAsset, p.makerQuoteBalanceBefore, p.makerQuoteBalanceAfter
        );
        // fee recipient collects fee asset 1 last
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            p.feeRecipient,
            p.quoteAsset,
            p.feeRecipientQuoteBalanceBefore,
            p.feeRecipientQuoteBalanceAfter
        );
    }

    function makeOrderSig(Structs.Order memory order, string memory user)
        public
        returns (bytes memory, bytes32)
    {
        (, uint256 privateKey) = makeAddrAndKey(user);
        bytes32 msgHash = orderDispatch.getOrderDigest(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        bytes memory sig = abi.encodePacked(r, s, v);
        assertEq(sig.length, 65);
        return (sig, msgHash);
    }

    function makeApprovedSignerSig(Structs.ApproveSigner memory _approval, string memory user)
        public
        returns (bytes memory, bytes32)
    {
        (, uint256 privateKey) = makeAddrAndKey(user);
        bytes32 msgHash = orderDispatch.getApprovalDigest(_approval);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        bytes memory sig = abi.encodePacked(r, s, v);
        assertEq(sig.length, 65);
        return (sig, msgHash);
    }

    function makeDepositSig(Structs.Deposit memory _deposit, string memory user)
        public
        returns (bytes memory, bytes32)
    {
        (, uint256 privateKey) = makeAddrAndKey(user);
        bytes32 msgHash = orderDispatch.getDepositDigest(_deposit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        bytes memory sig = abi.encodePacked(r, s, v);
        assertEq(sig.length, 65);
        return (sig, msgHash);
    }

    function makeWithdrawSig(Structs.Withdraw memory _withdraw, string memory user)
        public
        returns (bytes memory, bytes32)
    {
        (, uint256 privateKey) = makeAddrAndKey(user);
        bytes32 msgHash = orderDispatch.getWithdrawDigest(_withdraw);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        bytes memory sig = abi.encodePacked(r, s, v);
        assertEq(sig.length, 65);
        return (sig, msgHash);
    }

    function makeLiquidateSig(Structs.LiquidateSubAccount memory _liquidate, string memory user)
        public
        returns (bytes memory, bytes32)
    {
        (, uint256 privateKey) = makeAddrAndKey(user);
        bytes32 msgHash = orderDispatch.getLiquidateDigest(_liquidate);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        bytes memory sig = abi.encodePacked(r, s, v);
        assertEq(sig.length, 65);
        return (sig, msgHash);
    }

    /// @notice Computes payoff for perp i.e. unrealized P&L
    /// @dev Identical to maintenance margin calculations without risk weightings
    /// @dev Accounts for unrealised funding payments
    /// @return payoff Profit or loss of position @ current spot (can be negative)
    function getPerpPayoff(
        uint256 quantity,
        uint256 avgEntryPrice,
        bool isLong,
        uint256 markPrice,
        int256 initCumFunding,
        int256 currentCumFunding
    ) internal pure returns (int256 payoff) {
        // Case 1: long position
        // quantity * markPrice - quantity * avgEntryPrice - (currentCumFunding - initCumFunding) * quantity
        // == quantity(markPrice - avgEntryPrice - (currentCumFunding - initCumFunding))
        // == quantity(markPrice - avgEntryPrice - currentCumFunding + initCumFunding)
        if (isLong) {
            payoff = int256(quantity).mul(
                int256(markPrice) - int256(avgEntryPrice) - currentCumFunding + initCumFunding
            );
        }
        // Case 2: short position
        // quantity is flipped negative to represent short position
        // -quantity * markPrice - (-quantity) * avgEntryPrice - (currentCumFunding - initCumFunding) * (-quantity)
        // == -quantity(markPrice - avgEntryPrice - currentCumFunding + initCumFunding)
        else {
            payoff = -int256(quantity).mul(
                int256(markPrice) - int256(avgEntryPrice) - currentCumFunding + initCumFunding
            );
        }
    }

    /**
     * @dev returns the absolute value of a signed int
     */
    function abs(int256 a) internal pure returns (int256) {
        return a < 0 ? -a : a;
    }

    function noop() public {
        usdc.approve(address(0), 0);
    }
}
