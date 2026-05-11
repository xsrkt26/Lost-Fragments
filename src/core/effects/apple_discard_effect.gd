class_name AppleDiscardEffect
extends ItemEffect

## 苹果特有的效果：丢弃时回复梦值 (San值)

@export var sanity_recovery: int = 3

func on_discard(_item_data: ItemData, context: GameContext) -> GameAction:
	print("[Effect] 苹果被丢弃，触发回血: ", sanity_recovery)
	if context and context.state:
		context.state.consume_sanity(-sanity_recovery) # 增加 San 值
		
	# 返回一个简单的数值动作
	var action = GameAction.new(GameAction.Type.NUMERIC, "苹果回血")
	action.value = {"type": "sanity", "amount": sanity_recovery}
	return action
