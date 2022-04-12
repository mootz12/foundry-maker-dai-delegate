// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "forge-std/console.sol";
import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {IVault, StrategyParams} from "../interfaces/yearn/IVault.sol";

// NOTE: if the name of the strat or file changes this needs to be updated
import {Strategy} from "../Strategy.sol";

contract StrategyEmergencyDebtRepaymentTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    function testPassingZero_RepaysAllDebt() public {
        IVault yvDAI = strategy.yVault();
        uint256 _amount = 20 * (10 ** vault.decimals());

        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // assert the strategy has taken on debt
        assertGt(strategy.balanceOfDebt(), 0);

        // send profits to yVault to simulate ~2% yield
        uint256 profit = (yvDAI.totalAssets() * 2) / 100;
        tip(address(dai), whale, profit);
        vm_std_cheats.prank(whale);
        dai.transfer(address(yvDAI), profit);
        
        // TODO: Determine if this harvest logic is required for unit test.
        //       Harvest results in less value of yvDAI tokens for strategy and an increased
        //       amount of Maker debt (?), such that we can't repay the full debt anymore.
        // // realize profit
        // skip(1);
        // vm_std_cheats.prank(gov);
        // strategy.harvest();

        // repay debt
        uint256 prevCollateral = strategy.balanceOfMakerVault();
        vm_std_cheats.prank(gov);
        strategy.emergencyDebtRepayment(0);

        // assert all debt is repaid and collateral is left untouched
        assertEq(strategy.balanceOfDebt(), 0);
        assertEq(strategy.balanceOfMakerVault(), prevCollateral);
    }

    function testPassingValueOverCollatRatio_DoesNothing() public {
        uint256 _amount = 20 * (10 ** vault.decimals());

        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // assert the strategy has taken on debt
        assertGt(strategy.balanceOfDebt(), 0);

        // update debt ratio higher than current ratio
        uint256 prevCollateral = strategy.balanceOfMakerVault();
        uint256 prevDebt = strategy.balanceOfDebt();
        uint256 collatRatio = strategy.collateralizationRatio();
        vm_std_cheats.prank(gov);
        strategy.emergencyDebtRepayment(collatRatio + 1);

        // assert all debt is repaid and collateral is left untouched
        assertEq(strategy.balanceOfDebt(), prevDebt);
        assertEq(strategy.balanceOfMakerVault(), prevCollateral);
    }

    function testPassingLowerCollatRatio_AdjustsDebt() public {
        uint256 initialWant = 20 * (10 ** vault.decimals());
        uint256 _debtRemainingPct = 75;

        actions.depositAndHarvestStrategy(user, vault, strategy, initialWant);

        // assert the strategy has taken on debt
        assertGt(strategy.balanceOfDebt(), 0);

        // update debt ratio higher than current ratio
        uint256 prevCollateral = strategy.balanceOfMakerVault();
        uint256 prevDebt = strategy.balanceOfDebt();
        uint256 collatRatio = strategy.collateralizationRatio();
        vm_std_cheats.prank(gov);
        strategy.emergencyDebtRepayment((collatRatio * _debtRemainingPct) / 100);

        // assert all debt is repaid and collateral is left untouched
        assertRelApproxEq(strategy.balanceOfDebt(), (prevDebt * _debtRemainingPct) / 100, DELTA);
        assertEq(strategy.balanceOfMakerVault(), prevCollateral);
    }
}
