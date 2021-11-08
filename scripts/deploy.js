/* eslint-disable */

// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require('hardhat');

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  let STABLE_TOKEN_ADDRESS;
  let NAME = 'Vest';
  let SYMBOL = 'VEST';
  let SUPPLY = ethers.utils.parseEther('10000000000000');

  if (hre.network.name === 'maticTestnet')
    STABLE_TOKEN_ADDRESS = '0xe07d7b44d340216723ed5ea33c724908b817ee9d';
  else if (hre.network.name === 'matic')
    STABLE_TOKEN_ADDRESS = '0xe07d7b44d340216723ed5ea33c724908b817ee9d';

  //^^^^^^^^^^^^^^^^^^^^^^^^^^ DEPLOYMENT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

  /**
   * Params
   * NAME
   * SYMBOL
   * SUPPLY
   */

  // We get the contract to deploy
  const VestToken = await ethers.getContractFactory('ERC20Token');
  vestToken = await VestToken.deploy(NAME, SYMBOL, SUPPLY);

  await vestToken.deployed();

  console.log('Vesting Token deployed to:', vestToken.address);

  /**
   * Params
   * Address - Stable Token
   * Address - Vest Token
   */

  // We get the contract to deploy
  const VestingContract = await ethers.getContractFactory('Vesting');

  vestingContract = await VestingContract.deploy(
    STABLE_TOKEN_ADDRESS,
    vestToken.address
  );

  await vestingContract.deployed();

  console.log('Vesting Contract deployed to:', vestingContract.address);

  // vvvvvvvvvvvvvvvvvvvvvvvvv VERIFICATION vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
  console.log('Wait for contract!');
  await delay(46000);
  console.log('Waited 46s');

  await hre.run('verify:verify', {
    address: vestingContract.address,
    constructorArguments: [STABLE_TOKEN_ADDRESS, VEST_TOKEN_ADDRESS],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
