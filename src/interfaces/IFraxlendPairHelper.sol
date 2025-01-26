// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IFraxlendPairHelper {
    function previewUpdateExchangeRate(address pairAddress) external view returns (uint256);
    function getUserSnapshot(address _fraxlendPairAddress, address _address)
        external
        view
        returns (uint256 _userAssetShares, uint256 _userBorrowShares, uint256 _userCollateralBalance);
    function getPairAccounting(address pairAddress)
        external
        view
        returns (
            uint128 _totalAssetAmount,
            uint128 _totalAssetShares,
            uint128 _totalBorrowAmount,
            uint128 _totalBorrowShares,
            uint256 _totalCollateral
        );
}
