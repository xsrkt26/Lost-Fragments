extends Node2D

## 演示场景：展示重构后的 BattleManager 架构

@onready var backpack_ui = $CanvasLayer/BackpackUI
var battle_manager: BattleManager

func _ready():
	# 1. 创建逻辑中枢 BattleManager
	battle_manager = BattleManager.new()
	add_child(battle_manager)

	# 2. 注入依赖
	battle_manager.backpack_ui = backpack_ui
	# BattleManager 会在 _ready 中自动调用 backpack_ui.setup()

	# 3. 建立信号连接：UI 上报操作 -> Manager 执行逻辑
	backpack_ui.item_dropped_on_grid.connect(battle_manager.request_place_item)

	# 4. 创建几个带效果的物品
	create_test_item("棒球", ItemData.Direction.RIGHT, [ScoreEffect.new()])
	create_test_item("诅咒箱", ItemData.Direction.DOWN, [SanityEffect.new()])

func create_test_item(item_name: String, dir: ItemData.Direction, effects: Array):
	var item_ui_scene = load("res://src/ui/item/item_ui.tscn")
	var card = item_ui_scene.instantiate()

	var data = ItemData.new()
	data.item_name = item_name
	data.direction = dir
	data.runtime_id = randi() # 分配一个初始随机 ID
	for e in effects:
		data.effects.append(e)

	# 初始放在屏幕右侧
	$CanvasLayer.add_child(card)
	card.setup(data)
	card.position = Vector2(450, 100 + get_child_count() * 80)

	# 连接拖拽信号给 UI 层
	card.dropped.connect(func(drop_pos): backpack_ui.handle_item_dropped(card, drop_pos))
