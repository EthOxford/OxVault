// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./swap.sol";
import "./vault.sol";

contract C3ETFContract {

    using SafeMath for uint256;
    uint256 public AUM_In_Usd;
    uint256 public AUM;
    uint256 public C10_Supply;
    uint256 public C10_Price;
    uint256 public current_price;
    address public swapAddress;
    address public vaultAddress; // Vault address (modifiable)
    address public constant USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    uint256 public usdcAmount;
    uint256 public price;    
    uint256 public contractBalance;
    uint256 public amount_left;
    uint256 public amountOfTokenToWithdraw;
    IERC20 public usdcToken = IERC20(USDC);
    VaultContract public vaultcontract;
    SwapContract public swapcontract;

    constructor(address _vaultcontract, address _swapcontract) 
    {
        vaultAddress = _vaultcontract;
        vaultcontract = VaultContract(_vaultcontract);
        swapAddress = _swapcontract;
        swapcontract = SwapContract(_swapcontract);
    }
    function setVaultAddress(address _vault) public {
        vaultcontract = VaultContract(_vault);
    }

    function getTotalSupply() public view returns (uint256) {
        return vaultcontract.totalSupply();
    }

    function get_AUM() public {
        AUM = swapcontract.updatePoolValue() / 1e20;//is in x *1e2
    }

    function get_c10() public view returns (uint256) {
        return AUM_In_Usd / vaultcontract.totalSupply() / 1e2;
    }

    function get_current_price() public {
        current_price = (swapcontract.updatePoolValue()/ vaultcontract.totalSupply()) / 1e2;//is in x *1e2
    }
    
    function ifswapworks(uint256 usdc) public {
        
        for (uint256 i = 0; i < 3; i++) {
            swapcontract.buy_swap(33*usdc /100, i);
        }
    }

    function get_price() public returns (uint256)
    {
        price = 0;
        AUM_In_Usd = swapcontract.updatePoolValue();
        C10_Supply = vaultcontract.totalSupply();//1e18 * x
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
        require(usdcToken.allowance(msg.sender, swapAddress) >= usdcAmount, "Please approve the contract to spend your USDC first.");
        require(usdcToken.transferFrom(msg.sender, swapAddress, usdcAmount), "USDC transfer failed");
        for (uint256 i = 0; i < 3; i++)//rajouter require ici
        {
            swapcontract.buy_swap(33*usdcAmount /100, i);
        }
        AUM_In_Usd = swapcontract.updatePoolValue();//becomes 1e 
        vaultcontract.mint(msg.sender, c2_quantity * 1e18);//(x*1e20/x*1e2)/1e18
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
        for (uint256 i = 0; i < 3; i++) 
        {
            amountOfTokenToWithdraw = ((33 * usdcAmount) /100 * 1e20) / swapcontract.assetPrices(i);//10**11
            vaultcontract.withdraw(swapAddress, swapcontract.tokenAddresses(i), amountOfTokenToWithdraw);//je withdraw du vault vers ce contrat
            swapcontract.sell_swap(address(this),amountOfTokenToWithdraw, i);//je swap les assets sur ce contract et je les envoie a mtc
        }
        withdrawFromContract(recipient, vaultAddress, usdcAmount);//mtc.withdraw1 si tu veux onlyowner
        AUM_In_Usd = swapcontract.updatePoolValue();
        vaultcontract.burn(msg.sender, c2_quantity * 1e18);
    }
}