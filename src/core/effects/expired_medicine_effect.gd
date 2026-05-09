class_name ExpiredMedicineEffect
extends ItemEffect

## 过期药物效果：被撞：+5分，自身 +3 污染。

@export var score_amount: int = 5
@export var self_pollution: int = 3

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	# 先加分
	var action = GameAction.new(GameAction.Type.NUMERIC, "服用过期药物")
	action.value = {"type": "score", "amount": score_amount * multiplier}
	
	# 自我叠层
	instance.add_pollution(self_pollution)
	print("[Effect] 过期药物被撞，自身污染 +", self_pollution)
	
	return action
