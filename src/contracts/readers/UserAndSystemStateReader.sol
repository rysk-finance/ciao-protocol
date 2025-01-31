// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.19;

import "../interfaces/Structs.sol";
import "../interfaces/IPerpCrucible.sol";

import "../libraries/Commons.sol";
import "../libraries/BasicMath.sol";
import "../libraries/EnumerableSet.sol";
import "../libraries/AccessControl.sol";
import "../libraries/MarginDirective.sol";

contract UserAndSystemStateReader is AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    using BasicMath for int256;
    using BasicMath for uint256;

    uint8 constant CORE_COLLATERAL_INDEX = 1;

    constructor(address _addressManifest) {
        __AccessControl_init(_addressManifest);
    }

    struct UserAndSystemState {
        uint256 coreCollateralDebt;
        address coreCollateralAddress;
        Structs.SpotPosition[] spots;
        Structs.PerpPosition[] perps;
    }

    function CompileUserPositions(address account, uint8 subAccountId)
        external
        view
        returns (Structs.UserAndSystemState memory)
    {
        address subAccount = Commons.getSubAccount(account, subAccountId);
        // first get list of spot assets being held
        address[] memory spotAssets = _ciao().getSubAccountAssets(subAccount);
        IPerpCrucible perpCrucible = IPerpCrucible(Commons.perpCrucible(address(addressManifest)));
        uint256[] memory perpPositionIds = perpCrucible.getOpenPositionIds(subAccount);
        Structs.UserAndSystemState memory u;

        u.spots = new Structs.SpotPosition[](spotAssets.length);
        u.perps = new Structs.PerpPosition[](perpPositionIds.length);
        // loop through the spot assets
        for (uint256 i = 0; i < spotAssets.length; i++) {
            // get the balances of spot positions
            if (spotAssets[i] == _ciao().coreCollateralAddress()) {
                // get the balances of usdc and add it as a Structs.SpotPosition
                // get the coreCollateralDebt and add it
                u.coreCollateralDebt = _ciao().coreCollateralDebt(subAccount);
                u.coreCollateralAddress = spotAssets[i];
                u.spots[i] = Structs.SpotPosition(
                    spotAssets[i],
                    _ciao().balances(subAccount, spotAssets[i]),
                    1,
                    _furnace().getSpotRiskWeights(spotAssets[i])
                );
            }
        }

        // acquire perp positions
        for (uint256 i = 0; i < perpPositionIds.length; i++) {
            Structs.PositionState memory perpPos =
                perpCrucible.subAccountPositions(uint32(perpPositionIds[i]), subAccount);
            uint256 perpPrice = _furnace().prices(uint32(perpPositionIds[i]));
            int256 currentCumFunding = perpCrucible.currentCumFunding(uint32(perpPositionIds[i]));
            u.perps[i] = Structs.PerpPosition(
                perpPositionIds[i],
                perpPos,
                perpPrice,
                currentCumFunding,
                _furnace().getProductRiskWeights(uint32(perpPositionIds[i]))
            );
        }
        return u;
    }
}
