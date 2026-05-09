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

# --- 封口试管 (Sealed Tube) ---

func test_sealed_tube_absorption():
	var tube = item_db.get_item_by_id("sealed_tube")
	var paper = item_db.get_item_by_id("paper_ball")
	
	backpack.place_item(paper, Vector2i(0, 2))
	backpack.place_item(tube, Vector2i(1, 2))
	
	# 设置纸团有 9 层污染 (Multiplier = 10)
	backpack.grid[Vector2i(0, 2)].current_pollution = 9
	
	var resolver = ImpactResolver.new(backpack, context)
	# 纸团撞击试管
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	
	# 逻辑：试管被撞，虽倍率为 10，但效果脚本只增加 1 层污染。
	assert_eq(backpack.grid[Vector2i(1, 2)].current_pollution, 1, "Tube should only gain 1 poll regardless of multiplier")

func test_sealed_tube_interception():
	var tube = item_db.get_item_by_id("sealed_tube")
	var paper1 = item_db.get_item_by_id("paper_ball")
	var paper2 = item_db.get_item_by_id("paper_ball")
	
	backpack.place_item(paper1, Vector2i(0, 2))
	backpack.place_item(tube, Vector2i(1, 2))
	backpack.place_item(paper2, Vector2i(2, 2))
	
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	
	# 逻辑：
	# 1. Paper1 撞 Tube。
	# 2. Tube 吸收冲击 (TransmissionMode = NONE)。
	# 3. Paper2 应该毫发无损。
	assert_eq(backpack.grid[Vector2i(2, 2)].current_pollution, 0, "Item behind tube should be protected")
	assert_eq(backpack.grid[Vector2i(1, 2)].current_pollution, 1)
