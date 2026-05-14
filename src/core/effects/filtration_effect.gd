class_name FiltrationEffect
extends ItemEffect

## 深井滤芯效果：被撞：移除指向物品的最多 N 层污染，每层提供得分。
## 得分受滤芯自身倍率放大。执行后手动屏蔽目标，防止多格探测造成的二次伤害。

@export var max_filter_layers: int = 3
@export var score_per_layer: int = 10

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var backpack = resolver.backpack
	# 扫描：从每一个占据格都尝试探测，但只要有一个格过滤了，我们就屏蔽目标
	var target_item = null
	var _target_hit_pos = Vector2i(-1, -1)
	
	# 获取步进向量
	var step = Vector2i.ZERO
	match instance.data.direction:
		ItemData.Direction.UP: step = Vector2i(0, -1)
		ItemData.Direction.DOWN: step = Vector2i(0, 1)
		ItemData.Direction.LEFT: step = Vector2i(-1, 0)
		ItemData.Direction.RIGHT: step = Vector2i(1, 0)

	for offset in instance.data.shape:
		var pos = instance.root_pos + offset
		var found_pos = resolver._find_next_item(pos + step, instance.data.direction, [], instance)
		if found_pos != Vector2i(-1, -1):
			target_item = backpack.grid[found_pos]
			_target_hit_pos = found_pos
			break
			
	if target_item == null or target_item.current_pollution <= 0:
		return null
		
	# --- 物理屏蔽关键步骤 ---
	# 我们将目标物品加入本次撞击结算的屏蔽列表，防止本轮解析器再次撞击它
	if resolver.has_method("block_instance_for_current_resolution"):
		resolver.block_instance_for_current_resolution(target_item, instance.data.direction)
		print("[Effect] 深井滤芯已物理屏蔽目标 ", target_item.data.item_name, " 防止二次撞击")
	
	# 执行过滤
	var layers_to_remove = min(target_item.current_pollution, max_filter_layers)
	target_item.current_pollution -= layers_to_remove
	
	var total_gain = layers_to_remove * score_per_layer * multiplier
	print("[Effect] 深井滤芯过滤成功，消耗 ", layers_to_remove, " 层，得分: ", total_gain)
	
	var action = GameAction.new(GameAction.Type.NUMERIC, "过滤清算")
	action.value = {"type": "score", "amount": total_gain}
	return action
