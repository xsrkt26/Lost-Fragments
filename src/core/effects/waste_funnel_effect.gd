class_name WasteFunnelEffect
extends ItemEffect

## 废液漏斗效果：被撞：自身方向上的后续 2 个格子的物品各增加污染。
## 若目标无污染则 +1*Multi，若已有污染则 +2*Multi。

@export var scan_range: int = 2

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var backpack = _resolver.backpack
	var dir_vec = Vector2i.ZERO
	
	match instance.data.direction:
		ItemData.Direction.UP: dir_vec = Vector2i(0, -1)
		ItemData.Direction.DOWN: dir_vec = Vector2i(0, 1)
		ItemData.Direction.LEFT: dir_vec = Vector2i(-1, 0)
		ItemData.Direction.RIGHT: dir_vec = Vector2i(1, 0)
		
	# 找到形状的最远端作为起点（防止漏斗内部格干扰）
	# 废液漏斗是 1x3，假设 root 在最左，则最右是 root + (2,0)
	var max_offset = Vector2i.ZERO
	for offset in instance.data.shape:
		if offset.length_squared() > max_offset.length_squared():
			max_offset = offset
			
	var scan_start = instance.root_pos + max_offset + dir_vec
	var affected_items = []
	
	for i in range(scan_range):
		var current_pos = scan_start + dir_vec * i
		if backpack.grid.has(current_pos):
			var target = backpack.grid[current_pos]
			if target != instance and not affected_items.has(target):
				var add_amount = 1 if target.current_pollution == 0 else 2
				target.add_pollution(add_amount * multiplier)
				affected_items.append(target)
				print("[Effect] 废液漏斗灌注: ", target.data.item_name, " +", add_amount * multiplier, " 污染")
				
	if not affected_items.is_empty():
		return GameAction.new(GameAction.Type.EFFECT, "废液漏斗路径灌注")
		
	return null
