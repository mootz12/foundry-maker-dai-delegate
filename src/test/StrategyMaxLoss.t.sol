// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "forge-std/console.sol";
import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {IVault} from "../interfaces/yearn/IVault.sol";

contract StrategyMaxLossTest is StrategyFixture {
    // Maximum loss on withdrawal from yVault - Strategy.sol#L37
    uint256 internal constant MAX_LOSS_BPS = 10000;

    function setUp() public override {
        super.setUp();
    }

    function testSetMaxLoss_OverMaxBSP_Reverts() public {
        vm_std_cheats.prank(gov);
        vm_std_cheats.expectRevert();
        strategy.setMaxLoss(MAX_LOSS_BPS + 1);
    }

    function testSetMaxLoss_AtMaxBSP_SetsMaxLoss() public {
        vm_std_cheats.prank(gov);
        strategy.setMaxLoss(MAX_LOSS_BPS);

        assertEq(strategy.maxLoss(), MAX_LOSS_BPS);
    }

    function testSetMaxLoss_LessThanMaxBSP_SetsMaxLoss() public {
        vm_std_cheats.prank(gov);
        strategy.setMaxLoss(MAX_LOSS_BPS - 1);

        assertEq(strategy.maxLoss(), MAX_LOSS_BPS - 1);
    }
}
