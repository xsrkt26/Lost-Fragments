class_name PollutionAbsorptionEffect
extends ItemEffect

## 封口试管效果：被撞：吸收冲击能量，自身 +1 污染。
## 该物品应配合 TransmissionMode.NONE 使用，作为能量流的终点。

func on_hit(instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	# 无论外界倍率多大，内部只增加固定 1 层（模拟试管的容纳极限）
	instance.add_pollution(1)
	print("[Effect] 封口试管吸收了冲击，自身污染变为: ", instance.current_pollution)
	
	# 返回一个简单的效果动作，不产生分数（因为它吸收了能量）
	return GameAction.new(GameAction.Type.EFFECT, "吸收污染能量")
