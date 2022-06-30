// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IVestingContract {

    enum AllocationType {
        Seed,
        Private
    }

    event SetInitialTimestamp(uint256 initialTimestamp);
    event AddInvestor(address indexed investor, uint256 amount, AllocationType allocationType);
    event WithdrawTokens(address indexed investor, uint256 amount);


    function setInitialTimestamp(uint256 initialTimestamp) external;

    function addInvestors(address[] calldata investors, uint256[] calldata amounts, AllocationType allocationType) external;

    function withdrawTokens() external;
}