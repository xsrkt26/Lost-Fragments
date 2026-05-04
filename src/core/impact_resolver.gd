class_name ImpactResolver
extends Node

## 撞击解析器：现在负责生成 Action 序列，而不是直接执行逻辑

var backpack_mgr: BackpackManager

func _init(p_backpack_mgr: BackpackManager):
	backpack_mgr = p_backpack_mgr

## 执行解析并返回动作列表
func resolve_impact(start_pos: Vector2i, dir: ItemData.Direction) -> Array[GameAction]:
	var action_list: Array[GameAction] = []
	var visited_instances: Array = []
	
	_calculate_chain(start_pos, dir, action_list, visited_instances)
	
	return action_list

func _calculate_chain(pos: Vector2i, dir: ItemData.Direction, action_list: Array[GameAction], visited: Array) -> void:
	var hit_pos = backpack_mgr.get_next_item_pos(pos, dir)
	
	if hit_pos == Vector2i(-1, -1):
		return
		
	var instance = backpack_mgr.grid[hit_pos]
	
	if visited.has(instance):
		return
		
	visited.append(instance)
	
	# 1. 记录一个撞击动作
	var impact_action = GameAction.new(GameAction.Type.IMPACT, "碰撞发生")
	impact_action.value = {"pos": hit_pos}
	# 注意：这里我们只存了逻辑数据，后续 UI 层会将其关联到具体的 Node
	action_list.append(impact_action)
	
	# 2. 收集该物品产生的所有效果动作
	for effect in instance.data.effects:
		if effect:
			var action = effect.execute(instance, self)
			if action:
				action_list.append(action)
	
	# 3. 继续向下传导
	_calculate_chain(hit_pos, instance.data.direction, action_list, visited)
