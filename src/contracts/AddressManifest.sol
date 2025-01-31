pragma solidity >=0.8.19;

import "lib/solmate/src/auth/Owned.sol";

import "./libraries/Commons.sol";

import "./interfaces/Events.sol";
import "./interfaces/Errors.sol";

//     ___       __    __                    __  ___            _ ____          __
//    /   | ____/ /___/ /_______  __________/  |/  /___ _____  (_) __/__  _____/ /_
//   / /| |/ __  / __  / ___/ _ \/ ___/ ___/ /|_/ / __ `/ __ \/ / /_/ _ \/ ___/ __/
//  / ___ / /_/ / /_/ / /  /  __(__  |__  ) /  / / /_/ / / / / / __/  __(__  ) /_
// /_/  |_\__,_/\__,_/_/   \___/____/____/_/  /_/\__,_/_/ /_/_/_/  \___/____/\__/
////////////////////////////////////////////////////////////////////////////////////

/// @notice Contract for storing all protocol addresses and access rights
///         (used as ground truth for all protocols)
///         Mk 0.0.0
contract AddressManifest is Owned {
    // Governance Variables
    //////////////////////////////////////

    // address manifest storage
    /// At genesis the manifest will be layed out as follows:
    /// 0: N/A
    /// 1: Ciao
    /// 2: Furnace
    /// 3: ProductCatalogue
    /// 4: OrderDispatch
    /// 5: Liquidation
    /// 6: SpotCrucible
    /// 7: PerpCrucible
    mapping(uint256 => address) public manifest;
    // operator, responsible for calling the order dispatch
    address public operator;
    // admin, responsible for calling access controlled functionality elsewhere
    address public admin;
    // boolean for defining whether a public user can call the approve signer function directly
    // or if the call must go through the orderdispatch/off-chain system
    bool public requiresDispatchCall = true;

    // User controlled variables
    //////////////////////////////////////

    // approved signers for a given subaccount
    mapping(address => mapping(address => bool)) public approvedSigners;
    // has the given digest already been used before
    mapping(bytes32 => bool) public hasDigestBeenUsed;

    constructor() Owned(msg.sender) {}

    // Setters
    //////////////////////////////////////

    /// @notice update an address in the manifest, the schema of ids is shown above
    /// @param id the id of the address in the manifest to update
    /// @param _newAddress the address to update on the given id in the manifest
    function updateAddressInManifest(uint256 id, address _newAddress) external onlyOwner {
        manifest[id] = _newAddress;
        emit Events.ManifestUpdated(id, _newAddress);
    }

    /// @notice update the operator, responsible for routing actions from the off-chain engine
    /// @param _operator the address of the new operator
    function setOperator(address _operator) external onlyOwner {
        operator = _operator;
        emit Events.OperatorUpdated(_operator);
    }

    /// @notice update the admin, responsible for changing non-breaking gov variables
    /// @param _admin the address of the new admin
    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
        emit Events.AdminUpdated(_admin);
    }

    /// @notice set the variable for whether a certain function calls requires the order dispatch to be the caller
    /// @param _requiresDispatchCall whether the dispatch is the only allowed caller of a function
    function setRequiresDispatchCall(bool _requiresDispatchCall) external onlyOwner {
        requiresDispatchCall = _requiresDispatchCall;
        emit Events.RequiresDispatchCallSet(_requiresDispatchCall);
    }

    // External - Access Controlled
    //////////////////////////////////////

    /// @notice Approve a signer to sign transactions on a user's behalf
    /// @param account the account to change the signer status for
    /// @param subAccountId the id of the sub account to change the signer for
    /// @param approvedSigner the signer to approve as able to sign on behalf of the subAccount
    /// @param isApproved whether to approve the signer or not
    function approveSigner(
        address account,
        uint8 subAccountId,
        address approvedSigner,
        bool isApproved
    ) external {
        if (requiresDispatchCall) {
            if (msg.sender != manifest[4]) revert Errors.SenderInvalid();
        } else {
            if (msg.sender != account && msg.sender != manifest[4]) revert Errors.SenderInvalid();
        }
        address subAccount = Commons.getSubAccount(account, subAccountId);
        approvedSigners[subAccount][approvedSigner] = isApproved;
        emit Events.SignerApprovalUpdated(account, subAccountId, approvedSigner, isApproved);
    }

    /// @notice Mark a digest as having been used to ensure it cant be reused
    /// @param digest the digest to mark as used
    function checkInDigestAsUsed(bytes32 digest) external {
        if (msg.sender != manifest[4]) revert Errors.SenderInvalid();
        if (hasDigestBeenUsed[digest]) revert Errors.DigestedAlready();
        hasDigestBeenUsed[digest] = true;
    }
}
