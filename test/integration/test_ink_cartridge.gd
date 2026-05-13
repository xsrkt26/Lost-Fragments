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

# --- 夜色墨盒 (Ink Cartridge) ---

func test_ink_cartridge_reactive_draw():
	var ink_data = item_db.get_item_by_id("ink_cartridge")
	backpack.place_item(ink_data, Vector2i(2, 2))
	var instance = backpack.grid[Vector2i(2, 2)]
	
	var battle = context.battle
	
	battle._process_new_item_acquisition(item_db.get_item_by_id("english_book"))
	assert_eq(instance.current_pollution, 1)
	
	battle._process_new_item_acquisition(item_db.get_item_by_id("paper_ball"))
	assert_eq(instance.current_pollution, 2)
	
	battle._process_new_item_acquisition(item_db.get_item_by_id("roast_chicken"))
	assert_eq(instance.current_pollution, 2)

func test_ink_cartridge_growth_value():
	var ink_data = item_db.get_item_by_id("ink_cartridge")
	backpack.place_item(ink_data, Vector2i(2, 2))
	var instance = backpack.grid[Vector2i(2, 2)]
	instance.current_pollution = 9 
	
	var resolver = ImpactResolver.new(backpack, context)
	# 直接点击
	_apply_actions(resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 20)

func test_synergy_funnel_and_cartridge():
	var funnel_data = item_db.get_item_by_id("waste_funnel")
	var ink_data = item_db.get_item_by_id("ink_cartridge")
	backpack.place_item(funnel_data, Vector2i(0, 2))
	backpack.place_item(ink_data, Vector2i(1, 2)) # 紧贴
	
	# 强制方向
	backpack.grid[Vector2i(0, 2)].data.direction = ItemData.Direction.RIGHT
	
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	assert_eq(backpack.grid[Vector2i(1, 2)].current_pollution, 3)
	
	context.battle._process_new_item_acquisition(item_db.get_item_by_id("english_book"))
	assert_eq(backpack.grid[Vector2i(1, 2)].current_pollution, 4)
