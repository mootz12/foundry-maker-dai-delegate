// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "forge-std/console.sol";
import {StrategyFixture} from "./utils/StrategyFixture.sol";
import "../interfaces/yearn/IOSMedianizer.sol";

// NOTE: if the name of the strat or file changes this needs to be updated
import {Strategy} from "../Strategy.sol";

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
        vm_std_cheats.prank(user);
        want.approve(address(vault), _amount);
        vm_std_cheats.prank(user);
        vault.deposit(_amount);
        skip(1);
        console.log(strategy.strategist());
        vm_std_cheats.prank(strategist);
        strategy.harvest();
        assertRelApproxEq(strategy.estimatedTotalAssets(), _amount, DELTA);

        // Migrate to a new strategy
        vm_std_cheats.prank(strategist);
        Strategy newStrategy = Strategy(
            deployStrategy(
                address(vault),
                address(yVault),
                strategyName,
                ilk,
                address(gemJoin),
                address(wantToUSDOSMProxy),
                address(chainlinkWantToETHPriceFeed)
            )
        );
        // Strategy newStrategy = 
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
}
