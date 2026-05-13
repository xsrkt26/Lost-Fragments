class_name LeakyPenEffect
extends ItemEffect

@export var score_amount: int = 3
@export var pollution_amount: int = 1
@export var target_tag: String = "废弃物"

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var hit_pos = Vector2i(-1, -1)
	for offset in instance.data.shape:
		hit_pos = _find_next_occupied_pos(resolver.backpack, instance, instance.root_pos + offset, instance.data.direction)
		if hit_pos != Vector2i(-1, -1):
			break

	if hit_pos != Vector2i(-1, -1):
		var target = resolver.backpack.grid[hit_pos]
		if target.data.tags.has(target_tag):
			resolver.add_pollution(target, pollution_amount)

	var action = GameAction.new(GameAction.Type.NUMERIC, "Leaky pen score")
	action.value = {"type": "score", "amount": score_amount * multiplier}
	return action

func _find_next_occupied_pos(backpack: BackpackManager, source: BackpackManager.ItemInstance, start_pos: Vector2i, direction: ItemData.Direction) -> Vector2i:
	var step = _direction_to_step(direction)
	var current_pos = start_pos + step
	while current_pos.x >= 0 and current_pos.x < backpack.grid_width and current_pos.y >= 0 and current_pos.y < backpack.grid_height:
		var target = backpack.grid.get(current_pos)
		if target and target != source:
			return current_pos
		current_pos += step
	return Vector2i(-1, -1)

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
