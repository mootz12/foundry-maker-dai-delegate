// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVault} from "../../interfaces/yearn/IVault.sol";
import {Vm} from "forge-std/Vm.sol";
import {ExtendedDSTest} from "./ExtendedDSTest.sol";
import {stdCheats} from "forge-std/stdlib.sol";

import {Strategy} from "../../Strategy.sol";

contract Actions is ExtendedDSTest, stdCheats {
    using SafeERC20 for IERC20;

    Vm public constant vm_std_cheats = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function userDeposit(
        address _user,
        IVault _vault,
        uint256 _amount
    ) public {
        IERC20 _want = IERC20(_vault.token());
        tip(address(_want), _user, _amount);
        if (_want.allowance(_user, address(_vault)) < _amount) {
            vm_std_cheats.prank(_user);
            _want.approve(address(_vault), type(uint256).max);
        }
        vm_std_cheats.prank(_user);
        _vault.deposit(_amount);
    }

    function depositAndHarvestStrategy(
        address _user,
        IVault _vault,
        Strategy _strategy,
        uint256 _amount
    ) public {
        userDeposit(_user, _vault, _amount);
        skip(1);
        vm_std_cheats.prank(_strategy.strategist());
        _strategy.harvest();
    }
}