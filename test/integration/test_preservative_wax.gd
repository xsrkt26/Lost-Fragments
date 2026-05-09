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

# --- 防腐蜡 (Preservative Wax) ---

func test_wax_preserves_item():
	var wax = item_db.get_item_by_id("preservative_wax")
	var paper = item_db.get_item_by_id("paper_ball")
	
	backpack.place_item(wax, Vector2i(0, 2)) # Dir RIGHT
	backpack.place_item(paper, Vector2i(1, 2))
	
	var resolver = ImpactResolver.new(backpack, context)
	
	# 1. 触发防腐蜡 (直接点击蜡)
	# 物理流：蜡(on_hit: lock paper) -> 传导 -> 纸团(on_hit: add_poll)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	
	var paper_instance = backpack.grid[Vector2i(1, 2)]
	assert_true(paper_instance.is_preserved, "Paper should be preserved")
	
	# 逻辑：因为蜡在传导前就锁定了纸团，纸团被撞时的 add_pollution(1) 被忽略。
	assert_eq(paper_instance.current_pollution, 0, "Pollution should stay 0 as it was locked before the hit landed")
	
	# 2. 尝试手动增加污染 (模拟后续撞击)
	paper_instance.add_pollution(5)
	assert_eq(paper_instance.current_pollution, 0, "Still 0 after manual attempt")

func test_wax_prevents_cleaning():
	var wax = item_db.get_item_by_id("preservative_wax")
	var paper = item_db.get_item_by_id("paper_ball")
	var recycler = item_db.get_item_by_id("trash_recycler")
	
	backpack.place_item(wax, Vector2i(0, 0)) # Root (0,0)
	backpack.place_item(paper, Vector2i(1, 0)) # Root (1,0)
	backpack.place_item(recycler, Vector2i(0, 2)) # 3x3 at (0,2)-(2,4). OK for 5x5.
	
	var paper_instance = backpack.grid[Vector2i(1, 0)]
	paper_instance.current_pollution = 10
	
	var resolver = ImpactResolver.new(backpack, context)
	
	# 1. 蜡防腐纸团
	_apply_actions(resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT))
	assert_true(paper_instance.is_preserved)
	
	# 2. 回收器清场
	_apply_actions(resolver.resolve_impact(Vector2i(0, 2), ItemData.Direction.RIGHT))
	
	# 逻辑：即使全场大扫除，纸团层数也不应归零
	assert_eq(paper_instance.current_pollution, 10, "Preserved item's pollution is locked even during cleanup")
