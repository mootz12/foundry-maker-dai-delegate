// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "forge-std/console.sol";
import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {IVault} from "../interfaces/yearn/IVault.sol";

contract StrategyInternalLiquidatePositionTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    function testLiquidate_ExactWantBalance_LiquidatesAll() public {
        uint256 _amount = 20 * (10 ** vault.decimals());

        tip(address(want), user, _amount);
        vm_std_cheats.prank(user);
        want.transfer(address(strategy), _amount);

        (uint256 liquidatedAmount, uint256 loss) = strategy._liquidatePosition(_amount);

        assertEq(liquidatedAmount, _amount);
        assertEq(loss, 0);
    }

    function testLiquidate_LessThanBalance_LiquidatesRequestedAmount() public {
        uint256 _amount = 20 * (10 ** vault.decimals());

        tip(address(want), user, _amount);
        vm_std_cheats.prank(user);
        want.transfer(address(strategy), _amount);

        uint256 toLiquidate = (_amount * 50) / 100;
        (uint256 liquidatedAmount, uint256 loss) = strategy._liquidatePosition(toLiquidate);

        assertEq(liquidatedAmount, toLiquidate);
        assertEq(loss, 0);
    }

    function testLiquidate_MoreThanBalance_LiquidatesAllAndReportsLoss() public {
        uint256 _amount = 20 * (10 ** vault.decimals());

        tip(address(want), user, _amount);
        vm_std_cheats.prank(user);
        want.transfer(address(strategy), _amount);

        uint256 toLiquidate = (_amount * 150) / 100;
        (uint256 liquidatedAmount, uint256 loss) = strategy._liquidatePosition(toLiquidate);

        assertEq(liquidatedAmount, _amount);
        assertEq(loss, toLiquidate - _amount);
    }

    // Liquidate with deposited funds
    
    function testLiquidate_HappyPath() public {
        IVault yvDAI = strategy.yVault();
        uint256 _amount = 20 * (10 ** vault.decimals());
        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // transfer profit into the yVault so the strategy can close the whole position
        uint256 profit = yvDAI.totalAssets() / 100;
        tip(address(dai), whale, profit);
        vm_std_cheats.prank(whale);
        dai.transfer(address(yvDAI), profit);

        (uint256 liquidatedAmount, uint256 loss) = strategy._liquidatePosition(_amount);

        assertEq(liquidatedAmount, _amount);
        assertEq(loss, 0);
        assertGt(strategy.estimatedTotalAssets(), 0);
    }

    // In this test we attempt to liquidate the whole position a week after the deposit.
    // We do not simulate any gains in the yVault, so there will not be enough money
    // to unlock the whole collateral without a loss.
    // If leaveDebtBehind is false (default) then the strategy will need to unlock a bit
    // of collateral and sell it for DAI in order to pay back the debt.
    // We expect the recovered collateral to be a bit less than the deposited amount
    // due to Maker Stability Fees.
    function testLiquidate_WithoutEnoughProfit_SellsWant() public {
        IVault yvDAI = strategy.yVault();
        uint256 _amount = 20 * (10 ** vault.decimals());
        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // simulate a loss in the yvDAI vault
        uint256 shareLoss = yvDAI.balanceOf(address(strategy)) / 100;
        vm_std_cheats.prank(address(strategy));
        yvDAI.transfer(whale, shareLoss);

        (uint256 liquidatedAmount, uint256 loss) = strategy._liquidatePosition(_amount);

        assertEq(liquidatedAmount, _amount - loss);
        assertGt(loss, 0);
        assertEq(want.balanceOf(address(strategy)), liquidatedAmount);
    }

    // Same as above but this time leaveDebtBehind is set to True, so the strategy
    // should not ever sell want. The result is the CDP being locked until new deposits
    // are made and the debt set right above the floor (dust) set by Maker for YFI-A.
    function testLiquidate_WithoutEnoughProfit_LeavesDebtBehind() public {
        IVault yvDAI = strategy.yVault();

        // set strategy to leaveDebtBehind
        vm_std_cheats.prank(gov);
        strategy.setLeaveDebtBehind(true);

        uint256 _amount = 20 * (10 ** vault.decimals());
        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // simulate a loss in the yvDAI vault
        uint256 shareLoss = yvDAI.balanceOf(address(strategy)) / 100;
        vm_std_cheats.prank(address(strategy));
        yvDAI.transfer(whale, shareLoss);

        // Cannot take more than dust * (collateralization ratio - tolerance)
        // of collateral unless we pay the full debt.
        // Here we are leaving it behind, so it's a "loss" priced in want.
        uint256 wantPrice = strategy._getPrice();
        uint256 collatRatio = strategy.collateralizationRatio();
        uint256 rebalanceTolerance = strategy.rebalanceTolerance();
        // inflate debtFloor so debtFloor / wantPrice is in WAD
        uint256 minLockedWantForDebtFloor = (((debtFloorDai * 1e18) / wantPrice) * (collatRatio - rebalanceTolerance)) / 1e18;

        (uint256 liquidatedAmount, uint256 loss) = strategy._liquidatePosition(_amount);

        assertRelApproxEq(liquidatedAmount, _amount - minLockedWantForDebtFloor, DELTA);
        assertRelApproxEq(loss, minLockedWantForDebtFloor, DELTA);
        assertRelApproxEq(want.balanceOf(address(strategy)), _amount - minLockedWantForDebtFloor, DELTA);
    }
}
