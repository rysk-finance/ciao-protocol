// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

/// @notice Abstract contract containing all the events emitted by the protocol.
abstract contract Types {
    struct Users {
        // Default admin
        address payable gov;
        // Impartial user.
        address payable alice;
        // Second user
        address payable dan;
        // liquidator user
        address payable larry;
        // Malicious user.
        address payable hackerman;
        // Keeper
        address payable keeper;
        // Operator
        address payable operator;
        // Recipient
        address payable recipient;
        // insurance fund
        address payable insurance;
    }

    struct SpotBalanceDetailsTemp {
        address longAccount;
        int256 longAccountBaseBalanceBefore;
        int256 longAccountQuoteBalanceBefore;
        int256 longAccountBaseBalanceAfter;
        int256 longAccountQuoteBalanceAfter;
        address shortAccount;
        int256 shortAccountBaseBalanceBefore;
        int256 shortAccountQuoteBalanceBefore;
        int256 shortAccountBaseBalanceAfter;
        int256 shortAccountQuoteBalanceAfter;
        address feeRecipient;
        int256 feeRecipientBaseBalanceBefore;
        int256 feeRecipientQuoteBalanceBefore;
        int256 feeRecipientBaseBalanceAfter;
        int256 feeRecipientQuoteBalanceAfter;
        address baseAsset;
        address quoteAsset;
        int256 sequencerFee;
    }

    struct PerpBalanceDetailsTemp {
        address taker;
        int256 takerQuoteBalanceBefore;
        int256 takerQuoteBalanceAfter;
        address maker;
        int256 makerQuoteBalanceBefore;
        int256 makerQuoteBalanceAfter;
        address feeRecipient;
        int256 feeRecipientQuoteBalanceBefore;
        int256 feeRecipientQuoteBalanceAfter;
        address quoteAsset;
    }
}
