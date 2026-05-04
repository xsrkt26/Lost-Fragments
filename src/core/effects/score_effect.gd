class_name ScoreEffect
extends ItemEffect

## 增加分数的简单效果
@export var score_amount: int = 10

func on_hit(_instance, _source_instance, _resolver, _context) -> GameAction:
	var action = GameAction.new(GameAction.Type.NUMERIC, "增加分数")
	action.value = {"type": "score", "amount": score_amount}
	
	if _context and _context.state:
		_context.state.add_score(score_amount)
		
	return action
