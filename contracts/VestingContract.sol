// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol'; 
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IVestingContract.sol";
import "./TevaToken.sol";


contract VestingContract is IVestingContract, Ownable {
    using SafeERC20 for IERC20;  

    uint256 private constant VESTING_TIME = 600 minutes;
    uint256 private constant CLIFF_TIME = 10 minutes;

    mapping(address => Investor) public investorsInfo;
    
    uint256 public initialTimestamp;
    uint256 public totalSupply;
    address public immutable token;
    bool public timestampInitialized;
    
    /**
     * @dev Initializes the accepted token as a reward token.
     *
     * @param _token ERC-20 token address.
     */
    constructor(address _token) {
        require(_token != address(0), "Vesting: token address is zero");
        token = _token;
    }

    /**
     * @dev Initializes vesting start time.
     * Can only be called by the current owner.
     * Can be called only once.
     *
     * Emits an {SetInitialTimestamp} an event that indicates the initialization of the vesting start time.
     *
     * @param _initialTimestamp vesting start time
     */
    function setInitialTimestamp(uint256 _initialTimestamp) external override onlyOwner {
        require(!timestampInitialized, "Vesting: timestamp has already been initialized");
        require(_initialTimestamp > block.timestamp, "Vesting: initial timestamp is less than the current block timestamp");
        initialTimestamp = _initialTimestamp;
        timestampInitialized = true;
        emit SetInitialTimestamp(_initialTimestamp);
    }

    /**
     * @dev Adds investors with an amount for each.
     * Can only be called by the current owner.
     *
     * Emits an {AddInvestors} an event indicating the addition of an investor with an amount of tokens.
     *
     * @param _investors Array of addresses of investors.
     * @param _amounts Array of token amounts that will be added to the addresses of investors.
     * @param _allocationType Seed or Private allocation type
     */
    function addInvestors(address[] calldata _investors, uint256[] calldata _amounts, AllocationType _allocationType) external override onlyOwner {
        require(!timestampInitialized, "Vesting: vesting has already been started");
        require(_investors.length == _amounts.length, "Vesting: the number of items in the arrays does't match");
        
        uint256 totalAmount;
        for (uint256 i = 0; i < _investors.length; i++) { 
            _addInvestor(_investors[i], _amounts[i], _allocationType);           
            totalAmount += _amounts[i];      
        }

        totalSupply += totalAmount;
        TevaToken(token).mint(address(this), totalAmount);
    }

    /**
     * @dev Transfers the amount of reward tokens back to the owner.
     * Without parameters.

     * Emits an {WithdrawTokens} event that indicates who and how much withdraw tokens from the contract.
     */
    function withdrawTokens() external override{
        Investor storage investor = investorsInfo[msg.sender];

        require(timestampInitialized, "Vesting: not initialized");
        require(investor.amount > 0, "Vesting: you are not a investor");

        uint256 amountToSend = _amountToSend(investor);

        require(amountToSend > 0, "Vesting: no tokens available");
        require(amountToSend <= totalSupply, "Vesting: none tokens in the contact");

        investor.withdrawnAmount += amountToSend;     
        totalSupply -= amountToSend;
        IERC20(token).safeTransfer(msg.sender, amountToSend);
        emit WithdrawTokens(msg.sender, amountToSend);
    }

    /**
     * @dev Transfers the amount of reward tokens back to the owner.
     * Can only be called by the current owner.
     * Without parameters.
     *
     * Emits an {WithdrawTokens} event that indicates who and how much withdraw tokens from the contract.
     */
    function emergencyWithdraw() external onlyOwner {
        require(totalSupply > 0, "The transaction amount is zero");

        uint256 amount = totalSupply;
        totalSupply = 0;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit WithdrawTokens(msg.sender, amount);
    }

    function _addInvestor(address _investor, uint256 _amount, AllocationType _allocationType) internal {
        require(investorsInfo[_investor].amount == 0, "Vesting: this investor already exist");

        uint256 initialAmount;
        if(_allocationType == AllocationType.Seed)
            initialAmount = _amount * 10 / 100;
        else 
            initialAmount = _amount * 15 / 100;

        investorsInfo[_investor] = Investor(_amount, initialAmount, 0, _allocationType);
        emit AddInvestor(_investor, _amount, _allocationType);
    }

    function _amountToSend(Investor storage investor) internal view returns(uint256) {
        uint256 avaiableAmount;  
        uint256 vestingTimePassed = (block.timestamp - initialTimestamp);

        if (initialTimestamp + CLIFF_TIME > block.timestamp) {
            avaiableAmount = investor.initialAmount;
        } else if (initialTimestamp + VESTING_TIME > block.timestamp) {
            if(investor.allocationType == AllocationType.Seed)
                //avaiableBalance =  (amount * 10%) + (amount * 90% / 100%) * vestingTimePassed / (VESTING_TIME / 100%)
                avaiableAmount = investor.initialAmount + (9 * investor.amount * vestingTimePassed) / 10 / VESTING_TIME; 
            else if (investor.allocationType == AllocationType.Private)
                //avaiableBalance =  (amount * 15%) + (amount * 85% / 100%) * vestingTimePassed / (VESTING_TIME / 100%)
                avaiableAmount = investor.initialAmount + (17 * investor.amount * vestingTimePassed) / 20 / VESTING_TIME;
        } else
            avaiableAmount = investor.amount;

        uint256 amountToSend = avaiableAmount - investor.withdrawnAmount;
        return amountToSend; 
    }
}