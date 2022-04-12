// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "forge-std/console.sol";
import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {IVault} from "../interfaces/yearn/IVault.sol";
import {ManagerLike} from "../interfaces/maker/IMaker.sol";

contract StrategyAccessControlTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    function testSetCollateralizationRationAcl() public {
        vm_std_cheats.prank(gov);
        strategy.setCollateralizationRatio(200 * 1e18);
        assertEq(strategy.collateralizationRatio(), 200 * 1e18);

        vm_std_cheats.prank(management);
        strategy.setCollateralizationRatio(201 * 1e18);
        assertEq(strategy.collateralizationRatio(), 201 * 1e18);

        vm_std_cheats.prank(strategist);
        strategy.setCollateralizationRatio(202 * 1e18);
        assertEq(strategy.collateralizationRatio(), 202 * 1e18);

        vm_std_cheats.prank(guardian);
        strategy.setCollateralizationRatio(203 * 1e18);
        assertEq(strategy.collateralizationRatio(), 203 * 1e18);

        vm_std_cheats.prank(user);
        vm_std_cheats.expectRevert("!authorized");
        strategy.setCollateralizationRatio(204 * 1e18);
    }

    function testSetRebalanceToleranceAcl() public {
        vm_std_cheats.prank(gov);
        strategy.setRebalanceTolerance(5);
        assertEq(strategy.rebalanceTolerance(), 5);

        vm_std_cheats.prank(management);
        strategy.setRebalanceTolerance(4);
        assertEq(strategy.rebalanceTolerance(), 4);

        vm_std_cheats.prank(strategist);
        strategy.setRebalanceTolerance(3);
        assertEq(strategy.rebalanceTolerance(), 3);

        vm_std_cheats.prank(guardian);
        strategy.setRebalanceTolerance(2);
        assertEq(strategy.rebalanceTolerance(), 2);

        vm_std_cheats.prank(user);
        vm_std_cheats.expectRevert("!authorized");
        strategy.setRebalanceTolerance(1);
    }

    function testSetMaxLossAcl() public {
        vm_std_cheats.prank(gov);
        strategy.setMaxLoss(10);
        assertEq(strategy.maxLoss(), 10);

        vm_std_cheats.prank(management);
        strategy.setMaxLoss(11);
        assertEq(strategy.maxLoss(), 11);

        vm_std_cheats.prank(strategist);
        vm_std_cheats.expectRevert("!authorized");
        strategy.setMaxLoss(12);

        vm_std_cheats.prank(guardian);
        vm_std_cheats.expectRevert("!authorized");
        strategy.setMaxLoss(13);

        vm_std_cheats.prank(user);
        vm_std_cheats.expectRevert("!authorized");
        strategy.setMaxLoss(14);
    }

    function testSetLeaveDebtBehind() public {
        vm_std_cheats.prank(gov);
        strategy.setLeaveDebtBehind(true);
        assertTrue(strategy.leaveDebtBehind());

        vm_std_cheats.prank(management);
        strategy.setLeaveDebtBehind(false);
        assertTrue(!strategy.leaveDebtBehind());

        vm_std_cheats.prank(strategist);
        strategy.setLeaveDebtBehind(true);
        assertTrue(strategy.leaveDebtBehind());

        vm_std_cheats.prank(guardian);
        strategy.setLeaveDebtBehind(false);
        assertTrue(!strategy.leaveDebtBehind());

        vm_std_cheats.prank(user);
        vm_std_cheats.expectRevert("!authorized");
        strategy.setLeaveDebtBehind(true);
    }

    function testSwitchDexAcl() public {
        address sushiswap = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F; // default
        address uniswap = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

        // ensure gov can switch back and forth
        vm_std_cheats.prank(gov);
        strategy.switchDex(true);
        assertEq(address(strategy.router()), uniswap);

        vm_std_cheats.prank(gov);
        strategy.switchDex(false);
        assertEq(address(strategy.router()), sushiswap);

        // ensure management can switch back and forth
        vm_std_cheats.prank(management);
        strategy.switchDex(true);
        assertEq(address(strategy.router()), uniswap);

        vm_std_cheats.prank(management);
        strategy.switchDex(false);
        assertEq(address(strategy.router()), sushiswap);

        vm_std_cheats.prank(strategist);
        vm_std_cheats.expectRevert("!authorized");
        strategy.switchDex(true);

        vm_std_cheats.prank(guardian);
        vm_std_cheats.expectRevert("!authorized");
        strategy.switchDex(true);

        vm_std_cheats.prank(user);
        vm_std_cheats.expectRevert("!authorized");
        strategy.switchDex(true);
    }

    function testShiftCdpAcl() public {
        // cdp-not-allowed should be the revert msg when allowed / we are shifting to a random cdp
        vm_std_cheats.prank(gov);
        vm_std_cheats.expectRevert("cdp-not-allowed");
        strategy.shiftToCdp(123);

        vm_std_cheats.prank(management);
        vm_std_cheats.expectRevert("!authorized");
        strategy.shiftToCdp(123);

        vm_std_cheats.prank(strategist);
        vm_std_cheats.expectRevert("!authorized");
        strategy.shiftToCdp(123);

        vm_std_cheats.prank(guardian);
        vm_std_cheats.expectRevert("!authorized");
        strategy.shiftToCdp(123);

        vm_std_cheats.prank(user);
        vm_std_cheats.expectRevert("!authorized");
        strategy.shiftToCdp(123);
    }

    function testAllowManagingCdpAcl() public {
        ManagerLike cdpManager = ManagerLike(0x5ef30b9986345249bc32d8928B7ee64DE9435E39);
        uint256 cdp = strategy.cdpId();

        // verify non gov accounts can't grant rights
        vm_std_cheats.prank(management);
        vm_std_cheats.expectRevert("!authorized");
        strategy.grantCdpManagingRightsToUser(user, true);

        vm_std_cheats.prank(strategist);
        vm_std_cheats.expectRevert("!authorized");
        strategy.grantCdpManagingRightsToUser(user, true);

        vm_std_cheats.prank(guardian);
        vm_std_cheats.expectRevert("!authorized");
        strategy.grantCdpManagingRightsToUser(user, true);

        vm_std_cheats.prank(user);
        vm_std_cheats.expectRevert("!authorized");
        strategy.grantCdpManagingRightsToUser(user, true);

        // verify gov account can grant rights
        vm_std_cheats.prank(gov);
        strategy.grantCdpManagingRightsToUser(user, true);
        vm_std_cheats.prank(user);
        cdpManager.cdpAllow(cdp, guardian, 1);

        // verify gov account can remove rights
        vm_std_cheats.prank(gov);
        strategy.grantCdpManagingRightsToUser(user, false);
        vm_std_cheats.prank(user);
        vm_std_cheats.expectRevert("cdp-not-allowed");
        cdpManager.cdpAllow(cdp, guardian, 1);
    }

    function testMigrateDaiYVaultAcl() public {
        // This test does not verify the migrate yvDAI vault functionality.
        // It only confirms the access control on the function.
        // See StrategyMigrationTest for migration functionality tests.
        address newDaiVaultAddr = deployVault(
            tokenAddrs["DAI"],
            gov,
            rewards,
            "",
            "",
            guardian,
            management
        );
        IVault newDaiVault = IVault(newDaiVaultAddr);

        // verify non-gov addresses get reverted
        vm_std_cheats.prank(management);
        vm_std_cheats.expectRevert("!authorized");
        strategy.migrateToNewDaiYVault(newDaiVault);

        vm_std_cheats.prank(strategist);
        vm_std_cheats.expectRevert("!authorized");
        strategy.migrateToNewDaiYVault(newDaiVault);

        vm_std_cheats.prank(guardian);
        vm_std_cheats.expectRevert("!authorized");
        strategy.migrateToNewDaiYVault(newDaiVault);

        vm_std_cheats.prank(user);
        vm_std_cheats.expectRevert("!authorized");
        strategy.migrateToNewDaiYVault(newDaiVault);

        // verify gov call does not revert for !authorized
        vm_std_cheats.prank(gov);
        strategy.migrateToNewDaiYVault(newDaiVault);
    }

    function testEmergencyDebtRepaymentAcl() public {
        vm_std_cheats.prank(gov);
        strategy.emergencyDebtRepayment(0);
        assertEq(strategy.balanceOfDebt(), 0);

        vm_std_cheats.prank(management);
        strategy.emergencyDebtRepayment(0);
        assertEq(strategy.balanceOfDebt(), 0);

        vm_std_cheats.prank(strategist);
        vm_std_cheats.expectRevert("!authorized");
        strategy.emergencyDebtRepayment(0);

        vm_std_cheats.prank(guardian);
        vm_std_cheats.expectRevert("!authorized");
        strategy.emergencyDebtRepayment(0);

        vm_std_cheats.prank(user);
        vm_std_cheats.expectRevert("!authorized");
        strategy.emergencyDebtRepayment(0);
    }

    function testSetMaxAcceptableBaseFeeAcl() public {
        vm_std_cheats.prank(gov);
        strategy.setMaxAcceptableBaseFee(100 * 1e9);
        assertEq(strategy.maxAcceptableBaseFee(), 100 * 1e9);

        vm_std_cheats.prank(management);
        strategy.setMaxAcceptableBaseFee(90 * 1e9);
        assertEq(strategy.maxAcceptableBaseFee(), 90 * 1e9);

        vm_std_cheats.prank(strategist);
        strategy.setMaxAcceptableBaseFee(80 * 1e9);
        assertEq(strategy.maxAcceptableBaseFee(), 80 * 1e9);

        vm_std_cheats.prank(guardian);
        strategy.setMaxAcceptableBaseFee(70 * 1e9);
        assertEq(strategy.maxAcceptableBaseFee(), 70 * 1e9);

        vm_std_cheats.prank(user);
        vm_std_cheats.expectRevert("!authorized");
        strategy.setMaxAcceptableBaseFee(60 * 1e9);
    }

    function testRepayDebtAcl() public {
        vm_std_cheats.prank(gov);
        strategy.repayDebtWithDaiBalance(1);

        vm_std_cheats.prank(management);
        strategy.repayDebtWithDaiBalance(2);

        vm_std_cheats.prank(strategist);
        vm_std_cheats.expectRevert("!authorized");
        strategy.repayDebtWithDaiBalance(3);

        vm_std_cheats.prank(guardian);
        vm_std_cheats.expectRevert("!authorized");
        strategy.repayDebtWithDaiBalance(4);

        vm_std_cheats.prank(keeper);
        vm_std_cheats.expectRevert("!authorized");
        strategy.repayDebtWithDaiBalance(5);

        vm_std_cheats.prank(user);
        vm_std_cheats.expectRevert("!authorized");
        strategy.repayDebtWithDaiBalance(6);
    }
}
