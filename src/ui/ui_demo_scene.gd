extends Node2D

## 演示场景：展示背包网格和物品 UI

@onready var backpack_ui = $CanvasLayer/BackpackUI

func _ready():
	# 1. 创建管理逻辑
	var manager = BackpackManager.new()
	manager.setup_grid(5, 5)
	
	# 2. 初始化 UI
	backpack_ui.setup(manager)
	
	# 3. 创建几个带效果的物品
	create_test_item("棒球", ItemData.Direction.RIGHT, [ScoreEffect.new()])
	create_test_item("诅咒箱", ItemData.Direction.DOWN, [SanityEffect.new()])

func create_test_item(item_name: String, dir: ItemData.Direction, effects: Array):
	var item_ui_scene = load("res://src/ui/item/item_ui.tscn")
	var card = item_ui_scene.instantiate()
	
	var data = ItemData.new()
	data.item_name = item_name
	data.direction = dir
	for e in effects:
		data.effects.append(e)
	
	# 将物品放在屏幕右侧的“暂存区”，并加到 CanvasLayer 下
	$CanvasLayer.add_child(card)
	card.setup(data)
	card.position = Vector2(450, 100 + get_child_count() * 80)
	
	# 连接拖拽信号
	card.dropped.connect(func(drop_pos): backpack_ui.handle_item_dropped(card, drop_pos))

	print("创建物品: ", item_name, "，请尝试将其拖入左侧背包。")
