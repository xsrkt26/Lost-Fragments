extends GutTest

const RunManagerScript = preload("res://src/autoload/run_manager.gd")
const ShopGeneratorScript = preload("res://src/core/rewards/shop_generator.gd")
const ShopScene = preload("res://src/ui/shop/shop_scene.tscn")
const TOOL_ORNAMENT_IDS := [
	"tool_belt",
	"specimen_pin_case",
	"gardening_toolkit",
	"recycling_hook",
	"calibration_screwdriver",
	"universal_toolbox",
]

var item_db
var ornament_db

func before_each():
	item_db = get_node_or_null("/root/ItemDatabase")
	ornament_db = get_node_or_null("/root/OrnamentDatabase")
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()
	if ornament_db and ornament_db.ornaments.is_empty():
		ornament_db.load_all_ornaments()

func after_each():
	GlobalTooltip.hide()
	await get_tree().process_frame

func _make_run_manager(act: int = 1):
	var rm = autofree(RunManagerScript.new())
	rm.current_act = act
	rm.current_shards = 100
	rm.current_deck = [] as Array[String]
	rm.current_ornaments = [] as Array[String]
	rm.is_run_active = true
	return rm

func test_shop_offers_include_items_and_available_ornaments():
	var rm = _make_run_manager(1)

	var offers = ShopGeneratorScript.generate_offers(rm, item_db, ornament_db, 4)
	var types = offers.map(func(offer): return offer.get("type", ""))

	assert_eq(offers.size(), 4)
	assert_true(types.has("item"))
	assert_true(types.has("ornament"))
	for offer in offers:
		assert_true(int(offer.get("price", 0)) > 0)

func test_shop_filters_owned_ornaments():
	var rm = _make_run_manager(1)
	rm.current_ornaments = ["dreamcatcher_filter"] as Array[String]

	var offers = ShopGeneratorScript.generate_offers(rm, item_db, ornament_db, 4)
	for offer in offers:
		assert_false(offer.get("type", "") == "ornament" and offer.get("id", "") == "dreamcatcher_filter")

func test_shop_generation_includes_enabled_tool_ornaments():
	var rm = _make_run_manager(6)

	var offers = ShopGeneratorScript.generate_offers(rm, item_db, ornament_db, 80)
	var ornament_ids = offers.filter(func(offer): return offer.get("type", "") == "ornament").map(func(offer): return str(offer.get("id", "")))

	for ornament_id in TOOL_ORNAMENT_IDS:
		assert_true(ornament_ids.has(ornament_id))

func test_shop_generation_is_reproducible_with_run_seed_and_cached_per_node():
	var rm = _make_run_manager(2)
	rm.current_route_index = 1
	rm.set_random_seed(123456)

	var first = rm.generate_current_shop_offers(item_db, ornament_db, 4)
	var second = rm.generate_current_shop_offers(item_db, ornament_db, 4)
	var restored = autofree(RunManagerScript.new())
	restored.deserialize_run(rm.serialize_run())
	var restored_cached = restored.generate_current_shop_offers(item_db, ornament_db, 4)

	assert_eq(_offer_keys(first), _offer_keys(second))
	assert_eq(_offer_keys(first), _offer_keys(restored_cached))

func test_shop_refresh_spends_shards_and_updates_refresh_cost():
	var rm = _make_run_manager(2)
	rm.current_route_index = 1
	rm.current_shards = 100
	rm.set_random_seed(222)
	var initial_cost = rm.get_current_shop_refresh_cost()

	var before = rm.generate_current_shop_offers(item_db, ornament_db, 4)
	var after = rm.refresh_current_shop_offers(item_db, ornament_db, 4)

	assert_eq(rm.current_shards, 100 - initial_cost)
	assert_eq(rm.get_current_shop_refresh_cost(), initial_cost + 3)
	assert_eq(before.size(), 4)
	assert_eq(after.size(), 4)

func test_shop_prices_scale_with_act():
	var early = _make_run_manager(1)
	var late = _make_run_manager(5)

	var early_offers = ShopGeneratorScript.generate_offers(early, item_db, ornament_db, 12)
	var late_offers = ShopGeneratorScript.generate_offers(late, item_db, ornament_db, 12)
	var early_by_key = _offers_by_key(early_offers)
	var late_by_key = _offers_by_key(late_offers)
	var shared_key = ""
	for key in early_by_key.keys():
		if late_by_key.has(key):
			shared_key = key
			break

	assert_ne(shared_key, "")
	assert_true(int(late_by_key[shared_key].get("price", 0)) >= int(early_by_key[shared_key].get("price", 0)))

func test_buy_shop_offer_spends_shards_and_updates_long_term_state():
	var rm = _make_run_manager(1)

	assert_true(rm.buy_shop_offer({"type": "item", "id": "paper_ball", "price": 7}))
	assert_eq(rm.current_shards, 93)
	assert_eq(rm.current_deck, ["paper_ball"])

	assert_true(rm.buy_shop_offer({"type": "ornament", "id": "old_pocket_watch", "price": 45}))
	assert_eq(rm.current_shards, 48)
	assert_eq(rm.current_ornaments, ["old_pocket_watch"])

	assert_false(rm.buy_shop_offer({"type": "ornament", "id": "old_pocket_watch", "price": 45}))
	assert_eq(rm.current_shards, 48)

	assert_true(rm.buy_shop_offer({"type": "tool", "id": "small_patch", "price": 8}))
	assert_eq(rm.current_shards, 40)
	assert_eq(rm.get_tool_count("small_patch"), 1)

func test_shop_item_offer_uses_card_tooltip():
	var shop = add_child_autofree(ShopScene.instantiate())
	await get_tree().process_frame

	shop._show_offer_tooltip({"type": "item", "id": "paper_ball"})
	await get_tree().create_timer(0.25).timeout

	var tooltip = GlobalTooltip._tooltip_instance
	assert_not_null(tooltip)
	assert_true(tooltip.is_panel_visible())

	var expected_item = item_db.get_item_by_id("paper_ball")
	var title_label = tooltip.get_node("PanelContainer/MarginContainer/VBoxContainer/TitleLabel")
	assert_eq(title_label.text, expected_item.item_name)

func _offer_keys(offers: Array[Dictionary]) -> Array[String]:
	var keys: Array[String] = []
	for offer in offers:
		keys.append(ShopGeneratorScript.make_offer_key(offer))
	return keys

func _offers_by_key(offers: Array[Dictionary]) -> Dictionary:
	var result := {}
	for offer in offers:
		result[ShopGeneratorScript.make_offer_key(offer)] = offer
	return result
