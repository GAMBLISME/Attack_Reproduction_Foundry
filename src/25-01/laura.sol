//// SPDX-License-Identifier: MIT
//pragma solidity ^0.8.20;
//pragma experimental ABIEncoderV2;
//
//import "./imports/Context.sol";
//import "./imports/Ownable.sol";
//import "./imports/ERC20.sol";
//import "./imports/SafeMath.sol";
//import "./imports/Uniswap.sol";
//import "./imports/ABDKMath64x64.sol";
//import "./imports/Initializable.sol";
//
//contract PumpToken is ERC20, Ownable, Initializable {
//    using SafeMath for uint256;
//
//    string public imageUrl = '';
//    string public description = '';
//    bool public bondingCurve = false;
//    address public constant feeWallet = address(0x33Dc4F0c4E433fE99EcE9C7eDadA43F95FaB0CA2);
//    uint256 public constant feePermillage = 10;
//    uint public currentSupply = 0;
//    uint public currentRealSupply = REAL_LP_INITIAL_SUPPLY;
//    mapping(address => bool) public automatedMarketMakerPairs;
//
//    IUniswapV2Factory private uniswapFactory;
//    IUniswapV2Router02 private constant uniswapV2Router = IUniswapV2Router02(
//        address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)
//    );
//    address private uniswapV2Pair;
//
//    uint private constant ETH_TO_FILL = 5 * 1e18;  //当池子里的 ETH 超过这个值时，Bonding Curve 价格生效
//    uint private constant TOKENS_IN_LP_AFTER_FILL = 20_000_000 * 1e18; // 初始流动性池代币数量
//    uint private constant INITIAL_ETH_IN_LP = 1 * 1e15;  // 初始流动性池存入的 ETH（很少，仅 0.001 ETH）
//    uint private constant INITIAL_ETH_IN_VIRTUAL_LP = 1 * 1e18; // 计算 Bonding Curve 价格时的虚拟 ETH
//    uint private constant TARGET_TOTAL_SUPPLY = 100_000_000 * 1e18; // 10^26 目标最大供应量
//    int128 private INITIAL_PRICE;//代币的初始价格
//    int128 private K;//Bonding Curve 价格曲线的参数，通常用于控制价格变化幅度
//    bool private swapping = false;//在处理流动性或者买卖操作时，避免重复调用 swap 逻辑
//
//    //初始池子的 K 值（乘积常数） = 代币储备量 * ETH 储备量
//    uint private constant INITIAL_UNISWAP_K = TOKENS_IN_LP_AFTER_FILL * ETH_TO_FILL;
//
//    //实际流动性供应量（计算 K 值与初始 LP 的关系）
//    uint private constant REAL_LP_INITIAL_SUPPLY = INITIAL_UNISWAP_K / INITIAL_ETH_IN_LP;
//
//    //设定 流动性池代币大于 4 万枚 时，触发自动卖出代币换取 ETH（用于支付费用）。
//    uint256 private constant swapTokensAtAmount = 40_000 * 1e18;
//
//    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
//
//    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}
//
//    function initialize(
//        string memory name_,
//        string memory symbol_,
//        string memory image_,
//        string memory description_,
//        bool isMother
//    ) public payable initializer {
//        if (!isMother) {
//            setNameAndSymbol(name_, symbol_);
//            swapping = false;
//            imageUrl = image_;
//            description = description_;
//            _transferOwnership(feeWallet);
//            _initialize();
//            _addLp();
//        }
//    }
//
//    //创建 Uniswap 交易对
//    //设定 TOTAL_SUPPLY
//    //初始代币分配
//    //设置 Bonding Curve 价格参数 (K, INITIAL_PRICE)
//    function _initialize() internal {
//        uniswapFactory = IUniswapV2Factory(uniswapV2Router.factory());
//        uniswapV2Pair = uniswapFactory.createPair(address(this), uniswapV2Router.WETH());
//        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);
//        _totalSupply = TARGET_TOTAL_SUPPLY;
//        _balances[address(this)] = REAL_LP_INITIAL_SUPPLY;//10^26
//        K = ABDKMath64x64.divu(3719, 1e11);// 3.719×10^−8; 0.00000003719
//        INITIAL_PRICE = ABDKMath64x64.divu(1, 1e8);//10^-8 0.00000001
//        currentSupply = 0;
//        currentRealSupply = REAL_LP_INITIAL_SUPPLY;
//    }
//
//    function _addLp() internal {
//        require(msg.value >= INITIAL_ETH_IN_LP, "The msg value needs to be equal to the INITIAL_ETH_IN_LP");
//        _approve(address(this), address(uniswapV2Router), REAL_LP_INITIAL_SUPPLY);
//        uniswapV2Router.addLiquidityETH{value: INITIAL_ETH_IN_LP}(
//            address(this),
//            REAL_LP_INITIAL_SUPPLY,
//            0,
//            0,
//            address(this),
//            block.timestamp
//        );
//        bondingCurve = true;
//    }
//
//    receive() external payable {}
//
//    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
//        require(pair != uniswapV2Pair, "The pair cannot be removed from automatedMarketMakerPairs");
//        _setAutomatedMarketMakerPair(pair, value);
//    }
//
//    function _setAutomatedMarketMakerPair(address pair, bool value) private {
//        automatedMarketMakerPairs[pair] = value;
//        emit SetAutomatedMarketMakerPair(pair, value);
//    }
//
//    function _transfer(address from, address to, uint256 amount) internal override {
//        require(from != address(0), "ERC20: transfer from the zero address");
//
//        if (amount == 0) {
//            super._transfer(from, to, 0);
//            return;
//        }
//
//        handleTaxSellAndLpKValue(from);
//        uint originalAmount = amount;
//        uint256 fees = 0;
//
//        if (bondingCurve) {
//            if (automatedMarketMakerPairs[to]) {
//                if (!swapping) {
//                    fees = amount * feePermillage / 1000;
//                    amount -= fees;
//                }
//                amount = handleCurveSell(amount);
//                _balances[from] += amount - originalAmount;
//            } else if (automatedMarketMakerPairs[from]) {
//                amount = handleCurveBuy(amount);
//                if (amount > originalAmount) {
//                    amount = originalAmount;
//                    bondingCurve = false;
//                }
//                fees = amount * feePermillage / 1000;
//                amount -= fees;
//            }
//            if (fees > 0) {
//                _balances[address(this)] += fees;
//            }
//        }
//        super._transfer(from, to, amount);
//    }
//
//    function handleTaxSellAndLpKValue(address from) internal {
//        if (!swapping && from != address(this) && !automatedMarketMakerPairs[from]) {
//            uint256 contractTokenBalance = balanceOf(address(this));
//            bool canSwap = contractTokenBalance >= swapTokensAtAmount;
//
//            if (canSwap) {
//                swapping = true;
//                if (contractTokenBalance > 10 * swapTokensAtAmount) {
//                    contractTokenBalance = 10 * swapTokensAtAmount;
//                }
//                swapTokensForEth(contractTokenBalance);
//                swapping = false;
//            }
//
//            if (bondingCurve) {
//                removeLiquidityWhenKIncreases();
//            }
//        }
//    }
//
//    function swapTokensForEth(uint256 tokenAmount) internal {
//        address;
//        path[0] = address(this);
//        path[1] = uniswapV2Router.WETH();
//        _approve(address(this), address(uniswapV2Router), tokenAmount);
//        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
//            tokenAmount,
//            0,
//            path,
//            feeWallet,
//            block.timestamp
//        );
//    }
//
//    function removeLiquidityWhenKIncreases() public {
//        (uint256 tokenReserve, uint256 wethReserve) = getReservesSorted();
//        uint256 currentK = tokenReserve * wethReserve;
//        //在 Uniswap 池子 K 值（恒定乘积）增长超过 5% 时，减少流动性池中的代币数量。
//        //但是该预言机只依赖的单一 pool 的  K 值。
//        //攻击者通过闪电贷往该池子注入2种代币，导致 K 值变大，池子中LURA代币价格变高，能swap更多的 WETH。
//        //这时该lura合约执行该函数，减少池子中的LURA代币余额，降低流动性池中的代币供应。
//        if (currentK > (105 * INITIAL_UNISWAP_K / 100)) {
//            IUniswapV2Pair pair = IUniswapV2Pair(uniswapV2Pair);
//            _balances[uniswapV2Pair] -= tokenReserve * (currentK - INITIAL_UNISWAP_K) / currentK;
//            pair.sync();
//        }
//    }
//
//    function getReservesSorted() public view returns (uint112 tokenReserve, uint112 wethReserve) {
//        IUniswapV2Pair pair = IUniswapV2Pair(uniswapV2Pair);
//        (tokenReserve, wethReserve,) = pair.getReserves();
//        if (pair.token1() == address(this)) {
//            (tokenReserve, wethReserve) = (wethReserve, tokenReserve);
//        }
//    }
//
//    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) public pure returns (uint amountIn) {
//        uint numerator = reserveIn.mul(amountOut).mul(1000);
//        uint denominator = reserveOut.sub(amountOut).mul(997);
//        amountIn = (numerator / denominator).add(1);
//    }
//
//    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut) {
//        uint amountInWithFee = amountIn.mul(997);
//        uint numerator = amountInWithFee.mul(reserveOut);
//        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
//        amountOut = numerator / denominator;
//    }
//}
