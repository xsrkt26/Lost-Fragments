class_name LeakyPenEffect
extends ItemEffect

## 漏水钢笔：被撞：+3分，所指方向下一个物品若是废弃物，其+1污染。

@export var score_amount: int = 3
@export var pollution_amount: int = 1
@export var target_tag: String = "废弃物"

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var total_score = score_amount * multiplier
	
	# 查找所指方向下一个物品
	# 假设方向沿着 instance.data.direction
	var backpack = resolver.backpack
	var dir = instance.data.direction
	
	# 需要从 instance 的每一个格子出发寻找，取第一个撞到的废弃物
	var hit_pos = Vector2i(-1, -1)
	for offset in instance.data.shape:
		var slot_pos = instance.root_pos + offset
		hit_pos = backpack.get_next_item_pos(slot_pos, dir, [target_tag])
		if hit_pos != Vector2i(-1, -1):
			break
			
	if hit_pos != Vector2i(-1, -1):
		var target_instance = backpack.grid[hit_pos]
		target_instance.add_pollution(pollution_amount * multiplier)
		print("[Effect] 漏水钢笔将前方废弃物 '", target_instance.data.item_name, "' 的污染增加了 ", pollution_amount * multiplier)
	
	var action = GameAction.new(GameAction.Type.NUMERIC, "漏水钢笔增加分数")
	action.value = {"type": "score", "amount": total_score}
	return action
