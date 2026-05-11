class_name PollutionSourceEffect
extends ItemEffect

## 污染源瓶效果：被撞：所有带污染物品 +1 污染。
## 若本次链已经发生过至少 5 次污染结算，+20 分。

@export var bonus_score: int = 20
@export var settlement_threshold: int = 5

func on_hit(_instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var backpack = resolver.backpack
	var all_items = backpack.get_all_instances()
	
	# 1. 全场叠层
	var affected_count = 0
	for item in all_items:
		if item.current_pollution > 0:
			item.add_pollution(1)
			affected_count += 1
	print("[Effect] 污染源瓶活性化，为全场 ", affected_count, " 个物品增加了污染。")
	
	# 2. 检查长链奖励
	# 扫描 Resolver 的 actions 列表，寻找“污染反噬”动作的次数
	var settlement_count = 0
	for action in resolver.actions_history:
		if action.type == GameAction.Type.NUMERIC and action.description == "污染反噬":
			settlement_count += 1
			
	if settlement_count >= settlement_threshold:
		var final_bonus = bonus_score * multiplier
		print("[Effect] 污染源瓶感应到长链（结算次数:", settlement_count, "），提供额外得分: ", final_bonus)
		var action = GameAction.new(GameAction.Type.NUMERIC, "污染源共鸣奖励")
		action.value = {"type": "score", "amount": final_bonus}
		return action
		
	return GameAction.new(GameAction.Type.EFFECT, "污染源扩散")
