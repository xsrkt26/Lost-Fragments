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

# --- 废弃扑克牌 (Joker) ---
func test_joker_on_hit():
	var joker = item_db.get_item_by_id("joker")
	backpack.place_item(joker, Vector2i(2, 2))
	
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(1, 2), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 3, "Joker should give 3 score on hit")

# --- 旧足球 (Old Soccer Ball) ---
class SpyBattleManager extends BattleManager:
	var triggered_at = []
	func trigger_impact_at(pos: Vector2i):
		triggered_at.append(pos)

func test_old_soccer_ball_reactive():
	var soccer = item_db.get_item_by_id("old_soccer_ball")
	var trash = item_db.get_item_by_id("paper_ball") # tag: 废弃物
	backpack.place_item(soccer, Vector2i(2, 2))
	
	var spy_battle = SpyBattleManager.new()
	add_child(spy_battle)
	spy_battle.backpack_manager = backpack
	spy_battle.context = context
	context.battle = spy_battle
	
	spy_battle._process_new_item_acquisition(trash)
	await get_tree().process_frame
	
	assert_true(spy_battle.triggered_at.has(Vector2i(2, 2)), "Old soccer ball should react to Trash drawn")
	spy_battle.queue_free()

# --- 便利贴 (Sticky Note) ---
func test_sticky_note_pollution_conversion():
	var sticky = item_db.get_item_by_id("sticky_note")
	backpack.place_item(sticky, Vector2i(2, 2))
	
	var instance = backpack.grid[Vector2i(2, 2)]
	
	var resolver = ImpactResolver.new(backpack, context)
	
	# 测试：0 污染时，无变化
	_apply_actions(resolver.resolve_impact(Vector2i(1, 2), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 0)
	
	# 测试：累积 2 层污染时，无变化
	instance.current_pollution = 2
	_apply_actions(resolver.resolve_impact(Vector2i(1, 2), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 0)
	assert_eq(instance.current_pollution, 2)
	
	# 测试：累积 5 层污染时，消耗 3 层，+10 分，剩余 2 层
	# 注意：此时它有 5 层污染，因此其效果结算会被放大 (Multiplier = 1 + 5 = 6)
	# 得分: 1 (套) * 10 * 6 = 60
	instance.current_pollution = 5
	_apply_actions(resolver.resolve_impact(Vector2i(1, 2), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 60, "Score should be 10 * 6 multiplier = 60")
	assert_eq(instance.current_pollution, 2)
	
	# 测试：累积 7 层污染时，消耗 6 层，+20 分，剩余 1 层
	# 此时有 7 层污染，Multiplier = 1 + 7 = 8
	# 得分: 2 (套) * 10 * 8 = 160
	instance.current_pollution = 7
	_apply_actions(resolver.resolve_impact(Vector2i(1, 2), ItemData.Direction.RIGHT))
	assert_eq(gs.current_score, 220, "Score should be 60 + 160 = 220") # 之前60分 + 这次160分
	assert_eq(instance.current_pollution, 1)
