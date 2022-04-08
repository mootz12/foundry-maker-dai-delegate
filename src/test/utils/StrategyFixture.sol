// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ExtendedDSTest} from "./ExtendedDSTest.sol";
import {stdCheats} from "forge-std/stdlib.sol";
import {Vm} from "forge-std/Vm.sol";
import {IVault} from "../../interfaces/yearn/IVault.sol";
import {Actions} from "./Actions.sol";

// NOTE: if the name of the strat or file changes this needs to be updated
import {Strategy} from "../../Strategy.sol";

// Artifact paths for deploying from the deps folder, assumes that the command is run from
// the project root.
string constant vaultArtifact = "artifacts/Vault.json";

// Base fixture deploying Vault
contract StrategyFixture is ExtendedDSTest, stdCheats {
    using SafeERC20 for IERC20;

    // we use custom names that are unlikely to cause collisions so this contract
    // can be inherited easily
    // TODO: see if theres a better way to use this
    Vm public constant vm_std_cheats =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    IVault public vault;
    Strategy public strategy;
    IERC20 public weth;
    IERC20 public want;
    IERC20 public dai;

    mapping(string => address) tokenAddrs;
    mapping(string => uint256) tokenPrices;

    address public gov = 0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52;
    address public user = address(1);
    address public whale = address(2);
    address public rewards = address(3);
    address public guardian = address(4);
    address public management = address(5);
    address public strategist = address(6);
    address public keeper = address(7);

    // Strategy specific test fixtures
    address public yVault = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
    string public strategyName = "StrategyMakerDaiDelegate";
    // Obtaining the bytes32 ilk (verify its validity before using)
    // >>> ilk = ""
    // >>> for i in "YFI-A":
    // ...   ilk += hex(ord(i)).replace("0x","")
    // ...
    // >>> ilk += "0"*(64-len(ilk))
    // >>>
    // >>> ilk
    // '5946492d41000000000000000000000000000000000000000000000000000000'
    bytes32 public ilk = 0x5946492d41000000000000000000000000000000000000000000000000000000;
    address public gemJoin = 0x3ff33d9162aD47660083D7DC4bC02Fb231c81677;
    address public wantToUSDOSMProxy = 0xCF63089A8aD2a9D8BD6Bb8022f3190EB7e1eD0f1;
    address public chainlinkWantToETHPriceFeed = 0x7c5d4F8345e66f68099581Db340cd65B078C41f4;

    uint256 public minFuzzAmt;
    // @dev maximum amount of want tokens deposited based on @maxDollarNotional
    uint256 public maxFuzzAmt;
    // @dev maximum dollar amount of tokens to be deposited
    uint256 public constant maxDollarNotional = 1_000_000;
    uint256 public constant bigDollarNotional = 49_000_000;
    uint256 public constant DELTA = 10**5;
    uint256 public bigAmount;

    // utils
    Actions actions;

    function setUp() public virtual {
        actions = new Actions();
        
        _setTokenAddrs();
        _setTokenPrices();

        // Choose a token from the tokenAddrs mapping, see _setTokenAddrs for options
        string memory token = "YFI";
        weth = IERC20(tokenAddrs["WETH"]);
        want = IERC20(tokenAddrs[token]);
        dai = IERC20(tokenAddrs["DAI"]);

        // deployVaultAndStrategy (https://github.com/storming0x/foundry_strategy_mix/blob/master/src/test/utils/StrategyFixture.sol#L55)
        // fails to build with stack too deep. 
        // Call submethods explicitily to avoid local varaibles.

        // Deploy a vault
        deployVault(
            address(want),
            gov,
            rewards,
            "",
            "",
            guardian,
            management
        );

        // Deploy a strategy
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
        vm_std_cheats.prank(strategist);
        strategy.setKeeper(keeper);

        vm_std_cheats.prank(gov);
        strategy.setLeaveDebtBehind(false);
        vm_std_cheats.prank(gov);
        strategy.setDoHealthCheck(true);

        // Set a high acceptable max base fee to avoid changing test behavior
        vm_std_cheats.prank(gov);
        strategy.setMaxAcceptableBaseFee(1500 * 1e9);

        // Attach strategy to vault
        vm_std_cheats.prank(gov);
        vault.addStrategy(address(strategy), 10_000, 0, type(uint256).max, 1_000);

        // Set fuzzing bounds
        minFuzzAmt = 10**vault.decimals() / 10;
        maxFuzzAmt =
            uint256(maxDollarNotional / tokenPrices[token]) *
            10**vault.decimals();
        bigAmount =
            uint256(bigDollarNotional / tokenPrices[token]) *
            10**vault.decimals();

        // do here additional setup
        vm_std_cheats.prank(gov);
        vault.setDepositLimit(type(uint256).max);

        _setLabels();
    }

    // Deploys a vault
    function deployVault(
        address _token,
        address _gov,
        address _rewards,
        string memory _name,
        string memory _symbol,
        address _guardian,
        address _management
    ) public returns (address) {
        vm_std_cheats.prank(gov);
        address _vault = deployCode(vaultArtifact);
        vault = IVault(_vault);

        vm_std_cheats.prank(gov);
        vault.initialize(
            _token,
            _gov,
            _rewards,
            _name,
            _symbol,
            _guardian,
            _management
        );

        return address(vault);
    }

    // Deploys a strategy
    function deployStrategy(
        address _vault,
        address _yVault,
        string memory _strategyName,
        bytes32 _ilk,
        address _gemJoin,
        address _wantToUSDOSMProxy,
        address _chainlinkWantToETHPriceFeed
    ) public returns (address) {
        Strategy _strategy = new Strategy(
            _vault,
            _yVault,
            _strategyName,
            _ilk,
            _gemJoin,
            _wantToUSDOSMProxy,
            _chainlinkWantToETHPriceFeed
        );

        return address(_strategy);
    }

    function _setTokenAddrs() internal {
        tokenAddrs["WBTC"] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        tokenAddrs["YFI"] = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e;
        tokenAddrs["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        tokenAddrs["LINK"] = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
        tokenAddrs["USDT"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        tokenAddrs["DAI"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        tokenAddrs["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    }

    function _setTokenPrices() internal {
        tokenPrices["WBTC"] = 60_000;
        tokenPrices["WETH"] = 4_000;
        tokenPrices["LINK"] = 20;
        tokenPrices["YFI"] = 35_000;
        tokenPrices["USDT"] = 1;
        tokenPrices["USDC"] = 1;
        tokenPrices["DAI"] = 1;
    }

    function _setLabels() internal {
        // add more labels to make your traces readable
        vm_std_cheats.label(address(vault), "Vault");
        vm_std_cheats.label(address(strategy), "Strategy");
        vm_std_cheats.label(address(want), "Want");
        vm_std_cheats.label(gov, "Gov");
        vm_std_cheats.label(user, "User");
        vm_std_cheats.label(whale, "Whale");
        vm_std_cheats.label(rewards, "Rewards");
        vm_std_cheats.label(guardian, "Guardian");
        vm_std_cheats.label(management, "Management");
        vm_std_cheats.label(strategist, "Strategist");
        vm_std_cheats.label(keeper, "Keeper");

        // strategy specific labels
        vm_std_cheats.label(yVault, "yvDAI");
        vm_std_cheats.label(gemJoin, "GemJoin");
        vm_std_cheats.label(wantToUSDOSMProxy, "WantToUSDProxy");
        vm_std_cheats.label(chainlinkWantToETHPriceFeed, "ChainlinkWantToEth");
        vm_std_cheats.label(0x5ef30b9986345249bc32d8928B7ee64DE9435E39, "mkrManager");
        vm_std_cheats.label(0x9759A6Ac90977b93B58547b4A71c78317f391A28, "mkrDaiJoin");
        vm_std_cheats.label(0x65C79fcB50Ca1594B025960e539eD7A9a6D434A3, "mkrSpotter");
        vm_std_cheats.label(0x19c0976f590D67707E62397C87829d896Dc0f1F1, "mkrJug");
        vm_std_cheats.label(0xC7Bdd1F2B16447dcf3dE045C4a039A60EC2f0ba3, "mkrAutoLine");

        vm_std_cheats.label(tokenAddrs["DAI"], "DAI");
    }
}
