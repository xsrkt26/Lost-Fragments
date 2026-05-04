class_name SequencePlayer
extends Node

## 序列播放器：负责按顺序执行 Action 并播放对应的动画表现

signal sequence_finished

## 执行动作序列
func play_sequence(action_list: Array[GameAction]):
	for action in action_list:
		await _execute_action(action)
		# 在动作之间添加微小的延迟，增加“节奏感”
		await get_tree().create_timer(0.2).timeout
	
	sequence_finished.emit()

func _execute_action(action: GameAction):
	match action.type:
		GameAction.Type.IMPACT:
			_play_impact_anim(action)
		GameAction.Type.NUMERIC:
			_apply_numeric_change(action)
	
	# 暂时简单处理：所有动作瞬间完成，或者等一个固定的动画时间
	await get_tree().create_timer(0.1).timeout

func _play_impact_anim(action: GameAction):
	print("[Seq] 播放撞击动画: ", action.value.pos)
	# 这里后续会调用具体 UI 节点的抖动、闪烁等效果

func _apply_numeric_change(action: GameAction):
	var data = action.value
	var gs = get_node_or_null("/root/GameState")
	if not gs:
		print("[Seq] 警告: 未找到 GameState，跳过数值结算")
		return

	if data.type == "score":
		gs.add_score(data.amount)
	elif data.type == "sanity":
		if data.amount > 0:
			gs.heal_sanity(data.amount)
		else:
			gs.consume_sanity(abs(data.amount))
