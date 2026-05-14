class_name SanityEffect
extends ItemEffect

## 修改梦值的效果
@export var sanity_change: int = -5

func on_hit(_instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	var action = GameAction.new(GameAction.Type.NUMERIC, "改变梦值")
	action.value = {"type": "sanity", "amount": sanity_change * _multiplier}
	return action
