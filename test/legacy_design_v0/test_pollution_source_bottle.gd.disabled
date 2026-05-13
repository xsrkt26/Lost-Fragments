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

func test_source_bottle_global_stacking():
	var bottle = item_db.get_item_by_id("pollution_source_bottle")
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(bottle, Vector2i(4, 4))
	backpack.place_item(paper, Vector2i(0, 0))
	backpack.grid[Vector2i(0, 0)].current_pollution = 5
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(4, 4), ItemData.Direction.LEFT))
	# Activation triggers ONCE for the root hit. No return hit since paper is far.
	assert_eq(backpack.grid[Vector2i(0, 0)].current_pollution, 6)

func test_source_bottle_long_chain_bonus():
	var paper_data = item_db.get_item_by_id("paper_ball")
	var bottle_data = item_db.get_item_by_id("pollution_source_bottle")
	for i in range(5):
		backpack.place_item(paper_data, Vector2i(i, 2))
		backpack.grid[Vector2i(i, 2)].current_pollution = 1
		# 强制方向一致
		backpack.grid[Vector2i(i, 2)].data.direction = ItemData.Direction.RIGHT
	backpack.place_item(bottle_data, Vector2i(5, 2))
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	# 纸团 5x4 = 20. 瓶子奖励 20. 总 40.
	assert_eq(gs.current_score, 40)

func test_synergy_source_and_recycler():
	var bottle = item_db.get_item_by_id("pollution_source_bottle")
	var paper = item_db.get_item_by_id("paper_ball")
	var recycler = item_db.get_item_by_id("trash_recycler")
	# 纸团放在 (1, 0)，瓶子放在 (0, 0)，撞击向右
	backpack.place_item(paper, Vector2i(1, 0))
	backpack.place_item(bottle, Vector2i(0, 0))
	backpack.place_item(recycler, Vector2i(4, 4))
	
	# 强制方向一致以允许传导
	backpack.grid[Vector2i(0, 0)].data.direction = ItemData.Direction.RIGHT
	
	backpack.grid[Vector2i(1, 0)].current_pollution = 5
	var resolver = ImpactResolver.new(backpack, context)
	# 击中瓶子 (0,0) -> 传导至纸团 (1,0)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT))
	
	# 瓶子全局 +1 -> 纸团变为 6
	# 纸团被击中 -> Multi=7 -> 自增 7 -> 总 13.
	assert_eq(backpack.grid[Vector2i(1, 0)].current_pollution, 13)
	
	_apply_actions(resolver.resolve_impact(Vector2i(4, 4), ItemData.Direction.RIGHT))
	assert_eq(backpack.grid[Vector2i(1, 0)].current_pollution, 0)
