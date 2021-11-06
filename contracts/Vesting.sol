// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Vesting is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    address public stableCoin;

    constructor(address _stableCoin) {
        stableCoin = _stableCoin;
    }

    struct PreSaleTierInfo {
        uint256 maxTokensPerWallet;
        uint256 startTime;
        uint256 endTime;
        uint256 maxTokensForTier;
        uint256 price;
    }

    mapping(uint256 => uint256) public startVestingForTier;
    mapping(uint256 => mapping(uint256 => uint256)) public allocationPerMonth;
    mapping(address => mapping(uint256 => uint256)) public tokensBought;
    mapping(uint256 => uint256) public totalTokensBoughtForTier;

    TierInfo[] public tierInfo;

    function createPreSaleTier(
        uint256 _maxTokensPerWallet,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxTokensForTier,
        uint256 _price
    ) external onlyOwner {
        tierInfo.push(
            TierInfo({
                maxTokensPerWallet: _maxTokensPerWallet,
                startTime: _startTime,
                endTime: _endTime,
                price: _price,
                maxTokensForTier: _maxTokensForTier
            })
        );
    }

    function updatePreSaleTier(
        uint256 _tierId,
        uint256 _maxTokensPerWallet,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxTokensForTier,
        uint256 _price
    ) external onlyOwner {
        require(
            tierInfo[_tierId].startTime < block.timestamp,
            "Pre sale not yet started"
        );
        tierInfo[_tierId].maxTokensPerWallet = _maxTokensPerWallet;
        tierInfo[_tierId].startTime = _startTime;
        tierInfo[_tierId].endTime = _endTime;
        tierInfo[_tierId].maxTokensForTier = _maxTokensForTier;
        tierInfo[_tierId].price = _price;
    }

    function tierLength() external view returns (uint256) {
        return tierInfo.length;
    }

    function setVestingForTier(uint256 _tierId, uint256 _startTime)
        public
        onlyOwner
    {
        require(_tierId < tierInfo.length, "Invalid tier id");
        require(
            tierInfo[_tierId].startTime < _startTime,
            "Tier not yet started"
        );
        startVestingForTier[_tierId] = _startTime;
    }

    function setAllocation(
        uint256 _tierId,
        uint256 _month,
        uint256 _allocation
    ) public onlyOwner {
        require(_month > 0, "Invalid month number");
        require(_month < 13, "Invalid month number");
        require(_tierId < tierInfo.length, "Invalid tier id");
        allocationPerMonth[_tierId][_month] = _allocation;
    }

    function buyTokens(uint256 _tierId, uint256 _numTokens) public payable {
        require(
            tierInfo[_tierId].startTime < block.timestamp,
            "Pre sale not yet started"
        );
        require(tierInfo[_tierId].endTime > block.timestamp, "Pre sale over");
        require(
            totalTokensBoughtForTier[_tierId] + _numTokens <
                tierInfo[_tierId].maxTokensForTier,
            "Cant buy more tokens for this tier"
        );
        require(
            tokensBought[msg.sender] + _numTokens <
                tierInfo[_tierId].maxTokensPerWallet,
            "You cant buy more tokens"
        );
        uint256 tokenPrice = tierInfo[_tierId].price.mul(_numTokens);
        IERC20(stableCoin).transferFrom(msg.sender, address(this), _amount);
        tokensBought[msg.sender] = tokensBought[msg.sender].add(_numTokens);
        totalTokensBoughtForTier[_tierId] = totalTokensBoughtForTier[_tierId]
            .add(_numTokens);
    }
}
