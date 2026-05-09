class_name BattleManager
extends Node

## 战斗管理器：游戏的逻辑中枢 (Controller)
## 负责协调背包数据、撞击解析和动画序列播放

signal turn_started
signal turn_finished
signal item_drawn(item_data: ItemData)

var backpack_manager: BackpackManager
var context: GameContext
var draw_count: int = 0 # 记录当前局内抽取次数

@export var backpack_ui: Control:
	set(v):
		backpack_ui = v
		if backpack_ui and backpack_manager:
			backpack_ui.setup(backpack_manager)

func _init():
	print("[BattleManager] 正在初始化逻辑数据...")
	# 初始化逻辑数据
	backpack_manager = BackpackManager.new()
	add_child(backpack_manager)
	backpack_manager.setup_grid(5, 5)

# --- 运行相关的逻辑变量 ---
var _current_battle_deck: Array[String] = []

func _ready():
	print("[BattleManager] 节点就绪")
	# 初始化上下文（依赖注入）
	var gs = get_node_or_null("/root/GameState")
	context = GameContext.new(gs, self)
	
	# 如果 UI 已经注入，确保它被初始化
	if backpack_ui:
		print("[BattleManager] 正在初始化已绑定的 UI...")
		backpack_ui.setup(backpack_manager)
		
	_initialize_battle_data()

func _exit_tree():
	print("[BattleManager] 正在卸载...")

func _initialize_battle_data():
	print("[BattleManager] 正在从 RunManager 初始化战斗数据...")
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		_current_battle_deck = Array(rm.current_deck).duplicate()
		_current_battle_deck.shuffle()
		print("[BattleManager] 洗牌完成，当前战斗卡包大小: ", _current_battle_deck.size())
	else:
		print("[BattleManager] 警告: 未找到 RunManager，使用空卡包运行。")

## 处理玩家放置物品的逻辑请求
func request_place_item(item_ui: Control, grid_pos: Vector2i):
	if grid_pos == Vector2i(-1, -1):
		print("[BattleManager] 放置失败: 未能捕捉到有效的网格位置")
		backpack_ui.add_item_visual(item_ui, _find_item_old_pos(item_ui.item_data))
		return

	# --- 核心优化：先移除旧位置，再检查新位置 ---
	# 这样物品在微调位置时，就不会撞到“自己之前的影子”
	var old_pos = _find_item_old_pos(item_ui.item_data)
	if old_pos != Vector2i(-1, -1):
		backpack_manager.remove_item_at(old_pos)

	if not backpack_manager.can_place_item(item_ui.item_data, grid_pos):
		print("[BattleManager] 逻辑拒绝放置: 物品 ", item_ui.item_data.item_name, " 在 ", grid_pos, " 处无法放下 (出界或重叠)")
		# 如果新位置不行，放回老位置
		if old_pos != Vector2i(-1, -1):
			backpack_manager.place_item(item_ui.item_data, old_pos)
		backpack_ui.add_item_visual(item_ui, old_pos)
		return
	
	# 1. 逻辑层：放置新位置
	backpack_manager.place_item(item_ui.item_data, grid_pos)
	
	# 发出全局信号：物品已放置
	var bus = get_node_or_null("/root/GlobalEventBus")
	if bus:
		bus.item_placed.emit(backpack_manager.grid[grid_pos])
	
	# 2. 表现层：更新 UI 位置
	var old_data = item_ui.item_data
	var new_instance = backpack_manager.grid[grid_pos]
	item_ui.item_data = new_instance.data
	
	backpack_ui.update_item_mapping(old_data, item_ui.item_data)
	backpack_ui.add_item_visual(item_ui, grid_pos)
	
	print("[BattleManager] 物品已放置")

