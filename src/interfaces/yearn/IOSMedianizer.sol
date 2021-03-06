// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IOSMedianizer {
    function foresight() external view returns (uint256 price, bool osm);

    function read() external view returns (uint256 price, bool osm);

    function setAuthorized(address) external;
}
