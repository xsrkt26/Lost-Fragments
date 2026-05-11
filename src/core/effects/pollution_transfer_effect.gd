class_name PollutionTransferEffect
extends ItemEffect

## 污染转移效果（黑水瓶）：被撞：将自身全部污染转移给路径上的下一个物品。
## 若下一个物品没有“水”标签，该物品额外 +1 污染。

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	var backpack = resolver.backpack
	var next_pos = backpack.get_next_item_pos(instance.root_pos, instance.data.direction)
	
	if next_pos != Vector2i(-1, -1):
		var target = backpack.grid[next_pos]
		var transfer_amount = instance.current_pollution
		
		# 转移污染
		target.add_pollution(transfer_amount)
		# 非水标签惩罚
		if not target.data.tags.has("水"):
			target.add_pollution(1)
			print("[Effect] 黑水瓶向非水物品 ", target.data.item_name, " 倾倒，污染 +", transfer_amount + 1)
		else:
			print("[Effect] 黑水瓶向水系物品 ", target.data.item_name, " 转移，污染 +", transfer_amount)
			
		instance.current_pollution = 0
		return GameAction.new(GameAction.Type.EFFECT, "黑水倾倒")
		
	return null
