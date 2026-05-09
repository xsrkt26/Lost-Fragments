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

# --- 伤心泰迪熊 (Sad Teddy Bear) ---
func test_teddy_bear_lonely():
	var teddy = item_db.get_item_by_id("sad_teddy_bear")
	backpack.place_item(teddy, Vector2i(1, 1))
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(1, 1), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 10)
	assert_eq(backpack.grid[Vector2i(1, 1)].current_pollution, 2, "Lonely")

# --- 小药瓶 (Pill Bottle) ---
func test_pill_bottle_distribution():
	var pill = item_db.get_item_by_id("pill_bottle")
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(pill, Vector2i(2, 2))
	backpack.place_item(paper, Vector2i(0, 0))
	backpack.grid[Vector2i(0, 0)].current_pollution = 5
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT))
	assert_eq(backpack.grid[Vector2i(0, 0)].current_pollution, 6)

# --- 过期药物 (Expired Medicine) ---
func test_expired_medicine_self_pollution():
	var med = item_db.get_item_by_id("expired_medicine")
	backpack.place_item(med, Vector2i(1, 1))
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(1, 1), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 5)
	assert_eq(backpack.grid[Vector2i(1, 1)].current_pollution, 3)

# --- 综合测试：泰迪熊与过期药物的循环 (Synergy) ---
func test_synergy_teddy_and_medicine():
	var med = item_db.get_item_by_id("expired_medicine")
	var teddy = item_db.get_item_by_id("sad_teddy_bear")
	backpack.place_item(med, Vector2i(0, 1)) # (0,1), (0,2)
	backpack.place_item(teddy, Vector2i(1, 1)) # (1,1), (2,1), (1,2), (2,2)
	backpack.grid[Vector2i(0, 1)].data.direction = ItemData.Direction.RIGHT
	var resolver = ImpactResolver.new(backpack, context)
	
	# 第一次：Med(0,1) -> Teddy(1,1). Score: 5 + 10 = 15. Med=3, Teddy=2(Lonely).
	_apply_actions(resolver.resolve_impact(Vector2i(0, 1), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 15)
	assert_eq(backpack.grid[Vector2i(0, 1)].current_pollution, 3)
	assert_eq(backpack.grid[Vector2i(1, 1)].current_pollution, 2)
	
	# 第二次：Med(3 poll, Multi=4) +5*4=20. Teddy(2 poll, Multi=3) +10*3=30.
	# 总分：15 + 20 + 30 = 65.
	_apply_actions(resolver.resolve_impact(Vector2i(0, 1), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 65)
