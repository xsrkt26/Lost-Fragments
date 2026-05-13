class_name ImpactResolver
extends RefCounted

## 撞击解析器：负责递归处理撞击能量流 (Logic)
## 它不存储状态，仅根据当前背包格局计算所有受到影响的操作

var backpack: BackpackManager
var context: GameContext
var actions_history: Array[GameAction] = [] # 记录本次链条中产生的所有动作
var visited: Array = [] # 记录已访问的节点，格式: {"target": ItemInstance, "dir": Direction}

func _init(p_backpack: BackpackManager, p_context: GameContext):
	backpack = p_backpack
	context = p_context

func resolve_impact(start_pos: Vector2i, dir: ItemData.Direction, source: BackpackManager.ItemInstance = null) -> Array[GameAction]:
	actions_history = []
	visited = [] 
	print("[ImpactResolver] 开始处理撞击: 起点 ", start_pos, " 方向 ", dir, " 来源: ", source.data.item_name if source else "None")
	_resolve_recursive(start_pos, dir, actions_history, visited, source)
	return actions_history

func _resolve_recursive(current_pos: Vector2i, dir: ItemData.Direction, actions: Array[GameAction], visited_local: Array, source_instance: BackpackManager.ItemInstance = null, active_filters: Array[String] = [], ignore_visited: bool = false) -> bool:
	var filters: Array[String] = active_filters
	if source_instance and not source_instance.data.hit_filter_tags.is_empty():
		filters = source_instance.data.hit_filter_tags
	
	var step = Vector2i.ZERO
	match dir:
		ItemData.Direction.UP: step = Vector2i(0, -1)
		ItemData.Direction.DOWN: step = Vector2i(0, 1)
		ItemData.Direction.LEFT: step = Vector2i(-1, 0)
		ItemData.Direction.RIGHT: step = Vector2i(1, 0)

	var scan_start = current_pos
	if source_instance != null:
		scan_start = current_pos + step
		
	var next_item_pos = _find_next_item(scan_start, dir, filters, source_instance)
	
	if next_item_pos == Vector2i(-1, -1):
		return false
		
	var instance = backpack.grid[next_item_pos]
	
	# --- 物理去重 ---
	var visit_record = {"target": instance, "dir": dir}
	if not ignore_visited and visit_record in visited_local:
		return true
	visited_local.append(visit_record)
	
	var hit_action = GameAction.new(GameAction.Type.IMPACT, "击中了 " + instance.data.item_name)
	hit_action.item_instance = instance
	hit_action.value = {"pos": next_item_pos}
	actions.append(hit_action)
	
	var bus = context.state.get_node_or_null("/root/GlobalEventBus")
	if bus: bus.item_impacted.emit(instance, source_instance)
		
	var current_pollution = instance.current_pollution
	var total_multiplier = 1 + current_pollution
	
	if current_pollution > 0:
		var san_reduction = current_pollution
		if context.state and context.state.has_method("get_modifier"):
			san_reduction = max(0, san_reduction - context.state.get_modifier("pollution_san_reduction", 0))
		if san_reduction > 0:
			var san_action = GameAction.new(GameAction.Type.NUMERIC, "污染反噬")
			san_action.item_instance = instance
			san_action.value = {"type": "sanity", "amount": -san_reduction}
			actions.append(san_action)

	for effect in instance.data.effects:
		var effect_action = effect.on_hit(instance, source_instance, self, context, total_multiplier)
		if effect_action:
			if effect_action.item_instance == null: effect_action.item_instance = instance
			actions.append(effect_action)
		
	# --- 物理传导拦截逻辑 ---
	# 如果物品模式为 NONE，则彻底停止该方向的递归
	if instance.data.transmission_mode == ItemData.TransmissionMode.NONE:
		print("[ImpactResolver] 物品 ", instance.data.item_name, " 传导模式为 NONE，拦截能量流。")
		return true 
		
	# 修正点：将 source_instance 的 execute_after_hit 移出循环，且放在传导判定之前或之后？
	# 按照原逻辑，应该在传导之前触发（类似于“撞击瞬间”的反馈）
	if source_instance:
		for s_effect in source_instance.data.effects:
			if s_effect.has_method("execute_after_hit"):
				s_effect.execute_after_hit(instance, source_instance, self, context, actions)
		
	var did_hit_others = false
	match instance.data.transmission_mode:
		ItemData.TransmissionMode.NORMAL:
			var item_dir = instance.data.direction
			# 核心需求：方向相同时才会传导
			if item_dir == dir:
				for offset in instance.data.shape:
					if _resolve_recursive(instance.root_pos + offset, item_dir, actions, visited_local, instance, filters, false):
						did_hit_others = true
			else:
				print("[ImpactResolver] 物品 ", instance.data.item_name, " 方向不一致 (来源:", dir, " 自身:", item_dir, ")，传导终止。")
		ItemData.TransmissionMode.OMNI:
			for d in [ItemData.Direction.UP, ItemData.Direction.DOWN, ItemData.Direction.LEFT, ItemData.Direction.RIGHT]:
				for offset in instance.data.shape:
					if _resolve_recursive(instance.root_pos + offset, d, actions, visited_local, instance, filters, false):
						did_hit_others = true
						
	for effect in instance.data.effects:
		if effect.has_method("after_impact"):
			var post_action = effect.after_impact(instance, did_hit_others, self, context, total_multiplier)
			if post_action:
				if post_action.item_instance == null: post_action.item_instance = instance
				actions.append(post_action)
				
	return true

func _find_next_item(pos: Vector2i, _dir: ItemData.Direction, filters: Array[String], exclude: BackpackManager.ItemInstance) -> Vector2i:
	# 边界检查
	if pos.x < 0 or pos.x >= backpack.grid_width or pos.y < 0 or pos.y >= backpack.grid_height:
		return Vector2i(-1, -1)
		
	# 核心需求：仅检查紧贴的（相邻）格子，不再跳过空格搜索
	if backpack.grid.has(pos):
		var found = backpack.grid[pos]
		if found != exclude:
			if filters.is_empty(): 
				return pos
			# 检查过滤器：仅能撞击包含这些标签的物品
			for tag in found.data.tags:
				if tag in filters: 
					return pos
			# 如果有过滤器且不匹配，则视为未击中目标
			print("[ImpactResolver] 紧贴物 ", found.data.item_name, " 不满足标签过滤器: ", filters)
	
	return Vector2i(-1, -1)
