import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";
import { Contract, ContractFactory, BigNumber } from "ethers";
import { ethers, network } from "hardhat";

const {
  BN,
  expectEvent,
  constants,
  expectRevert,
  snapshot,
  time
} = require("@openzeppelin/test-helpers");

require("chai")
    .should();


describe("Vesting Contract", function () {
  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;

  let TevaToken: ContractFactory;
  let tevaToken: Contract;
  let VestingContract: ContractFactory;
  let vestingContract: Contract;
  let snapshotA: any;
  
  //const AMOUNT = new BN(100000);
  const AMOUNT = BigNumber.from(100);
  const VESTING_TIME = 600 * 60; //in sec
  const CLIFF_TIME = 10 * 60; //in sec


  before(async function () {
    [owner, user1, user2, user3] = await ethers.getSigners();

    TevaToken = await ethers.getContractFactory("TevaToken");
    VestingContract = await ethers.getContractFactory("VestingContract");
    tevaToken = await TevaToken.deploy();
    vestingContract = await VestingContract.deploy(tevaToken.address);

    await tevaToken.addMinter(vestingContract.address);
    
    snapshotA = await snapshot();
  });

  describe("Vesting Contract Test Cases", function () {

    describe("Vesting Contract Deploy Test Cases 🏗️", function () {

        it("shouldn't deploy contract if the token address is zero", async () => {
            await expectRevert(
              VestingContract.deploy(constants.ZERO_ADDRESS),
              "Vesting: token address is zero"
            );
        });

        it("should deploy with correct owner", async () => {
          expect(await vestingContract.owner()).to.equal(owner.address);
        });
  
    });

    describe("Vesting Contract Owner Test Cases 👮", function () {

      afterEach(async function () {
        await snapshotA.restore();
      });
      
      //setInitialTimestamp
      it("should initialize timestamp", async () => {
          let initialTimestamp = Math.floor(Date.now() / 1000) + 10;
          let receipt = await vestingContract.setInitialTimestamp(initialTimestamp);

          await expect(receipt).to.emit(
            vestingContract,
            "SetInitialTimestamp"
          ).withArgs(
            BigNumber.from(initialTimestamp)
          );
      });

      it("shouldn't initialize timestamp from the non-current owner", async () => {
          let initialTimestamp = Math.floor(Date.now() / 1000) + 10;

          await expectRevert(
            vestingContract.connect(user1).setInitialTimestamp(initialTimestamp),
            "Ownable: caller is not the owner"
          );
      });

      it("shouldn't initialize timestamp if it already initialized", async () => {
        let initialTimestamp = Math.floor(Date.now() / 1000) + 10;
        await vestingContract.setInitialTimestamp(initialTimestamp),
        
        await expectRevert(
          vestingContract.setInitialTimestamp(initialTimestamp),
          "Vesting: timestamp has already been initialized"
        );     
      });

      it("shouldn't initialize timestamp if it less than the current block timestamp", async () => {
        let initialTimestamp = Math.floor(Date.now() / 1000) - 10;
        
        await expectRevert(
          vestingContract.setInitialTimestamp(initialTimestamp),
          "Vesting: initial timestamp is less than the current block timestamp"
        );     
      });

      //addInvestors
      it("should add investors", async () => {
          let receipt = await vestingContract.addInvestors([user1.address], [AMOUNT], 0);
          await expect(receipt).to.emit(
            vestingContract,
            "AddInvestor"
          ).withArgs(
            user1.address,
            AMOUNT,
            BigNumber.from(0)
          );

          let receipt2 = await vestingContract.addInvestors([user2.address, user3.address], [AMOUNT, AMOUNT], 1);
          await expect(receipt2).to.emit(
            vestingContract,
            "AddInvestor"
          ).withArgs(
            user2.address,
            AMOUNT,
            BigNumber.from(1)
          );
          await expect(receipt2).to.emit(
            vestingContract,
            "AddInvestor"
          ).withArgs(
            user3.address,
            AMOUNT,
            BigNumber.from(1)
          );

          let totalSupply = await vestingContract.totalSupply();
          totalSupply.should.be.equal(BigNumber.from(Number(AMOUNT) * 3));
      });

      it("shouldn't add investors from the non-current owner", async () => {
          await expectRevert(
            vestingContract.connect(user1).addInvestors([user1.address], [AMOUNT], 0),
            "Ownable: caller is not the owner"
          );
      });

      it("shouldn't add investors if vesting has already been started", async () => {
        let initialTimestamp = Math.floor(Date.now() / 1000) + 10;
        await vestingContract.setInitialTimestamp(initialTimestamp),

        await expectRevert(
          vestingContract.addInvestors([user1.address], [AMOUNT], 0),
          "Vesting: vesting has already been started"
        );
      });

      it("shouldn't add investors if the number of items in the arrays does't match", async () => {

        await expectRevert(
          vestingContract.addInvestors([user1.address, user2.address], [AMOUNT], 0),
          "Vesting: the number of items in the arrays does't match"
        );

        await expectRevert(
          vestingContract.addInvestors([user1.address], [AMOUNT, AMOUNT], 0),
          "Vesting: the number of items in the arrays does't match"
        );

      });

    });

    describe("Withdrawer Test Cases 💳", function () {

      afterEach(async function () {
        await snapshotA.restore();
      });

      //withdrawTokens
      it("should withdraw tokens to seed investor", async () => {
        await vestingContract.addInvestors([user1.address], [AMOUNT], 0);
        let initialTimestamp = Math.floor(Date.now() / 1000) + 10;
        await vestingContract.setInitialTimestamp(initialTimestamp);
        await time.increase(CLIFF_TIME + 10);

        let receipt = await vestingContract.connect(user1).withdrawTokens();

        let timestamp = await getCurrentTimestamp(receipt.blockNumber);
        let vestingTimePassed = timestamp - initialTimestamp;
        let amount = Math.floor(Number(AMOUNT) / 10) + Math.floor(Math.floor((9 * Number(AMOUNT) * vestingTimePassed) / 10) / VESTING_TIME); 
        await expect(receipt).to.emit(
          vestingContract,
          "WithdrawTokens"
        ).withArgs(
          user1.address,
          BigNumber.from(amount)
        );

        let totalSupply = await vestingContract.totalSupply();
        totalSupply.should.be.equal(BigNumber.from(Number(AMOUNT) - amount));
      });

      it("should withdraw tokens to private investor", async () => {
        await vestingContract.addInvestors([user1.address], [AMOUNT], 1);
        let initialTimestamp = Math.floor(Date.now() / 1000) + 10;
        await vestingContract.setInitialTimestamp(initialTimestamp);
        await time.increase(CLIFF_TIME + 10);

        let receipt = await vestingContract.connect(user1).withdrawTokens();

        let timestamp = await getCurrentTimestamp(receipt.blockNumber);
        let vestingTimePassed = timestamp - initialTimestamp;
        let amount = Math.floor(Number(AMOUNT) * 3 / 20) + Math.floor(Math.floor((17 * Number(AMOUNT) * vestingTimePassed) / 20) / VESTING_TIME);

        await expect(receipt).to.emit(
          vestingContract,
          "WithdrawTokens"
        ).withArgs(
          user1.address,
          BigNumber.from(amount)
        );

        let totalSupply = await vestingContract.totalSupply();
        totalSupply.should.be.equal(BigNumber.from(Number(AMOUNT) - amount));
      });

      it("should withdraw all tokens to investor after vesting", async () => {
        await vestingContract.addInvestors([user1.address], [AMOUNT], 0);
        let initialTimestamp = Math.floor(Date.now() / 1000) + 10;
        await vestingContract.setInitialTimestamp(initialTimestamp);
        await time.increase(VESTING_TIME + 10);

        let receipt = await vestingContract.connect(user1).withdrawTokens();
        await expect(receipt).to.emit(
          vestingContract,
          "WithdrawTokens"
        ).withArgs(
          user1.address,
          AMOUNT
        );

        let totalSupply = await vestingContract.totalSupply();
        totalSupply.should.be.equal(BigNumber.from(0));
      });

      it("shouldn't withdraw tokens to investor if timestamp not initialized", async () => {
        await expectRevert(
          vestingContract.connect(user1).withdrawTokens(),
          "Vesting: not initialized"
        );
      });

      it("shouldn't withdraw tokens to investor if you are not a investor", async () => {
        let initialTimestamp = Math.floor(Date.now() / 1000) + 10;
        await vestingContract.setInitialTimestamp(initialTimestamp);
        await time.increase(CLIFF_TIME + 10);

        await expectRevert(
          vestingContract.connect(user1).withdrawTokens(),
          "Vesting: you are not a investor"
        );
      });

      it("shouldn't withdraw tokens to investor if no tokens available", async () => {     
        let initialTimestamp = Math.floor(Date.now() / 1000) + 10;
        await vestingContract.addInvestors([user1.address], [AMOUNT], 0);
        await vestingContract.setInitialTimestamp(initialTimestamp);
        await time.increase(CLIFF_TIME + 10);
        await vestingContract.connect(user1).withdrawTokens();

        await expectRevert(
          vestingContract.connect(user1).withdrawTokens(),
          "Vesting: no tokens available"
        );
      });

    });
  });

  async function getCurrentTimestamp(blockNumber: number): Promise<any> {
    return (await ethers.provider.getBlock(blockNumber)).timestamp;
  };

});