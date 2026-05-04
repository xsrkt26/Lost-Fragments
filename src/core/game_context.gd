class_name GameContext
extends RefCounted

## 游戏上下文：依赖注入的容器
## 包含了逻辑执行过程中需要访问的所有外部服务和状态管理

var state: Node # 指向 GameState 单例或其他状态节点
var battle: Node # 指向当前 BattleManager
var event_bus: Node # 指向 GlobalEventBus

func _init(p_state: Node, p_battle: Node = null):
	state = p_state
	battle = p_battle
	event_bus = p_state.get_node_or_null("/root/GlobalEventBus")

## 快捷访问方法
func add_score(amount: int):
	if state and state.has_method("add_score"):
		state.add_score(amount)

func change_sanity(amount: int):
	if state:
		if amount > 0:
			state.heal_sanity(amount)
		else:
			state.consume_sanity(abs(amount))
