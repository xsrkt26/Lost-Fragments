class_name PreservativeEffect
extends ItemEffect

## 防腐蜡效果：被撞：赋予指向方向的第一个物品“防腐”状态。
## 防腐状态下的物品，其污染层数不再发生任何变化。

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	# 物理探测：寻找前方物品
	var target_pos = resolver._find_next_item(instance.root_pos, instance.data.direction, [], instance)
	if target_pos != Vector2i(-1, -1):
		var target_item = resolver.backpack.grid[target_pos]
		target_item.is_preserved = true
		print("[Effect] 防腐蜡生效：", target_item.data.item_name, " 已进入防腐状态。")
		
		# 构造效果反馈
		var action = GameAction.new(GameAction.Type.EFFECT, "防腐封装")
		action.item_instance = target_item
		return action
		
	return null
