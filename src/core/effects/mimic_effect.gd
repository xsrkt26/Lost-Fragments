class_name MimicEffect
extends ItemEffect

## 模仿效果：裂痕镜片特有。复制并触发撞自己的物品的效果。

func on_hit(instance: BackpackManager.ItemInstance, source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, context: GameContext, multiplier: int = 1) -> GameAction:
	if not source_instance:
		print("[Effect] 镜片被初始撞击，没有可模仿的对象。")
		return null
		
	print("[Effect] 镜片模仿: ", source_instance.data.item_name)
	
	# 遍历撞击者的所有效果并执行一次
	var result_action: GameAction = null
	for effect in source_instance.data.effects:
		# 排除自身，防止死循环 (虽然理论上镜片不会撞镜片，但安全第一)
		if effect is MimicEffect: continue
		
		# 执行效果并记录第一个产生动作的效果
		var action = effect.on_hit(instance, source_instance, resolver, context, multiplier)
		if not result_action:
			result_action = action
			
	if result_action:
		return result_action
		
	return GameAction.new(GameAction.Type.IMPACT, "镜片映射")
