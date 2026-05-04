class_name SanityEffect
extends ItemEffect

## 修改 San 值的效果
@export var sanity_change: int = -5

func on_hit(_instance, _source_instance, _resolver, _context) -> GameAction:
	var action = GameAction.new(GameAction.Type.NUMERIC, "改变San值")
	action.value = {"type": "sanity", "amount": sanity_change}
	
	if _context and _context.state:
		_context.state.consume_sanity(-sanity_change)
		
	return action
