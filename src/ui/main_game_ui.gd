extends Control

## 主游戏 UI 控制器：负责将布局中的各个部分与逻辑层连接

@onready var backpack_ui = $HBoxContainer/RightPanel/BackpackArea/CenterContainer/BackpackUI
@onready var sanity_label = $HBoxContainer/LeftPanel/BottomRow/SanityArea/VBox/Value
@onready var draw_button = $HBoxContainer/LeftPanel/DrawArea/DrawButton

var battle_manager: BattleManager

func _ready():
	# 实际项目中这里通常由更高级别的 Manager 或场景脚本注入
	# 为了演示，我们在这里手动初始化或等待注入
	pass

func setup(p_battle_manager: BattleManager):
	battle_manager = p_battle_manager
	battle_manager.backpack_ui = backpack_ui
	
	# 连接状态更新信号
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.sanity_changed.connect(_on_sanity_changed)
		gs.score_changed.connect(_on_score_changed)
		_update_stats_display(gs.current_sanity, gs.current_score)

func _on_sanity_changed(new_val):
	var gs = get_node("/root/GameState")
	_update_stats_display(new_val, gs.current_score)

func _on_score_changed(new_val):
	var gs = get_node("/root/GameState")
	_update_stats_display(gs.current_sanity, new_val)

func _update_stats_display(san, score):
	sanity_label.text = str(san) + " / " + str(score)

func _on_draw_button_pressed():
	# 触发抽卡逻辑
	print("[UI] 玩家请求抽卡")
	# battle_manager.request_draw() # 假设未来有此方法
