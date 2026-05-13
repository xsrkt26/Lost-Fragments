class_name ExpiredMedicineEffect
extends ItemEffect

@export var score_amount: int = 5
@export var self_pollution: int = 3

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	resolver.add_pollution(instance, self_pollution)

	var action = GameAction.new(GameAction.Type.NUMERIC, "Expired medicine score")
	action.value = {"type": "score", "amount": score_amount * multiplier}
	return action
