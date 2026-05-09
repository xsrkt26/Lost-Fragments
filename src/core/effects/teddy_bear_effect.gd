class_name TeddyBearEffect
extends ItemEffect

## 伤心泰迪熊效果：被撞：+10分；若没有撞到别人，自身+2污染。

@export var base_score: int = 10
@export var loneliness_pollution: int = 2

func on_hit(_instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, multiplier: int = 1) -> GameAction:
	var action = GameAction.new(GameAction.Type.NUMERIC, "泰迪熊给予安慰")
	action.value = {"type": "score", "amount": base_score * multiplier}
	return action

func after_impact(instance: BackpackManager.ItemInstance, did_hit_others: bool, _resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	if not did_hit_others:
		instance.add_pollution(loneliness_pollution)
		print("[Effect] 伤心泰迪熊没撞到别人，感到孤独，污染 +", loneliness_pollution)
		return GameAction.new(GameAction.Type.EFFECT, "泰迪熊感到孤独")
	return null