## 发起一次指定的撞击
func trigger_impact_at(pos: Vector2i):
	if not backpack_manager.grid.has(pos):
		print("[BattleManager] 警告: 尝试在空坐标发起撞击: ", pos)
		return
		
	var instance = backpack_manager.grid[pos]
	print("[BattleManager] 手动触发撞击. 源物品: ", instance.data.item_name, " 坐标: ", pos)
	_run_impact_sequence(pos, instance.data.direction)

## 处理丢弃逻辑
func request_discard_item(item_ui: Control):
	print("[BattleManager] 物品丢弃请求: ", item_ui.item_data.item_name)
	
	# 1. 逻辑层：如果物品已在背包中，先将其移除
	_remove_item_from_logic(item_ui.item_data)
	
	# 2. 发出全局信号
	var bus = get_node_or_null("/root/GlobalEventBus")
	if bus:
		bus.item_discarded.emit(item_ui.item_data)
	
	# 3. 触发 on_discard 效果
	for effect in item_ui.item_data.effects:
		effect.on_discard(item_ui.item_data, context)
	
	# 4. 清理 UI 映射
	if backpack_ui and backpack_ui.item_ui_map.has(item_ui.item_data.runtime_id):
		backpack_ui.item_ui_map.erase(item_ui.item_data.runtime_id)
	
	item_ui.queue_free()

## 处理装备饰品的逻辑请求
func request_equip_ornament(item_ui: Control):
	print("[BattleManager] 饰品装备请求: ", item_ui.item_data.item_name)
	
	# 1. 逻辑层：如果物品已在背包中，先将其移除
	_remove_item_from_logic(item_ui.item_data)
	
	# 2. 触发 on_equip 效果
	for effect in item_ui.item_data.effects:
		if effect.has_method("on_equip"):
			effect.on_equip(item_ui.item_data, context)
	
	# 3. 表现层：将物品 UI 移动到饰品槽中
	if backpack_ui and backpack_ui.item_ui_map.has(item_ui.item_data.runtime_id):
		backpack_ui.item_ui_map.erase(item_ui.item_data.runtime_id)
		
	var main_ui = get_tree().current_scene if get_tree() else null
	if main_ui and main_ui.has_node("HBoxContainer/RightPanel/OrnamentsArea/Slots"):
		var slots = main_ui.get_node("HBoxContainer/RightPanel/OrnamentsArea/Slots")
		if item_ui.get_parent():
			item_ui.get_parent().remove_child(item_ui)
		slots.add_child(item_ui)
		item_ui.position = Vector2.ZERO # HBoxContainer 会自动排版
		
		# 禁用被放入饰品区物品的拖拽（或者允许未来卸下，目前简单处理）
		item_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _run_impact_sequence(start_pos: Vector2i, dir: ItemData.Direction):
	turn_started.emit()
	
	var resolver = ImpactResolver.new(backpack_manager, context)
	var actions = resolver.resolve_impact(start_pos, dir)
	
	var player = SequencePlayer.new()
	add_child(player)
	
	# 播放并等待结束
	if backpack_ui:
		await player.play_sequence(actions, backpack_ui.item_ui_map, context)
	else:
		# 在没有 UI 的情况下（如单元测试），可以模拟等待或直接结束
		# print("[BattleManager] 警告: 未绑定 backpack_ui，跳过动画播放")
		pass
	
	player.queue_free()
	turn_finished.emit()

func _find_item_old_pos(item_data: ItemData) -> Vector2i:
	for pos in backpack_manager.grid.keys():
		if backpack_manager.grid[pos].data.runtime_id == item_data.runtime_id:
			return backpack_manager.grid[pos].root_pos
	return Vector2i(-1, -1)

func _remove_item_from_logic(item_data: ItemData):
	var old_pos = _find_item_old_pos(item_data)
	if old_pos != Vector2i(-1, -1):
		backpack_manager.remove_item_at(old_pos)

