# 当前系统技术架构

文档状态：已按当前代码更新。后续需求优先级以 `ImplementationTODO.md` 为准，Agent 执行流程以 `04_Agent_Development_Workflow.md` 为准。

## 一、核心原则

### 1. `RunManager` 是整局运行状态源

`RunManager` 维护跨场景状态，包括：

- 当前路线 ID、场景层 `current_act`、路线节点下标和已完成节点。
- 长期卡组、碎片、饰品、背包布局、暂存物品。
- 背包可用区域、锁格、删格、临时锁格。
- 商店节点缓存、事件节点缓存、已见事件、可序列化随机源。
- 整局是否活跃、是否完成、失败或胜利结算。

局内、商店、事件和奖励都应通过 `RunManager` 写入长期状态，不应各自维护平行运行数据。

### 2. 数据驱动

静态内容由数据资源或 JSON 驱动：

- 物品：`data/items/*.tres`，由 `ItemDatabase` 加载。
- 饰品：`data/ornaments/ornaments.json`，由 `OrnamentDatabase` 加载。
- 事件：`data/events/events.json`，由 `EventDatabase` 加载。
- 路线：`data/routes/routes.json`，由 `RouteConfig` 加载。
- 经济曲线：`src/core/rewards/economy_config.gd`。

路线、奖励、商店、事件和经济数值不应散落在 UI 场景脚本中。

### 3. 逻辑与表现分离

- `BackpackManager` 负责网格、物品实例、放置、旋转、播种、锁格和运行时状态。
- `ImpactResolver` 负责撞击解析并产出 `GameAction`。
- `SequencePlayer` 负责按动作序列播放表现并同步数值。
- `BattleManager` 负责局内状态机、抽取、撞击队列、背包持久化和饰品触发。
- UI 只发出交互请求并渲染状态，不直接改长期运行状态。

### 4. 运行时资源隔离

`ItemData` 是静态资源。进入背包或局内运行态时必须通过 `ItemInstance` 和深拷贝隔离状态，避免同类物品共享污染、方向、形态、runtime id 等可变数据。

物品变身或替换数据时必须保留原 `runtime_id`，并通知 UI 同步表现节点，避免拖拽、悬浮或动画映射丢失。

### 5. 可测试与可复现

- 随机奖励、商店和事件使用 `RunManager` 的可序列化随机源。
- 关键场景由 `scripts/scene_smoke_scenes.json` 维护并 headless 加载。
- 所有新增功能应补 GUT 测试；UI/场景/资源改动必须跑严格场景冒烟。

## 二、主要子系统

### 1. 路线与场景推进

`RouteConfig` 从 `data/routes/routes.json` 读取默认路线：

```text
局内游戏 -> 商店 -> 事件 -> 局内游戏 -> 商店 -> 事件 -> Boss局内游戏 -> 商店 -> 事件
```

当前支持节点类型：

- `battle`
- `boss_battle`
- `shop`
- `event`
- `cutscene`
- `reward`
- `elite_battle`

`HubScene` 由路线按钮驱动，只允许进入当前节点；完成战斗、离开商店或完成事件后推进路线。完成第 6 个场景最后节点后，整局胜利并返回主菜单。

### 2. 战斗生命周期

`BattleManager` 使用状态机：

- `INTERACTIVE`
- `DRAWING`
- `RESOLVING`
- `FINISHING`
- `FINISHED`

玩家手动结束或梦值归零都会走 `request_finish_battle(reason)`。如果当前仍在抽取或结算中，结束请求会延迟到本次结算完成后再发出，避免中途打断本次撞击结算。

普通战斗默认无分数目标；Boss 战从路线节点的 `score_target` 规则读取目标分数。达到目标不会自动结束，战斗结束时统一判定胜负。

### 3. 背包与物品状态

背包物理大小为 7x7，初始可用区域为 5x5。新 run 默认在背包中放入 `root_dream`，用于每 5 次捕梦触发一次根源撞击。

`RunManager.current_backpack_items` 持久化背包内物品，保存字段包括物品 id、根坐标、方向、形状和 runtime id。战斗结束时背包外物品丢弃，污染清零，衍生物品不跨战斗保存。

事件可以改变背包区域：

- 扩展可用区域。
- 锁格。
- 删格。
- 临时锁格。
- 强制搬迁已有物品。

锁格、删格和临时锁格都会统一输出为 `blocked_cells`，战斗和整理背包读取同一逻辑。

### 4. 撞击调度

所有撞击统一进入 `BattleManager.queue_impact_at(pos, direction, source, reason)`。队列按左上优先级和入队序号排序；每次只处理一次撞击结算，等待 `ImpactResolver` 与 `SequencePlayer` 完整结算后再处理下一次。

