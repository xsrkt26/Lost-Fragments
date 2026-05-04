class_name BattleManager
extends Node

## 战斗管理器：游戏的逻辑中枢 (Controller)
## 负责协调背包数据、撞击解析和动画序列播放

signal turn_started
signal turn_finished

var backpack_manager: BackpackManager
var context: GameContext

@export var backpack_ui: Control:
	set(v):
		backpack_ui = v
		if backpack_ui and backpack_manager:
			backpack_ui.setup(backpack_manager)

func _init():
	# 初始化逻辑数据
	backpack_manager = BackpackManager.new()
	backpack_manager.setup_grid(5, 5)

func _ready():
	# 初始化上下文（依赖注入）
	var gs = get_node_or_null("/root/GameState")
	context = GameContext.new(gs, self)
	
	# 如果 UI 已经注入，确保它被初始化
	if backpack_ui:
		backpack_ui.setup(backpack_manager)

## 处理玩家放置物品的逻辑请求
func request_place_item(item_ui: Control, grid_pos: Vector2i):
	if not backpack_manager.can_place_item(item_ui.item_data, grid_pos):
		# 逻辑层拒绝，通知 UI 回弹
		backpack_ui.add_item_visual(item_ui, _find_item_old_pos(item_ui.item_data))
		return
	
	# 1. 逻辑层：移除旧位置（如果有）并放置新位置
	_remove_item_from_logic(item_ui.item_data)
	backpack_manager.place_item(item_ui.item_data, grid_pos)
	
	# 2. 表现层：更新 UI 位置
	# 注意：place_item 后 item_data 已被 duplicate，需要同步引用
	var old_data = item_ui.item_data
	var new_instance = backpack_manager.grid[grid_pos]
	item_ui.item_data = new_instance.data
	
	backpack_ui.update_item_mapping(old_data, item_ui.item_data)
	backpack_ui.add_item_visual(item_ui, grid_pos)
	
	# 3. 启动连锁反应
	_run_impact_sequence(grid_pos, item_ui.item_data.direction)

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
