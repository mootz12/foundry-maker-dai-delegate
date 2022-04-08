// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "forge-std/console.sol";
import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {IVault, StrategyParams} from "../interfaces/yearn/IVault.sol";

// used to fetch prices
import "../libraries/MakerDaiDelegateLib.sol";

// NOTE: if the name of the strat or file changes this needs to be updated
import {Strategy} from "../Strategy.sol";

contract StrategyDirectTransferTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    function testDirectTransfer_IncrementsEstTotalAssets() public {
        uint256 initialEstAssets = strategy.estimatedTotalAssets();

        uint256 _amount = 10 * (10 ** vault.decimals());
        tip(address(want), user, _amount);
        vm_std_cheats.prank(user);
        want.transfer(address(strategy), _amount);

        assertEq(_amount + initialEstAssets, strategy.estimatedTotalAssets());
    }

    function testDirectTransfer_IncrementsProfits() public {
        uint256 initialGain = vault.strategies(address(strategy)).totalGain;
        // initialize pool with large deposit to avoid healthcheck profit limit
        actions.depositAndHarvestStrategy(user, vault, strategy, 1234 ether);

        uint256 _amount = 10 * (10 ** vault.decimals());
        tip(address(want), user, _amount);
        vm_std_cheats.prank(user);
        want.transfer(address(strategy), _amount);

        // re-harvest strategy
        skip(1);
        vm_std_cheats.prank(gov);
        strategy.harvest();

        assertRelApproxEq(_amount + initialGain, vault.strategies(address(strategy)).totalGain, DELTA);
    }

    function testDirectTransfer_IncrementsProfitsWithActualProfits() public {
        IVault yvDAI = strategy.yVault();
        uint256 initialGain = vault.strategies(address(strategy)).totalGain;
        // initialize pool with large deposit to avoid healthcheck profit limit
        actions.depositAndHarvestStrategy(user, vault, strategy, 1234 ether);

        // send some profit to yvault
        uint256 profitAmount = 20000 ether;
        tip(address(dai), user, profitAmount);
        vm_std_cheats.prank(user);
        dai.transfer(address(yvDAI), profitAmount);

        // allow time to pass
        skip(1 days);
        vm_std_cheats.roll(block.number + 1);

        // direct transfer
        uint256 _amount = 10 * (10 ** vault.decimals());
        tip(address(want), user, _amount);
        vm_std_cheats.prank(user);
        want.transfer(address(strategy), _amount);

        // allow time to pass
        skip(1 days);
        vm_std_cheats.roll(block.number + 1);

        // re-harvest strategy
        skip(1);
        vm_std_cheats.prank(gov);
        strategy.harvest();

        assertGt(vault.strategies(address(strategy)).totalGain, initialGain + _amount);
    }

    function testBorrowTokenTransfer_SendsToYVault() public {
        // initialize pool with large deposit to avoid healthcheck profit limit
        actions.depositAndHarvestStrategy(user, vault, strategy, 1234 ether);

        uint256 _amount = 1000 * (10 ** vault.decimals());
        tip(address(dai), user, _amount);
        vm_std_cheats.prank(user);
        dai.transfer(address(strategy), _amount);

        // re-harvest strategy
        skip(1);
        vm_std_cheats.prank(gov);
        strategy.harvest();

        assertEq(0, dai.balanceOf(address(strategy)));
    }

    function testBorrowTokenTransfer_IncrementsProfits() public {
        // initialize pool with large deposit to avoid healthcheck profit limit
        actions.depositAndHarvestStrategy(user, vault, strategy, 1234 ether);

        uint256 _amount = 1000 * (10 ** vault.decimals());
        tip(address(dai), user, _amount);
        vm_std_cheats.prank(user);
        dai.transfer(address(strategy), _amount);

        // re-harvest strategy
        skip(1);
        vm_std_cheats.prank(gov);
        strategy.harvest();

        // check amount in want was deposited
        uint256 daiInWant = MakerDaiDelegateLib.getSpotPrice(ilk);
        uint256 transferInWant = (_amount * 1e18) / daiInWant;

        // wait a minute!
        skip(1 minutes);
        vm_std_cheats.roll(block.number + 1);

        // assert profit increases by transferInWant net fees and slippage (max 5%)
        assertGt(vault.strategies(address(strategy)).totalGain, (transferInWant * 95) / 100);
    }

    function testDeposit_DoesNotIncrementProfits() public {
        uint256 initialGain = vault.strategies(address(strategy)).totalGain;

        actions.depositAndHarvestStrategy(user, vault, strategy, 1234 ether);

        assertEq(initialGain, vault.strategies(address(strategy)).totalGain);
    }
}
