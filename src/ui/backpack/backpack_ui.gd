extends Control

## 背包 UI：纯表现层 (View)
## 只负责显示网格、对齐物品、以及将玩家的操作“上报”给管理器

signal item_dropped_on_grid(item_ui: Control, grid_pos: Vector2i)

@export var grid_container_path: NodePath = "GridContainer"
@onready var grid_container: GridContainer = get_node(grid_container_path)

var manager: BackpackManager # 仅用于读取网格尺寸等基础信息
var item_ui_map: Dictionary = {}

func setup(p_manager: BackpackManager):
	print("[BackpackUI] 接收到 Manager，正在执行 setup...")
	manager = p_manager
	_refresh_grid()

func _refresh_grid():
	if not manager: 
		print("[BackpackUI] 警告: manager 为空，无法刷新网格")
		return
	
	print("[BackpackUI] 正在生成网格: ", manager.grid_width, "x", manager.grid_height)
	for child in grid_container.get_children():
		child.queue_free()
	
	grid_container.columns = manager.grid_width
	for i in range(manager.grid_width * manager.grid_height):
		var slot = ColorRect.new()
		slot.custom_minimum_size = Vector2(64, 64)
		slot.color = Color(1, 1, 1, 0.1)
		var border = ReferenceRect.new()
		border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		border.border_color = Color.GRAY
		border.editor_only = false
		slot.add_child(border)
		grid_container.add_child(slot)
	
	print("[BackpackUI] 网格刷新完成，子节点数: ", grid_container.get_child_count())

func get_slot_center_position(grid_pos: Vector2i) -> Vector2:
	if not manager or grid_pos.x < 0 or grid_pos.y < 0: return Vector2.ZERO
	grid_container.force_update_transform()
	var index = grid_pos.y * manager.grid_width + grid_pos.x
	if index >= grid_container.get_child_count(): return Vector2.ZERO
	var slot = grid_container.get_child(index) as Control
	return slot.position + (slot.size / 2.0)

func get_grid_pos_at(global_pos: Vector2) -> Vector2i:
	var closest_pos = Vector2i(-1, -1)
	var min_dist = 99999.0
	var threshold = 120.0 # 提高阈值，让吸附更灵敏
	
	for i in range(grid_container.get_child_count()):
		var slot = grid_container.get_child(i) as Control
		var slot_center = slot.global_position + (slot.size / 2.0)
		var dist = global_pos.distance_to(slot_center)
		if dist < min_dist and dist < threshold:
			min_dist = dist
			closest_pos = Vector2i(i % manager.grid_width, int(float(i) / manager.grid_width))
	
	if closest_pos != Vector2i(-1, -1):
		print("[BackpackUI] 捕捉到最近格子: ", closest_pos, " 距离: ", min_dist)
	return closest_pos

## 将物品 UI 添加并对齐到网格
func add_item_visual(item_ui: Control, grid_pos: Vector2i):
	if grid_pos == Vector2i(-1, -1): return # 不在网格内
	
	# 更新映射关系（使用 runtime_id 作为稳定键）
	item_ui_map[item_ui.item_data.runtime_id] = item_ui
	
	if item_ui.get_parent() != self:
		if item_ui.get_parent(): item_ui.get_parent().remove_child(item_ui)
		add_child(item_ui)
	
	grid_container.force_update_transform()
	await get_tree().process_frame
	
	# --- 核心修复：多格物品对齐 ---
	# 计算形状的最小偏移量（防止形状不是从 (0,0) 开始的情况）
	var min_offset = Vector2i(0, 0)
	for p in item_ui.item_data.shape:
		min_offset.x = min(min_offset.x, p.x)
		min_offset.y = min(min_offset.y, p.y)
	
	# UI 的位置应基于起始格子的位置，并减去形状的最小偏移（转换为像素）
	var grid_step = 68.0 # 64 + 4 间隔
	var index = grid_pos.y * manager.grid_width + grid_pos.x
	var slot = grid_container.get_child(index) as Control
	item_ui.position = slot.position + Vector2(min_offset) * grid_step

## 同步最新的映射关系（当 Data 被克隆后调用）
func update_item_mapping(old_data: ItemData, new_data: ItemData):
	if item_ui_map.has(old_data.runtime_id):
		var ui = item_ui_map[old_data.runtime_id]
		# 如果新旧 ID 一致（由于 @export 已经保留了），我们只需确保 map 指向最新数据即可
		# 如果项目逻辑需要更严谨，可以保留这个手动同步
		item_ui_map[new_data.runtime_id] = ui
		print("[BackpackUI] 映射关系已同步. RID: ", new_data.runtime_id)

## UI 层的松手处理：不再直接计算逻辑，而是发出信号
func handle_item_dropped(item_ui: Control, drop_center_pos: Vector2):
	var grid_pos = get_grid_pos_at(drop_center_pos)
	# 向上级报告：有人想在这个位置放东西
	item_dropped_on_grid.emit(item_ui, grid_pos)
