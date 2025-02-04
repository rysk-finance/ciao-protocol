// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/contracts/libraries/Commons.sol";
import {Events} from "src/contracts/interfaces/Events.sol";
import {IProductCatalogue} from "src/contracts/interfaces/IProductCatalogue.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "src/contracts/libraries/BasicMath.sol";
import {Base_Test} from "../../Base.t.sol";
import {Structs} from "src/contracts/interfaces/Structs.sol";
import "forge-std/console.sol";

contract OrderDispatchBase is Base_Test {
    using MessageHashUtils for bytes32;

    Structs.Order public takerOrder;
    bytes public takerOrderBytes;
    Structs.Order public makerOrder;

    Structs.Order[] public makerOrderArr;
    bytes[] public makerOrderArrBytes;
    bytes[] public makerSigs;
    bytes[] public transaction;

    Structs.ApproveSigner public approval;
    bytes public approvalBytes;

    Structs.LiquidateSubAccount public liqui;

    function setUp() public virtual override {
        Base_Test.setUp();
    }

    function constructMatchOrderPayload() public returns (bytes32, bytes32) {
        if (makerOrderArr.length > 0) {
            makerOrderArr.pop();
            makerOrderArrBytes.pop();
            makerSigs.pop();
            transaction.pop();
        }
        if (transaction.length > 0) {
            transaction.pop();
        }
        (bytes memory takerSig, bytes32 takerHash) = makeOrderSig(
            takerOrder,
            "dan"
        );
        (bytes memory makerSig, bytes32 makerHash) = makeOrderSig(
            makerOrder,
            "alice"
        );
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
        return (takerHash, makerHash);
    }

    function appendMatchOrderPayload() public returns (bytes32, bytes32) {
        if (makerOrderArr.length > 0) {
            makerOrderArr.pop();
            makerOrderArrBytes.pop();
            makerSigs.pop();
        }
        makerOrderArr.push(makerOrder);
        (bytes memory takerSig, bytes32 takerHash) = makeOrderSig(
            takerOrder,
            "dan"
        );
        (bytes memory makerSig, bytes32 makerHash) = makeOrderSig(
            makerOrder,
            "alice"
        );
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
        return (takerHash, makerHash);
    }

    function appendMakerOrderPayload()
        public
        returns (bytes memory, bytes32, bytes32)
    {
        if (transaction.length > 0) {
            transaction.pop();
        }
        makerOrderArr.push(makerOrder);
        (bytes memory takerSig, bytes32 takerHash) = makeOrderSig(
            takerOrder,
            "dan"
        );
        (bytes memory makerSig, bytes32 makerHash) = makeOrderSig(
            makerOrder,
            "alice"
        );
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
        return (
            abi.encode(
                Structs.MatchedOrder(takerOrderBytes, makerOrderArrBytes)
            ),
            takerHash,
            makerHash
        );
    }

    function constructApproveSignerPayload(
        string memory user,
        uint64 nonce
    ) public {
        if (transaction.length > 0) {
            transaction.pop();
        }
        approval.nonce = nonce;
        (bytes memory sig, ) = makeApprovedSignerSig(approval, user);
        approvalBytes = abi.encodePacked(
            approval.account,
            approval.subAccountId,
            approval.approvedSigner,
            approval.isApproved,
            approval.nonce,
            sig
        );
        transaction.push(abi.encodePacked(uint8(3), approvalBytes));
    }

    function appendApproveSignerPayload(
        string memory user,
        uint64 nonce
    ) public {
        approval.nonce = nonce;
        (bytes memory sig, ) = makeApprovedSignerSig(approval, user);
        approvalBytes = abi.encodePacked(
            approval.account,
            approval.subAccountId,
            approval.approvedSigner,
            approval.isApproved,
            approval.nonce,
            sig
        );

        transaction.push(abi.encodePacked(uint8(3), approvalBytes));
    }

    function constructDepositPayload(
        address u,
        uint8 said,
        uint256 quantity,
        address asset,
        string memory userString
    ) public {
        if (transaction.length > 0) {
            transaction.pop();
        }
        (bytes memory sig, ) = makeDepositSig(
            Structs.Deposit(u, said, asset, quantity, uint64(1)),
            userString
        );
        bytes memory depositBytes = abi.encodePacked(
            u,
            said,
            asset,
            quantity,
            uint64(1),
            sig
        );
        transaction.push(abi.encodePacked(uint8(2), depositBytes));
    }

    function constructWithdrawPayload(
        address u,
        uint8 said,
        address asset,
        uint256 quantity,
        string memory userString
    ) public {
        if (transaction.length > 0) {
            transaction.pop();
        }
        (bytes memory sig, ) = makeWithdrawSig(
            Structs.Withdraw(u, said, asset, uint128(quantity), uint64(1)),
            userString
        );

        bytes memory withdrawBytes = abi.encodePacked(
            u,
            said,
            asset,
            uint128(quantity),
            uint64(1),
            sig
        );
        transaction.push(abi.encodePacked(uint8(4), withdrawBytes));
    }

    function constructForceSwapPayload(
        uint8 coreCollatOrLiq,
        uint64 offChainDepositCount
    ) public returns (bytes32, bytes32) {
        if (makerOrderArr.length > 0) {
            makerOrderArr.pop();
            makerOrderArrBytes.pop();
            makerSigs.pop();
            transaction.pop();
        }
        (, bytes32 takerHash) = makeOrderSig(takerOrder, "dan");
        (bytes memory makerSig, bytes32 makerHash) = makeOrderSig(
            makerOrder,
            "alice"
        );
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
            takerOrder.nonce
        );
        makerSigs.push(makerSig);
        transaction.push(
            abi.encodePacked(
                uint8(5),
                uint8(coreCollatOrLiq),
                uint64(offChainDepositCount),
                abi.encode(
                    Structs.MatchedOrder(takerOrderBytes, makerOrderArrBytes)
                )
            )
        );
        return (takerHash, makerHash);
    }

    function appendForceSwapPayload(
        uint8 collatOrLiq,
        uint64 offChainDepositCount
    ) public returns (bytes32, bytes32) {
        if (makerOrderArr.length > 0) {
            makerOrderArr.pop();
            makerOrderArrBytes.pop();
            makerSigs.pop();
        }
        makerOrderArr.push(makerOrder);
        (, bytes32 takerHash) = makeOrderSig(takerOrder, "dan");
        (bytes memory makerSig, bytes32 makerHash) = makeOrderSig(
            makerOrder,
            "alice"
        );
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
            takerOrder.nonce
        );
        makerSigs.push(makerSig);
        transaction.push(
            abi.encodePacked(
                uint8(5),
                uint8(collatOrLiq),
                uint64(offChainDepositCount),
                abi.encode(
                    Structs.MatchedOrder(takerOrderBytes, makerOrderArrBytes)
                )
            )
        );
        return (takerHash, makerHash);
    }

    function appendForceSwapMakerPayload(
        uint8 collatOrLiq,
        uint64 offChainDepositCount
    ) public returns (bytes32, bytes32) {
        if (transaction.length > 0) {
            transaction.pop();
        }
        makerOrderArr.push(makerOrder);
        (, bytes32 takerHash) = makeOrderSig(takerOrder, "dan");
        (bytes memory makerSig, bytes32 makerHash) = makeOrderSig(
            makerOrder,
            "alice"
        );
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
            takerOrder.nonce
        );
        makerSigs.push(makerSig);
        transaction.push(
            abi.encodePacked(
                uint8(5),
                uint8(collatOrLiq),
                uint64(offChainDepositCount),
                abi.encode(
                    Structs.MatchedOrder(takerOrderBytes, makerOrderArrBytes)
                )
            )
        );
        return (takerHash, makerHash);
    }

    function constructLiquidatePayload(uint64 offChainDepositCount) public {
        if (transaction.length > 0) {
            transaction.pop();
        }
        (bytes memory sig, ) = makeLiquidateSig(liqui, "alice");

        bytes memory liquidateBytes = abi.encodePacked(
            uint8(6),
            abi.encodePacked(
                liqui.liquidator,
                liqui.liquidatorSubAccountId,
                liqui.liquidatee,
                liqui.liquidateeSubAccountId,
                liqui.liquidationMode,
                liqui.productId,
                liqui.quantity,
                liqui.nonce,
                sig
            ),
            offChainDepositCount
        );
        transaction.push(liquidateBytes);
    }
}
