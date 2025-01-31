// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.19;

import "lib/solmate/src/tokens/ERC20.sol";
import "lib/solmate/src/utils/SafeTransferLib.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";

import "./interfaces/Events.sol";
import "./interfaces/Errors.sol";
import "./interfaces/Structs.sol";
import "./interfaces/IAddressManifest.sol";

import "./libraries/Commons.sol";
import "./libraries/BasicMath.sol";
import "./libraries/EnumerableSet.sol";
import "./libraries/AccessControl.sol";

//    _______
//   / ____(_)___ _____
//  / /   / / __ `/ __ \
// / /___/ / /_/ / /_/ /
// \____/_/\__,_/\____/
/////////////////////////

/// @notice Contract acting as the margin account for a Ciao trader.
///         Accounts will send collateral to this contract to satisfy
///         margin requirements of their existing positions.
///         Mk 0.0.0

contract Ciao is ReentrancyGuardUpgradeable, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    // Governance State
    //////////////////////////////////////

    /// @notice base collateral address
    address public coreCollateralAddress;
    /// @notice fee recipient for receiving all fees, can withdraw like any other user to harvest fees
    address public feeRecipient;
    /// @notice address for receiving all insurance contributions
    address public insurance;
    /// @notice boolean for defining whether a public user can call the deposit or request withdrawal function directly
    ///         or if the call must go through the orderdispatch/off-chain system
    bool public requiresDispatchCall;

    // Dynamic State
    //////////////////////////////////////

    /// @notice Enumerable set for a subAccount
    mapping(address => EnumerableSet.AddressSet) private subAccountAssets;
    /// @notice balances of collateral assets per subAccount subAccount=>asset=>quantity
    mapping(address => mapping(address => uint256)) public balances;
    /// @notice negative balance of base collateral asset per subAccount
    mapping(address => uint256) public coreCollateralDebt;
    /// @notice min deposit amount for a spot asset
    mapping(address => uint256) public minDepositAmount;
    /// @notice mapping of subAccount to asset to WithdrawalReceipt
    mapping(address => mapping(address => Structs.WithdrawalReceipt)) public withdrawalReceipts;
    /// @notice mapping of subAccount to number of deposits made
    mapping(address => uint64) public depositCount;
    /// @notice withdrawal fee for each spot asset. Denoted in asset decimals
    mapping(address => uint256) public withdrawalFees;

    function initialize(
        address _addressManifest,
        address _coreCollateralAddress,
        address _feeRecipient,
        address _insurance
    ) external initializer {
        __AccessControl_init(_addressManifest);
        __ReentrancyGuard_init();
        coreCollateralAddress = _coreCollateralAddress;
        feeRecipient = _feeRecipient;
        insurance = _insurance;
        requiresDispatchCall = false;
    }

    // External - Access Controlled
    //////////////////////////////////////

    /// @notice set the variable for whether a certain function calls requires the order dispatch to be the caller
    /// @param _requiresDispatchCall whether the dispatch is the only allowed caller of a function
    function setRequiresDispatchCall(bool _requiresDispatchCall) external {
        _isAdmin();
        requiresDispatchCall = _requiresDispatchCall;
        emit Events.RequiresDispatchCallSet(_requiresDispatchCall);
    }

    function setFeeRecipient(address _feeRecipient) external {
        _isAdmin();
        require(_feeRecipient != address(0));
        feeRecipient = _feeRecipient;
        emit Events.FeeRecipientChanged(_feeRecipient);
    }

    function setInsurance(address _insurance) external {
        _isAdmin();
        require(_insurance != address(0));
        insurance = _insurance;
        emit Events.InsuranceChanged(_insurance);
    }

    function setMinDepositAmount(address _asset, uint256 _minDepositAmount) external {
        _isAdmin();
        minDepositAmount[_asset] = _minDepositAmount;
        emit Events.MinDepositAmountChanged(_asset, _minDepositAmount);
    }

    function setWithdrawalFee(address _asset, uint256 _fee) external {
        _isAdmin();
        withdrawalFees[_asset] = _fee;
        emit Events.WithdrawalFeeChanged(_asset, _fee);
    }

    /// @notice Update balances of a account
    /// @dev Must be called by the OrderDispatch or Liquidation
    /// @param takerSubAccount the subAccount of the account that took liquidity from the book
    /// @param makerSubAccount the subAccount of the account that the taker matched with
    /// @param baseQuantity quantity of the quote asset to change
    /// @param quoteQuantity quantity of the base asset to change
    /// @param productId uint32 id of the product being traded
    /// @param isTakerBuy is the takerSubAccount the buyer or seller (i.e. are they gaining or losing baseAsset)
    /// @param takerFee the fee being charged to takerSubAccount (not incl. sequencer fee)
    /// @param makerFee the fee being charged to makerSubAccount
    /// @param sequencerFee the fixed fee charged to the maker. denominated in core collateral
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
    ) external {
        // check that the caller is the order dispatch or liquidation
        _isBalanceUpdater();
        // get the baseAsset and quoteAsset
        Structs.Product memory product = _productCatalogue().products(productId);
        if (isTakerBuy) {
            _updateBalance(
                takerSubAccount, makerSubAccount, product.baseAsset, baseQuantity, takerFee
            );
            _updateBalance(
                makerSubAccount, takerSubAccount, product.quoteAsset, quoteQuantity, makerFee
            );
        } else {
            _updateBalance(
                makerSubAccount, takerSubAccount, product.baseAsset, baseQuantity, makerFee
            );
            _updateBalance(
                takerSubAccount, makerSubAccount, product.quoteAsset, quoteQuantity, takerFee
            );
        }
        if (sequencerFee > 0) {
            _settleCoreCollateral(takerSubAccount, -int256(sequencerFee));
            _settleCoreCollateral(feeRecipient, int256(sequencerFee));
        }
    }

    /// @notice Settles the pnl of any derivative positions in the base collateral asset
    /// Allows for negative balance, so long as the subAccount has sufficient margin health in other assets
    /// @dev Must be called by the OrderDispatch or Liquidation
    /// @param subAccount the subAccount of the account to update
    /// @param coreCollateralQuantity the value to add or subtract to the subAccount's balance
    function settleCoreCollateral(address subAccount, int256 coreCollateralQuantity)
        external
        nonReentrant
    {
        // check that the caller is the order dispatch or liquidation
        _isBalanceUpdater();
        subAccountAssets[subAccount].add(coreCollateralAddress);
        if (coreCollateralQuantity == 0) return;
        _settleCoreCollateral(subAccount, coreCollateralQuantity);
    }

    /// @notice Increments the fee value of the fee recipient in whatever asset is appropriate
    /// @dev Must be called by the OrderDispatch or Liquidation
    /// @param asset the asset to charge the fee on
    /// @param fee the quantity of fee in terms of the asset
    /// @param recipient the address to send fee to
    function incrementFee(address asset, uint256 fee, address recipient) external nonReentrant {
        // check that the caller is the order dispatch or liquidation
        _isBalanceUpdater();
        subAccountAssets[recipient].add(asset);
        if (asset == coreCollateralAddress) {
            _settleCoreCollateral(recipient, int256(fee));
        } else {
            _changeBalance(recipient, asset, int256(fee));
        }
    }

    /// @notice allows owner to deposit spot assets on behalf of a subAccount
    /// @dev Accessable by Owner
    /// @param account subAccount to change
    /// @param subAccountId the subAccount to deposit to
    /// @param quantity the amount to increase the balance by
    /// @param asset the spot asset balance to increase
    function donate(address account, uint8 subAccountId, uint256 quantity, address asset)
        external
    {
        _isOwner();
        if (quantity == 0) {
            revert Errors.DepositQuantityInvalid();
        }
        if (_productCatalogue().baseAssetQuoteAssetSpotIds(asset, coreCollateralAddress) == 0) {
            revert Errors.ProductInvalid();
        }

        address subAccount = Commons.getSubAccount(account, subAccountId);
        // Add the address to the subAccount's EnumerableSet
        subAccountAssets[subAccount].add(asset);
        // Store the balance update, we need to first check for any coreCollateralDebt
        uint256 quantityE18 = Commons.convertToE18(quantity, ERC20(asset).decimals());
        // if the asset is base collateral then handle with usdc debt, otherwise handle normally
        if (coreCollateralAddress == asset) {
            _settleCoreCollateral(subAccount, int256(quantityE18));
        } else {
            _changeBalance(subAccount, asset, int256(quantityE18));
        }
        // Pull resources from owner to this contract
        SafeTransferLib.safeTransferFrom(
            ERC20(asset), addressManifest.owner(), address(this), quantity
        );
        depositCount[subAccount]++;

        // emit event that mocks the user depositing the asset themself
        emit Events.Deposit(account, subAccountId, asset, quantity);
    }

    // External - Public
    //////////////////////////////////////

    /// @notice Deposit new assets into margin account represented as a subAccount
    /// @dev Requires approval from `msg.sender`
    /// @param account the account to take funds from for the deposit
    /// @param subAccountId the subAccount to be used for the deposit
    /// @param quantity quantity of the asset to deposit
    /// @param asset address representing the product being deposited
    function deposit(address account, uint8 subAccountId, uint256 quantity, address asset)
        external
        nonReentrant
    {
        if (requiresDispatchCall) {
            if (msg.sender != _orderDispatch()) revert Errors.SenderInvalid();
        } else {
            if (msg.sender != account && msg.sender != _orderDispatch()) {
                revert Errors.SenderInvalid();
            }
        }
        if (quantity == 0 || quantity < minDepositAmount[asset]) {
            revert Errors.DepositQuantityInvalid();
        }
        if (_productCatalogue().baseAssetQuoteAssetSpotIds(asset, coreCollateralAddress) == 0) {
            revert Errors.ProductInvalid();
        }
        address subAccount = Commons.getSubAccount(account, subAccountId);
        // Add the address to the subAccount's EnumerableSet
        subAccountAssets[subAccount].add(asset);
        // Store the balance update, we need to first check for any coreCollateralDebt
        uint256 quantityE18 = Commons.convertToE18(quantity, ERC20(asset).decimals());
        // if the asset is base collateral then handle with usdc debt, otherwise handle normally
        if (coreCollateralAddress == asset) {
            _settleCoreCollateral(subAccount, int256(quantityE18));
        } else {
            _changeBalance(subAccount, asset, int256(quantityE18));
        }
        // Pull resources from sender to this contract
        SafeTransferLib.safeTransferFrom(ERC20(asset), account, address(this), quantity);
        depositCount[subAccount]++;

        emit Events.Deposit(account, subAccountId, asset, quantity);
    }

    /// @notice Request to withdraw assets from the margin account represented as a subAccount
    ///         This records a request for withdrawal, based on this request the ciao engine will
    ///         process the request to withdraw if it is safe to do so.
    /// @param subAccountId the subAccount to be used for the withdraw
    /// @param quantity quantity of the asset to withdraw. Denoted in `asset` decimals
    /// @param asset address representing the asset to be traded
    function requestWithdrawal(uint8 subAccountId, uint256 quantity, address asset)
        external
        nonReentrant
    {
        if (requiresDispatchCall) {
            revert Errors.SenderInvalid();
        }
        // check their balance against the quantity being requested for withdrawal
        address subAccount = Commons.getSubAccount(msg.sender, subAccountId);
        uint256 quantityE18 = Commons.convertToE18(quantity, ERC20(asset).decimals());
        if (quantity <= withdrawalFees[asset] || quantityE18 > balances[subAccount][asset]) {
            revert Errors.WithdrawQuantityInvalid();
        }
        // record the withdrawal receipt
        withdrawalReceipts[subAccount][asset] =
            Structs.WithdrawalReceipt(quantityE18, block.timestamp);
        // emit an event to show the withdrawal was requested
        emit Events.RequestWithdrawal(msg.sender, subAccountId, asset, quantity);
    }

    /// @notice Withdraw assets from margin account represented as a subAccount.
    ///         This executes a balance transfer between the protocols and the withdrawer,
    ///         this will happen in one of three scenarios.
    ///         1. The user submitted a request for withdrawal and the off-chain engine processed it
    ///         2. The user submits a withdrawal to the off-chain system directly and the off-chain engine
    ///            processes it
    /// @param account the account to send the withdrawal to
    /// @param subAccountId the subAccount to be used for the withdraw
    /// @param quantity quantity of the asset to withdraw. Denoted in `asset` decimals
    /// @param asset address representing the asset to be traded
    function executeWithdrawal(address account, uint8 subAccountId, uint256 quantity, address asset)
        external
        nonReentrant
    {
        address subAccount = Commons.getSubAccount(account, subAccountId);
        uint256 quantityE18 = Commons.convertToE18(quantity, ERC20(asset).decimals());
        if (msg.sender != _orderDispatch()) revert Errors.SenderInvalid();
        if (quantity <= withdrawalFees[asset] || quantityE18 > balances[subAccount][asset]) {
            revert Errors.WithdrawQuantityInvalid();
        }
        // if the caller is the orderDispatch then execute the withdrawal normally
        _withdraw(account, subAccount, quantityE18, asset);
        emit Events.ExecuteWithdrawal(account, subAccountId, asset, quantity);
    }

    // Basic Getters
    //////////////////////////////////////

    function isAssetInSubAccountAssetSet(address subAccount, address _a)
        external
        view
        returns (bool)
    {
        return subAccountAssets[subAccount].contains(_a);
    }

    function assetAtIndexInSubAccountAssetSet(address subAccount, uint256 _i)
        external
        view
        returns (address)
    {
        return subAccountAssets[subAccount].at(_i);
    }

    function subAccountAssetSetLength(address subAccount) external view returns (uint256) {
        return subAccountAssets[subAccount].length();
    }

    function getSubAccountAssets(address subAccount) external view returns (address[] memory) {
        return subAccountAssets[subAccount].values();
    }

    // Internals
    //////////////////////////////////////

    function _withdraw(address account, address subAccount, uint256 quantity, address asset)
        internal
    {
        // The account has the full quantity withdrawn from balance
        _changeBalance(subAccount, asset, -int256(quantity));
        // if the balance becomes zero then remove the asset from the set
        if (balances[subAccount][asset] == 0 && asset != coreCollateralAddress) {
            subAccountAssets[subAccount].remove(asset);
        }
        uint256 quantityRealDecimals = Commons.convertFromE18(quantity, ERC20(asset).decimals());
        // clear the withdrawal receipt
        delete withdrawalReceipts[subAccount][asset];
        uint256 fee = withdrawalFees[asset];
        // increment fee recipient balance by withdrawal fee
        _changeBalance(
            feeRecipient, asset, int256(Commons.convertToE18(fee, ERC20(asset).decimals()))
        );
        // Transfer asset to sender minus withdrawal fee
        SafeTransferLib.safeTransfer(ERC20(asset), account, quantityRealDecimals - fee);
    }

    /// @dev this function should be used for any non-core collateral assets
    function _changeBalance(address subAccount, address asset, int256 change) internal {
        int256 balanceBefore = int256(balances[subAccount][asset]);
        if (change > 0) {
            balances[subAccount][asset] += uint256(change);
        } else {
            balances[subAccount][asset] -= uint256(-change);
        }
        emit Events.BalanceChanged(
            subAccount, asset, balanceBefore, int256(balances[subAccount][asset])
        );
    }

    function _updateBalance(
        address incAccount,
        address decAccount,
        address asset,
        uint256 quantity,
        uint256 incAccountFee
    ) internal {
        // Add the address to the subAccount's EnumerableSet
        subAccountAssets[incAccount].add(asset);
        // if the asset is base collateral then handle for usdc debt, otherwise handle normally
        // only handle for the incremental account as we dont want this function to allow for the
        // accrual of debt
        if (coreCollateralAddress == asset) {
            _settleCoreCollateral(incAccount, int256(quantity) - int256(incAccountFee));
        } else {
            _changeBalance(incAccount, asset, int256(quantity) - int256(incAccountFee));
        }
        // update the balance of the fee recipient with the fee
        subAccountAssets[feeRecipient].add(asset);
        _changeBalance(feeRecipient, asset, int256(incAccountFee));
        // handle the decremented account
        if (balances[decAccount][asset] >= quantity) {
            _changeBalance(decAccount, asset, -int256(quantity));
            // if the balance of the account hits 0 then remove the asset from the accounts list
            if (balances[decAccount][asset] == 0 && asset != coreCollateralAddress) {
                subAccountAssets[decAccount].remove(asset);
            }
            // decAccount has insufficient funds
        } else {
            revert Errors.BalanceInsufficient();
        }
    }

    function _settleCoreCollateral(address subAccount, int256 coreCollateralQuantity) internal {
        int256 balanceBefore = int256(balances[subAccount][coreCollateralAddress])
            - int256(coreCollateralDebt[subAccount]);
        if (coreCollateralQuantity >= 0) {
            uint256 absoluteBCA = uint256(coreCollateralQuantity);
            uint256 existingDebt = coreCollateralDebt[subAccount];
            uint256 debit = BasicMath.min(existingDebt, absoluteBCA);
            coreCollateralDebt[subAccount] -= debit;
            absoluteBCA -= debit;
            balances[subAccount][coreCollateralAddress] += absoluteBCA;
        } else {
            uint256 absoluteBCA = uint256(-coreCollateralQuantity);
            uint256 existingBalance = balances[subAccount][coreCollateralAddress];
            uint256 credit = BasicMath.min(existingBalance, absoluteBCA);
            balances[subAccount][coreCollateralAddress] -= credit;
            absoluteBCA -= credit;
            coreCollateralDebt[subAccount] += absoluteBCA;
        }
        emit Events.BalanceChanged(
            subAccount, coreCollateralAddress, balanceBefore, balanceBefore + coreCollateralQuantity
        );
    }
}
