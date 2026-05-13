extends Node

## 全局事件总线 (Autoload: GlobalEventBus)
## 采用弱类型定义以确保加载优先级和稳定性

# 当任何物品被撞击时发出
# instance/source 类型通常为 BackpackManager.ItemInstance
@warning_ignore("unused_signal")
signal item_impacted(instance, source)

# 当有新物品被抽到时发出
# item_data 类型为 ItemData
@warning_ignore("unused_signal")
signal item_drawn(item_data)

# 当物品被丢弃到垃圾桶时发出
@warning_ignore("unused_signal")
signal item_discarded(item_data)

# 当物品在背包中成功放置时发出
@warning_ignore("unused_signal")
signal item_placed(instance)

# 当播种生成梦境之种时发出
@warning_ignore("unused_signal")
signal seed_sown(instance)

# 当梦境之种升级时发出
@warning_ignore("unused_signal")
signal seed_upgraded(instance, old_level: int, new_level: int)

# 当播种目标不可用时发出
@warning_ignore("unused_signal")
signal seed_sow_failed(source, direction: int)

# 当污染层数变化时发出
@warning_ignore("unused_signal")
signal pollution_changed(instance, old_value: int, new_value: int)
