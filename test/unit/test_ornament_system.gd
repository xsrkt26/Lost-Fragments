extends GutTest

const BattleManagerScript = preload("res://src/battle/battle_manager.gd")
const RunManagerScript = preload("res://src/autoload/run_manager.gd")
const TOOL_ORNAMENT_IDS := [
	"tool_belt",
	"specimen_pin_case",
	"gardening_toolkit",
	"recycling_hook",
	"calibration_screwdriver",
	"universal_toolbox",
]

var rm
var gs
var item_db
var old_ornaments: Array[String]

func before_each():
	rm = get_node_or_null("/root/RunManager")
	gs = get_node_or_null("/root/GameState")
	item_db = get_node_or_null("/root/ItemDatabase")
	old_ornaments = Array(rm.current_ornaments).duplicate() if rm else []
	if gs:
		gs.reset_game()
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()

func after_each():
	if rm:
		rm.current_ornaments = old_ornaments
	if gs:
		gs.reset_game()

func _make_manager(ornament_ids: Array[String]) -> BattleManager:
	var ids: Array[String] = ornament_ids.duplicate()
	rm.current_ornaments = ids
	var manager = add_child_autofree(BattleManagerScript.new())
	await get_tree().process_frame
	manager.backpack_manager.grid.clear()
	return manager

func _make_draw_item(cost: int = 0) -> ItemData:
	var item = ItemData.new()
	item.id = "test_draw"
	item.item_name = "Test Draw"
	item.base_cost = cost
	item.can_draw = false
	return item

func test_ornament_database_loads_formal_table_and_filters_available_pool():
	var ornament_db = get_node_or_null("/root/OrnamentDatabase")
	assert_not_null(ornament_db)
	var all_ornaments = ornament_db.get_all_ornaments()
	assert_eq(all_ornaments.size(), 56)
	assert_not_null(ornament_db.get_ornament_by_id("old_pocket_watch"))
	var enabled_count := 0
	for ornament in all_ornaments:
		assert_ne(ornament.effect_id, "")
		assert_not_null(ornament.effect)
		if ornament.enabled:
			enabled_count += 1
	assert_eq(enabled_count, 56)
	for ornament_id in TOOL_ORNAMENT_IDS:
		var ornament = ornament_db.get_ornament_by_id(ornament_id)
		assert_not_null(ornament)
		assert_true(ornament.enabled)
		assert_eq(ornament.effect_id, ornament_id)

	var act_one = ornament_db.get_available_ornaments(1, ["old_pocket_watch"] as Array[String])
	for ornament in act_one:
		assert_true(ornament.earliest_act <= 1)
		assert_true(ornament.id != "old_pocket_watch")

	var all_available = ornament_db.get_available_ornaments(6, [] as Array[String])
	var available_ids = all_available.map(func(ornament): return ornament.id)
	for ornament_id in TOOL_ORNAMENT_IDS:
		assert_true(available_ids.has(ornament_id))

func test_run_manager_prevents_duplicate_ornaments():
	var manager = autofree(RunManagerScript.new())
	manager.current_ornaments = [] as Array[String]

	assert_true(manager.add_ornament("old_pocket_watch"))
	assert_false(manager.add_ornament("old_pocket_watch"))
	assert_eq(manager.current_ornaments, ["old_pocket_watch"])

func test_old_pocket_watch_and_safety_pin_modify_sanity_loss_in_order():
	var manager = await _make_manager(["old_pocket_watch", "safety_pin"] as Array[String])
	var item = _make_draw_item(-1)

	manager._process_new_item_acquisition(item)
	assert_eq(gs.current_sanity, 100)

	manager._process_new_item_acquisition(item)
	assert_eq(gs.current_sanity, 98)

func test_dreamcatcher_filter_scores_every_three_draws():
	var manager = await _make_manager(["dreamcatcher_filter"] as Array[String])
	var item = _make_draw_item(0)

	manager._process_new_item_acquisition(item)
	manager._process_new_item_acquisition(item)
	assert_eq(gs.current_score, 0)

	manager._process_new_item_acquisition(item)
	assert_eq(gs.current_score, 3)

func test_echo_earring_scores_once_when_chain_hits_any_item():
	var manager = await _make_manager(["echo_earring"] as Array[String])
	var action = GameAction.new(GameAction.Type.IMPACT, "hit")

	manager._apply_ornament_impact_chain_resolved(null, [action] as Array[GameAction])

	assert_eq(gs.current_score, 2)

func test_guiding_compass_rotates_root_dream_after_empty_chain():
	var manager = await _make_manager(["guiding_compass"] as Array[String])
	var root = ItemData.new()
	root.id = "root_dream"
	root.direction = ItemData.Direction.RIGHT
	var source = BackpackManager.ItemInstance.new(root, Vector2i(1, 1))

	manager._apply_ornament_impact_chain_resolved(source, [] as Array[GameAction])

	assert_eq(root.direction, ItemData.Direction.DOWN)

