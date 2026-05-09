extends SceneTree

func _init():
	print("Checking MainGameUI instantiation...")
	var scene = load("res://src/ui/main_game_ui.tscn")
	if scene == null:
		print("FAILED to load scene file.")
		quit(1)
		return
		
	var instance = scene.instantiate()
	if instance == null:
		print("FAILED to instantiate scene.")
		quit(1)
		return
		
	print("SUCCESS: MainGameUI instantiated.")
	instance.free()
	quit(0)
