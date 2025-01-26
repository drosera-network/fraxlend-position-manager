// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {FraxLendPositionTrap} from "../src/FraxLendPositionTrap.sol";
import {PositionController} from "../src/PositionController.sol";
import {IFraxlendPair} from "../src/interfaces/IFraxlendPair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFraxlendPairHelper} from "../src/interfaces/IFraxlendPairHelper.sol";

contract PositionControllerTest is Test {
    FraxLendPositionTrap public trap;
    PositionController public controller;

    address internal FRAXLEND_PAIR = 0x794F6B13FBd7EB7ef10d1ED205c9a416910207Ff; // WETH/FRAX
    address internal COLLATERAL_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    address internal FRAXLEND_PAIR_HELPER_ADDRESS = 0x26fa88b783cE712a2Fa10E91296Caf3daAE0AB37;
    uint256 internal FORK_BLOCK = 18_900_000;
    uint256 internal SAFE_THRESHOLD = 10000;

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);

        address user = makeAddr("user");
        controller = new PositionController(user, 75000, SAFE_THRESHOLD);
        trap = new FraxLendPositionTrap(address(controller));

        controller.setTrapAddress(address(trap));
        controller.addPair(FRAXLEND_PAIR);

        deal(COLLATERAL_TOKEN, address(controller), 100 ether);
    }

    function test_shouldRespond_tvlDecreased() public {
        IFraxlendPair pair = IFraxlendPair(FRAXLEND_PAIR);
        deal(COLLATERAL_TOKEN, controller.getUserAddress(), 10 ether);
        vm.startPrank(controller.getUserAddress());
        IERC20(COLLATERAL_TOKEN).approve(FRAXLEND_PAIR, 10 ether);

        pair.borrowAsset(15 ether, 0.01 ether, controller.getUserAddress());
        vm.stopPrank();

        bytes[] memory data = new bytes[](1);
        data[0] = trap.collect();

        (bool shouldAct, bytes memory responseData) = trap.shouldRespond(data);
        assertTrue(shouldAct);

        (address[] memory pairs, uint256[] memory ltvs, uint256[] memory required) =
            abi.decode(responseData, (address[], uint256[], uint256[]));

        vm.prank(address(trap));
        controller.addCollateral(pairs, ltvs, required);

        // check if ltv decreased
        IFraxlendPairHelper ph = IFraxlendPairHelper(FRAXLEND_PAIR_HELPER_ADDRESS);
        uint256 exchangeRate = ph.previewUpdateExchangeRate(FRAXLEND_PAIR);
        (, uint256 userBorrowShares, uint256 userCollateral) =
            ph.getUserSnapshot(FRAXLEND_PAIR, controller.getUserAddress());
        (,, uint256 totalBorrowAmount, uint256 totalBorrowShares,) = ph.getPairAccounting(FRAXLEND_PAIR);

        uint256 userBorrowAmount = userBorrowShares * totalBorrowAmount / totalBorrowShares;
        uint256 newLTV = (userBorrowAmount * exchangeRate * 1e5) / (userCollateral * 1e18);

        // check if our safe threshold is reached
        assertTrue(newLTV == SAFE_THRESHOLD, "LTV not reduced to safe threshold");
    }
}
