// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IPositionController} from "./interfaces/IPositionController.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IFraxlendPair} from "./interfaces/IFraxlendPair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title PositionController - Manages FraxLend lending positions and collateral
/// @notice Controls position parameters and collateral management for FraxLend pairs
/// @dev Implements access control and position management for a single user address
contract PositionController is IPositionController, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Set of tracked FraxLend pair addresses
    EnumerableSet.AddressSet private pairs;

    /// @notice Address of the user whose positions are being managed
    address private userAddress;

    /// @notice Liquidation threshold as percentage in percentage points (75000 = 75%)
    uint256 private liquidationThreshold;

    /// @notice Address of authorized trap contract
    address private trapAddress;

    /// @notice Safe threshold as percentage in percentage points
    uint256 private safeThreshold;

    modifier onlyTrap() {
        if (msg.sender != trapAddress) {
            revert OnlyTrap();
        }
        _;
    }

    /// @notice Initializes controller with user address and thresholds
    /// @param _userAddress Address of user whose positions are managed
    /// @param _liquidationThreshold Liquidation threshold (75000 = 75%)
    /// @param _safeThreshold Safe threshold (65000 = 65%)
    constructor(address _userAddress, uint256 _liquidationThreshold, uint256 _safeThreshold) Ownable(msg.sender) {
        userAddress = _userAddress;
        liquidationThreshold = _liquidationThreshold;
        safeThreshold = _safeThreshold;
    }

    /// @notice Add collateral to positions that need it
    /// @dev Only callable by trap config
    /// @param _pairs Array of pair addresses needing collateral
    /// @param _ltvs Current LTV of each position
    /// @param _requiredCollateral Amount of collateral needed for each position
    function addCollateral(address[] calldata _pairs, uint256[] calldata _ltvs, uint256[] calldata _requiredCollateral)
        external
        onlyTrap
    {
        if (_pairs.length != _ltvs.length || _pairs.length != _requiredCollateral.length) {
            revert LengthMismatch();
        }

        for (uint256 i = 0; i < _pairs.length; i++) {
            IFraxlendPair pair = IFraxlendPair(_pairs[i]);
            IERC20 token = IERC20(pair.collateralContract());

            uint256 balance = token.balanceOf(address(this));
            if (balance < _requiredCollateral[i]) {
                revert InsufficientBalance();
            }

            token.approve(address(pair), _requiredCollateral[i]);
            pair.addCollateral(_requiredCollateral[i], userAddress);

            emit CollateralAdded(_pairs[i], _requiredCollateral[i]);
        }
    }

    /// @notice Get array of tracked FraxLend pair addresses
    /// @return Array of pair addresses
    function getPairs() external view returns (address[] memory) {
        return pairs.values();
    }

    /// @notice Get managed user address
    /// @return User address
    function getUserAddress() external view returns (address) {
        return userAddress;
    }

    /// @notice Get liquidation threshold
    /// @return Liquidation threshold
    function getLiquidationThreshold() external view returns (uint256) {
        return liquidationThreshold;
    }

    /// @notice Get safe threshold
    /// @return Safe threshold
    function getSafeThreshold() external view returns (uint256) {
        return safeThreshold;
    }

    /// @notice Add pair to tracked set
    /// @param _pair Address of pair to add
    function addPair(address _pair) external onlyOwner {
        if (!pairs.add(_pair)) {
            revert PairAlreadyAdded();
        }
        emit PairAdded(_pair);
    }

    /// @notice Remove pair from tracked set
    /// @param _pair Address of pair to remove
    function removePair(address _pair) external onlyOwner {
        if (!pairs.remove(_pair)) {
            revert PairNotFound();
        }
        emit PairRemoved(_pair);
    }

    /// @notice Update liquidation threshold
    /// @param _liquidationThreshold New liquidation threshold
    function setLiquidationThreshold(uint256 _liquidationThreshold) external onlyOwner {
        liquidationThreshold = _liquidationThreshold;
        emit LiquidationThresholdSet(_liquidationThreshold);
    }

    /// @notice Update safe threshold
    /// @param _safeThreshold New safe threshold
    function setSafeThreshold(uint256 _safeThreshold) external onlyOwner {
        safeThreshold = _safeThreshold;
        emit SafeThresholdSet(_safeThreshold);
    }

    /// @notice Update user address
    /// @param _userAddress New user address
    function setUserAddress(address _userAddress) external onlyOwner {
        userAddress = _userAddress;
        emit UserAddressSet(_userAddress);
    }

    /// @notice Set trap contract address
    /// @dev Only callable by owner
    /// @param _trapAddress New trap address
    function setTrapAddress(address _trapAddress) external onlyOwner {
        trapAddress = _trapAddress;
        emit TrapAddressSet(_trapAddress);
    }
}
