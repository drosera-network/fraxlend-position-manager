// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";
import {IPositionController} from "./interfaces/IPositionController.sol";
import {IFraxlendPairHelper} from "./interfaces/IFraxlendPairHelper.sol";

contract FraxLendPositionTrap is ITrap {
    address internal FRAXLEND_PAIR_HELPER_ADDRESS = 0x26fa88b783cE712a2Fa10E91296Caf3daAE0AB37;
    address internal positionController; // place controller address after deployment

    struct PairState {
        address pairAddress;
        uint256 exchangeRate;
        uint256 totalBorrowAmount;
        uint256 totalBorrowShares;
        uint256 userBorrowShares;
        uint256 userCollateralBalance;
        uint256 liquidationThreshold;
        uint256 safeThreshold;
    }

    // only for testing
    constructor(address _positionController) {
        positionController = _positionController;
    }

    function collect() external view returns (bytes memory) {
        IPositionController pc = IPositionController(positionController);
        IFraxlendPairHelper ph = IFraxlendPairHelper(FRAXLEND_PAIR_HELPER_ADDRESS);

        // get all controller data
        address[] memory pairAddresses = pc.getPairs();
        address userAddress = pc.getUserAddress();
        uint256 liquidationThreshold = pc.getLiquidationThreshold();
        uint256 safeThreshold = pc.getSafeThreshold();
        PairState[] memory pairStates = new PairState[](pairAddresses.length);

        for (uint256 i = 0; i < pairAddresses.length; i++) {
            uint256 exchangeRate = ph.previewUpdateExchangeRate(pairAddresses[i]);

            (,, uint256 totalBorrowAmount, uint256 totalBorrowShares,) = ph.getPairAccounting(pairAddresses[i]);

            (, uint256 userBorrowShares, uint256 userCollateralBalance) =
                ph.getUserSnapshot(pairAddresses[i], userAddress);

            pairStates[i] = PairState({
                pairAddress: pairAddresses[i],
                exchangeRate: exchangeRate,
                totalBorrowAmount: totalBorrowAmount,
                totalBorrowShares: totalBorrowShares,
                userBorrowShares: userBorrowShares,
                userCollateralBalance: userCollateralBalance,
                liquidationThreshold: liquidationThreshold,
                safeThreshold: safeThreshold
            });
        }
        return abi.encode(pairStates);
    }

    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory) {
        PairState[] memory pairStates = abi.decode(data[0], (PairState[]));

        bool dangerous = false;
        address[] memory riskyPairs = new address[](pairStates.length);
        uint256[] memory ltvs = new uint256[](pairStates.length);
        uint256[] memory requiredCollateral = new uint256[](pairStates.length);
        uint256 count = 0;

        for (uint256 i = 0; i < pairStates.length; i++) {
            if (pairStates[i].userBorrowShares == 0 || pairStates[i].userCollateralBalance == 0) {
                continue;
            }

            uint256 userBorrowAmount =
                pairStates[i].userBorrowShares * pairStates[i].totalBorrowAmount / pairStates[i].totalBorrowShares;
            uint256 userLTV =
                (userBorrowAmount * pairStates[i].exchangeRate * 1e5) / (pairStates[i].userCollateralBalance * 1e18);
            if (userLTV > pairStates[i].safeThreshold) {
                uint256 targetCollateral =
                    (userBorrowAmount * pairStates[i].exchangeRate * 1e5) / (pairStates[i].safeThreshold * 1e18);
                uint256 additionalCollateral = targetCollateral > pairStates[i].userCollateralBalance
                    ? targetCollateral - pairStates[i].userCollateralBalance
                    : 0;

                riskyPairs[count] = pairStates[i].pairAddress;
                ltvs[count] = userLTV;
                requiredCollateral[count] = additionalCollateral;
                count++;
                dangerous = true;
            }
        }

        if (dangerous) {
            assembly {
                mstore(riskyPairs, count)
                mstore(ltvs, count)
                mstore(requiredCollateral, count)
            }
            return (true, abi.encode(riskyPairs, ltvs, requiredCollateral));
        }

        return (false, "");
    }
}
