class_name PlaceholderEffect
extends ItemEffect

## 占位符效果：用于尚未实现的卡牌

func on_hit(instance: BackpackManager.ItemInstance, _source: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	print("[Effect] 触发了占位符效果 (ID: ", instance.data.id, ")")
	return null
