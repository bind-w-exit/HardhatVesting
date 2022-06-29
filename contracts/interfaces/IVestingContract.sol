// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;


interface IVestingContract {

    enum AllocationType {
        Seed,
        Private
    }

    //  Param:
    //- initial timestamp
    function setInitialTimestamp(uint256 initialTimestamp) external;

    //This function should mint tokens for vesting contract equal to the sum of param tokens amount
    // Params:
    // - investors
    // - tokens amount for each investor
    // - allocation type
    function addInvestors(address[] calldata investors, uint256[] calldata amounts, AllocationType allocationType) external;

    //Should transfer tokens to investors. 
    //Without parameters.
    function withdrawTokens() external;
}