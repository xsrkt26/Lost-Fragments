class_name SameItemDrawImpactEffect
extends ItemEffect

@export var trigger_item_id: String = ""

func on_global_item_drawn(new_item: ItemData, my_instance: BackpackManager.ItemInstance, context: GameContext):
	if context == null or context.battle == null:
		return
	if new_item == null or new_item.runtime_id == my_instance.data.runtime_id:
		return
	var expected_id = trigger_item_id if trigger_item_id != "" else my_instance.data.id
	if new_item.id == expected_id:
		context.battle.queue_impact_at(my_instance.root_pos, -1, my_instance, "same_item_draw")
