// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/contracts/libraries/Commons.sol";
import "src/contracts/libraries/Parser.sol";
import {Events} from "src/contracts/interfaces/Events.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {Base_Test} from "../../Base.t.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";

contract OrderDispatchBaseTest is Base_Test {
    using MessageHashUtils for bytes32;

    Structs.Order public takerOrder;
    bytes public takerOrderBytes;
    Structs.Order public makerOrder;
    Structs.MatchedOrder[] public matchedOrder;

    Structs.Order[] public makerOrderArr;
    bytes[] public makerOrderArrBytes;
    bytes[] public makerSigs;
    bytes[] public transaction;

    function setUp() public virtual override {
        Base_Test.setUp();
        deployOrderDispatch();
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
    }

    function constructMatchOrderPayload(bytes memory takerSig, bytes memory makerSig) public {
        if (makerOrderArr.length > 0) {
            makerOrderArr.pop();
            makerOrderArrBytes.pop();
            makerSigs.pop();
            transaction.pop();
        }
        makerOrderArr.push(makerOrder);
        makerOrderArrBytes.push(
            abi.encodePacked(
                makerOrder.account,
                makerOrder.subAccountId,
                makerOrder.productId,
                makerOrder.isBuy,
                makerOrder.orderType,
                makerOrder.timeInForce,
                makerOrder.expiration,
                makerOrder.price,
                makerOrder.quantity,
                makerOrder.nonce,
                makerSig
            )
        );
        takerOrderBytes = abi.encodePacked(
            takerOrder.account,
            takerOrder.subAccountId,
            takerOrder.productId,
            takerOrder.isBuy,
            takerOrder.orderType,
            takerOrder.timeInForce,
            takerOrder.expiration,
            takerOrder.price,
            takerOrder.quantity,
            takerOrder.nonce,
            takerSig
        );
        makerSigs.push(makerSig);
        transaction.push(
            abi.encodePacked(
                uint8(0), abi.encode(Structs.MatchedOrder(takerOrderBytes, makerOrderArrBytes))
            )
        );
    }

    function test_Happy_Correct_SignatureFuzz(string memory user) public {
        (address userAddr, uint256 privateKey) = makeAddrAndKey(user);
        Structs.Order memory order =
            Structs.Order(userAddr, 1, 2, true, uint8(0), uint8(1), 1, 100e18, 100e18, 1);
        bytes32 msgHash = keccak256(abi.encode(order)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);
        assertTrue(orderDispatch.checkSignature(userAddr, uint8(0), msgHash, signature));
    }

    function test_Fail_Signature_Not_Match_Sign_SenderFuzz(string memory user) public {
        (, uint256 privateKey) = makeAddrAndKey("hackerman");
        (address userAddr,) = makeAddrAndKey(user);
        Structs.Order memory order =
            Structs.Order(userAddr, 1, 2, true, uint8(0), uint8(1), 1, 100e18, 100e18, 1);
        bytes32 msgHash = keccak256(abi.encode(order)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);
        assertFalse(orderDispatch.checkSignature(userAddr, uint8(0), msgHash, signature));
    }

    function test_Fail_Signature_Not_Match_SenderFuzz(string memory user) public {
        (address userAddr, uint256 privateKey) = makeAddrAndKey(user);
        Structs.Order memory order =
            Structs.Order(userAddr, 1, 2, true, uint8(0), uint8(1), 1, 100e18, 100e18, 1);
        bytes32 msgHash = keccak256(abi.encode(order)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);
        assertFalse(orderDispatch.checkSignature(users.hackerman, uint8(0), msgHash, signature));
    }

    function test_Happy_Match_Order_Sig(string memory takerStr, string memory makerStr) public {
        (address taker, uint256 takerPrivateKey) = makeAddrAndKey(takerStr);
        (address maker, uint256 makerPrivateKey) = makeAddrAndKey(makerStr);
        depositAssetsToCiaoForAddresses(taker, maker);
        takerOrder.account = taker;
        makerOrder.account = maker;
        bytes32 takerMsgHash = orderDispatch.getOrderDigest(takerOrder);
        bytes32 makerMsgHash = orderDispatch.getOrderDigest(makerOrder);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(takerPrivateKey, takerMsgHash);
        bytes memory takerSig = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(makerPrivateKey, makerMsgHash);
        bytes memory makerSig = abi.encodePacked(r, s, v);
        assertEq(takerSig.length, 65);
        assertEq(makerSig.length, 65);
        constructMatchOrderPayload(takerSig, makerSig);
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerMsgHash, makerMsgHash);
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Not_Match_Order_Sig(string memory takerStr, string memory makerStr) public {
        (address taker,) = makeAddrAndKey(takerStr);
        (address maker,) = makeAddrAndKey(makerStr);
        (, uint256 hackerman) = makeAddrAndKey("hackerman");
        depositAssetsToCiaoForAddresses(taker, maker);
        bytes32 takerMsgHash = orderDispatch.getOrderDigest(takerOrder);
        bytes32 makerMsgHash = orderDispatch.getOrderDigest(makerOrder);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(hackerman, takerMsgHash);
        bytes memory takerSig = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(hackerman, makerMsgHash);
        bytes memory makerSig = abi.encodePacked(r, s, v);
        assertEq(takerSig.length, 65);
        assertEq(makerSig.length, 65);
        constructMatchOrderPayload(takerSig, makerSig);
        vm.expectRevert(bytes4(keccak256("SignatureInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Not_Match_Order_Sig_Order(string memory takerStr, string memory makerStr)
        public
    {
        (address taker, uint256 takerPrivateKey) = makeAddrAndKey(takerStr);
        (address maker, uint256 makerPrivateKey) = makeAddrAndKey(makerStr);
        depositAssetsToCiaoForAddresses(taker, maker);
        bytes32 takerMsgHash = orderDispatch.getOrderDigest(takerOrder);
        bytes32 makerMsgHash = orderDispatch.getOrderDigest(makerOrder);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(takerPrivateKey, takerMsgHash);
        bytes memory takerSig = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(makerPrivateKey, makerMsgHash);
        bytes memory makerSig = abi.encodePacked(r, s, v);
        assertEq(takerSig.length, 65);
        assertEq(makerSig.length, 65);
        constructMatchOrderPayload(takerSig, makerSig);
        vm.expectRevert(bytes4(keccak256("SignatureInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Happy_Order_Parser(
        string memory user,
        uint8 subAccountId,
        uint32 productId,
        bool isBuy,
        uint64 expiration,
        uint128 price,
        uint128 quantity,
        uint64 nonce
    ) public {
        (address account,) = makeAddrAndKey(user);
        takerOrder.account = account;
        takerOrder.subAccountId = subAccountId;
        takerOrder.productId = productId;
        takerOrder.isBuy = isBuy;
        takerOrder.orderType = uint8(5);
        takerOrder.timeInForce = uint8(1);
        takerOrder.expiration = expiration;
        takerOrder.price = price;
        takerOrder.quantity = quantity;
        takerOrder.nonce = nonce;
        (bytes memory signatori,) = makeOrderSig(takerOrder, user);
        bytes memory encodedOrder = abi.encodePacked(
            account,
            subAccountId,
            productId,
            isBuy,
            takerOrder.orderType,
            takerOrder.timeInForce,
            expiration,
            price,
            quantity,
            nonce,
            signatori
        );
        (Structs.Order memory order, bytes memory sig) = Parser.parseOrderBytes(encodedOrder, false);
        assertEq(order.account, account);
        assertEq(order.subAccountId, subAccountId);
        assertEq(order.productId, productId);
        assertEq(order.isBuy, isBuy);
        assertEq(uint8(order.orderType), uint8(takerOrder.orderType));
        assertEq(uint8(order.timeInForce), uint8(takerOrder.timeInForce));
        assertEq(order.expiration, expiration);
        assertEq(order.price, price);
        assertEq(order.quantity, quantity);
        assertEq(order.nonce, nonce);
        assertEq(sig, signatori);
    }
}
