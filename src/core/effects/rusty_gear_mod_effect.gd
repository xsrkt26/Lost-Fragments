class_name RustyGearModEffect
extends ItemEffect

## 生锈齿轮(改)：被撞：+1污染，随后将自身污染扩散至周围物品。

@export var self_pollution: int = 1

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var backpack = resolver.backpack
	
	# 1. 自身增加污染
	var added = self_pollution * multiplier
	instance.add_pollution(added)
	var current_p = instance.current_pollution
	print("[Effect] 生锈齿轮(改)自身污染 +", added, "，当前总计: ", current_p)
	
	# 2. 传染给周围 (九宫格，8个方向)
	if current_p > 0:
		var neighbors = []
		var offsets = [
			Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
			Vector2i(-1, 0),                   Vector2i(1, 0),
			Vector2i(-1, 1),  Vector2i(0, 1),  Vector2i(1, 1)
		]
		
		# 从自身的每一个格子向外探测
		for my_offset in instance.data.shape:
			var my_pos = instance.root_pos + my_offset
			for dir_offset in offsets:
				var target_pos = my_pos + dir_offset
				if backpack.grid.has(target_pos):
					var neighbor = backpack.grid[target_pos]
					if neighbor != instance and not neighbors.has(neighbor):
						neighbors.append(neighbor)
		
		for neighbor in neighbors:
			neighbor.add_pollution(current_p)
			print("[Effect] 生锈齿轮(改)将 ", current_p, " 层污染扩散给了: ", neighbor.data.item_name)
			
	return GameAction.new(GameAction.Type.EFFECT, "生锈齿轮(改)散播污染")
