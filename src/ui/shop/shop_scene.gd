extends Control

## 商店场景：允许玩家购买新卡牌

@onready var shard_label = $MarginContainer/VBoxContainer/Header/ShardLabel
@onready var shelf = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var back_button = $MarginContainer/VBoxContainer/Header/BackButton

func _ready():
	print("[Shop] 欢迎光临梦境商店")
	GlobalInput.set_context(GlobalInput.Context.UI)
	_update_shard_display()
	_populate_shelf()
	
	back_button.pressed.connect(_on_back_pressed)

func _input(event):
	# 输入权限检查
	if not GlobalInput.can_cancel(): return

	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		_on_back_pressed()

func _update_shard_display():
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		shard_label.text = "碎片: " + str(rm.current_shards)

func _populate_shelf():
	# 模拟商店货架
	var item_db = get_node_or_null("/root/ItemDatabase")
	if not item_db: return
	
	for child in shelf.get_children():
		child.queue_free()
		
	# 随机挑选 3 个物品出售
	var keys = item_db.items.keys()
	keys.shuffle()
	
	for i in range(min(3, keys.size())):
		var item = item_db.items[keys[i]]
		_add_shop_item(item)

func _add_shop_item(item_data: ItemData):
	var btn = Button.new()
	btn.text = item_data.item_name + "\n价格: " + str(item_data.price)
	btn.custom_minimum_size = Vector2(200, 100)
	btn.pressed.connect(func(): _buy_item(item_data))
	shelf.add_child(btn)

func _buy_item(item_data: ItemData):
	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.current_shards >= item_data.price:
		rm.current_shards -= item_data.price
		rm.current_deck.append(item_data.id)
		print("[Shop] 购买成功: ", item_data.item_name)
		_update_shard_display()
	else:
		print("[Shop] 购买失败：碎片不足！")

func _on_back_pressed():
	GlobalScene.go_back()
