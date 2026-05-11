class_name ItemUI
extends Control

## 物品 UI 脚本：负责物品的视觉表现和拖拽信号

@export var item_data: ItemData
var context: GameContext
var item_instance: BackpackManager.ItemInstance:
	set(v):
		if item_instance and item_instance.pollution_changed.is_connected(_on_pollution_changed):
			item_instance.pollution_changed.disconnect(_on_pollution_changed)
		item_instance = v
		if item_instance:
			item_instance.pollution_changed.connect(_on_pollution_changed)
			_update_pollution_visual()

@onready var background = $Background
@onready var label = $Label
@onready var arrow = $Arrow
var pollution_label: Label

func setup(p_data: ItemData, p_context: GameContext = null):
	item_data = p_data
	context = p_context
	
	# 容错：确保 ID 存在，否则基于 ID 的网格清理会失效
	if item_data.runtime_id <= 0:
		item_data.runtime_id = randi()
		
	if is_inside_tree():
		_update_visuals()

func _ready():
	add_to_group("items")
	pivot_offset = Vector2.ZERO # 以左上角为锚点
	
	# 动态创建污染标签（如果不存在）
	if not has_node("PollutionLabel"):
		pollution_label = Label.new()
		pollution_label.name = "PollutionLabel"
		add_child(pollution_label)
		# 样式设置
		pollution_label.set_deferred("horizontal_alignment", HORIZONTAL_ALIGNMENT_RIGHT)
		pollution_label.set_deferred("vertical_alignment", VERTICAL_ALIGNMENT_BOTTOM)
		pollution_label.add_theme_color_override("font_color", Color.PURPLE)
		pollution_label.add_theme_constant_override("outline_size", 4)
		pollution_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 5)
	else:
		pollution_label = $PollutionLabel

	_update_visuals()
	
	# 尝试自动获取关联的实例（如果是重载或初始化）
	_refresh_instance_binding()
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _refresh_instance_binding():
	if context and context.battle:
		var bm = context.battle
		if bm.backpack_manager:
			for pos in bm.backpack_manager.grid.keys():
				var inst = bm.backpack_manager.grid[pos]
				if inst.data.runtime_id == item_data.runtime_id:
					item_instance = inst
					return
	item_instance = null

func _on_pollution_changed(_new_val):
	_update_pollution_visual()

func _update_pollution_visual():
	if not pollution_label: return
	if item_instance and item_instance.current_pollution > 0:
		pollution_label.text = str(item_instance.current_pollution)
		pollution_label.show()
	else:
		pollution_label.hide()

func _update_visuals():
	if not item_data or not is_inside_tree(): return
	
	if label:
		label.text = item_data.item_name
	
	# 根据形状计算 UI 大小 (假设格子大小 64 + 间隔 4 = 68)
	var min_x = 0; var max_x = 0
	var min_y = 0; var max_y = 0
	for p in item_data.shape:
		min_x = min(min_x, p.x); max_x = max(max_x, p.x)
		min_y = min(min_y, p.y); max_y = max(max_y, p.y)
	
	var grid_step = 68.0
	custom_minimum_size = Vector2((max_x - min_x + 1) * grid_step - 4, (max_y - min_y + 1) * grid_step - 4)
	size = custom_minimum_size

	if arrow:
		# 根据朝向旋转箭头
		match item_data.direction:
			ItemData.Direction.UP: arrow.rotation_degrees = -90
			ItemData.Direction.DOWN: arrow.rotation_degrees = 90
			ItemData.Direction.LEFT: arrow.rotation_degrees = 180
			ItemData.Direction.RIGHT: arrow.rotation_degrees = 0

signal drag_started
signal dropped(snap_pos: Vector2, mouse_pos: Vector2)

var is_dragging: bool = false
var is_rotating: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var hover_timer: SceneTreeTimer

func _on_mouse_entered():
	if is_dragging: return
	
	if hover_timer and hover_timer.timeout.is_connected(_on_hover_timeout):
		hover_timer.timeout.disconnect(_on_hover_timeout)
		
	hover_timer = get_tree().create_timer(0.3)
	hover_timer.timeout.connect(_on_hover_timeout)

func _on_mouse_exited():
	if hover_timer and hover_timer.timeout.is_connected(_on_hover_timeout):
		hover_timer.timeout.disconnect(_on_hover_timeout)
	hover_timer = null
	_hide_tooltip()

func _on_hover_timeout():
	if not is_dragging:
		_show_tooltip()

func _show_tooltip():
	var tooltip = get_tree().get_first_node_in_group("card_tooltip")
	if not tooltip:
		var tooltip_scene = load("res://src/ui/tooltip/card_tooltip.tscn")
		tooltip = tooltip_scene.instantiate()
		tooltip.add_to_group("card_tooltip")
		get_tree().root.add_child(tooltip)
	
	var instance = _get_instance_data()
	tooltip.show_tooltip(item_data, instance)

