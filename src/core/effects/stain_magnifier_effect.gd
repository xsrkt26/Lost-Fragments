class_name StainMagnifierEffect
extends ItemEffect

## 污点放大镜：被撞：污染层最高的物品+1污染，并立即让其进行一次污染结算。

@export var extra_pollution: int = 1

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, context: GameContext, multiplier: int = 1) -> GameAction:
	var instances = resolver.backpack.get_all_instances()
	
	var max_pollution_instance: BackpackManager.ItemInstance = null
	var max_pollution: int = 0 # 只有污染 > 0 的物品才会被选中
	
	# 寻找污染层数最高的物品（如果一样高，取第一个找到的）
	# 排除了自己，以防自己就是最高的形成死循环
	for target in instances:
		if target != instance and target.current_pollution > max_pollution:
			max_pollution = target.current_pollution
			max_pollution_instance = target
			
	if max_pollution_instance != null:
		# 1. 增加污染
		var added_pollution = extra_pollution * multiplier
		max_pollution_instance.add_pollution(added_pollution)
		print("[Effect] 污点放大镜找到了最高污染者: ", max_pollution_instance.data.item_name, "，为其增加了 ", added_pollution, " 层污染，现为 ", max_pollution_instance.current_pollution, " 层。")
		
		# 2. 触发一次额外撞击
		if context.battle:
			# Queue this as a new chain after the current impact chain finishes.
			print("[Effect] 污点放大镜指挥 ", max_pollution_instance.data.item_name, " 触发额外撞击！")
			context.battle.queue_impact_at(max_pollution_instance.root_pos, -1, max_pollution_instance, "stain_magnifier")
			
	return GameAction.new(GameAction.Type.EFFECT, "污点放大镜扫视全场")
