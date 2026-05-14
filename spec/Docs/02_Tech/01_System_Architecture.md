# 系统技术架构 (Technical Architecture)

本文档定义了《GoDotGame》的长期技术架构，旨在支撑海量卡牌、复杂连锁反应及高表现力的视觉需求。

## 一、 核心设计原则

### 1. 数据驱动与资源隔离
* **自定义资源 (Custom Resources)**: 采用 `ItemData`, `ItemEffect` 等存储。
* **物理副本隔离**: `BackpackManager` 在放置物品时，必须对 `ItemData` 执行 `duplicate(true)`。这确保了同一类卡牌（如多个“纸团”）在背包中拥有独立的污染层数和属性，互不干扰。
* **运行时身份连续**: 物品变身、进化或替换静态数据时，必须保留原 `runtime_id`，并通过统一事件同步 UI 映射，避免逻辑实例和表现节点脱节。

### 2. 状态锁定机制 (State Locking)
* **防腐 (Preservation)**: 通过 `ItemInstance` 的属性 Setter 实现逻辑层保护。当 `is_preserved` 为真时，任何试图修改 `current_pollution` 的操作（含直接赋值）均会被拦截。

### 3. 动作序列化 (Action Sequencing)
* 逻辑层产生 `GameAction` 序列。
* 表现层按序消耗动作，确保连锁反应的视觉表现力。

## 二、 核心子系统设计

### 1. 撞击解析物理引擎 (ImpactResolver 3.0)
负责递归处理撞击能量流，具备以下工业级特性：
*   **严谨去重规则**：使用 `visited` 集合记录 `(目标实例, 进入方向)` 对。
    *   **多格物体安全**：即便解析器从多格物体的不同组成格发起探测，同一目标在同一连锁中只会被有效“击中”一次，彻底杜绝回声碰撞和数值爆炸。
*   **物理拦截 (NONE Mode)**：支持 `TransmissionMode.NONE`。当能量流击中拦截类物品（如深井滤芯）后，解析器会立即终止该路径的递归。
*   **动作溯源 (History Tracing)**：解析器保留 `actions_history`。效果脚本可回溯之前的结算动作（如检测链条中已发生的“污染反噬”次数）来触发额外奖励。

### 2. 同步采集管道 (Acquisition Pipeline)
`BattleManager` 负责新卡牌获取的原子化处理：
1.  **同步通知感应卡**：通过同步循环调用 `on_global_item_drawn`，确保墨盒、足球等成长卡在任何撞击开始前完成叠层。
2.  **信号发射**：发出 `item_drawn` 全局信号。
3.  **延迟撞击处理**：使用 `call_deferred` 触发自发性撞击（如污水泵），防止在大规模连锁中发生堆栈溢出。

### 3. 污染倍率公式
*   **Multiplier = 1 + current_pollution**。
*   **污染反噬**：每次撞击时，根据当前污染层数自动产生 Sanity 扣除动作，受“隔离箱”等防御件的 Modifiers 修正。

## 三、 目录结构规范
```text
res://
├── src/
│   ├── core/           # 逻辑层
│   │   ├── backpack/    # 背包网格与运行时物品实例
│   │   ├── effects/     # 物品效果脚本实现
│   │   ├── events/      # 事件数据结构
│   │   ├── ornaments/   # 饰品数据与饰品效果
│   │   ├── rewards/     # 奖励与商店生成器
│   │   └── route/       # 路线节点配置
│   ├── battle/         # 流程控制
│   ├── debug/          # 手工调试场景，不进入自动化测试收集
│   ├── ui/             # 表现层
│   └── autoload/       # 全局事件总线与持久化
├── data/               # 静态资源
├── test/               # 工业级测试套件 (unit/integration)
├── tools/              # 仓库级工具脚本
└── spec/               # 设计与技术协议
```

导出产物属于本地构建结果，默认输出到 `package/`，但不进入版本库；源码仓库只保留可复现导出的配置与资源。
