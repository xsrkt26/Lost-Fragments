# 系统技术架构 (Technical Architecture)

本文档定义了《GoDotGame》的长期技术架构，旨在支撑海量卡牌、复杂连锁反应及高表现力的视觉需求。

## 一、 核心设计原则

### 1. 数据驱动 (Data-Driven)
* **自定义资源 (Custom Resources)**: 所有物品、效果均采用 `ItemData`, `ItemEffect` 等 Resource 类存储在 `res://data/` 中。
* **配置即玩法**: 通过在编辑器中组合不同的 Resource 实例，无需编写新代码即可实现大部分新物品逻辑。

### 2. MVC 与 极致解耦
* **Model (数据层)**: `BackpackManager` 等类，仅处理数学运算和内存状态。
* **View (表现层)**: `BackpackUI`, `ItemUI` 等，负责接收数据并呈现视觉效果。
* **Controller (控制层)**: `BattleManager` 协调全局，严禁 UI 节点直接调用核心逻辑。

### 3. 动作序列化 (Action Sequencing)
* 逻辑层快速结算并产生 `GameAction` 序列。
* 表现层通过 `SequencePlayer` 按序异步消耗 `GameAction` 序列，确保连锁反应具有清晰的节奏感和演出效果。

## 二、 核心子系统设计

### 1. 卡牌数据与实例
* **`ItemData` (Resource)**：静态数据模型。包含形状、基础方向、数值、标签数组 (`Array[String]`) 及绑定的 `ItemEffect`。
* **`ItemInstance` (RefCounted)**：背包中的运行实例。保存**运行时状态**，如当前坐标 (`root_pos`) 和 **污染层数 (`current_pollution`)**。

### 2. 生命周期与事件钩子 (Event Hooks)
所有卡牌效果通过实现特定接口注入游戏流程：
* `on_draw()`: 抽到时触发。
* `on_discard()`: 丢弃时触发。
* `on_hit(source, resolver, context)`: **核心钩子**，被撞击时触发。

### 3. 全局事件总线 (GlobalEventBus)
Autoload 单例，解耦跨卡牌联动。
* 核心信号：`item_drawn`, `item_discarded`, `item_impacted`, `pollution_changed`。

### 4. 撞击解析器 (ImpactResolver 2.0)
负责计算物理/逻辑上的撞击连锁反应。
* **寻路与过滤**：根据 `Direction`、`TransmissionMode` 寻找目标，并受 `hit_filter_tags` 限制。
* **污染乘法引擎**：获取目标的污染层数 N，循环执行 (1+N) 次 `on_hit` 效果，并通知 `GameContext` 扣除额外的 San 值。

## 三、 目录结构规范
```text
res://
├── src/
│   ├── core/           # 数据模型(Model)、状态与计算逻辑
│   ├── battle/         # 战斗控制(Controller)、序列播放
│   ├── ui/             # 表现层(View)场景与脚本
│   └── autoload/       # 全局单例
├── data/               # 静态配置资源 (.tres)
└── spec/               # 设计与技术文档
```