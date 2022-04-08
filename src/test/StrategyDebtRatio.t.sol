// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "forge-std/console.sol";
import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {IVault, StrategyParams} from "../interfaces/yearn/IVault.sol";

// NOTE: if the name of the strat or file changes this needs to be updated
import {Strategy} from "../Strategy.sol";

// TODO: Verify test is not duplicate from vault tests
contract StrategyDebtRatioTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    function testDebtRatioIncrease() public {
        uint256 _amount = 20 * (10 ** vault.decimals());
        IVault yvDAI = strategy.yVault();

        vm_std_cheats.prank(gov);
        vault.updateStrategyDebtRatio(address(strategy), 5000); // fixture initializes at 10_000
        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // assert correct strategy debt amount
        uint256 expectedDebtStart = 10 * (10 ** vault.decimals());
        assertEq(expectedDebtStart, vault.strategies(address(strategy)).totalDebt);

        // transfer additional 200 DAI into the yvDAI vault
        vm_std_cheats.prank(whale);
        dai.transfer(address(yvDAI), 200 ether);

        // update the strategy
        skip(1);
        vm_std_cheats.prank(gov);
        strategy.harvest();
        skip(2 days);
        vm_std_cheats.roll(block.number + 1);
        vm_std_cheats.prank(gov);
        vault.updateStrategyDebtRatio(address(strategy), 10000);
        vm_std_cheats.prank(gov);
        strategy.harvest();

        // assert correct strategy debt amount and no loss
        uint256 minDebtEnd = 20 * (10 ** vault.decimals());
        StrategyParams memory endParams = vault.strategies(address(strategy));
        assertGe(endParams.totalDebt, minDebtEnd);
        assertEq(0, endParams.totalLoss);
    }

    function testDebtRatioDecrease() public {
        uint256 _amount = 20 * (10 ** vault.decimals());
        IVault yvDAI = strategy.yVault();

        vm_std_cheats.prank(gov);
        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // assert correct strategy debt amount
        uint256 expectedDebtStart = 20 * (10 ** vault.decimals());
        assertEq(expectedDebtStart, vault.strategies(address(strategy)).totalDebt);

        // update the strategy
        skip(1);
        vm_std_cheats.prank(gov);
        strategy.harvest();
        skip(2 days);

        vm_std_cheats.roll(block.number + 1);
        vm_std_cheats.prank(gov);
        vault.updateStrategyDebtRatio(address(strategy), 5000); // fixture initializes at 10_000
        vm_std_cheats.prank(gov);
        strategy.harvest();

        // assert correct strategy debt amount and no loss
        // 15 because it should be less than 20 but there is some profit.
        uint256 maxDebtEnd = 15 * (10 ** vault.decimals());
        StrategyParams memory endParams = vault.strategies(address(strategy));
        assertLe(endParams.totalDebt, maxDebtEnd);
        assertEq(0, endParams.totalLoss);
    }
}
