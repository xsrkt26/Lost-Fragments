class_name StickyNoteEffect
extends ItemEffect

## 便利贴效果：每当有3层污染叠加时：+10分
## 这里的实现是：每次被撞击结算时，检查自身污染层数，每满3层消耗之并转化为分数。

@export var score_per_3_pollution: int = 10

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	if instance.current_pollution >= 3:
		var sets_of_3 = instance.current_pollution / 3
		instance.current_pollution -= sets_of_3 * 3
		
		var score_to_add = sets_of_3 * score_per_3_pollution * multiplier
		print("[Effect] 便利贴消耗了 ", sets_of_3 * 3, " 层污染，获得额外分数: ", score_to_add)
		
		var action = GameAction.new(GameAction.Type.NUMERIC, "便利贴污染转化")
		action.value = {"type": "score", "amount": score_to_add}
		return action
		
	return null
