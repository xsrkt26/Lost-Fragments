class_name MechanicalItemEffect
extends ItemEffect

@export var effect_id: String = ""

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var summary = resolver.get_current_resolution_summary()
	var amount = 0
	match effect_id:
		"small_gear":
			amount = 3
			if int(summary.get("mechanical_hit_count", 0)) >= 2:
				amount += 2
		"transmission_belt":
			amount = 4
		"brake_pad":
			amount = 8
		"gear_rack":
			amount = min(int(summary.get("mechanical_hit_count", 0)), 10)
	if amount <= 0:
		return null
	return _score_action(instance, amount * multiplier)

func after_impact(instance: BackpackManager.ItemInstance, did_hit_others: bool, _resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var amount = 0
	match effect_id:
		"transmission_belt":
			if did_hit_others:
				amount = 3
		"gear_rack":
			if did_hit_others:
				amount = 4
		"crankshaft":
			if did_hit_others:
				amount = 10
	if amount <= 0:
		return null
	return _score_action(instance, amount * multiplier)

func after_resolution(instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var summary = resolver.get_current_resolution_summary()
	var hit_count = int(summary.get("hit_count", 0))
	var mechanical_hit_count = int(summary.get("mechanical_hit_count", 0))
	var turn_count = int(summary.get("turn_transmission_count", 0))
	var bidirectional_count = int(summary.get("bidirectional_transmission_count", 0))
	var amount = 0
	match effect_id:
		"differential":
			amount = mechanical_hit_count * 2
			if turn_count >= 2:
				amount += 10
		"energy_flywheel":
			amount = min(floori(float(mechanical_hit_count) / 3.0), 2) * 12
		"counting_wheel":
			if hit_count >= 9:
				amount = 32
			elif hit_count >= 6:
				amount = 18
		"central_engine":
			if mechanical_hit_count >= 10:
				amount = 60
			if turn_count >= 3:
				amount += 30
		"terminal_computer":
			amount = min(mechanical_hit_count * 3, 45)
			if bidirectional_count > 0:
				amount += 15
	if amount <= 0:
		return null
	return _score_action(instance, amount * multiplier)

func _score_action(instance: BackpackManager.ItemInstance, amount: int) -> GameAction:
	var action = GameAction.new(GameAction.Type.NUMERIC, "机械结算")
	action.item_instance = instance
	action.value = {"type": "score", "amount": amount}
	return action
