class_name IsolationBoxEffect
extends ItemEffect

## 隔离箱：(被动) 污染层数导致的 San 值扣除效应 -1

@export var reduction_amount: int = 1

func on_equip(_item_data: ItemData, _context: GameContext):
	if _context and _context.state:
		var current = _context.state.get_modifier("pollution_san_reduction", 0)
		_context.state.set_modifier("pollution_san_reduction", current + reduction_amount)
		print("[Effect] 隔离箱已装备，污染反噬减少 ", reduction_amount)

func on_unequip(_item_data: ItemData, _context: GameContext):
	if _context and _context.state:
		var current = _context.state.get_modifier("pollution_san_reduction", 0)
		_context.state.set_modifier("pollution_san_reduction", max(0, current - reduction_amount))
		print("[Effect] 隔离箱已卸下")
