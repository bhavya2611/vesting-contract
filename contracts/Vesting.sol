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
    address public vestToken;

    constructor(address _stableCoin, address _vestToken) {
        stableCoin = _stableCoin;
        vestToken = _vestToken;
    }

    struct PreSaleTierInfo {
        uint256 maxTokensPerWallet;
        uint256 startTime;
        uint256 endTime;
        uint256 maxTokensForTier;
        uint256 price;
    }

    // tierId => startTime
    mapping(uint256 => uint256) public startVestingForTier;

    // tierId => month => percentage
    mapping(uint256 => mapping(uint256 => uint256)) public allocationPerMonth;

    // user address => tierId => tokensBought
    mapping(address => mapping(uint256 => uint256)) public tokensBought;

    // tierId => tokensBought
    mapping(uint256 => uint256) public totalTokensBoughtForTier;

    // user address => tierId => month => vested
    mapping(address => mapping(uint256 => mapping(uint256 => bool)))
        public userVestedTokens;

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
            tokensBought[msg.sender][_tierId] + _numTokens <
                tierInfo[_tierId].maxTokensPerWallet,
            "You cant buy more tokens"
        );
        uint256 tokenPrice = tierInfo[_tierId].price.mul(_numTokens);
        IERC20(stableCoin).transferFrom(msg.sender, address(this), _amount);
        tokensBought[msg.sender][_tierId] = tokensBought[msg.sender][_tierId]
            .add(_numTokens);
        totalTokensBoughtForTier[_tierId] = totalTokensBoughtForTier[_tierId]
            .add(_numTokens);
    }

    function vestTokens(uint256 _tierId, uint256 _month) public payable {
        require(
            startVestingForTier[_tierId] < block.timestamp,
            "Vesting for tier not yet started"
        );
        require(
            tokensBought[msg.sender][_tierId] > 0,
            "Your token balance is zero"
        );
        require(
            !userVestedTokens[msg.sender][_tierId][_month],
            "You already vested tokens"
        );

        // add a require to calculate month and _month less than the months passed

        uint256 amount = tokensBought[msg.sender][_tierId]
            .mul(allocationPerMonth[_tierId][_month])
            .div(10000);
        userVestedTokens[msg.sender][_tierId][_month] = true;
        IERC20(vestToken).transferFrom(address(this), msg.sender, amount);
    }
}
