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

func test_math_textbook_filtering():
	var math_book = item_db.get_item_by_id("math_textbook")
	var paper_ball = item_db.get_item_by_id("paper_ball")
	var eng_book = item_db.get_item_by_id("english_book")
	backpack.place_item(math_book, Vector2i(0, 0))
	backpack.place_item(paper_ball, Vector2i(2, 0))
	backpack.place_item(eng_book, Vector2i(4, 0))
	var resolver = ImpactResolver.new(backpack, context)
	var actions = resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT)
	var hit_paper = false
	var hit_eng = false
	for a in actions:
		if a.description.contains("纸团"): hit_paper = true
		if a.description.contains("英语课本"): hit_eng = true
	assert_false(hit_paper, "Math book should skip non-book item")
	assert_true(hit_eng, "Math book should hit the next book")

func test_english_book_normal_hit():
	var eng = item_db.get_item_by_id("english_book")
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(paper, Vector2i(0, 2))
	backpack.place_item(eng, Vector2i(2, 2))
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	# 纸团(2) + 英语课本(5) = 7
	assert_eq(gs.current_score, 7)

func test_english_book_bonus_hit():
	var ancient = item_db.get_item_by_id("ancient_book")
	var eng = item_db.get_item_by_id("english_book")
	backpack.place_item(ancient, Vector2i(0, 2))
	backpack.place_item(eng, Vector2i(2, 2))
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	# 古书(15) + 英语课本(15, 因受到书籍撞击) = 30
	assert_eq(gs.current_score, 30)

func test_ancient_book_decay():
	var book = item_db.get_item_by_id("ancient_book")
	backpack.place_item(book, Vector2i(2, 2))
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 15)
	_apply_actions(resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 15 + 14)
