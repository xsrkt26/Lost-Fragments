extends Node

## 音频管理器：全局音频调度中心
## 支持背景音乐淡入淡出、音效池管理、音量控制

enum Bus { MASTER, MUSIC, SFX }

const BGM_PATHS = {
	"menu": "res://assets/audio/bgm/main_menu.wav",
	"hub": "res://assets/audio/bgm/hub_theme.wav",
	"battle": "res://assets/audio/bgm/battle_theme.wav"
}

const SFX_PATHS = {
	"click": "res://assets/audio/sfx/ui_click.wav",
	"draw": "res://assets/audio/sfx/card_draw.wav",
	"place": "res://assets/audio/sfx/card_place.wav",
	"hit": "res://assets/audio/sfx/hit_impact.wav",
	"score": "res://assets/audio/sfx/score_up.wav",
	"error": "res://assets/audio/sfx/ui_error.wav"
}

var _bgm_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_size: int = 12
var _fade_tween: Tween = null

func _ready():
	_setup_audio_nodes()
	AudioServer.set_bus_mute(0, true)
	print("[GlobalAudio] 音频管理器已就绪。")

func _setup_audio_nodes():
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Music"
	add_child(_bgm_player)
	
	for i in range(_pool_size):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)

func _exit_tree():
	# 退出时强制停止并清理播放器引用，彻底防止内存泄漏
	if _bgm_player:
		_bgm_player.stop()
		_bgm_player.stream = null
	for player in _sfx_pool:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	print("[GlobalAudio] 音频资源已安全卸载。")

## 播放 BGM，修复了淡入淡出冲突
func play_bgm(bgm_key: String, fade_time: float = 1.0):
	if not BGM_PATHS.has(bgm_key): return
	var path = BGM_PATHS[bgm_key]
	if not FileAccess.file_exists(path): return

	var stream = load(path)
	if _bgm_player.stream == stream and _bgm_player.playing: return

	# 杀掉之前的淡入淡出，防止音量争夺
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()

	if fade_time > 0:
		_fade_tween = create_tween()
		# 先淡出
		_fade_tween.tween_property(_bgm_player, "volume_db", -80.0, fade_time / 2.0)
		_fade_tween.tween_callback(func():
			_bgm_player.stream = stream
			_bgm_player.play()
		)
		# 后淡入
		_fade_tween.tween_property(_bgm_player, "volume_db", 0.0, fade_time / 2.0)
	else:
		_bgm_player.stream = stream
		_bgm_player.play()
		_bgm_player.volume_db = 0.0

func stop_bgm(fade_time: float = 1.0):
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	if fade_time > 0:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_bgm_player, "volume_db", -80.0, fade_time)
		_fade_tween.tween_callback(_bgm_player.stop)
	else:
		_bgm_player.stop()

func play_sfx(sfx_key: String, pitch_range: float = 0.1):
	if not SFX_PATHS.has(sfx_key): return
	var path = SFX_PATHS[sfx_key]
	if not FileAccess.file_exists(path): return

	var stream = load(path)
	_play_stream_from_pool(stream, pitch_range)

func _play_stream_from_pool(stream: AudioStream, pitch_range: float):
	for player in _sfx_pool:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = 1.0 + randf_range(-pitch_range, pitch_range)
			player.play()
			return
	_sfx_pool[0].stream = stream
	_sfx_pool[0].play()

func set_volume(bus_type: Bus, volume: float):
	var bus_name = "Master"
	match bus_type:
		Bus.MUSIC: bus_name = "Music"
		Bus.SFX: bus_name = "SFX"
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		# 转换到分贝
		AudioServer.set_bus_volume_db(idx, linear_to_db(volume))
