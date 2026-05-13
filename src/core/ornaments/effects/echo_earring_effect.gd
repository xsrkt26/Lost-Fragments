class_name EchoEarringEffect
extends "res://src/core/ornaments/ornament_effect.gd"

func after_impact_chain_resolved(_source: BackpackManager.ItemInstance, actions: Array[GameAction], context: GameContext, _state: Dictionary) -> void:
	if context != null and _count_impacts(actions) > 0:
		context.add_score(2)
