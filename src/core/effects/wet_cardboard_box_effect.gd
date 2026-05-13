class_name WetCardboardBoxEffect
extends ItemEffect

@export var score_amount: int = 6
@export var target_pollution: int = 3

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var next_pos = _find_nearest_next_item_pos(resolver.backpack, instance)
	if next_pos != Vector2i(-1, -1):
		resolver.add_pollution(resolver.backpack.grid[next_pos], target_pollution)

	var action = GameAction.new(GameAction.Type.NUMERIC, "Wet cardboard box score")
	action.value = {"type": "score", "amount": score_amount * multiplier}
	return action

func _find_nearest_next_item_pos(backpack: BackpackManager, instance: BackpackManager.ItemInstance) -> Vector2i:
	var step = _direction_to_step(instance.data.direction)
	var best_pos = Vector2i(-1, -1)
	var best_distance = 999999

	for offset in instance.data.shape:
		var distance = 1
		var current_pos = instance.root_pos + offset + step
		while current_pos.x >= 0 and current_pos.x < backpack.grid_width and current_pos.y >= 0 and current_pos.y < backpack.grid_height:
			var target = backpack.grid.get(current_pos)
			if target and target != instance:
				if distance < best_distance:
					best_distance = distance
					best_pos = current_pos
				break
			current_pos += step
			distance += 1

	return best_pos

func _direction_to_step(direction: ItemData.Direction) -> Vector2i:
	match direction:
		ItemData.Direction.UP:
			return Vector2i(0, -1)
		ItemData.Direction.DOWN:
			return Vector2i(0, 1)
		ItemData.Direction.LEFT:
			return Vector2i(-1, 0)
		ItemData.Direction.RIGHT:
			return Vector2i(1, 0)
	return Vector2i.ZERO
