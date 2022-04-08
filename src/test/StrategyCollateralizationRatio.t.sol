// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "forge-std/console.sol";
import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {IVault} from "../interfaces/yearn/IVault.sol";

// NOTE: if the name of the strat or file changes this needs to be updated
import {Strategy} from "../Strategy.sol";

contract StrategyCollateralizationRatioTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    // lower target ratio test
    function testLowerTargetRatio_OutsideReblanaceBand_TakesMoreDebt() public {
        uint256 _amount = 25 * (10 ** vault.decimals());
        IVault yvDAI = strategy.yVault();

        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // shares in yVault before change
        uint256 balanceBefore = yvDAI.balanceOf(address(strategy));
        uint256 ratioBefore = strategy.collateralizationRatio();
        uint256 ratioPercent = 90; // 90 / 100

        // set new collateral ratio
        vm_std_cheats.prank(gov);
        strategy.setCollateralizationRatio((ratioBefore * ratioPercent) / 100);

        // adjust position
        vm_std_cheats.prank(gov);
        strategy.tend();

        // assert more DAI gets minted into yvDAI vault
        uint256 expectedBalance = (balanceBefore / ratioPercent) * 100;
        assertRelApproxEq(expectedBalance, yvDAI.balanceOf(address(strategy)), DELTA);
    }

    function testLowerTargetRatio_InsideRebalanceBand_DoesNotTakeMoreDebt() public {
        uint256 _amount = 25 * (10 ** vault.decimals());
        IVault yvDAI = strategy.yVault();

        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // shares in yVault before change
        uint256 balanceBefore = yvDAI.balanceOf(address(strategy));
        uint256 ratioBefore = strategy.collateralizationRatio();
        uint256 ratioPercent = 99; // 99 / 100

        // set new collateral ratio
        vm_std_cheats.prank(gov);
        strategy.setCollateralizationRatio((ratioBefore * ratioPercent) / 100);

        // adjust position
        vm_std_cheats.prank(gov);
        strategy.tend();

        // assert no more DAI gets minted
        assertEq(balanceBefore, yvDAI.balanceOf(address(strategy)));
    }

    // higher target ratio tests
    function testHigherTargetRatio_InsideRebalanceBand_RepaysDebt() public {
        uint256 _amount = 25 * (10 ** vault.decimals());
        IVault yvDAI = strategy.yVault();

        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // shares in yVault before change
        uint256 balanceBefore = yvDAI.balanceOf(address(strategy));
        uint256 ratioBefore = strategy.collateralizationRatio();
        uint256 ratioPercent = 110; // 110 / 100

        // set new collateral ratio
        vm_std_cheats.prank(gov);
        strategy.setCollateralizationRatio((ratioBefore * ratioPercent) / 100);

        // adjust position
        vm_std_cheats.prank(gov);
        strategy.tend();

        // assert DAI gets repayed
        uint256 expectedBalance = (balanceBefore / ratioPercent) * 100;
        assertRelApproxEq(expectedBalance, yvDAI.balanceOf(address(strategy)), DELTA);
    }

    function testHigherTargetRatio_InsideRebalanceBand_DoesNotRepayDebt() public {
        uint256 _amount = 25 * (10 ** vault.decimals());
        IVault yvDAI = strategy.yVault();

        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // shares in yVault before change
        uint256 balanceBefore = yvDAI.balanceOf(address(strategy));
        uint256 ratioBefore = strategy.collateralizationRatio();
        uint256 ratioPercent = 101; // 101 / 100

        // set new collateral ratio
        vm_std_cheats.prank(gov);
        strategy.setCollateralizationRatio((ratioBefore * ratioPercent) / 100);

        // adjust position
        vm_std_cheats.prank(gov);
        strategy.tend();

        // assert no DAI is repayed
        assertEq(balanceBefore, yvDAI.balanceOf(address(strategy)));
    }

    function testLowerTargetRatio_BelowLiquidation_Reverts() public {
        vm_std_cheats.prank(gov);
        vm_std_cheats.expectRevert();
        strategy.setCollateralizationRatio(1 * 1e18);
    }

    function testTolerance_BelowLiquidation_Reverts() public {
        vm_std_cheats.prank(gov);
        vm_std_cheats.expectRevert();
        strategy.setRebalanceTolerance(1 * 1e18);
    }

    // TODO: Refactor: Place into test class that exercises withdrawal 
    function testWithdrawal_EnforcesCollateralizationRatio() public {
        uint256 _amount = 25 * (10 ** vault.decimals());
        IVault yvDAI = strategy.yVault();
        
        // assert no collateral is locked
        assertEq(0, strategy.getCurrentMakerVaultRatio());

        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // shares in yVault before change
        uint256 balanceBefore = yvDAI.balanceOf(address(strategy));

        // adjust position
        vm_std_cheats.prank(user);
        vault.withdraw((_amount * 3) / 100);

        // assert collateralization level is still good
        uint256 expectedCollateral = strategy.collateralizationRatio();
        assertRelApproxEq(expectedCollateral, strategy.getCurrentMakerVaultRatio(), DELTA);
        // assert strategy has less funds
        uint256 expectedBalance = (balanceBefore * 97) / 100;
        assertRelApproxEq(expectedBalance, yvDAI.balanceOf(address(strategy)), DELTA);
    }
}