func test_sturdy_strap_reduces_large_item_draw_cost():
	var manager = await _make_manager(["sturdy_strap"] as Array[String])
	var item = _make_draw_item(4)
	item.shape = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)] as Array[Vector2i]

	manager._process_new_item_acquisition(item)

	assert_eq(gs.current_sanity, 98)

func test_pollution_ornaments_react_to_pollution_changes():
	var manager = await _make_manager(["sealed_bottle", "active_petri_dish", "corrosion_guide"] as Array[String])
	var paper = item_db.get_item_by_id("paper_ball")
	manager.backpack_manager.place_item(paper, Vector2i(1, 1))
	var instance = manager.backpack_manager.grid[Vector2i(1, 1)]

	instance.add_pollution(1)
	assert_eq(gs.current_score, 5)

	instance.add_pollution(1)
	assert_eq(gs.current_score, 8)

func test_discard_ornaments_apply_once_and_count_discards():
	var manager = await _make_manager(["sanity_coin_purse", "light_pendant"] as Array[String])
	gs.current_sanity = 80
	var waste = _make_draw_item(0)
	waste.id = "paper_ball"
	waste.price = -5

	manager._apply_ornament_item_discarded(waste, null, false)
	manager._apply_ornament_item_discarded(waste, null, false)
	manager._apply_ornament_item_discarded(waste, null, false)

	assert_eq(gs.current_score, 10)
	assert_eq(gs.current_sanity, 82)

func test_seed_upgrade_ornaments_score_and_restore_sanity():
	var manager = await _make_manager(["greenhouse_glass", "rejuvenation_talisman"] as Array[String])
	gs.current_sanity = 80
	var seed = item_db.get_item_by_id("dream_seed_4x4")
	manager.backpack_manager.place_item(seed, Vector2i(1, 1))
	var instance = manager.backpack_manager.grid[Vector2i(1, 1)]

	manager._on_ornament_seed_upgraded(instance, 29, 30)

	assert_eq(gs.current_score, 9)
	assert_eq(gs.current_sanity, 83)

	manager._on_ornament_seed_upgraded(instance, 30, 31)

	assert_eq(gs.current_score, 10)
	assert_eq(gs.current_sanity, 83)

func test_greenhouse_glass_scores_when_upgrade_crosses_seed_threshold():
	var manager = await _make_manager(["greenhouse_glass"] as Array[String])
	var seed = item_db.get_item_by_id("dream_seed_2x2")
	manager.backpack_manager.place_item(seed, Vector2i(1, 1))
	var instance = manager.backpack_manager.grid[Vector2i(1, 1)]

	manager._on_ornament_seed_upgraded(instance, 9, 11)

	assert_eq(gs.current_score, 9)

func test_chain_end_ornaments_score_from_hit_count_thresholds():
	var manager = await _make_manager(["chain_counter", "terminal_pressure_gauge"] as Array[String])
	var actions: Array[GameAction] = []
	for index in range(8):
		var action = GameAction.new(GameAction.Type.IMPACT, "hit")
		var item = _make_draw_item(0)
		item.runtime_id = 9000 + index
		action.item_instance = BackpackManager.ItemInstance.new(item, Vector2i(index, 0))
		actions.append(action)

	manager._apply_ornament_impact_chain_resolved(null, actions)

	assert_eq(gs.current_score, 16)

func test_terminal_pressure_gauge_counts_mechanical_hits_only():
	var manager = await _make_manager(["terminal_pressure_gauge"] as Array[String])
	var actions: Array[GameAction] = []
	for index in range(8):
		var action = GameAction.new(GameAction.Type.IMPACT, "hit")
		var item = _make_draw_item(0)
		item.tags = ["机械"] as Array[String]
		item.runtime_id = 9100 + index
		action.item_instance = BackpackManager.ItemInstance.new(item, Vector2i(index, 0))
		actions.append(action)

	manager._apply_ornament_impact_chain_resolved(null, actions)

	assert_eq(gs.current_score, 25)

func test_gear_oil_scores_successful_mechanical_transmissions_only():
	var manager = await _make_manager(["gear_oil"] as Array[String])
	var source_data = _make_draw_item(0)
	source_data.direction = ItemData.Direction.RIGHT
	var source = BackpackManager.ItemInstance.new(source_data, Vector2i(0, 1))

	var gear = item_db.get_item_by_id("small_gear")
	manager.backpack_manager.place_item(gear, Vector2i(1, 1))
	var first = manager.backpack_manager.grid[Vector2i(1, 1)]
	first.data.direction = ItemData.Direction.RIGHT

	var brake = item_db.get_item_by_id("brake_pad")
	manager.backpack_manager.place_item(brake, Vector2i(2, 1))

	var resolver = ImpactResolver.new(manager.backpack_manager, manager.context)
	var actions = resolver.resolve_impact(source.root_pos, ItemData.Direction.RIGHT, source)
	manager._apply_ornament_impact_chain_resolved(source, actions)

	assert_eq(gs.current_score, 2)

