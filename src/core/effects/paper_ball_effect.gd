class_name PaperBallEffect
extends ItemEffect

## 纸团：被撞：+2分，自身+1污染。

@export var score_amount: int = 2
@export var pollution_amount: int = 1

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var total_score = score_amount * multiplier
	
	# 立即在逻辑层增加污染
	instance.add_pollution(pollution_amount * multiplier)
	print("[Effect] 纸团污染增加 ", pollution_amount * multiplier, " 层，当前污染：", instance.current_pollution)
	
	var action = GameAction.new(GameAction.Type.NUMERIC, "纸团增加分数并自身污染")
	action.value = {"type": "score", "amount": total_score}
	return action
