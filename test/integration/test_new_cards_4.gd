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

# --- 霉斑抹布 (Moldy Rag) ---
func test_moldy_rag_logic():
	var rag = item_db.get_item_by_id("moldy_rag")
	backpack.place_item(rag, Vector2i(2, 2))
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT))
	
	# 得分 2. 污染 +1.
	assert_eq(gs.current_score, 2)
	assert_eq(backpack.grid[Vector2i(2, 2)].current_pollution, 1)

# --- 黑水瓶 (Black Water Bottle) ---
func test_black_water_bottle_transfer():
	var bottle = item_db.get_item_by_id("black_water_bottle") # 1x2 RIGHT
	var paper = item_db.get_item_by_id("paper_ball")
	
	backpack.place_item(bottle, Vector2i(0, 0)) # (0,0), (0,1)
	backpack.place_item(paper, Vector2i(1, 0)) # 紧贴
	
	var bottle_inst = backpack.grid[Vector2i(0, 0)]
	bottle_inst.current_pollution = 5
	
	var resolver = ImpactResolver.new(backpack, context)
	# 直接撞击瓶子
	_apply_actions(resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT))
	
	# 逻辑：转移 5 层给纸团。纸团非水，额外 +1.
	# 纸团被撞：由于此时纸团已有 6 层，Multiplier=7. 自增 1*7=7.
	# 总 6 + 7 = 13.
	assert_eq(backpack.grid[Vector2i(1, 0)].current_pollution, 13)
	assert_eq(bottle_inst.current_pollution, 0, "Pollution transferred out")

func test_black_water_bottle_to_water_item():
	var bottle = item_db.get_item_by_id("black_water_bottle")
	var sponge = item_db.get_item_by_id("corrosive_sponge") # tag 水
	
	backpack.place_item(bottle, Vector2i(0, 0))
	backpack.place_item(sponge, Vector2i(1, 0))
	
	var bottle_inst = backpack.grid[Vector2i(0, 0)]
	bottle_inst.current_pollution = 5
	
	var resolver = ImpactResolver.new(backpack, context)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT))
	
	# 逻辑：转移 5 层给海绵。海绵是水，无额外惩罚。
	assert_eq(backpack.grid[Vector2i(1, 0)].current_pollution, 5)

# --- 腐蚀海绵 (Corrosive Sponge) ---
func test_corrosive_sponge_linear_spread():
	var sponge = item_db.get_item_by_id("corrosive_sponge") # 2x1 DOWN
	var p1 = item_db.get_item_by_id("paper_ball")
	var p2 = item_db.get_item_by_id("paper_ball")
	
	backpack.place_item(sponge, Vector2i(2, 0)) # (2,0), (3,0). Dir DOWN.
	backpack.place_item(p1, Vector2i(2, 1)) # 紧贴 (2,0)
	backpack.place_item(p2, Vector2i(2, 2)) # 紧贴 p1
	
	var resolver = ImpactResolver.new(backpack, context)
	# 撞击海绵
	_apply_actions(resolver.resolve_impact(Vector2i(2, 0), ItemData.Direction.DOWN))
	
	# 逻辑：海绵向下方(DOWN)扫描。
	# p1(2,1) 和 p2(2,2) 都会被腐蚀 +1.
	# 此外，海绵会传导能量给 p1. p1 被撞自增 Multi=2 (+2).
	# p1 最终 = 1 + 2 = 3.
	# p2 只被腐蚀，没被撞（因为 p1 阻挡了传导流，且 p1 NONE 传导）。
	assert_eq(backpack.grid[Vector2i(2, 1)].current_pollution, 3)
	assert_eq(backpack.grid[Vector2i(2, 2)].current_pollution, 1)

# --- 综合协同：黑水灌注海绵 (Fluid Synergy) ---
func test_synergy_fluid_pollution_cascade():
	# 剧本：黑水瓶 -> 腐蚀海绵 -> 纸团
	var bottle = item_db.get_item_by_id("black_water_bottle")
	var sponge = item_db.get_item_by_id("corrosive_sponge")
	var paper = item_db.get_item_by_id("paper_ball")
	
	backpack.place_item(bottle, Vector2i(0, 0))
	backpack.place_item(sponge, Vector2i(1, 0)) # Sponge is 2x1 (1,0),(2,0). Dir DOWN.
	backpack.place_item(paper, Vector2i(1, 1)) # 紧贴 Sponge (1,0) 的下方
	
	backpack.grid[Vector2i(0, 0)].current_pollution = 4
	
	var resolver = ImpactResolver.new(backpack, context)
	# 点击黑水瓶 (0,0)
	_apply_actions(resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT))
	
	# 1. 瓶子向右传导击中海绵 (1,0)。
	# 2. 瓶子效果：转移 4 层给海绵。海绵当前 4 层。
	# 3. 海绵效果：被撞，向下腐蚀一列。纸团 (1,1) 获得 +1 污染。
	# 4. 海绵传导：海绵(1,0) 向下(DOWN) 击中纸团 (1,1)。
	#    此时纸团有 1 层。Multiplier=2. 纸团自增 +2.
	# 5. 纸团最终 = 1 + 2 = 3.
	assert_eq(backpack.grid[Vector2i(1, 0)].current_pollution, 4, "Sponge got pollution from bottle")
	assert_eq(backpack.grid[Vector2i(1, 1)].current_pollution, 3, "Paper got corroded and hit")
