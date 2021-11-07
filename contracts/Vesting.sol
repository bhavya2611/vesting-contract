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

    event TokensBought(
        address indexed _from,
        uint256 indexed _tierId,
        uint256 _value
    );

    event TokensVested(
        address indexed _from,
        uint256 indexed _tierId,
        uint256 _value
    );

    uint256 public secondsInMonth = 2592000;

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

    // user address => tierId => month => vestedMonth
    mapping(address => mapping(uint256 => uint256))
        public userVestedTokensMonth;

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
        require(_month < 37, "Invalid month number");
        require(_tierId <= tierInfo.length, "Invalid tier id");
        require(
            tierVestingInfo[_tierId].totalAllocationDone.add(_allocation) <=
                100,
            "Allocation cant be more than 100"
        );
        require(
            tierVestingInfo[_tierId].startVestingForTier < block.timestamp,
            "Vesting started"
        );
        tierVestingInfo[_tierId].totalAllocationDone = tierVestingInfo[_tierId]
            .totalAllocationDone
            .add(_allocation);
        allocationPerMonth[_tierId][_month] = _allocation;
    }

    function buyTokens(uint256 _tierId, uint256 _numTokens) public {
        require(
            tierInfo[_tierId].startTime < block.timestamp,
            "Pre sale not yet started"
        );
        require(tierInfo[_tierId].endTime > block.timestamp, "Pre sale over");
        require(
            tierVestingInfo[_tierId].totalTokensBoughtForTier.add(_numTokens) <=
                tierInfo[_tierId].maxTokensForTier,
            "Cant buy more tokens for this tier"
        );
        require(
            tokensBought[msg.sender][_tierId].add(_numTokens) <=
                tierInfo[_tierId].maxTokensPerWallet,
            "You cant buy more tokens"
        );
        uint256 totalTokenAmount = tierInfo[_tierId].price.mul(_numTokens);
        IERC20(stableCoin).transferFrom(
            msg.sender,
            address(this),
            totalTokenAmount
        );
        tokensBought[msg.sender][_tierId] = tokensBought[msg.sender][_tierId]
            .add(_numTokens);
        tierVestingInfo[_tierId].totalTokensBoughtForTier = tierVestingInfo[
            _tierId
        ].totalTokensBoughtForTier.add(_numTokens);

        emit TokensBought(msg.sender, _tierId, _numTokens);
    }

    function vestTokens(uint256 _tierId) public {
        require(
            tierVestingInfo[_tierId].startVestingForTier < block.timestamp,
            "Vesting for tier not yet started"
        );
        require(
            tokensBought[msg.sender][_tierId] > 0,
            "Your token balance is zero"
        );
        require(
            tierVestingInfo[_tierId].totalAllocationDone == 0,
            "Allocation is not 100%"
        );

        uint256 monthsPassed = (block.timestamp +
            tierVestingInfo[_tierId].startVestingForTier) % secondsInMonth;

        require(
            monthsPassed > userVestedTokensMonth[msg.sender][_tierId],
            "You already vested tokens"
        );

        uint256 i = 0;
        uint256 totalAllocation = 0;
        uint256 loopUpperLimit = 0;

        if (monthsPassed < 37) {
            loopUpperLimit = monthsPassed;
        } else {
            loopUpperLimit = 36;
        }

        for (
            i = userVestedTokensMonth[msg.sender][_tierId] + 1;
            i <= loopUpperLimit;
            i++
        ) {
            totalAllocation = totalAllocation + allocationPerMonth[_tierId][i];
        }

        uint256 amount = tokensBought[msg.sender][_tierId]
            .mul(totalAllocation)
            .div(10000);

        userVestedTokensMonth[msg.sender][_tierId] = monthsPassed;
        IERC20(vestToken).transferFrom(address(this), msg.sender, amount);

        emit TokensVested(msg.sender, _tierId, amount);
    }
}
