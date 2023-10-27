// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

interface IExchange {
    // ===================================== events ===================================== //
    /**
     * @notice 购买token触发的事件
     * @param buyer 用户地址
     * @param ethSold 售出的eth数量
     * @param tokensBought 购买到的token数量
     */
    event TokenPurchase(address indexed buyer, uint256 indexed ethSold, uint256 indexed tokensBought);

    /**
     * @notice 购买eth触发的事件
     * @param buyer 用户地址
     * @param tokendSold 售出的token地址
     * @param ethBought 购买到的eth数量
     */
    event EthPurchase(address indexed buyer, uint256 indexed tokendSold, uint256 indexed ethBought);

    /**
     * @notice 添加流动性时触发的事件
     * @param provider 用户地址
     * @param ethAmount 投入eth数量
     * @param tokenAmount 投入的token数量
     */
    event AddLiquidity(address indexed provider, uint256 indexed ethAmount, uint256 indexed tokenAmount);

    /**
     * @notice 移除流动性时触发的事件
     * @param provider 用户地址
     * @param ethAmount eth提现数量
     * @param tokenAmount token提现数量
     */
    event RemoveLiquidity(address indexed provider, uint256 indexed ethAmount,uint256 indexed tokenAmount);

    // ===================================== functions ===================================== //

    function addLiquidity(
        uint256 minLiquidity,
        uint256 maxTokens,
        uint256 deadline
    ) external payable returns (uint256);

    function removeLiquidity(
        uint256 lptAmount,
        uint256 minEth,
        uint256 minTokens,
        uint256 deadline
    ) external returns (uint256, uint256);

    function ethToTokenSwapInput(
        uint256 minTokens,
        uint256 deadline
    ) external payable returns (uint256);

    function ethToTokenTransferInput(
        uint256 minTokens,
        uint256 deadline,
        address recipient
    ) external payable returns (uint256);

    function ethToTokenSwapOutput(
        uint256 tokensBought,
        uint256 deadline
    ) external payable returns (uint256);

    function ethToTokenTransferOutput(
        uint256 tokensBought,
        uint256 deadline,
        address recipient
    ) external payable returns (uint256);

    function tokenToEthSwapInput(
        uint256 tokensSold,
        uint256 minEth,
        uint256 deadline
    ) external returns (uint256);

    function tokenToEthTransferInput(
        uint256 tokensSold,
        uint256 minEth,
        uint256 deadline,
        address recipient
    ) external returns (uint256);

    function tokenToEthSwapOutput(
        uint256 ethBought,
        uint256 maxTokens,
        uint256 deadline
    ) external returns (uint256);

    function tokenToEthTransferOutput(
        uint256 ethBought,
        uint256 maxTokens,
        uint256 deadline,
        address recipient
    ) external returns (uint256);

    function tokenToTokenSwapInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address tokenAddr
    ) external returns (uint256);

    function tokenToTokenTransferInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address tokenAddr,
        address recipient
    ) external returns (uint256);

    function tokenToTokenSwapOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address tokenAddr
    ) external returns (uint256);

    function tokenToTokenTransferOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address recipient,
        address tokenAddr
    ) external returns (uint256);

    function tokenToExchangeSwapInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address exchangeAddr
    ) external returns (uint256);

    function tokenToExchangeTransferInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address recipient,
        address exchangeAddr
    ) external returns (uint256);

    function tokenToExchangeSwapOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address exchangeAddr
    ) external returns (uint256);

    function tokenToExchangeTransferOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address recipient,
        address exchangeAddr
    ) external returns (uint256);

    function getEthToTokenInputPrice(
        uint256 ethSold
    ) external view returns (uint256);

    function getEthToTokenOutputPrice(
        uint256 tokensBought
    ) external  view returns (uint256);

    function getTokenToEthInputPrice(
        uint256 tokenSold
    ) external view returns (uint256);

    function getTokenToEthOutputPrice(
        uint256 ethBought
    ) external view returns (uint256);

    /**
     * @notice 查询当前exchange交易的token
     * @return token的合约地址
     */
    function tokenAddress() external view returns (address);

    /**
     * @notice 查询创建当前exchange的factory
     * @return factory的合约地址
     */
    function factoryAddress() external view returns (address);

    function balanceOf(address owner) external view returns (uint256);
}
