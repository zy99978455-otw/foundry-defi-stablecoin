// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title ERC20Mock
 * @notice 这是一个简易的 ERC20 假代币合约，专供本地 Anvil 测试使用。
 * 它允许我们随意铸造（mint）假的 WETH 和 WBTC 来进行抵押测试。
 */
contract ERC20Mock is ERC20 {
    // 构造函数：部署时立刻给某个地址印一笔初始资金
    constructor(string memory name, string memory symbol, address initialAccount, uint256 initialBalance)
        ERC20(name, symbol)
    {
        _mint(initialAccount, initialBalance);
    }

    // 暴露一个公共的 mint 函数，方便我们在测试脚本里随时印假钞
    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    // 暴露一个公共的 burn 函数，方便我们销毁假钞
    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }
}
