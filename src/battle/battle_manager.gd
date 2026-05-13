class_name BattleManager
extends Node

## 战斗管理器：游戏的逻辑中枢 (Controller)
## 负责协调 backpack 数据、碰撞解析、序列播放和音频触发

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

# UI 3.0 尺寸适配 (原始素材像素)
const GRID_STEP = Vector2(103.2857, 97.7142)
const SLOT_HALF = Vector2(51.6428, 48.8571)

func _init():
	print("[BattleManager] 正在初始化逻辑数据...")
	# 初始化逻辑数据
	backpack_manager = BackpackManager.new()
	add_child(backpack_manager)
	# 7x7 总格，5x5 可用
	backpack_manager.setup_grid(7, 7, 5, 5)

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
func request_rotate_item(item_ui: Control, mouse_global_pos: Vector2, pivot_offset: Vector2i):
	var item_data = item_ui.get("item_data") as ItemData
	if not item_data: return
	
	print("[BattleManager] 收到旋转请求: ", item_data.item_name)
	
	var old_pos = _find_item_old_pos(item_data)
	if old_pos == Vector2i(-1, -1):
		_rotate_outside_item(item_ui, mouse_global_pos, pivot_offset)
		return
	if old_pos != Vector2i(-1, -1):
		# 1. 尝试将物品从逻辑中移除
		backpack_manager.remove_by_runtime_id(item_data.runtime_id)
	
	if not is_instance_valid(backpack_ui):
		return
		
	# 保存旋转前的状态
	var old_direction = item_data.direction
	var old_shape = item_data.shape.duplicate()
	
	# 预测新局部偏移量 (如果旋转的话)
	var new_pivot_offset = item_data.get_rotated_offset(pivot_offset)
		
	# 真正执行旋转
	item_data.rotate_90()
	if item_ui.has_method("_sync_visuals"):
		item_ui._sync_visuals()
		
	# 2. 精确计算新的 root_pos 
	var mouse_grid_pos = backpack_ui.get_grid_pos_at(mouse_global_pos)
	var new_root_pos = mouse_grid_pos - new_pivot_offset
	
	if backpack_manager.can_place_item(item_data, new_root_pos):
		# 3a. 碰撞检测通过：放回去
		backpack_manager.place_item(item_data, new_root_pos)
		GlobalAudio.play_sfx("place")
		
		var new_instance = backpack_manager.grid[new_root_pos]
		item_ui.set("item_instance", new_instance)
		item_ui.set("item_data", new_instance.data)
		
		# 视觉表现
		if backpack_ui.has_method("add_item_visual"):
			backpack_ui.add_item_visual(item_ui, new_root_pos)
		print("[BattleManager] 旋转成功，新位置: ", new_root_pos)
	else:
		# 3b. 碰撞检测失败：恢复状态并强制弹出 (符合用户对“失败弹出”位置的需求)
		item_data.direction = old_direction
		item_data.shape = old_shape
		if item_ui.has_method("_sync_visuals"):
			item_ui._sync_visuals()
			
		print("[BattleManager] 旋转导致碰撞/出界，强制弹出到侧边。")
		_handle_place_failure(item_ui, Vector2i(-1, -1), [])

## 处理玩家放置物品的逻辑请求
func request_place_item(item_ui: Control, grid_pos: Vector2i):
	var item_data = item_ui.get("item_data") as ItemData
	if not item_data: return
	
	var old_pos = _find_item_old_pos(item_data)
	var old_shape = _get_logical_shape_in_grid(item_data)
	
	if grid_pos == Vector2i(-1, -1):
		request_place_item_outside(item_ui)
		return

	# 在检查可放置性之前，先把物品从网格中临时移除
	# 这样拖拽多格物品时就不会和它自己原本的格子发生碰撞
	if old_pos != Vector2i(-1, -1):
		backpack_manager.remove_by_runtime_id(item_data.runtime_id)

	if not backpack_manager.can_place_item(item_data, grid_pos):
		# 如果放置失败，_handle_place_failure 会负责把它放回 old_pos
		_handle_place_failure(item_ui, old_pos, old_shape)
		return
	
	backpack_manager.place_item(item_data, grid_pos)
	GlobalAudio.play_sfx("place")
	
	var bus = get_node_or_null("/root/GlobalEventBus")
	if bus:
		bus.item_placed.emit(backpack_manager.grid[grid_pos])
	
	var old_data = item_data
	var new_instance = backpack_manager.grid[grid_pos]
	item_ui.set("item_instance", new_instance)
	item_ui.set("item_data", new_instance.data)
	
	if is_instance_valid(backpack_ui):
		if backpack_ui.has_method("update_item_mapping"):
			backpack_ui.update_item_mapping(old_data, new_instance.data)
		if backpack_ui.has_method("add_item_visual"):
			backpack_ui.add_item_visual(item_ui, grid_pos)
	
	print("[BattleManager] 物品已放置")

