class_name MoldyRagEffect
extends ItemEffect

## 霉斑抹布效果：被撞：+2分，自身 +1 污染。

@export var score_amount: int = 2
@export var self_pollution: int = 1

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var action = GameAction.new(GameAction.Type.NUMERIC, "抹布擦拭")
	action.value = {"type": "score", "amount": score_amount * multiplier}
	
	instance.add_pollution(self_pollution)
	print("[Effect] 霉斑抹布被撞，污染 +", self_pollution)
	
	return action
