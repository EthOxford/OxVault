// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./lastvault.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

    contract utils {

        uint256 public Pool_Value;
        mapping (address => uint256) public tokenBalances;
        AggregatorV3Interface[] public priceFeeds;//chainlink
        address[2] public tokenAddresses;
        uint256[2] public Proportion;
        uint256[2] public assetPrices;
        using SafeMath for uint256;
        uint256 public i;
        uint256 public tokenBalance;
        uint256 public tokenPrice;
        address public vaultAddress; // Vault address (modifiable)
        C10Vault public vault;

        address public constant USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
        IERC20 public usdcToken = IERC20(USDC);
        address public constant routerAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
        ISwapRouter public immutable swapRouter = ISwapRouter(routerAddress);
        uint24 public constant poolFee = 3000;
 
        constructor(address _vault) {
            vaultAddress = _vault;
            vault = C10Vault(_vault);
            Proportion[0] = 50;
            Proportion[1] = 50;
            priceFeeds = new AggregatorV3Interface[](2);
            priceFeeds[0] = AggregatorV3Interface(0xAB594600376Ec9fD91F8e885dADF0CE036862dE0); //MATIC/USD price feed
            priceFeeds[1] = AggregatorV3Interface(0xdf0Fb4e4F928d2dCB76f438575fDD8682386e13C); //UNI/USD price feed
            tokenAddresses[0] = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;//WPOL
            tokenAddresses[1] = 0xb33EaAd8d922B1083446DC23f610c2567fB5180f;//UNI
        }

        function setVaultAddress(address _vault) public {
            vaultAddress = _vault;
            vault = C10Vault(_vault);
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