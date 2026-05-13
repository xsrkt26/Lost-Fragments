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

func test_rusty_gear_omni_transmission():
	var gear = item_db.get_item_by_id("rusty_gear")
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(gear, Vector2i(2, 2))
	backpack.place_item(paper, Vector2i(2, 1)) # UP
	backpack.place_item(paper, Vector2i(2, 3)) # DOWN
	backpack.place_item(paper, Vector2i(1, 2)) # LEFT
	backpack.place_item(paper, Vector2i(3, 2)) # RIGHT
	
	# Omni gear handles all directions
	var resolver = ImpactResolver.new(backpack, context)
	var actions = resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT)
	var hits = 0
	for a in actions:
		if a.type == GameAction.Type.IMPACT and a.item_instance != null: hits += 1
	assert_eq(hits, 5)

func test_rusty_gear_on_hit():
	var gear = item_db.get_item_by_id("rusty_gear")
	backpack.place_item(gear, Vector2i(2, 2))
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 2)

func test_rusty_gear_at_boundary():
	var gear = item_db.get_item_by_id("rusty_gear")
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(gear, Vector2i(0, 0))
	backpack.place_item(paper, Vector2i(1, 0)) # RIGHT
	backpack.place_item(paper, Vector2i(0, 1)) # DOWN
	var resolver = ImpactResolver.new(backpack, context)
	var actions = resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT)
	var hits = 0
	for a in actions:
		if a.type == GameAction.Type.IMPACT and a.item_instance != null: hits += 1
	assert_eq(hits, 3)

func test_large_gear_transmission():
	var lg = item_db.get_item_by_id("large_gear") # 2x2 OMNI
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(lg, Vector2i(1, 1))
	backpack.place_item(paper, Vector2i(3, 1)) # RIGHT. 2x2 at (1,1) neighbor is (3,1)
	var resolver = ImpactResolver.new(backpack, context)
	var actions = resolver.resolve_impact(Vector2i(1, 1), ItemData.Direction.RIGHT)
	var hit_paper = false
	for a in actions:
		if a.description.contains("纸团"): hit_paper = true
	assert_true(hit_paper)

func test_rusty_gear_mod_diffusion():
	var mod = item_db.get_item_by_id("rusty_gear_mod")
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(mod, Vector2i(2, 2))
	backpack.place_item(paper, Vector2i(3, 2))
	
	# 强制方向
	backpack.grid[Vector2i(2,2)].data.direction = ItemData.Direction.RIGHT
	
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT))
	assert_eq(backpack.grid[Vector2i(3, 2)].current_pollution, 3)

func test_trash_bag_purify():
	var bag = item_db.get_item_by_id("trash_bag")
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(bag, Vector2i(1, 1))
	backpack.place_item(paper, Vector2i(2, 1)) # 紧贴
	
	backpack.grid[Vector2i(1,1)].data.direction = ItemData.Direction.RIGHT
	
	backpack.grid[Vector2i(2, 1)].current_pollution = 10
	gs.current_sanity = 50
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(1, 1), ItemData.Direction.RIGHT))
	assert_eq(gs.current_sanity, 60)
	assert_eq(backpack.grid[Vector2i(2, 1)].current_pollution, 1)

func test_long_plank_logic():
	var plank = item_db.get_item_by_id("long_plank") # 1x3 RIGHT
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(plank, Vector2i(1, 1)) # (1,1), (2,1), (3,1)
	backpack.place_item(paper, Vector2i(4, 1)) # 紧贴
	
	backpack.grid[Vector2i(1,1)].data.direction = ItemData.Direction.RIGHT
	
	var resolver = ImpactResolver.new(backpack, context)
	var actions = resolver.resolve_impact(Vector2i(1, 1), ItemData.Direction.RIGHT)
	var hit_paper = false
	for a in actions:
		if a.description.contains("纸团"): hit_paper = true
	assert_true(hit_paper)
