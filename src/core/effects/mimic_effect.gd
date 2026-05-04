class_name MimicEffect
extends ItemEffect

## 模仿效果：裂痕镜片特有。复制并触发撞自己的物品的效果。

func on_hit(instance, source_instance, resolver, context) -> GameAction:
	if not source_instance:
		print("[Effect] 镜片被初始撞击，没有可模仿的对象。")
		return null
		
	print("[Effect] 镜片模仿: ", source_instance.data.item_name)
	
	# 遍历撞击者的所有效果并执行一次
	for effect in source_instance.data.effects:
		# 排除自身，防止死循环 (虽然理论上镜片不会撞镜片，但安全第一)
		if effect is MimicEffect: continue
		
		# 执行效果
		effect.on_hit(instance, source_instance, resolver, context)
		
	var action = GameAction.new(GameAction.Type.IMPACT, "镜片映射")
	return action
