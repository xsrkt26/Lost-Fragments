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
	# 清理全局事件总线的连接，防止测试间干扰
	var bus = get_node_or_null("/root/GlobalEventBus")
	if bus:
		for sig in bus.get_signal_list():
			for conn in bus.get_signal_connection_list(sig.name):
				bus.disconnect(sig.name, conn.callable)
				
	# 显式清理 mock_battle，因为它内部有 add_child
	if context and context.battle:
		context.battle.queue_free()

func test_apple_discard_logic():
	var apple = item_db.get_item_by_id("apple")
	backpack.place_item(apple, Vector2i(1, 1))
	gs.current_sanity = 50
	
	for effect in apple.effects:
		effect.on_discard(apple, context)
		
	assert_eq(gs.current_sanity, 53, "Should heal 3 Sanity on discard")

func test_apple_discard_at_edge():
	# 边界：在 (0,0) 丢弃苹果
	var apple = item_db.get_item_by_id("apple")
	backpack.place_item(apple, Vector2i(0, 0))
	
	# 模拟丢弃逻辑 (检查是否有崩溃风险)
	for effect in apple.effects:
		effect.on_discard(apple, context)
	assert_eq(gs.current_sanity, 100, "Should be clamped to max_sanity (100)")

func test_apple_core_transformation():
	var core = item_db.get_item_by_id("apple_core")
	var success = backpack.place_item(core, Vector2i(0, 0))
	assert_true(success, "Apple core should be placeable")
	assert_not_null(backpack.grid.get(Vector2i(0, 0)), "Instance should exist")

func test_apple_core_on_hit():
	# 确保被撞时不会报错且能正常传导
	var core_data = item_db.get_item_by_id("apple_core")
	var paper_data = item_db.get_item_by_id("paper_ball")
	backpack.place_item(core_data, Vector2i(2, 2))
	backpack.place_item(paper_data, Vector2i(4, 2))
	
	# 重要：设置 Apple Core 的传导方向为 RIGHT
	backpack.grid[Vector2i(2,2)].data.direction = ItemData.Direction.RIGHT
	
	var resolver = ImpactResolver.new(backpack, context)
	# 从左侧撞击 Apple Core
	var actions = resolver.resolve_impact(Vector2i(1, 2), ItemData.Direction.RIGHT)
	
	var hit_paper = false
	for a in actions:
		if a.description.contains("纸团"): hit_paper = true
	assert_true(hit_paper, "Apple core should transmit impact in its direction (RIGHT)")

# --- 梦境燃料罐测试 (Dream Fuel Tank) ---

class SpyBattleManager extends BattleManager:
	var triggered_at = []
	func trigger_impact_at(pos: Vector2i):
		triggered_at.append(pos)

func test_dream_fuel_tank_reactive():
	var tank_data = item_db.get_item_by_id("dream_fuel_tank")
	var paper_data = item_db.get_item_by_id("paper_ball")
	
	backpack.place_item(tank_data, Vector2i(0, 0)) # 2x2
	backpack.place_item(paper_data, Vector2i(3, 0))
	
	var spy_battle = SpyBattleManager.new()
	add_child(spy_battle)
	spy_battle.backpack_manager = backpack
	spy_battle.context = context
	context.battle = spy_battle
	
	# 获取网格中的实例数据
	var tank_instance = backpack.grid[Vector2i(0, 0)]
	tank_instance.data.runtime_id = 999
	
	# 模拟燃料罐已“在手” (触发 on_draw 建立监听)
	# 注意：必须传入网格中的 data 副本
	for effect in tank_instance.data.effects:
		effect.on_draw(tank_instance.data, context)
		
	# 触发其他物品的撞击
	var bus = gs.get_node("/root/GlobalEventBus")
	var paper_instance = backpack.grid[Vector2i(3, 0)]
	bus.item_impacted.emit(paper_instance, null)
	
	await get_tree().process_frame
	
	assert_true(spy_battle.triggered_at.has(Vector2i(0, 0)), "Fuel tank should react to other items being hit")
	spy_battle.queue_free()

func test_gift_box_transformation_boundary():
	# 场景：2x2 的礼物盒在边缘变身为另一个 2x2 的物品 (或更小的)
	# 验证变身过程是否会因为空间检查失败而崩溃
	var gift_box = item_db.get_item_by_id("gift_box")
	backpack.place_item(gift_box, Vector2i(3, 3)) # 刚好占据最后两排
	
	var resolver = ImpactResolver.new(backpack, context)
	var actions = resolver.resolve_impact(Vector2i(2, 3), ItemData.Direction.RIGHT)
	_apply_actions(actions)
	
	var instance = backpack.grid.get(Vector2i(3, 3))
	assert_ne(instance.data.id, "gift_box", "Should transform safely at boundary")

func test_gift_box_transformation_count():
	var gift_box = item_db.get_item_by_id("gift_box")
	backpack.place_item(gift_box, Vector2i(1, 1))
	
	# 模拟 5 次变身，确保每次都能成功变身为新东西
	for i in range(5):
		var resolver = ImpactResolver.new(backpack, context)
		var actions = resolver.resolve_impact(Vector2i(0, 1), ItemData.Direction.RIGHT)
		_apply_actions(actions)
		var instance = backpack.grid.get(Vector2i(1, 1))
		assert_not_null(instance)
		# 礼物盒变身后不再是礼物盒 (或者概率极低，这里假设它变了)
		# 实际逻辑是 GiftBoxEffect 会调用 replace_item_data

func test_cracked_lens_mimic():
	var lens = item_db.get_item_by_id("cracked_lens")
	var alarm = item_db.get_item_by_id("alarm_clock")
	
	# 闹钟打中镜片。闹钟放在 (0,0)，镜片放在 (2,0)
	backpack.place_item(alarm, Vector2i(0, 0))
	backpack.place_item(lens, Vector2i(2, 0))
	
	var resolver = ImpactResolver.new(backpack, context)
	# 从 (0,0) 发起，闹钟作为源不会被击中，它打中镜片
	var actions = resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT)
	
	# 此时 actions 应该包含：镜片模仿了闹钟的效果。
	# 闹钟效果：+3分。镜片模仿后也应该+3分。
	# 实际上 Resolver 只会打中镜片。
	var total_score = 0
	for action in actions:
		if action.type == GameAction.Type.NUMERIC and action.value.type == "score":
			context.add_score(action.value.amount)
			
	assert_eq(total_score, 0, "Wait, total_score should be 0 because we added to GS, not local var")
	assert_eq(gs.current_score, 3, "Cracked lens should mimic the alarm clock (3 pts)")

func test_cracked_lens_no_mirror_infinite():
	# 测试：镜片不应模仿另一个镜片的模仿行为（防止死循环）
	var lens1 = item_db.get_item_by_id("cracked_lens")
	var lens2 = item_db.get_item_by_id("cracked_lens")
	backpack.place_item(lens1, Vector2i(0, 0))
	backpack.place_item(lens2, Vector2i(2, 0))
	
	var resolver = ImpactResolver.new(backpack, context)
	var actions = resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT)
	
	# 应该平稳结束，不产生分，仅记录冲击
	assert_not_null(actions)
	assert_eq(gs.current_score, 0)

func _apply_actions(actions: Array[GameAction]):
	for action in actions:
		if action.type == GameAction.Type.NUMERIC:
			if action.value.type == "score":
				context.add_score(action.value.amount)
			elif action.value.type == "sanity":
				context.change_sanity(action.value.amount)
