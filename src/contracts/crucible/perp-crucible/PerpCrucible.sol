pragma solidity >=0.8.19;

import "../../libraries/EnumerableSet.sol";
import "../../libraries/BasicMath.sol";
import "../../interfaces/Errors.sol";
import "../../interfaces/Events.sol";

import "../Crucible.sol";

import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

//     ____                  ______                _ __    __
//    / __ \___  _________  / ____/______  _______(_) /_  / /__
//   / /_/ / _ \/ ___/ __ \/ /   / ___/ / / / ___/ / __ \/ / _ \
//  / ____/  __/ /  / /_/ / /___/ /  / /_/ / /__/ / /_/ / /  __/
// /_/    \___/_/  / .___/\____/_/   \__,_/\___/_/_.___/_/\___/
//                /_/
/////////////////////////////////////////////////////////////////

contract PerpCrucible is Crucible, Initializable {
    using EnumerableSet for EnumerableSet.UintSet;
    using BasicMath for uint256;
    using BasicMath for int256;

    // Dynamic State
    //////////////////////////////////////

    // mapping from product id to subaccount to Position
    mapping(uint32 => mapping(address => Structs.PositionState))
        public subAccountPositions;

    // mapping from productId to current cumulative funding
    mapping(uint32 => int256) public currentCumFunding;

    function initialize(address _addressManifest) external initializer {
        __Crucible_init(_addressManifest);
    }
    
    // External - Access Controlled
    //////////////////////////////////////

    /// @notice this function takes funding diffs as parameters. This is the dollar value of funding incurred per contract in the period
    /// @dev only accessible by the order dispatch
    /// @param fundingData array of bytes containing details of funding updates for each product id
    function updateCumulativeFundings(bytes memory fundingData) external {
        // check that the caller is the order dispatch
        _isOrderDispatch();
        // look at the length of the byte array to determine how many funding rates are being updated
        if (fundingData.length % 36 != 0) revert Errors.OrderByteLengthInvalid();
        uint fundingDataLen = fundingData.length;
        for (uint i; i < fundingDataLen; ) {
            uint32 productId;
            int256 fundingDiff;
            uint256 pidOffset = i + 4;
            uint256 fundingOffset = i + 36;
            /// @solidity memory-safe-assembly
            assembly {
                productId := mload(add(fundingData, pidOffset))
                fundingDiff := mload(add(fundingData, fundingOffset))
            }
            currentCumFunding[productId] += fundingDiff;
            i += 36;
        }
    }

    /// @notice updates state with details of a user's new position
    /// @dev a user can only hold one position for each productID (no concurrent short and long)
    /// @param takerSubAccount the subaccount of the taker of the matched order
    /// @param makerSubAccount the subaccount of the maker of the matched order
    /// @param productId product ID of the market being traded
    /// @param makerPosition the position that is being incremented onto the existing position,
    ///                      uses the maker pos as reference and flips the direction for the taker
    /// @return takerRealisedPnl the profit or loss of the realised portion of the taker's position, including all funding accrued
    /// @return makerRealisedPnl the profit or loss of the realised portion of the maker's position, including all funding accrued
    function updatePosition(
        address takerSubAccount,
        address makerSubAccount,
        uint32 productId,
        Structs.NewPosition memory makerPosition
    ) external returns (int256 takerRealisedPnl, int256 makerRealisedPnl) {
        // check that the caller is the order dispatch or liquidation
        _isBalanceUpdater();
        takerRealisedPnl = _updatePosition(
            takerSubAccount,
            productId,
            Structs.NewPosition(
                makerPosition.executionPrice,
                makerPosition.quantity,
                !makerPosition.isLong
            )
        );
        makerRealisedPnl = _updatePosition(
            makerSubAccount,
            productId,
            makerPosition
        );
    }

    // Internal
    //////////////////////////////////////

    /// @notice updates state with details of a user's new position
    /// @dev a user can only hold one position for each productID (no concurrent short and long)
    /// @param subAccount the subaccount that the position belongs to
    /// @param productId product ID of the market being traded
    /// @param position the position that is being incremented onto the existing position
    /// @return realisedPnl the profit or loss of the realised portion of the position, including all funding accrued
    function _updatePosition(
        address subAccount,
        uint32 productId,
        Structs.NewPosition memory position
    ) internal returns (int256 realisedPnl) {
        Structs.PositionState memory existingPosition = subAccountPositions[productId][subAccount];
        if (openPositionIds[subAccount].contains(productId)) {
            // position is already open for this market, so update it and settle funding
            // settle funding first
            // equal to difference in cumulative funding snapshots * number of contracts open
            // if cumFunding has increased, longs will have negative funding pnl, and vice versa
            realisedPnl = (
                existingPosition.isLong
                    ? (existingPosition.initCumFunding -
                        currentCumFunding[productId])
                    : (currentCumFunding[productId] -
                        existingPosition.initCumFunding)
            ).mul(int256(existingPosition.quantity));
            if (existingPosition.isLong == position.isLong) {
                // add to existing position
                // update avgEntryPrice and quantity of position
                // no pnl is realised here
                uint newAvgEntryPrice = (existingPosition.avgEntryPrice.mul(
                    existingPosition.quantity
                ) + position.executionPrice.mul(position.quantity)).div(
                        existingPosition.quantity + position.quantity
                    );
                subAccountPositions[productId][subAccount] = Structs
                    .PositionState(
                        newAvgEntryPrice,
                        existingPosition.quantity + position.quantity,
                        position.isLong,
                        currentCumFunding[productId]
                    );
            } else if (existingPosition.quantity >= position.quantity) {
                realisedPnl += (
                    existingPosition.isLong
                        ? (int(position.executionPrice) -
                            int(existingPosition.avgEntryPrice))
                        : (int(existingPosition.avgEntryPrice) -
                            int(position.executionPrice))
                ).mul(int(position.quantity));
                if (existingPosition.quantity == position.quantity) {
                    // close position entirely
                    // realise all pnl and remove position from state

                    openPositionIds[subAccount].remove(productId);
                    delete subAccountPositions[productId][subAccount];
                } else {
                    // reduce position size but is not flipping long/short side
                    // realise pnl proportional to quantity of position being closed
                    // reduce the position quantity
                    subAccountPositions[productId][subAccount] = Structs
                        .PositionState(
                            existingPosition.avgEntryPrice,
                            existingPosition.quantity - position.quantity,
                            existingPosition.isLong,
                            currentCumFunding[productId]
                        );
                }
            } else {
                // existingPosition.quantity < position.quantity
                // position is fully closed and flipped to opposite direction
                // realise all pnl
                // create new position on opposite long/short side with any leftover size
                realisedPnl += (
                    existingPosition.isLong
                        ? (int(position.executionPrice) -
                            int(existingPosition.avgEntryPrice))
                        : (int(existingPosition.avgEntryPrice) -
                            int(position.executionPrice))
                ).mul(int(existingPosition.quantity));
                subAccountPositions[productId][subAccount] = Structs
                    .PositionState(
                        position.executionPrice,
                        position.quantity - existingPosition.quantity,
                        position.isLong,
                        currentCumFunding[productId]
                    );
            }
        } else {
            // no existing position for this asset exists
            // add position to storage
            subAccountPositions[productId][subAccount] = Structs.PositionState(
                position.executionPrice,
                position.quantity,
                position.isLong,
                currentCumFunding[productId]
            );

            openPositionIds[subAccount].add(productId);
        }
        emit Events.PerpPositionUpdated(
            subAccount,
            productId,
            existingPosition,
            subAccountPositions[productId][subAccount]
        );
    }

    // Basic Getters
    //////////////////////////////////////
    function getSubAccountPosition(
        uint32 productId,
        address subAccount
    ) external view returns (Structs.PositionState memory) {
        return subAccountPositions[productId][subAccount];
    }

    function isPositionOpenForId(
        address subAccount,
        uint32 productId
    ) external view returns (bool) {
        return openPositionIds[subAccount].contains(productId);
    }
}
