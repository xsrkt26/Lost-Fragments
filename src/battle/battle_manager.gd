class_name BattleManager
extends Node

## 战斗管理器：游戏的逻辑中枢 (Controller)
## 负责协调背包数据、撞击解析和动画序列播放

signal turn_started
signal turn_finished
signal item_drawn(item_data: ItemData)

var backpack_manager: BackpackManager
var context: GameContext
var backpack_ui: Control: # 保持 Control 以兼容 Mock 测试
	set(v):
		backpack_ui = v
		if backpack_ui and context:
			if backpack_ui.has_method("setup"):
				backpack_ui.setup(context)

func _init():
	print("[BattleManager] 正在初始化逻辑数据...")
	# 初始化逻辑数据
	backpack_manager = BackpackManager.new()
	add_child(backpack_manager)
	backpack_manager.setup_grid(5, 5)

# --- 运行相关的逻辑变量 ---
var _current_battle_deck: Array[String] = []
var draw_count: int = 0 # 记录当前局内抽取次数

func _ready():
	print("[BattleManager] 节点就绪")
	# 初始化上下文（依赖注入）
	var gs = get_node_or_null("/root/GameState")
	context = GameContext.new(gs, self)
	
	# 如果 UI 已经注入，确保它被初始化
	if backpack_ui:
		print("[BattleManager] 正在初始化已绑定的 UI...")
		if backpack_ui.has_method("setup"):
			backpack_ui.setup(context)
		
	_initialize_battle_data()

func _exit_tree():
	print("[BattleManager] 正在卸载...")

func _initialize_battle_data():
	print("[BattleManager] 正在从 RunManager 初始化战斗数据...")
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		_current_battle_deck = Array(rm.current_deck).duplicate()
		_current_battle_deck.shuffle()
		print("[BattleManager] 洗牌完成，当前战斗卡包大小: ", _current_battle_deck.size())
	else:
		print("[BattleManager] 警告: 未找到 RunManager，使用空卡包运行。")

## 处理物品在背包内被旋转的逻辑请求
## 使用 Control 类型以允许 Mock 注入
func request_rotate_item(item_ui: Control, target_root_center: Vector2, target_global_pos: Vector2):
	var item_data = item_ui.get("item_data") as ItemData
	if not item_data: return
	
	print("[BattleManager] 收到旋转请求: ", item_data.item_name)
	
	var old_pos = _find_item_old_pos(item_data)
	if old_pos != Vector2i(-1, -1):
		# 1. 尝试将物品从逻辑中移除 (使用 RID 移除法，绝对防幽灵)
		backpack_manager.remove_by_runtime_id(item_data.runtime_id)
	
	if not is_instance_valid(backpack_ui):
		return
		
	# 2. 精确计算新的 root_pos (纯逻辑换算，杜绝 UI 吸附修正导致的误判)
	var bp_rect = backpack_ui.get_global_rect()
	var local_pixel_pos = target_root_center - bp_rect.position
	
	var grid_step = 68.0
	var new_root_pos = Vector2i(
		roundi((local_pixel_pos.x - 34.0) / grid_step),
		roundi((local_pixel_pos.y - 34.0) / grid_step)
	)
	
	if backpack_manager.can_place_item(item_data, new_root_pos):
		# 3a. 碰撞检测通过：放回去
		backpack_manager.place_item(item_data, new_root_pos)
		var new_instance = backpack_manager.grid[new_root_pos]
		item_ui.set("item_instance", new_instance)
		item_ui.set("item_data", new_instance.data)
		
		# 视觉表现
		if backpack_ui.has_method("add_item_visual"):
			backpack_ui.add_item_visual(item_ui, new_root_pos)
		print("[BattleManager] 旋转成功，新位置: ", new_root_pos)
	else:
		# 3b. 碰撞检测失败：强制弹出
		print("[BattleManager] 旋转导致碰撞/出界，物品被弹出背包。")
		if item_ui.get_parent() == backpack_ui:
			backpack_ui.remove_child(item_ui)
			if get_tree() and get_tree().current_scene:
				get_tree().current_scene.add_child(item_ui)
			else:
				get_parent().add_child(item_ui)
			
		item_ui.set("item_instance", null)
		item_ui.global_position = Vector2(bp_rect.end.x + 50, bp_rect.position.y + 100)
		
		var tween = create_tween()
		tween.tween_property(item_ui, "scale", Vector2(1.1, 1.1), 0.1)
		tween.tween_property(item_ui, "scale", Vector2(1.0, 1.0), 0.1)

