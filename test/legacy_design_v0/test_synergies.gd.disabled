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
	# 场景：双重触发器 (机械) -> 数学课本 (书籍) -> 纸团
	var double_trigger = item_db.get_item_by_id("large_gear") # 2x2 item
	# 手动赋予双重触发效果
	var effect = load("res://src/core/effects/double_trigger_effect.gd").new()
	var new_effects: Array[ItemEffect] = [effect]
	double_trigger.effects = new_effects
	
	var math_book = item_db.get_item_by_id("math_textbook")
	var paper = item_db.get_item_by_id("paper_ball")
	
	# Large Gear (2x2) at (0,0) occupies (0,0), (1,0), (0,1), (1,1)
	backpack.place_item(double_trigger, Vector2i(0, 0))
	backpack.place_item(math_book, Vector2i(2, 0)) # Adjacent to Gear's right side
	backpack.place_item(paper, Vector2i(3, 0)) # Adjacent to Book
	
	# 强制方向一致
	backpack.grid[Vector2i(0,0)].data.direction = ItemData.Direction.RIGHT
	backpack.grid[Vector2i(2,0)].data.direction = ItemData.Direction.RIGHT
	
	var resolver = ImpactResolver.new(backpack, context)
	# 击中双重触发器
	_apply_actions(resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT))
	
	# 逻辑：
	# 1. Gear 被撞，触发 DoubleTrigger (Multiplier=1). 它会执行 2 次传导。
	# 2. 传导 A: 击中 Math Book. Math Book 效果: 被撞, 向前撞击 1 次.
	# 3. 传导 A-1: Book 向前撞击纸团. 纸团得分 2.
	# 4. 传导 B: 再次击中 Math Book. Math Book 再次向前撞击纸团.
	# 5. 传导 B-1: 纸团再次得分 (此时 Multiplier 取决于污染，假设 0 污染则得分 2).
	# 总分取决于具体物品实现。这里确保传导通畅。
	assert_gt(gs.current_score, 0, "Should have triggered a chain")

func test_synergy_pollution_cascade():
	var pen = item_db.get_item_by_id("leaky_pen")
	var recycler = item_db.get_item_by_id("trash_recycler")
	var paper = item_db.get_item_by_id("paper_ball")
	
	backpack.place_item(pen, Vector2i(0, 2))
	backpack.place_item(paper, Vector2i(1, 2)) # 紧贴
	backpack.place_item(recycler, Vector2i(0, 3)) # 紧贴 pen 的下方
	
	# 强制方向
	backpack.grid[Vector2i(0,2)].data.direction = ItemData.Direction.RIGHT
	
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	
	assert_gt(backpack.grid[Vector2i(1, 2)].current_pollution, 0)

func test_stability_mirror_deadlock():
	var lens1 = item_db.get_item_by_id("cracked_lens")
	var lens2 = item_db.get_item_by_id("cracked_lens")
	backpack.place_item(lens1, Vector2i(1, 1))
	backpack.place_item(lens2, Vector2i(2, 1)) # 紧贴
	
	# 强制方向一致
	backpack.grid[Vector2i(1,1)].data.direction = ItemData.Direction.RIGHT
	
	var resolver = ImpactResolver.new(backpack, context)
	var inst1 = backpack.grid[Vector2i(1, 1)]
	var actions = resolver.resolve_impact(Vector2i(1, 1), ItemData.Direction.RIGHT, inst1)
	assert_not_null(actions)
