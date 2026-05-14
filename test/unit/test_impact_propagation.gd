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
	backpack.setup_grid(5, 5)
	
	context = GameContext.new(gs)
	
	var mock_battle = autofree(Node.new())
	mock_battle.set_script(preload("res://src/battle/battle_manager.gd"))
	mock_battle.backpack_manager = backpack
	mock_battle.context = context
	add_child(mock_battle)
	context.battle = mock_battle
	
	item_db = get_node_or_null("/root/ItemDatabase")

func _make_test_item(item_id: String) -> ItemData:
	var item = ItemData.new()
	item.id = item_id
	item.item_name = item_id
	item.can_draw = false
	item.base_cost = 0
	item.shape = [Vector2i(0, 0)] as Array[Vector2i]
	item.direction = ItemData.Direction.RIGHT
	item.transmission_mode = ItemData.TransmissionMode.NORMAL
	return item

## 测试：紧贴传导 (Adjacency)
func test_strictly_adjacent_propagation():
	var clock = item_db.get_item_by_id("alarm_clock")
	# 闹钟在 (1, 0)
	backpack.place_item(clock, Vector2i(1, 0))
	
	var resolver = ImpactResolver.new(backpack, context)
	# 模拟从 (1, 0) 本身发起向右撞击，应该撞不到东西 (因为右边 (2, 0) 为空)
	var inst_clock = backpack.grid[Vector2i(1, 0)]
	var actions = resolver.resolve_impact(Vector2i(1, 0), ItemData.Direction.RIGHT, inst_clock)
	
	var hit_anything = false
	for action in actions:
		if action.type == GameAction.Type.IMPACT:
			hit_anything = true
	
	assert_false(hit_anything, "Should not hit anything if neighbor is empty")

## 测试：从邻居发起撞击 (Hit from neighbor)
func test_hit_from_neighbor():
	var clock = item_db.get_item_by_id("alarm_clock")
	# 闹钟在 (1, 0)
	backpack.place_item(clock, Vector2i(1, 0))
	var inst_clock = backpack.grid[Vector2i(1, 0)]
	
	# 纸团在 (0, 0)，作为来源
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(paper, Vector2i(0, 0))
	var inst_paper = backpack.grid[Vector2i(0, 0)]
	
	var resolver = ImpactResolver.new(backpack, context)
	# 纸团 (0, 0) 向右撞击，应该撞到 (1, 0) 的闹钟
	var actions = resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT, inst_paper)
	
	var hit_clock = false
	for action in actions:
		if action.type == GameAction.Type.IMPACT and action.item_instance == inst_clock:
			hit_clock = true
	
	assert_true(hit_clock, "Neighbor should be hit")

## 测试：空位阻断 (Gap blocks propagation)
func test_gap_blocks_propagation():
	var clock = item_db.get_item_by_id("alarm_clock")
	# 闹钟在 (2, 0)，中间留一个空格 (1, 0)
	backpack.place_item(clock, Vector2i(2, 0))
	
	# 来源在 (0, 0)
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(paper, Vector2i(0, 0))
	var inst_paper = backpack.grid[Vector2i(0, 0)]
	
	var resolver = ImpactResolver.new(backpack, context)
	var actions = resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT, inst_paper)
	
	var hit_clock = false
	for action in actions:
		if action.type == GameAction.Type.IMPACT and action.item_instance.data.id == "alarm_clock":
			hit_clock = true
	
	assert_false(hit_clock, "Item with gap should NOT be hit")

## 测试：方向传导 (Same Direction)
func test_same_direction_propagation():
	var paper_ball = item_db.get_item_by_id("paper_ball")
	# 纸团1在 (0, 0)，方向向右
	backpack.place_item(paper_ball, Vector2i(0, 0))
	var inst1 = backpack.grid[Vector2i(0, 0)]
	inst1.data.direction = ItemData.Direction.RIGHT
	
	# 纸团2在 (1, 0)，方向向右
	backpack.place_item(paper_ball, Vector2i(1, 0))
	var inst2 = backpack.grid[Vector2i(1, 0)]
	inst2.data.direction = ItemData.Direction.RIGHT
	
	# 纸团3在 (2, 0)
	backpack.place_item(paper_ball, Vector2i(2, 0))
	var inst3 = backpack.grid[Vector2i(2, 0)]
	
	var resolver = ImpactResolver.new(backpack, context)
	# 纸团1 (0, 0) 发起撞击
	var actions = resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT, inst1)
	
	var hit_count = 0
	var hit_inst2 = false
	var hit_inst3 = false
	for action in actions:
		if action.type == GameAction.Type.IMPACT:
			hit_count += 1
			if action.item_instance == inst2: hit_inst2 = true
			if action.item_instance == inst3: hit_inst3 = true
	
	assert_eq(hit_count, 2, "Both neighbor and next item with same direction should be hit")
	assert_true(hit_inst2)
	assert_true(hit_inst3)

