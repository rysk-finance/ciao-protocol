// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/contracts/libraries/Commons.sol";
import {Events} from "src/contracts/interfaces/Events.sol";
import {IProductCatalogue} from "src/contracts/interfaces/IProductCatalogue.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "src/contracts/libraries/BasicMath.sol";
import {Base_Test} from "../../Base.t.sol";
import {OrderDispatchBase} from "./OrderDispatchBase.t.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";

contract OrderDispatchDepositBaseTest is OrderDispatchBase {
    using MessageHashUtils for bytes32;

    function setUp() public virtual override {
        OrderDispatchBase.setUp();
        deployOrderDispatch();
        approval = Structs.ApproveSigner(users.alice, 1, users.keeper, true, uint64(2));
        takerOrder = Structs.Order(
            users.dan,
            1,
            2,
            true,
            uint8(0),
            uint8(1),
            2,
            1000e18,
            uint128(defaults.wethDepositQuantity()),
            1
        );
        makerOrder = Structs.Order(
            users.alice,
            1,
            2,
            false,
            uint8(0),
            uint8(1),
            2,
            1000e18,
            uint128(defaults.wethDepositQuantity()),
            1
        );
        (u1a1, u1a2, u2a1, u2a2, fa1, fa2) = getSpotBalances(
            Commons.getSubAccount(users.dan, 1),
            Commons.getSubAccount(users.alice, 1),
            address(usdc),
            address(weth)
        );
        addressManifest.setRequiresDispatchCall(false);
    }

    function test_Happy_Deposit_Usdc() public {
        vm.startPrank(users.alice);
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        vm.stopPrank();
        vm.startPrank(users.gov);
        address subAccount = Commons.getSubAccount(users.alice, 0);
        expectCallToTransferFrom(users.alice, address(ciao), defaults.usdcDepositQuantity());
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc)))
                + int256(Commons.convertToE18(defaults.usdcDepositQuantity(), usdc.decimals()))
        );
        vm.expectEmit(address(ciao));
        emit Events.Deposit(users.alice, 0, address(usdc), defaults.usdcDepositQuantity());
        constructDepositPayload(
            users.alice, 0, defaults.usdcDepositQuantity(), address(usdc), "alice"
        );
        orderDispatch.ingresso(transaction);
        assertEq(
            ciao.balances(subAccount, address(usdc)),
            Commons.convertToE18(defaults.usdcDepositQuantity(), usdc.decimals())
        );
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(usdc)));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0), address(usdc));
        assertEq(ciao.subAccountAssetSetLength(subAccount), 1);
        address[] memory subAccountAssets = ciao.getSubAccountAssets(subAccount);
        assertEq(subAccountAssets[0], address(usdc));
        assertEq(subAccountAssets.length, 1);
    }

    function test_Fail_cant_reuse_signature() public {
        vm.startPrank(users.alice);
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        vm.stopPrank();
        vm.startPrank(users.gov);
        address subAccount = Commons.getSubAccount(users.alice, 0);
        expectCallToTransferFrom(users.alice, address(ciao), defaults.usdcDepositQuantity());
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc)))
                + int256(Commons.convertToE18(defaults.usdcDepositQuantity(), usdc.decimals()))
        );
        vm.expectEmit(address(ciao));
        emit Events.Deposit(users.alice, 0, address(usdc), defaults.usdcDepositQuantity());
        constructDepositPayload(
            users.alice, 0, defaults.usdcDepositQuantity(), address(usdc), "alice"
        );
        orderDispatch.ingresso(transaction);
        assertEq(
            ciao.balances(subAccount, address(usdc)),
            Commons.convertToE18(defaults.usdcDepositQuantity(), usdc.decimals())
        );
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(usdc)));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0), address(usdc));
        assertEq(ciao.subAccountAssetSetLength(subAccount), 1);
        address[] memory subAccountAssets = ciao.getSubAccountAssets(subAccount);
        assertEq(subAccountAssets[0], address(usdc));
        assertEq(subAccountAssets.length, 1);
        vm.expectRevert(bytes4(keccak256("DigestedAlready()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Deposit_Usdc_0() public {
        vm.startPrank(users.alice);
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        vm.stopPrank();
        vm.startPrank(users.gov);
        constructDepositPayload(users.alice, 1, 0, address(usdc), "alice");
        vm.expectRevert(bytes4(keccak256("DepositQuantityInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Hackerman_depositing_with_someone_else() public {
        vm.startPrank(users.alice);
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        vm.stopPrank();
        vm.startPrank(users.gov);
        constructDepositPayload(
            users.alice, 1, defaults.usdcDepositQuantity(), address(usdc), "hackerman"
        );
        vm.expectRevert(bytes4(keccak256("SignatureInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Deposit_Usdc_InvalidProduct() public {
        vm.startPrank(users.alice);
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        vm.stopPrank();
        vm.startPrank(users.gov);
        constructDepositPayload(
            users.alice, 1, defaults.usdcDepositQuantity(), address(users.alice), "alice"
        );
        vm.expectRevert(bytes4(keccak256("ProductInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Happy_Deposit_Weth() public {
        vm.startPrank(users.alice);
        weth.approve(address(ciao), defaults.wethDepositQuantity());
        vm.stopPrank();
        vm.startPrank(users.gov);
        address subAccount = Commons.getSubAccount(users.alice, 1);
        expectCallToTransferFromToken(
            weth, users.alice, address(ciao), defaults.wethDepositQuantity()
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(weth),
            int256(ciao.balances(subAccount, address(weth))),
            int256(ciao.balances(subAccount, address(weth)))
                + int256(defaults.wethDepositQuantity())
        );
        vm.expectEmit(address(ciao));
        emit Events.Deposit(users.alice, 1, address(weth), defaults.wethDepositQuantity());
        constructDepositPayload(
            users.alice, 1, defaults.wethDepositQuantity(), address(weth), "alice"
        );
        orderDispatch.ingresso(transaction);
        assertEq(
            ciao.balances(subAccount, address(weth)),
            Commons.convertToE18(defaults.wethDepositQuantity() * 2, 18)
        );
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(weth)));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 1), address(weth));
        assertEq(ciao.subAccountAssetSetLength(subAccount), 2);
    }

    function test_Happy_Deposit_Multiple() public {
        vm.startPrank(users.alice);
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        vm.stopPrank();
        vm.startPrank(users.gov);
        ciao.setRequiresDispatchCall(true);
        address subAccount = Commons.getSubAccount(users.alice, 0);
        expectCallToTransferFrom(users.alice, address(ciao), defaults.usdcDepositQuantity());
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc)))
                + int256(Commons.convertToE18(defaults.usdcDepositQuantity(), usdc.decimals()))
        );
        vm.expectEmit(address(ciao));
        emit Events.Deposit(users.alice, 0, address(usdc), defaults.usdcDepositQuantity());
        constructDepositPayload(
            users.alice, 0, defaults.usdcDepositQuantity(), address(usdc), "alice"
        );
        orderDispatch.ingresso(transaction);
        assertEq(
            ciao.balances(subAccount, address(usdc)),
            Commons.convertToE18(defaults.usdcDepositQuantity(), usdc.decimals())
        );
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(usdc)));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0), address(usdc));
        assertEq(ciao.subAccountAssetSetLength(subAccount), 1);
        vm.startPrank(users.alice);
        weth.approve(address(ciao), defaults.wethDepositQuantity());
        vm.stopPrank();
        vm.startPrank(users.gov);
        expectCallToTransferFromToken(
            weth, users.alice, address(ciao), defaults.wethDepositQuantity()
        );
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(weth),
            int256(ciao.balances(subAccount, address(weth))),
            int256(ciao.balances(subAccount, address(weth)))
                + int256(defaults.wethDepositQuantity())
        );
        vm.expectEmit(address(ciao));
        emit Events.Deposit(users.alice, 0, address(weth), defaults.wethDepositQuantity());
        constructDepositPayload(
            users.alice, 0, defaults.wethDepositQuantity(), address(weth), "alice"
        );
        orderDispatch.ingresso(transaction);
        assertEq(
            ciao.balances(subAccount, address(weth)),
            Commons.convertToE18(defaults.wethDepositQuantity(), 18)
        );
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(weth)));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 1), address(weth));
        assertEq(ciao.subAccountAssetSetLength(subAccount), 2);
    }

    function test_Happy_Depo_Update_Price_Match_Order_Approve_Signer() public {
        vm.startPrank(users.alice);
        usdc.approve(address(ciao), defaults.usdcDepositQuantity());
        vm.stopPrank();
        vm.startPrank(users.gov);
        address subAccount = Commons.getSubAccount(users.alice, 0);
        expectCallToTransferFrom(users.alice, address(ciao), defaults.usdcDepositQuantity());
        vm.expectEmit(address(ciao));
        emit Events.BalanceChanged(
            subAccount,
            address(usdc),
            int256(ciao.balances(subAccount, address(usdc))),
            int256(ciao.balances(subAccount, address(usdc)))
                + int256(Commons.convertToE18(defaults.usdcDepositQuantity(), usdc.decimals()))
        );
        vm.expectEmit(address(ciao));
        emit Events.Deposit(users.alice, 0, address(usdc), defaults.usdcDepositQuantity());
        constructDepositPayload(
            users.alice, 0, defaults.usdcDepositQuantity(), address(usdc), "alice"
        );
        uint32[] memory setPricesProductIds = new uint32[](1);
        setPricesProductIds[0] = defaults.wbtcProductId();

        uint256[] memory setPricesValues = new uint256[](1);
        setPricesValues[0] = 100000e18;
        bytes memory payload =
            abi.encodePacked(uint8(1), setPricesProductIds[0], setPricesValues[0]);
        transaction.push(payload);
        appendApproveSignerPayload("alice", 1);
        (bytes32 takerHash, bytes32 makerHash) = appendMatchOrderPayload();
        vm.expectEmit(address(addressManifest));
        emit Events.SignerApprovalUpdated(
            approval.account, approval.subAccountId, approval.approvedSigner, approval.isApproved
        );
        ensureBalanceChangeEventsSpotMatch(
            defaults.usdcDepositQuantityE18(),
            defaults.wethDepositQuantity(),
            true,
            takerOrder.productId,
            BasicMath.min(takerOrder.quantity, makerOrder.quantity),
            makerOrder.price
        );
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerHash, makerHash);
        orderDispatch.ingresso(transaction);
        assertEq(
            ciao.balances(subAccount, address(usdc)),
            Commons.convertToE18(defaults.usdcDepositQuantity(), usdc.decimals())
        );
        assertTrue(ciao.isAssetInSubAccountAssetSet(subAccount, address(usdc)));
        assertEq(ciao.assetAtIndexInSubAccountAssetSet(subAccount, 0), address(usdc));
        assertEq(ciao.subAccountAssetSetLength(subAccount), 1);
        subAccount = Commons.getSubAccount(users.alice, 1);
        assertEq(furnace.prices(defaults.wbtcProductId()), 100000e18);
        assertTrue(addressManifest.approvedSigners(subAccount, users.keeper));
        assertEq(spotCrucible.filledQuantitys(takerHash), takerOrder.quantity);
        assertEq(spotCrucible.filledQuantitys(makerHash), makerOrder.quantity);
        assertSpotBalanceChange(
            defaults.usdcDepositQuantityE18(),
            defaults.wethDepositQuantity(),
            true,
            takerOrder.productId,
            BasicMath.min(takerOrder.quantity, makerOrder.quantity),
            makerOrder.price,
            orderDispatch.txFees(0)
        );
    }

    function test_Fail_Bad_Payload_Shape() public {
        constructDepositPayload(
            users.alice, 0, defaults.usdcDepositQuantity(), address(usdc), "alice"
        );
        transaction[0] = abi.encodePacked(transaction[0], uint8(0));
        vm.expectRevert(bytes4(keccak256("OrderByteLengthInvalid()")));
        orderDispatch.ingresso(transaction);
    }
}
