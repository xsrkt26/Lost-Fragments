class_name SyringeEffect
extends ItemEffect

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	var step = _direction_to_step(instance.data.direction)
	var affected_items: Array = []

	var current_pos = _get_frontmost_cell(instance, step) + step
	while current_pos.x >= 0 and current_pos.x < resolver.backpack.grid_width and current_pos.y >= 0 and current_pos.y < resolver.backpack.grid_height:
		var target = resolver.backpack.grid.get(current_pos)
		if target and target != instance and target.data.tags.has("废弃物") and not affected_items.has(target):
			resolver.add_pollution(target, 1)
			affected_items.append(target)
		current_pos += step

	if affected_items.is_empty():
		return null
	return GameAction.new(GameAction.Type.EFFECT, "Syringe adds pollution")

func _get_frontmost_cell(instance: BackpackManager.ItemInstance, step: Vector2i) -> Vector2i:
	var front = instance.root_pos + instance.data.shape[0]
	for offset in instance.data.shape:
		var cell = instance.root_pos + offset
		if step.x > 0 and cell.x > front.x:
			front = cell
		elif step.x < 0 and cell.x < front.x:
			front = cell
		elif step.y > 0 and cell.y > front.y:
			front = cell
		elif step.y < 0 and cell.y < front.y:
			front = cell
	return front

func _direction_to_step(dir: ItemData.Direction) -> Vector2i:
	match dir:
		ItemData.Direction.UP:
			return Vector2i(0, -1)
		ItemData.Direction.DOWN:
			return Vector2i(0, 1)
		ItemData.Direction.LEFT:
			return Vector2i(-1, 0)
		ItemData.Direction.RIGHT:
			return Vector2i(1, 0)
	return Vector2i.ZERO
