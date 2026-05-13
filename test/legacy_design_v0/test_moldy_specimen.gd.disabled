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

# --- 发霉标本 (Moldy Specimen) ---

func test_specimen_organic_growth():
	var specimen_data = item_db.get_item_by_id("moldy_specimen") # 2x2
	var chicken_data = item_db.get_item_by_id("roast_chicken") # 2x2 tag 食物
	
	backpack.place_item(specimen_data, Vector2i(2, 2)) # (2,2)-(3,3)
	backpack.place_item(chicken_data, Vector2i(4, 2)) # (4,2)-(5,3)
	
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT))
	
	# Logic:
	# 1. Specimen hit. Finds Chicken neighbor.
	# 2. Growth: Specimen +3 pollution. Total 3. Multiplier 4.
	# 3. Infection: Chicken +4 pollution.
	# 4. ImpactResolver deduplication prevents second hit on specimen.
	var instance = backpack.grid[Vector2i(2, 2)]
	var chicken = backpack.grid[Vector2i(4, 2)]
	
	assert_eq(instance.current_pollution, 3, "Specimen grew by 3")
	assert_eq(chicken.current_pollution, 4, "Chicken infected by Multi(4)")

func test_specimen_multi_infection():
	var specimen_data = item_db.get_item_by_id("moldy_specimen")
	var paper_data = item_db.get_item_by_id("paper_ball")
	
	backpack.place_item(specimen_data, Vector2i(2, 2))
	backpack.place_item(paper_data, Vector2i(1, 2))
	backpack.place_item(paper_data, Vector2i(4, 2))
	
	var instance = backpack.grid[Vector2i(2, 2)]
	instance.current_pollution = 2 # Multi = 3
	
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT))
	
	# Logic:
	# 1. No food. Specimen remains 2. Multi 3.
	# 2. Both neighbors infected by 3.
	assert_eq(backpack.grid[Vector2i(1, 2)].current_pollution, 3)
	assert_eq(backpack.grid[Vector2i(4, 2)].current_pollution, 3)

func test_synergy_specimen_and_recycler():
	var specimen_data = item_db.get_item_by_id("moldy_specimen")
	var chicken_data = item_db.get_item_by_id("roast_chicken")
	var recycler_data = item_db.get_item_by_id("trash_recycler")
	
	backpack.place_item(chicken_data, Vector2i(0, 0))
	backpack.place_item(specimen_data, Vector2i(2, 0))
	backpack.place_item(recycler_data, Vector2i(5, 5))
	
	var resolver = ImpactResolver.new(backpack, context)
	
	# 1. Spread pollution
	_apply_actions(resolver.resolve_impact(Vector2i(2, 0), ItemData.Direction.RIGHT))
	# Specimen (2,0) root. Chicken (0,0) neighbor.
	# Specimen +3. Chicken +4.
	assert_eq(backpack.grid[Vector2i(2, 0)].current_pollution, 3)
	assert_eq(backpack.grid[Vector2i(0, 0)].current_pollution, 4)
	
	# 2. Cleanup
	_apply_actions(resolver.resolve_impact(Vector2i(5, 5), ItemData.Direction.RIGHT))
	assert_eq(backpack.grid[Vector2i(0, 0)].current_pollution, 0, "Cleanup successful")
