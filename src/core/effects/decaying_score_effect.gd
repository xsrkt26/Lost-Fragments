class_name DecayingScoreEffect
extends ItemEffect

## 古老藏书效果：被撞 +15分，每次触发使此分数 -1

@export var current_score: int = 15

func on_hit(_instance: BackpackManager.ItemInstance, _source: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	var score_to_add = current_score * _multiplier
	
	# 分数衰减 (修改实例中的数据)
	if current_score > 0:
		current_score -= 1
		print("[Effect] 古老藏书褪色，下次分数减 1. 当前: ", current_score)
		
	var action = GameAction.new(GameAction.Type.NUMERIC, "翻阅古书")
	action.value = {"type": "score", "amount": score_to_add}
	return action
