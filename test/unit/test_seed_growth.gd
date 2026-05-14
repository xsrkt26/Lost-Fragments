extends GutTest

var backpack: BackpackManager
var item_db

func before_each():
	backpack = autofree(BackpackManager.new())
	backpack.setup_grid(7, 7, 5, 5)
	item_db = get_node_or_null("/root/ItemDatabase")
	if item_db and item_db.items.is_empty():
		item_db.load_all_items()

func test_sow_seed_creates_derived_level_one_seed_in_first_empty_cell():
	var source_data: ItemData = item_db.get_item_by_id("paper_ball")
	backpack.place_item(source_data, Vector2i(2, 2))
	var source = backpack.grid[Vector2i(2, 2)]

	var seed = backpack.sow_seed(source, ItemData.Direction.RIGHT, item_db)

	assert_not_null(seed)
	assert_eq(seed.root_pos, Vector2i(3, 2))
	assert_eq(seed.data.id, "dream_seed_1x1")
	assert_true(seed.data.tags.has("衍生物品"))

func test_sow_seed_on_existing_seed_upgrades_it():
	var source_data: ItemData = item_db.get_item_by_id("paper_ball")
	backpack.place_item(source_data, Vector2i(2, 2))
	var source = backpack.grid[Vector2i(2, 2)]
	var seed = backpack.sow_seed(source, ItemData.Direction.RIGHT, item_db)

	var upgraded = backpack.sow_seed(source, ItemData.Direction.RIGHT, item_db)

	assert_not_null(upgraded)
	assert_eq(upgraded.root_pos, seed.root_pos)
	assert_eq(upgraded.data.id, "dream_seed_1x1")
	assert_eq(upgraded.dream_seed_level, 2)
	assert_true(upgraded.data.tags.has("衍生物品"))

func test_seed_upgrade_changes_shape_at_level_ten():
	var seed_data: ItemData = item_db.get_item_by_id("dream_seed_1x1")
	backpack.place_item(seed_data, Vector2i(2, 2))
	var seed = backpack.grid[Vector2i(2, 2)]
	seed.dream_seed_level = 9
	seed.data.set_meta("dream_seed_level", 9)

	var result = backpack.upgrade_seed(seed, item_db)

	assert_eq(result.data.id, "dream_seed_2x2")
	assert_eq(result.dream_seed_level, 10)
	assert_true(backpack.grid.has(Vector2i(3, 3)))

func test_seed_upgrade_drops_out_when_larger_shape_does_not_fit():
	var seed_data: ItemData = item_db.get_item_by_id("dream_seed_1x1")
	backpack.place_item(seed_data, Vector2i(5, 5))
	var seed = backpack.grid[Vector2i(5, 5)]
	seed.dream_seed_level = 9
	seed.data.set_meta("dream_seed_level", 9)

	var result = backpack.upgrade_seed(seed, item_db)

	assert_eq(result.data.id, "dream_seed_2x2")
	assert_eq(result.dream_seed_level, 10)
	assert_false(backpack.grid.has(Vector2i(5, 5)))

func test_seed_does_not_grow_beyond_four_by_four_after_level_thirty():
	var seed_data: ItemData = item_db.get_item_by_id("dream_seed_4x4")
	backpack.place_item(seed_data, Vector2i(1, 1))
	var seed = backpack.grid[Vector2i(1, 1)]

	var result = backpack.upgrade_seed(seed, item_db)

	assert_eq(result.data.id, "dream_seed_4x4")
	assert_eq(result.dream_seed_level, 31)

func test_seed_scores_from_current_level_and_stage_when_hit():
	var gs = autofree(Node.new())
	add_child(gs)
	var source_data: ItemData = item_db.get_item_by_id("baseball")
	backpack.place_item(source_data, Vector2i(1, 1))
	var source = backpack.grid[Vector2i(1, 1)]

	var seed_data: ItemData = item_db.get_item_by_id("dream_seed_2x2")
	backpack.place_item(seed_data, Vector2i(2, 1))
	var seed = backpack.grid[Vector2i(2, 1)]
	seed.dream_seed_level = 12
	seed.data.set_meta("dream_seed_level", 12)

	var context = GameContext.new(gs)
	var resolver = ImpactResolver.new(backpack, context)
	var actions = resolver.resolve_impact(source.root_pos, ItemData.Direction.RIGHT, source)

	var score = 0
	for action in actions:
		if action.type == GameAction.Type.NUMERIC and action.value.type == "score":
			score += int(action.value.amount)

	assert_eq(score, 24)
