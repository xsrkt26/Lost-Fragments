extends Control

## 图鉴场景：展示所有已解锁/未解锁物品

@onready var grid = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var back_button = $MarginContainer/VBoxContainer/Header/BackButton

func _ready():
	print("[Gallery] 进入物品图鉴")
	GlobalInput.set_context(GlobalInput.Context.UI)
	_populate_gallery()
	
	back_button.pressed.connect(_on_back_pressed)

func _input(event):
	# 输入权限检查
	if not GlobalInput.can_cancel(): return

	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		_on_back_pressed()

func _populate_gallery():
	var item_db = get_node_or_null("/root/ItemDatabase")
	if not item_db: return
	
	# 清理旧节点
	for child in grid.get_children():
		child.queue_free()
	
	# 加载所有物品并展示 (此处暂时使用简单的 Label 或图标)
	for item_id in item_db.items.keys():
		var item = item_db.items[item_id]
		var label = Label.new()
		label.text = item.item_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(label)

func _on_back_pressed():
	GlobalScene.go_back()
