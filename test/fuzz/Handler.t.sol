// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract Handler is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    // 限制单次最大存款金额，防止 Fuzzer 生成太大的数字导致溢出崩溃
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _dsce, DecentralizedStableCoin _dsc) {
        dsce = _dsce;
        dsc = _dsc;

        // 利用 Getter 函数，从系统里安全地取出抵押代币地址
        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
    }

    // -------------------------------------------------------------
    // Fuzzer 机器人现在只能调这个函数，不能直接碰 DSCEngine 了！
    // -------------------------------------------------------------
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        // 1. 漏斗过滤一：从随机数里选出正确的代币 (WETH 或 WBTC)
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        
        // 2. 漏斗过滤二：把随机金额限制在 [1, MAX_DEPOSIT_SIZE] 之间
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        // 3. 漏斗过滤三：代打工模式 (替测试用户印钱 + 授权)
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dsce), amountCollateral);
        
        // 4. 真正发起存款！现在这笔存款 100% 会成功，不会被 Revert 浪费掉
        dsce.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    // --- Helper Functions ---
    // 把随机数转成具体的代币
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }




}