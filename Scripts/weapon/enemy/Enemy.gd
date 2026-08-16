extends CharacterBody2D

## 移动速度（像素/秒）
@export var move_speed: float = 100.0

## 方向改变的时间范围（秒）
@export var min_direction_time: float = 2.0
@export var max_direction_time: float = 5.0

## 站立概率（0~1），移动结束后可能站立的几率
@export var stand_probability: float = 0.3
## 站立持续时间范围（秒）
@export var min_stand_time: float = 1.0
@export var max_stand_time: float = 4.0

## 活动区域（屏幕中央 200x200 矩形）
var boundary_min: Vector2
var boundary_max: Vector2

# ---------- 状态枚举 ----------
enum State { MOVING, STANDING }
var current_state: State = State.MOVING

var move_direction: Vector2 = Vector2.ZERO
var state_timer: float = 0.0          # 当前状态剩余时间

# ========== 初始化 ==========
func _ready():
	# 计算边界（屏幕中央 200x200）
	var viewport_size = get_viewport().get_visible_rect().size
	var center = viewport_size / 2
	var half_size = 100.0
	boundary_min = center - Vector2(half_size, half_size)
	boundary_max = center + Vector2(half_size, half_size)
	
	# 初始状态：移动
	_enter_moving_state()

# ========== 每帧更新 ==========
func _physics_process(delta):
	state_timer -= delta
	
	match current_state:
		State.MOVING:
			if state_timer <= 0:
				# 时间到，决定是否站立
				if randf() < stand_probability:
					_enter_standing_state()
				else:
					_enter_moving_state()  # 继续移动，重新选方向
			else:
				# 移动中检测边界，如果碰壁则换方向
				_check_boundary_and_redirect()
				# 应用移动
				if move_direction != Vector2.ZERO:
					velocity = move_direction * move_speed
				else:
					velocity = Vector2.ZERO
				move_and_slide()
				# 最后夹紧位置（安全防护）
				_clamp_position_to_boundary()
		
		State.STANDING:
			velocity = Vector2.ZERO
			if state_timer <= 0:
				_enter_moving_state()  # 站立结束，开始移动

# ========== 状态切换函数 ==========
func _enter_moving_state():
	current_state = State.MOVING
	_pick_valid_direction()  # 选取一个不撞墙的方向
	state_timer = randf_range(min_direction_time, max_direction_time)

func _enter_standing_state():
	current_state = State.STANDING
	velocity = Vector2.ZERO
	state_timer = randf_range(min_stand_time, max_stand_time)

# ========== 随机选择一个“合法”方向（不会立即撞墙） ==========
func _pick_valid_direction():
	var attempts = 0
	var max_attempts = 20
	var new_dir = Vector2.ZERO
	
	while attempts < max_attempts:
		var angle = randf() * TAU
		new_dir = Vector2(cos(angle), sin(angle)).normalized()
		# 模拟如果朝这个方向走一小步，会不会超出边界
		var test_pos = global_position + new_dir * 10.0
		if _is_position_inside_boundary(test_pos):
			move_direction = new_dir
			return
		attempts += 1
	
	# 如果找不到合法方向（可能被围困），那就原地不动
	move_direction = Vector2.ZERO

# ========== 检查当前是否碰壁，若是则重定向 ==========
func _check_boundary_and_redirect():
	var pos = global_position
	var new_dir = move_direction
	
	# 检测是否碰到边界（容差 2 像素）
	var tolerance = 2.0
	var adjusted = false
	
	if pos.x <= boundary_min.x + tolerance and move_direction.x < 0:
		# 左边界，不能向左
		new_dir.x = abs(move_direction.x)  # 强制向右
		adjusted = true
	elif pos.x >= boundary_max.x - tolerance and move_direction.x > 0:
		new_dir.x = -abs(move_direction.x) # 强制向左
		adjusted = true
	
	if pos.y <= boundary_min.y + tolerance and move_direction.y < 0:
		new_dir.y = abs(move_direction.y)
		adjusted = true
	elif pos.y >= boundary_max.y - tolerance and move_direction.y > 0:
		new_dir.y = -abs(move_direction.y)
		adjusted = true
	
	if adjusted:
		# 重新归一化，但防止零向量
		if new_dir.length_squared() > 0:
			move_direction = new_dir.normalized()
		else:
			# 如果所有分量都被清零，随机选一个合法方向
			_pick_valid_direction()
	else:
		# 检查是否因为其他原因卡在边界（比如刚被击退到边界上）
		# 如果当前位置在边界上但未触发上述条件，强制随机换向
		if not _is_position_inside_boundary(pos):
			_pick_valid_direction()

# ========== 辅助函数：判断点是否在边界内 ==========
func _is_position_inside_boundary(pos: Vector2) -> bool:
	return pos.x >= boundary_min.x and pos.x <= boundary_max.x and \
		   pos.y >= boundary_min.y and pos.y <= boundary_max.y

# ========== 强制位置在边界内 ==========
func _clamp_position_to_boundary():
	global_position.x = clamp(global_position.x, boundary_min.x, boundary_max.x)
	global_position.y = clamp(global_position.y, boundary_min.y, boundary_max.y)

# ========== 击退（外部调用） ==========
func knockback(force: Vector2) -> void:
	# 如果当前在站立状态，击退会打断站立，转为移动状态
	if current_state == State.STANDING:
		_enter_moving_state()
	
	# 应用速度冲量
	velocity += force
	move_and_slide()
	_clamp_position_to_boundary()
	# 击退后可能撞墙，需要重新调整方向，防止卡墙
	_check_boundary_and_redirect()
