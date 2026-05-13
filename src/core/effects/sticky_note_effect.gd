class_name StickyNoteEffect
extends ItemEffect

@export var score_per_3_pollution: int = 10

var rewarded_sets: int = 0

func on_pollution_added(instance: BackpackManager.ItemInstance, _added: int, old_pollution: int, _resolver: ImpactResolver, _context: GameContext) -> GameAction:
	var old_sets = floori(old_pollution / 3.0)
	var new_sets = floori(instance.current_pollution / 3.0)
	var payable_sets = max(0, new_sets - max(old_sets, rewarded_sets))
	rewarded_sets = max(rewarded_sets, new_sets)

	if payable_sets <= 0:
		return null

	var action = GameAction.new(GameAction.Type.NUMERIC, "Sticky note pollution bonus")
	action.value = {"type": "score", "amount": payable_sets * score_per_3_pollution}
	return action
