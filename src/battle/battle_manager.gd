class_name BattleManager
extends Node

## 战斗管理器：游戏的逻辑中枢 (Controller)
## 负责协调背包数据、撞击解析和动画序列播放

signal turn_started
signal turn_finished
signal item_drawn(item_data: ItemData)

var backpack_manager: BackpackManager
var context: GameContext
var draw_count: int = 0 # 记录当前局内抽取次数

@export var backpack_ui: Control:
	set(v):
		backpack_ui = v
		if backpack_ui and backpack_manager:
			backpack_ui.setup(backpack_manager)

func _init():
	print("[BattleManager] 正在初始化逻辑数据...")
	# 初始化逻辑数据
	backpack_manager = BackpackManager.new()
	backpack_manager.setup_grid(5, 5)

func _ready():
	print("[BattleManager] 节点就绪")
	# 初始化上下文（依赖注入）
	var gs = get_node_or_null("/root/GameState")
	context = GameContext.new(gs, self)
	
	# 如果 UI 已经注入，确保它被初始化
	if backpack_ui:
		print("[BattleManager] 正在初始化已绑定的 UI...")
		backpack_ui.setup(backpack_manager)

func _exit_tree():
	print("[BattleManager] 正在卸载...")

## 处理玩家放置物品的逻辑请求
func request_place_item(item_ui: Control, grid_pos: Vector2i):
	if grid_pos == Vector2i(-1, -1):
		print("[BattleManager] 放置失败: 未能捕捉到有效的网格位置")
		backpack_ui.add_item_visual(item_ui, _find_item_old_pos(item_ui.item_data))
		return

	# --- 核心优化：先移除旧位置，再检查新位置 ---
	# 这样物品在微调位置时，就不会撞到“自己之前的影子”
	var old_pos = _find_item_old_pos(item_ui.item_data)
	if old_pos != Vector2i(-1, -1):
		backpack_manager.remove_item_at(old_pos)

	if not backpack_manager.can_place_item(item_ui.item_data, grid_pos):
		print("[BattleManager] 逻辑拒绝放置: 物品 ", item_ui.item_data.item_name, " 在 ", grid_pos, " 处无法放下 (出界或重叠)")
		# 如果新位置不行，放回老位置
		if old_pos != Vector2i(-1, -1):
			backpack_manager.place_item(item_ui.item_data, old_pos)
		backpack_ui.add_item_visual(item_ui, old_pos)
		return
	
	# 1. 逻辑层：放置新位置
	backpack_manager.place_item(item_ui.item_data, grid_pos)
	
	# 2. 表现层：更新 UI 位置
	var old_data = item_ui.item_data
	var new_instance = backpack_manager.grid[grid_pos]
	item_ui.item_data = new_instance.data
	
	backpack_ui.update_item_mapping(old_data, item_ui.item_data)
	backpack_ui.add_item_visual(item_ui, grid_pos)
	
	print("[BattleManager] 物品已放置，不再自动触发撞击")

## 发起一次指定的撞击
func trigger_impact_at(pos: Vector2i):
	if not backpack_manager.grid.has(pos):
		print("[BattleManager] 警告: 尝试在空坐标发起撞击: ", pos)
		return
		
	var instance = backpack_manager.grid[pos]
	print("[BattleManager] 手动触发撞击. 源物品: ", instance.data.item_name, " 坐标: ", pos)
	_run_impact_sequence(pos, instance.data.direction)

## 处理丢弃逻辑
func request_discard_item(item_ui: Control):
	print("[BattleManager] 物品丢弃请求: ", item_ui.item_data.item_name)
	# TODO: 触发 on_discard 效果
	# 清理 UI 映射
	if backpack_ui and backpack_ui.item_ui_map.has(item_ui.item_data.runtime_id):
		backpack_ui.item_ui_map.erase(item_ui.item_data.runtime_id)
	
	item_ui.queue_free()

func _run_impact_sequence(start_pos: Vector2i, dir: ItemData.Direction):
	turn_started.emit()
	
	var resolver = ImpactResolver.new(backpack_manager, context)
	var actions = resolver.resolve_impact(start_pos, dir)
	
	var player = SequencePlayer.new()
	add_child(player)
	
	# 播放并等待结束
	await player.play_sequence(actions, backpack_ui.item_ui_map, context)
	
	player.queue_free()
	turn_finished.emit()

func _find_item_old_pos(item_data: ItemData) -> Vector2i:
	for pos in backpack_manager.grid.keys():
		if backpack_manager.grid[pos].data == item_data:
			return backpack_manager.grid[pos].root_pos
	return Vector2i(-1, -1)

func _remove_item_from_logic(item_data: ItemData):
	var old_pos = _find_item_old_pos(item_data)
	if old_pos != Vector2i(-1, -1):
		backpack_manager.remove_item_at(old_pos)

## 模拟抽卡逻辑：生成一个随机物品并通知 UI
func request_draw():
	# 1. 计算并扣除阶梯式 San 值 (5 + 1 * n)
	var cost = 5 + 1 * draw_count
	if context and context.state:
		context.state.consume_sanity(cost)
		print("[BattleManager] 抽卡消耗 San 值: ", cost, " (当前次数: ", draw_count, ")")
	
	draw_count += 1

	# 2. 生成随机物品
	var item = ItemData.new()
	var type = randi() % 3
	if type == 0:
		item.item_name = "棒球"
		item.tags = ["运动"] as Array[String]
		item.direction = ItemData.Direction.RIGHT
		item.effects.append(ScoreEffect.new())
	elif type == 1:
		item.item_name = "诅咒箱"
		item.tags = ["神秘"] as Array[String]
		item.direction = ItemData.Direction.DOWN
		item.effects.append(SanityEffect.new())
	else:
		item.item_name = "长木板"
		item.tags = ["工具"] as Array[String]
		item.direction = ItemData.Direction.RIGHT
		item.shape.clear()
		item.shape.append(Vector2i(0, 0))
		item.shape.append(Vector2i(1, 0))
		item.effects.append(ScoreEffect.new())
	
	item.runtime_id = randi()
	
	# 3. 特殊逻辑：同名卡连锁触发 (目前仅 棒球 具备该特性)
	# 先通知 UI 创建新物品，再触发旧物品撞击（符合“抽到卡时，旧卡撞击”的直觉）
	if item.item_name == "棒球":
		_check_same_name_trigger(item.item_name)
	
	item_drawn.emit(item)

func _check_same_name_trigger(new_item_name: String):
	# 遍历背包，找到所有同名卡牌并依次触发一次撞击
	for pos in backpack_manager.grid.keys():
		var instance = backpack_manager.grid[pos]
		# 只有 root 坐标才触发一次，防止占据多格的物品重复触发
		if instance.root_pos == pos and instance.data.item_name == new_item_name:
			print("[BattleManager] 发现同名卡，触发连锁: ", new_item_name, " 在坐标 ", pos)
			trigger_impact_at(pos)
