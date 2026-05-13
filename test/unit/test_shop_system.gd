extends GutTest

const RunManagerScript = preload("res://src/autoload/run_manager.gd")
const ShopGeneratorScript = preload("res://src/core/rewards/shop_generator.gd")

var item_db
var ornament_db

func before_each():
	item_db = get_node_or_null("/root/ItemDatabase")
	ornament_db = get_node_or_null("/root/OrnamentDatabase")
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()
	if ornament_db and ornament_db.ornaments.is_empty():
		ornament_db.load_all_ornaments()

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
