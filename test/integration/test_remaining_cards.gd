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

# --- 小丑鼻子 (Clown Nose) ---
class SpyBattle extends BattleManager:
	var triggered_pos = []
	func trigger_impact_at(pos: Vector2i):
		triggered_pos.append(pos)

func test_clown_nose_reactive():
	var nose_data = item_db.get_item_by_id("clown_nose")
	var trash_data = item_db.get_item_by_id("paper_ball")
	
	backpack.place_item(nose_data, Vector2i(2, 2))
	
	var spy_battle = SpyBattle.new()
	add_child(spy_battle)
	spy_battle.backpack_manager = backpack
	spy_battle.context = context
	context.battle = spy_battle
	
	# 模拟抽到废弃物
	spy_battle._process_new_item_acquisition(trash_data)
	await get_tree().process_frame
	
	assert_true(spy_battle.triggered_pos.has(Vector2i(2, 2)), "Clown nose should trigger on Trash draw")
	spy_battle.queue_free()

# --- 隔离箱 (Isolation Box) ---
func test_isolation_box_passive():
	var box_data = item_db.get_item_by_id("isolation_box")
	var paper_data = item_db.get_item_by_id("paper_ball")
	
	# 模拟放置隔离箱 (触发 on_equip)
	backpack.place_item(box_data, Vector2i(0, 0))
	for effect in box_data.effects:
		if effect.has_method("on_equip"):
			effect.on_equip(box_data, context)
	
	# 放置纸团并设置污染
	backpack.place_item(paper_data, Vector2i(2, 0))
	var paper_inst = backpack.grid[Vector2i(2, 0)]
	paper_inst.current_pollution = 5 # Multiplier = 6, Backlash = 5
	
	var resolver = ImpactResolver.new(backpack, context)
	var actions = resolver.resolve_impact(Vector2i(2, 0), ItemData.Direction.RIGHT)
	
	# 检查反噬数值：本应扣 5 San，现在应扣 5 - 1 = 4 San
	var backlash_found = false
	for a in actions:
		if a.description == "污染反噬":
			backlash_found = true
			assert_eq(a.value.amount, -4, "Backlash should be reduced by 1")
	assert_true(backlash_found)

# --- 草稿纸 (Scratch Paper) ---
func test_scratch_paper_reactive():
	var paper_data = item_db.get_item_by_id("scratch_paper")
	var book_data = item_db.get_item_by_id("english_book")
	
	backpack.place_item(paper_data, Vector2i(2, 2))
	
	var spy_battle = SpyBattle.new()
	add_child(spy_battle)
	spy_battle.backpack_manager = backpack
	spy_battle.context = context
	context.battle = spy_battle
	
	# 模拟抽到书籍
	spy_battle._process_new_item_acquisition(book_data)
	await get_tree().process_frame
	
	assert_true(spy_battle.triggered_pos.has(Vector2i(2, 2)), "Scratch paper should trigger on Book draw")
	spy_battle.queue_free()

# --- 污点放大镜 (Stain Magnifier) ---
func test_stain_magnifier_trigger():
	var mag_data = item_db.get_item_by_id("stain_magnifier")
	var p1 = item_db.get_item_by_id("paper_ball")
	var p2 = item_db.get_item_by_id("paper_ball")
	
	backpack.place_item(mag_data, Vector2i(0, 0))
	backpack.place_item(p1, Vector2i(2, 0))
	backpack.place_item(p2, Vector2i(4, 0))
	
	backpack.grid[Vector2i(2, 0)].current_pollution = 10 # 最高
	backpack.grid[Vector2i(4, 0)].current_pollution = 5
	
	var spy_battle = SpyBattle.new()
	add_child(spy_battle)
	spy_battle.backpack_manager = backpack
	spy_battle.context = context
	context.battle = spy_battle
	
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT))
	
	# 逻辑：
	# 1. 放大镜被撞。P1(10 poll) -> 11 poll. 指挥 P1 触发额外撞击 (deferred).
	# 2. 放大镜传导 RIGHT。击中 P1. 
	#    此时 P1 有 11 层，Multiplier=12. P1 自增 +12. 
	#    P1 最终 = 11 + 12 = 23.
	assert_eq(backpack.grid[Vector2i(2, 0)].current_pollution, 23, "P1 should be 23 (10+1+12)")
	
	await get_tree().process_frame # 等待 call_deferred
	assert_true(spy_battle.triggered_pos.has(Vector2i(2, 0)), "Highest polluter should be triggered")
	
	spy_battle.queue_free()
