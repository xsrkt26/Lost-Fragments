extends Control

## 音频设置界面：允许调整音量和开关静音

@onready var master_slider = $MarginContainer/VBoxContainer/MasterSlider
@onready var mute_button = $MarginContainer/VBoxContainer/MuteButton
@onready var close_button = $MarginContainer/VBoxContainer/CloseButton

func _ready():
	_update_ui()
	
	master_slider.value_changed.connect(_on_master_changed)
	mute_button.pressed.connect(_on_mute_toggled)
	close_button.pressed.connect(_on_close_pressed)

func _input(event):
	# 支持 ESC 键关闭
	if event.is_action_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		_on_close_pressed()
		# 消耗掉事件防止透传
		get_viewport().set_input_as_handled()

func _update_ui():
	var settings = SettingsManager.audio_settings
	master_slider.value = settings["master_volume"]
	mute_button.text = "解除静音" if settings["is_muted"] else "静音"

func _on_master_changed(val: float):
	SettingsManager.set_master_volume(val)

func _on_mute_toggled():
	var muted = SettingsManager.toggle_mute()
	mute_button.text = "解除静音" if muted else "静音"

func _on_close_pressed():
	print("[Settings] 退出设置界面")
	queue_free()
