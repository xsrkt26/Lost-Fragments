class_name LotteryEffect
extends ItemEffect

## 半张彩票效果：50% +8分，50% -2梦值

func on_hit(_instance: BackpackManager.ItemInstance, _source: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	var action = GameAction.new(GameAction.Type.NUMERIC, "彩票结算")
	
	if randf() < 0.5:
		# 中奖
		action.value = {"type": "score", "amount": 8 * _multiplier}
		print("[Effect] 彩票中奖！+" + str(8 * _multiplier) + "分")
	else:
		# 没中
		action.value = {"type": "sanity", "amount": -2 * _multiplier}
		print("[Effect] 彩票没中... " + str(-2 * _multiplier) + "梦值")
		
	return action
