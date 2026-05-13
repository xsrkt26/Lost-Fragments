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
	assert_eq(upgraded.data.id, "dream_seed_2x2")
	assert_true(upgraded.data.tags.has("衍生物品"))

func test_seed_upgrade_rolls_back_when_larger_shape_does_not_fit():
	var seed_data: ItemData = item_db.get_item_by_id("dream_seed_1x1")
	backpack.place_item(seed_data, Vector2i(5, 5))
	var seed = backpack.grid[Vector2i(5, 5)]

	var result = backpack.upgrade_seed(seed, item_db)

	assert_eq(result.data.id, "dream_seed_1x1")
	assert_true(backpack.grid.has(Vector2i(5, 5)))
	assert_eq(backpack.grid[Vector2i(5, 5)].data.id, "dream_seed_1x1")
