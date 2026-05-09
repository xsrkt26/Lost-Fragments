class_name InkCartridgeEffect
extends ItemEffect

## 夜色墨盒效果：被撞：+2分。
## 感应：每当抽到“书籍”或“废弃物”物品时，自身 +1 污染。

@export var score_amount: int = 2

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var action = GameAction.new(GameAction.Type.NUMERIC, "墨水溅射")
	action.value = {"type": "score", "amount": score_amount * multiplier}
	return action

func on_global_item_drawn(new_item: ItemData, my_instance: BackpackManager.ItemInstance, _context: GameContext):
	# 检查标签感应：书籍 或 废弃物 (纸团属于废弃物)
	if new_item.tags.has("书籍") or new_item.tags.has("废弃物"):
		my_instance.add_pollution(1)
		print("[Effect] 夜色墨盒感应到 ", new_item.item_name, "，自身污染 +1. 当前: ", my_instance.current_pollution)
