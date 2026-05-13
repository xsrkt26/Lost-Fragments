class_name DreamcatcherFilterEffect
extends "res://src/core/ornaments/ornament_effect.gd"

func after_item_drawn(_item_data: ItemData, draw_count: int, context: GameContext, _state: Dictionary) -> void:
	if draw_count > 0 and draw_count % 3 == 0 and context != null:
		context.add_score(3)
