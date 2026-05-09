extends Control

## 主游戏 UI 控制器：负责将布局中的各个部分与逻辑层连接

@onready var backpack_ui = $ContentLayer/GridPanel/BackpackUI
@onready var sanity_label = $ContentLayer/StatsPanel/Label
@onready var draw_button = $ContentLayer/DreamcatcherPanel/DrawButton
@onready var trash_bin = $ContentLayer/GridPanel/TrashBin
@onready var ornaments_area = $ContentLayer/OrnamentsPanel/Slots

var battle_manager: BattleManager

func _ready():
	print("[MainGameUI Debug] UI初始化开始...")
	# 检查关键节点是否成功获取
	if draw_button:
		print("[MainGameUI Debug] 发现抽卡按钮节点: ", draw_button.get_path())
		print("[MainGameUI Debug] 按钮当前 Mouse Filter: ", draw_button.mouse_filter)
		print("[MainGameUI Debug] 按钮当前尺寸: ", draw_button.size)
		# 强制确保按钮是可见的且接收鼠标
		draw_button.visible = true
	else:
		print("[MainGameUI Debug] 警告: 未找到抽卡按钮节点！检查节点路径。")

	# 容错：自动初始化逻辑
	await get_tree().create_timer(0.1).timeout
	if battle_manager == null:
		print("[MainGameUI Debug] 正在启动自初始化...")
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
		gs.game_over.connect(_on_game_over)
		_update_stats_display(gs.current_sanity, gs.current_score)

func _on_game_over():
	print("[MainGameUI] 收到游戏结束信号，正在执行失败逻辑...")
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		rm.fail_run()
	
	# 此处后续可以添加死亡动画
	get_tree().change_scene_to_file("res://src/ui/main_menu/main_menu.tscn")

func _on_item_drawn(item_data: ItemData):
	var item_ui_scene = load("res://src/ui/item/item_ui.tscn")
	var card = item_ui_scene.instantiate()
	
	# 将卡牌放入 UI 层
	add_child(card)
	card.setup(item_data)
	
	# 初始位置：抽卡区中心
	var dc_panel = $ContentLayer/DreamcatcherPanel
	var draw_center = dc_panel.global_position + dc_panel.size / 2.0
	card.global_position = draw_center - card.custom_minimum_size / 2.0
	
	# 连接拖拽信号
	card.dropped.connect(func(snap_pos, mouse_pos): _handle_item_dropped(card, snap_pos, mouse_pos))

func _handle_item_dropped(item_ui: Control, snap_pos: Vector2, mouse_pos: Vector2):
	# 1. 检查是否掉落在垃圾桶
	if trash_bin.get_global_rect().has_point(mouse_pos):
		print("[UI] 检测到物品掉入垃圾桶: ", item_ui.item_data.item_name)
		if battle_manager:
			battle_manager.request_discard_item(item_ui)
		return
		
	# 2. 检查是否掉落在饰品区 (且不是垃圾桶)
	if ornaments_area.get_global_rect().has_point(mouse_pos):
		print("[UI] 检测到物品试图装备到饰品区: ", item_ui.item_data.item_name)
		if battle_manager and battle_manager.has_method("request_equip_ornament"):
			battle_manager.request_equip_ornament(item_ui)
		return
	
	# 3. 否则按原逻辑交给背包
	backpack_ui.handle_item_dropped(item_ui, snap_pos)

func _on_draw_button_pressed():
	print("[MainGameUI Debug] >>> 捕梦按钮被物理点击了！信号接收成功 <<<")
	
	if battle_manager:
		print("[MainGameUI Debug] 正在向 BattleManager 发起 request_draw...")
		battle_manager.request_draw()
	else:
		print("[MainGameUI Debug] 错误: BattleManager 丢失，无法执行抽卡逻辑。")

func _on_menu_button_pressed():
	print("[MainGameUI] 玩家选择暂时离开战斗，返回整备室...")
	get_tree().change_scene_to_file("res://src/ui/hub/hub_scene.tscn")

func _on_sanity_changed(new_val):
	var gs = get_node("/root/GameState")
	if gs:
		_update_stats_display(new_val, gs.current_score)

func _on_score_changed(new_val):
	var gs = get_node("/root/GameState")
	if gs:
		_update_stats_display(gs.current_sanity, new_val)

func _update_stats_display(_san, score):
	var rm = get_node_or_null("/root/RunManager")
	var target = 100
	if rm:
		target = rm.get_target_score()
		
	if sanity_label:
		sanity_label.text = str(score) + " / " + str(target)
		
	# 胜利判定
	if score >= target:
		_on_victory()

func _on_victory():
	print("[MainGameUI] 目标达成！战斗胜利。")
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		# 奖励碎片：基础 5 + 深度加成
		rm.win_battle(5 + rm.current_depth * 2)
		
	# 胜利后返回整备室 (Hub)
	get_tree().change_scene_to_file("res://src/ui/hub/hub_scene.tscn")
