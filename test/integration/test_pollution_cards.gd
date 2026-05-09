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

func test_paper_ball_and_leaky_pen():
	var paper = load("res://data/items/paper_ball.tres")
	var pen = load("res://data/items/leaky_pen.tres")
	backpack.place_item(pen, Vector2i(0, 0))
	backpack.place_item(paper, Vector2i(2, 0))
	var resolver = ImpactResolver.new(backpack, context)
	# 钢笔被撞: +3分(Pen) + 4分(Paper被倍化) = 7
	_apply_actions(resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 7)

func test_trash_recycler_extreme_pollution():
	var recycler = load("res://data/items/trash_recycler.tres")
	var paper = load("res://data/items/paper_ball.tres")
	backpack.place_item(recycler, Vector2i(2, 0))
	backpack.place_item(paper, Vector2i(0, 0))
	backpack.grid[Vector2i(0, 0)].current_pollution = 100
	var resolver = ImpactResolver.new(backpack, context)
	# 纸团被撞: 2*101 = 202. 回收器被撞: 25 + 201*25 = 5050.
	# 总分 = 5252
	_apply_actions(resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 5252)
