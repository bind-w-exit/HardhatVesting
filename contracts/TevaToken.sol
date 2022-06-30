// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TevaToken is ERC20, AccessControl {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    address private _owner;


    modifier onlyOwner() {
        //require(hasRole(OWNER_ROLE, msg.sender), "TevaToken: caller is not the owner");
        require(_owner == msg.sender, "TevaToken: caller is not the owner");
        _;
    }

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "TevaToken: Caller is not a minter");
        _;
    }

    modifier onlyBurner() {
        require(hasRole(BURNER_ROLE, msg.sender), "TevaToken: Caller is not a burner");
        _;
    }

    constructor() ERC20("Teva token", "TEVA") {
        _owner = msg.sender;
        _setupRole(OWNER_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);
        _setRoleAdmin(MINTER_ROLE, OWNER_ROLE);
        _setRoleAdmin(BURNER_ROLE, OWNER_ROLE);
    }
    function addMinter(address minter) external onlyOwner {
        grantRole(MINTER_ROLE, minter);
    }

    function addBurner(address burner) external onlyOwner {
        grantRole(BURNER_ROLE, burner);
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function mint(address account, uint256 amount) external onlyMinter returns (bool) {    
        _mint(account, amount);
        return true;
    }

    
     /**
     * @dev Destroys amount tokens from account, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function burn(uint256 amount) external onlyBurner returns (bool) { 
        _burn(msg.sender, amount);
        return true;
    }


    function owner() public view returns (address) {
        return _owner;
    }

}