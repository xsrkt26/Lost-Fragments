extends Node

## 运行管理器：单局游戏的数据源 (Source of Truth)
## 负责跨场景保存金钱、卡组、深度等核心数据。

# --- 核心信号 ---
signal run_started
signal run_finished(victory: bool)
signal shards_changed(new_amount: int)
signal deck_changed(new_deck: Array)

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
var is_run_active: bool = false

@onready var saver = SaveManager.new()

func _ready():
	add_child(saver)
	# 自动尝试恢复存档
	if saver.has_save():
		deserialize_run(saver.load_run())

## 开启新的一局
func start_new_run():
	print("[RunManager] 开启新的一局...")
	current_shards = INITIAL_SHARDS
	current_deck = INITIAL_DECK.duplicate()
	current_ornaments = []
	current_depth = 1
	is_run_active = true
	
	save_current_state()
	run_started.emit()

## 胜利结算
func win_battle(reward_shards: int):
	current_shards += reward_shards
	current_depth += 1
	print("[RunManager] 战斗胜利! 获得碎片: ", reward_shards, " | 当前深度: ", current_depth)
	shards_changed.emit(current_shards)
	save_current_state()

## 失败结算 (彻底重来)
func fail_run():
	print("[RunManager] 梦境惊醒... 运行结束。")
	is_run_active = false
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

## 存档序列化
func save_current_state():
	if not is_run_active: return
	saver.save_run(serialize_run())

func serialize_run() -> Dictionary:
	return {
		"shards": current_shards,
		"deck": current_deck,
		"ornaments": current_ornaments,
		"depth": current_depth,
		"is_active": is_run_active
	}

func deserialize_run(data: Dictionary):
	if data.is_empty(): return
	current_shards = data.get("shards", INITIAL_SHARDS)
	current_deck = Array(data.get("deck", INITIAL_DECK))
	current_ornaments = Array(data.get("ornaments", []))
	current_depth = data.get("depth", 1)
	is_run_active = data.get("is_active", false)
	print("[RunManager] 已从存档恢复状态")