func _hide_tooltip():
	var tooltip = get_tree().get_first_node_in_group("card_tooltip")
	if tooltip:
		tooltip.hide_tooltip()

func _get_instance_data():
	if item_instance:
		return item_instance
	_refresh_instance_binding()
	return item_instance

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				_hide_tooltip()
				drag_offset = get_global_mouse_position() - global_position
				# 置顶显示，防止被其他 UI 遮挡
				z_index = 100
				drag_started.emit()
			else:
				if is_dragging:
					is_dragging = false
					z_index = 0
					# 核心修复：吸附点不再是整个 UI 的中心，而是第一个格子 (0,0) 的中心
					var root_tile_center = global_position + Vector2(34, 34)
					dropped.emit(root_tile_center, get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if item_data and item_data.can_rotate:
				rotate_item()
				get_viewport().set_input_as_handled()

func _process(_delta):
	if is_dragging:
		global_position = get_global_mouse_position() - drag_offset

func rotate_item():
	if not item_data or not item_data.can_rotate or is_rotating: return
	
	# 1. 记录旋转前的“锚点格子”在世界空间的位置
	# 这里的锚点格子就是鼠标当前指向的那个格子
	var mouse_local = get_local_mouse_position()
	var grid_step = 68.0
	var hovered_cell = Vector2i(floor(mouse_local.x / grid_step), floor(mouse_local.y / grid_step))
	
	# 如果点在了形状外，强制修正到第一个格子
	if not item_data.shape.has(hovered_cell):
		hovered_cell = item_data.shape[0]

	# 计算这个格子中心的世界坐标，我们将以此为旋转中心
	var cell_global_center = global_position + Vector2(hovered_cell) * grid_step + Vector2(34, 34)
	
	# 2. 逻辑旋转并归一化
	# 旋转前的 shape 是归一化的，旋转后的 shape 也会由 ItemData 自动归一化
	var old_shape = item_data.shape.duplicate()
	item_data.rotate_90()
	
	# 计算：原本这个 cell 在旋转+归一化后，变成了哪个 cell？
	# a. 旋转：(x, y) -> (-y, x)
	var rotated_cell = Vector2i(-hovered_cell.y, hovered_cell.x)
	# b. 归一化：由于 ItemData 内部做了 offset 处理，我们需要知道那个 offset
	# 既然 ItemData 已经把结果存到了 shape，且它又是归一化的。
	# 我们只需要找到旋转后的新 MinX, MinY 即可算出 new_hovered_cell。
	var min_x = 0; var min_y = 0
	for p in old_shape:
		var rp = Vector2i(-p.y, p.x)
		min_x = min(min_x, rp.x); min_y = min(min_y, rp.y)
	
	var new_hovered_cell = rotated_cell - Vector2i(min_x, min_y)
	
	# 3. 视觉刷新
	_update_visuals()
	_update_pollution_visual()
	
	# 4. 计算新的 UI 全局位置
	# 目标：旋转后，new_hovered_cell 的中心依然重合于 cell_global_center
	var target_global_pos = cell_global_center - (Vector2(new_hovered_cell) * grid_step + Vector2(34, 34))
	
	# 5. 更新状态
	if is_dragging:
		global_position = target_global_pos
		drag_offset = get_global_mouse_position() - global_position
	else:
		# 此时 emit 的 new_root_pos 已经是左上角了，因为 shape 已经归一化
		# 我们不需要再在 BattleManager 里做复杂的逆推
		var new_root_pos_center = target_global_pos + Vector2(34, 34)
		rotation_requested.emit(self, new_root_pos_center, target_global_pos)
		
	# 6. 视觉补间动画
	is_rotating = true
	var visual_pivot = Vector2(new_hovered_cell) * grid_step + Vector2(34, 34)
	pivot_offset = visual_pivot
	rotation_degrees = -90.0
	
	var tween = create_tween()
	tween.tween_property(self, "rotation_degrees", 0.0, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	pivot_offset = Vector2.ZERO
	is_rotating = false

signal rotation_requested(item_ui: Control, target_root_center: Vector2, target_global_pos: Vector2)

# 播放被撞击时的抖动动画
func play_impact_anim():
	var tween = create_tween()
	# 快速左右抖动
	var original_pos = position
	tween.tween_property(self, "position", original_pos + Vector2(10, 0), 0.05)
	tween.tween_property(self, "position", original_pos - Vector2(10, 0), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(5, 0), 0.05)
	tween.tween_property(self, "position", original_pos, 0.05)
	return tween.finished

# 播放触发效果时的闪烁动画
func play_effect_anim():
	var tween = create_tween()
	# 缩放并改变颜色
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(background, "color", Color.WHITE, 0.1)
	
	tween.set_parallel(false)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property(background, "color", Color(0.25, 0.45, 0.65, 1), 0.1)
	return tween.finished
