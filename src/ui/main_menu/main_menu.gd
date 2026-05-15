extends Control

## 主菜单：使用分层背景和书卷按钮素材，文字由引擎渲染。

const BASE_MENU_SIZE := Vector2(1280.0, 720.0)
const MENU_RECTS := {
	"NewGameButton": Rect2(94.0, 188.0, 214.0, 460.0),
	"ContinueButton": Rect2(294.0, 232.0, 198.0, 425.0),
	"GalleryButton": Rect2(482.0, 294.0, 174.0, 374.0),
	"SettingsButton": Rect2(648.0, 344.0, 154.0, 330.0),
	"QuitButton": Rect2(792.0, 400.0, 134.0, 286.0),
	"TitleLabel": Rect2(874.0, 92.0, 320.0, 110.0),
}
const BUTTON_LABELS := {
	"NewGameButton": "开\n始\n游\n戏",
	"ContinueButton": "继\n续\n游\n戏",
	"GalleryButton": "图\n鉴",
	"SettingsButton": "设\n置",
	"QuitButton": "退\n出",
}
const ENABLED_MODULATE := Color(1, 1, 1, 1)
const DISABLED_MODULATE := Color(0.5, 0.5, 0.56, 0.72)

@onready var continue_button: Button = $MenuHotspots/ContinueButton
@onready var new_game_button: Button = $MenuHotspots/NewGameButton
@onready var gallery_button: Button = $MenuHotspots/GalleryButton
@onready var settings_button: Button = $MenuHotspots/SettingsButton
@onready var quit_button: Button = $MenuHotspots/QuitButton
@onready var title_label: Label = $MenuHotspots/TitleLabel
@onready var settings_container: Control = $CanvasLayer/SettingsContainer

func _ready() -> void:
	print("[MainMenu] 进入主菜单")
	GlobalInput.set_context(GlobalInput.Context.MENU)
	GlobalAudio.play_bgm("menu")

	resized.connect(_update_menu_layout)
	call_deferred("_update_menu_layout")
	_configure_hotspot_labels()
	_refresh_continue_state()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		GlobalScene.transition_to(GlobalScene.SceneType.DEBUG)

func _configure_hotspot_labels() -> void:
	new_game_button.tooltip_text = "开始游戏"
	gallery_button.tooltip_text = "图鉴"
	settings_button.tooltip_text = "设置"
	quit_button.tooltip_text = "退出"
	for button_name in BUTTON_LABELS.keys():
		var label := get_node_or_null("MenuHotspots/%s/Label" % button_name) as Label
		if label:
			label.text = BUTTON_LABELS[button_name]

func _refresh_continue_state() -> void:
	var rm = get_node_or_null("/root/RunManager")
	var has_continue_save: bool = rm != null and rm.saver != null and rm.saver.has_save() and not rm.is_run_complete
	continue_button.disabled = not has_continue_save
	continue_button.modulate = ENABLED_MODULATE if has_continue_save else DISABLED_MODULATE
	if has_continue_save:
		continue_button.tooltip_text = "继续游戏（第 %d 场景）" % rm.current_act
	else:
		continue_button.tooltip_text = "继续游戏（无存档）"

func _update_menu_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = BASE_MENU_SIZE

	var scale_factor: float = maxf(viewport_size.x / BASE_MENU_SIZE.x, viewport_size.y / BASE_MENU_SIZE.y)
	var displayed_art_size: Vector2 = BASE_MENU_SIZE * scale_factor
	var displayed_art_origin: Vector2 = (viewport_size - displayed_art_size) * 0.5

	for node_name in MENU_RECTS.keys():
		var node := get_node_or_null("MenuHotspots/%s" % node_name)
		if node == null or not node is Control:
			continue
		var source_rect: Rect2 = MENU_RECTS[node_name]
		var target_rect: Rect2 = Rect2(
			displayed_art_origin + source_rect.position * scale_factor,
			source_rect.size * scale_factor
		)
		var control := node as Control
		control.position = target_rect.position
		control.size = target_rect.size
		control.pivot_offset = target_rect.size * 0.5
		if control is Button:
			_update_scroll_label(control as Button, target_rect.size)
	_update_title_label(target_rect_scale_font(scale_factor, 74.0))

func _update_scroll_label(button: Button, button_size: Vector2) -> void:
	var label := button.get_node_or_null("Label") as Label
	if label == null:
		return
	var top_padding := button_size.y * 0.21
	var bottom_padding := button_size.y * 0.07
	var side_padding := button_size.x * 0.2
	label.offset_left = side_padding
	label.offset_top = top_padding
	label.offset_right = -side_padding
	label.offset_bottom = -bottom_padding
	label.add_theme_font_size_override("font_size", int(clamp(button_size.y * 0.078, 22.0, 40.0)))
	label.add_theme_constant_override("line_spacing", int(clamp(button_size.y * 0.012, 3.0, 8.0)))

func _update_title_label(font_size: int) -> void:
	if title_label == null:
		return
	title_label.add_theme_font_size_override("font_size", font_size)

func target_rect_scale_font(scale_factor: float, base_size: float) -> int:
	return int(clamp(base_size * scale_factor, 42.0, 92.0))

func _on_new_game_button_pressed() -> void:
	print("[MainMenu] 点击新游戏")
	var rm = get_node_or_null("/root/RunManager")
	if rm:
		rm.start_new_run()
		GlobalScene.transition_to(GlobalScene.SceneType.HUB)

func _on_continue_button_pressed() -> void:
	print("[MainMenu] 点击继续游戏")
	GlobalScene.transition_to(GlobalScene.SceneType.HUB)

func _on_gallery_button_pressed() -> void:
	print("[MainMenu] 进入图鉴")
	GlobalScene.transition_to(GlobalScene.SceneType.GALLERY)

func _on_settings_button_pressed() -> void:
	if settings_container.get_child_count() > 0:
		for child in settings_container.get_children():
			child.queue_free()
	else:
		var scene = load("res://src/ui/settings/audio_settings_ui.tscn")
		var ui = scene.instantiate()
		settings_container.add_child(ui)

func _on_quit_button_pressed() -> void:
	get_tree().quit()
