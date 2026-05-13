class_name MimicEffect
extends ItemEffect

@export var base_score: int = 5

func on_hit(instance: BackpackManager.ItemInstance, source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, context: GameContext, multiplier: int = 1) -> GameAction:
	if source_instance:
		for effect in source_instance.data.effects:
			if effect is MimicEffect:
				continue
			var copied_action = effect.on_hit(instance, source_instance, resolver, context, multiplier)
			if copied_action:
				if copied_action.item_instance == null:
					copied_action.item_instance = instance
				resolver.actions_history.append(copied_action)

	var action = GameAction.new(GameAction.Type.NUMERIC, "Cracked lens score")
	action.value = {"type": "score", "amount": base_score * multiplier}
	return action
