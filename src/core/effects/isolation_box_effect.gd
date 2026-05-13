class_name IsolationBoxEffect
extends ItemEffect

@export var reduction_amount: int = 1

func get_pollution_san_reduction(_instance: BackpackManager.ItemInstance, _context: GameContext) -> int:
	return reduction_amount
