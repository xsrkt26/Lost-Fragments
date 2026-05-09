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

func test_synergy_book_and_machinery():
	# 线性传导：数学课本(0,0) -> 书籍齿轮(2,0) -> 英语课本(3,0)
	var math = item_db.get_item_by_id("math_textbook")
	var gear_orig = item_db.get_item_by_id("rusty_gear")
	var eng = item_db.get_item_by_id("english_book")
	var gear = gear_orig.duplicate()
	gear.tags.append("书籍")
	backpack.place_item(math, Vector2i(0, 0))
	backpack.place_item(gear, Vector2i(2, 0))
	backpack.place_item(eng, Vector2i(3, 0))
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT))
	
	# 推导：
	# 1. 初始撞击：齿轮被撞(2分) -> 传导英语课本(15分，因受到书籍齿轮撞击)
	# 2. 数学课本联动：再次撞击齿轮(2分) -> 齿轮再次传导英语课本(15分)
	# 总分 = (2 + 15) * 2 = 34
	assert_eq(gs.current_score, 34, "Double Trigger should amplify both self-hit and transmissions")

func test_synergy_pollution_cascade():
	var pen = item_db.get_item_by_id("leaky_pen")
	var paper = item_db.get_item_by_id("paper_ball")
	var recycler = item_db.get_item_by_id("trash_recycler")
	
	backpack.place_item(pen, Vector2i(0, 2))
	backpack.place_item(paper, Vector2i(1, 2))
	backpack.place_item(recycler, Vector2i(2, 0)) # 3x3, covers (2,0) to (4,2)
	
	backpack.grid[Vector2i(1,2)].add_pollution(5)
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	
	assert_eq(backpack.grid[Vector2i(1, 2)].current_pollution, 0, "Cascaded and cleaned")

func test_stability_mirror_deadlock():
	var lens1 = item_db.get_item_by_id("cracked_lens")
	var lens2 = item_db.get_item_by_id("cracked_lens")
	backpack.place_item(lens1, Vector2i(1, 1))
	backpack.place_item(lens2, Vector2i(2, 1))
	var resolver = ImpactResolver.new(backpack, context)
	assert_not_null(resolver.resolve_impact(Vector2i(1, 1), ItemData.Direction.RIGHT))
