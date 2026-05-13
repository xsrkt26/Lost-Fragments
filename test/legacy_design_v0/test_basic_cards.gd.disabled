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
	# 清理全局事件总线的连接，防止测试间干扰 (之前是 singleton)
	var bus = get_node_or_null("/root/GlobalEventBus")
	if bus:
		for sig in bus.get_signal_list():
			for conn in bus.get_signal_connection_list(sig.name):
				bus.disconnect(sig.name, conn.callable)
				
	# 显式清理 mock_battle，因为它内部有 add_child
	if context and context.battle:
		context.battle.queue_free()

# --- 美味烧鸡测试 (Roast Chicken) ---

func test_roast_chicken_normal_healing():
	var chicken = item_db.get_item_by_id("roast_chicken")
	backpack.place_item(chicken, Vector2i(2, 0))
	gs.current_sanity = 50
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(2, 0), ItemData.Direction.RIGHT))
	assert_eq(gs.current_sanity, 55, "Normal healing should add 5 Sanity")

func test_roast_chicken_max_sanity_limit():
	var chicken = item_db.get_item_by_id("roast_chicken")
	backpack.place_item(chicken, Vector2i(2, 0))
	gs.current_sanity = 98 # 接近上限 100
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(2, 0), ItemData.Direction.RIGHT))
	assert_eq(gs.current_sanity, 100, "Sanity should not exceed 100 (Max)")

func test_roast_chicken_on_hit():
	var chicken = item_db.get_item_by_id("roast_chicken")
	backpack.place_item(chicken, Vector2i(2, 2))
	var resolver = ImpactResolver.new(backpack, context)
	var actions = resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT)
	assert_gt(actions.size(), 1, "Roast chicken should be hitable")

# --- 破旧闹钟测试 (Alarm Clock) ---

func test_alarm_clock_base_score():
	var clock = item_db.get_item_by_id("alarm_clock")
	backpack.place_item(clock, Vector2i(2, 0))
	context.battle.draw_count = 10 # 刚好在阈值上 ( > 10 才会额外加分)
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(2, 0), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 3, "At threshold 10, should still give base 3 score")

func test_alarm_clock_extra_score():
	var clock = item_db.get_item_by_id("alarm_clock")
	backpack.place_item(clock, Vector2i(2, 0))
	context.battle.draw_count = 11 # 超过阈值
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(2, 0), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 11, "Above threshold 10, should give 3+8=11 score")

# --- 半张彩票测试 (Lottery) ---

func test_lottery_game_over_on_backlash():
	var lottery = item_db.get_item_by_id("lottery")
	
	watch_signals(gs)
	seed(12345) 
	gs.current_sanity = 10
	
	# 直接模拟 100 次效果触发，确保 San 值归零
	for i in range(100):
		for effect in lottery.effects:
			var action = effect.on_hit(null, null, null, context)
			_apply_actions([action])
		if gs.current_sanity <= 0:
			break
		
	assert_signal_emitted(gs, "game_over", "Lottery backlash should eventually trigger Game Over")

func test_lottery_probability_check():
	var lottery = item_db.get_item_by_id("lottery")
	
	seed(123) # 固定种子
	var win_count = 0
	var lose_count = 0
	
	for i in range(100):
		for effect in lottery.effects:
			var action = effect.on_hit(null, null, null, context)
			if action.value.type == "score": win_count += 1
			if action.value.type == "sanity": lose_count += 1
			
	assert_true(win_count > 30 and win_count < 70, "Win count should be roughly 50% (actual: " + str(win_count) + ")")
	assert_true(lose_count > 30 and lose_count < 70, "Lose count should be roughly 50% (actual: " + str(lose_count) + ")")

# --- 诅咒箱测试 (Curse Box) ---

func test_curse_box_effect():
	var box = item_db.get_item_by_id("curse_box")
	backpack.place_item(box, Vector2i(2, 2))
	gs.current_sanity = 50
	
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT))
	
	assert_eq(gs.current_sanity, 45, "Should lose 5 sanity on hit")

