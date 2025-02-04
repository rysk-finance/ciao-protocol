pragma solidity >=0.8.19;

import "../libraries/AccessControl.sol";
import "../libraries/EnumerableSet.sol";

//    ______                _ __    __
//   / ____/______  _______(_) /_  / /__
//  / /   / ___/ / / / ___/ / __ \/ / _ \
// / /___/ /  / /_/ / /__/ / /_/ / /  __/
// \____/_/   \__,_/\___/_/_.___/_/\___/
//
//////////////////////////////////////////

/// @notice Based contract for crucibles
///         Mk 0.0.0
abstract contract Crucible is AccessControl {
    using EnumerableSet for EnumerableSet.UintSet;

    // Dynamic Variables
    //////////////////////////////////////

    // mapping from subaccount to set of productIds for which a  position is open
    mapping(address => EnumerableSet.UintSet) internal openPositionIds;

    // filled quantity storage
    mapping(bytes32 => uint128) public filledQuantitys;

    function __Crucible_init(address _addressManifest) internal {
        __AccessControl_init(_addressManifest);
    }
    
    // External - Access Controlled
    //////////////////////////////////////

    /// @notice updates the filled quantity for a given trade, this is how much of a trade has been filled
    ///         for a given digest, this digest was used as the message for an EIP712 signature so is a unique
    ///         identifier for a given trade.
    /// @dev only accessible by the order dispatch so by extension the operator
    /// @param takerDigest the digest of the taker's order used in combination with their EIP712 signature
    /// @param makerDigest the digest of the maker's order used in combination with their EIP712 signature
    /// @param filledQuantityIncrease the quantity to increment the total filled quantity by for both users
    function updateFilledQuantity(
        bytes32 takerDigest,
        bytes32 makerDigest,
        uint128 filledQuantityIncrease
    ) external {
        // check that the caller is the order dispatch
        _isOrderDispatch();
        filledQuantitys[takerDigest] += filledQuantityIncrease;
        filledQuantitys[makerDigest] += filledQuantityIncrease;
    }

    // Basic Getters
    //////////////////////////////////////

    function getOpenPositionIds(
        address subAccount
    ) external view returns (uint256[] memory) {
        return openPositionIds[subAccount].values();
    }
}
