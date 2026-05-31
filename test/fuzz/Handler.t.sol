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
    // Fuzzer 机器人专用存钱通道
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

    // -------------------------------------------------------------
    // Fuzzer 机器人取钱专用通道
    // -------------------------------------------------------------
    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        // 1. 漏斗过滤一：获取正确的代币 (WETH 或 WBTC)
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        // 2. 动态安检：去底层系统查一下，这个 Fuzzer 用户在这个币种上，到底存了多少钱？
        uint256 maxCollateralToRedeem = dsce.getCollateralBalanceOfUser(address(collateral), msg.sender);

        // 3. 漏斗过滤二：把取钱金额强制限制在 [0, 用户真实余额] 之间
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);

        // 4. 终极拦截：如果余额是 0，或者刚好随机到了 0，直接踢走，不发起底层调用！
        if (amountCollateral == 0) {
            return;
        }

        // 5. 真正发起赎回
        vm.startPrank(msg.sender);
        dsce.redeemCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }


    // -------------------------------------------------------------
    // Fuzzer 机器人铸钱专用通道
    // -------------------------------------------------------------
    function mintDsc(uint256 amount) public {

        // 1. 查账：去底层的 DSCEngine 查一下当前用户的资产情况
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(msg.sender);
    
        // 2. 算额度：根据 200% 超额抵押率，算出他还能印多少钱
        // (注意：Solidity 里 uint 不能小于 0，在 0.8 版本后如果算出来是负数会自动 revert)
        uint256 maxDscToMint = (collateralValueInUsd / 2) - totalDscMinted;
        if(maxDscToMint <= 0){ // 修改：最好用 <= 0，如果是 0 就没必要印了
            return; 
        }

        // 3. 拦截与清洗：把 Fuzzer 瞎填的金额，按死在 0 到 maxDscToMint 之间
        amount = bound(amount, 0, maxDscToMint);
        if(amount == 0){
            return; // 取到 0 直接踢走，防止无意义底层报错
        }

        // 4. 真正发起印钞调用
        vm.startPrank(msg.sender);
        dsce.mintDsc(amount);
        vm.stopPrank();
    }


}
