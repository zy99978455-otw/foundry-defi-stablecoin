// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol"; // 引入你刚写的 Handler

contract Invariants is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    address weth;
    address wbtc;

    Handler handler; // 声明 Handler 变量

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();

        // 实例化 Handler，并把引擎和币传给它
        handler = new Handler(dsce, dsc);

        // 💣 极其关键的一步！告诉 Fuzzer 机器人：你的攻击目标是 Handler，不要直接打 DSCEngine！
        targetContract(address(handler));
    }

    // 核心不变量：系统的总抵押物价值，必须永远大于等于铸造出来的 DSC 总价值
    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // 1. 获取全网发行的 DSC 总量 (负债)
        uint256 totalSupply = dsc.totalSupply();

        // 2. 获取系统合约里锁定的 WETH 和 WBTC 总量
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dsce));

        // 3. 把这些代币转成美元价值
        uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = dsce.getUsdValue(wbtc, totalWbtcDeposited);

        // 打印日志，方便我们在终端里观察每次测试的情况
        console.log("WETH Value: ", wethValue);
        console.log("WBTC Value: ", wbtcValue);
        console.log("Total Supply: ", totalSupply);

        console.log("Times Mint Called: ", handler.timesMintIsCalled());

        // 4. 断言：抵押物美元总价值 >= 负债总量
        assert(wethValue + wbtcValue >= totalSupply);
    }
}
