class_name ReplicationEffect
extends ItemEffect

## 复制效果：抽到时将自身的一个复制品放入背包空位

func on_draw(item_data: ItemData, context: GameContext) -> GameAction:
	var manager = context.battle.backpack_manager
	var ui = context.battle.backpack_ui
	
	# 寻找空位
	var target_pos = manager.find_available_pos(item_data)
	if target_pos != Vector2i(-1, -1):
		print("[Effect] 纸团效果：发现空位 ", target_pos, "，自动复制一个。")
		
		# 1. 逻辑层放置副本
		var duplicate_data = item_data.duplicate(true)
		duplicate_data.runtime_id = randi()
		manager.place_item(duplicate_data, target_pos)
		
		# 2. 表现层实例化 UI (模仿 draw 的过程)
		if ui:
			# 为了让 UI 正确显示，我们需要像主 UI 那样实例化一个卡牌
			# 这里直接借用信号可能更优雅，但为了即时性，我们通知 battle_manager 发出一个 item_drawn 信号也可以
			# 但最直接的是让 UI 增加一个视觉项
			# 这里简单的做法是：告诉 battle_manager 再给一个 item
			context.battle.item_drawn.emit(duplicate_data)
			
	return null
