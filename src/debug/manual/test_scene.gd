extends Node2D

func _ready():
	# 延迟一帧执行，确保所有 Autoload 都已加载完毕
	await get_tree().process_frame
	
	print("\n" + "=".repeat(20))
	print("开始【场景模式】集成逻辑验证")
	print("=".repeat(20) + "\n")
	
	# 1. 检查 GameState
	if not GameState:
		print("[错误] 未找到 GameState 单例！请确保 Autoload 设置正确。")
		return
		
	GameState.reset_game()
	print("初始状态 - 分数: ", GameState.current_score, " 梦值: ", GameState.current_sanity)
	
	# 2. 初始化背包
	var backpack = BackpackManager.new()
	backpack.setup_grid(5, 5)
	
	# 3. 定义物品与效果
	var item_a = ItemData.new()
	item_a.item_name = "治疗包(A)"
	item_a.direction = ItemData.Direction.RIGHT
	var heal = SanityEffect.new()
	heal.sanity_change = 5
	item_a.effects.append(heal)
	
	var item_b = ItemData.new()
	item_b.item_name = "宝箱(B)"
	item_b.direction = ItemData.Direction.RIGHT
	var score1 = ScoreEffect.new()
	score1.score_amount = 10
	item_b.effects.append(score1)
	
	var item_c = ItemData.new()
	item_c.item_name = "自爆箱(C)"
	item_c.direction = ItemData.Direction.RIGHT
	var hurt = SanityEffect.new()
	hurt.sanity_change = -20
	var score2 = ScoreEffect.new()
	score2.score_amount = 50
	item_c.effects.append(hurt)
	item_c.effects.append(score2) # 扣血但加高分
	
	# 4. 放置物品
	backpack.place_item(item_a, Vector2i(0, 0))
	backpack.place_item(item_b, Vector2i(2, 0))
	backpack.place_item(item_c, Vector2i(4, 0))
	
	# 5. 执行连锁撞击
	var context = GameContext.new(GameState)
	var resolver = ImpactResolver.new(backpack, context)
	print("\n>>> 触发连锁动作: 从 A 向右撞击 >>>")
	resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT)
	
	# 6. 等待结算完成并打印结果
	print("\n" + "=".repeat(20))
	print("测试完成！最终数据：")
	print("当前总分: ", GameState.current_score, " (预期: 60)")
	print("当前梦值: ", GameState.current_sanity, " (预期: 80)")
	print("=".repeat(20) + "\n")
	
	print("此窗口将在 5 秒后自动关闭...")
	await get_tree().create_timer(5.0).timeout
	get_tree().quit()
