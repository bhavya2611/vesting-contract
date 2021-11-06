// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Vesting is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    constructor(address _token) {}

    struct TierInfo {
        uint256 maxTokens;
        uint256 startTime;
        uint256 tokensReleased;
    }

    mapping(address => TierInfo) public tierInfo;

    function setTierInfo(
        address _address,
        uint256 _maxTokens,
        uint256 _startTime
    ) public onlyOwner {
        require(
            tierInfo[_address].startTime < block.timestamp,
            "Tier Already Passed"
        );
        tierInfo[_address].maxTokens = _maxTokens;
        tierInfo[_address].startTime = _startTime;
    }

    function releaseToken(uint256 _amount) public onlyOwner {
        uint256 tokensReleased = tierInfo[msg.sender].tokensReleased;
        require(
            block.timestamp > tierInfo[msg.sender].startTime,
            "Vesting not started yet"
        );
        require(
            tokensReleased + _amount < tierInfo[msg.sender].maxTokens,
            "Insufficient balance"
        );
        IERC20(token).transferFrom(address(this), address(msg.sender), _amount);
        tierInfo[msg.sender].tokensReleased = tierInfo[msg.sender]
            .tokensReleased
            .add(_amount);
    }
}