同一结算窗口中新产生的撞击会继续进入队列并重新排序，但不会打断当前正在播放的撞击结算。

### 5. 播种与梦境之种

`BackpackManager.sow_seed()` 是统一播种入口：

- 指定方向第一格为空时生成 `dream_seed_1x1`。
- 目标格已有梦境之种时调用 `upgrade_seed()`。
- 梦境之种可升级到 `dream_seed_5x5`。
- 升级失败会回滚并发出失败事件。

相关事件通过 `GlobalEventBus` 广播，供饰品和后续道具系统监听。

### 6. 饰品系统

饰品不占背包格，不参与撞击，不能重复获得。当前已加载 50 个非道具饰品，并接入：

- 战斗开始。
- 捕梦。
- 放置。
- 丢弃。
- 本次撞击结算结束。
- 播种成功/失败。
- 种子升级。
- 污染增加。
- 净化。
- 商店折扣。
- 奖励选项增量。

简单饰品通过 `GenericOrnamentEffect` 分发，复杂饰品可拆为独立脚本。道具联动饰品依赖 F1 道具系统，当前暂缓。

### 7. 奖励、商店、事件与经济

`RewardGenerator` 生成奖励选项，支持物品、饰品、碎片、权重随机、Boss 稀有倾向、已有构筑标签倾向和候选为空时的安全回退。

`ShopGenerator` 生成商店库存，支持节点缓存、刷新、已购买排除、已拥有饰品过滤、构筑倾向推荐和价格曲线。

`EventDatabase` 按层数、已见事件、权重、风险收益和随机源选择事件。`RunManager.apply_event_choice()` 以事务方式应用事件效果，失败会回滚。

`EconomyConfig` 集中维护当前基础经济曲线：普通战斗碎片、Boss 碎片、刷新费、物品价格倍率和饰品稀有度倍率。

### 8. 物品获得语义

统一物品获得入口为 `RunManager.grant_item()`，支持三种去向：

- `deck`：加入卡组。
- `backpack`：尝试自动放入长期背包，失败回退暂存。
- `staging`：进入暂存区，玩家在整理背包界面手动摆放。

商店物品默认进入暂存区；奖励物品默认加入卡组；事件效果可在 JSON 中配置去向。

### 9. UI 与全局反馈

核心场景：

- 主菜单：`src/ui/main_menu/main_menu.tscn`
- Hub：`src/ui/hub/hub_scene.tscn`
- 局内：`src/ui/main_game_ui.tscn`
- 商店：`src/ui/shop/shop_scene.tscn`
- 事件：`src/ui/event/event_scene.tscn`
- 背包：`src/ui/backpack/backpack_ui.tscn`
- 调试沙盒：`src/ui/debug/debug_sandbox.tscn`

`GlobalFeedback` 会为场景内和运行时动态生成的 `BaseButton` 自动绑定 hover 缩放、手型光标和点击音效。

当前已知 UI 问题：用户视频反馈显示 Hub、整理背包和局内界面切换时背包布面板存在大面积覆盖和层级重叠。后续修复优先检查 `HubScene._open_backpack_overlay()` 与 `main_game_ui.tscn` 的背包布局，必要时拆出独立整理背包 scene。

### 10. 测试与发布

本地全量测试：

```powershell
.\tools\run_tests_silent.ps1
```

严格场景冒烟：

```powershell
python -B scripts\run_scene_smoke_tests.py --fail-on-engine-error
```

发布预检：

```powershell
.\tools\export_windows_release.ps1 -PrecheckOnly
```

发布脚本会运行 GUT 和严格场景冒烟，并写入 `package/*.manifest.json`。正式导出使用 `export_presets.cfg` 中的 `Windows Desktop` preset。

## 三、目录结构

```text
res://
├── addons/        # GUT 等第三方插件
├── assets/        # 美术、音频、应用图标
├── data/          # 物品、饰品、事件、路线等静态数据
├── scripts/       # 场景冒烟 runner 配置
├── spec/          # 设计文档、技术文档、历史日志
├── src/
│   ├── autoload/  # 全局管理器和数据库
│   ├── battle/    # 局内流程和动作播放
│   ├── core/      # 背包、效果、事件、饰品、奖励、路线等纯逻辑
│   ├── debug/     # 手工调试场景
│   └── ui/        # 场景和 UI 控制脚本
├── test/          # GUT 单元/集成测试
└── tools/         # 本地测试、发布和资源工具
```

## 四、仍未闭环事项

- F1 道具系统：用户已确认暂缓。
- 正式捕梦动画、美术或 CG：缺少正式素材，替换点是 `MainGameUI._play_dreamcatcher_animation()`。
- GitHub Releases 自动发布：需要 tag 策略、token 和发布权限；当前仅完成本地归档发布流程。