## 处理玩家放置物品的逻辑请求
func request_place_item(item_ui: Control, grid_pos: Vector2i):
	var item_data = item_ui.get("item_data") as ItemData
	if not item_data: return
	
	var old_pos = _find_item_old_pos(item_data)
	var old_shape = _get_logical_shape_in_grid(item_data)
	
	if grid_pos == Vector2i(-1, -1):
		_handle_place_failure(item_ui, old_pos, old_shape)
		return

	if old_pos != Vector2i(-1, -1):
		backpack_manager.remove_by_runtime_id(item_data.runtime_id)

	if not backpack_manager.can_place_item(item_data, grid_pos):
		_handle_place_failure(item_ui, old_pos, old_shape)
		return
	
	backpack_manager.place_item(item_data, grid_pos)
	
	var bus = get_node_or_null("/root/GlobalEventBus")
	if bus:
		bus.item_placed.emit(backpack_manager.grid[grid_pos])
	
	var old_data = item_data
	var new_instance = backpack_manager.grid[grid_pos]
	item_ui.set("item_data", new_instance.data)
	
	if is_instance_valid(backpack_ui):
		if backpack_ui.has_method("update_item_mapping"):
			backpack_ui.update_item_mapping(old_data, new_instance.data)
		if backpack_ui.has_method("add_item_visual"):
			backpack_ui.add_item_visual(item_ui, grid_pos)
	
	print("[BattleManager] 物品已放置")

func _get_logical_shape_in_grid(item_data: ItemData) -> Array[Vector2i]:
	var old_pos = _find_item_old_pos(item_data)
	if old_pos != Vector2i(-1, -1):
		return backpack_manager.grid[old_pos].data.shape
	return item_data.shape

func _handle_place_failure(item_ui: Control, old_pos: Vector2i, _old_shape: Array[Vector2i]):
	var item_data = item_ui.get("item_data") as ItemData
	if old_pos != Vector2i(-1, -1) and backpack_manager.can_place_item(item_data, old_pos):
		backpack_manager.place_item(item_data, old_pos)
		var new_instance = backpack_manager.grid[old_pos]
		item_ui.set("item_instance", new_instance)
		item_ui.set("item_data", new_instance.data)
		if is_instance_valid(backpack_ui) and backpack_ui.has_method("add_item_visual"):
			backpack_ui.add_item_visual(item_ui, old_pos)
	else:
		if item_ui.get_parent() == backpack_ui:
			backpack_ui.remove_child(item_ui)
			if get_tree() and get_tree().current_scene:
				get_tree().current_scene.add_child(item_ui)
			else:
				get_parent().add_child(item_ui)
		item_ui.set("item_instance", null)
		
		var bp_rect = backpack_ui.get_global_rect() if is_instance_valid(backpack_ui) else Rect2(Vector2(500, 500), Vector2(1,1))
		item_ui.global_position = Vector2(bp_rect.end.x + 50, bp_rect.position.y + 100)
		
		var tween = create_tween()
		tween.tween_property(item_ui, "scale", Vector2(1.1, 1.1), 0.1)
		tween.tween_property(item_ui, "scale", Vector2(1.0, 1.0), 0.1)

func trigger_impact_at(pos: Vector2i):
	if not backpack_manager.grid.has(pos):
		return
	var instance = backpack_manager.grid[pos]
	_run_impact_sequence(pos, instance.data.direction)

func request_draw():
	if _current_battle_deck.is_empty():
		_initialize_battle_data()
	if _current_battle_deck.is_empty():
		return
	var item_id = _current_battle_deck.pop_back()
	var item_db = get_node_or_null("/root/ItemDatabase")
	var item = item_db.get_item_by_id(item_id)
	if item:
		_process_new_item_acquisition(item)

func _process_new_item_acquisition(item: ItemData):
	if not item: return
	draw_count += 1
	if item.runtime_id <= 0:
		item.runtime_id = randi()
	for effect in item.effects:
		effect.on_draw(item, context)
	item_drawn.emit(item)
	var all_instances = backpack_manager.get_all_instances()
	for inst in all_instances:
		for effect in inst.data.effects:
			if effect.has_method("on_global_item_drawn"):
				effect.on_global_item_drawn(item, inst, context)
	var new_item_name = item.item_name
	for pos in backpack_manager.grid.keys():
		var instance = backpack_manager.grid[pos]
		if instance.root_pos == pos and instance.data.item_name == new_item_name:
			trigger_impact_at(pos)

func _run_impact_sequence(start_pos: Vector2i, dir: ItemData.Direction):
	turn_started.emit()
	var resolver = ImpactResolver.new(backpack_manager, context)
	var actions = resolver.resolve_impact(start_pos, dir)
	var player = SequencePlayer.new()
	add_child(player)
	var ui_map = {}
	if is_instance_valid(backpack_ui):
		ui_map = backpack_ui.get("item_ui_map")
	await player.play_sequence(actions, ui_map, context)
	player.queue_free()
	turn_finished.emit()

func _find_item_old_pos(item_data: ItemData) -> Vector2i:
	for pos in backpack_manager.grid.keys():
		var inst = backpack_manager.grid[pos]
		if inst.data.runtime_id == item_data.runtime_id:
			return inst.root_pos
	return Vector2i(-1, -1)

func debug_get_item(item_id: String):
	var item_db = get_node_or_null("/root/ItemDatabase")
	if item_db:
		var item = item_db.get_item_by_id(item_id)
		if item:
			item_drawn.emit(item)

func debug_clear_all():
	if backpack_manager:
		backpack_manager.grid.clear()
		if is_instance_valid(backpack_ui) and backpack_ui.has_method("_refresh_grid"):
			backpack_ui._refresh_grid()
