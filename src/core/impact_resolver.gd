class_name ImpactResolver
extends RefCounted

var backpack: BackpackManager
var context: GameContext
var actions_history: Array[GameAction] = []
var visited: Array = []

func _init(p_backpack: BackpackManager, p_context: GameContext):
	backpack = p_backpack
	context = p_context

func resolve_impact(start_pos: Vector2i, dir: ItemData.Direction, source: BackpackManager.ItemInstance = null) -> Array[GameAction]:
	actions_history = []
	visited = []
	_resolve_recursive(start_pos, dir, actions_history, visited, source)
	return actions_history

func _resolve_recursive(current_pos: Vector2i, dir: ItemData.Direction, actions: Array[GameAction], visited_local: Array, source_instance: BackpackManager.ItemInstance = null, active_filters: Array[String] = [], ignore_visited: bool = false) -> bool:
	var filters: Array[String] = active_filters
	if source_instance and not source_instance.data.hit_filter_tags.is_empty():
		filters = source_instance.data.hit_filter_tags

	var step = _direction_to_step(dir)
	var scan_start = current_pos
	if source_instance != null:
		scan_start = current_pos + step

	var next_item_pos = _find_next_item(scan_start, dir, filters, source_instance)
	if next_item_pos == Vector2i(-1, -1):
		return false

	var instance = backpack.grid[next_item_pos]
	var visit_record = {"target": instance, "dir": dir}
	if not ignore_visited and visit_record in visited_local:
		return true
	visited_local.append(visit_record)

	var hit_action = GameAction.new(GameAction.Type.IMPACT, "Hit " + instance.data.item_name)
	hit_action.item_instance = instance
	hit_action.value = {"pos": next_item_pos}
	actions.append(hit_action)

	var bus = context.state.get_node_or_null("/root/GlobalEventBus") if context and context.state else null
	if bus:
		bus.item_impacted.emit(instance, source_instance)

	var current_pollution = instance.current_pollution
	var total_multiplier = 1 + current_pollution
	if current_pollution > 0:
		var san_reduction = current_pollution
		if context.state and context.state.has_method("get_modifier"):
			san_reduction = max(0, san_reduction - context.state.get_modifier("pollution_san_reduction", 0))
		san_reduction = max(0, san_reduction - _get_backpack_pollution_san_reduction())
		if san_reduction > 0:
			var san_action = GameAction.new(GameAction.Type.NUMERIC, "Pollution backlash")
			san_action.item_instance = instance
			san_action.value = {"type": "sanity", "amount": -san_reduction}
			actions.append(san_action)

	for effect in instance.data.effects:
		var effect_action = effect.on_hit(instance, source_instance, self, context, total_multiplier)
		if effect_action:
			if effect_action.item_instance == null:
				effect_action.item_instance = instance
			actions.append(effect_action)

	if instance.data.transmission_mode == ItemData.TransmissionMode.NONE:
		return true

	if source_instance:
		for source_effect in source_instance.data.effects:
			if source_effect.has_method("execute_after_hit"):
				source_effect.execute_after_hit(instance, source_instance, self, context, actions)

	var did_hit_others = false
	match instance.data.transmission_mode:
		ItemData.TransmissionMode.NORMAL:
			if instance.data.direction == dir:
				for offset in instance.data.shape:
					if _resolve_recursive(instance.root_pos + offset, instance.data.direction, actions, visited_local, instance, filters, false):
						did_hit_others = true
		ItemData.TransmissionMode.OMNI:
			for next_dir in [ItemData.Direction.UP, ItemData.Direction.DOWN, ItemData.Direction.LEFT, ItemData.Direction.RIGHT]:
				for offset in instance.data.shape:
					if _resolve_recursive(instance.root_pos + offset, next_dir, actions, visited_local, instance, filters, false):
						did_hit_others = true

	for effect in instance.data.effects:
		if effect.has_method("after_impact"):
			var post_action = effect.after_impact(instance, did_hit_others, self, context, total_multiplier)
			if post_action:
				if post_action.item_instance == null:
					post_action.item_instance = instance
				actions.append(post_action)

	return true

func add_pollution(instance: BackpackManager.ItemInstance, amount: int) -> void:
	if instance == null or amount <= 0:
		return

	var old_pollution = instance.current_pollution
	instance.add_pollution(amount)
	var added = instance.current_pollution - old_pollution
	if added <= 0:
		return

	for effect in instance.data.effects:
		if effect.has_method("on_pollution_added"):
			var action = effect.on_pollution_added(instance, added, old_pollution, self, context)
			if action:
				if action.item_instance == null:
					action.item_instance = instance
				actions_history.append(action)

func _get_backpack_pollution_san_reduction() -> int:
	var reduction = 0
	for instance in backpack.get_all_instances():
		for effect in instance.data.effects:
			if effect.has_method("get_pollution_san_reduction"):
				reduction += effect.get_pollution_san_reduction(instance, context)
	return reduction

func _find_next_item(pos: Vector2i, _dir: ItemData.Direction, filters: Array[String], exclude: BackpackManager.ItemInstance) -> Vector2i:
	if pos.x < 0 or pos.x >= backpack.grid_width or pos.y < 0 or pos.y >= backpack.grid_height:
		return Vector2i(-1, -1)

	if backpack.grid.has(pos):
		var found = backpack.grid[pos]
		if found != exclude:
			if filters.is_empty():
				return pos
			for tag in found.data.tags:
				if tag in filters:
					return pos

	return Vector2i(-1, -1)

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
