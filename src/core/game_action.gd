class_name GameAction
extends RefCounted

## 游戏动作基类：用于记录逻辑链条中的每一个离散事件
## 表现层会根据这些 Action 按顺序播放动画

enum Type { 
	NONE,
	IMPACT,      # A 撞到了 B
	EFFECT,      # 触发了某个物品的效果
	NUMERIC,     # 分数或梦值发生变动
	ANIMATION    # 纯表现动画
}

var type: Type = Type.NONE
var source_node: Node        # 发起动作的物品 UI 节点
var target_node: Node        # 受影响的物品 UI 节点
var item_instance: Variant   # 逻辑层物品实例 (BackpackManager.ItemInstance)
var value: Variant           # 携带的数值数据（如分数改变量）
var description: String = ""

func _init(p_type: Type, p_desc: String = ""):
	type = p_type
	description = p_desc
