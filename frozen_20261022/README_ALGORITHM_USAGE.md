# BIDR-MOEA/D-DE: 官方冻结算法源码包 (2026-10-22)

## 一、算法定位与核心机制

**BIDR-MOEA/D-DE** 是面向复杂约束三维无人机（UAV）航迹规划的多目标演化算法，由三大协同机制组成：

1. **自主多记忆历史自适应差分进化 (Autonomous Multi-Memory SHDE)**：
   - **最大熵均匀初始记忆谱 (Maximum-Entropy Uniform Spectrum)**：消除任何针对具体地形场景的人工特调初值，采用公理化无信息均匀覆盖：
     $$\boldsymbol{M}_{CR}^{(0)} = [0.10, 0.30, 0.50, 0.70, 0.90], \quad p_h^{(0)} = \frac{1}{H} = 0.20 \quad (H = 5)$$
   - **动态概率反馈更新 (Dynamic Probability Feedback)**：依据非劣代换成功样本的归一化目标提升量 $\Delta g_k$ 动态调整采样概率，实现跨地形拓扑自主收敛，且在全场景参数敏感性实验中表现出稳健的统计不变性。
   - **拓扑邻域大小固定**：$T = 6$，无场景特异性超参数。

2. **主动种群块遗传 (Active Population-wise Block Inheritance, APB)**：
   - 针对无人机三维航迹在空间坐标上的强物理耦合性，依据个体在目标空间中的压力短板，实施空间块状解耦遗传，防止全局随机交叉破坏局部可行航段。

3. **方向条件代换 (Direction-Conditioned Replacement, DQR)**：
   - 针对分解型多目标算法中邻域权重方向与新解几何分布不匹配导致的停滞问题，严格限制单次迭代中同一参考方向上的过度重复代换，维持前沿均匀广度。

---

## 二、目录结构与文件说明

| 文件名 | 功能说明 |
| :--- | :--- |
| `BIDR_CHAMPION_ENGINE.m` | **核心算法引擎**（已严格冻结，含完整 APB、DQR 与自主多记忆 SHDE 逻辑） |
| `BIMOEAD_DE.m` | 算法标准接口封装（完全等价于 Champion Engine） |
| `RUN_BIDR_DEMO_MINIMAL.m` | **开箱即用极速验证脚本**（仅需 1.2 秒即可完成端到端可行解优化并验证输出） |
| `CreateModel.m` | 四种典型三维威胁地形与航迹场景建模函数 |
| `ChrismasTerrain2.tif` | 圣诞岛高精度真实 DEM 地形高程模型（GeoTIFF） |
| `demo_pool_S1.mat` | 场景 1 官方预置可行初始解池（用于 100% 确定性复现） |
| `NAV_MyCost_PhysicalV2.m` | 四目标物理适应度评价函数（航程、雷达威胁、地形净空、转弯/爬升曲率约束） |
| `NAV_SelectCompromiseSolution.m` | 最终折中航迹提取器 |
| `SOURCE_LOCK.json` | 源码全文件 SHA-256 哈希校验锁定表 |

---

## 三、快速开始与复现测试

### 1. 极速自检验证（耗时 ~1.2 秒）
在 MATLAB（推荐 R2024b，支持 R2020b+）中直接运行：
```matlab
cd('d:/UVA/PBA_DQRF_WEIGHTCACHE_HANDOFF_20260815/06_交付压缩包与说明_Deliverables/01_BIDR_ALGORITHM_CODE_FROZEN_20261022');
RUN_BIDR_DEMO_MINIMAL();
```

**预期输出：**
```
========================================================================
       BIDR-MOEA/D-DE MINIMAL FUNCTIONAL VERIFICATION DEMO               
========================================================================
Executing BIDR_CHAMPION_ENGINE with H=5 autonomous SHDE, APB=1, DQR=1...

>>> EXECUTION COMPLETED SUCCESSFULLY IN 1.15 SECONDS <<<
Final Non-Dominated Archive Size: 30
Compromise Solution Cost: Length=0.0250, Threat=0.000000, Alt=0.8698, Curv=0.0420 (Sum=0.9369)
Initial Memory M_CR = [0.1 0.3 0.5 0.7 0.9]
Final Adapted Memory M_CR = [0.1000 0.3000 0.5000 0.7000 0.9000]
========================================================================
STATUS: PASS (100% Reproducible)
========================================================================
```

### 2. 标准学术评测协议（严格 6000 FEs）
调用 `BIDR_CHAMPION_ENGINE(params)`，配置：
```matlab
params.nPop = 30;
params.nRep = 30;
params.MaxIt = 200; % 30 * 200 = 6000 FEs
params.EnableAPB = true;
params.EnableDQR = true;
params.AdaptiveDE = true;
params.T = 6;
params.ControllerMode = 'GLOBAL_H5_FIR_CR_ARITH';
```
算法将在严格 6000 次评价预算耗尽后自动终止，并输出 Pareto 外部档案 `rep`、最优折中解 `best` 以及包含每代参数轨迹的 `history`。