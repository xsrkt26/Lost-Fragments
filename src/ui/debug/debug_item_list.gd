extends Control

## 调试物品列表：用于在沙盒中选择任意物品

@onready var container = $ScrollContainer/VBoxContainer
var battle_manager: BattleManager

func setup(p_battle_manager: BattleManager):
	battle_manager = p_battle_manager
	_refresh_list()

func _refresh_list():
	for child in container.get_children():
		child.queue_free()
	
	# 添加“清空全部”按钮
	var clear_btn = Button.new()
	clear_btn.text = "!!! 清空全部 !!!"
	clear_btn.modulate = Color.RED
	clear_btn.custom_minimum_size = Vector2(0, 50)
	clear_btn.pressed.connect(_on_clear_pressed)
	container.add_child(clear_btn)
	
	# 分割线
	var hs = HSeparator.new()
	container.add_child(hs)
	
	var item_db = get_node_or_null("/root/ItemDatabase")
	if not item_db: return
	
	var all_items = item_db.get_all_items()
	for item in all_items:
		var btn = Button.new()
		btn.text = item.item_name + " (" + item.id + ")"
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(func(): _on_item_selected(item.id))
		container.add_child(btn)

func _on_item_selected(item_id: String):
	if battle_manager:
		battle_manager.debug_get_item(item_id)

func _on_clear_pressed():
	if battle_manager:
		battle_manager.debug_clear_all()
