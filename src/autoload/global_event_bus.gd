extends Node

## 全局事件总线 (Autoload: GlobalEventBus)
## 采用弱类型定义以确保加载优先级和稳定性

# 当任何物品被撞击时发出
# instance/source 类型通常为 BackpackManager.ItemInstance
signal item_impacted(instance, source)

# 当有新物品被抽到时发出
# item_data 类型为 ItemData
signal item_drawn(item_data)

# 当物品被丢弃到垃圾桶时发出
signal item_discarded(item_data)

# 当物品在背包中成功放置时发出
signal item_placed(instance)
