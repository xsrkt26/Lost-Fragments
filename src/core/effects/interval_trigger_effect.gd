class_name IntervalTriggerEffect
extends ItemEffect

## 间隔触发效果：每捕梦 N 次，若满足条件则自动触发一次撞击。
## 适用于：污水泵（每 3 次，需有污染）

@export var interval: int = 3
@export var require_pollution: bool = true

func on_global_item_drawn(_new_item: ItemData, my_instance: BackpackManager.ItemInstance, context: GameContext):
	if context.battle == null:
		return
		
	var draw_count = context.battle.draw_count
	
	# 检查频率
	if draw_count > 0 and draw_count % interval == 0:
		# 检查条件：必须有污染
		if require_pollution and my_instance.current_pollution <= 0:
			print("[Effect] ", my_instance.data.item_name, " 达到触发间隔，但因没有污染而跳过。")
			return
			
		print("[Effect] ", my_instance.data.item_name, " 达到触发间隔，正在自动发起撞击！")
		# 自动发起撞击
		context.battle.call_deferred("trigger_impact_at", my_instance.root_pos)
