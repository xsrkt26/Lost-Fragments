class_name TrashBagEffect
extends ItemEffect

## 垃圾袋：被撞：净化相邻所有物品的污染，每净化1层+1梦值。

@export var san_per_pollution: int = 1

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var backpack = resolver.backpack
	var total_purified = 0
	
	# 查找周围十字相邻的物品
	var neighbors = []
	var offsets = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	
	# 遍历自身的所有格子，查找它们的邻居
	for my_offset in instance.data.shape:
		var my_pos = instance.root_pos + my_offset
		for dir_offset in offsets:
			var target_pos = my_pos + dir_offset
			if backpack.grid.has(target_pos):
				var neighbor_instance = backpack.grid[target_pos]
				if neighbor_instance != instance and not neighbors.has(neighbor_instance):
					neighbors.append(neighbor_instance)
					
	for neighbor in neighbors:
		var p = neighbor.current_pollution
		if p > 0:
			total_purified += p
			neighbor.current_pollution = 0 # 净化清零
			print("[Effect] 垃圾袋净化了 '", neighbor.data.item_name, "' 的 ", p, " 层污染")
			
	var total_san = total_purified * san_per_pollution * multiplier
	
	var action = GameAction.new(GameAction.Type.NUMERIC, "垃圾袋净化增加梦值")
	if total_san > 0:
		action.value = {"type": "sanity", "amount": total_san}
	else:
		action.value = {"type": "sanity", "amount": 0} # 产生一个 0 的变化作为兜底
		
	return action
