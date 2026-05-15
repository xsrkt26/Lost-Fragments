extends Control

## 商店场景：允许玩家购买物品和饰品

const RouteConfig = preload("res://src/core/route/route_config.gd")

@onready var shard_label = $MarginContainer/VBoxContainer/Header/ShardLabel
@onready var shelf = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var refresh_button = $MarginContainer/VBoxContainer/Header/RefreshButton
@onready var back_button = $MarginContainer/VBoxContainer/Header/BackButton

func _ready():
	print("[Shop] 欢迎光临梦境商店")
	GlobalInput.set_context(GlobalInput.Context.UI)
	_update_shard_display()
	_populate_shelf()
	
	refresh_button.pressed.connect(_on_refresh_pressed)
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
	_update_refresh_button()

func _update_refresh_button() -> void:
	var rm = get_node_or_null("/root/RunManager")
	if rm == null or not rm.has_method("get_current_shop_refresh_cost"):
		refresh_button.disabled = true
		return
	var cost = rm.get_current_shop_refresh_cost()
	refresh_button.text = "刷新 %d" % cost
	refresh_button.tooltip_text = "刷新当前商店库存"
	refresh_button.disabled = int(rm.current_shards) < cost

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
	_update_refresh_button()

func _add_shop_offer(offer: Dictionary):
	var btn = Button.new()
	btn.set_meta("offer", offer)
	btn.text = _format_offer_text(offer)
	btn.tooltip_text = str(offer.get("description", ""))
	btn.custom_minimum_size = Vector2(200, 100)
	btn.mouse_entered.connect(func(): _show_offer_tooltip(offer))
	btn.mouse_exited.connect(_hide_offer_tooltip)
	btn.pressed.connect(func(): _buy_offer(offer, btn))
	shelf.add_child(btn)

func _format_offer_text(offer: Dictionary) -> String:
	var title = str(offer.get("title", "商品"))
	var price = _get_offer_price(offer)
	match str(offer.get("type", "")):
		"item":
			return "%s\n物品/%s | %d 碎片" % [title, _format_item_destination(offer), price]
		"ornament":
			return "%s\n%s饰品 | %d 碎片" % [title, str(offer.get("rarity", "")), price]
		"tool":
			return "%s\n%s | %d 碎片" % [title, str(offer.get("rarity", "道具")), price]
	return "%s\n%d 碎片" % [title, price]

func _format_item_destination(offer: Dictionary) -> String:
	match str(offer.get("item_destination", offer.get("destination", "deck"))):
		"backpack":
			return "入背包"
		"staging":
			return "暂存"
	return "入卡组"

func _buy_offer(offer: Dictionary, button: Button):
	GlobalTooltip.hide()
	var rm = get_node_or_null("/root/RunManager")
	var item_db = get_node_or_null("/root/ItemDatabase")
	if rm and rm.has_method("buy_shop_offer") and rm.buy_shop_offer(offer, item_db):
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

func _show_offer_tooltip(offer: Dictionary) -> void:
	if str(offer.get("type", "")) != "item":
		GlobalTooltip.hide()
		return
	var item_db = get_node_or_null("/root/ItemDatabase")
	var item = item_db.get_item_by_id(str(offer.get("id", ""))) if item_db and item_db.has_method("get_item_by_id") else null
	if item:
		GlobalTooltip.show_item(item)
	else:
		GlobalTooltip.hide()

func _hide_offer_tooltip() -> void:
	GlobalTooltip.hide()

func _on_refresh_pressed() -> void:
	GlobalTooltip.hide()
	var rm = get_node_or_null("/root/RunManager")
	var item_db = get_node_or_null("/root/ItemDatabase")
	var ornament_db = get_node_or_null("/root/OrnamentDatabase")
	if rm == null or item_db == null or not rm.has_method("refresh_current_shop_offers"):
		return
	rm.refresh_current_shop_offers(item_db, ornament_db, 4)
	_update_shard_display()
	_populate_shelf()

func _on_back_pressed():
	GlobalTooltip.hide()
	var rm = get_node_or_null("/root/RunManager")
	if rm and rm.get_current_route_node_type() == RouteConfig.NODE_SHOP:
		rm.advance_route_node()
		var next_scene = GlobalScene.SceneType.MAIN_MENU if rm.is_run_complete else GlobalScene.SceneType.HUB
		GlobalScene.transition_to(next_scene, false)
	else:
		GlobalScene.go_back()
