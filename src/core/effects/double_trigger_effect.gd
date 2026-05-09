class_name DoubleTriggerEffect
extends ItemEffect

## 双重触发效果：数学课本特有。被撞击的书籍额外触发一次。

func on_hit(_instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	# 数学课本主要作为功能发射器
	return null

## 在撞击结束后，如果命中了目标，则发起第二次手动效果触发
func execute_after_hit(hit_instance: BackpackManager.ItemInstance, source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, context: GameContext, actions: Array[GameAction]):
	# 检查标签：只对书籍生效
	if hit_instance.data.tags.has("书籍"):
		print("[Effect] 数学课本触发书籍联动！手动执行二次效果: ", hit_instance.data.item_name)
		
		# 计算该物品当前的污染倍率
		var multiplier = 1 + hit_instance.current_pollution
		
		# 直接遍历执行目标的所有效果，模拟“再撞一次”
		for effect in hit_instance.data.effects:
			# 排除掉 DoubleTriggerEffect 自身，防止两本书互撞导致死循环
			if effect is DoubleTriggerEffect:
				continue
				
			var extra_action = effect.on_hit(hit_instance, source_instance, resolver, context, multiplier)
			if extra_action:
				if extra_action.item_instance == null:
					extra_action.item_instance = hit_instance
				actions.append(extra_action)
