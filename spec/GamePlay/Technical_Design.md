# Lost Fragments - 技术设计文档 (Gameplay)

## 1. 核心架构设计

### 1.1 数据层 (Model / Resource)
- **`ItemData.gd` (src/core/item_data.gd)**:
	- `id`: String
	- `item_name`: String
	- `tags`: Array[String] (类别词条，如 ["运动", "神秘"])
	- `shape`: Array[Vector2i]
	- `direction`: Enum (UP, DOWN, LEFT, RIGHT)
	- `runtime_id`: int (用于逻辑与表现层的稳定绑定)
	- `effects`: Array[ItemEffect]

### 1.2 逻辑层 (Logic / Manager)
- **`BattleManager.gd`**:
	- `draw_count`: int (记录当前局内抽取次数)
	- `request_draw()`: 
		1. 计算消耗：`cost = 5 + 1 * draw_count`。
		2. 调用 `GameState` 扣除 San 值。
		3. 实例化 `ItemData` 并通过信号发送。
	- **`request_discard_item(item_ui)`**:
		1. 接口预留：处理丢弃逻辑。
		2. 触发该物品及全局的 `on_discard` 效果。
		3. 销毁 UI 节点并清理映射。
	- **`trigger_impact_at(pos: Vector2i)`**: 
		1. 获取该位置物品及其朝向。
		2. 调用 `ImpactResolver` 解析动作序列。
		3. 调用 `SequencePlayer` 异步回放。
- **`BackpackManager.gd`**:
	- `grid`: Dictionary[Vector2i, ItemInstance]
	- 管理网格占用与物品实例生命周期。

### 1.3 表现层 (View)
- **`MainGameUI.gd`**: 
	- 响应 `item_drawn` 信号，在暂置区创建 `ItemUI`。
	- **垃圾桶检测**：当 `ItemUI` 掉落在特定区域时，调用 `request_discard_item`。

## 2. 核心游戏流程

1. **Wait_Input**: 玩家点击抽卡。
2. **Draw_Stage**:
	- 扣除阶梯式 San 值 (`5 + 1*n`)。
	- 随机抽取物品，检查是否触发“同名连锁”等特殊逻辑。
3. **Placing_Stage**:
	- 玩家放置或丢弃物品。**注意：放置动作本身不再触发撞击**。
4. **Resolution_Stage**:
	- 由特定事件（如抽到特定卡牌）手动调用 `trigger_impact_at` 发起。

## 3. 饰品系统 (Ornaments)
- 饰品作为全局 Buff 容器，在 `ImpactResolver` 或 `BattleManager` 计算逻辑时注入影响。
