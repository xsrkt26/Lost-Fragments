class_name ItemEffect
extends Resource

## 物品效果基类
## 定义了不同的触发入口，子类根据需要重写相应方法

## 被撞击时触发 (默认行为)
## source_instance: 发起撞击的物品实例 (如果是初始撞击则可能为 null)
## multiplier: 效果倍率，默认为 1。用于支持“污染流”等倍增机制。
func on_hit(_instance: BackpackManager.ItemInstance, _source_instance: BackpackManager.ItemInstance, _resolver: ImpactResolver, _context: GameContext, _multiplier: int = 1) -> GameAction:
	return null

## 抽到物品时触发
func on_draw(_item_data: ItemData, _context: GameContext) -> GameAction:
	return null

## 丢弃物品时触发
func on_discard(_item_data: ItemData, _context: GameContext) -> GameAction:
	return null

## 装备为饰品时触发
func on_equip(_item_data: ItemData, _context: GameContext):
	pass

## 卸下饰品时触发
func on_unequip(_item_data: ItemData, _context: GameContext):
	pass

## 当其他任何物品被抽到时触发（由管理器统一调用，避免连接泄露）
func on_global_item_drawn(_new_item: ItemData, _my_instance: BackpackManager.ItemInstance, _context: GameContext):
	pass

## 兼容旧代码的 execute 方法，默认指向 on_hit
func execute(instance, resolver, context, multiplier: int = 1) -> GameAction:
	return on_hit(instance, null, resolver, context, multiplier)
