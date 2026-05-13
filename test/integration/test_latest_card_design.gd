extends GutTest

var gs
var backpack: BackpackManager
var context: GameContext
var item_db

func before_each():
	gs = autofree(Node.new())
	gs.set_script(preload("res://src/autoload/game_state.gd"))
	add_child(gs)
	gs.reset_game()

	backpack = autofree(BackpackManager.new())
	backpack.setup_grid(7, 7, 7, 7)
	context = GameContext.new(gs)
	item_db = get_node_or_null("/root/ItemDatabase")
	item_db.load_all_items()

func _apply_actions(actions: Array[GameAction]):
	for action in actions:
		if action.type == GameAction.Type.NUMERIC:
			if action.value.type == "score":
				context.add_score(action.value.amount)
			elif action.value.type == "sanity":
				context.change_sanity(action.value.amount)

func test_loaded_items_match_latest_design_list():
	var expected_ids = [
		"alarm_clock", "apple", "apple_core", "baseball", "cracked_lens",
		"dream_seed_1x1", "dream_seed_2x2", "dream_seed_3x3", "dream_seed_4x4", "dream_seed_5x5",
		"expired_medicine", "gift_box", "insurance_contract", "isolation_box", "joker",
		"leaky_pen", "leftover_box", "mineral_water_bottle", "old_soccer_ball", "paper_ball",
		"pill_bottle", "roast_chicken", "root_dream", "rusty_gear", "sad_teddy_bear",
		"sticky_note", "syringe", "tin_can", "trash_bag", "trash_recycler", "wet_cardboard_box"
	]
	expected_ids.sort()

	var actual_ids = item_db.items.keys()
	actual_ids.sort()

	assert_eq(actual_ids, expected_ids)

func test_pollution_additions_are_not_multiplied_by_existing_pollution():
	var source = item_db.get_item_by_id("baseball")
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(source, Vector2i(0, 0))
	backpack.place_item(paper, Vector2i(1, 0))

	var source_instance = backpack.grid[Vector2i(0, 0)]
	var paper_instance = backpack.grid[Vector2i(1, 0)]
	paper_instance.current_pollution = 4

	var resolver = ImpactResolver.new(backpack, context)
	var actions = resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT, source_instance)
	_apply_actions(actions)

	assert_eq(paper_instance.current_pollution, 5)
	assert_eq(gs.current_score, 10)

func test_sticky_note_scores_when_pollution_crosses_three_layers():
	var sticky = item_db.get_item_by_id("sticky_note")
	backpack.place_item(sticky, Vector2i(0, 0))
	var sticky_instance = backpack.grid[Vector2i(0, 0)]

	var resolver = ImpactResolver.new(backpack, context)
	resolver.add_pollution(sticky_instance, 3)
	_apply_actions(resolver.actions_history)

	assert_eq(sticky_instance.current_pollution, 3)
	assert_eq(gs.current_score, 10)

func test_isolation_box_reduces_pollution_sanity_loss():
	var source = item_db.get_item_by_id("baseball")
	var paper = item_db.get_item_by_id("paper_ball")
	var isolation = item_db.get_item_by_id("isolation_box")
	backpack.place_item(source, Vector2i(0, 0))
	backpack.place_item(paper, Vector2i(1, 0))
	backpack.place_item(isolation, Vector2i(3, 3))

	var source_instance = backpack.grid[Vector2i(0, 0)]
	var paper_instance = backpack.grid[Vector2i(1, 0)]
	paper_instance.current_pollution = 3

	var resolver = ImpactResolver.new(backpack, context)
	var actions = resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT, source_instance)
	_apply_actions(actions)

	assert_eq(gs.current_sanity, 98)

func test_leaky_pen_only_pollutes_if_next_item_is_waste():
	var source = item_db.get_item_by_id("baseball")
	var pen = item_db.get_item_by_id("leaky_pen")
	var blocker = item_db.get_item_by_id("apple")
	var waste = item_db.get_item_by_id("paper_ball")
	backpack.place_item(source, Vector2i(0, 0))
	backpack.place_item(pen, Vector2i(1, 0))
	backpack.place_item(blocker, Vector2i(3, 0))
	backpack.place_item(waste, Vector2i(4, 0))

	var source_instance = backpack.grid[Vector2i(0, 0)]
	var blocker_instance = backpack.grid[Vector2i(3, 0)]
	var waste_instance = backpack.grid[Vector2i(4, 0)]
	blocker_instance.data.direction = ItemData.Direction.DOWN

	var resolver = ImpactResolver.new(backpack, context)
	var actions = resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT, source_instance)
	_apply_actions(actions)

	assert_eq(blocker_instance.current_pollution, 0)
	assert_eq(waste_instance.current_pollution, 0)

func test_wet_cardboard_box_uses_whole_shape_to_find_next_item():
	var source = item_db.get_item_by_id("baseball")
	var cardboard = item_db.get_item_by_id("wet_cardboard_box")
	var target = item_db.get_item_by_id("apple")
	backpack.place_item(source, Vector2i(0, 0))
	backpack.place_item(cardboard, Vector2i(1, 0))
	backpack.place_item(target, Vector2i(3, 1))

	var source_instance = backpack.grid[Vector2i(0, 0)]
	var target_instance = backpack.grid[Vector2i(3, 1)]

	var resolver = ImpactResolver.new(backpack, context)
	var actions = resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT, source_instance)
	_apply_actions(actions)

	assert_eq(target_instance.current_pollution, 3)
