class_name ScalingScoreEffect
extends ItemEffect

## 缩放得分效果：根据全场某种指标的总和进行加分
## 适用于：病历夹（根据全场总污染加分）

@export var base_score: int = 2
@export var per_layers: int = 2 # 每多少层污染加 1 分
@export var bonus_per_step: int = 1

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var backpack = resolver.backpack
	var all_items = backpack.get_all_instances()
	
	var total_pollution = 0
	for item in all_items:
		total_pollution += item.current_pollution
		
	var scaling_bonus = (total_pollution / per_layers) * bonus_per_step
	var total_score = (base_score + scaling_bonus) * multiplier
	
	print("[Effect] 病历夹结算：全场总污染 ", total_pollution, "，提供加成 ", scaling_bonus, "，最终得分: ", total_score)
	
	var action = GameAction.new(GameAction.Type.NUMERIC, "病历夹病志记录")
	action.value = {"type": "score", "amount": total_score}
	return action
