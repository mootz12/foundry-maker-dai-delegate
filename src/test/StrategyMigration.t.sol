// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "forge-std/console.sol";
import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {IVault} from "../interfaces/yearn/IVault.sol";
import "../interfaces/yearn/IOSMedianizer.sol";

// NOTE: if the name of the strat or file changes this needs to be updated
import {TestStrategy} from "./utils/TestStrategy.sol";

contract StrategyMigrationTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    // TODO: Test breaks at 1.5 YFI, determine why.
    //       Original brownie test not passing either.
    function testMigration(uint256 _amount) public {
        vm_std_cheats.assume(_amount > 0.1 ether && _amount < 1.4 ether);
        tip(address(want), user, _amount);

        // Deposit to the vault and harvest
        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);
        assertRelApproxEq(strategy.estimatedTotalAssets(), _amount, DELTA);

        // Migrate to a new strategy
        vm_std_cheats.prank(strategist);
        TestStrategy newStrategy = TestStrategy(
            deployTestStrategy(
                address(vault),
                address(yVault),
                strategyName,
                ilk,
                address(gemJoin),
                address(wantToUSDOSMProxy),
                address(chainlinkWantToETHPriceFeed)
            )
        );
        vm_std_cheats.label(address(newStrategy), "newStrategy");
        vm_std_cheats.prank(gov);
        vault.migrateStrategy(address(strategy), address(newStrategy));
        
        // Allow the new strategy to query the OSM proxy
        IOSMedianizer osmProxy = IOSMedianizer(strategy.wantToUSDOSMProxy());
        vm_std_cheats.prank(gov);
        osmProxy.setAuthorized(address(newStrategy));

        uint256 origCdpId = strategy.cdpId();
        vm_std_cheats.prank(gov);
        newStrategy.shiftToCdp(origCdpId);

        assertEq(newStrategy.balanceOfMakerVault(), _amount);
        assertEq(newStrategy.cdpId(), origCdpId);
        assertEq(vault.strategies(address(newStrategy)).totalDebt, _amount);
        assertRelApproxEq(newStrategy.estimatedTotalAssets(), _amount, DELTA);
    }

    function testYVaultMigrationWithNoAssets() public {
        IVault yvDAI = strategy.yVault();
        uint256 _amount = 10 * (10 ** vault.decimals());
        tip(address(want), user, _amount);

        actions.userDeposit(user, vault, _amount);

        assertEq(strategy.estimatedTotalAssets(), 0);

        // make new dai yVault
        address newDaiVaultAddress = deployVault(
            address(dai),
            gov,
            rewards,
            "",
            "",
            guardian,
            management
        );
        IVault newDaiVault = IVault(newDaiVaultAddress);

        // migrate to and harvest with new vault
        vm_std_cheats.prank(gov);
        strategy.migrateToNewDaiYVault(newDaiVault);

        skip(1);
        vm_std_cheats.prank(gov);
        strategy.harvest();

        // assert dai deposited into new vault
        assertGt(newDaiVault.balanceOf(address(strategy)), 0);
        // assert old vault is empty
        assertEq(yvDAI.balanceOf(address(strategy)), 0);
    }
}
