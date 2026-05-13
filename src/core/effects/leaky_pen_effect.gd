class_name LeakyPenEffect
extends ItemEffect

@export var score_amount: int = 3
@export var pollution_amount: int = 1
@export var target_tag: String = "废弃物"

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var hit_pos = Vector2i(-1, -1)
	for offset in instance.data.shape:
		hit_pos = resolver.backpack.get_next_item_pos(instance.root_pos + offset, instance.data.direction, [target_tag])
		if hit_pos != Vector2i(-1, -1):
			break

	if hit_pos != Vector2i(-1, -1):
		resolver.add_pollution(resolver.backpack.grid[hit_pos], pollution_amount)

	var action = GameAction.new(GameAction.Type.NUMERIC, "Leaky pen score")
	action.value = {"type": "score", "amount": score_amount * multiplier}
	return action
