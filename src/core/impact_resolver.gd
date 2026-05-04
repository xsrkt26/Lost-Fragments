class_name ImpactResolver
extends RefCounted

## 撞击解析器：负责计算物理/逻辑上的撞击连锁反应

var backpack: BackpackManager
var context: GameContext

func _init(p_backpack: BackpackManager, p_context: GameContext):
	backpack = p_backpack
	context = p_context

## 核心算法：解析从 start_pos 开始向 dir 方向的撞击链
## 返回一个 GameAction 数组，按顺序记录发生的事件
func resolve_impact(start_pos: Vector2i, dir: ItemData.Direction) -> Array[GameAction]:
	var actions: Array[GameAction] = []
	
	# 1. 记录初始撞击动作（即便没撞到东西，也可以作为起始动画）
	var initial_impact = GameAction.new(GameAction.Type.IMPACT, "开始撞击")
	initial_impact.value = {"pos": start_pos}
	actions.append(initial_impact)
	
	# 2. 递归/循环查找被撞击的物品
	_resolve_recursive(start_pos, dir, actions, [])
	
	return actions

func _resolve_recursive(current_pos: Vector2i, dir: ItemData.Direction, actions: Array[GameAction], visited: Array, source_instance: BackpackManager.ItemInstance = null):
	var next_item_pos = backpack.get_next_item_pos(current_pos, dir)
	
	if next_item_pos == Vector2i(-1, -1):
		print("[Resolver Debug] 搜索结束，未撞击到任何物品。起始点: ", current_pos)
		return
		
	var instance = backpack.grid[next_item_pos]
	print("[Resolver Debug] 发现撞击! 目标: ", instance.data.item_name, " 坐标: ", next_item_pos, " RID: ", instance.data.runtime_id)
	
	if instance in visited:
		print("[Resolver Debug] 忽略已访问过的物品: ", instance.data.item_name)
		return
	visited.append(instance)
	
	# 3. 记录“击中”动作
	var hit_action = GameAction.new(GameAction.Type.IMPACT, "击中了 " + instance.data.item_name)
	hit_action.item_instance = instance
	hit_action.value = {"pos": next_item_pos}
	actions.append(hit_action)
	
	# 4. 触发物品的效果 (现在传入撞击来源 source_instance)
	for effect in instance.data.effects:
		var effect_action = effect.on_hit(instance, source_instance, self, context)
		if effect_action:
			# 确保效果动作也携带实例引用，以便播放动画
			if effect_action.item_instance == null:
				effect_action.item_instance = instance
			actions.append(effect_action)
			
	# 5. 核心修复：连锁反应
	# 以被撞击的物品为新起点，沿着它的朝向继续传播撞击
	print("[Resolver Debug] 连锁传播: ", instance.data.item_name, " 向方向 ", instance.data.direction, " 发起新撞击")
	_resolve_recursive(next_item_pos, instance.data.direction, actions, visited, instance)