func test_gear_oil_ignores_mechanical_hits_without_transmission():
	var manager = await _make_manager(["gear_oil"] as Array[String])
	var source_data = _make_draw_item(0)
	source_data.direction = ItemData.Direction.RIGHT
	var source = BackpackManager.ItemInstance.new(source_data, Vector2i(0, 1))

	var gear = item_db.get_item_by_id("small_gear")
	manager.backpack_manager.place_item(gear, Vector2i(1, 1))
	var first = manager.backpack_manager.grid[Vector2i(1, 1)]
	first.data.direction = ItemData.Direction.DOWN

	var resolver = ImpactResolver.new(manager.backpack_manager, manager.context)
	var actions = resolver.resolve_impact(source.root_pos, ItemData.Direction.RIGHT, source)
	manager._apply_ornament_impact_chain_resolved(source, actions)

	assert_eq(gs.current_score, 0)

func test_universal_bearing_adds_bidirectional_transmission_inside_same_resolution():
	var manager = await _make_manager(["universal_bearing"] as Array[String])
	var source_data = _make_draw_item(0)
	source_data.direction = ItemData.Direction.RIGHT
	var source = BackpackManager.ItemInstance.new(source_data, Vector2i(0, 2))

	var gear = item_db.get_item_by_id("small_gear")
	manager.backpack_manager.place_item(gear, Vector2i(1, 2))
	var first = manager.backpack_manager.grid[Vector2i(1, 2)]
	first.data.direction = ItemData.Direction.RIGHT

	var upper = item_db.get_item_by_id("brake_pad")
	manager.backpack_manager.place_item(upper, Vector2i(1, 1))
	var lower = item_db.get_item_by_id("brake_pad")
	manager.backpack_manager.place_item(lower, Vector2i(1, 3))

	var resolver = ImpactResolver.new(manager.backpack_manager, manager.context)
	var actions = resolver.resolve_impact(source.root_pos, ItemData.Direction.RIGHT, source)
	var summary = resolver.get_current_resolution_summary()

	assert_eq(summary.mechanical_hit_count, 3)
	assert_eq(summary.bidirectional_transmission_count, 1)
	assert_eq(_impact_count(actions), 3)

func test_recoil_plate_queues_mechanical_filtered_recoil():
	var manager = await _make_manager(["recoil_plate"] as Array[String])
	var target_data = item_db.get_item_by_id("small_gear")
	manager.backpack_manager.place_item(target_data, Vector2i(2, 2))
	var target = manager.backpack_manager.grid[Vector2i(2, 2)]

	var action = GameAction.new(GameAction.Type.IMPACT, "hit")
	action.item_instance = target
	manager._apply_ornament_impact_chain_resolved(null, [action] as Array[GameAction])

	assert_eq(manager._impact_queue.size(), 1)
	assert_true(Array(manager._impact_queue[0].get("filters", [])).has("机械"))

func test_honey_spoon_only_counts_official_food_items():
	var manager = await _make_manager(["honey_spoon"] as Array[String])
	var leftover = item_db.get_item_by_id("leftover_box")
	var apple = item_db.get_item_by_id("apple")

	manager._apply_ornament_item_discarded(leftover, null, false)
	assert_eq(gs.current_score, 0)

	manager._apply_ornament_item_discarded(apple, null, false)
	assert_eq(gs.current_score, 4)

func test_seed_insurance_scores_when_seed_growth_cannot_fit():
	var manager = await _make_manager(["seed_insurance"] as Array[String])
	var seed = item_db.get_item_by_id("dream_seed_1x1")
	manager.backpack_manager.place_item(seed, Vector2i(5, 5))
	var instance = manager.backpack_manager.grid[Vector2i(5, 5)]
	instance.dream_seed_level = 9
	instance.data.set_meta("dream_seed_level", 9)

	manager.backpack_manager.upgrade_seed(instance, item_db, 1)

	assert_eq(gs.current_score, 8)
	assert_false(manager.backpack_manager.grid.has(Vector2i(5, 5)))

func _impact_count(actions: Array[GameAction]) -> int:
	var count = 0
	for action in actions:
		if action.type == GameAction.Type.IMPACT:
			count += 1
	return count

func test_recycling_coupon_discounts_next_item_after_first_item_purchase():
	var manager = autofree(RunManagerScript.new())
	manager.current_shards = 100
	manager.current_ornaments = ["recycling_coupon"] as Array[String]
	manager.current_deck = [] as Array[String]
	manager.is_run_active = true
	var offer = {"type": "item", "id": "paper_ball", "price": 10}

	assert_eq(manager.get_current_shop_offer_price(offer), 10)
	assert_true(manager.buy_shop_offer(offer))
	assert_eq(manager.current_shards, 90)
	assert_eq(manager.get_current_shop_offer_price(offer), 8)
	assert_true(manager.buy_shop_offer(offer))
	assert_eq(manager.current_shards, 82)
	assert_eq(manager.get_current_shop_offer_price(offer), 10)
