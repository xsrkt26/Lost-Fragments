class_name PillBottleEffect
extends ItemEffect

func on_hit(_instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	var target_item: BackpackManager.ItemInstance = null
	var max_pollution = -1

	for item in resolver.backpack.get_all_instances():
		if item.current_pollution > max_pollution:
			max_pollution = item.current_pollution
			target_item = item

	if target_item == null:
		return null

	resolver.add_pollution(target_item, 1)
	var action = GameAction.new(GameAction.Type.EFFECT, "Pill bottle adds pollution")
	action.item_instance = target_item
	return action
