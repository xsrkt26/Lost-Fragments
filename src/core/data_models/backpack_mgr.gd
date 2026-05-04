class_name BackpackManager
extends Node

## 内部类，记录物品在网格中的实例信息
class ItemInstance:
	var data: ItemData
	var root_pos: Vector2i
	
	func _init(p_data: ItemData, p_pos: Vector2i):
		data = p_data
		root_pos = p_pos

var grid_width: int = 3
var grid_height: int = 3

## 核心网格字典：Key 是 Vector2i 坐标，Value 是 ItemInstance
var grid: Dictionary = {}

func setup_grid(w: int, h: int) -> void:
	grid_width = w
	grid_height = h
	grid.clear()

## 检查指定位置是否可以放置该物品
func can_place_item(item_data: ItemData, root_pos: Vector2i) -> bool:
	for offset in item_data.shape:
		var target_pos = root_pos + offset
		
		# 边界检查
		if target_pos.x < 0 or target_pos.x >= grid_width or target_pos.y < 0 or target_pos.y >= grid_height:
			return false
			
		# 重叠检查
		if grid.has(target_pos):
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

## 获取特定方向上的邻居物品坐标（用于撞击算法）
func get_next_item_pos(start_pos: Vector2i, direction: ItemData.Direction) -> Vector2i:
	var step = Vector2i.ZERO
	match direction:
		ItemData.Direction.UP: step = Vector2i(0, -1)
		ItemData.Direction.DOWN: step = Vector2i(0, 1)
		ItemData.Direction.LEFT: step = Vector2i(-1, 0)
		ItemData.Direction.RIGHT: step = Vector2i(1, 0)
	
	var current_pos = start_pos + step
	# 沿方向搜索直到撞到物品或出界
	while current_pos.x >= 0 and current_pos.x < grid_width and \
		  current_pos.y >= 0 and current_pos.y < grid_height:
		if grid.has(current_pos):
			return current_pos
		current_pos += step
		
	return Vector2i(-1, -1) # 表示未击中
