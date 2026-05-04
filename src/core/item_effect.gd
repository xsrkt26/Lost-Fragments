class_name ItemEffect
extends Resource

## 物品效果基类 (Resource 版)
## 所有的具体效果（加分、回血、炸裂等）都应继承此类并重写 execute 方法

## 执行效果并返回生成的动作对象，但不立即修改全局状态
func execute(_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver) -> GameAction:
	# 在子类中实现逻辑，返回一个 GameAction 对象
	return null
