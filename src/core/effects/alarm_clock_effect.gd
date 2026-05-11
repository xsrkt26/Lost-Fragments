class_name AlarmClockEffect
extends ItemEffect

## 破旧闹钟效果：被撞时 +3 分，若抽卡超过 10 次额外 +8 分

@export var base_score: int = 3
@export var extra_score: int = 8
@export var threshold: int = 10

func on_hit(_instance: BackpackManager.ItemInstance, _source: BackpackManager.ItemInstance, _resolver: ImpactResolver, context: GameContext, multiplier: int = 1) -> GameAction:
	var final_score = base_score * multiplier
	
	if context and context.battle:
		if context.battle.draw_count > threshold:
			final_score += extra_score * multiplier
			print("[Effect] 闹钟触发额外奖励! 总分: ", final_score)
	
	var action = GameAction.new(GameAction.Type.NUMERIC, "闹钟响了")
	action.value = {"type": "score", "amount": final_score}
	return action
