// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockV3Aggregator
 * @notice Based on the FluxAggregator contract
 * @notice Use this contract when you need to test
 * other contract's ability to read data from an
 * aggregator contract, but how the aggregator got
 * its answer is unimportant
 */

contract MockV3Aggregator {
    // 预言机版本号。为了骗过引擎，随便写个 0 或者真实的 4 都行。
    uint256 public constant version = 0;

    // 价格的精度。例如 ETH/USD 的精度是 8（即 2000 美元在底层显示为 2000 * 10^8）
    uint8 public decimals;
    // 最新一次更新的价格
    int256 public latestAnswer;
    // 最新一次更新的时间戳
    uint256 public latestTimestamp;
    // 最新一次更新的“回合数”（Chainlink 每次更新价格，回合数就会 +1）
    uint256 public latestRound;

    // 历史账本：记录每一个回合对应的【价格】
    mapping(uint256 => int256) public getAnswer;
    // 历史账本：记录每一个回合对应的【更新时间戳】
    mapping(uint256 => uint256) public getTimestamp;
    // 历史账本：记录每一个回合对应的【开始时间戳】（在 Mock 里通常和更新时间一样）
    mapping(uint256 => uint256) private getStartedAt;

    /**
     * @notice 构造函数（创世引擎）
     * @param _decimals 你想伪造的精度（如 8）
     * @param _initialAnswer 部署那一瞬间的初始价格（如 2000e8）
     */
    constructor(uint8 _decimals, int256 _initialAnswer) {
        decimals = _decimals;
        // 部署时，立刻把初始价格录入第一回合的账本中
        updateAnswer(_initialAnswer);
    }

    /**
     * @notice 【上帝视角的作弊器 1】：只改价格
     * @dev 在测试脚本中调用它，可以瞬间模拟“以太坊闪崩”或“暴涨”的极端行情！
     */
    function updateAnswer(int256 _answer) public {
        latestAnswer = _answer;                 // 更新最新价格
        latestTimestamp = block.timestamp;      // 更新时间戳为当前区块时间
        latestRound++;                          // 开启新的一个回合
        
        // 把新数据归档到历史账本里
        getAnswer[latestRound] = _answer;
        getTimestamp[latestRound] = block.timestamp;
        getStartedAt[latestRound] = block.timestamp;
    }

    /**
     * @notice 【上帝视角的作弊器 2】：连时间和回合数一起篡改（硬核测试专用）
     * @dev 如果你想测试你的风控系统能不能扛住“预言机宕机（价格陈旧过期）”的漏洞，用这个函数造假！
     */
    function updateRoundData(uint80 _roundId, int256 _answer, uint256 _timestamp, uint256 _startedAt) public {
        latestRound = _roundId;
        latestAnswer = _answer;
        latestTimestamp = _timestamp;
        
        getAnswer[latestRound] = _answer;
        getTimestamp[latestRound] = _timestamp;
        getStartedAt[latestRound] = _startedAt;
    }

    /**
     * @notice 【前台伪装接口 1】：查询历史数据
     * @dev 你的 DSCEngine 如果想查昨天的价格，就会调这个函数。
     */
    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, getAnswer[_roundId], getStartedAt[_roundId], getTimestamp[_roundId], _roundId);
    }

    /**
     * @notice 【前台伪装接口 2】：获取最新价格数据（⭐️ 最核心接口）
     * @dev 你的 DSCEngine 每次计算抵押物价值时，调用的就是这个函数。
     * 它把最新的 5 个参数打包吐出来，完美伪装成真实的 Chainlink。
     */
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (
            uint80(latestRound),           // 当前的回合 ID
            getAnswer[latestRound],        // 当前的假价格
            getStartedAt[latestRound],     // 假开始时间
            getTimestamp[latestRound],     // 假更新时间
            uint80(latestRound)            // 回答的回合 ID
        );
    }

    /**
     * @notice 自我介绍
     */
    function description() external pure returns (string memory) {
        return "v0.6/tests/MockV3Aggregator.sol";
    }
}