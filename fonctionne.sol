// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils.sol";
import "./lastvault.sol";

contract C10ETF {

    using SafeMath for uint256;
    uint256 public AUM_In_Usd;
    uint256 public AUM;
    uint256 public C10_Supply;
    uint256 public C10_Price;
    uint256 public current_price;
    address public utilsAddress;
    address public vaultAddress; // Vault address (modifiable)
    address public constant USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    IERC20 public usdcToken = IERC20(USDC);
    C10Vault public vault;
    utils public utilsInstance;

    constructor(address _vault, address _utils) 
    {
        vaultAddress = _vault;
        vault = C10Vault(_vault);
        utilsAddress = _utils;
        utilsInstance = utils(_utils);
    }
    function setVaultAddress(address _vault) public {
            vault = C10Vault(_vault);
    }

    function getTotalSupply() public view returns (uint256) {
        return vault.totalSupply();
    }

    function get_AUM() public {
        AUM = utilsInstance.updatePoolValue() / 1e20;//is in x *1e2
    }

    function get_c10() public view returns (uint256) {
        return AUM_In_Usd / vault.totalSupply() / 1e2;
    }

    function get_current_price() public {
        current_price = (utilsInstance.updatePoolValue()/ vault.totalSupply()) / 1e2;//is in x *1e2
    }
    
    function ifswapworks(uint256 usdc) public {
        
        for (uint256 i = 0; i < 2; i++) {
            utilsInstance.buy_swap(50*usdc /100, i);
        }
    }

    uint256 public usdcAmount;
    uint256 public price;    
    uint256 public contractBalance;
    uint256 public amount_left;
    uint256 public amountOfTokenToWithdraw;

    function get_price() public returns (uint256)
    {
        price = 0;
        AUM_In_Usd = utilsInstance.updatePoolValue();
        C10_Supply = vault.totalSupply();//1e18 * x
        if (AUM_In_Usd == 0 && C10_Supply == 0)
        {
             return (1000);
        }        
        require(C10_Supply > 0, "C10_Supply cannot be zero");
        price = (AUM_In_Usd / C10_Supply) / 1e2;//1e20
        return (price);
    }

    function buyETF_Final(uint256 c2_quantity) public  
    {

        C10_Price = get_price();//1000 at start ie 0.001 usdc
        usdcAmount =  c2_quantity * C10_Price;//0.001usdc ie 1000
        require(usdcToken.balanceOf(msg.sender) >= usdcAmount, "Not enough USDC in wallet");
        require(usdcToken.allowance(msg.sender, utilsAddress) >= usdcAmount, "Please approve the contract to spend your USDC first.");
        require(usdcToken.transferFrom(msg.sender, utilsAddress, usdcAmount), "USDC transfer failed");
        for (uint256 i = 0; i < 2; i++)//rajouter require ici
        {
            utilsInstance.buy_swap(50*usdcAmount /100, i);
        }
        AUM_In_Usd = utilsInstance.updatePoolValue();//becomes 1e 
        vault.mint(c2_quantity * 1e18);//(x*1e20/x*1e2)/1e18
    }

    function withdrawFromContract(address thirdPartyAddress,address vault_address, uint256 amount_to_sell) public {
        require(thirdPartyAddress != address(0), "Third-party address not set yet.");
        contractBalance = usdcToken.balanceOf(address(this));
        if (contractBalance > amount_to_sell){
            amount_left = contractBalance - amount_to_sell;//x * 1e18
            usdcToken.transfer(vault_address, amount_left);
            contractBalance = contractBalance - amount_left;
        }
        usdcToken.transfer(thirdPartyAddress,contractBalance);
    }

    function sellETF_Final(uint256 c2_quantity) public 
    {
        address recipient = msg.sender;
        C10_Price = get_price();//1000 at start ie 0.001 usdc
        usdcAmount =  c2_quantity * C10_Price;//0.001usdc ie 1000
        for (uint256 i = 0; i < 2; i++) 
        {
            amountOfTokenToWithdraw = ((50 * usdcAmount) /100 * 1e20) / utilsInstance.assetPrices(i);//10**11
            vault.withdraw(utilsAddress, utilsInstance.tokenAddresses(i), amountOfTokenToWithdraw);//je withdraw du vault vers ce contrat
            utilsInstance.sell_swap(address(this),amountOfTokenToWithdraw, i);//je swap les assets sur ce contract et je les envoie a mtc
        }
        withdrawFromContract(recipient, vaultAddress, usdcAmount);//mtc.withdraw1 si tu veux onlyowner
        AUM_In_Usd = utilsInstance.updatePoolValue();
        vault.burn(c2_quantity * 1e18);
    }
}