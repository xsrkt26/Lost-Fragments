class_name RustyGearEffect
extends ItemEffect

@export var self_pollution: int = 1

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	resolver.add_pollution(instance, self_pollution)
	var current_pollution = instance.current_pollution

	for neighbor in _get_surrounding_instances(instance, resolver.backpack):
		resolver.add_pollution(neighbor, current_pollution)

	return GameAction.new(GameAction.Type.EFFECT, "Rusty gear spreads pollution")

func _get_surrounding_instances(instance: BackpackManager.ItemInstance, backpack: BackpackManager) -> Array:
	var neighbors: Array = []
	var offsets = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1, 0),                    Vector2i(1, 0),
		Vector2i(-1, 1),  Vector2i(0, 1),  Vector2i(1, 1)
	]

	for my_offset in instance.data.shape:
		var my_pos = instance.root_pos + my_offset
		for offset in offsets:
			var target_pos = my_pos + offset
			if backpack.grid.has(target_pos):
				var neighbor = backpack.grid[target_pos]
				if neighbor != instance and not neighbors.has(neighbor):
					neighbors.append(neighbor)
	return neighbors
