extends Node

## 设置管理器：负责持久化玩家偏好（如音量、静音状态等）

const SETTINGS_FILE = "user://settings.cfg"

var config = ConfigFile.new()

# 默认设置
var audio_settings = {
	"master_volume": 0.8,
	"music_volume": 0.7,
	"sfx_volume": 0.9,
	"is_muted": true # 默认静音
}

func _ready():
	load_settings()
	apply_audio_settings()

func save_settings():
	for key in audio_settings:
		config.set_value("audio", key, audio_settings[key])
	config.save(SETTINGS_FILE)
	print("[Settings] 设置已保存至: ", SETTINGS_FILE)

func load_settings():
	var err = config.load(SETTINGS_FILE)
	if err == OK:
		for key in audio_settings.keys():
			audio_settings[key] = config.get_value("audio", key, audio_settings[key])
		print("[Settings] 设置已加载")
	else:
		print("[Settings] 未发现旧设置，使用默认配置")

func apply_audio_settings():
	# 映射到音轨
	_set_bus_vol("Master", audio_settings["master_volume"])
	_set_bus_vol("Music", audio_settings["music_volume"])
	_set_bus_vol("SFX", audio_settings["sfx_volume"])
	
	AudioServer.set_bus_mute(0, audio_settings["is_muted"])

func _set_bus_vol(bus_name: String, linear_vol: float):
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear_vol))

func toggle_mute():
	audio_settings["is_muted"] = !audio_settings["is_muted"]
	AudioServer.set_bus_mute(0, audio_settings["is_muted"])
	save_settings()
	return audio_settings["is_muted"]

func set_master_volume(val: float):
	audio_settings["master_volume"] = val
	_set_bus_vol("Master", val)
	save_settings()
