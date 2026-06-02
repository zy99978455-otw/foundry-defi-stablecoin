// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;

    function staleCheckLatestRoundData(AggregatorV3Interface pricefeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        // 1. 调用 Chainlink 原生的获取价格接口
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            pricefeed.latestRoundData();

        // 2. 算时差： 当前区块时间 - 预言机最后一次更新的时间
        uint256 secondsSince = block.timestamp - updatedAt;

        // 3. 终极熔断： 如果超过了 3 小时没更新，直接抛出异常，让整个交易回滚！
        if (secondsSince > TIMEOUT) {
            revert OracleLib__StalePrice();
        }

        // 4. 安检通过， 证明数据新鲜，正常把数据原封不动地返回出去
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
