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

# --- 污水泵 (Sewage Pump) ---

class SpyBattleManager extends BattleManager:
	var triggered_at = []
	func trigger_impact_at(pos: Vector2i):
		triggered_at.append(pos)

func test_sewage_pump_interval_trigger():
	var pump_data = item_db.get_item_by_id("sewage_pump")
	var dummy = item_db.get_item_by_id("joker")
	
	backpack.place_item(pump_data, Vector2i(2, 2))
	var instance = backpack.grid[Vector2i(2, 2)]
	instance.current_pollution = 1 # 满足污染条件
	
	var spy_battle = SpyBattleManager.new()
	add_child(spy_battle)
	spy_battle.backpack_manager = backpack
	spy_battle.context = context
	context.battle = spy_battle
	
	# Draw 1
	spy_battle._process_new_item_acquisition(dummy)
	assert_eq(spy_battle.triggered_at.size(), 0, "No trigger at draw 1")
	
	# Draw 2
	spy_battle._process_new_item_acquisition(dummy)
	assert_eq(spy_battle.triggered_at.size(), 0, "No trigger at draw 2")
	
	# Draw 3
	spy_battle._process_new_item_acquisition(dummy)
	await get_tree().process_frame # 等待 call_deferred
	
	assert_eq(spy_battle.triggered_at.size(), 1, "Triggered at draw 3")
	assert_true(spy_battle.triggered_at.has(Vector2i(2, 2)))
	
	spy_battle.queue_free()

func test_sewage_pump_no_pollution_no_trigger():
	var pump_data = item_db.get_item_by_id("sewage_pump")
	var dummy = item_db.get_item_by_id("joker")
	
	backpack.place_item(pump_data, Vector2i(2, 2))
	# instance.current_pollution = 0 # 默认 0
	
	var spy_battle = SpyBattleManager.new()
	add_child(spy_battle)
	spy_battle.backpack_manager = backpack
	spy_battle.context = context
	context.battle = spy_battle
	
	# 设置 draw_count 准备进入第 3 次
	spy_battle.draw_count = 2
	
	# Draw 3
	spy_battle._process_new_item_acquisition(dummy)
	await get_tree().process_frame
	
	assert_eq(spy_battle.triggered_at.size(), 0, "Should NOT trigger without pollution")
	
	spy_battle.queue_free()

# --- 综合协同：纸箱灌注与水泵自动触发 ---
func test_synergy_box_and_pump():
	var box_data = item_db.get_item_by_id("wet_cardboard_box")
	var pump_data = item_db.get_item_by_id("sewage_pump")
	var dummy = item_db.get_item_by_id("joker")
	
	# 纸箱 (0,2) 向右渗水。水泵放在 (2,2) 
	backpack.place_item(box_data, Vector2i(0, 2))
	backpack.place_item(pump_data, Vector2i(2, 2))
	
	var spy_battle = SpyBattleManager.new()
	add_child(spy_battle)
	spy_battle.backpack_manager = backpack
	spy_battle.context = context
	context.battle = spy_battle
	
	# 1. 发起撞击。纸箱使水泵 +3 污染。
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	
	# 逻辑：水泵只得到渗水的 3 层。它被撞时不会自增（因为它没绑定自增效果）。
	assert_eq(backpack.grid[Vector2i(2, 2)].current_pollution, 3, "Pump got 3 poll from leakage")
	
	# 2. 连续抽卡。直到达到触发间隔。
	spy_battle.draw_count = 2
	spy_battle._process_new_item_acquisition(dummy) # 这是第 3 次
	await get_tree().process_frame
	
	assert_true(spy_battle.triggered_at.has(Vector2i(2, 2)), "Pump should automatically trigger")
	
	spy_battle.queue_free()
