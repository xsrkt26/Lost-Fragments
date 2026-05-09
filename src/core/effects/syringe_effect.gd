class_name SyringeEffect
extends ItemEffect

## 针管效果：被撞：自身所指方向一整行中所有废弃物+1污染。

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	var backpack = _resolver.backpack
	var dir = instance.data.direction
	var step = Vector2i.ZERO
	
	match dir:
		ItemData.Direction.UP: step = Vector2i(0, -1)
		ItemData.Direction.DOWN: step = Vector2i(0, 1)
		ItemData.Direction.LEFT: step = Vector2i(-1, 0)
		ItemData.Direction.RIGHT: step = Vector2i(1, 0)
	
	var current_pos = instance.root_pos + step
	var affected_items = []
	
	# 沿着方向扫描一整行/列
	while current_pos.x >= 0 and current_pos.x < backpack.grid_width and \
		  current_pos.y >= 0 and current_pos.y < backpack.grid_height:
		
		var target_instance = backpack.grid.get(current_pos)
		if target_instance and target_instance != instance:
			# 检查是否包含“废弃物”标签，且尚未在本次动作中处理过（防止多格物品重复处理）
			if target_instance.data.tags.has("废弃物") and not affected_items.has(target_instance):
				target_instance.add_pollution(1)
				affected_items.append(target_instance)
				print("[Effect] 针管注向: ", target_instance.data.item_name, " 污染 +1")
		
		current_pos += step
		
	if not affected_items.is_empty():
		return GameAction.new(GameAction.Type.EFFECT, "针管群体注射")
		
	return null
