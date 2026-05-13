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

# --- 废液漏斗 (Waste Funnel) ---

func test_funnel_basic_injection():
	var funnel = item_db.get_item_by_id("waste_funnel") # 1x3 RIGHT
	var p1 = item_db.get_item_by_id("paper_ball")
	var p2 = item_db.get_item_by_id("paper_ball")
	
	backpack.place_item(funnel, Vector2i(0, 2)) # (0,2)-(2,2)
	backpack.place_item(p1, Vector2i(3, 2))
	backpack.place_item(p2, Vector2i(4, 2))
	
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	
	# 逻辑推导：
	# 1. 漏斗灌注：P1=+1, P2=+1.
	# 2. 漏斗传导：击中 P1. P1(1层, Multi=2) 被撞自增 +2. P1=3.
	# 3. P1 传导：击中 P2. P2(1层, Multi=2) 被撞自增 +2. P2=3.
	assert_eq(backpack.grid[Vector2i(3, 2)].current_pollution, 3, "P1: 1(injected) + 2(hit) = 3")
	assert_eq(backpack.grid[Vector2i(4, 2)].current_pollution, 3, "P2: 1(injected) + 2(inherited hit) = 3")

func test_funnel_enrichment_effect():
	var funnel = item_db.get_item_by_id("waste_funnel")
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(funnel, Vector2i(0, 2))
	backpack.place_item(paper, Vector2i(3, 2))
	backpack.grid[Vector2i(3, 2)].current_pollution = 5
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	# 5 + 2(enrich) + 1*8(hit) = 15
	assert_eq(backpack.grid[Vector2i(3, 2)].current_pollution, 15)

func test_funnel_multiplier_amplification():
	var funnel = item_db.get_item_by_id("waste_funnel")
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(funnel, Vector2i(0, 2))
	backpack.place_item(paper, Vector2i(3, 2))
	backpack.grid[Vector2i(0, 2)].current_pollution = 1 # Multi=2
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	# 0 + 1*2(inj) + 1*3(hit) = 5
	assert_eq(backpack.grid[Vector2i(3, 2)].current_pollution, 5)

func test_synergy_funnel_and_sticky_note():
	var funnel = item_db.get_item_by_id("waste_funnel")
	var sticky = item_db.get_item_by_id("sticky_note")
	backpack.place_item(funnel, Vector2i(0, 2))
	backpack.place_item(sticky, Vector2i(3, 2))
	backpack.grid[Vector2i(0, 2)].current_pollution = 2 # Multi=3
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	# 1. 灌注 3 层。 2. 击中 Multi=4. 3. 结算 10*4 = 40.
	assert_eq(gs.current_score, 40)
	assert_eq(backpack.grid[Vector2i(3, 2)].current_pollution, 0)
