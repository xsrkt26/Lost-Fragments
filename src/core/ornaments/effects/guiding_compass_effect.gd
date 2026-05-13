class_name GuidingCompassEffect
extends "res://src/core/ornaments/ornament_effect.gd"

func after_impact_chain_resolved(source: BackpackManager.ItemInstance, actions: Array[GameAction], _context: GameContext, _state: Dictionary) -> void:
	if source == null or source.data == null:
		return
	if source.data.id != "root_dream" or _count_impacts(actions) > 0:
		return
	source.data.rotate_90()
