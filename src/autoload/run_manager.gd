extends Node

## 运行管理器：单局游戏的数据源 (Source of Truth)
## 负责跨场景保存金钱、卡组、深度等核心数据。

const RouteConfig = preload("res://src/core/route/route_config.gd")

# --- 核心信号 ---
signal run_started
signal run_finished(victory: bool)
signal shards_changed(new_amount: int)
signal deck_changed(new_deck: Array)
signal route_changed(current_act: int, route_index: int, current_node: Dictionary)

# --- 配置项 ---
const INITIAL_SHARDS = 10
const INITIAL_DECK: Array[String] = [
	"paper_ball", "paper_ball", "paper_ball", "paper_ball", "paper_ball",
	"alarm_clock", "alarm_clock", "alarm_clock", "alarm_clock", "alarm_clock",
	"tin_can", "tin_can", "tin_can", "tin_can", "tin_can"
]

# --- 状态数据 ---
var current_shards: int = INITIAL_SHARDS
var current_deck: Array[String] = INITIAL_DECK.duplicate()
var current_ornaments: Array[String] = []
var current_depth: int = 1
var current_route_id: String = RouteConfig.DEFAULT_ROUTE_ID
var current_act: int = 1
var current_route_index: int = 0
var completed_route_nodes: Array[int] = []
var is_run_active: bool = false

var saver: SaveManager = null

func _ready():
	if saver == null:
		saver = SaveManager.new()
	add_child(saver)
	# 自动尝试恢复存档
	if saver.has_save():
		deserialize_run(saver.load_run())

## 开启新的一局
func start_new_run():
	print("[RunManager] 开启新的一局...")
	
	# 核心修复：重置全局战斗状态 (San值、分数等)
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.reset_game()
	
	current_shards = INITIAL_SHARDS
	current_deck = INITIAL_DECK.duplicate()
	current_ornaments = []
	current_depth = 1
	reset_route_progress()
	is_run_active = true
	
	save_current_state()
	run_started.emit()
	_emit_route_changed()

## 胜利结算
func win_battle(reward_shards: int):
	current_shards += reward_shards
	current_depth += 1
	print("[RunManager] 战斗胜利! 获得碎片: ", reward_shards, " | 当前深度: ", current_depth)
	if RouteConfig.is_battle_node_type(get_current_route_node_type()):
		advance_route_node()
	shards_changed.emit(current_shards)
	save_current_state()

## 失败结算 (彻底重来)
func fail_run():
	print("[RunManager] 梦境惊醒... 运行结束。")
	is_run_active = false
	if saver:
		saver.delete_save()
	run_finished.emit(false)

## 购买卡牌
func add_to_deck(item_id: String, cost: int):
	if current_shards >= cost:
		current_shards -= cost
		current_deck.append(item_id)
		print("[RunManager] 购买成功: ", item_id, " | 剩余碎片: ", current_shards)
		shards_changed.emit(current_shards)
		deck_changed.emit(current_deck)
		save_current_state()
		return true
	return false

func reset_route_progress(route_id: String = RouteConfig.DEFAULT_ROUTE_ID):
	current_route_id = RouteConfig.normalize_route_id(route_id)
	current_act = 1
	current_route_index = 0
	completed_route_nodes = []
	_emit_route_changed()

func get_route_nodes() -> Array:
	return RouteConfig.get_route_nodes(current_route_id)

func get_current_route_node() -> Dictionary:
	return RouteConfig.get_route_node(current_route_id, current_route_index)

func get_current_route_node_type() -> String:
	return get_current_route_node().get("type", "")

func can_enter_route_node(index: int) -> bool:
	return is_run_active and index == current_route_index and not get_current_route_node().is_empty()

func get_scene_type_for_node(node: Dictionary) -> int:
	var node_type = node.get("type", "")
	match node_type:
		RouteConfig.NODE_BATTLE, RouteConfig.NODE_BOSS_BATTLE:
			return GlobalScene.SceneType.BATTLE
		RouteConfig.NODE_SHOP:
			return GlobalScene.SceneType.SHOP
		RouteConfig.NODE_EVENT:
			return GlobalScene.SceneType.EVENT
	return GlobalScene.SceneType.HUB

func get_current_node_scene_type() -> int:
	return get_scene_type_for_node(get_current_route_node())

func advance_route_node(expected_node_id: String = "") -> Dictionary:
	if not is_run_active:
		return {}
	var current_node = get_current_route_node()
	if current_node.is_empty():
		return {}
	if expected_node_id != "" and current_node.get("id", "") != expected_node_id:
		return {}
	if not completed_route_nodes.has(current_route_index):
		completed_route_nodes.append(current_route_index)
	current_route_index += 1

	if current_route_index >= RouteConfig.get_route_size(current_route_id):
		current_act += 1
		current_route_index = 0
		completed_route_nodes = []

	save_current_state()
	_emit_route_changed()
	return current_node

func _emit_route_changed():
	route_changed.emit(current_act, current_route_index, get_current_route_node())

## 存档序列化
func save_current_state():
	if not is_run_active: return
	if saver:
		saver.save_run(serialize_run())

func serialize_run() -> Dictionary:
	return {
		"shards": current_shards,
		"deck": current_deck,
		"ornaments": current_ornaments,
		"depth": current_depth,
		"route_id": current_route_id,
		"act": current_act,
		"route_index": current_route_index,
		"completed_route_nodes": completed_route_nodes,
		"is_active": is_run_active
	}

func deserialize_run(data: Dictionary):
	if data.is_empty(): return
	current_shards = data.get("shards", INITIAL_SHARDS)
	current_deck = _to_string_array(data.get("deck", INITIAL_DECK))
	current_ornaments = _to_string_array(data.get("ornaments", []))
	current_depth = data.get("depth", 1)
	current_route_id = RouteConfig.normalize_route_id(data.get("route_id", RouteConfig.DEFAULT_ROUTE_ID))
	current_act = max(1, int(data.get("act", 1)))
	current_route_index = clampi(int(data.get("route_index", 0)), 0, max(0, RouteConfig.get_route_size(current_route_id) - 1))
	completed_route_nodes = []
	for index in Array(data.get("completed_route_nodes", [])):
		completed_route_nodes.append(int(index))
	is_run_active = data.get("is_active", true)
	_emit_route_changed()

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for entry in Array(value):
		result.append(str(entry))
	return result
## 获取当前深度的目标分数
func get_target_score() -> int:
	# 简单逻辑：第一关 50，随后每关递增
	return 30 + (current_depth * 20)
