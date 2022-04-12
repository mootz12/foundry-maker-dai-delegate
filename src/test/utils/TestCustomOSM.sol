// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "../../interfaces/yearn/IOSMedianizer.sol";

contract TestCustomOSM is IOSMedianizer {
    uint256 internal currentPrice;
    bool internal revertRead;

    uint256 internal futurePrice;
    bool internal revertForesight;

    constructor(
        uint256 _currentPrice,
        bool _revertRead,
        uint256 _futurePrice,
        bool _revertForesight
    ) public {
        currentPrice = _currentPrice;
        revertRead = _revertRead;
        futurePrice = _futurePrice;
        revertForesight = _revertForesight;
    }

    function setCurrentPrice(uint256 _currentPrice, bool _revertRead) external {
        currentPrice = _currentPrice;
        revertRead = _revertRead;
    }

    function setFuturePrice(uint256 _futurePrice, bool _revertForesight)
        external
    {
        futurePrice = _futurePrice;
        revertForesight = _revertForesight;
    }

    function foresight()
        external
        view
        override
        returns (uint256 price, bool osm)
    {
        if (revertForesight) {
            require(1 == 2);
        }
        return (futurePrice, true);
    }

    function read() external view override returns (uint256 price, bool osm) {
        if (revertRead) {
            require(1 == 2);
        }
        return (currentPrice, true);
    }

    function setAuthorized(address _address) external override  {
        require(1 == 1);
    }
}
