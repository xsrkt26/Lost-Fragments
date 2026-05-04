extends Node2D

## 演示场景：整合了拼贴风格 UI 与 战斗系统

@onready var main_ui = $MainGameUI # 假设场景中有名为 MainGameUI 的实例
var battle_manager: BattleManager

func _ready():
	# 1. 创建逻辑中枢 BattleManager
	battle_manager = BattleManager.new()
	add_child(battle_manager)

	# 2. 初始化 UI 并建立连接
	# 如果 MainGameUI 是在编辑器里直接拖进去的
	if main_ui:
		main_ui.setup(battle_manager)
	
	print("[Demo] 整合场景就绪，点击'点击捕梦'开始游戏")
