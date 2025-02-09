// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./vault.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

    contract SwapContract 
    {
        uint256 public Pool_Value;
        mapping (address => uint256) public tokenBalances;
        AggregatorV3Interface[] public priceFeeds;//chainlink
        address[3] public tokenAddresses;
        uint256[3] public Proportion;
        uint256[3] public assetPrices;
        using SafeMath for uint256;
        uint256 public i;
        uint256 public tokenBalance;
        uint256 public tokenPrice;
        address public vaultAddress; // Vault address (modifiable)
        VaultContract public vaultcontract;

        address public constant USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
        IERC20 public usdcToken = IERC20(USDC);
        address public constant routerAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
        ISwapRouter public immutable swapRouter = ISwapRouter(routerAddress);
        uint24 public constant poolFee = 3000;
 
        constructor(address _vault) {
            vaultAddress = _vault;
            vaultcontract = VaultContract(_vault);
            Proportion[0] = 33;
            Proportion[1] = 33;
            Proportion[2] = 33;
            priceFeeds = new AggregatorV3Interface[](3);
            priceFeeds[0] = AggregatorV3Interface(0x72484B12719E23115761D5DA1646945632979bB6); //AAVE/USD price feed
            priceFeeds[1] = AggregatorV3Interface(0xdf0Fb4e4F928d2dCB76f438575fDD8682386e13C); //UNI/USD price feed
            priceFeeds[2] = AggregatorV3Interface(0xd9FFdb71EbE7496cC440152d43986Aae0AB76665); //LINK/USD price feed
            tokenAddresses[0] = 0xD6DF932A45C0f255f85145f286eA0b292B21C90B;//AAVE
            tokenAddresses[1] = 0xb33EaAd8d922B1083446DC23f610c2567fB5180f;//UNI
            tokenAddresses[2] = 0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39;//LINK
        }

        function setVaultAddress(address _vault) public {
            vaultAddress = _vault;
            vaultcontract = VaultContract(_vault);
        }

        function getPriceFeedsLength() public view returns (uint256) {
            return priceFeeds.length;
        }
        
        function getProportion(uint256 index) public view returns (uint256) {
            return Proportion[index];
        }

        function updateAssetValues() public 
        {
            for (i = 0; i < priceFeeds.length; i++) 
            {
                (, int256 price, , , ) = priceFeeds[i].latestRoundData();
                assetPrices[i] = uint256(price);
            }
        }

        function updateTokenBalance() public
        {
            for (i = 0; i < priceFeeds.length; i++){
                uint256 nextBalance = IERC20(tokenAddresses[i]).balanceOf(vaultAddress);//with 18 decimals
                tokenBalances[tokenAddresses[i]] = nextBalance;
            }
        }
        
        function updatePoolValue() public returns (uint256)
        {
            Pool_Value = 0; 
            updateTokenBalance(); 
            updateAssetValues();
            for (i = 0; i < priceFeeds.length; i++) {
                tokenBalance = (tokenBalances[tokenAddresses[i]]);//1e18
                tokenPrice = (assetPrices[i]);
                Pool_Value = Pool_Value.add(tokenBalance.mul(tokenPrice));//1e20
            }
            return (Pool_Value);
        }

         function buy_swap(uint256 amountIn, uint256 j) public returns (uint256 amountOut)
        {
            usdcToken.approve(address(swapRouter), amountIn);
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: USDC,
                    tokenOut: tokenAddresses[j],
                    fee: poolFee,
                    recipient: vaultAddress,
                    deadline: block.timestamp,
                    amountIn: amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });
            amountOut = swapRouter.exactInputSingle(params);     
        }

        function sell_swap(address recipient, uint256 _amountIn, uint256 j) public returns (uint256)
        {
            IERC20 token = IERC20(tokenAddresses[j]);
            token.approve(address(swapRouter), _amountIn);
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: tokenAddresses[j],
                    tokenOut: USDC,
                    fee: poolFee,
                    recipient: recipient,
                    deadline: block.timestamp,
                    amountIn: _amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
            });
            uint256 amountOut = swapRouter.exactInputSingle(params);
        return (amountOut);
        }
    }