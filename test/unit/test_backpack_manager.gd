extends GutTest

var backpack: BackpackManager

func before_each():
	backpack = autofree(BackpackManager.new())
	backpack.setup_grid(5, 5)

func test_setup_grid():
	assert_eq(backpack.grid_width, 5)
	assert_eq(backpack.grid_height, 5)
	assert_eq(backpack.grid.size(), 0)

func test_can_place_item_out_of_bounds():
	var item = ItemData.new()
	var s: Array[Vector2i] = [Vector2i(0, 0)]
	item.shape = s
	
	assert_true(backpack.can_place_item(item, Vector2i(0, 0)), "Should place at 0,0")
	assert_false(backpack.can_place_item(item, Vector2i(-1, 0)), "Should not place at negative x")
	assert_false(backpack.can_place_item(item, Vector2i(5, 5)), "Should not place outside bounds")

func test_can_place_item_overlap():
	var item1 = ItemData.new()
	var s1: Array[Vector2i] = [Vector2i(0, 0)]
	item1.shape = s1
	backpack.place_item(item1, Vector2i(2, 2))
	
	var item2 = ItemData.new()
	var s2: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	item2.shape = s2
	
	assert_false(backpack.can_place_item(item2, Vector2i(1, 2)), "Should detect overlap")
	assert_true(backpack.can_place_item(item2, Vector2i(3, 2)), "Should place cleanly")

func test_place_item_creates_unique_instance():
	var item = ItemData.new()
	item.item_name = "Test Item"
	var s: Array[Vector2i] = [Vector2i(0, 0)]
	item.shape = s
	
	backpack.place_item(item, Vector2i(1, 1))
	var instance = backpack.grid[Vector2i(1, 1)]
	
	assert_ne(instance.data, item, "Data should be duplicated")
	assert_eq(instance.data.item_name, "Test Item")
	assert_eq(instance.current_pollution, 0)
	
	instance.add_pollution(5)
	assert_eq(instance.current_pollution, 5)

func test_get_next_item_pos():
	var item1 = ItemData.new()
	var s1: Array[Vector2i] = [Vector2i(0, 0)]
	item1.shape = s1
	backpack.place_item(item1, Vector2i(1, 1))
	
	var item2 = ItemData.new()
	var s2: Array[Vector2i] = [Vector2i(0, 0)]
	item2.shape = s2
	backpack.place_item(item2, Vector2i(4, 1))
	
	var next_pos = backpack.get_next_item_pos(Vector2i(1, 1), ItemData.Direction.RIGHT)
	assert_eq(next_pos, Vector2i(4, 1), "Should find item to the right")
	
	var no_pos = backpack.get_next_item_pos(Vector2i(4, 1), ItemData.Direction.RIGHT)
	assert_eq(no_pos, Vector2i(-1, -1), "Should not find anything")
