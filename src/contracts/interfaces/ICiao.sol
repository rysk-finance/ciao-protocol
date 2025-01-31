// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.19;

import "./Structs.sol";

/// @notice Interface for ciao
interface ICiao {
    function deposit(address account, uint8 subAccountId, uint256 quantity, address asset)
        external;

    function executeWithdrawal(address account, uint8 subAccountId, uint256 quantity, address asset)
        external;

    function withdrawalReceipts(address subAccount, address asset)
        external
        view
        returns (Structs.WithdrawalReceipt memory);

    function updateBalance(
        address takerSubAccount,
        address makerSubAccount,
        uint256 baseQuantity,
        uint256 quoteQuantity,
        uint32 productId,
        bool isTakerBuy,
        uint256 takerFee,
        uint256 makerFee,
        uint256 sequencerFee
    ) external;

    function incrementFee(address asset, uint256 feeQuantity, address recipient) external;

    function settleCoreCollateral(address subAccount, int256 quantity) external;

    function getSubAccountAssets(address subAccount) external view returns (address[] memory);

    function balances(address subAccount, address asset) external view returns (uint256);

    function coreCollateralDebt(address subAccount) external view returns (uint256);

    function depositCount(address subAccount) external view returns (uint64);

    function coreCollateralAddress() external view returns (address);

    function feeRecipient() external view returns (address);

    function insurance() external view returns (address);
}
