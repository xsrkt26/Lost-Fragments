extends Control

## 背包 UI 脚本：负责将 BackpackManager 的数据可视化

@export var slot_scene: PackedScene # 单个格子的场景（可选，这里先用代码生成）
@export var grid_container_path: NodePath = "GridContainer"

@onready var grid_container: GridContainer = get_node(grid_container_path)

var manager: BackpackManager

func setup(p_manager: BackpackManager):
	manager = p_manager
	_refresh_grid()

func _refresh_grid():
	if not manager: return
	
	# 清除现有格子
	for child in grid_container.get_children():
		child.queue_free()
	
	# 设置 GridContainer 列数
	grid_container.columns = manager.grid_width
	
	# 生成所有格子
	for i in range(manager.grid_width * manager.grid_height):
		var slot = ColorRect.new()
		slot.custom_minimum_size = Vector2(64, 64)
		slot.color = Color(1, 1, 1, 0.1) # 半透明背景
		
		var border = ReferenceRect.new()
		border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		border.border_color = Color.GRAY
		border.editor_only = false
		slot.add_child(border)
		
		grid_container.add_child(slot)

## 获取指定网格坐标在 UI 上的中心位置
func get_slot_center_position(grid_pos: Vector2i) -> Vector2:
	if not manager: return Vector2.ZERO
	if grid_pos.x < 0 or grid_pos.y < 0: return Vector2.ZERO
	
	# 确保容器已经完成了布局计算
	grid_container.force_update_transform()
	
	# 计算索引
	var index = grid_pos.y * manager.grid_width + grid_pos.x
	if index >= grid_container.get_child_count(): return Vector2.ZERO
	
	var slot = grid_container.get_child(index) as Control
	# 返回相对于 BackpackUI 的位置 + 格子大小的一半（中心）
	return slot.position + (slot.size / 2.0)

## 根据全局坐标查找最近的网格坐标（增加容错性）
func get_grid_pos_at(global_pos: Vector2) -> Vector2i:
	var closest_pos = Vector2i(-1, -1)
	var min_dist = 99999.0
	var threshold = 60.0 # 只有距离格子中心 60 像素以内才算感应到
	
	for i in range(grid_container.get_child_count()):
		var slot = grid_container.get_child(i) as Control
		var slot_center = slot.global_position + (slot.size / 2.0)
		var dist = global_pos.distance_to(slot_center)
		
		if dist < min_dist and dist < threshold:
			min_dist = dist
			var x = i % manager.grid_width
			var y = i / manager.grid_width
			closest_pos = Vector2i(x, y)
			
	return closest_pos

## 将物品 UI 添加并对齐到网格
func add_item_visual(item_ui: Control, grid_pos: Vector2i):
	# 如果该物品还没在 BackpackUI 下，则添加
	if item_ui.get_parent() != self:
		if item_ui.get_parent():
			item_ui.get_parent().remove_child(item_ui)
		add_child(item_ui)
	
	grid_container.force_update_transform()
	await get_tree().process_frame
	var target_center = get_slot_center_position(grid_pos)
	item_ui.position = target_center - (item_ui.custom_minimum_size / 2.0)

## 当物品被松开时调用（处理吸附和放置逻辑）
func handle_item_dropped(item_ui: Control, drop_center_pos: Vector2):
	var grid_pos = get_grid_pos_at(drop_center_pos)
	
	# 如果物品已经在背包里，先记录旧位置并移除
	var old_pos = Vector2i(-1, -1)
	for pos in manager.grid.keys():
		if manager.grid[pos].data == item_ui.item_data:
			old_pos = manager.grid[pos].root_pos
			break
	
	if old_pos != Vector2i(-1, -1):
		manager.remove_item_at(old_pos)
	# 检查新位置是否能放下
	if grid_pos != Vector2i(-1, -1) and manager.can_place_item(item_ui.item_data, grid_pos):
		manager.place_item(item_ui.item_data, grid_pos)
		add_item_visual(item_ui, grid_pos)

		# --- 重构后的核心：生成序列并播放 ---
		var resolver = ImpactResolver.new(manager)
		var actions = resolver.resolve_impact(grid_pos, item_ui.item_data.direction)

		var player = SequencePlayer.new()
		add_child(player) # 需要在树里才能用 timer 和 await
		player.play_sequence(actions)
		player.sequence_finished.connect(func(): player.queue_free())

	else:
		# 放不下，回弹到旧位置或原位
		if old_pos != Vector2i(-1, -1):
			manager.place_item(item_ui.item_data, old_pos)
			add_item_visual(item_ui, old_pos)
		print("[Action] 放不下或不在范围内，已回弹")
