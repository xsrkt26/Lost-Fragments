class_name SequencePlayer
extends Node

## 序列播放器：负责按顺序执行 Action 并播放对应的动画表现

signal sequence_finished

var node_map: Dictionary # 用于从 ItemData 查找 ItemUI 节点
var context: GameContext

## 执行动作序列
func play_sequence(action_list: Array[GameAction], p_node_map: Dictionary, p_context: GameContext):
	node_map = p_node_map
	context = p_context
	for action in action_list:
		await _execute_action(action)
	
	sequence_finished.emit()

func _execute_action(action: GameAction):
	# 获取关联的 UI 节点
	var target_ui: Control = null
	if action.item_instance:
		var rid = action.item_instance.data.runtime_id
		if node_map.has(rid):
			target_ui = node_map[rid]
			print("[Seq Debug] 执行动作: ", action.description, " | 目标 UI: ", target_ui.name, " (", target_ui.item_data.item_name, ")")
		else:
			# 只有当确实应该有节点却没找到时才打印调试信息
			print("[Seq Debug] 找不到映射关系! RID: ", rid, " | Action: ", action.description)

	match action.type:
		GameAction.Type.IMPACT:
			if target_ui:
				await target_ui.play_impact_anim()
			else:
				# 如果是起始动作（没有 item_instance），静默等待即可，不视为错误
				if action.item_instance == null:
					# print("[Seq] 序列开始: ", action.value.pos if action.value else "")
					await get_tree().create_timer(0.1).timeout
				else:
					var pos_str = str(action.value.pos) if (action.value is Dictionary and action.value.has("pos")) else "Unknown"
					print("[Seq] 警告: 找不到物品 UI 节点，跳过动画. Pos: ", pos_str)
					await get_tree().create_timer(0.2).timeout
				
		GameAction.Type.NUMERIC:
			if target_ui:
				await target_ui.play_effect_anim()
			_apply_numeric_change(action)
			await get_tree().create_timer(0.1).timeout

func _apply_numeric_change(action: GameAction):
	var data = action.value
	if not context:
		print("[Seq] 警告: 未注入 GameContext，跳过数值结算")
		return

	if data.type == "score":
		context.add_score(data.amount)
	elif data.type == "sanity":
		context.change_sanity(data.amount)
