// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ManagerLike} from "../interfaces/maker/IMaker.sol";
import {Strategy} from "../Strategy.sol";
import "forge-std/console.sol";

contract StrategyCdpSetup is StrategyFixture {
    // Events to validate correct Cdp Setup
    event NewCdp(address indexed usr, address indexed own, uint indexed cdp);

    address public makerManager = 0x5ef30b9986345249bc32d8928B7ee64DE9435E39;

    function setUp() public override {
        // Don't call super's setup
        // Tests validate actions taken during strategy deployment

        // Deploy a vault during setup to allow for strategy initialization
        _setTokenAddrs();
        _setTokenPrices();
        weth = IERC20(tokenAddrs["WETH"]);
        want = IERC20(tokenAddrs["YFI"]);
        deployVault(
            address(want),
            gov,
            rewards,
            "",
            "",
            guardian,
            management
        );
        _setLabels();
    }

    function testDeployCreatesNewMakerVault() public {
        // Don't validate address data on newcdp event emit
        // -> usr/own are yet to be deployed strategy
        // -> cpdId can change if a new YFI-A maker vault is created on mainnet
        vm_std_cheats.expectEmit(false, false, false, false);
        emit NewCdp(address(strategy), address(strategy), 27958);
        vm_std_cheats.prank(strategist);
        deployStrategy(
            address(vault),
            yVault,
            strategyName,
            ilk,
            gemJoin,
            wantToUSDOSMProxy,
            chainlinkWantToETHPriceFeed
        );
    }

    function testDeployCreatesYFIAMakerVault() public {
        // deploy strategy
        vm_std_cheats.prank(strategist);
        address _strategy = deployStrategy(
            address(vault),
            yVault,
            strategyName,
            ilk,
            gemJoin,
            wantToUSDOSMProxy,
            chainlinkWantToETHPriceFeed
        );
        strategy = Strategy(_strategy);

        // verify vault is of the asset type specified on creation
        ManagerLike managerLike = ManagerLike(makerManager);
        bytes32 makerVaultIlk = managerLike.ilks(strategy.cdpId());
        assertEq(ilk, makerVaultIlk);
    }

    function testDeployStrategyOwnsMakerVault() public {
        // deploy strategy
        vm_std_cheats.prank(strategist);
        address _strategy = deployStrategy(
            address(vault),
            yVault,
            strategyName,
            ilk,
            gemJoin,
            wantToUSDOSMProxy,
            chainlinkWantToETHPriceFeed
        );
        strategy = Strategy(_strategy);

        // verify vault is owned by the strategy
        ManagerLike managerLike = ManagerLike(makerManager);
        address makerVaultOwner = managerLike.owns(strategy.cdpId());
        assertEq(_strategy, makerVaultOwner);
    }
}
