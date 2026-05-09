class_name TrashRecyclerEffect
extends ItemEffect

## 垃圾回收器：被撞：+25分，净化全场污染，每层再+25分。

@export var base_score: int = 25
@export var score_per_pollution: int = 25

func on_hit(_instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var instances = resolver.backpack.get_all_instances()
	var total_purified = 0
	
	# 全场大扫除
	for target in instances:
		if target.current_pollution > 0:
			total_purified += target.current_pollution
			target.current_pollution = 0
			print("[Effect] 垃圾回收器净化了 '", target.data.item_name, "'")
			
	var total_score = (base_score + total_purified * score_per_pollution) * multiplier
	
	var action = GameAction.new(GameAction.Type.NUMERIC, "垃圾回收器结算全场污染")
	action.value = {"type": "score", "amount": total_score}
	
	print("[Effect] 垃圾回收器总共净化了 ", total_purified, " 层污染，产生暴击得分: ", total_score)
	return action
