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

# --- 针管 (Syringe) ---
func test_syringe_row_injection():
	var syringe = item_db.get_item_by_id("syringe")
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(syringe, Vector2i(0, 2))
	backpack.place_item(paper, Vector2i(3, 2)) 
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	# 逻辑：感染+1，传导撞击(Multiplier=2)再+2 = 3
	assert_eq(backpack.grid[Vector2i(3, 2)].current_pollution, 3)

# --- 剩饭盒 (Leftover Box) ---
func test_leftover_box_logic():
	var box = item_db.get_item_by_id("leftover_box") # 3x3
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(box, Vector2i(1, 1))
	backpack.place_item(paper, Vector2i(0, 1)) 
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(1, 1), ItemData.Direction.RIGHT))
	assert_eq(backpack.grid[Vector2i(0, 1)].current_pollution, 1)

# --- 潮湿纸箱 (Wet Cardboard Box) ---
func test_wet_cardboard_box_logic():
	var box = item_db.get_item_by_id("wet_cardboard_box") # 2x2
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(box, Vector2i(0, 0))
	backpack.place_item(paper, Vector2i(2, 0))
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT))
	# 渗水+3，传导(Multiplier=4)再+4 = 7
	assert_eq(backpack.grid[Vector2i(2, 0)].current_pollution, 7)

# --- 综合扩散链测试 (Mass Synergy - Fixed) ---
func test_synergy_pollution_spread_chain_fixed():
	var med = item_db.get_item_by_id("expired_medicine")
	var box = item_db.get_item_by_id("leftover_box")
	var paper = item_db.get_item_by_id("paper_ball")
	
	backpack.place_item(med, Vector2i(0, 0)) # (0,0),(0,1)
	backpack.place_item(box, Vector2i(1, 1)) # 3x3
	backpack.place_item(paper, Vector2i(4, 1)) # Box邻居
	
	backpack.grid[Vector2i(0,0)].data.direction = ItemData.Direction.RIGHT
	var resolver = ImpactResolver.new(backpack, context)
	
	# 击中药物，开始连锁
	_apply_actions(resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT))
	
	# 药物：撞击+3, 饭盒感染+1 = 4
	assert_eq(backpack.grid[Vector2i(0, 0)].current_pollution, 4)
	# 纸团：饭盒感染+1, 饭盒传导(Multi=2)再+2 = 3
	assert_eq(backpack.grid[Vector2i(4, 1)].current_pollution, 3)
