extends Sprite2D


# Called when the node enters the scene tree for the first time.
func _process(delta: float) -> void:
	position.x += 100 * delta
