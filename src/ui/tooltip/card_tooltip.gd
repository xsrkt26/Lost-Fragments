extends CanvasLayer

@onready var panel = $PanelContainer
@onready var title_label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var desc_label = $PanelContainer/MarginContainer/VBoxContainer/DescLabel
@onready var status_label = $PanelContainer/MarginContainer/VBoxContainer/StatusLabel

func _ready():
	panel.hide()

func show_tooltip(item_data: ItemData, instance_data: Variant = null):
	if not item_data:
		return
		
	title_label.text = item_data.item_name
	
	# 使用数据层的动态方法获取富文本描述
	var dynamic_text = item_data.get_tooltip_text(instance_data)
	if dynamic_text != "":
		desc_label.text = dynamic_text
		desc_label.show()
	else:
		desc_label.text = "(暂无描述)"
		desc_label.show()
	
	if instance_data and instance_data.current_pollution > 0:
		status_label.text = "当前污染: " + str(instance_data.current_pollution) + " 层"
		status_label.show()
	else:
		status_label.hide()
		
	panel.show()

func hide_tooltip():
	panel.hide()

func _process(_delta):
	if panel.visible:
		var mouse_pos = panel.get_global_mouse_position()
		# 偏移量，避免挡住鼠标指针
		var offset = Vector2(15, 15) 
		var new_pos = mouse_pos + offset
		
		# 简单的边界检查，防止悬浮窗跑出屏幕外
		var viewport_size = get_viewport().get_visible_rect().size
		if new_pos.x + panel.size.x > viewport_size.x:
			new_pos.x = mouse_pos.x - panel.size.x - 10
		if new_pos.y + panel.size.y > viewport_size.y:
			new_pos.y = mouse_pos.y - panel.size.y - 10
			
		panel.global_position = new_pos
