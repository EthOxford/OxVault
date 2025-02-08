// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; 

contract C10Token is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("C2index", "C2") Ownable(msg.sender) {}

    function mint(uint256 amount) public  {
        _mint(msg.sender, amount);
    }

    function burnTokens(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function burnAllTokens() public onlyOwner {
        _burn(owner(), totalSupply()); // Burns all tokens from the owner's balance
    }
}

contract C10Vault is C10Token {

    address public C10Contract;
    address[2] public tokens;

        constructor() {
            tokens[0] = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;//WPOL
            tokens[1] = 0xb33EaAd8d922B1083446DC23f610c2567fB5180f;//UNI
        }

    function setC2ContractAsOwner(address _C10Contract) public {
        C10Contract = _C10Contract;
        transferOwnership(_C10Contract);
    }
    
    function withdraw(address utils_address, address _tokenAddress, uint256 _amount) public {
        IERC20 token = IERC20(_tokenAddress);
        require(_amount >= 0, "Amount must be greater than zero");
        require(token.balanceOf(address(this)) >= _amount, "Insufficient balance");
        token.transfer(utils_address, _amount);
    }

    function withdrawAllTokens() public {
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20 token = IERC20(tokens[i]);
            uint256 balance = token.balanceOf(address(this));
            if (balance > 0) {
                token.transfer(msg.sender, balance);
            }
        }
    }
}
