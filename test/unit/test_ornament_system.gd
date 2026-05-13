extends GutTest

const BattleManagerScript = preload("res://src/battle/battle_manager.gd")
const RunManagerScript = preload("res://src/autoload/run_manager.gd")

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

func test_ornament_database_loads_v1_1_table_and_filters_available_pool():
	var ornament_db = get_node_or_null("/root/OrnamentDatabase")
	assert_not_null(ornament_db)
	assert_eq(ornament_db.get_all_ornaments().size(), 50)
	assert_not_null(ornament_db.get_ornament_by_id("old_pocket_watch"))

	var act_one = ornament_db.get_available_ornaments(1, ["old_pocket_watch"] as Array[String])
	for ornament in act_one:
		assert_true(ornament.earliest_act <= 1)
		assert_true(ornament.id != "old_pocket_watch")

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
