# 游戏架构专业评审报告 (Gameplay Architect Review)

**评审日期**: 2026年5月10日
**评审版本**: v3.0 (ImpactResolver 3.0 基于)
**评审人**: Gemini CLI (Professional Gameplay Architect)

---

## 1. 整体架构概览 (Architectural Overview)

本作采用了典型的 **数据驱动 (Data-Driven)** 与 **组合模式 (Composition)** 相结合的架构方案，在 Godot 引擎环境下展现出了高度的灵活性和可维护性。

### 核心分层：
- **数据层 (Model)**: 以 `Resource` (`ItemData`, `ItemEffect`) 为核心。通过 `BackpackManager.ItemInstance` 实现了逻辑实例与静态数据的解耦，并确保了状态（如污染度）的物理隔离。
- **逻辑处理层 (Service/Logic)**: `ImpactResolver` 作为一个纯逻辑处理类，负责复杂的递归撞击解析。这种“输入当前格局 -> 输出动作序列”的设计模式非常接近于函数式编程思想，极大地降低了副作用。
- **协调层 (Controller)**: `BattleManager` 充当了“大脑”角色，协调 UI、逻辑和全局状态之间的交互。
- **表现执行层 (Expression)**: `SequencePlayer` 通过协程 (`await`) 依次执行 `GameAction` 序列。这种设计完美解决了游戏开发中常见的“表现与逻辑同步”难题。

---

## 2. 设计亮点 (Architectural Highlights)

### 2.1 基于动作序列的同步机制 (Action Queue)
`ImpactResolver` 不直接修改全局梦值或分数，而是生成 `GameAction` 对象列表。由 `SequencePlayer` 在播放对应动画时再触发数值变动。
- **优点**: 玩家看到的数值跳变与动画反馈是同步的，不会出现“人还没撞到，分数先加了”的尴尬情况。

### 2.2 深度递归与物理去重
`ImpactResolver` 中的 `visited_local` 记录了当前链条中已访问的物品及其方向。
- **优点**: 完美规避了卡牌游戏中常见的死循环问题，同时允许同一个物品在不同方向上被多次触发（如果设计允许）。

### 2.3 资源隔离与克隆机制
`BackpackManager` 在放置物品时调用 `item_data.duplicate(true)`。
- **优点**: 彻底解决了“修改一个苹果的数据，导致所有苹果都变强”的 Resource 共享问题。这是 Roguelike 游戏走向深度的技术基石。

---

## 3. 潜在隐患与改进建议 (Observations & Recommendations)

### 3.1 状态变更的一致性风险 (Immediate vs. Deferred Changes)
- **现状**: “污染度”在 `ImpactResolver` 解析过程中即时修改，而“分数/梦值”则延迟到 `SequencePlayer` 播放时修改。
- **风险**: 如果某个 `ItemEffect` 的逻辑依赖于全局分数或梦值，在同一个递归链条中，后执行的 Effect 拿到的是旧的分数，而可能已经拿到了新的污染度。
- **建议**: 考虑将所有状态变更统一收拢。或者，如果 Effect 需要读取当前梦值进行分支判断，应提供一个“预演状态 (Projected State)”。

### 3.2 核心状态的视觉可见性 (Visibility of Core Mechanics)
- **现状**: “污染 (Pollution)”是本作的核心机制之一，但目前仅在 Tooltip 中可见。
- **建议**: 在 `ItemUI` 上增加一个常驻的数字标签或特效层（如紫色烟雾强度），直接反映其污染层数。对于这种频率极高的数值，依赖悬浮窗会增加玩家的认知负荷。

### 3.3 依赖查找的规范化 (Dependency Injection)
- **现状**: `ItemUI` 通过 `get_tree().get_first_node_in_group("battle_manager")` 来获取逻辑层引用。
- **风险**: 当项目规模扩大或需要进行单元测试时，这种基于场景树结构的查找会导致组件难以独立运行。
- **建议**: 进一步强化 `GameContext` 的作用。在物品 UI 生成时，由 `BackpackUI` 统一注入上下文引用。

---

## 4. 结论 (Conclusion)

本作的代码架构非常成熟，尤其在 **逻辑与表现分离** 方面做得相当出色。`ImpactResolver` 的设计是整套系统的灵魂，具备极强的扩展性。目前的架构完全能够支撑从“简单的物品撞击”到“复杂的全局连锁反应”的跨越。

**建议下一步重点**:
1. 增强 UI 对动态属性（污染、倍率）的直观反馈。
2. 规范化 Effect 中的数值读写流程，确保长链触发下的逻辑一致性。

---
*文档结束*
