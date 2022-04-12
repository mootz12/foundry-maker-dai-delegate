// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
import "forge-std/console.sol";

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {IVault} from "../interfaces/yearn/IVault.sol";

contract StrategyOperationsTest is StrategyFixture {
    // setup is run on before each test
    function setUp() public override {
        // setup vault
        super.setUp();
    }

    function testSetupVaultOK() public {
        console.log("address of vault", address(vault));
        assertTrue(address(0) != address(vault));
        assertEq(vault.token(), address(want));
        assertEq(vault.depositLimit(), type(uint256).max);
    }

    // TODO: add additional check on strat params
    function testSetupStrategyOK() public {
        console.log("address of strategy", address(strategy));
        assertTrue(address(0) != address(strategy));
        assertEq(address(strategy.vault()), address(vault));
    }

    /// Test Operations
    function testStrategyOperation(uint256 _amount) public {
        vm_std_cheats.assume(
            _amount > minFuzzAmt && _amount < maxFuzzAmt
        );
        tip(address(want), user, _amount);

        // deposit
        uint256 balanceBefore = want.balanceOf(address(user));
        vm_std_cheats.prank(user);
        want.approve(address(vault), _amount);
        vm_std_cheats.prank(user);
        vault.deposit(_amount);
        assertRelApproxEq(want.balanceOf(address(vault)), _amount, DELTA);

        // harvest
        skip(60 * 3); // skip 3 minutes
        vm_std_cheats.prank(strategist);
        strategy.harvest();
        assertRelApproxEq(strategy.estimatedTotalAssets(), _amount, DELTA);

        // tend
        vm_std_cheats.prank(strategist);
        strategy.tend();

        // withdraw
        vm_std_cheats.prank(user);
        vault.withdraw();

        assertRelApproxEq(want.balanceOf(user), balanceBefore, DELTA);
    }

    function testEmergencyExit(uint256 _amount) public {
        vm_std_cheats.assume(
            _amount > minFuzzAmt && _amount < maxFuzzAmt
        );
        tip(address(want), user, _amount);

        // Deposit to the vault
        vm_std_cheats.prank(user);
        want.approve(address(vault), _amount);
        vm_std_cheats.prank(user);
        vault.deposit(_amount);
        skip(1);
        vm_std_cheats.prank(strategist);
        strategy.harvest();
        assertRelApproxEq(strategy.estimatedTotalAssets(), _amount, DELTA);

        // set emergency and exit
        vm_std_cheats.prank(gov);
        strategy.setEmergencyExit();
        skip(1);
        vm_std_cheats.prank(strategist);
        strategy.harvest();
        assertLt(strategy.estimatedTotalAssets(), _amount);
    }

    function testProfitableHarvest(uint256 _amount) public {
        IVault yvDAI = strategy.yVault();
        vm_std_cheats.assume(
            _amount > minFuzzAmt && _amount < maxFuzzAmt
        );
        tip(address(want), user, _amount);

        // Deposit to the vault
        vm_std_cheats.prank(user);
        want.approve(address(vault), _amount);
        vm_std_cheats.prank(user);
        vault.deposit(_amount);
        assertRelApproxEq(want.balanceOf(address(vault)), _amount, DELTA);

        // Harvest 1: Send funds through the strategy
        skip(1);
        vm_std_cheats.prank(strategist);
        strategy.harvest();
        assertRelApproxEq(strategy.estimatedTotalAssets(), _amount, DELTA);

        // simulate profit in yVault
        uint256 vaultProfit = (yvDAI.totalAssets() * 2) / 100;
        tip(address(dai), whale, vaultProfit);
        vm_std_cheats.prank(whale);
        dai.transfer(address(yvDAI), vaultProfit);

        // Harvest 2: Realize profit
        uint256 beforePps = vault.pricePerShare();
        skip(1);
        vm_std_cheats.prank(strategist);
        strategy.harvest();
        skip(6 hours);

        uint256 profit = want.balanceOf(address(vault));
        assertGt(strategy.estimatedTotalAssets() + profit, _amount);
        assertGt(vault.pricePerShare(), beforePps);
    }

    function testChangeDebt(uint256 _amount) public {
        vm_std_cheats.assume(
            _amount > minFuzzAmt && _amount < maxFuzzAmt
        );
        tip(address(want), user, _amount);

        // Deposit to the vault and harvest
        vm_std_cheats.prank(user);
        want.approve(address(vault), _amount);
        vm_std_cheats.prank(user);
        vault.deposit(_amount);
        vm_std_cheats.prank(gov);
        vault.updateStrategyDebtRatio(address(strategy), 5_000);
        skip(1);
        vm_std_cheats.prank(strategist);
        strategy.harvest();
        uint256 half = uint256(_amount / 2);
        assertRelApproxEq(strategy.estimatedTotalAssets(), half, DELTA);

        vm_std_cheats.prank(gov);
        vault.updateStrategyDebtRatio(address(strategy), 10_000);
        skip(1);
        vm_std_cheats.prank(strategist);
        strategy.harvest();
        assertRelApproxEq(strategy.estimatedTotalAssets(), _amount, DELTA);

        // In order to pass these tests, you will need to implement prepareReturn.
        // TODO: uncomment the following lines.
        vm_std_cheats.prank(gov);
        vault.updateStrategyDebtRatio(address(strategy), 5_000);
        skip(1);
        vm_std_cheats.prank(strategist);
        strategy.harvest();
        assertRelApproxEq(strategy.estimatedTotalAssets(), half, DELTA);
    }

    function testSweep(uint256 _amount) public {
        vm_std_cheats.assume(
            _amount > minFuzzAmt && _amount < maxFuzzAmt
        );
        tip(address(want), user, _amount);

        // Strategy want token doesn't work
        vm_std_cheats.prank(user);
        want.transfer(address(strategy), _amount);
        assertEq(address(want), address(strategy.want()));
        assertGt(want.balanceOf(address(strategy)), 0);

        vm_std_cheats.prank(gov);
        vm_std_cheats.expectRevert("!want");
        strategy.sweep(address(want));

        // Vault share token doesn't work
        vm_std_cheats.prank(gov);
        vm_std_cheats.expectRevert("!shares");
        strategy.sweep(address(vault));

        uint256 beforeBalance = weth.balanceOf(gov);
        uint256 wethAmount = 1 ether;
        tip(address(weth), user, wethAmount);
        vm_std_cheats.prank(user);
        weth.transfer(address(strategy), wethAmount);
        assertNeq(address(weth), address(strategy.want()));
        assertEq(weth.balanceOf(user), 0);
        vm_std_cheats.prank(gov);
        strategy.sweep(address(weth));
        assertRelApproxEq(
            weth.balanceOf(gov),
            wethAmount + beforeBalance,
            DELTA
        );
    }

    function testTriggers(uint256 _amount) public {
        vm_std_cheats.assume(
            _amount > minFuzzAmt && _amount < maxFuzzAmt
        );
        tip(address(want), user, _amount);

        // Deposit to the vault and harvest
        vm_std_cheats.prank(user);
        want.approve(address(vault), _amount);
        vm_std_cheats.prank(user);
        vault.deposit(_amount);
        vm_std_cheats.prank(gov);
        vault.updateStrategyDebtRatio(address(strategy), 5_000);
        skip(1);
        vm_std_cheats.prank(strategist);
        strategy.harvest();

        strategy.harvestTrigger(0);
        strategy.tendTrigger(0);
    }
}