func test_curse_box_multiplier():
	var box = item_db.get_item_by_id("curse_box")
	backpack.place_item(box, Vector2i(2, 2))
	backpack.grid[Vector2i(2, 2)].add_pollution(1) # x2 multiplier
	gs.current_sanity = 50
	
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT))
	
	# 50 - 10 (effect x2) - 1 (backlash) = 39
	assert_eq(gs.current_sanity, 39, "Should lose 10 sanity (effect) + 1 (backlash) = 11 total")

func test_curse_box_at_boundary():
	var box = item_db.get_item_by_id("curse_box")
	backpack.place_item(box, Vector2i(4, 4))
	
	var resolver = ImpactResolver.new(backpack, context)
	# 边界测试：确保不会崩溃且能被撞击
	var actions = resolver.resolve_impact(Vector2i(4, 4), ItemData.Direction.RIGHT)
	assert_gt(actions.size(), 0)

# --- 易拉罐测试 (Tin Can) ---

func test_tin_can_basic_score():
	var can = item_db.get_item_by_id("tin_can")
	backpack.place_item(can, Vector2i(2, 2)) # 1x2 item
	
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT))
	
	assert_eq(gs.current_score, 5, "Should give 5 points on hit")

func test_tin_can_multi_hit():
	var can = item_db.get_item_by_id("tin_can")
	backpack.place_item(can, Vector2i(2, 2))
	
	var resolver = ImpactResolver.new(backpack, context)
	# 同时击中它的两个格子
	_apply_actions(resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT))
	_apply_actions(resolver.resolve_impact(Vector2i(2, 3), ItemData.Direction.RIGHT))
	
	assert_eq(gs.current_score, 10, "Should give 10 points when hit twice")

func test_tin_can_transmission():
	var can = item_db.get_item_by_id("tin_can")
	var paper = item_db.get_item_by_id("paper_ball")
	backpack.place_item(can, Vector2i(2, 1)) # 占据 (2,1), (2,2)
	backpack.place_item(paper, Vector2i(3, 1)) # 紧贴 (2,1) 的右侧
	
	var resolver = ImpactResolver.new(backpack, context)
	# 从其自身位置触发撞击
	var actions = resolver.resolve_impact(Vector2i(2, 1), ItemData.Direction.RIGHT)
	
	var hit_paper = false
	for a in actions:
		if a.description.contains("纸团"): hit_paper = true
	assert_true(hit_paper, "Tin can should transmit impact to adjacent paper ball")

# --- 棒球测试 (Baseball) ---

class SpyBattle extends BattleManager:
	var triggered_pos = []
	func trigger_impact_at(pos: Vector2i):
		triggered_pos.append(pos)

func test_baseball_empty_board():
	# 场景：背包里一个球都没有，抽到球不应报错
	var baseball_data = item_db.get_item_by_id("baseball")
	var spy_battle = SpyBattle.new()
	add_child(spy_battle)
	spy_battle.backpack_manager = backpack
	spy_battle.context = context
	
	# 应该平稳执行，不产生任何触发
	spy_battle._process_new_item_acquisition(baseball_data)
	assert_eq(spy_battle.triggered_pos.size(), 0, "No triggers if board is empty")
	spy_battle.queue_free()

func test_baseball_at_corner():
	# 边界：球在角落 (4,4)
	var baseball_data = item_db.get_item_by_id("baseball")
	backpack.place_item(baseball_data, Vector2i(4, 4))
	
	var spy_battle = SpyBattle.new()
	add_child(spy_battle)
	spy_battle.backpack_manager = backpack
	spy_battle.context = context
	
	spy_battle._process_new_item_acquisition(baseball_data)
	assert_true(spy_battle.triggered_pos.has(Vector2i(4, 4)), "Should trigger even at corner")
	spy_battle.queue_free()

func _apply_actions(actions: Array[GameAction]):
	for action in actions:
		if action.type == GameAction.Type.NUMERIC:
			if action.value.type == "score":
				context.add_score(action.value.amount)
			elif action.value.type == "sanity":
				context.change_sanity(action.value.amount)
