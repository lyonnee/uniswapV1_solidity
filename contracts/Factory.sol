// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {IFactory} from "./IFactory.sol";
import {Exchange} from "./Exchange.sol";

contract Factory is IFactory{
    address public exchangeTemplate;
    uint256 private tokenCount;
    mapping (address => address) private _tokenToExchange;
    mapping (address => address) private _exchangeToToken;
    mapping (uint256 => address) private _idToToken;

    constructor(address newExchangeTemplate){
        assert(newExchangeTemplate != address(0));
        exchangeTemplate = newExchangeTemplate;
    }

        /**
     * @notice 创建新的Exchange的合约实例
     * @param token 交易的token合约地址
     * @return 创建的Exchange地址
     */
    function createExchange(address token) external returns(address){
        assert(token != address(0));
        require(_tokenToExchange[token] == address(0),"this token exchange has been created");
        address exchange = createClone(exchangeTemplate);
        Exchange(exchange).setup(token);

        _tokenToExchange[token] = exchange;
        _exchangeToToken[exchange] = token;
        tokenCount+= 1;
        _idToToken[tokenCount] = token;
        emit NewExchange(token, exchange);
        return exchange;
    }

    /**
     * @notice 查询售卖指定token的Exchange合约地址
     * @param token token合约地址
     * @return Exchange合约地址
     */
    function getExchange(address token) external view returns(address){
        return _tokenToExchange[token];
    }

    /**
     * @notice 查询Exchange售卖的token地址
     * @param exchange Exchange合约地址
     * @return token合约地址
     */
    function getToken(address exchange) external view returns(address){
        return _exchangeToToken[exchange];
    }

    /**
     * @notice 查询指定id对应的token
     * @param tokenId tokenId
     * @return token合约地址
     */
    function getTokenWithId(uint256 tokenId) external view returns(address){
        return _idToToken[tokenId];
    }

    function createClone(address target) internal returns (address result) {
    bytes20 targetBytes = bytes20(target);
    assembly {
      let clone := mload(0x40)
      mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
      mstore(add(clone, 0x14), targetBytes)
      mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
      result := create(0, clone, 0x37)
    }
  }
}