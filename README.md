# FraxLend Position Manager

A system for automated collateral management of FraxLend positions to prevent liquidations.

## Overview

The system consists of two main components:

- `PositionController`: On-chain contract managing positions and executing collateral additions
- `FraxLendPositionTrap`: Off-chain monitoring contract calculating position health

## How It Works

1. The Trap fetches position data:

   - Lending pairs being monitored
   - Current exchange rates
   - User's borrow and collateral balances
   - Liquidation/safe thresholds

2. Position health calculation:

   ```solidity
   userBorrowAmount = userBorrowShares * totalBorrowAmount / totalBorrowShares
   userLTV = (userBorrowAmount * exchangeRate * 1e5) / (userCollateralBalance * 1e18)
   ```

3. If LTV exceeds safe threshold:
   - Calculates required collateral to return to safe level
   - Returns pair addresses and amounts needing collateral
   - Controller executes on-chain collateral additions

## Usage

1. Deploy `PositionController` with:

   - User address to monitor
   - Liquidation threshold (e.g. 75000 for 75% for FraxLend pairs)
   - Safe threshold (e.g. 65000 for 65%)

2. Add FraxLend pairs to monitor via `addPair()`

3. Supply the `PositionController` with collateral token from pairs you want to monitor

4. Your trap contract will now monitor the positions and execute collateral additions when necessary.
