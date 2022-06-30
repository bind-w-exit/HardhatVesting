// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol'; 
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IVestingContract.sol";
import "./TevaToken.sol";


contract VestingContract is IVestingContract, Ownable {
    using SafeERC20 for IERC20;  

    struct Investor {
        uint256 amount;    
        uint256 withdrawnAmount;
        AllocationType allocationType;
    }

    uint256 private constant VESTING_TIME = 600 minutes;
    uint256 private constant CLIFF_TIME = 10 minutes;

    mapping(address => Investor) public investorsBalances;
    
    uint256 public initialTimestamp;
    uint256 public totalSupply;
    address public token;
    bool public timestampInitialized;
    

    constructor(address _token) {
        require(_token != address(0), "Vesting: token address is zero");
        token = _token;
    }

    function setInitialTimestamp(uint256 _initialTimestamp) onlyOwner external {
        require(!timestampInitialized, "Vesting: timestamp has already been initialized");
        require(_initialTimestamp > block.timestamp, "Vesting: initial timestamp is less than the current block timestamp");
        initialTimestamp = _initialTimestamp;
        timestampInitialized = true;
        emit SetInitialTimestamp(_initialTimestamp);
    }

    function addInvestors(address[] calldata _investors, uint256[] calldata _amounts, AllocationType _allocationType) onlyOwner external {
        require(!timestampInitialized, "Vesting: vesting has already been started");
        require(_investors.length == _amounts.length, "Vesting: the number of items in the arrays does't match");
        
        uint256 amountsSum;
        for (uint256 i = 0; i < _investors.length; i++) {
            amountsSum += _amounts[i];
            investorsBalances[_investors[i]] = Investor(_amounts[i], 0, _allocationType);
            emit AddInvestor(_investors[i], _amounts[i], _allocationType);
        }

        totalSupply += amountsSum;
        TevaToken(token).mint(address(this), amountsSum);
    }

    function withdrawTokens() external {
        Investor memory investor = investorsBalances[msg.sender];

        require(timestampInitialized, "Vesting: timestamp not initialized");
        require(initialTimestamp + CLIFF_TIME <= block.timestamp, "Vesting: cliff time is not over");
        require(investor.amount > 0, "Vesting: you are not a investor");

        uint256 avaiableBalance;  
        uint256 vestingTimePassed = (block.timestamp - initialTimestamp);

        if(initialTimestamp + VESTING_TIME > block.timestamp) {
            if(investor.allocationType == AllocationType.Seed)
                //avaiableBalance =  (amount * 10%) + (amount * 90% / 100%) * vestingTimePassed / (VESTING_TIME / 100%)
                avaiableBalance = investor.amount / 10 + (9 * investor.amount * vestingTimePassed) / 10 / VESTING_TIME; 
            else if (investor.allocationType == AllocationType.Private)
                //avaiableBalance =  (amount * 15%) + (amount * 85% / 100%) * vestingTimePassed / (VESTING_TIME / 100%)
                avaiableBalance = investor.amount * 3 / 20 + (17 * investor.amount * vestingTimePassed) / 20 / VESTING_TIME;
        } else
            avaiableBalance = investor.amount;

        uint256 amountToSend = avaiableBalance - investor.withdrawnAmount; 
        require(amountToSend > 0, "Vesting: no tokens available");

        investorsBalances[msg.sender].withdrawnAmount += amountToSend;     
        totalSupply -= amountToSend;
        IERC20(token).safeTransfer(msg.sender, amountToSend);
        emit WithdrawTokens(msg.sender, avaiableBalance);
    }
}