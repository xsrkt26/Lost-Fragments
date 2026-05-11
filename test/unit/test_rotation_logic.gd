extends "res://addons/gut/test.gd"

var ItemData = load("res://src/core/item_data.gd")
var BackpackManager = load("res://src/core/data_models/backpack_mgr.gd")
var BattleManager = load("res://src/battle/battle_manager.gd")

class MockItemUI extends Control:
	var item_data: Resource
	var item_instance: Object
	func _play_rotate_tween(): pass

class MockBackpackUI extends Control:
	var item_ui_map = {}
	var grid_width = 5
	var grid_height = 5
	
	func setup(_context): pass
	
	func get_grid_pos_at(center_pos: Vector2) -> Vector2i:
		var grid_step = 68.0
		var res = Vector2i(floori(center_pos.x / grid_step), floori(center_pos.y / grid_step))
		if res.x < 0 or res.x >= grid_width or res.y < 0 or res.y >= grid_height:
			return Vector2i(-1, -1)
		return res
		
	func add_item_visual(_item_ui, _pos): pass
	func update_item_mapping(_old, _new): pass

func test_item_data_rotation_normalization_1x2():
	var item = ItemData.new()
	item.item_name = "Tin Can"
	item.shape = [Vector2i(0, 0), Vector2i(0, 1)] as Array[Vector2i]
	item.direction = ItemData.Direction.UP
	
	item.rotate_90()
	
	assert_eq(item.direction, ItemData.Direction.RIGHT)
	assert_true(item.shape.has(Vector2i(0, 0)))
	assert_true(item.shape.has(Vector2i(1, 0)))
	assert_eq(item.shape.size(), 2)

func test_item_data_rotation_square_no_shape_change():
	var item = ItemData.new()
	item.item_name = "Box"
	item.shape = [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)] as Array[Vector2i]
	item.direction = ItemData.Direction.UP
	
	var old_shape = item.shape.duplicate()
	item.rotate_90()
	
	assert_eq(item.direction, ItemData.Direction.RIGHT)
	assert_eq(item.shape, old_shape)

func test_backpack_remove_by_runtime_id():
	var manager = autofree(BackpackManager.new())
	manager.setup_grid(5, 5)
	
	var item = ItemData.new()
	item.runtime_id = 12345
	item.shape = [Vector2i(0, 0), Vector2i(0, 1)] as Array[Vector2i]
	
	manager.place_item(item, Vector2i(0, 0))
	assert_true(manager.grid.has(Vector2i(0, 0)))
	
	manager.remove_by_runtime_id(12345)
	assert_false(manager.grid.has(Vector2i(0, 0)))

func test_rotation_success_mid_grid_1x3():
	# 场景：1x3 横向在 (1,1)，点中 (2,1) 旋转
	var manager = autofree(BattleManager.new())
	add_child(manager)
	manager.backpack_manager.setup_grid(5, 5)
	var mock_bp_ui = autofree(MockBackpackUI.new())
	add_child(mock_bp_ui)
	manager.backpack_ui = mock_bp_ui
	
	var plank = ItemData.new(); plank.runtime_id = 201
	plank.shape = [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)] as Array[Vector2i]
	manager.backpack_manager.place_item(plank, Vector2i(1, 1))
	
	var rotated_data = manager.backpack_manager.grid[Vector2i(1,1)].data
	rotated_data.rotate_90()
	
	var mock_ui = autofree(MockItemUI.new())
	mock_ui.item_data = rotated_data
	
	# 以 (2,1) 为轴旋转：新 root 应在 (2,0)
	# (2,0) 中心 = (170, 34)
	manager.request_rotate_item(mock_ui, Vector2(170, 34), Vector2(136, 0))
	
	assert_not_null(mock_ui.item_instance)
	assert_eq(manager.backpack_manager.grid[Vector2i(2,0)].root_pos, Vector2i(2, 0))

func test_rotation_failure_right_edge():
	# 场景：1x2 竖放在 (4,0)，右旋出界
	var manager = autofree(BattleManager.new())
	add_child(manager)
	manager.backpack_manager.setup_grid(5, 5)
	manager.backpack_ui = autofree(MockBackpackUI.new())
	add_child(manager.backpack_ui)
	
	var can = ItemData.new(); can.runtime_id = 301
	can.shape = [Vector2i(0,0), Vector2i(0,1)] as Array[Vector2i]
	manager.backpack_manager.place_item(can, Vector2i(4, 0))
	
	var data = manager.backpack_manager.grid[Vector2i(4,0)].data
	data.rotate_90()
	
	var mock_ui = autofree(MockItemUI.new())
	mock_ui.item_data = data
	# 以 (4,0) 为轴旋转 -> 尝试占用 (4,0), (5,0)
	manager.request_rotate_item(mock_ui, Vector2(306, 34), Vector2(272, 0))
	
	assert_null(mock_ui.item_instance, "Should pop out at edge")

func test_rotation_failure_collision():
	# 场景：(2,1) 有障碍，(1,1) 处 1x2 旋转撞击它
	var manager = autofree(BattleManager.new())
	add_child(manager)
	manager.backpack_manager.setup_grid(5, 5)
	manager.backpack_ui = autofree(MockBackpackUI.new())
	add_child(manager.backpack_ui)
	
	var obstacle = ItemData.new(); obstacle.runtime_id = 999; obstacle.shape = [Vector2i(0,0)] as Array[Vector2i]
	manager.backpack_manager.place_item(obstacle, Vector2i(2, 1))
	
	var can = ItemData.new(); can.runtime_id = 401; can.shape = [Vector2i(0,0), Vector2i(0,1)] as Array[Vector2i]
	manager.backpack_manager.place_item(can, Vector2i(1, 1))
	
	var data = manager.backpack_manager.grid[Vector2i(1,1)].data
	data.rotate_90()
	
	var mock_ui = autofree(MockItemUI.new())
	mock_ui.item_data = data
	# 尝试占用 (1,1), (2,1) -> 撞到 obstacle
	manager.request_rotate_item(mock_ui, Vector2(102, 102), Vector2(68, 68))
	
	assert_null(mock_ui.item_instance, "Should pop out due to collision")

func test_rotation_360_degree_stability():
	var item = ItemData.new()
	item.shape = [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)] as Array[Vector2i]
	for i in range(4):
		item.rotate_90()
	assert_eq(item.shape, [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)] as Array[Vector2i], "360 rotation should return to original normalized shape")
