// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.8.19;

import "../interfaces/Errors.sol";
import "../interfaces/Structs.sol";

library Parser {
    /// @notice function to convert an order that has been packed to bytes into an Order struct
    /// @dev uses assembly
    /// @param packedEncodedOrder the packed Order that is to be decompiled to a Structs.Order struct
    /// @param noSig if a sig needs to be extracted from the payload
    function parseOrderBytes(bytes memory packedEncodedOrder, bool noSig)
        public
        pure
        returns (Structs.Order memory, bytes memory)
    {
        address account;
        uint8 subAccountId;
        uint32 productId;
        uint8 isBuy;
        uint8 orderType;
        uint8 timeInForce;
        uint64 expiration;
        uint128 price;
        uint128 quantity;
        uint64 nonce;
        bytes memory sig = new bytes(65);
        if (noSig) {
            if (packedEncodedOrder.length != 76) {
                revert Errors.OrderByteLengthInvalid();
            }
        } else {
            if (packedEncodedOrder.length != 141) {
                revert Errors.OrderByteLengthInvalid();
            }
            /// @solidity memory-safe-assembly
            assembly {
                mstore(add(sig, 32), mload(add(packedEncodedOrder, 108)))
                mstore(add(sig, 64), mload(add(packedEncodedOrder, 140)))
                mstore(add(sig, 65), mload(add(packedEncodedOrder, 141)))
            }
        }
        /// @solidity memory-safe-assembly
        assembly {
            account := mload(add(packedEncodedOrder, 20))
            subAccountId := mload(add(packedEncodedOrder, 21))
            productId := mload(add(packedEncodedOrder, 25))
            isBuy := mload(add(packedEncodedOrder, 26))
            orderType := mload(add(packedEncodedOrder, 27))
            timeInForce := mload(add(packedEncodedOrder, 28))
            expiration := mload(add(packedEncodedOrder, 36))
            price := mload(add(packedEncodedOrder, 52))
            quantity := mload(add(packedEncodedOrder, 68))
            nonce := mload(add(packedEncodedOrder, 76))
        }
        return (
            Structs.Order(
                account,
                subAccountId,
                productId,
                isBuy == 1,
                orderType,
                timeInForce,
                expiration,
                price,
                quantity,
                nonce
            ),
            sig
        );
    }

    /// @notice function to convert a signer approval that has been packed to bytes into an ApproveSigner struct
    /// @dev uses assembly
    /// @param packedEncodedApprovedSigner the packed ApproveSigner that is to be decompiled to a Structs.ApproveSigner struct
    function parseApprovedSignerBytes(bytes memory packedEncodedApprovedSigner)
        public
        pure
        returns (Structs.ApproveSigner memory, bytes memory)
    {
        address account;
        uint8 subAccountId;
        address approvedSigner;
        uint8 isApproved;
        uint64 nonce;
        bytes memory sig = new bytes(65);
        if (packedEncodedApprovedSigner.length != 115) {
            revert Errors.OrderByteLengthInvalid();
        }
        /// @solidity memory-safe-assembly
        assembly {
            account := mload(add(packedEncodedApprovedSigner, 20))
            subAccountId := mload(add(packedEncodedApprovedSigner, 21))
            approvedSigner := mload(add(packedEncodedApprovedSigner, 41))
            isApproved := mload(add(packedEncodedApprovedSigner, 42))
            nonce := mload(add(packedEncodedApprovedSigner, 50))
            mstore(add(sig, 32), mload(add(packedEncodedApprovedSigner, 82)))
            mstore(add(sig, 64), mload(add(packedEncodedApprovedSigner, 114)))
            mstore(add(sig, 65), mload(add(packedEncodedApprovedSigner, 115)))
        }
        return (
            Structs.ApproveSigner(account, subAccountId, approvedSigner, isApproved == 1, nonce),
            sig
        );
    }

    /// @notice function to convert a deposit that has been packed to bytes into a Deposit struct
    /// @dev uses assembly
    /// @param packedEncodedDeposit the packed Deposit that is to be decompiled to a Structs.Deposit struct
    function parseDepositBytes(bytes memory packedEncodedDeposit)
        public
        pure
        returns (Structs.Deposit memory, bytes memory)
    {
        address account;
        uint8 subAccountId;
        address asset;
        uint256 quantity;
        uint64 nonce;
        bytes memory sig = new bytes(65);
        if (packedEncodedDeposit.length != 146) {
            revert Errors.OrderByteLengthInvalid();
        }
        /// @solidity memory-safe-assembly
        assembly {
            account := mload(add(packedEncodedDeposit, 20))
            subAccountId := mload(add(packedEncodedDeposit, 21))
            asset := mload(add(packedEncodedDeposit, 41))
            quantity := mload(add(packedEncodedDeposit, 73))
            nonce := mload(add(packedEncodedDeposit, 81))
            mstore(add(sig, 32), mload(add(packedEncodedDeposit, 113)))
            mstore(add(sig, 64), mload(add(packedEncodedDeposit, 145)))
            mstore(add(sig, 65), mload(add(packedEncodedDeposit, 146)))
        }
        return (Structs.Deposit(account, subAccountId, asset, quantity, nonce), sig);
    }

    /// @notice function to convert a withdraw that has been packed to bytes into a Withdraw struct
    /// @dev uses assembly
    /// @param packedEncodedWithdraw the packed Withdraw that is to be decompiled to a Structs.Withdraw struct
    function parseWithdrawBytes(bytes memory packedEncodedWithdraw)
        public
        pure
        returns (Structs.Withdraw memory, bytes memory)
    {
        address account;
        uint8 subAccountId;
        address asset;
        uint128 quantity;
        uint64 nonce;
        bytes memory sig = new bytes(65);
        if (packedEncodedWithdraw.length != 130) {
            revert Errors.OrderByteLengthInvalid();
        }
        /// @solidity memory-safe-assembly
        assembly {
            account := mload(add(packedEncodedWithdraw, 20))
            subAccountId := mload(add(packedEncodedWithdraw, 21))
            asset := mload(add(packedEncodedWithdraw, 41))
            quantity := mload(add(packedEncodedWithdraw, 57))
            nonce := mload(add(packedEncodedWithdraw, 65))
            mstore(add(sig, 32), mload(add(packedEncodedWithdraw, 97)))
            mstore(add(sig, 64), mload(add(packedEncodedWithdraw, 129)))
            mstore(add(sig, 65), mload(add(packedEncodedWithdraw, 130)))
        }
        return (Structs.Withdraw(account, subAccountId, asset, quantity, nonce), sig);
    }

    /// @notice function to convert a liquidation that has been packed to bytes into a LiquidateSubAccount struct
    /// @dev uses assembly
    /// @param packedEncodedLiquidate the packed Liquidate that is to be decompiled to a Structs.LiquidateSubAccount struct
    function parseLiquidateBytes(bytes memory packedEncodedLiquidate)
        public
        pure
        returns (Structs.LiquidateSubAccount memory, bytes memory, uint64)
    {
        address liquidator;
        uint8 liquidatorSubAccountId;
        address liquidatee;
        uint8 liquidateeSubAccountId;
        uint8 liquidationMode;
        uint32 productId;
        uint128 quantity;
        uint64 nonce;
        uint64 offchainDepositCount;
        bytes memory sig = new bytes(65);
        if (packedEncodedLiquidate.length != 144) {
            revert Errors.OrderByteLengthInvalid();
        }
        /// @solidity memory-safe-assembly
        assembly {
            liquidator := mload(add(packedEncodedLiquidate, 20))
            liquidatorSubAccountId := mload(add(packedEncodedLiquidate, 21))
            liquidatee := mload(add(packedEncodedLiquidate, 41))
            liquidateeSubAccountId := mload(add(packedEncodedLiquidate, 42))
            liquidationMode := mload(add(packedEncodedLiquidate, 43))
            productId := mload(add(packedEncodedLiquidate, 47))
            quantity := mload(add(packedEncodedLiquidate, 63))
            nonce := mload(add(packedEncodedLiquidate, 71))
            mstore(add(sig, 32), mload(add(packedEncodedLiquidate, 103)))
            mstore(add(sig, 64), mload(add(packedEncodedLiquidate, 135)))
            mstore(add(sig, 65), mload(add(packedEncodedLiquidate, 136)))
            offchainDepositCount := mload(add(packedEncodedLiquidate, 144))
        }
        return (
            Structs.LiquidateSubAccount(
                liquidator,
                liquidatorSubAccountId,
                liquidatee,
                liquidateeSubAccountId,
                liquidationMode,
                productId,
                quantity,
                nonce
            ),
            sig,
            offchainDepositCount
        );
    }
}