## 处理物品放置到背包外的逻辑
func request_place_item_outside(item_ui: Control):
	var item_data = item_ui.get("item_data") as ItemData
	if not item_data: return

	var old_pos = _find_item_old_pos(item_data)
	if old_pos != Vector2i(-1, -1):
		backpack_manager.remove_by_runtime_id(item_data.runtime_id)
	_remove_item_visual_mapping(item_data)
	item_ui.set("item_instance", null)
	_move_item_visual_outside(item_ui, item_ui.global_position)

	if is_instance_valid(backpack_ui) and backpack_ui.has_method("update_slot_visuals"):
		backpack_ui.update_slot_visuals()

	print("[BattleManager] Item placed outside backpack")

func _rotate_outside_item(item_ui: Control, _mouse_global_pos: Vector2, pivot_offset: Vector2i):
	var item_data = item_ui.get("item_data") as ItemData
	if not item_data: return

	var new_pivot_offset = item_data.get_rotated_offset(pivot_offset)
	item_data.rotate_90()
	if item_ui.has_method("_sync_visuals"):
		item_ui._sync_visuals()

	var pivot_delta = Vector2(pivot_offset.x - new_pivot_offset.x, pivot_offset.y - new_pivot_offset.y)
	_move_item_visual_outside(item_ui, item_ui.global_position + pivot_delta * Vector2(100.0, 94.0) * 0.7)
	GlobalAudio.play_sfx("place")
	print("[BattleManager] Outside item rotated")

func _move_item_visual_outside(item_ui: Control, global_pos: Vector2):
	var target_parent = _get_outside_item_parent()
	if target_parent and item_ui.get_parent() != target_parent:
		if item_ui.get_parent():
			item_ui.get_parent().remove_child(item_ui)
		target_parent.add_child(item_ui)

	item_ui.scale = Vector2(0.7, 0.7)
	item_ui.global_position = global_pos
	item_ui.z_index = 0

func _get_outside_item_parent() -> Node:
	if is_instance_valid(backpack_ui):
		var grid_panel = backpack_ui.get_parent()
		if grid_panel and grid_panel.get_parent():
			return grid_panel.get_parent()
	if get_parent():
		return get_parent()
	return self

func _remove_item_visual_mapping(item_data: ItemData):
	if not is_instance_valid(backpack_ui):
		return
	var item_ui_map = backpack_ui.get("item_ui_map")
	if item_ui_map is Dictionary and item_ui_map.has(item_data.runtime_id):
		item_ui_map.erase(item_data.runtime_id)
		backpack_ui.set("item_ui_map", item_ui_map)
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
		GlobalAudio.play_sfx("error")
		if item_ui.get_parent() == backpack_ui:
			backpack_ui.remove_child(item_ui)
			# 统一回到 ContentLayer (scale 1.0)，避免叠加 GridPanel 的 0.7 缩放
			var content_layer = backpack_ui.get_parent().get_parent()
			if content_layer:
				content_layer.add_child(item_ui)
			else:
				# 兜底方案
				get_parent().add_child(item_ui)
				
		item_ui.set("item_instance", null)
		item_ui.scale = Vector2(0.7, 0.7)
		
		# 统一弹出位置：背包左侧一点 (相对 GridPanel 坐标系)
		var bp_rect = backpack_ui.get_global_rect() if is_instance_valid(backpack_ui) else Rect2(Vector2(500, 300), Vector2(1,1))
		item_ui.global_position = Vector2(bp_rect.position.x - 180, bp_rect.position.y + 150)
		
		var tween = create_tween()
		tween.tween_property(item_ui, "scale", Vector2(0.77, 0.77), 0.1)
		tween.tween_property(item_ui, "scale", Vector2(0.7, 0.7), 0.1)

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
	
	GlobalAudio.play_sfx("draw")
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
			_process_new_item_acquisition(item)

func debug_clear_all():
	if backpack_manager:
		backpack_manager.grid.clear()
		if is_instance_valid(backpack_ui) and backpack_ui.has_method("_refresh_grid"):
			backpack_ui._refresh_grid()
