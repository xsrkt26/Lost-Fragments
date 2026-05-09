extends CharacterBody2D

## 枢纽场景角色控制器：强兼容版
@export var speed: float = 400.0
@export var gravity: float = 1200.0

func _physics_process(delta):
	# 1. 处理重力（确保踩在地板上）
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# 2. 直接监听键盘按键，不依赖 Input Map
	var direction = 0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction += 1

	# 3. 计算速度
	if direction != 0:
		velocity.x = direction * speed
		# 处理旋转/翻转
		if $Sprite2D:
			$Sprite2D.flip_h = (direction < 0)
	else:
		# 平滑减速
		velocity.x = move_toward(velocity.x, 0, speed * 0.2)

	# 4. 执行移动
	var was_moving = velocity.length() > 0
	move_and_slide()
	
	if was_moving:
		# 可以在这里打印坐标来确认角色是否在动
		# print("[Player] 坐标: ", global_position)
		pass
