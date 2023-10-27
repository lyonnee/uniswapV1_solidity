// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {IExchange} from "./IExchange.sol";
import {IFactory} from "./IFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract Exchange is IExchange, IERC20,IERC20Errors {
    /* ================================== Exchange Fields ================================= */
    IERC20 public token;
    IFactory public factory;
    /* ================================== Exchange END ==================================== */

    /* ================================== ERC20 Fields ==================================== */
    string public name;
    string public symbol;
    uint256 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) private balances;
    mapping(address account => mapping(address spender => uint256)) public allowances;

    /* ================================== ERC20 END ======================================= */

    constructor() {
    }

    bool initialized;
    function setup(address tokenAddr) external {
        require(initialized == false, "");
        initialized = true;

        token = IERC20(tokenAddr);
        factory = IFactory(msg.sender);
        name = "UniswapV1";
        symbol = "UniswapV1";
        decimals = 18;
    }

    /* ================================== Exchange Functions ================================= */
    /**
     * @dev 使用修饰词统一检查交易是否超时
     */
    modifier noTimeout(uint256 deadline) {
        require(block.timestamp <= deadline, "transaction has timed out");
        _;
    }

    function _selfAddress() internal view returns (address) {
        return address(this);
    }

    function _selfEthBalance() internal view returns (uint256) {
        return _selfAddress().balance;
    }

    function _selfTokenBalance() internal view returns (uint256) {
        return token.balanceOf(_selfAddress());
    }

    /**
     * @notice 按当前比例存入 ETH 和 token 并铸造 LPtoken 代币 给质押者. 
     * @dev 当 LPtoken 总供应量为 0 时，minLiquidity 无效
     * @param minLiquidity 接受的铸造 LPtoken 最小数量
     * @param maxTokens 存入token的最大数量. 如果 LPtoken 总供应量为 0，则存入最大数量
     * @param deadline 交易超时时间
     * @return 实际铸造 LPtoken 的数量
     */
    function addLiquidity(
        uint256 minLiquidity,
        uint256 maxTokens,
        uint256 deadline
    ) external payable noTimeout(deadline) returns (uint256) {
        require(
            maxTokens > 0 && msg.value > 0,
            "the input and output must be greater than 0"
        );

        if (totalSupply > 0) {
            uint256 _totalLiquidity = totalSupply;
            require(minLiquidity > 0, "minLiquidity must be greater than 0");
            // 添加前流动性池的 eth 余额
            uint256 _ethReserve = _selfEthBalance() - msg.value;
            // 添加前流动性池的 token 余额
            uint256 _tokenReserve = _selfTokenBalance();
            // 用户需要添加的 token 的金额
            uint256 _tokenAmount = (msg.value * _tokenReserve) /
                _ethReserve +
                1;
            // LP token的铸造数量
            uint256 _liquidityMinted = (msg.value * _totalLiquidity) /
                _ethReserve;

            // 断言 需要添加的token数量和铸造的LPtoken是否符合用户预期
            require(
                maxTokens >= _tokenAmount && _liquidityMinted >= minLiquidity,
                "out of expetation"
            );

            // 从用户账户转出 token
            assert(
                token.transferFrom(msg.sender, _selfAddress(), _tokenAmount)
            );
            // 更新用户的LPtoken余额和当前发行的LPtoken总量
            balances[msg.sender] += _liquidityMinted;
            totalSupply += _totalLiquidity + _liquidityMinted;

            // 触发添加流动性和增发LPtoken的事件
            emit AddLiquidity(msg.sender, msg.value, _tokenAmount);
            emit Transfer(address(0), msg.sender, _tokenAmount);
            return _liquidityMinted;
        } else {
            require(
                msg.value >= 1000000000,
                "add liquidity ETH must be greater than 0.000000001"
            );
            // x * y = k
            // 当前k没有确定, 所以eth和token的数量比例没有要求
            uint256 _tokenAmount = maxTokens;
            uint256 _initialLiquidity = _selfAddress().balance;

            totalSupply = _initialLiquidity;
            balances[msg.sender] = _initialLiquidity;

            assert(
                token.transferFrom(msg.sender, _selfAddress(), _tokenAmount)
            );

            emit AddLiquidity(msg.sender, msg.value, _tokenAmount);
            emit Transfer(address(0), msg.sender, _initialLiquidity);
            return _initialLiquidity;
        }
    }


    /**
     * @notice 从流动池提现
     * @dev 销毁 LPtoken 以当前比例提取ETH和token
     * @param lptAmount 要销毁的 LPtoken 数量
     * @param minEth 最小 eth 输出数量
     * @param minTokens 最小 token 输出数量
     * @param deadline 交易超时时间
     * @return 实际提取的 ETH 和 token 数量
     */
    function removeLiquidity(
        uint256 lptAmount,
        uint256 minEth,
        uint256 minTokens,
        uint256 deadline
    ) external noTimeout(deadline) returns (uint256, uint256) {
        require(
            lptAmount > 0 && minEth > 0 && minTokens > 0,
            "the input and output must be greater than 0"
        );

        uint256 _totalLiquidity = totalSupply;
        assert(_totalLiquidity > 0);
        // 当前流动性池中token储备数量
        uint256 _tokenReserve = _selfTokenBalance();
        // 可以提现的eth金额
        uint256 _ethAmount = (lptAmount * _selfEthBalance()) / _totalLiquidity;
        // 可以提现的token金额
        uint256 _tokenAmount = (lptAmount * _tokenReserve) / _totalLiquidity;
        // 断言 可以提现的eth和token是否符合用户预期
        require(
            _ethAmount > minEth && _tokenAmount > minTokens,
            "out of expetation"
        );
        // 更新用户的LPtoken余额和当前发行的LPtoken总量
        balances[msg.sender] -= lptAmount;
        totalSupply -= lptAmount;

        // 转账 eth 和 token给用户
        payable(msg.sender).transfer(_ethAmount);
        assert(token.transfer(msg.sender, _tokenAmount));

        // 触发事件
        emit RemoveLiquidity(msg.sender, _ethAmount, _tokenAmount);
        emit Transfer(msg.sender, address(0), lptAmount);

        return (_ethAmount,_tokenAmount);
    }

    /**
     * @dev 精确指定卖出（input）值，确定池子中买入单币种卖出币种存量
     * @param inputAmount 卖出的eth/token数量
     * @param inputReserve 卖出的eth/token的储备量
     * @param outputReserve 买入的eth/token的储备量
     * @return 能够买入eth/token数量
     */
    function _getInputPrice(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) internal pure returns (uint256) {
        assert(inputReserve > 0 && outputReserve > 0);
        // 扣除手续费后实际卖出的eth/token数量
        uint256 inputAmountWithFee = inputAmount * 997;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 1000) + inputAmountWithFee;
        return numerator / denominator;
    }

    /**
     * @dev 精确指定买入（output）值，确定池子中买入单币种卖出币种存量
     * @param outputAmount 买入的eth/token数量
     * @param inputReserve 卖出的eth/token的储备量
     * @param outputReserve 卖买的eth/token的储备量
     * @return 实际要卖出的eth/token数量
     */
    function _getOutputPrice(
        uint256 outputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) internal pure returns (uint256) {
        assert(inputReserve > 0 && outputReserve > 0);
        uint256 numerator = inputReserve * outputAmount * 1000;
        uint256 denominator = (outputReserve - outputAmount) * 997;
        return numerator / denominator + 1;
    }

    function _ethToTokenInput(
        uint256 ethSold,
        uint256 minTokens,
        address buyer,
        address recipient
    ) internal returns (uint256) {
        assert(ethSold > 0 && minTokens > 0);
        // 接收到用户转入的eth之前的eth储备量
        uint256 _ethReserve = _selfEthBalance() - ethSold;
        // 当前token的储备量
        uint256 _tokenReserve = _selfTokenBalance();
        // 能够买到的token数量
        uint256 _tokensBought = _getInputPrice(
            ethSold,
            _ethReserve,
            _tokenReserve
        );
        // 断言 能购买到的token数量符合用户预期
        assert(_tokensBought >= minTokens);

        // 转账token给用户
        assert(token.transfer(recipient, _tokensBought));
        // 触发购买token的事件
        emit TokenPurchase(buyer, ethSold, _tokensBought);
        return _tokensBought;
    }

    /**
     * @notice 卖出ETH 以买入 token
     * @dev 明确指定要卖出的ETH数量
     * @param minTokens 最小 token 买入数量
     * @param deadline 交易超时时间
     * @return 实际买入的token数量
     */
    function ethToTokenSwapInput(
        uint256 minTokens,
        uint256 deadline
    ) external payable noTimeout(deadline) returns (uint256) {
        return _ethToTokenInput(msg.value, minTokens, msg.sender, msg.sender);
    }

    /**
     * @notice 卖出ETH 以买入 token, 并把token 转给recipient
     * @param minTokens 能接受的最小 token 买入数量
     * @param deadline 交易超时时间
     * @param recipient token接收地址
     * @return 实际买入的token数量
     */
    function ethToTokenTransferInput(
        uint256 minTokens,
        uint256 deadline,
        address recipient
    ) external payable noTimeout(deadline) returns (uint256) {
        require(
            recipient != address(0),
            "the recipient cannot be zero address"
        );
        return _ethToTokenInput(msg.value, minTokens, msg.sender, recipient);
    }

    function _ethToTokenOutput(
        uint256 tokensBought,
        uint256 maxEth,
        address buyer,
        address recipient
    ) internal returns (uint256) {
        assert(tokensBought > 0 && maxEth > 0);
        uint256 _tokenReserve = _selfTokenBalance();
        uint256 _ethReserve = _selfEthBalance() - maxEth;
        // 实际换出的eth金额
        uint256 _ethSold = _getOutputPrice(maxEth, _ethReserve, _tokenReserve);
        // 多支付的eth金额
        uint256 _ethRefund = maxEth - _ethSold;
        // 返还多支付的eth
        if (_ethRefund > 0) {
            payable(buyer).transfer(_ethRefund);
        }
        assert(token.transfer(recipient, tokensBought));
        emit TokenPurchase(buyer, _ethSold, tokensBought);
        return _ethSold;
    }

    /**
     * @notice 卖出ETH 以买入token
     * @dev 明确指出要买入的token数量
     * @param tokensBought 购买token的数量
     * @param deadline 交易超时时间
     * @return 实际卖出 ETH的数量
     */
    function ethToTokenSwapOutput(
        uint256 tokensBought,
        uint256 deadline
    ) external payable noTimeout(deadline) returns (uint256) {
        return
            _ethToTokenOutput(tokensBought, msg.value, msg.sender, msg.sender);
    }

    /**
     * @notice 卖出ETH 以买入token 并把token 转给recipient
     * @dev 明确指出要买入的token数量
     * @param tokensBought 购买token的数量
     * @param deadline 交易超时时间
     * @param recipient token接收地址
     * @return 实际卖出 ETH的数量
     */
    function ethToTokenTransferOutput(
        uint256 tokensBought,
        uint256 deadline,
        address recipient
    ) external payable noTimeout(deadline) returns (uint256) {
        require(
            recipient != address(0),
            "the recipient cannot be zero address"
        );
        return
            _ethToTokenOutput(tokensBought, msg.value, msg.sender, recipient);
    }

    function _tokenToEthInput(
        uint256 tokensSold,
        uint256 minEth,
        address buyer,
        address recipient
    ) internal returns (uint256) {
        assert(tokensSold > 0 && minEth > 0);
        uint256 _tokenReserve = _selfTokenBalance();
        uint256 _ethReserve = _selfEthBalance();
        // 能买到的eth数量
        uint256 _ethBought = _getInputPrice(
            tokensSold,
            _tokenReserve,
            _ethReserve
        );
        // 断言是否符合用户预期
        assert(_ethBought >= minEth);

        assert(token.transferFrom(buyer, _selfAddress(), tokensSold));
        payable(recipient).transfer(_ethBought);

        emit EthPurchase(buyer, tokensSold, _ethBought);
        return _ethBought;
    }

    /**
     * @notice 卖出token 以买入 ETH
     * @dev 明确指出要卖出的token数量
     * @param tokensSold 卖出的token数量
     * @param minEth 最小的eth买入数量
     * @param deadline 交易超时时间
     * @return 实际买入的eth数量
     */
    function tokenToEthSwapInput(
        uint256 tokensSold,
        uint256 minEth,
        uint256 deadline
    ) external noTimeout(deadline) returns (uint256) {
        return _tokenToEthInput(tokensSold, minEth, msg.sender, msg.sender);
    }

    /**
     * @notice 卖出token 以买入 ETH, 并把ETH发送给recipient
     * @dev 明确指出要卖出的token数量
     * @param tokensSold 卖出的token数量
     * @param minEth 最小的eth买入数量
     * @param deadline 交易超时时间
     * @param recipient eth接收地址
     * @return 实际买入的eth数量
     */
    function tokenToEthTransferInput(
        uint256 tokensSold,
        uint256 minEth,
        uint256 deadline,
        address recipient
    ) external noTimeout(deadline) returns (uint256) {
        require(
            recipient != address(0),
            "the recipient cannot be zero address"
        );
        return _tokenToEthInput(tokensSold, minEth, msg.sender, recipient);
    }

    function _tokenToEthOutput(
        uint256 ethBought,
        uint256 maxTokens,
        address buyer,
        address recipient
    ) internal returns (uint256) {
        assert(ethBought > 0);
        uint256 _tokenReserve = _selfTokenBalance();
        uint256 _ethReserve = _selfEthBalance();
        // 需要换出的token数量
        uint256 _tokensSold = _getOutputPrice(
            ethBought,
            _tokenReserve,
            _ethReserve
        );
        // 断言token售出数量符合用户预期
        assert(_tokensSold <= maxTokens);

        assert(token.transferFrom(buyer, _selfAddress(), _tokensSold));
        payable(recipient).transfer(ethBought);

        emit EthPurchase(buyer, _tokensSold, ethBought);
        return _tokensSold;
    }

    /**
     * @notice 卖出token以买入ETH
     * @dev 明确指出要买入的ETH的数量
     * @param ethBought 要买入的ETH数量
     * @param maxTokens 最大卖出的token数量
     * @param deadline 交易超时时间
     * @return 实际卖出的token数量
     */
    function tokenToEthSwapOutput(
        uint256 ethBought,
        uint256 maxTokens,
        uint256 deadline
    ) external noTimeout(deadline) returns (uint256) {
        return _tokenToEthOutput(ethBought, maxTokens, msg.sender, msg.sender);
    }

    /**
     * @notice 卖出token以买入ETH,并把ETH发送给recipient
     * @dev 明确指出要买入的ETH的数量
     * @param ethBought 要买入的ETH数量
     * @param maxTokens 最大卖出的token数量
     * @param deadline 交易超时时间
     * @param recipient eth接收地址
     * @return 实际卖出的token数量
     */
    function tokenToEthTransferOutput(
        uint256 ethBought,
        uint256 maxTokens,
        uint256 deadline,
        address recipient
    ) external noTimeout(deadline) returns (uint256) {
        require(
            recipient != address(0),
            "the recipient cannot be zero address"
        );
        return _tokenToEthOutput(ethBought, maxTokens, msg.sender, recipient);
    }

    /**
     * @dev Token => ETH => Token
     */
    function _tokenToTokenInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        address buyer,
        uint256 deadline,
        address recipient,
        address exchangeAddr
    ) internal returns (uint256) {
        assert(tokensSold > 0 && minTokensBought > 0 && minEthBought > 0);
        require(
            exchangeAddr != _selfAddress() && exchangeAddr != address(0),
            "exchange cannot be zero address or equal self"
        );

        uint256 _tokenReserve = _selfTokenBalance();
        uint256 _ethReserve = _selfEthBalance();
        // 获取卖出的token能买入的eth金额
        uint256 _ethBought = _getInputPrice(
            tokensSold,
            _tokenReserve,
            _ethReserve
        );
        // 断言换入的eth符合用户预期
        assert(_ethBought >= minEthBought);
        // 扣除用户token(用户卖出)
        assert(token.transferFrom(buyer, _selfAddress(), tokensSold));
        // 触发买入eth事件
        emit EthPurchase(buyer, tokensSold, _ethBought);
        // 中转交易: 用刚刚买入的ETH到指定Exchange去买入token,得到实际买入的token金额
        uint256 _tokensBought = IExchange(exchangeAddr).ethToTokenTransferInput{value:_ethBought}(
            minTokensBought,
            deadline,
            recipient
        );
        return _tokensBought;
    }

    /**
     * @notice 将token 兑换为指定token(tokenAddr）
     * @dev 精确指出要卖出的token数量
     * @param tokensSold 卖出的token数量
     * @param minTokensBought 买入token的最小数量
     * @param minEthBought token => ETH, 最小ETH数量
     * @param deadline 交易超时时间
     * @param tokenAddr 要买入的token地址
     * @return 实际买入的token数量
     */
    function tokenToTokenSwapInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address tokenAddr
    ) external noTimeout(deadline) returns (uint256) {
        address _exchangeAddr = factory.getExchange(tokenAddr);
        return
            _tokenToTokenInput(
                tokensSold,
                minTokensBought,
                minEthBought,
                msg.sender,
                deadline,
                msg.sender,
                _exchangeAddr
            );
    }

    /**
     * @notice 将tokenA 以买入 tokenB(tokenAddr) 并发送给recipient
     * @dev 精确指出要卖出的token数量
     * @param tokensSold 卖出的token数量
     * @param minTokensBought 买入token的最小数量
     * @param minEthBought token => ETH, 最小ETH数量
     * @param deadline 交易超时时间
     * @param tokenAddr 要买入的token地址
     * @param recipient token接收地址
     * @return 实际买入的token数量
     */
    function tokenToTokenTransferInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address tokenAddr,
        address recipient
    ) external noTimeout(deadline) returns (uint256) {
        address _exchangeAddr = factory.getExchange(tokenAddr);
        return
            _tokenToTokenInput(
                tokensSold,
                minTokensBought,
                minEthBought,
                msg.sender,
                deadline,
                recipient,
                _exchangeAddr
            );
    }

    /**
     * @dev 确认要买入的Atoken数量和卖出的Btoken最大数量
     * @return 实际卖出的Btoken的数量
     */
    function _tokenToTokenOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address buyer,
        address recipient,
        address exchangeAddr
    ) internal returns (uint256) {
        assert(tokensBought > 0 && maxEthSold > 0);
        require(
            exchangeAddr != _selfAddress() && exchangeAddr != address(0),
            "exchange cannot be zero address or equal self"
        );
        IExchange exchange = IExchange(exchangeAddr);
        // 获取要买入Atoken需要多少ETH
        uint256 _ethBought = exchange.getEthToTokenOutputPrice(tokensBought);
        uint256 _tokenReserve = _selfTokenBalance();
        uint256 _ethReserve = _selfEthBalance();
        // 获取买入_ethBought数量的ETH需要卖出多少Btoken
        uint256 _tokensSold = _getOutputPrice(
            _ethBought,
            _tokenReserve,
            _ethReserve
        );
        // 断言 卖出的Btoken数量 和 买入Atoken时卖出的ETH数量 是否符合预期
        assert(_tokensSold <= maxTokensSold && _ethBought <= maxEthSold);
        // 卖出Btoken到 本Exchange
        assert(token.transferFrom(buyer, _selfAddress(), _tokensSold));
        // 到Atoken的exchange,用卖出Btoken得到的ETH去买入Atoken
        uint256 _ethSold = exchange.ethToTokenTransferOutput{value:_ethBought}(
            tokensBought,
            deadline,
            recipient
        );
        emit EthPurchase(buyer, _tokensSold, _ethBought);
        return _tokensSold;
    }

    /**
     * @notice 将tokenA 以买入 tokenB(tokenAddr)
     * @dev 明确指定要买入的tokenB数量
     * @param tokensBought 要买入的tokenB数量
     * @param maxTokensSold 最大的卖出tokenA数量
     * @param maxEthSold tokenA => ETH 最大ETH数量
     * @param deadline 交易超时时间
     * @param tokenAddr 要买入的tokenB地址
     * @return 实际卖出的tokenA数量
     */
    function tokenToTokenSwapOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address tokenAddr
    ) external noTimeout(deadline) returns (uint256) {
        address _exchangeAddr = factory.getExchange(tokenAddr);
        return
            _tokenToTokenOutput(
                tokensBought,
                maxTokensSold,
                maxEthSold,
                deadline,
                msg.sender,
                msg.sender,
                _exchangeAddr
            );
    }

    /**
     * @notice 将tokenA 以买入 tokenB(tokenAddr),并将tokenB发送给recipient
     * @dev 明确指定要买入的tokenB数量
     * @param tokensBought 买入的tokenB数量
     * @param maxTokensSold 最大的tokenA卖出数量
     * @param maxEthSold tokenA => ETH 最大ETH数量
     * @param deadline 交易超时时间
     * @param recipient tokenB接收地址
     * @param tokenAddr 要买入的tokenB地址
     * @return 实际卖出的tokenA数量
     */
    function tokenToTokenTransferOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address recipient,
        address tokenAddr
    ) external noTimeout(deadline) returns (uint256) {
        address _exchangeAddr = factory.getExchange(tokenAddr);
        return
            _tokenToTokenOutput(
                tokensBought,
                maxTokensSold,
                maxEthSold,
                deadline,
                msg.sender,
                recipient,
                _exchangeAddr
            );
    }

    /**
     * @notice 将tokenA 以买入 指定交易所的tokenB(exchangeAddr)
     * @dev 允许通过非相同Factory部署的合约进行交易
     * @dev 明确指出要卖出的tokenA数量
     * @param tokensSold 卖出的tokenA数量
     * @param minTokensBought 最小买入tokenB的数量
     * @param minEthBought tokenA => ETH 最小ETH数量
     * @param deadline 交易超时时间
     * @param exchangeAddr 要买入tokenB的交易所地址
     * @return 实际买入tokenB的数量
     */
    function tokenToExchangeSwapInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address exchangeAddr
    ) external noTimeout(deadline) returns (uint256) {
        return
            _tokenToTokenInput(
                tokensSold,
                minTokensBought,
                minEthBought,
                msg.sender,
                deadline,
                msg.sender,
                exchangeAddr
            );
    }

    /**
     * @notice 将tokenA 以买入 指定交易所的tokenB(exchangeAddr) 并发送tokenB给recipient
     * @dev 允许通过非相同Factory部署的合约进行交易
     * @dev 明确指出要卖出的token数量
     * @param tokensSold 卖出的token数量
     * @param minTokensBought 买入token的最小数量
     * @param minEthBought tokenA => ETH 最小ETH数量
     * @param deadline 交易超时时间
     * @param recipient tokenB接收地址
     * @param exchangeAddr tokenB的交易所地址
     * @return 实际买入的tokenB数量
     */
    function tokenToExchangeTransferInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address recipient,
        address exchangeAddr
    ) external noTimeout(deadline) returns (uint256) {
        return
            _tokenToTokenInput(
                tokensSold,
                minTokensBought,
                minEthBought,
                msg.sender,
                deadline,
                recipient,
                exchangeAddr
            );
    }

    /**
     * @notice 将tokenA 以买入 指定交易所的tokenB(exchangeAddr)
     * @dev 允许通过非相同Factory部署的合约进行交易
     * @dev 明确指出要买入的tokenB的数量
     * @param tokensBought 买入的tokenB数量
     * @param maxTokensSold 卖出token的最大数量
     * @param maxEthSold tokenA => ETH 最大ETH数量
     * @param deadline 交易超时时间
     * @param exchangeAddr tokenB的交易所地址
     * @return 实际卖出的tokenA数量
     */
    function tokenToExchangeSwapOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address exchangeAddr
    ) external noTimeout(deadline) returns (uint256) {
        return
            _tokenToTokenOutput(
                tokensBought,
                maxTokensSold,
                maxEthSold,
                deadline,
                msg.sender,
                msg.sender,
                exchangeAddr
            );
    }

    /**
     * @notice 将tokenA 以买入 指定交易所的tokenB(exchangeAddr) 并发送tokenB给recipient
     * @dev 允许通过非相同Factory部署的合约进行交易
     * @dev 明确指出买入的tokenB数量
     * @param tokensBought 买入的tokenB数量
     * @param maxTokensSold 卖出token的最大数量
     * @param maxEthSold tokenA => ETH 最大ETH数量
     * @param deadline 交易超时时间
     * @param recipient tokenB接收地址
     * @param exchangeAddr tokenB的交易所地址
     * @return 实际卖出的tokenA数量
     */
    function tokenToExchangeTransferOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address recipient,
        address exchangeAddr
    ) external noTimeout(deadline) returns (uint256) {
        return
            _tokenToTokenOutput(
                tokensBought,
                maxTokensSold,
                maxEthSold,
                deadline,
                msg.sender,
                recipient,
                exchangeAddr
            );
    }

    /**
     * @notice 指定数量的ETH兑换token数量的查询函数
     * @dev 明确指出要换出的ETH数量
     * @param ethSold eth数量
     * @return 能换入的token数量
     */
    function getEthToTokenInputPrice(
        uint256 ethSold
    ) external view returns (uint256) {
        assert(ethSold > 0);
        uint256 _tokenReserve = _selfTokenBalance();
        uint256 _ethReserve = _selfEthBalance();
        return _getInputPrice(ethSold, _ethReserve, _tokenReserve);
    }

    /**
     * @notice 兑换指定token数量需要ETH数量的查询函数
     * @dev 明确指出要换入的token数量
     * @param tokensBought 要换入的token数量
     * @return 要换出的ETH数量
     */
    function getEthToTokenOutputPrice(
        uint256 tokensBought
    ) external view returns (uint256) {
        assert(tokensBought > 0);
        uint256 _tokenReserve = _selfTokenBalance();
        uint256 _ethReserve = _selfEthBalance();
        return _getOutputPrice(tokensBought, _ethReserve, _tokenReserve);
    }

    /**
     * @notice 指定数量的token兑换ETH数量的查询函数
     * @dev 明确指出要换出的token数量
     * @param tokenSold 要换出的token数量
     * @return 可以换入的ETH的数量
     */
    function getTokenToEthInputPrice(
        uint256 tokenSold
    ) external view returns (uint256) {
        assert(tokenSold > 0);
        uint256 _tokenReserve = _selfTokenBalance();
        uint256 _ethReserve = _selfEthBalance();
        return _getInputPrice(tokenSold, _tokenReserve, _ethReserve);
    }

    /**
     * @notice 指定数量的ETH兑换token数量的查询函数
     * @dev 明确指出要换入的ETH数量
     * @param ethBought 要换入的ETH数量
     * @return 可以换出的token数量
     */
    function getTokenToEthOutputPrice(
        uint256 ethBought
    ) external view returns (uint256) {
        assert(ethBought > 0);
        uint256 _tokenReserve = _selfTokenBalance();
        uint256 _ethReserve = _selfEthBalance();
        return _getOutputPrice(ethBought, _ethReserve, _tokenReserve);
    }

    function tokenAddress() external view returns (address) {
        return address(token);
    }

    function factoryAddress() external view returns (address) {
        return address(factory);
    }

    /* ================================== Exchange Functions END ================================= */
    function balanceOf(
        address account
    ) external view override(IExchange, IERC20) returns (uint256) {
        return balances[account];
    }

    function transfer(address to, uint256 value) public virtual returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public  returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _transfer(from, to, value);
        return true;
    }

    function approve(
        address spender,
        uint256 value
    ) public  returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

        function allowance(address owner, address spender) public view  returns (uint256) {
        return allowances[owner][spender];
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    function _update(address from, address to, uint256 value) internal  {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            totalSupply += value;
        } else {
            uint256 fromBalance = balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value,
        bool emitEvent
    ) internal  {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 value
    ) internal  {
        uint256 currentAllowance = allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(
                    spender,
                    currentAllowance,
                    value
                );
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}
