extends Control

## 商店场景：允许玩家购买物品和饰品

const RouteConfig = preload("res://src/core/route/route_config.gd")

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
	var rm = get_node_or_null("/root/RunManager")
	var item_db = get_node_or_null("/root/ItemDatabase")
	var ornament_db = get_node_or_null("/root/OrnamentDatabase")
	if rm == null or item_db == null:
		return
	
	for child in shelf.get_children():
		child.queue_free()
	
	var offers = rm.generate_current_shop_offers(item_db, ornament_db, 4) if rm.has_method("generate_current_shop_offers") else []
	for offer in offers:
		_add_shop_offer(offer)

func _add_shop_offer(offer: Dictionary):
	var btn = Button.new()
	btn.set_meta("offer", offer)
	btn.text = _format_offer_text(offer)
	btn.tooltip_text = str(offer.get("description", ""))
	btn.custom_minimum_size = Vector2(200, 100)
	btn.pressed.connect(func(): _buy_offer(offer, btn))
	shelf.add_child(btn)

func _format_offer_text(offer: Dictionary) -> String:
	var title = str(offer.get("title", "商品"))
	var price = _get_offer_price(offer)
	match str(offer.get("type", "")):
		"item":
			return "%s\n物品 | %d 碎片" % [title, price]
		"ornament":
			return "%s\n%s饰品 | %d 碎片" % [title, str(offer.get("rarity", "")), price]
	return "%s\n%d 碎片" % [title, price]

func _buy_offer(offer: Dictionary, button: Button):
	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.has_method("buy_shop_offer") and rm.buy_shop_offer(offer):
		print("[Shop] 购买成功: ", offer.get("title", ""))
		button.disabled = true
		button.text = str(offer.get("title", "商品")) + "\n已购买"
		_update_shard_display()
		_refresh_offer_buttons()
	else:
		print("[Shop] 购买失败：碎片不足！")

func _refresh_offer_buttons() -> void:
	for child in shelf.get_children():
		if child is Button and not child.disabled and child.has_meta("offer"):
			child.text = _format_offer_text(child.get_meta("offer"))

func _get_offer_price(offer: Dictionary) -> int:
	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.has_method("get_current_shop_offer_price"):
		return rm.get_current_shop_offer_price(offer)
	return int(offer.get("price", 0))

func _on_back_pressed():
	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.get_current_route_node_type() == RouteConfig.NODE_SHOP:
		rm.advance_route_node()
		var next_scene = GlobalScene.SceneType.MAIN_MENU if rm.is_run_complete else GlobalScene.SceneType.HUB
		GlobalScene.transition_to(next_scene, false)
	else:
		GlobalScene.go_back()
