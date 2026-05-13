class_name TeddyBearEffect
extends ItemEffect

@export var base_score: int = 10
@export var loneliness_pollution: int = 2

func on_hit(_instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var action = GameAction.new(GameAction.Type.NUMERIC, "Sad teddy bear score")
	action.value = {"type": "score", "amount": base_score * multiplier}
	return action

func after_impact(instance: BackpackManager.ItemInstance, did_hit_others: bool, resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	if did_hit_others:
		return null
	resolver.add_pollution(instance, loneliness_pollution)
	return GameAction.new(GameAction.Type.EFFECT, "Sad teddy bear gains pollution")
