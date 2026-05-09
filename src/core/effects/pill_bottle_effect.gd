class_name PillBottleEffect
extends ItemEffect

## 小药瓶效果：被撞：定向给全场污染最高的物品 +1 污染。

func on_hit(_instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	var all_items = _resolver.backpack.get_all_instances()
	var max_pollution = -1
	var target_item = null
	
	for item in all_items:
		if item.current_pollution > max_pollution:
			max_pollution = item.current_pollution
			target_item = item
		elif item.current_pollution == max_pollution and target_item != null:
			# 如果并列，可以随机或者按某种规则。这里简单取第一个。
			pass
			
	if target_item:
		target_item.add_pollution(1)
		print("[Effect] 小药瓶为最高污染者 ", target_item.data.item_name, " 增加了 1 层污染")
		var action = GameAction.new(GameAction.Type.EFFECT, "小药瓶分药")
		action.item_instance = target_item
		return action
		
	return null
