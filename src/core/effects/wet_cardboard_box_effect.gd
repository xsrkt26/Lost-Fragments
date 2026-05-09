class_name WetCardboardBoxEffect
extends ItemEffect

## 潮湿纸箱效果：被撞：+6分，自身方向上的下一个物品+3污染。

@export var score_amount: int = 6
@export var target_pollution: int = 3

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var action = GameAction.new(GameAction.Type.NUMERIC, "纸箱渗水")
	action.value = {"type": "score", "amount": score_amount * multiplier}
	
	# 寻找方向上的下一个物品
	var backpack = _resolver.backpack
	var next_pos = backpack.get_next_item_pos(instance.root_pos, instance.data.direction)
	
	if next_pos != Vector2i(-1, -1):
		var target = backpack.grid[next_pos]
		target.add_pollution(target_pollution)
		print("[Effect] 潮湿纸箱打湿了 ", target.data.item_name, " 污染 +", target_pollution)
		
	return action
