class_name BackpackManager
extends Node

## 内部类，记录物品在网格中的实例信息
class ItemInstance:
	var data: ItemData
	var root_pos: Vector2i
	var current_pollution: int = 0:
		set(val):
			if is_preserved:
				print("[BackpackManager] 物品 ", data.item_name, " 已防腐，拒绝修改污染 (", current_pollution, " -> ", val, ")")
				return
			current_pollution = max(0, val)
	
	var is_preserved: bool = false
	
	func _init(p_data: ItemData, p_pos: Vector2i):
		data = p_data
		root_pos = p_pos

	func add_pollution(amount: int):
		# 现在 setter 会自动处理 guard
		current_pollution += amount

var grid_width: int = 5
var grid_height: int = 5

## 核心网格字典：Key 是 Vector2i 坐标，Value 是 ItemInstance
var grid: Dictionary = {}

func setup_grid(w: int, h: int) -> void:
	grid_width = w
	grid_height = h
	grid.clear()
	print("[BackpackManager] 网格已初始化: ", w, "x", h)

## 检查指定位置是否可以放置该物品
func can_place_item(item_data: ItemData, root_pos: Vector2i) -> bool:
	for offset in item_data.shape:
		var target_pos = root_pos + offset
		
		# 边界检查
		if target_pos.x < 0 or target_pos.x >= grid_width or target_pos.y < 0 or target_pos.y >= grid_height:
			print("[BackpackManager] 放置拒绝: 坐标 ", target_pos, " 超出边界 (", grid_width, "x", grid_height, ")")
			return false
			
		# 重叠检查
		if grid.has(target_pos):
			print("[BackpackManager] 放置拒绝: 坐标 ", target_pos, " 已有物品: ", grid[target_pos].data.item_name)
			return false
			
	return true

## 放置物品到网格
func place_item(item_data: ItemData, root_pos: Vector2i) -> bool:
	if not can_place_item(item_data, root_pos):
		return false
	
	# --- 核心重构：资源隔离 ---
	# 每一个进入背包的物品都必须是唯一的副本，
	# 这样修改这一张卡的属性（如强化、诅咒）才不会影响到其他同类卡。
	var unique_data = item_data.duplicate(true)
	
	var instance = ItemInstance.new(unique_data, root_pos)
	for offset in unique_data.shape:
		var target_pos = root_pos + offset
		grid[target_pos] = instance
		
	return true

## 替换指定位置物品的数据 (用于变身、进化等逻辑)
func replace_item_data(pos: Vector2i, new_data: ItemData):
	if not grid.has(pos): return
	
	var instance: ItemInstance = grid[pos]
	var root_pos = instance.root_pos
	
	# 如果形状改变，需要先清理旧网格，再重新放置
	# 如果形状一致，直接修改 data 即可
	if instance.data.shape == new_data.shape:
		instance.data = new_data.duplicate(true)
	else:
		remove_item_at(root_pos)
		place_item(new_data, root_pos)

## 移除并返回指定位置的物品数据
func remove_item_at(pos: Vector2i) -> ItemData:
	if not grid.has(pos):
		return null
		
	var instance: ItemInstance = grid[pos]
	var item_data = instance.data
	var root_pos = instance.root_pos
	
	for offset in item_data.shape:
		var target_pos = root_pos + offset
		grid.erase(target_pos)
		
	return item_data

## 寻找并返回所有空闲的格子坐标
func get_empty_slots() -> Array[Vector2i]:
	var empty_slots: Array[Vector2i] = []
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			if not grid.has(pos):
				empty_slots.append(pos)
	return empty_slots

## 查找一个足以放下指定形状物品的空闲 root 位置
func find_available_pos(item_data: ItemData) -> Vector2i:
	# 简单算法：从左上角开始扫描
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			if can_place_item(item_data, pos):
				return pos
	return Vector2i(-1, -1)

## 获取一个物品实例的所有相邻物品实例 (不含自己)
func get_neighbor_instances(instance: ItemInstance) -> Array[ItemInstance]:
	var neighbors: Array[ItemInstance] = []
	
	# 遍历该物品占据的所有格子
	for offset in instance.data.shape:
		var cell = instance.root_pos + offset
		# 检查该格子周围的 4 个方向
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor_cell = cell + dir
			if grid.has(neighbor_cell):
				var neighbor_instance = grid[neighbor_cell]
				if neighbor_instance != instance and not neighbors.has(neighbor_instance):
					neighbors.append(neighbor_instance)
					
	return neighbors

## 获取背包中所有不重复的物品实例
func get_all_instances() -> Array[ItemInstance]:
	var instances: Array[ItemInstance] = []
	for pos in grid.keys():
		var instance = grid[pos]
		if not instances.has(instance):
			instances.append(instance)
	return instances

## 获取特定方向上的邻居物品坐标（用于撞击算法）
func get_next_item_pos(start_pos: Vector2i, direction: ItemData.Direction, filter_tags: Array[String] = []) -> Vector2i:
	var step = Vector2i.ZERO
	match direction:
		ItemData.Direction.UP: step = Vector2i(0, -1)
		ItemData.Direction.DOWN: step = Vector2i(0, 1)
		ItemData.Direction.LEFT: step = Vector2i(-1, 0)
		ItemData.Direction.RIGHT: step = Vector2i(1, 0)
	
	# 获取起始位置的物品实例（如果有），搜索时应跳过它
	var source_instance = grid.get(start_pos)
	
	var current_pos = start_pos + step
	# 沿方向搜索直到撞到物品或出界
	while current_pos.x >= 0 and current_pos.x < grid_width and \
		  current_pos.y >= 0 and current_pos.y < grid_height:
		if grid.has(current_pos):
			var hit_instance = grid[current_pos]
			# 只有撞到的不是自己时，才处理
			if hit_instance != source_instance:
				# 如果有过滤器，检查是否匹配
				if filter_tags.is_empty():
					return current_pos
				else:
					var matched = false
					for tag in filter_tags:
						if hit_instance.data.tags.has(tag):
							matched = true
							break
					if matched:
						return current_pos
					else:
						# 不匹配，跳过该物品继续向后搜索 (实现“穿透”非目标的效果)
						print("[BackpackManager] 过滤器跳过物品: ", hit_instance.data.item_name)
		current_pos += step
		
	return Vector2i(-1, -1) # 表示未击中
