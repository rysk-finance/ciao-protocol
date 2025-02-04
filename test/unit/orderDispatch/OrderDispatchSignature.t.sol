// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/contracts/libraries/Commons.sol";
import "src/contracts/libraries/Parser.sol";
import {OrderDispatch} from "src/contracts/OrderDispatch.sol";
import {Events} from "src/contracts/interfaces/Events.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Base_Test} from "../../Base.t.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";

contract OrderDispatchBaseTest is Base_Test, EIP712("Ciao", "0.0.0") {
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

    function constructMatchOrderPayload(
        bytes memory takerSig,
        bytes memory makerSig
    ) public {
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
                uint8(0),
                abi.encode(
                    Structs.MatchedOrder(takerOrderBytes, makerOrderArrBytes)
                )
            )
        );
    }

    function test_Fail_Cannot_Reinitialize_OrderDispatch() public {
        vm.expectRevert(bytes4(keccak256("InvalidInitialization()")));
        orderDispatch.initialize(users.hackerman);
    }

    function test_Happy_ProxyAdmin_Can_Upgrade() public {
        address newOrderDispatchImpl = address(new OrderDispatch());
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)),
            newOrderDispatchImpl,
            bytes("")
        );
        assertEq(
            address(
                uint160(
                    uint256(
                        vm.load(
                            address(proxy),
                            ERC1967Utils.IMPLEMENTATION_SLOT
                        )
                    )
                )
            ),
            newOrderDispatchImpl
        );
    }

    function test_Happy_Match_Order_Sig_After_Upgrade() public {
        (, uint256 takerPrivateKey) = makeAddrAndKey("dan");
        (, uint256 makerPrivateKey) = makeAddrAndKey("alice");
        bytes32 takerMsgHash = orderDispatch.getOrderDigest(takerOrder);
        bytes32 makerMsgHash = orderDispatch.getOrderDigest(makerOrder);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            takerPrivateKey,
            takerMsgHash
        );
        bytes memory takerSig = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(makerPrivateKey, makerMsgHash);
        bytes memory makerSig = abi.encodePacked(r, s, v);
        assertEq(takerSig.length, 65);
        assertEq(makerSig.length, 65);
        address newOrderDispatchImpl = address(new OrderDispatch());
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)),
            newOrderDispatchImpl,
            bytes("")
        );
        assertEq(
            address(
                uint160(
                    uint256(
                        vm.load(
                            address(proxy),
                            ERC1967Utils.IMPLEMENTATION_SLOT
                        )
                    )
                )
            ),
            newOrderDispatchImpl
        );
        constructMatchOrderPayload(takerSig, makerSig);
        vm.expectEmit(address(orderDispatch));
        emit Events.OrderMatched(takerMsgHash, makerMsgHash);
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_ProxyAdmin_Cant_Reinit() public {
        address newOrderDispatchImpl = address(new OrderDispatch());
        vm.expectRevert(bytes4(keccak256("InvalidInitialization()")));
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)),
            newOrderDispatchImpl,
            abi.encodeCall(OrderDispatch.initialize, address(users.gov))
        );
    }

    function test_Fail_Non_ProxyAdmin_Owner_Cannot_Upgrade() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(0x118cdaa7),
                0x89aFFa3D814BDC8244c4F5F555396d6B97217085
            )
        );
        vm.startPrank(users.hackerman);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)),
            users.hackerman,
            "0x0"
        );
    }

    function test_Happy_Correct_Signature() public {
        Structs.Order memory order = Structs.Order(
            users.gov,
            1,
            2,
            true,
            uint8(0),
            uint8(1),
            1,
            100e18,
            100e18,
            1
        );
        (, uint256 privateKey) = makeAddrAndKey("gov");
        bytes32 msgHash = _hashTypedDataV4(
            keccak256(abi.encode(order)).toEthSignedMessageHash()
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);
        assertTrue(
            orderDispatch.checkSignature(
                users.gov,
                uint8(0),
                msgHash,
                signature
            )
        );
    }

    function test_Fail_Signature_Not_Match_Sign_Sender() public {
        Structs.Order memory order = Structs.Order(
            users.gov,
            1,
            2,
            true,
            uint8(0),
            uint8(1),
            1,
            100e18,
            100e18,
            1
        );
        (, uint256 privateKey) = makeAddrAndKey("hackerman");
        bytes32 msgHash = _hashTypedDataV4(
            keccak256(abi.encode(order)).toEthSignedMessageHash()
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);
        assertFalse(
            orderDispatch.checkSignature(
                users.gov,
                uint8(0),
                msgHash,
                signature
            )
        );
    }

    function test_Fail_Signature_Not_Match_Sender() public {
        Structs.Order memory order = Structs.Order(
            users.gov,
            1,
            2,
            true,
            uint8(0),
            uint8(1),
            1,
            100e18,
            100e18,
            1
        );
        (, uint256 privateKey) = makeAddrAndKey("gov");
        bytes32 msgHash = _hashTypedDataV4(
            keccak256(abi.encode(order)).toEthSignedMessageHash()
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);
        assertFalse(
            orderDispatch.checkSignature(
                users.hackerman,
                uint8(0),
                msgHash,
                signature
            )
        );
    }

    function test_Happy_Match_Order_Sig() public {
        (, uint256 takerPrivateKey) = makeAddrAndKey("dan");
        (, uint256 makerPrivateKey) = makeAddrAndKey("alice");
        bytes32 takerMsgHash = orderDispatch.getOrderDigest(takerOrder);
        bytes32 makerMsgHash = orderDispatch.getOrderDigest(makerOrder);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            takerPrivateKey,
            takerMsgHash
        );
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

    function test_Fail_Match_Order_Sig_Bad_Order() public {
        (, uint256 takerPrivateKey) = makeAddrAndKey("dan");
        (, uint256 makerPrivateKey) = makeAddrAndKey("alice");
        bytes32 takerMsgHash = orderDispatch.getOrderDigest(takerOrder);
        bytes32 makerMsgHash = orderDispatch.getOrderDigest(makerOrder);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            takerPrivateKey,
            takerMsgHash
        );
        bytes memory takerSig = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(makerPrivateKey, makerMsgHash);
        bytes memory makerSig = abi.encodePacked(r, s, v);
        assertEq(takerSig.length, 65);
        assertEq(makerSig.length, 65);
        makerOrder = Structs.Order(
            users.alice,
            1,
            2,
            false,
            uint8(0),
            uint8(1),
            2,
            uint128(200 * 10 ** usdc.decimals()),
            100e18,
            1
        );
        constructMatchOrderPayload(takerSig, makerSig);
        vm.expectRevert(bytes4(keccak256("SignatureInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Match_Order_Sig_Bad_Taker() public {
        (, uint256 takerPrivateKey) = makeAddrAndKey("alice");
        (, uint256 makerPrivateKey) = makeAddrAndKey("alice");
        bytes32 takerMsgHash = orderDispatch.getOrderDigest(takerOrder);
        bytes32 makerMsgHash = orderDispatch.getOrderDigest(makerOrder);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            takerPrivateKey,
            takerMsgHash
        );
        bytes memory takerSig = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(makerPrivateKey, makerMsgHash);
        bytes memory makerSig = abi.encodePacked(r, s, v);
        assertEq(takerSig.length, 65);
        assertEq(makerSig.length, 65);
        constructMatchOrderPayload(takerSig, makerSig);
        vm.expectRevert(bytes4(keccak256("SignatureInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Match_Order_Sig_Bad_Maker() public {
        (, uint256 takerPrivateKey) = makeAddrAndKey("dan");
        (, uint256 makerPrivateKey) = makeAddrAndKey("dan");
        bytes32 takerMsgHash = orderDispatch.getOrderDigest(takerOrder);
        bytes32 makerMsgHash = orderDispatch.getOrderDigest(makerOrder);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            takerPrivateKey,
            takerMsgHash
        );
        bytes memory takerSig = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(makerPrivateKey, makerMsgHash);
        bytes memory makerSig = abi.encodePacked(r, s, v);
        assertEq(takerSig.length, 65);
        assertEq(makerSig.length, 65);
        constructMatchOrderPayload(takerSig, makerSig);
        vm.expectRevert(bytes4(keccak256("SignatureInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Match_Order_Sig_Bad_Taker_Order() public {
        (, uint256 takerPrivateKey) = makeAddrAndKey("alice");
        (, uint256 makerPrivateKey) = makeAddrAndKey("dan");
        bytes32 takerMsgHash = orderDispatch.getOrderDigest(takerOrder);
        bytes32 makerMsgHash = orderDispatch.getOrderDigest(makerOrder);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            takerPrivateKey,
            takerMsgHash
        );
        bytes memory takerSig = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(makerPrivateKey, makerMsgHash);
        bytes memory makerSig = abi.encodePacked(r, s, v);
        assertEq(takerSig.length, 65);
        assertEq(makerSig.length, 65);
        constructMatchOrderPayload(takerSig, makerSig);
        vm.expectRevert(bytes4(keccak256("SignatureInvalid()")));
        orderDispatch.ingresso(transaction);
    }

    function test_Fail_Order_Parser_Overflow() public {
        (bytes memory signatori, ) = makeOrderSig(takerOrder, "alice");
        bytes memory encodedOrder = abi.encodePacked(
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
            signatori,
            takerOrder.subAccountId
        );
        vm.expectRevert(bytes4(keccak256("OrderByteLengthInvalid()")));
        Parser.parseOrderBytes(encodedOrder, false);
    }

    function test_Happy_Set_Tx_Fee() public {
        vm.expectEmit(address(orderDispatch));
        emit Events.TxFeeChanged(69, 1e18);
        orderDispatch.setTxFees(69, 1e18);
        assertEq(orderDispatch.txFees(69), 1e18);
    }

    function test_Fail_Set_Tx_Fee_unauth() public {
        vm.startPrank({msgSender: users.hackerman});
        vm.expectRevert("UNAUTHORIZED");
        orderDispatch.setTxFees(0, 69e18);
    }
}
