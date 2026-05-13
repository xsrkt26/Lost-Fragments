extends GutTest

var gs
var backpack: BackpackManager
var context: GameContext
var battle: BattleManager
var item_db

func before_each():
	gs = autofree(Node.new())
	gs.set_script(preload("res://src/autoload/game_state.gd"))
	add_child(gs)
	gs.reset_game()
	
	battle = autofree(BattleManager.new())
	add_child(battle)
	
	# 强制注入测试用的 gs 到 battle 的 context 中
	battle.context.state = gs
	
	backpack = battle.backpack_manager
	context = battle.context
	
	item_db = get_node_or_null("/root/ItemDatabase")

func test_discard_floating_items_at_end():
	var item_data = item_db.get_item_by_id("paper_ball")
	
	# 模拟创建两个 UI 物品，赋予一个简单的脚本以持有变量
	var script = GDScript.new()
	script.source_code = "extends Control\nvar item_data\nvar item_instance"
	script.reload()
	
	var item_ui1 = Control.new()
	item_ui1.set_script(script)
	item_ui1.item_data = item_data
	item_ui1.item_instance = null # 悬浮
	
	var item_ui2 = Control.new()
	item_ui2.set_script(script)
	item_ui2.item_data = item_data
	# 放置其中一个到中心 (2, 2)
	backpack.place_item(item_data, Vector2i(2, 2))
	var inst2 = backpack.grid[Vector2i(2, 2)]
	item_ui2.item_instance = inst2 # 在背包中
	
	# 注册到管理器
	battle.managed_item_uis = [item_ui1, item_ui2]
	
	# 执行自动清理
	battle.discard_all_outside_items()
	
	assert_true(item_ui1.is_queued_for_deletion(), "Floating item should be discarded")
	assert_false(item_ui2.is_queued_for_deletion(), "Placed item should NOT be discarded")
	assert_eq(battle.managed_item_uis.size(), 1, "Managed list should now only contain the placed item")
	
	item_ui2.free() 

func test_on_discard_effect_trigger():
	var apple_data = item_db.get_item_by_id("apple")
	
	gs.current_score = 0
	
	var script = GDScript.new()
	script.source_code = "extends Control\nvar item_data\nvar item_instance"
	script.reload()
	
	var apple_ui = Control.new()
	apple_ui.set_script(script)
	apple_ui.item_data = apple_data
	apple_ui.item_instance = null
	
	battle.managed_item_uis = [apple_ui]
	battle.discard_all_outside_items()
	
	assert_eq(gs.current_score, 3, "Discarding apple should add dream value")
