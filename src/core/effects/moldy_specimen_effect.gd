class_name MoldySpecimenEffect
extends ItemEffect

## 发霉标本效果：被撞：
## 1. 吸收周围“食物”的能量：每个邻近食物使自身 +3 污染。
## 2. 感染周围：所有邻居获得等同于自身当前 Multiplier 的污染层数。

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	# 防止在同一个解析链中重复触发（针对多格物体）
	for action in _resolver.actions_history:
		if action.description == "发霉扩散" and action.item_instance == instance:
			return null

	var backpack = _resolver.backpack
	var neighbors = backpack.get_neighbor_instances(instance)
	
	# 1. 吸收成长
	var food_count = 0
	for neighbor in neighbors:
		if neighbor.data.tags.has("食物"):
			food_count += 1
	
	if food_count > 0:
		instance.add_pollution(food_count * 3)
		print("[Effect] 发霉标本吸收了 ", food_count, " 个食物，自身污染 +", food_count * 3)
		
	# 2. 扩散感染 (使用最新的 Multiplier)
	var new_multiplier = 1 + instance.current_pollution
	for neighbor in neighbors:
		neighbor.add_pollution(new_multiplier)
		print("[Effect] 发霉标本感染了邻居: ", neighbor.data.item_name, " +", new_multiplier, " 污染")
		
	var action = GameAction.new(GameAction.Type.EFFECT, "发霉扩散")
	action.item_instance = instance
	return action
