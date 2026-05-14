# 架构评审追踪记录

文档状态：历史评审已按当前代码补充处理结果。本文不作为需求来源；当前需求以 `../02_Tech/ImplementationTODO.md` 为准。

## 原评审主题与当前状态

| 评审主题 | 原问题 | 当前状态 |
| --- | --- | --- |
| 逻辑与表现解耦 | `BackpackUI` 过重，逻辑难以无 UI 测试 | 已大幅推进。放置、旋转、丢弃、撞击、背包持久化由 `BattleManager`/`BackpackManager` 处理；UI 仍有布局和交互职责。 |
| 撞击算法空间精确性 | 多格物品撞击入口/出口存在歧义 | 已有 `ImpactResolver` 和确定性撞击队列；复杂机械传动 action 元数据仍待后续细化。 |
| 序列化表现系统 | 逻辑瞬间完成，缺少动作节奏 | 已实现 `GameAction` + `SequencePlayer`，并接入撞击结算表现。 |
| 资源实例隔离 | 同类 `ItemData` 共享可变状态 | 已通过 `ItemInstance`、深拷贝、runtime id 保留和替换事件解决主路径问题。 |
| 依赖查找解耦 | 大量 `/root` 查找影响单测 | 部分解决。`GameContext` 已用于效果和战斗上下文；autoload 仍作为全局状态入口保留。 |

## 当前仍需关注

- `main_game_ui.tscn` 仍承载局内战斗和整理背包两种使用场景，用户视频反馈显示背包布面板在 Hub/整理背包/局内切换时存在覆盖和层级重叠。下一轮应优先修复或拆出独立整理背包 scene。
- 复杂机械传动类饰品仍缺少更细的传动 action 元数据。
- 道具系统 F1 已暂缓。51-56 号道具联动饰品已作为未启用数据保留，奖励/商店入口会过滤，实际效果待 F1 恢复后实现。
- GitHub Releases 自动发布尚未接入，需要发布权限和 tag 策略。

## 当前验证基线

- 全量 GUT：`tools/run_tests_silent.ps1`
- 严格场景冒烟：`python -B scripts/run_scene_smoke_tests.py --fail-on-engine-error`
- 发布预检：`tools/export_windows_release.ps1 -PrecheckOnly`

## 使用说明

本文用于理解历史技术债的处理轨迹。若本文与 `ImplementationTODO.md`、`01_System_Architecture.md` 或当前代码冲突，以后者为准。
