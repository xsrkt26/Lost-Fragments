extends Node

## 反馈管理器：全局“汁水” (Juice) 系统
## 负责屏幕震动、飘字、冻结帧等表现效果

enum TextType { SCORE, SANITY, INFO }

var _shake_tween: Tween = null

func _ready():
	print("[GlobalFeedback] 反馈管理器已就绪。")

# --- 屏幕震动 (Screen Shake) ---

## 触发屏幕震动
func shake_screen(intensity: float = 5.0, duration: float = 0.2):
	var camera = _get_active_camera()
	if not camera: return
	
	# 核心修复：如果上一次震动还没结束，先杀掉它，防止多个 Tween 争夺 Offset 控制权
	if _shake_tween and _shake_tween.is_running():
		_shake_tween.kill()
	
	var original_pos = Vector2.ZERO # 假设基础偏移是 0
	_shake_tween = create_tween()
	
	# 产生随机抖动序列
	var steps = 4
	for i in range(steps):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		_shake_tween.tween_property(camera, "offset", offset, duration / steps)
		intensity *= 0.7 
		
	_shake_tween.tween_property(camera, "offset", original_pos, 0.05)

func _get_active_camera() -> Camera2D:
	var viewport = get_viewport()
	if viewport:
		return viewport.get_camera_2d()
	return null

# --- 飘字系统 (Floating Text) ---

## 在指定位置显示动画文字
func show_text(text: String, global_pos: Vector2, type: TextType = TextType.INFO):
	var label = Label.new()
	label.text = text
	label.z_index = 200 
	
	# 优化样式
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	match type:
		TextType.SCORE:
			label.add_theme_color_override("font_color", Color.YELLOW)
			label.add_theme_font_size_override("font_size", 24)
		TextType.SANITY:
			label.add_theme_color_override("font_color", Color.RED if "-" in text else Color.GREEN)
			label.add_theme_font_size_override("font_size", 24)
		TextType.INFO:
			label.add_theme_color_override("font_color", Color.WHITE)
			
	get_tree().root.add_child(label)
	
	# 修正初始位置：将中心点对齐到 global_pos
	label.global_position = global_pos - label.get_combined_minimum_size() / 2.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	# 向上飘移
	tween.tween_property(label, "global_position:y", global_pos.y - 60.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 渐隐
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.2)
	# 轻微缩放增加动感
	label.scale = Vector2(0.5, 0.5)
	label.pivot_offset = label.get_combined_minimum_size() / 2.0
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.chain().tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)
	
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

# --- 冻结帧 (Hit Stop) ---

func hit_stop(duration: float = 0.05):
	Engine.time_scale = 0.01
	await get_tree().create_timer(duration, true, false, true).timeout 
	Engine.time_scale = 1.0
