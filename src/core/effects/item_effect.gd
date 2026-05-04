class_name ItemEffect
extends Resource

## 物品效果基类
## 定义了不同的触发入口，子类根据需要重写相应方法

## 被撞击时触发 (默认行为)
## source_instance: 发起撞击的物品实例 (如果是初始撞击则可能为 null)
func on_hit(_instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext) -> GameAction:
	return null

## 抽到物品时触发
func on_draw(_item_data: ItemData, _context: GameContext) -> GameAction:
	return null

## 丢弃物品时触发
func on_discard(_item_data: ItemData, _context: GameContext) -> GameAction:
	return null

## 兼容旧代码的 execute 方法，默认指向 on_hit
func execute(instance, resolver, context) -> GameAction:
	return on_hit(instance, null, resolver, context)
