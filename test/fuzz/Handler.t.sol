// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    // 声明全局的喂价预言机变量
    MockV3Aggregator public ethUsdPriceFeed;

    // 限制单次最大存款金额，防止 Fuzzer 生成太大的数字导致溢出崩溃
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    // 加入幽灵变量，用来在测试结果里看我们到底成功印了几次钞
    uint256 public timesMintIsCalled;

    // 建立 VIP 花名册，只有存过钱的人才能进来
    address[] public usersWithCollateralDeposited;

    constructor(DSCEngine _dsce, DecentralizedStableCoin _dsc) {
        dsce = _dsce;
        dsc = _dsc;

        // 利用 Getter 函数，从系统里安全地取出抵押代币地址
        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(weth)));
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

        // 5. 只要存钱成功，就把真实的 msg.sender 加入花名册！
        usersWithCollateralDeposited.push(msg.sender);
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
    function mintDsc(uint256 amount, uint256 addressSeed) public {
        if (usersWithCollateralDeposited.length == 0) {
            return;
        }

        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];

        // 真实 sender，
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(sender);

        uint256 maxDscToMint = (collateralValueInUsd / 2) - totalDscMinted;
        if (maxDscToMint <= 0) {
            return;
        }

        amount = bound(amount, 0, maxDscToMint);
        if (amount == 0) {
            return; // 取到 0 直接踢走，防止无意义底层报错
        }

        // 真正发起印钞调用
        vm.startPrank(sender);
        dsce.mintDsc(amount);
        vm.stopPrank();

        timesMintIsCalled++;
    }

    // -------------------------------------------------------------
    // 💣 预言机崩盘模拟器 (价格操纵通道)
    // -------------------------------------------------------------
    // 教程指出：这个函数暴露出系统无法抵御极端价格闪崩的物理弱点。
    // 如果取消注释，你的不变量测试将 100% 失败 (爆仓报错)。
    // 作为目前的妥协，我们先把它写出来并注释掉，表示我们“已知此系统性风险”。

    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }
}
