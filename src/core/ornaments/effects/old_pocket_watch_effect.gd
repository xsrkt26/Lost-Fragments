class_name OldPocketWatchEffect
extends "res://src/core/ornaments/ornament_effect.gd"

func modify_sanity_loss(amount: int, reason: String, _item_data: ItemData, context: GameContext, _state: Dictionary) -> int:
	if reason != "draw" or context == null or context.battle == null:
		return amount
	if context.battle.draw_count <= 3:
		return max(0, amount - 1)
	return amount
