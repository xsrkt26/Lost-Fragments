class_name PaperBallEffect
extends ItemEffect

@export var score_amount: int = 2
@export var pollution_amount: int = 1

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	resolver.add_pollution(instance, pollution_amount)

	var action = GameAction.new(GameAction.Type.NUMERIC, "Paper ball score")
	action.value = {"type": "score", "amount": score_amount * multiplier}
	return action
