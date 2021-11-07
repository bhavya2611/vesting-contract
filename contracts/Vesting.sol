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

    struct TierVestingInfo {
        uint256 totalTokensBoughtForTier;
        uint256 startVestingForTier;
        uint256 totalAllocationDone;
    }

    // tierId => month => percentage
    mapping(uint256 => mapping(uint256 => uint256)) public allocationPerMonth;

    // tierId => TierVestingInfo
    mapping(uint256 => TierVestingInfo) public tierVestingInfo;

    // user address => tierId => tokensBought
    mapping(address => mapping(uint256 => uint256)) public tokensBought;

    // user address => tierId => month => vested
    mapping(address => mapping(uint256 => mapping(uint256 => bool)))
        public userVestedTokens;

    PreSaleTierInfo[] public tierInfo;

    function createPreSaleTier(
        uint256 _maxTokensPerWallet,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxTokensForTier,
        uint256 _price
    ) external onlyOwner {
        tierInfo.push(
            PreSaleTierInfo({
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
        require(
            tierVestingInfo[_tierId].totalAllocationDone == 100,
            "Total allocation less than 100"
        );
        tierVestingInfo[_tierId].startVestingForTier = _startTime;
    }

    function setAllocation(
        uint256 _tierId,
        uint256 _month,
        uint256 _allocation
    ) public onlyOwner {
        require(_month > 0, "Invalid month number");
        require(_month < 13, "Invalid month number");
        require(_tierId < tierInfo.length, "Invalid tier id");
        require(
            tierVestingInfo[_tierId].totalAllocationDone.add(_allocation) <=
                100,
            "Allocation cant be more than 100"
        );
        // See If a check is required to not allow to do allocation again or change allocation after month is passed
        tierVestingInfo[_tierId].totalAllocationDone = tierVestingInfo[_tierId]
            .totalAllocationDone
            .add(_allocation);
        allocationPerMonth[_tierId][_month] = _allocation;
    }

    function buyTokens(uint256 _tierId, uint256 _numTokens) public payable {
        require(
            tierInfo[_tierId].startTime < block.timestamp,
            "Pre sale not yet started"
        );
        require(tierInfo[_tierId].endTime > block.timestamp, "Pre sale over");
        require(
            tierVestingInfo[_tierId].totalTokensBoughtForTier + _numTokens <
                tierInfo[_tierId].maxTokensForTier,
            "Cant buy more tokens for this tier"
        );
        require(
            tokensBought[msg.sender][_tierId] + _numTokens <
                tierInfo[_tierId].maxTokensPerWallet,
            "You cant buy more tokens"
        );
        uint256 tokenPrice = tierInfo[_tierId].price.mul(_numTokens);
        IERC20(stableCoin).transferFrom(msg.sender, address(this), tokenPrice);
        tokensBought[msg.sender][_tierId] = tokensBought[msg.sender][_tierId]
            .add(_numTokens);
        tierVestingInfo[_tierId].totalTokensBoughtForTier = tierVestingInfo[
            _tierId
        ].totalTokensBoughtForTier.add(_numTokens);
    }

    function vestTokens(uint256 _tierId, uint256 _month) public payable {
        require(
            tierVestingInfo[_tierId].startVestingForTier < block.timestamp,
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

        // add a require to calculate month and check _month less than the months passed

        uint256 amount = tokensBought[msg.sender][_tierId]
            .mul(allocationPerMonth[_tierId][_month])
            .div(10000);
        userVestedTokens[msg.sender][_tierId][_month] = true;
        IERC20(vestToken).transferFrom(address(this), msg.sender, amount);
    }
}
