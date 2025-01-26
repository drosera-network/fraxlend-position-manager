// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPositionController {
    event PairAdded(address pair);
    event PairRemoved(address pair);
    event LiquidationThresholdSet(uint256 threshold);
    event UserAddressSet(address userAddress);
    event TrapAddressSet(address trapAddress);
    event CollateralAdded(address pair, uint256 amount);
    event SafeThresholdSet(uint256 threshold);

    error PairAlreadyAdded();
    error PairNotFound();
    error OnlyTrap();
    error LengthMismatch();
    error InsufficientBalance();

    function getPairs() external view returns (address[] memory);
    function getUserAddress() external view returns (address);
    function getLiquidationThreshold() external view returns (uint256);
    function getSafeThreshold() external view returns (uint256);
}
