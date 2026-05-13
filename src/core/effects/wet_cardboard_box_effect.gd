class_name WetCardboardBoxEffect
extends ItemEffect

@export var score_amount: int = 6
@export var target_pollution: int = 3

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var next_pos = resolver.backpack.get_next_item_pos(instance.root_pos, instance.data.direction)
	if next_pos != Vector2i(-1, -1):
		resolver.add_pollution(resolver.backpack.grid[next_pos], target_pollution)

	var action = GameAction.new(GameAction.Type.NUMERIC, "Wet cardboard box score")
	action.value = {"type": "score", "amount": score_amount * multiplier}
	return action
