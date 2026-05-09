class_name ScoreEffect
extends ItemEffect

## 增加分数的简单效果
@export var score_amount: int = 10

func on_hit(_instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	var action = GameAction.new(GameAction.Type.NUMERIC, "增加分数")
	action.value = {"type": "score", "amount": score_amount * _multiplier}
	return action
