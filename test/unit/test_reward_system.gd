extends GutTest

const RewardGeneratorScript = preload("res://src/core/rewards/reward_generator.gd")
const RunManagerScript = preload("res://src/autoload/run_manager.gd")

var item_db
var ornament_db

func before_each():
	item_db = get_node_or_null("/root/ItemDatabase")
	ornament_db = get_node_or_null("/root/OrnamentDatabase")
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()
	if ornament_db and ornament_db.ornaments.is_empty():
		ornament_db.load_all_ornaments()

func _make_run_manager(act: int, route_index: int):
	var rm = autofree(RunManagerScript.new())
	rm.current_act = act
	rm.current_route_index = route_index
	rm.current_ornaments = [] as Array[String]
	rm.current_deck = [] as Array[String]
	rm.is_run_active = true
	return rm

func test_normal_battle_rewards_include_item_ornament_and_shards():
	var rm = _make_run_manager(1, 0)

	var options = RewardGeneratorScript.generate_options(rm, item_db, ornament_db, 3)
	var types = options.map(func(reward): return reward.get("type", ""))

	assert_eq(options.size(), 3)
	assert_true(types.has("item"))
	assert_true(types.has("ornament"))
	assert_true(types.has("shards"))

func test_boss_rewards_prioritize_rare_ornaments_when_available():
	var rm = _make_run_manager(4, 6)

	var options = RewardGeneratorScript.generate_options(rm, item_db, ornament_db, 3)

	assert_eq(options[0].get("type"), "ornament")
	assert_eq(options[0].get("rarity"), "稀有")

func test_apply_reward_updates_long_term_state_and_blocks_duplicate_ornaments():
	var rm = _make_run_manager(1, 0)
	rm.current_shards = 0

	assert_true(rm.apply_reward({"type": "shards", "amount": 9}))
	assert_eq(rm.current_shards, 9)

	assert_true(rm.apply_reward({"type": "item", "id": "paper_ball"}))
	assert_eq(rm.current_deck, ["paper_ball"])

	assert_true(rm.apply_reward({"type": "ornament", "id": "old_pocket_watch"}))
	assert_false(rm.apply_reward({"type": "ornament", "id": "old_pocket_watch"}))
	assert_eq(rm.current_ornaments, ["old_pocket_watch"])
