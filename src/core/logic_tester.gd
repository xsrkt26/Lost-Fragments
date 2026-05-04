@tool
extends EditorScript

# 更新后的逻辑验证测试：加入数值结算验证
# 运行方式：在编辑器打开此文件，按 Ctrl + Shift + X

func _run():
	print("\n" + "=".repeat(20))
	print("开始集成逻辑验证测试 (GameState + Effects)")
	print("=".repeat(20) + "\n")
	
	# 获取 GameState (在编辑器运行模式下需要通过 root 获取)
	var root = Engine.get_main_loop().root
	var gs = root.get_node_or_null("GameState")
	
	if not gs:
		print("[警告] 未检测到 Autoload 的 GameState。请确保已在项目设置中添加 src/autoload/game_state.gd 并命名为 GameState。")
		print("当前将以模拟模式运行...\n")
	else:
		gs.reset_game()
		print("GameState 已就绪，初始分数: ", gs.current_score, " San值: ", gs.current_sanity)
	
	# 1. 初始化背包
	var backpack = BackpackManager.new()
	backpack.setup_grid(5, 5)
	
	# 2. 定义效果
	var effect_add_10 = ScoreEffect.new()
	effect_add_10.score_amount = 10
	
	var effect_heal_5 = SanityEffect.new()
	effect_heal_5.sanity_change = 5
	
	var effect_hurt_10 = SanityEffect.new()
	effect_hurt_10.sanity_change = -10
	
	# 3. 创建测试物品并挂载效果
	var item_a = ItemData.new()
	item_a.item_name = "治疗包(A)"
	item_a.direction = ItemData.Direction.RIGHT
	item_a.effects = [effect_heal_5] # 撞击时回血
	
	var item_b = ItemData.new()
	item_b.item_name = "宝箱(B)"
	item_b.direction = ItemData.Direction.RIGHT
	item_b.effects = [effect_add_10] # 撞击时加分
	
	var item_c = ItemData.new()
	item_c.item_name = "诅咒书(C)"
	item_c.direction = ItemData.Direction.RIGHT
	item_c.effects = [effect_hurt_10, effect_add_10] # 撞击时加分但扣血
	
	# 4. 摆放物品 [A] -> [B] -> [C]
	backpack.place_item(item_a, Vector2i(0, 0))
	backpack.place_item(item_b, Vector2i(2, 0))
	backpack.place_item(item_c, Vector2i(4, 0))
	
	# 5. 执行撞击
	var resolver = ImpactResolver.new(backpack)
	print("\n--- 触发连锁撞击：从 (0,0) A 开始 ---")
	resolver.resolve_impact(Vector2i(0, 0), ItemData.Direction.RIGHT)
	
	# 6. 最终结果核对
	print("\n" + "=".repeat(20))
	if gs:
		print("测试完成！最终数据：")
		print("当前分数: ", gs.current_score, " (预期: 20)")
		print("当前San值: ", gs.current_sanity, " (预期: 95)")
	else:
		print("测试完成 (模拟模式)。请检查上方 [Effect] 打印输出。")
	print("=".repeat(20) + "\n")
