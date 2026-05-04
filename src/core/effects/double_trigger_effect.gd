class_name DoubleTriggerEffect
extends ItemEffect

## 双重触发效果：数学课本特有。被撞击的书籍额外触发一次。

func on_hit(instance, source_instance, resolver, context) -> GameAction:
	# 数学课本本身的加分逻辑（如果有的话，这里可以加上）
	# 根据策划案，数学课本主要是功能性的
	
	print("[Effect] 数学课本触发！正在寻找下一个书籍目标...")
	return null

# 注意：数学课本的“只能撞击书籍”逻辑现在由 ItemData.hit_filter_tags = ["书籍"] 自动处理
# 但“额外触发一次”需要我们在这里手动干预后续目标
func execute_after_hit(hit_instance, source_instance, resolver, context, actions: Array[GameAction]):
	if hit_instance.data.tags.has("书籍"):
		print("[Effect] 书籍联动！额外触发一次: ", hit_instance.data.item_name)
		for effect in hit_instance.data.effects:
			var extra_action = effect.on_hit(hit_instance, source_instance, resolver, context)
			if extra_action:
				if extra_action.item_instance == null:
					extra_action.item_instance = hit_instance
				actions.append(extra_action)
