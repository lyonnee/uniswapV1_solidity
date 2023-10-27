// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

interface IFactory{
    /**
     * @notice 创建了新的Exchange触发的事件
     * @param token token合约地址
     * @param exchange exhcnage合约地址
     */
    event NewExchange (address indexed token, address indexed exchange);

    // ===================================== functions ===================================== //

    function createExchange(address token) external returns(address);

    function getExchange(address token) external view returns(address);

    function getToken(address exchange) external view returns(address);

    function getTokenWithId(uint256 tokenId) external view returns(address);
}