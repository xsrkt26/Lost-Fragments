class_name SafetyPinEffect
extends "res://src/core/ornaments/ornament_effect.gd"

func modify_sanity_loss(amount: int, _reason: String, _item_data: ItemData, _context: GameContext, state: Dictionary) -> int:
	if amount <= 0 or bool(state.get("used", false)):
		return amount
	state["used"] = true
	return max(0, amount - 2)
