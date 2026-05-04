class_name ItemEffect
extends Resource

## 物品效果基类 (Resource 版)
## 所有的具体效果（加分、回血、炸裂等）都应继承此类并重写 execute 方法

## 执行效果并返回生成的动作对象，通过 context 访问全局服务
func execute(_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext) -> GameAction:
	# 在子类中实现逻辑
	return null
