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

- `main_game_ui.tscn` 仍承载局内战斗和整理背包两种使用场景，但已新增整理背包浮层模式，解决基础关闭入口、输入上下文和布局覆盖问题；后续只有在整理背包继续扩展专属功能时才需要拆独立 scene。
- 复杂机械传动类饰品仍缺少更细的传动 action 元数据。
- 道具系统 F1 基础版本已完成。15 个正式道具、独立堆叠库存、局内道具栏、奖励/商店/事件入口和 51-56 号道具联动饰品已接入；剩余风险是正式获取权重、价格和数值调优。
- GitHub Releases 自动发布已接入 `v*` tag、内置 `GITHUB_TOKEN` 和 Windows zip 上传；后续按试玩节奏推 tag。

## 当前验证基线

- 全量 GUT：`tools/run_tests_silent.ps1`
- 严格场景冒烟：`python -B scripts/run_scene_smoke_tests.py --fail-on-engine-error`
- 发布预检：`tools/export_windows_release.ps1 -PrecheckOnly`

## 使用说明

本文用于理解历史技术债的处理轨迹。若本文与 `ImplementationTODO.md`、`01_System_Architecture.md` 或当前代码冲突，以后者为准。
