class_name CorrosiveSpreadEffect
extends ItemEffect

## 腐蚀扩散效果（腐蚀海绵）：被撞：给路径上之后所有格子的物品各 +1 污染。

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	var backpack = resolver.backpack
	var dir = instance.data.direction
	var step = Vector2i.ZERO
	
	match dir:
		ItemData.Direction.UP: step = Vector2i(0, -1)
		ItemData.Direction.DOWN: step = Vector2i(0, 1)
		ItemData.Direction.LEFT: step = Vector2i(-1, 0)
		ItemData.Direction.RIGHT: step = Vector2i(1, 0)
		
	var current_pos = instance.root_pos + step
	var affected_items = []
	
	# 沿着方向扫描到底
	while current_pos.x >= 0 and current_pos.x < backpack.grid_width and \
		  current_pos.y >= 0 and current_pos.y < backpack.grid_height:
		
		if backpack.grid.has(current_pos):
			var target = backpack.grid[current_pos]
			if target != instance and not affected_items.has(target):
				target.add_pollution(1)
				affected_items.append(target)
				print("[Effect] 腐蚀海绵侵蚀: ", target.data.item_name)
		
		current_pos += step
		
	if not affected_items.is_empty():
		return GameAction.new(GameAction.Type.EFFECT, "海绵腐蚀")
		
	return null
