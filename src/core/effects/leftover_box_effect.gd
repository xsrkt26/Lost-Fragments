class_name LeftoverBoxEffect
extends ItemEffect

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	var affected_count = 0
	for neighbor in resolver.backpack.get_neighbor_instances(instance):
		if neighbor.data.tags.has("废弃物"):
			resolver.add_pollution(neighbor, 1)
			affected_count += 1

	if affected_count == 0:
		return null
	return GameAction.new(GameAction.Type.EFFECT, "Leftover box adds pollution")
