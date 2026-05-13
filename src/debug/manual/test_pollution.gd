extends Node2D

func _ready():
	await get_tree().process_frame
	
	print("\n" + "=".repeat(20))
	print("开始【污染流】大招卡逻辑验证")
	print("=".repeat(20) + "\n")
	
	var gs = get_node_or_null("/root/GameState")
	if not gs:
		print("[错误] 找不到 GameState")
		return
	gs.reset_game()
	print("初始状态 - 分数: ", gs.current_score, " San值: ", gs.current_sanity)
	
	var backpack = BackpackManager.new()
	backpack.setup_grid(5, 5)
	
	var item_db = get_node_or_null("/root/ItemDatabase")
	if not item_db: return
		
	var paper_ball = item_db.get_item_by_id("paper_ball")
	var sticky_note = item_db.get_item_by_id("sticky_note")
	var rusty_gear = item_db.get_item_by_id("rusty_gear")
	var trash_recycler = item_db.get_item_by_id("trash_recycler")
	
	backpack.place_item(paper_ball, Vector2i(0, 0))
	backpack.place_item(sticky_note, Vector2i(2, 0))
	backpack.place_item(rusty_gear, Vector2i(0, 1))
	backpack.place_item(trash_recycler, Vector2i(2, 2)) # 3x3 (2,2 to 4,4)
	
	# 给纸团一点初始污染，这样放大镜能找到它
	backpack.grid[Vector2i(0,0)].add_pollution(2)
	
	var context = GameContext.new(gs)
	
	# 模拟 BattleManager 提供 call_deferred 的代理
	var mock_battle = Node.new()
	mock_battle.set_script(preload("res://src/battle/battle_manager.gd"))
	mock_battle.backpack_manager = backpack
	mock_battle.context = context
	add_child(mock_battle)
	context.battle = mock_battle
	
	var resolver = ImpactResolver.new(backpack, context)
	
	print("\n>>> 触发 1: 污点放大镜 (2,0) 向右 >>>")
	var actions = resolver.resolve_impact(Vector2i(2, 0), ItemData.Direction.RIGHT)
	apply_actions(actions, context)
	print(">>> 预期: 找到纸团(2层污染)，加1层污染，变为3层。并将其加入后续撞击队列。")
	
	# 等待 call_deferred 的撞击触发
	await get_tree().process_frame
	
	print("\n>>> 触发 2: 生锈齿轮改 (0,1) 向右 >>>")
	actions = resolver.resolve_impact(Vector2i(0, 1), ItemData.Direction.RIGHT)
	apply_actions(actions, context)
	print(">>> 预期: 自身污染+1。传染给周围(含纸团)，纸团污染再增加。")
	
	print("\n>>> 触发 3: 垃圾回收器 (2,2) 向右 >>>")
	actions = resolver.resolve_impact(Vector2i(2, 2), ItemData.Direction.RIGHT)
	apply_actions(actions, context)
	print(">>> 预期: 全场清零，按污染层数*25暴击加分。")
	
	print("\n" + "=".repeat(20))
	print("污染流大招测试结束")
	print("=".repeat(20) + "\n")

	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func apply_actions(actions: Array[GameAction], context: GameContext):
	for action in actions:
		if action.type == GameAction.Type.NUMERIC:
			if action.value.type == "score":
				context.add_score(action.value.amount)
			elif action.value.type == "sanity":
				context.change_sanity(action.value.amount)
