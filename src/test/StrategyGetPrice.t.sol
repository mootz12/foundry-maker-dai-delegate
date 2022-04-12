// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "forge-std/console.sol";
import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {TestCustomOSM} from "./utils/TestCustomOSM.sol";

// used to fetch prices
import "../libraries/MakerDaiDelegateLib.sol";

contract StrategyGetPriceTest is StrategyFixture {
    // Artifact paths for deploying from the deps folder, assumes that the command is run from
    // the project root.
    string internal constant OSM_ARTIFACT = "out/TestCustomOSM.sol/TestCustomOSM.json";
    TestCustomOSM internal mockedOsm;

    function setUp() public override {
        super.setUp();
        // deploy a custom OSM contract
        address mockedOsmAddress = deployCode(OSM_ARTIFACT);
        mockedOsm = TestCustomOSM(mockedOsmAddress);
    }

    function testBothOsmReverts_UseSpotPrice() public {
        strategy.setCustomOSM(mockedOsm);
        mockedOsm.setCurrentPrice(0, true);
        mockedOsm.setFuturePrice(0, true);

        uint256 strategyPrice = strategy._getPrice();

        uint256 expectedPrice = MakerDaiDelegateLib.getSpotPrice(ilk);
        assertGt(strategyPrice, 0);
        assertEq(strategyPrice, expectedPrice);
    }

    function testFutureOsmReverts_CurrentPriceMin_UseCurrentPrice() public {
        strategy.setCustomOSM(mockedOsm);
        uint256 spotPrice = MakerDaiDelegateLib.getSpotPrice(ilk);
        uint256 currentPrice = spotPrice - 1e18;

        mockedOsm.setCurrentPrice(currentPrice, false);
        mockedOsm.setFuturePrice(0, true);

        uint256 strategyPrice = strategy._getPrice();

        assertGt(strategyPrice, 0);
        assertEq(strategyPrice, currentPrice);
    }

    function testFutureOsmReverts_CurrentPriceMax_UseSpotPrice() public {
        strategy.setCustomOSM(mockedOsm);
        uint256 spotPrice = MakerDaiDelegateLib.getSpotPrice(ilk);
        uint256 currentPrice = spotPrice + 1e18;

        mockedOsm.setCurrentPrice(currentPrice, false);
        mockedOsm.setFuturePrice(0, true);

        uint256 strategyPrice = strategy._getPrice();

        assertGt(strategyPrice, 0);
        assertEq(strategyPrice, spotPrice);
    }

    function testCurrentOsmReverts_FuturePriceMin_UseFuturePrice() public {
        strategy.setCustomOSM(mockedOsm);
        uint256 spotPrice = MakerDaiDelegateLib.getSpotPrice(ilk);
        uint256 futurePrice = spotPrice - 1e18;

        mockedOsm.setCurrentPrice(0, true);
        mockedOsm.setFuturePrice(futurePrice, false);

        uint256 strategyPrice = strategy._getPrice();

        assertGt(strategyPrice, 0);
        assertEq(strategyPrice, futurePrice);
    }

    function testCurrentOsmReverts_FuturePriceMax_UseSpotPrice() public {
        strategy.setCustomOSM(mockedOsm);
        uint256 spotPrice = MakerDaiDelegateLib.getSpotPrice(ilk);
        uint256 futurePrice = spotPrice + 1e18;

        mockedOsm.setCurrentPrice(0, true);
        mockedOsm.setFuturePrice(futurePrice, false);

        uint256 strategyPrice = strategy._getPrice();

        assertGt(strategyPrice, 0);
        assertEq(strategyPrice, spotPrice);
    }

    function testBothOsmReturns_SpotPriceMin_UseMinPrice() public {
        strategy.setCustomOSM(mockedOsm);
        uint256 spotPrice = MakerDaiDelegateLib.getSpotPrice(ilk);
        uint256 currentPrice = spotPrice + 1e18;
        uint256 futurePrice = spotPrice + 2e18;

        mockedOsm.setCurrentPrice(currentPrice, false);
        mockedOsm.setFuturePrice(futurePrice, false);

        uint256 strategyPrice = strategy._getPrice();

        assertGt(strategyPrice, 0);
        assertEq(strategyPrice, spotPrice);
    }

    function testBothOsmReturns_CurrentPriceMin_UseMinPrice() public {
        strategy.setCustomOSM(mockedOsm);
        uint256 spotPrice = MakerDaiDelegateLib.getSpotPrice(ilk);
        uint256 currentPrice = spotPrice - 1e18;
        uint256 futurePrice = spotPrice + 2e18;

        mockedOsm.setCurrentPrice(currentPrice, false);
        mockedOsm.setFuturePrice(futurePrice, false);

        uint256 strategyPrice = strategy._getPrice();

        assertGt(strategyPrice, 0);
        assertEq(strategyPrice, currentPrice);
    }

    function testBothOsmReturns_FuturePriceMin_UseMinPrice() public {
        strategy.setCustomOSM(mockedOsm);
        uint256 spotPrice = MakerDaiDelegateLib.getSpotPrice(ilk);
        uint256 currentPrice = spotPrice + 1e18;
        uint256 futurePrice = spotPrice - 2e18;

        mockedOsm.setCurrentPrice(currentPrice, false);
        mockedOsm.setFuturePrice(futurePrice, false);

        uint256 strategyPrice = strategy._getPrice();

        assertGt(strategyPrice, 0);
        assertEq(strategyPrice, futurePrice);
    }
}
