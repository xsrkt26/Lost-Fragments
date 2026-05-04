class_name LotteryEffect
extends ItemEffect

## 半张彩票效果：50% +8分，50% -2梦值

func on_hit(_instance, _source, _resolver, _context) -> GameAction:
	var action = GameAction.new(GameAction.Type.NUMERIC, "彩票结算")
	
	if randf() < 0.5:
		# 中奖
		if _context and _context.state:
			_context.state.add_score(8)
		action.value = {"type": "score", "amount": 8}
		print("[Effect] 彩票中奖！+8分")
	else:
		# 没中
		if _context and _context.state:
			_context.state.consume_sanity(2)
		action.value = {"type": "sanity", "amount": -2}
		print("[Effect] 彩票没中... -2梦值")
		
	return action
