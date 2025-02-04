pragma solidity >=0.8.19;

import "../Crucible.sol";

import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

//    _____             __  ______                _ __    __
//   / ___/____  ____  / /_/ ____/______  _______(_) /_  / /__
//   \__ \/ __ \/ __ \/ __/ /   / ___/ / / / ___/ / __ \/ / _ \
//  ___/ / /_/ / /_/ / /_/ /___/ /  / /_/ / /__/ / /_/ / /  __/
// /____/ .___/\____/\__/\____/_/   \__,_/\___/_/_.___/_/\___/
//     /_/
////////////////////////////////////////////////////////////////

/// @notice Contract for storing all important information for spot positions
///         Mk 0.0.0

contract SpotCrucible is Crucible, Initializable {
    function initialize(address _addressManifest) external initializer {
        __Crucible_init(_addressManifest);
    }
}
