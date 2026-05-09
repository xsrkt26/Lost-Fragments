class_name TagReactiveEffect
extends ItemEffect

## 标签响应效果：当特定标签的物品被抽到时，自身触发撞击。
## 适用于：小丑鼻子 (废弃物)、草稿纸 (书籍)。

@export var trigger_tag: String = ""

func on_global_item_drawn(new_item: ItemData, my_instance: BackpackManager.ItemInstance, context: GameContext):
	# 检查抽到的物品是否符合标签要求
	if new_item.tags.has(trigger_tag):
		print("[Effect] 感应到匹配标签: ", trigger_tag, "，物品 ", my_instance.data.item_name, " 触发撞击！")
		if context.battle:
			# 使用 call_deferred 确保在当前帧的抽卡结算完毕后再发起新的撞击序列
			context.battle.call_deferred("trigger_impact_at", my_instance.root_pos)
