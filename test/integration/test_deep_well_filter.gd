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
	backpack.setup_grid(10, 10)
	context = GameContext.new(gs)
	var mock_battle = autofree(Node.new())
	mock_battle.set_script(preload("res://src/battle/battle_manager.gd"))
	mock_battle.backpack_manager = backpack
	mock_battle.context = context
	add_child(mock_battle)
	context.battle = mock_battle
	item_db = get_node_or_null("/root/ItemDatabase")

func after_each():
	var bus = get_node_or_null("/root/GlobalEventBus")
	if bus:
		for sig in bus.get_signal_list():
			for conn in bus.get_signal_connection_list(sig.name):
				bus.disconnect(sig.name, conn.callable)
	if context and context.battle:
		context.battle.queue_free()

func _apply_actions(actions: Array[GameAction]):
	for action in actions:
		if action.type == GameAction.Type.NUMERIC:
			if action.value.type == "score":
				context.add_score(action.value.amount)
			elif action.value.type == "sanity":
				context.change_sanity(action.value.amount)

# --- 深井滤芯 (Deep Well Filter) ---

func test_filter_basic_conversion():
	var filter_data = item_db.get_item_by_id("deep_well_filter")
	var paper_data = item_db.get_item_by_id("paper_ball")
	
	backpack.place_item(filter_data, Vector2i(0, 2))
	backpack.place_item(paper_data, Vector2i(1, 2))
	
	# 设置初始层数
	backpack.grid[Vector2i(1, 2)].current_pollution = 5
	
	var resolver = ImpactResolver.new(backpack, context)
	# 启动撞击：击中滤芯
	# 物理逻辑：
	# 1. 滤芯 on_hit 触发：过滤 3 层。5 -> 2. 得分 30.
	# 2. 传导检查：滤芯 TransmissionMode 是 NONE。
	# 3. 解析器停止。纸团不应被击中。
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	
	assert_eq(backpack.grid[Vector2i(1, 2)].current_pollution, 2, "Pollution should be exactly 2 after filtering and NO transmission")
	assert_eq(gs.current_score, 30, "Should gain base 30 score")

func test_filter_small_amount():
	var filter_data = item_db.get_item_by_id("deep_well_filter")
	var paper_data = item_db.get_item_by_id("paper_ball")
	backpack.place_item(filter_data, Vector2i(0, 2))
	backpack.place_item(paper_data, Vector2i(1, 2))
	backpack.grid[Vector2i(1, 2)].current_pollution = 1
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	assert_eq(backpack.grid[Vector2i(1, 2)].current_pollution, 0)
	assert_eq(gs.current_score, 10)

func test_synergy_source_bottle_and_filter():
	var paper_data = item_db.get_item_by_id("paper_ball")
	var filter_data = item_db.get_item_by_id("deep_well_filter")
	backpack.place_item(paper_data, Vector2i(2, 2))
	backpack.place_item(filter_data, Vector2i(0, 2))
	
	# 设定：滤芯有 2 层(Multi=3)，纸团有 5 层
	backpack.grid[Vector2i(0, 2)].current_pollution = 2
	backpack.grid[Vector2i(2, 2)].current_pollution = 5
	
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	
	# 3层 * 10 * Multi(3) = 90.
	assert_eq(gs.current_score, 90)
	assert_eq(backpack.grid[Vector2i(2, 2)].current_pollution, 2)
