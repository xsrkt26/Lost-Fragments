class_name LeftoverBoxEffect
extends ItemEffect

## 剩饭盒效果：被撞：相邻所有废弃物+1污染。

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	var backpack = _resolver.backpack
	var neighbors = backpack.get_neighbor_instances(instance)
	var affected_count = 0
	
	for neighbor in neighbors:
		if neighbor.data.tags.has("废弃物"):
			neighbor.add_pollution(1)
			affected_count += 1
			print("[Effect] 剩饭盒感染邻居: ", neighbor.data.item_name, " 在 ", neighbor.root_pos)
			
	if affected_count > 0:
		return GameAction.new(GameAction.Type.EFFECT, "剩饭盒异味扩散")
		
	return null
