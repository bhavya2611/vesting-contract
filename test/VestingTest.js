/* eslint-disable */

const timeMachine = require('@atixlabs/hardhat-time-n-mine');
const { ethers } = require('hardhat');
const { use, expect } = require('chai');
const { solidity } = require('ethereum-waffle');

use(solidity);

const secondsInMonth = 2592000;

describe('Vesting Contract', function () {
  it('Defining Generals', async function () {
    // General
    provider = ethers.provider;
    accounts = await hre.ethers.getSigners();
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
      Date.now() + secondsInMonth,
      ethers.utils.parseEther('200'),
      ethers.utils.parseEther('5')
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
      Date.now() + secondsInMonth * 2,
      ethers.utils.parseEther('200'),
      ethers.utils.parseEther('10')
    );

    const tierInfo = await vestingContract.tierInfo(1);
    expect(tierInfo.maxTokensPerWallet).to.equal(ethers.utils.parseEther('10'));
  });

  it('Update Tier 2', async function () {
    await vestingContract.updatePreSaleTier(
      1,
      ethers.utils.parseEther('10'),
      Date.now() + secondsInMonth,
      Date.now() + secondsInMonth * 2,
      ethers.utils.parseEther('200'),
      ethers.utils.parseEther('8')
    );

    const tierInfo = await vestingContract.tierInfo(1);
    expect(tierInfo.price).to.equal(ethers.utils.parseEther('8'));
  });
});
