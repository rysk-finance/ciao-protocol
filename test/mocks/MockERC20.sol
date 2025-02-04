// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.9;

import "lib/solmate/src/tokens/ERC20.sol";

/**
 * @notice This is only to be used as a mock contract. Please do not
 *         use this contract in any other context
 */
contract MockERC20 is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name, _symbol, _decimals) {}

    /**
     * @notice Allow others to create new tokens
     * @param account is the owner address
     * @param quantity is the quantity to mint
     */
    function mint(address account, uint256 quantity) external {
        _mint(account, quantity);
    }

    /**
     * @notice Allow others to destroy existing tokens
     * @param account is the owner address
     * @param quantity is the quantity to burn
     */
    function burn(address account, uint256 quantity) external {
        _burn(account, quantity);
    }
}
