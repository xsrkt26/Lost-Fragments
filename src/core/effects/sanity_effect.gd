class_name SanityEffect
extends ItemEffect

## 修改 San 值的效果
@export var sanity_change: int = -5

func execute(_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver) -> GameAction:
	var action = GameAction.new(GameAction.Type.NUMERIC, "改变San值")
	action.value = {"type": "sanity", "amount": sanity_change}
	return action
