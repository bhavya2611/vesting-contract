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

    event TierCreated(
        uint256 _tierId,
        uint256 _maxTokensPerWallet,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxTokensForTier,
        uint256 _price,
        bool _isPrivate
    );

    event TierUpdated(
        uint256 _tierId,
        uint256 _maxTokensPerWallet,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxTokensForTier,
        uint256 _price,
        bool _isPrivate
    );

    event AddressWhitelistedStatus(
        address indexed _address,
        uint256 _tier,
        bool _isWhitelisted
    );

    event AddDistributionMonthAndPercent(
        uint256 _tierId,
        uint256 _month,
        uint256 _percent
    );

    event VestingTimeForTier(uint256 _tierId, uint256 _startTime);

    uint256 public sInMonth = 30 days;

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
        bool isPrivate;
    }

    struct TierVestingInfo {
        uint256 totalTokensBoughtForTier;
        uint256 vestingStartTime;
        uint256 totalAllocationDone;
    }

    // tierId => month => percentage
    mapping(uint256 => mapping(uint256 => uint256)) public allocationPerMonth;

    // tierId => TierVestingInfo
    mapping(uint256 => TierVestingInfo) public tierVestingInfo;

    // user address => tierId => tokensBought
    mapping(address => mapping(uint256 => uint256)) public tokensBought;

    // user address => tierId => tokensBought
    mapping(address => mapping(uint256 => bool)) public isAddressWhitelisted;

    // user address => tierId => month => vestedMonth
    mapping(address => mapping(uint256 => uint256))
        public userVestedTokensMonth;

    PreSaleTierInfo[] public tierInfo;

    /*
     * Params
     * uint256 - How many tokens in total a wallet can buy?
     * uint256 - When does the sale for this tier start?
     * uint256 - When does the sale for this tier end?
     * uint256 - What is the total amount of tokens sold in this Tier?
     * uint256 - What is the price per one token?
     * bool - Do wallets need to be whitelisted?
     */

    function createPreSaleTier(
        uint256 _maxTokensPerWallet,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxTokensForTier,
        uint256 _price,
        bool _isPrivate
    ) external onlyOwner {
        tierInfo.push(
            PreSaleTierInfo({
                maxTokensPerWallet: _maxTokensPerWallet,
                startTime: _startTime,
                endTime: _endTime,
                price: _price,
                maxTokensForTier: _maxTokensForTier,
                isPrivate: _isPrivate
            })
        );
        emit TierCreated(
            tierInfo.length.sub(1),
            _maxTokensPerWallet,
            _startTime,
            _endTime,
            _maxTokensForTier,
            _price,
            _isPrivate
        );
    }

    function updatePreSaleTier(
        uint256 _tierId,
        uint256 _maxTokensPerWallet,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxTokensForTier,
        uint256 _price,
        bool _isPrivate
    ) external onlyOwner {
        require(
            tierInfo[_tierId].startTime > block.timestamp,
            "Pre sale already in progress"
        );
        tierInfo[_tierId].maxTokensPerWallet = _maxTokensPerWallet;
        tierInfo[_tierId].startTime = _startTime;
        tierInfo[_tierId].endTime = _endTime;
        tierInfo[_tierId].maxTokensForTier = _maxTokensForTier;
        tierInfo[_tierId].price = _price;
        tierInfo[_tierId].isPrivate = _isPrivate;
        emit TierUpdated(
            _tierId,
            _maxTokensPerWallet,
            _startTime,
            _endTime,
            _maxTokensForTier,
            _price,
            _isPrivate
        );
    }

    function tierLength() external view returns (uint256) {
        return tierInfo.length;
    }

    function whitelistAddress(address _address, uint256 _tierId)
        public
        onlyOwner
    {
        require(_tierId <= tierInfo.length, "Invalid tier id");
        require(tierInfo[_tierId].isPrivate, "Tier needs to be private");
        isAddressWhitelisted[_address][_tierId] = true;
        emit AddressWhitelistedStatus(_address, _tierId, true);
    }

    function removeWhitelistAddress(address _address, uint256 _tierId)
        public
        onlyOwner
    {
        require(_tierId <= tierInfo.length, "Invalid tier id");
        require(
            tokensBought[msg.sender][_tierId] == 0,
            "User already bought tokens"
        );
        isAddressWhitelisted[_address][_tierId] = false;
        emit AddressWhitelistedStatus(_address, _tierId, false);
    }

    function setDistributionPercent(
        uint256 _tierId,
        uint256 _month,
        uint256 _percent
    ) public onlyOwner {
        require(_month > 0, "Invalid month number");
        require(_month < 37, "Invalid month number");
        require(_tierId <= tierInfo.length, "Invalid tier id");
        require(
            tierVestingInfo[_tierId].totalAllocationDone.add(_percent) <= 10000,
            "Allocation cant be more than 10000"
        );
        require(
            tierVestingInfo[_tierId].vestingStartTime < block.timestamp,
            "Vesting started"
        );
        tierVestingInfo[_tierId].totalAllocationDone = tierVestingInfo[_tierId]
            .totalAllocationDone
            .add(_percent);
        allocationPerMonth[_tierId][_month] = _percent;
        emit AddDistributionMonthAndPercent(_tierId, _month, _percent);
    }

    function setVestingTimeForTier(uint256 _tierId, uint256 _startTime)
        public
        onlyOwner
    {
        require(_tierId < tierInfo.length, "Invalid tier id");
        require(
            tierVestingInfo[_tierId].totalAllocationDone == 10000,
            "Total allocation less than 10000"
        );
        tierVestingInfo[_tierId].vestingStartTime = _startTime;
        emit VestingTimeForTier(_tierId, _startTime);
    }

    function buyVestingTokens(uint256 _tierId, uint256 _numTokens) public {
        require(tx.origin == msg.sender, "Wallets only!");
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
            tokensBought[msg.sender][_tierId] + _numTokens <=
                tierInfo[_tierId].maxTokensPerWallet,
            "You cant buy more tokens"
        );

        if (tierInfo[_tierId].isPrivate) {
            require(
                isAddressWhitelisted[msg.sender][_tierId],
                "Not allowed to buy tokens"
            );
        }
        uint256 totalTokenAmount;
        if (tierInfo[_tierId].price > 0) {
            totalTokenAmount = tierInfo[_tierId].price.mul(_numTokens).div(
                10e17
            );
        } else {
            totalTokenAmount = _numTokens;
        }

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
            tierVestingInfo[_tierId].vestingStartTime < block.timestamp,
            "Vesting for tier not yet started"
        );
        require(
            tokensBought[msg.sender][_tierId] > 0,
            "Your token balance is zero"
        );
        require(
            tierVestingInfo[_tierId].totalAllocationDone == 10000,
            "Allocation is not 10000%"
        );

        uint256 monthsPassed = (block.timestamp -
            tierVestingInfo[_tierId].vestingStartTime) / sInMonth;

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
        IERC20(vestToken).transfer(msg.sender, amount);

        emit TokensVested(msg.sender, _tierId, amount);
    }

    function adminWithdrawStableCoin(uint256 _amount) public onlyOwner {
        IERC20(stableCoin).transfer(msg.sender, _amount);
    }
}
