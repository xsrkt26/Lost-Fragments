extends Control

## 物品 UI 脚本：负责物品的视觉表现和拖拽信号

@export var item_data: ItemData

@onready var background = $Background
@onready var label = $Label
@onready var arrow = $Arrow

func setup(p_data: ItemData):
	item_data = p_data
	if is_inside_tree():
		_update_visuals()

func _ready():
	_update_visuals()

func _update_visuals():
	if not item_data or not is_inside_tree(): return
	
	if label:
		label.text = item_data.item_name
	
	if arrow:
		# 根据朝向旋转箭头
		match item_data.direction:
			ItemData.Direction.UP: arrow.rotation_degrees = -90
			ItemData.Direction.DOWN: arrow.rotation_degrees = 90
			ItemData.Direction.LEFT: arrow.rotation_degrees = 180
			ItemData.Direction.RIGHT: arrow.rotation_degrees = 0

signal drag_started
signal dropped(global_pos: Vector2)

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_offset = get_global_mouse_position() - global_position
				# 置顶显示，防止被其他 UI 遮挡
				z_index = 100
				drag_started.emit()
			else:
				if is_dragging:
					is_dragging = false
					z_index = 0
					dropped.emit(global_position + size / 2.0)

func _process(_delta):
	if is_dragging:
		global_position = get_global_mouse_position() - drag_offset

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
