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

# --- 病历夹 (Medical Clipboard) ---

func test_clipboard_basic():
	var board = item_db.get_item_by_id("medical_clipboard")
	backpack.place_item(board, Vector2i(2, 2))
	var resolver = ImpactResolver.new(backpack, context)
	# 点击物品自身
	_apply_actions(resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 2)

func test_clipboard_global_bonus():
	var board = item_db.get_item_by_id("medical_clipboard")
	var paper1 = item_db.get_item_by_id("paper_ball")
	var paper2 = item_db.get_item_by_id("paper_ball")
	backpack.place_item(board, Vector2i(2, 2))
	backpack.place_item(paper1, Vector2i(0, 0))
	backpack.place_item(paper2, Vector2i(4, 4))
	backpack.grid[Vector2i(0, 0)].current_pollution = 5
	backpack.grid[Vector2i(4, 4)].current_pollution = 6 
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 7)

func test_clipboard_self_multiplier():
	var board = item_db.get_item_by_id("medical_clipboard")
	backpack.place_item(board, Vector2i(2, 2))
	backpack.grid[Vector2i(2, 2)].current_pollution = 3 # Multiplier = 4
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT))
	# (2 + 3/2) * 4 = 12
	assert_eq(gs.current_score, 12)

func test_synergy_math_book_to_clipboard():
	var math = item_db.get_item_by_id("math_textbook")
	var board = item_db.get_item_by_id("medical_clipboard")
	backpack.place_item(math, Vector2i(0, 1))
	backpack.place_item(board, Vector2i(2, 1))
	
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(paper, Vector2i(4, 4))
	backpack.grid[Vector2i(4, 4)].current_pollution = 10 
	
	var resolver = ImpactResolver.new(backpack, context)
	# 点击数学课本。它会传导给病历夹，并触发双重撞击。
	_apply_actions(resolver.resolve_impact(Vector2i(0, 1), ItemData.Direction.RIGHT))
	
	# 1. 正常撞击：7分
	# 2. 联动撞击：7分
	# 总分 = 14
	assert_eq(gs.current_score, 14, "Math book should trigger Clipboard twice")
