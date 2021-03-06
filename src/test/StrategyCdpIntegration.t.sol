// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {IVault} from "../interfaces/yearn/IVault.sol";

contract StrategyCdpIntegrationTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    function testDaiMintedAfterDeposit() public {
        // NOTE: This test just asserts DAI gets minted and deposited
        //       into the yVault. Thus, no fuzzing is required.
        uint256 _amount = 25 * (10 ** vault.decimals());
        tip(address(want), user, _amount);

        // assert yvDAI vault does not have DAI
        IVault yvDAI = strategy.yVault();
        assertEq(yvDAI.balanceOf(address(strategy)), 0);

        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // assert minted DAI ends up in yvDAI
        assertEq(dai.balanceOf(address(strategy)), 0);
        assertTrue(yvDAI.balanceOf(address(strategy)) > 0);
    }

    function testDaiMintedMatchesCollateralizationRatio(uint256 _amount) public {
        // fuzzer needs to avoid any deposit amount worth less than 50k DAI
        vm_std_cheats.assume(_amount > 5 ether && _amount < maxFuzzAmt);
        tip(address(want), user, _amount);

        // assert yvDAI vault does not have DAI
        IVault yvDAI = strategy.yVault();
        assertEq(yvDAI.balanceOf(address(strategy)), 0);

        // deposit funds into the vault
        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // assert minted DAI matches collateralization ratio
        uint256 expectedRatio = strategy.collateralizationRatio();
        uint256 currentRatio = strategy.getCurrentMakerVaultRatio();
        assertRelApproxEq(expectedRatio, currentRatio, DELTA);
    }

    // NOTE: This test relies on correct collateralization ratios
    //       verified in testDaiMintedMatchesCollateralizationRatio.
    function testDelegatedAssetsPricing(uint256 _amount) public {
        // fuzzer needs to avoid any deposit amount worth less than 50k DAI
        vm_std_cheats.assume(_amount > 5 ether && _amount < maxFuzzAmt);
        tip(address(want), user, _amount);

        // assert yvDAI vault does not have DAI
        IVault yvDAI = strategy.yVault();
        assertEq(yvDAI.balanceOf(address(strategy)), 0);

        actions.depositAndHarvestStrategy(user, vault, strategy, _amount);

        // assert delegated assets matches up with deposited amount
        uint256 delegatedAssets = strategy.delegatedAssets();
        // collatRatio is in 1e18, inflate amount by 1e18 to avoid unit loss
        uint256 expectedAssets = (_amount * 10**18) / strategy.collateralizationRatio();
        assertRelApproxEq(expectedAssets, delegatedAssets, DELTA);
    }
}
