class_name OrnamentEffect
extends Resource

func modify_sanity_loss(amount: int, _reason: String, _item_data: ItemData, _context: GameContext, _state: Dictionary) -> int:
	return amount

func after_item_drawn(_item_data: ItemData, _draw_count: int, _context: GameContext, _state: Dictionary) -> void:
	pass

func after_impact_chain_resolved(_source: BackpackManager.ItemInstance, _actions: Array[GameAction], _context: GameContext, _state: Dictionary) -> void:
	pass

func _count_impacts(actions: Array[GameAction]) -> int:
	var count = 0
	for action in actions:
		if action.type == GameAction.Type.IMPACT:
			count += 1
	return count
