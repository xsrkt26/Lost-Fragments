class_name InsuranceContractEffect
extends ItemEffect

@export var sanity_recovery: int = 5

func get_sanity_recovery(_instance: BackpackManager.ItemInstance, _context: GameContext) -> int:
	return sanity_recovery
