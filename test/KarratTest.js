const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Karrat", function () {
  let token, timelock, governor;
  const ONE = ethers.utils.parseEther("1");
  const ZERO_ADDR = '0x0000000000000000000000000000000000000000';

  beforeEach(async function () {
    [deployer, addr1, addr2, addr3, addr4, addr5, voter, recipient] = await ethers.getSigners();

    timelock = await hre.ethers.deployContract("KarratTimelock", [0, [], [], deployer.address]);
    await timelock.deployed()
    token = await hre.ethers.deployContract("ERC20Mock");
    await token.deployed()
    governor = await hre.ethers.deployContract("KarratGovernor", [
      token.address,
      timelock.address,
      token.address
    ]);
    await governor.deployed();

    // init timelock
    // executor zero means anyone can execute
    await timelock.connect(deployer).initialize(governor.address, ZERO_ADDR)
    // mint to the timelock = DAO
    await token.mint(timelock.address, ONE)
    await token.mint(voter.address, ONE)
  })

  it("Basic flow", async function() {

    const transferCalldata = token.interface.encodeFunctionData("transfer", [recipient.address, ONE]);

    const description = "Proposal #1: Transfer 1 token";
    const targets = [token.address]; // The token contract is the target of the proposal
    const values = [0]; // No ether is sent along with the call
    const calldatas = [transferCalldata]; // The encoded function call

    const proposeTx = await governor.propose(targets, values, calldatas, description)
    const proposeReceipt = await proposeTx.wait();
    const proposalId = proposeReceipt.events.find(e => e.event === "ProposalCreated").args.proposalId;
    console.log(proposalId)
    expect(await governor.state(proposalId)).to.eq(0);

    // await network.provider.send("evm_increaseTime", [2 * 24 * 60 * 60]); // 2 days, adjust according to your GovernorSettings
    await network.provider.send("evm_mine");
    await network.provider.send("evm_mine");

    console.log("clock:", await governor.clock())
    console.log("snapshot:", await governor.proposalSnapshot(proposalId))
    expect(await governor.state(proposalId)).to.eq(1);

    // voting started
    const castVoteTx = await governor.connect(voter).castVote(proposalId, 1);
    await castVoteTx.wait();

    // voting finished
    await network.provider.send("evm_mine");
    await network.provider.send("evm_mine");
    await network.provider.send("evm_mine");
    console.log("clock:", await governor.clock())
    console.log("snapshot:", await governor.proposalSnapshot(proposalId))

    // queued
    const queueTx = await governor.queue(targets, values, calldatas, ethers.utils.keccak256(ethers.utils.toUtf8Bytes(description)))
    await queueTx.wait()

    // now executing
    const executeTx = await governor.execute(targets, values, calldatas, ethers.utils.keccak256(ethers.utils.toUtf8Bytes(description)))
    await executeTx.wait()

    expect(await token.balanceOf(recipient.address)).to.equal(ONE);
  });
});
