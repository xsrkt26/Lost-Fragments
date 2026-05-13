class_name TagReactiveEffect
extends ItemEffect

@export var trigger_tag: String = ""

func on_global_item_drawn(new_item: ItemData, my_instance: BackpackManager.ItemInstance, context: GameContext):
	if trigger_tag == "" or new_item == null:
		return
	if new_item.tags.has(trigger_tag) and context and context.battle:
		context.battle.call_deferred("trigger_impact_at", my_instance.root_pos)
