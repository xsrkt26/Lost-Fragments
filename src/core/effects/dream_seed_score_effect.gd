class_name DreamSeedScoreEffect
extends ItemEffect

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var level = max(1, instance.dream_seed_level)
	var score_multiplier = _score_multiplier_for_level(level)
	var action = GameAction.new(GameAction.Type.NUMERIC, "梦境之种结算")
	action.value = {"type": "score", "amount": level * score_multiplier * multiplier}
	return action

func _score_multiplier_for_level(level: int) -> int:
	if level >= 30:
		return 8
	if level >= 20:
		return 4
	if level >= 10:
		return 2
	return 1
