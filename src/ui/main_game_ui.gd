extends Control

## 主游戏 UI 控制器：负责将布局中的各个部分与逻辑层连接

@onready var backpack_ui = $HBoxContainer/RightPanel/BackpackArea/Center/BackpackUI
@onready var sanity_label = $HBoxContainer/LeftPanel/BottomRow/SanityArea/VBox/Value
@onready var draw_button = $HBoxContainer/LeftPanel/DrawArea/DrawButton
@onready var trash_bin = $HBoxContainer/RightPanel/OrnamentsArea/TrashBin

var battle_manager: BattleManager

func _ready():
	print("[MainGameUI] 节点就绪")
	# 容错：如果 0.1 秒后还没有被外部 setup，则尝试自动初始化（仅用于直接运行该场景调试）
	await get_tree().create_timer(0.1).timeout
	if battle_manager == null:
		print("[MainGameUI] 检测到未进行外部 setup，正在启动自初始化流程...")
		var mock_manager = BattleManager.new()
		add_child(mock_manager)
		setup(mock_manager)

func setup(p_battle_manager: BattleManager):
	print("[MainGameUI] 正在执行 setup...")
	battle_manager = p_battle_manager
	
	if backpack_ui == null:
		print("[MainGameUI] 错误: backpack_ui 引用为空！")
	
	battle_manager.backpack_ui = backpack_ui
	
	# 连接逻辑信号
	battle_manager.item_drawn.connect(_on_item_drawn)
	backpack_ui.item_dropped_on_grid.connect(battle_manager.request_place_item)
	
	# 连接状态更新信号
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.sanity_changed.connect(_on_sanity_changed)
		gs.score_changed.connect(_on_score_changed)
		_update_stats_display(gs.current_sanity, gs.current_score)

func _on_item_drawn(item_data: ItemData):
	var item_ui_scene = load("res://src/ui/item/item_ui.tscn")
	var card = item_ui_scene.instantiate()
	
	# 将卡牌放入 UI 层
	add_child(card)
	card.setup(item_data)
	
	# 初始位置：抽卡区中心
	var draw_center = $HBoxContainer/LeftPanel/DrawArea.global_position + $HBoxContainer/LeftPanel/DrawArea.size / 2.0
	card.global_position = draw_center - card.custom_minimum_size / 2.0
	
	# 连接拖拽信号
	card.dropped.connect(func(drop_pos): _handle_item_dropped(card, drop_pos))

func _handle_item_dropped(item_ui: Control, drop_pos: Vector2):
	# 1. 检查是否掉落在垃圾桶 (使用 global_rect 判定)
	if trash_bin.get_global_rect().has_point(drop_pos):
		print("[UI] 检测到物品掉入垃圾桶: ", item_ui.item_data.item_name)
		if battle_manager:
			battle_manager.request_discard_item(item_ui)
		return
	
	# 2. 否则按原逻辑交给背包
	backpack_ui.handle_item_dropped(item_ui, drop_pos)

func _on_draw_button_pressed():
	# 触发抽卡逻辑
	if battle_manager:
		battle_manager.request_draw()

func _on_sanity_changed(new_val):
	var gs = get_node("/root/GameState")
	if gs:
		_update_stats_display(new_val, gs.current_score)

func _on_score_changed(new_val):
	var gs = get_node("/root/GameState")
	if gs:
		_update_stats_display(gs.current_sanity, new_val)

func _update_stats_display(san, score):
	if sanity_label:
		sanity_label.text = str(san) + " / " + str(score)
