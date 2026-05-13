extends GutTest

var player

func before_each():
	player = add_child_autofree(load("res://src/ui/hub/hub_player.gd").new())

func test_mouse_move_target_is_set_and_cleared():
	player.move_to_global_x(420.0)
	assert_true(player.has_move_target)
	assert_eq(player.move_target_x, 420.0)

	player.clear_move_target()
	assert_false(player.has_move_target)
