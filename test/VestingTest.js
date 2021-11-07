/* eslint-disable */

const timeMachine = require('@atixlabs/hardhat-time-n-mine');
const { ethers } = require('hardhat');
const { use, expect } = require('chai');
const { solidity } = require('ethereum-waffle');

use(solidity);

const secondsInMonth = 2592000000;

describe('Vesting Contract', function () {
  it('Defining Generals', async function () {
    // General
    provider = ethers.provider;
    accounts = await hre.ethers.getSigners();

    await ethers.provider.send('evm_setNextBlockTimestamp', [Date.now()]);
    await ethers.provider.send('evm_mine');
  });

  it('Deploying Contracts', async function () {
    const VestToken = await ethers.getContractFactory('ERC20Token');
    vestToken = await VestToken.deploy(
      'Vest',
      'VEST',
      ethers.utils.parseEther('100000')
    );

    const StableToken = await ethers.getContractFactory('ERC20Token');
    stableToken = await StableToken.deploy(
      'Stable',
      'STABLE',
      ethers.utils.parseEther('100000')
    );

    await vestToken.deployed();
    await stableToken.deployed();

    const VestingContract = await ethers.getContractFactory('Vesting');
    vestingContract = await VestingContract.deploy(
      stableToken.address,
      vestToken.address
    );
    await vestingContract.deployed();
  });

  it('Create Tier 1', async function () {
    await vestingContract.createPreSaleTier(
      ethers.utils.parseEther('100'),
      Date.now(),
      Date.now() + secondsInMonth * 4,
      ethers.utils.parseEther('200'),
      ethers.utils.parseEther('5'),
      false
    );

    const tierInfo = await vestingContract.tierInfo(0);
    expect(tierInfo.maxTokensPerWallet).to.equal(
      ethers.utils.parseEther('100')
    );
  });

  it('Create Tier 2', async function () {
    await vestingContract.createPreSaleTier(
      ethers.utils.parseEther('10'),
      Date.now() + secondsInMonth,
      Date.now() + secondsInMonth * 8,
      ethers.utils.parseEther('200'),
      ethers.utils.parseEther('10'),
      true
    );

    const tierInfo = await vestingContract.tierInfo(1);
    expect(tierInfo.maxTokensPerWallet).to.equal(ethers.utils.parseEther('10'));
  });

  it('Update Tier 2', async function () {
    await vestingContract.updatePreSaleTier(
      1,
      ethers.utils.parseEther('10'),
      Date.now() + secondsInMonth,
      Date.now() + secondsInMonth * 8,
      ethers.utils.parseEther('200'),
      ethers.utils.parseEther('8'),
      true
    );

    const tierInfo = await vestingContract.tierInfo(1);
    expect(tierInfo.price).to.equal(ethers.utils.parseEther('8'));
  });

  it('Whitelist account 3 for tier 2', async function () {
    await vestingContract.whitelistAddress(accounts[3].address, 1);

    const isAddressWhitelisted = await vestingContract.isAddressWhitelisted(
      accounts[3].address,
      1
    );
    expect(isAddressWhitelisted).to.equal(true);
  });

  it('Set allocations for tier 1', async function () {
    await vestingContract.setAllocation(0, 2, 10);
    await vestingContract.setAllocation(0, 4, 20);
    await vestingContract.setAllocation(0, 6, 30);
    await vestingContract.setAllocation(0, 8, 40);

    let allocationPerMonthInfo = await vestingContract.allocationPerMonth(0, 2);
    expect(allocationPerMonthInfo).to.equal(10);
    allocationPerMonthInfo = await vestingContract.allocationPerMonth(0, 4);
    expect(allocationPerMonthInfo).to.equal(20);
    allocationPerMonthInfo = await vestingContract.allocationPerMonth(0, 6);
    expect(allocationPerMonthInfo).to.equal(30);
    allocationPerMonthInfo = await vestingContract.allocationPerMonth(0, 8);
    expect(allocationPerMonthInfo).to.equal(40);
    allocationPerMonthInfo = await vestingContract.allocationPerMonth(0, 1);
    expect(allocationPerMonthInfo).to.equal(0);
  });

  it('Set Vesting Time For Tier 1', async function () {
    const time = Date.now() + secondsInMonth;
    await vestingContract.setVestingTimeForTier(0, time);

    tierVestingInfo = await vestingContract.tierVestingInfo(0);
    expect(tierVestingInfo.vestingStartTime).to.equal(time);
  });

  it('Set Vesting Time For Tier 2 Should Fail', async function () {
    const time = Date.now() + secondsInMonth;
    await expect(
      vestingContract.setVestingTimeForTier(1, time)
    ).to.be.revertedWith('Total allocation less than 100');
  });

  it('Set allocations for tier 2', async function () {
    await vestingContract.setAllocation(1, 1, 20);
    await vestingContract.setAllocation(1, 2, 20);
    await vestingContract.setAllocation(1, 6, 30);
    await vestingContract.setAllocation(1, 12, 30);

    let allocationPerMonthInfo = await vestingContract.allocationPerMonth(1, 1);
    expect(allocationPerMonthInfo).to.equal(20);
    allocationPerMonthInfo = await vestingContract.allocationPerMonth(1, 2);
    expect(allocationPerMonthInfo).to.equal(20);
    allocationPerMonthInfo = await vestingContract.allocationPerMonth(1, 6);
    expect(allocationPerMonthInfo).to.equal(30);
    allocationPerMonthInfo = await vestingContract.allocationPerMonth(1, 12);
    expect(allocationPerMonthInfo).to.equal(30);
    allocationPerMonthInfo = await vestingContract.allocationPerMonth(1, 3);
    expect(allocationPerMonthInfo).to.equal(0);
  });

  it('Set Vesting Time For Tier 2', async function () {
    const time = Date.now() + secondsInMonth;
    await vestingContract.setVestingTimeForTier(1, time);

    tierVestingInfo = await vestingContract.tierVestingInfo(1);
    expect(tierVestingInfo.vestingStartTime).to.equal(time);
  });

  it('Transfer Stable Tokens to Account 2', async function () {
    await stableToken.transfer(
      accounts[2].address,
      ethers.utils.parseEther('100')
    );

    balance = await stableToken.balanceOf(accounts[2].address);
    expect(balance).to.equal(ethers.utils.parseEther('100'));
  });

  it('Transfer Stable Tokens to Account 3', async function () {
    await stableToken.transfer(
      accounts[3].address,
      ethers.utils.parseEther('100')
    );

    balance = await stableToken.balanceOf(accounts[3].address);
    expect(balance).to.equal(ethers.utils.parseEther('100'));
  });

  it('Transfer Vest Tokens to Contract', async function () {
    await vestToken.transfer(
      vestingContract.address,
      ethers.utils.parseEther('100')
    );

    balance = await vestToken.balanceOf(vestingContract.address);
    expect(balance).to.equal(ethers.utils.parseEther('100'));
  });

  it('Buy Vesting Tokens For Tier 2 From account 2 should fail', async function () {
    await ethers.provider.send('evm_setNextBlockTimestamp', [
      Date.now() + secondsInMonth,
    ]);
    await ethers.provider.send('evm_mine');

    await stableToken
      .connect(accounts[2])
      .approve(vestingContract.address, ethers.utils.parseEther('1000'));

    await expect(
      vestingContract
        .connect(accounts[2])
        .buyVestingTokens(1, ethers.utils.parseEther('10'))
    ).to.be.revertedWith('Not allowed to buy tokens');
  });

  it('Buy Vesting Tokens', async function () {
    await ethers.provider.send('evm_setNextBlockTimestamp', [
      Date.now() + secondsInMonth,
    ]);
    await ethers.provider.send('evm_mine');

    await stableToken
      .connect(accounts[2])
      .approve(vestingContract.address, ethers.utils.parseEther('1000'));

    await vestingContract
      .connect(accounts[2])
      .buyVestingTokens(0, ethers.utils.parseEther('10'));

    tokensBought = await vestingContract.tokensBought(accounts[2].address, 0);
    expect(tokensBought).to.equal(ethers.utils.parseEther('10'));

    balance = await stableToken.balanceOf(accounts[2].address);
    expect(balance).to.equal(ethers.utils.parseEther('50'));
  });

  it('Vest Tokens After 3 months', async function () {
    await ethers.provider.send('evm_setNextBlockTimestamp', [
      Date.now() + secondsInMonth * 3,
    ]);
    await ethers.provider.send('evm_mine');

    await vestingContract.connect(accounts[2]).vestTokens(0);

    balance = await vestToken.balanceOf(accounts[2].address);
    expect(balance).to.equal(ethers.utils.parseEther('1'));
  });

  it('Vest Tokens After 8 months', async function () {
    await ethers.provider.send('evm_setNextBlockTimestamp', [
      Date.now() + secondsInMonth * 8,
    ]);
    await ethers.provider.send('evm_mine');

    await vestingContract.connect(accounts[2]).vestTokens(0);

    balance = await vestToken.balanceOf(accounts[2].address);
    expect(balance).to.equal(ethers.utils.parseEther('6'));
  });

  it('Vest Tokens After 16 months', async function () {
    await ethers.provider.send('evm_setNextBlockTimestamp', [
      Date.now() + secondsInMonth * 16,
    ]);
    await ethers.provider.send('evm_mine');

    await vestingContract.connect(accounts[2]).vestTokens(0);

    balance = await vestToken.balanceOf(accounts[2].address);
    expect(balance).to.equal(ethers.utils.parseEther('10'));
  });
});
