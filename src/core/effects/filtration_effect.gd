class_name FiltrationEffect
extends ItemEffect

## 深井滤芯效果：被撞：移除指向物品的最多 N 层污染，每层提供得分。
## 得分受滤芯自身倍率放大。执行后手动屏蔽目标，防止多格探测造成的二次伤害。

@export var max_filter_layers: int = 3
@export var score_per_layer: int = 10

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var backpack = _resolver.backpack
	# 扫描：从每一个占据格都尝试探测，但只要有一个格过滤了，我们就屏蔽目标
	var target_item = null
	var target_hit_pos = Vector2i(-1, -1)
	
	for offset in instance.data.shape:
		var pos = instance.root_pos + offset
		var found_pos = _resolver._find_next_item(pos, instance.data.direction, [], instance)
		if found_pos != Vector2i(-1, -1):
			target_item = backpack.grid[found_pos]
			target_hit_pos = found_pos
			break
			
	if target_item == null or target_item.current_pollution <= 0:
		return null
		
	# --- 物理屏蔽关键步骤 ---
	# 我们将目标物品和方向加入 resolver 的 visited 列表，防止本轮解析器再次撞击它
	if _resolver.get("visited") != null:
		var visited_entry = {"target": target_item, "dir": instance.data.direction}
		_resolver.visited.append(visited_entry)
		print("[Effect] 深井滤芯已物理屏蔽目标 ", target_item.data.item_name, " 防止二次撞击")
	
	# 执行过滤
	var layers_to_remove = min(target_item.current_pollution, max_filter_layers)
	target_item.current_pollution -= layers_to_remove
	
	var total_gain = layers_to_remove * score_per_layer * multiplier
	print("[Effect] 深井滤芯过滤成功，消耗 ", layers_to_remove, " 层，得分: ", total_gain)
	
	var action = GameAction.new(GameAction.Type.NUMERIC, "过滤清算")
	action.value = {"type": "score", "amount": total_gain}
	return action