## 测试：不同方向阻断传导 (Different Direction blocks chain)
func test_different_direction_stops_chain():
	var paper_ball = item_db.get_item_by_id("paper_ball")
	# 纸团1在 (0, 0)，作为来源
	backpack.place_item(paper_ball, Vector2i(0, 0))
	var inst1 = backpack.grid[Vector2i(0, 0)]
	inst1.data.direction = ItemData.Direction.RIGHT
	
	# 纸团2在 (1, 0)，方向向 下 (阻断)
	backpack.place_item(paper_ball, Vector2i(1, 0))
	var inst2 = backpack.grid[Vector2i(1, 0)]
	inst2.data.direction = ItemData.Direction.DOWN
	
	# 纸团3在 (2, 0)
	backpack.place_item(paper_ball, Vector2i(2, 0))
	
	var resolver = ImpactResolver.new(backpack, context)
	var actions = resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT, inst1)
	
	var hit_count = 0
	var hit_paper2 = false
	var hit_paper3 = false
	for action in actions:
		if action.type == GameAction.Type.IMPACT:
			hit_count += 1
			if action.item_instance == inst2: hit_paper2 = true
			if action.item_instance.root_pos == Vector2i(2, 0): hit_paper3 = true
	
	assert_eq(hit_count, 1, "Only the first neighbor should be hit")
	assert_true(hit_paper2, "Neighbor should be hit")
	assert_false(hit_paper3, "Third item should NOT be hit because neighbor direction mismatched")

func test_same_item_is_hit_once_per_resolution_even_from_multiple_directions():
	var source_data = _make_test_item("virtual_source")
	source_data.direction = ItemData.Direction.UP
	var source_instance = BackpackManager.ItemInstance.new(source_data, Vector2i(1, 2))

	var omni = _make_test_item("omni")
	omni.transmission_mode = ItemData.TransmissionMode.OMNI
	assert_true(backpack.place_item(omni, Vector2i(1, 1)))

	var target = _make_test_item("l_target")
	target.transmission_mode = ItemData.TransmissionMode.NONE
	target.shape = [Vector2i(1, 0), Vector2i(0, 1)] as Array[Vector2i]
	assert_true(backpack.place_item(target, Vector2i(0, 0)))
	var target_instance = backpack.grid[Vector2i(1, 0)]

	var resolver = ImpactResolver.new(backpack, context)
	var actions = resolver.resolve_impact(source_instance.root_pos, ItemData.Direction.UP, source_instance)

	var target_hit_count = 0
	for action in actions:
		if action.type == GameAction.Type.IMPACT and action.item_instance == target_instance:
			target_hit_count += 1

	assert_eq(target_hit_count, 1)
	assert_eq(resolver.get_current_resolution_summary().hit_count, 2)

func test_resolution_summary_tracks_distinct_and_mechanical_hits():
	var source_data = _make_test_item("virtual_source")
	source_data.direction = ItemData.Direction.RIGHT
	var source_instance = BackpackManager.ItemInstance.new(source_data, Vector2i(0, 0))

	var first = _make_test_item("mechanical_one")
	first.tags = ["机械"] as Array[String]
	first.direction = ItemData.Direction.RIGHT
	assert_true(backpack.place_item(first, Vector2i(1, 0)))

	var second = _make_test_item("mechanical_two")
	second.tags = ["机械"] as Array[String]
	second.direction = ItemData.Direction.RIGHT
	assert_true(backpack.place_item(second, Vector2i(2, 0)))

	var resolver = ImpactResolver.new(backpack, context)
	resolver.resolve_impact(source_instance.root_pos, ItemData.Direction.RIGHT, source_instance)
	var summary = resolver.get_current_resolution_summary()

	assert_eq(summary.hit_count, 2)
	assert_eq(summary.mechanical_hit_count, 2)
	assert_eq(summary.turn_transmission_count, 0)
