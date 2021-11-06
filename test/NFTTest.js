const timeMachine = require("@atixlabs/hardhat-time-n-mine");
const { ethers } = require("hardhat");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");

use(solidity);

describe("NFT Category Contract", function () {
  it("Defining Generals", async function () {
    // General
    provider = ethers.provider;
    accounts = await hre.ethers.getSigners();
  });

  it("Deploying NFT Contract", async function () {
    const NFTContract = await ethers.getContractFactory("NftCategory");
    nftContract = await NFTContract.deploy(
      "Name",
      "Symbol",
      "10",
      "www.link.com/"
    );
    await nftContract.deployed();
  });

  it("Create a Private Category - Team minting", async function () {
    var time = Math.floor(Date.now() / 1000);
    await nftContract.addCategory(
      time,
      time + 5200,
      5,
      10,
      true,
      true,
      ethers.utils.parseEther("0.1")
    );
  });

  it("Allow Address to mint in private Category - Team minting", async function () {
    await nftContract.allowAddressToMint(accounts[0].address, 0);
  });

  it("Reserve Token for minting", async function () {
    await nftContract.reserveToken(accounts[0].address, 4);
    await nftContract.reserveToken(accounts[0].address, 6);
    var reservedToken4 = await nftContract.reservedTokenOwners(
      accounts[0].address,
      0
    );
    var reservedToken6 = await nftContract.reservedTokenOwners(
      accounts[0].address,
      1
    );
    expect(reservedToken4.toString()).to.equal("4");
    expect(reservedToken6.toString()).to.equal("6");
  });

  it("Reserve and Unreserve Tokens", async function () {
    await nftContract.reserveToken(accounts[2].address, 55);
    await nftContract.reserveToken(accounts[2].address, 56);
    await nftContract.unreserveToken(accounts[2].address, 55);
    var reservedTokens = await nftContract.reservedTokenOwners(
      accounts[2].address,
      0
    );
    expect(reservedTokens.toString()).to.equal("56");
  });

  it("Mint Reserved Token", async function () {
    await nftContract.mintTokens(0, 2, {
      value: ethers.utils.parseEther("0.2"),
    });
    var reservedTokenOwner6 = await nftContract.ownerOf(6);
    expect(reservedTokenOwner6).to.equal(accounts[0].address);
    var reservedTokenOwner4 = await nftContract.ownerOf(4);
    expect(reservedTokenOwner4).to.equal(accounts[0].address);
  });

  it("stopAdminMinting", async function () {
    await nftContract.stopAdminMinting();
    expect(await nftContract.isAdminMintingDone()).to.equal(true);
  });

  it("Mint Token", async function () {
    await nftContract.mintTokens(0, 2, {
      value: ethers.utils.parseEther("0.2"),
    });
    var ownerOf0 = await nftContract.ownerOf(0);
    expect(ownerOf0).to.equal(accounts[0].address);
    var ownerOf1 = await nftContract.ownerOf(1);
    expect(ownerOf1).to.equal(accounts[0].address);
  });

  it("Expected to Revert - Max wallet category tokens already minted", async function () {
    await expect(
      nftContract.mintTokens(0, 5, {
        value: ethers.utils.parseEther("0.5"),
      })
    ).to.be.revertedWith("Over Max wallet category");
  });

  it("Create a Public Category", async function () {
    var time = Math.floor(Date.now() / 1000);
    await nftContract.addCategory(
      time,
      time + 5200,
      5,
      10,
      false,
      true,
      ethers.utils.parseEther("0.1")
    );
  });

  it("Can't Mint Max per Category achieved!", async function () {
    await nftContract.connect(accounts[2]).mintTokens(1, 5, {
      value: ethers.utils.parseEther("0.5"),
    });
  });

  it("Create a Public Category", async function () {
    var time = Math.floor(Date.now() / 1000);
    await nftContract.addCategory(
      time + 5200,
      time + 15200,
      5,
      10,
      false,
      true,
      ethers.utils.parseEther("0.1")
    );
  });

  it("Expected to Revert - Can't Mint before minting time has started", async function () {
    await expect(
      nftContract.connect(accounts[2]).mintTokens(2, 5, {
        value: ethers.utils.parseEther("0.5"),
      })
    ).to.be.revertedWith("Category not Active");
  });

  it("Create a Public Category - 1 Max mint per category", async function () {
    var time = Math.floor(Date.now() / 1000);
    await nftContract.addCategory(
      time,
      time + 15200,
      5,
      1,
      false,
      true,
      ethers.utils.parseEther("0.1")
    );
  });

  it("Expected to Revert - Can't Mint before minting time has started", async function () {
    await expect(
      nftContract.connect(accounts[3]).mintTokens(3, 5, {
        value: ethers.utils.parseEther("0.5"),
      })
    ).to.be.revertedWith("Over Max category tokens");
  });

  it("Token URI", async function () {
    tokenURI = await nftContract.tokenURI(1);
    expect(tokenURI).to.equal("www.link.com/1");
  });
});