## 请求捕梦 (抽卡)
func request_draw():
	if _current_battle_deck.is_empty():
		print("[BattleManager] 卡包已抽空！正在重新洗牌...")
		_initialize_battle_data()
		
	if _current_battle_deck.is_empty():
		print("[BattleManager] 错误: 卡包依然为空，无法抽卡。")
		return

	# 1. 从当前战斗卡包取一张 ID
	var item_id = _current_battle_deck.pop_back()
	var item_db = get_node_or_null("/root/ItemDatabase")
	var item = item_db.get_item_by_id(item_id)
	
	if not item:
		print("[BattleManager] 错误: 无法加载物品: ", item_id)
		return

	# 2. 计算并扣除 San 值
	var cost = 0
	if item.base_cost == -1:
		cost = 5 + 1 * draw_count
	else:
		cost = abs(item.base_cost)
		
	if context and context.state:
		context.state.consume_sanity(cost)
	
	# 3. 进入通用处理流
	_process_new_item_acquisition(item)

## 调试接口：直接根据 ID 获得物品
func debug_get_item(item_id: String):
	var item_db = get_node_or_null("/root/ItemDatabase")
	var item = item_db.get_item_by_id(item_id)
	if item:
		print("[BattleManager] 调试获取物品: ", item.item_name)
		_process_new_item_acquisition(item)

## 彻底清空所有物品 (仅用于调试)
func debug_clear_all():
	print("[BattleManager] 正在执行全量清理...")
	
	# 1. 逻辑层清理
	if backpack_manager:
		backpack_manager.grid.clear()
	
	draw_count = 0
	
	# 2. 状态清理
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.reset_game()
	
	# 3. 表现层清理
	if backpack_ui:
		backpack_ui.item_ui_map.clear()
	
	# 4. 彻底删除场景中所有的物品 UI (不论在背包内还是外)
	var all_item_uis = get_tree().get_nodes_in_group("items")
	for item_ui in all_item_uis:
		if is_instance_valid(item_ui):
			item_ui.queue_free()
					
	print("[BattleManager] 全量清理完成。")

## 通用处理流：处理新获得物品后的所有连锁反应（信号、效果触发等）
func _process_new_item_acquisition(item: ItemData):
	draw_count += 1
	item.runtime_id = randi()
	print("[BattleManager] 处理新物品获取: ", item.item_name, " (抽卡计数: ", draw_count, ")")
	
	# 1. 触发背包内所有已有物品的“响应全局抽卡”效果 (例如夜色墨盒、小丑鼻子)
	# 必须最先执行，确保在任何撞击连锁开始前完成叠层
	var all_instances = backpack_manager.get_all_instances()
	for instance in all_instances:
		for effect in instance.data.effects:
			if effect.has_method("on_global_item_drawn"):
				effect.on_global_item_drawn(item, instance, context)
	
	# 2. 发出全局事件总线信号
	var bus = get_node_or_null("/root/GlobalEventBus")
	if bus:
		bus.item_drawn.emit(item)
	
	# 3. 触发新物品自身的抽卡效果 (可能引发撞击)
	for effect in item.effects:
		effect.on_draw(item, context)
		
	# 4. 特殊逻辑：同名卡连锁触发
	if item.item_name == "棒球":
		_check_same_name_trigger(item.item_name)
		
	# 5. 固定撞击源处理
	if draw_count > 0 and draw_count % 5 == 0:
		print("[BattleManager] 达到 5 次捕梦，触发第三排固定撞击源！")
		_run_impact_sequence(Vector2i(0, 2), ItemData.Direction.RIGHT)
	
	item_drawn.emit(item)

func _check_same_name_trigger(new_item_name: String):
	# 遍历背包，找到所有同名卡牌并依次触发一次撞击
	for pos in backpack_manager.grid.keys():
		var instance = backpack_manager.grid[pos]
		# 只有 root 坐标才触发一次，防止占据多格的物品重复触发
		if instance.root_pos == pos and instance.data.item_name == new_item_name:
			print("[BattleManager] 发现同名卡，触发连锁: ", new_item_name, " 在坐标 ", pos)
			trigger_impact_at(pos)
