class_name TagReactiveEffect
extends ItemEffect

## 标签响应效果：监听到特定标签被抽到时，触发自身撞击。
## 适用于：小丑鼻子 (废弃物)、草稿纸 (书籍)。

@export var trigger_tag: String = ""

func on_draw(item_data: ItemData, context: GameContext) -> GameAction:
	var bus = context.state.get_node_or_null("/root/GlobalEventBus")
	if bus:
		if not bus.item_drawn.is_connected(_on_item_drawn):
			bus.item_drawn.connect(_on_item_drawn.bind(item_data, context))
	return null

func _on_item_drawn(drawn_item_data: ItemData, my_data: ItemData, context: GameContext):
	# 检查抽到的物品是否符合标签要求
	if drawn_item_data.tags.has(trigger_tag):
		print("[Effect] 感应到匹配标签: ", trigger_tag, "，物品 ", my_data.item_name, " 触发撞击！")
		if context.battle:
			var my_pos = context.battle._find_item_old_pos(my_data)
			if my_pos != Vector2i(-1, -1):
				context.battle.call_deferred("trigger_impact_at", my_pos)
