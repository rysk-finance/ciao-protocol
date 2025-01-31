// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../interfaces/ICiao.sol";
import "../interfaces/IFurnace.sol";
import "../interfaces/IProductCatalogue.sol";
import "../interfaces/IAddressManifest.sol";
import "../interfaces/IPerpCrucible.sol";

abstract contract AccessControl {
    IAddressManifest public addressManifest;

    function __AccessControl_init(address _addressManifest) internal {
        addressManifest = IAddressManifest(_addressManifest);
    }

    function _isOwner() internal view {
        require(msg.sender == addressManifest.owner(), "UNAUTHORIZED");
    }

    function _isAdmin() internal view {
        require(msg.sender == addressManifest.admin(), "UNAUTHORIZED");
    }

    function _isOrderDispatch() internal view {
        require(msg.sender == _orderDispatch(), "UNAUTHORIZED");
    }

    function _isBalanceUpdater() internal view {
        require(msg.sender == _orderDispatch() || msg.sender == _liquidation(), "UNAUTHORIZED");
    }

    function _ciao() internal view returns (ICiao) {
        return ICiao(addressManifest.manifest(1));
    }

    function _furnace() internal view returns (IFurnace) {
        return IFurnace(addressManifest.manifest(2));
    }

    function _productCatalogue() internal view returns (IProductCatalogue) {
        return IProductCatalogue(addressManifest.manifest(3));
    }

    function _orderDispatch() internal view returns (address) {
        return addressManifest.manifest(4);
    }

    function _liquidation() internal view returns (address) {
        return addressManifest.manifest(5);
    }

    function _perpCrucible() internal view returns (IPerpCrucible) {
        return IPerpCrucible(addressManifest.manifest(7));
    }
}
