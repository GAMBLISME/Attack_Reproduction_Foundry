## 对web3攻击进行分析与使用foundry复现

### 环境安装

在进行复现之前，您需要先安装 **Foundry**。以下是安装步骤：

#### 安装 Foundry

1. 打开终端并运行以下命令：

   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   ```

2. 添加 Foundry 到系统 PATH 中：

   ```bash
   export PATH="$HOME/.foundry/bin:$PATH"
   ```

3. 完成安装后，验证是否安装成功：

   ```bash
   forge --version
   ```

### 2025年1月1日 LAURAToken 攻击事件分析与复现

本文将通过对 **2025年1月1日 LAURAToken 攻击事件** 的详细分析，使用 Foundry 工具进行复现。请参阅详细分析文档：[LAURAToken 攻击事件分析与复现](https://learnblockchain.cn/article/12139)

#### 复现命令

在安装完 Foundry 后，可以使用以下命令来运行复现的攻击事件：

```bash
forge test --contracts ./src/25-01/LAURAToken_exp.sol -vvv
```

该命令会编译并运行 `LAURAToken_exp.sol` 合约，执行相应的测试，复现攻击事件的过程。

---

该项目将继续扩展，分析更多的 Web3 攻击事件并通过 Foundry 进行复现。敬请关注更新。

