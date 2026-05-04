# Lost Fragments - 核心架构蓝图

本文档定义了《Lost Fragments》的长期技术架构，旨在支撑海量卡牌、复杂连锁反应及高表现力的视觉需求。

## 1. 核心设计原则

### 1.1 数据驱动 (Data-Driven)
- **自定义资源 (Custom Resources)**: 所有的物品、效果、关卡配置均采用 `ItemData`, `ItemEffect` 等 Resource 类存储。
- **配置即玩法**: 通过在编辑器中组合不同的 Resource 实例，无需编写新代码即可实现新物品逻辑。

### 1.2 MVC 与 极致解耦
- **Model (数据层)**: `BackpackManager` 等类，仅处理数学运算和内存状态，不依赖任何 Node 或 UI 属性。
- **View (表现层)**: `BackpackUI`, `ItemUI` 等，负责接收数据并呈现视觉效果。通过 `SequencePlayer` 实现逻辑结果的“异步回放”。
- **Controller (控制层)**: `BattleManager` 协调全局，利用 `SignalBus` 进行跨层通信，严禁 UI 节点直接调用核心逻辑。

### 1.3 动作序列化 (Action Sequencing)
- 逻辑层产生 `GameAction` 序列。
- 表现层按序消耗 `GameAction` 序列。
- 确保连锁反应具有清晰的节奏感和演出效果。

## 2. 目录结构规范

```text
res://
├── src/
│   ├── core/           # 跨场景复用的底层逻辑与数据模型
│   ├── battle/         # 战斗逻辑、状态机、序列播放
│   ├── ui/             # 表现层场景与 UI 逻辑
│   └── autoload/       # 全局单例与信号总线
├── data/               # 游戏静态配置文件 (.tres)
├── assets/             # 原始美术/音频素材
└── spec/               # 技术与设计文档
```

## 3. 战斗流程状态机 (Battle State Machine)
拟引入以下状态以确保流程可控：
1. **Initialize**: 加载数据，初始化背包。
2. **Draw**: 抽取新物品，播放入场序列。
3. **Placing**: 等待玩家操作（拖拽、放置、舍弃）。
4. **Resolving**: 执行撞击算法，播放连锁反应动画。
5. **Evaluating**: 检查胜利/失败条件，结算 San 值。
