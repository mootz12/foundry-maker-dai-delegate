// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "forge-std/console.sol";
import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {IVault, StrategyParams} from "../interfaces/yearn/IVault.sol";

// used to fetch prices
import "../libraries/MakerDaiDelegateLib.sol";

contract StrategyDustAndCeilingTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    function testSmallDeposit_DoesNotGenerateDebtUnderFloor() public {
        IVault yvDAI = strategy.yVault();
        // The strategy should not take on any debt if deposit is less that floor.
        // Pick amount in want that generates 'floor' debt ~5% less than threshold.
        uint256 wantPrice = MakerDaiDelegateLib.getSpotPrice(ilk);
        uint256 floorInWant = (strategy.collateralizationRatio() * debtFloorDai) / wantPrice;
        uint256 _amount = (floorInWant * 95) / 100;

        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // assert strategy has no debt
        assertEq(strategy.balanceOfDebt(), 0);
        assertEq(yvDAI.balanceOf(address(strategy)), 0);
        assertEq(dai.balanceOf(address(strategy)), 0);

        // assert all want is locked in Maker's vault
        assertEq(strategy.balanceOfMakerVault(), _amount);
        assertEq(want.balanceOf(address(strategy)), 0);
        assertEq(want.balanceOf(address(vault)), 0);

        // assert collateralization ratio large
        assertGt(strategy.getCurrentMakerVaultRatio(), strategy.collateralizationRatio());
    }

    function testSmallDeposit_GeneratesDebtPastFloor() public {
        IVault yvDAI = strategy.yVault();
        // The strategy should not take on any debt if deposit is less that floor.
        // Pick amount in want that generates 'floor' debt ~5% less than threshold.
        uint256 wantPrice = MakerDaiDelegateLib.getSpotPrice(ilk);
        uint256 floorInWant = (strategy.collateralizationRatio() * debtFloorDai) / wantPrice;
        uint256 belowFloorAmount = (floorInWant * 95) / 100;

        actions.depositAndHarvestStrategy(user, vault, strategy, belowFloorAmount);

        // assert strategy has no debt
        assertEq(strategy.balanceOfDebt(), 0);
        assertEq(yvDAI.balanceOf(address(strategy)), 0);
        assertEq(dai.balanceOf(address(strategy)), 0);
        assertEq(strategy.balanceOfMakerVault(), belowFloorAmount);

        // deposit a small amount that pushes the strategy past the debt floor
        // push total amount ~5% past floor
        uint256 _amount = (floorInWant * 10) / 100;
        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // assert debt is generated
        assertGt(strategy.balanceOfDebt(), 0);
        assertGt(yvDAI.balanceOf(address(strategy)), 0);
        assertEq(strategy.balanceOfMakerVault(), _amount + belowFloorAmount);

        // assert collateralization ratio is approximately the target
        assertRelApproxEq(strategy.getCurrentMakerVaultRatio(), strategy.collateralizationRatio(), DELTA);
    }

    function testSmallDeposit_DoesNotGenerateDebtPastCeiling() public {
        IVault yvDAI = strategy.yVault();
        // Deposit an amount ensured to be over debt ceiling (2x)
        uint256 wantPrice = MakerDaiDelegateLib.getSpotPrice(ilk);
        uint256 ceilingInWant = (strategy.collateralizationRatio() * debtCeilingDai) / wantPrice;
        uint256 ceilingDeposit = ceilingInWant * 2;

        actions.depositAndHarvestStrategy(user, vault, strategy, ceilingDeposit);

        uint256 investmentAtCeiling = yvDAI.balanceOf(address(strategy));
        uint256 ratioAtCeiling = strategy.getCurrentMakerVaultRatio();

        // deposit a small, additional amount
        uint256 _amount = 1 * (10 ** vault.decimals());
        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // assert no additional dai was minted
        assertEq(yvDAI.balanceOf(address(strategy)), investmentAtCeiling);
        assertGt(strategy.getCurrentMakerVaultRatio(), ratioAtCeiling);
    }

    function testLargeDeposit_DoesNotGenerateDebtOverCeiling() public {
        IVault yvDAI = strategy.yVault();
        // Deposit an amount ensured to be over debt ceiling (2x)
        uint256 wantPrice = MakerDaiDelegateLib.getSpotPrice(ilk);
        uint256 ceilingInWant = (strategy.collateralizationRatio() * debtCeilingDai) / wantPrice;
        uint256 _amount = ceilingInWant * 2;

        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // assert strategy deposited DAI into yVault
        assertGt(yvDAI.balanceOf(address(strategy)), 0);
        assertEq(dai.balanceOf(address(strategy)), 0);

        // assert all want is locked in Maker's vault
        assertEq(want.balanceOf(address(strategy)), 0);
        assertEq(want.balanceOf(address(vault)), 0);

        // assert collateralization ratio significantly larger due to cap
        assertGt(strategy.getCurrentMakerVaultRatio(), (strategy.collateralizationRatio() * 150) / 100);
    }

    function testWithdraw_DoesNotLeaveDebtUnderFloor() public {
        IVault yvDAI = strategy.yVault();
        uint256 initialWant = 10 * (10 ** vault.decimals());

        actions.depositAndHarvestStrategy(user, vault, strategy, initialWant);

        // assert strategy deposited funds in yvDAI
        assertGt(yvDAI.balanceOf(address(strategy)), 0);

        // send profits to yVault to simulate ~3% yield
        uint256 profit = (yvDAI.totalAssets() * 3) / 100;
        tip(address(dai), whale, profit);
        vm_std_cheats.prank(whale);
        dai.transfer(address(yvDAI), profit);
        uint256 vaultShares = yvDAI.balanceOf(address(strategy));

        // withdraw large amount so remaining debt is under floor
        vm_std_cheats.prank(user);
        vault.withdraw((initialWant * 99) / 100);

        // assert the large majority of shares used to repay the debt
        uint256 expectedSharesRemaining = vaultShares - (vaultShares * 100) / 103;
        assertRelApproxEq(yvDAI.balanceOf(address(strategy)), expectedSharesRemaining, DELTA);

        // assert collateralization ratio large (no debt)
        assertGt(strategy.getCurrentMakerVaultRatio(), strategy.collateralizationRatio());
    }

    function testWithdrawEverything_DebtInCeiling_Unwinds() public {
        IVault yvDAI = strategy.yVault();
        // Deposit an amount ensured to be over debt ceiling (2x)
        uint256 wantPrice = MakerDaiDelegateLib.getSpotPrice(ilk);
        uint256 ceilingInWant = (strategy.collateralizationRatio() * debtCeilingDai) / wantPrice;
        uint256 _amount = ceilingInWant * 2;

        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // withdraw everything
        vm_std_cheats.prank(user);
        vault.withdraw();

        // assert the strategy is able to fully unwind
        assertEq(vault.strategies(address(strategy)).totalDebt, 0);
        assertEq(strategy.getCurrentMakerVaultRatio(), 0);
        assertLt(yvDAI.balanceOf(address(strategy)), 1e18); // allow dust
        assertRelApproxEq(want.balanceOf(address(user)), _amount, DELTA);
    }

    function testWithdraw_UnderFloorWithoutFundsToCancelDebt_Reverts() public {
        IVault yvDAI = strategy.yVault();

        // stop strategy from selling want to repay debt
        vm_std_cheats.prank(gov);
        strategy.setLeaveDebtBehind(false);

        // deposit just above token floor
        uint256 wantPrice = MakerDaiDelegateLib.getSpotPrice(ilk);
        uint256 floorInWant = (strategy.collateralizationRatio() * debtFloorDai) / wantPrice;
        uint256 approxFloor = (floorInWant * 102) / 100;

        // define bounds
        uint256 lowerRebalancingBound = strategy.collateralizationRatio() - strategy.rebalanceTolerance();
        uint256 minFloorInBand = (approxFloor * lowerRebalancingBound) / strategy.collateralizationRatio();

        actions.depositAndHarvestStrategy(user, vault, strategy, approxFloor);

        // simulate a loss in the yvDAI vault (~1%)
        uint256 lossAmount =  yvDAI.balanceOf(address(strategy)) / 100;
        vm_std_cheats.prank(address(strategy));
        yvDAI.transfer(user, lossAmount);

        // perform a safe, max withdraw
        uint256 maxWithdraw = approxFloor - minFloorInBand - 1e15;
        vm_std_cheats.prank(user);
        uint256 withdrawResult = vault.withdraw(maxWithdraw);
        assertEq(maxWithdraw, withdrawResult);

        // due to the yvDAI loss, there will not be enough to repay the debt
        // assert a full withdraw reverts
        vm_std_cheats.prank(user);
        vm_std_cheats.expectRevert();
        vault.withdraw();
    }

    // TODO: Refactor test placement
    function testWithdraw_CancelsCorrespondingDebt() public {
        IVault yvDAI = strategy.yVault();
        uint256 initialWant = 10 * (10 ** vault.decimals());
        uint256 _withdrawPct = 10;

        actions.depositAndHarvestStrategy(user, vault, strategy, initialWant);

        uint256 vaultShares = yvDAI.balanceOf(address(strategy));

        // withdraw 
        uint256 maxWithdraw = (initialWant * _withdrawPct) / 100;
        vm_std_cheats.prank(user);
        uint256 withdrawResult = vault.withdraw(maxWithdraw);

        // assert the withdraw cancled correspinding debt
        assertEq(withdrawResult, maxWithdraw);
        uint256 expectedShares = (vaultShares * (100 - _withdrawPct)) / 100;
        assertRelApproxEq(yvDAI.balanceOf(address(strategy)), expectedShares, DELTA);
    }

    function testTendTrigger_DebtUnderDust_ReturnsFalse() public {
        // Pick amount in want that generates 'floor' debt ~5% less than threshold.
        uint256 wantPrice = MakerDaiDelegateLib.getSpotPrice(ilk);
        uint256 floorInWant = (strategy.collateralizationRatio() * debtFloorDai) / wantPrice;
        uint256 _amount = (floorInWant * 95) / 100;

        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // assert tend trigger returns false
        assertTrue(!strategy.tendTrigger(1));
    }

    function testTendTrigger_FundsInCdpButNoDebt_ReturnsFalse() public {
        IVault yvDAI = strategy.yVault();
        uint256 initialWant = 10 * (10 ** vault.decimals());
        actions.depositAndHarvestStrategy(user, vault, strategy, initialWant);

        // send profits to yVault to simulate ~1% yield
        uint256 profit = (yvDAI.totalAssets() * 1) / 100;
        tip(address(dai), whale, profit);
        vm_std_cheats.prank(whale);
        dai.transfer(address(yvDAI), profit);
        
        // TODO: Determine if second harvest used in brownie test required.
        //       See StrategyEmergencyDebtRepayment.t.sol#L31 for details.

        // repay debt
        vm_std_cheats.prank(gov);
        strategy.emergencyDebtRepayment(0);

        // assert tend trigger returns false
        assertGt(strategy.balanceOfMakerVault(), 0);
        assertEq(strategy.balanceOfDebt(), 0);
        assertGt(strategy.getCurrentMakerVaultRatio() / 1e18, 1000);
        assertTrue(!strategy.tendTrigger(1));
    }
}
