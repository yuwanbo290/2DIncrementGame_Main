extends CollisionShape2D

# ===== 由武器系统传入的数据 =====
var speed: float = 800.0
var target_position: Vector2
var weapon_data: WeaponBase
var attacker: Node2D

# ===== 轨迹参数（从武器数据读取） =====
var arc_height: float = 0.0
var lateral_curve: float = 0.0

# ===== 运动计算变量 =====
var start_position: Vector2
var total_distance: float
var traveled_distance: float = 0.0
var direction: Vector2          # 起始指向终点的单位方向
var normal: Vector2             # 垂直于方向向量（用于侧弧）

func _ready():
	# 1. 从武器数据读取参数
	if weapon_data:
		speed = weapon_data.throw_speed
		arc_height = weapon_data.arc_height
		lateral_curve = weapon_data.lateral_curve
	
	# 2. 缓存起点和方向
	start_position = global_position
	total_distance = start_position.distance_to(target_position)
	direction = (target_position - start_position).normalized()
	# 计算法向量（垂直方向）：旋转90度，用于产生侧向弯曲
	normal = Vector2(-direction.y, direction.x)

func _physics_process(delta):
	traveled_distance += speed * delta
	var progress = traveled_distance / total_distance
	
	if progress >= 1.0:
		progress = 1.0
		_on_reach_target()
		return
	
	# 3. 计算基础位置（直线插值）
	var base_pos = start_position.lerp(target_position, progress)
	
	# 4. 计算垂直偏移（Y轴弧线：低 -> 高 -> 低）
	var vertical_offset = Vector2(0, -sin(progress * PI) * arc_height)
	
	# 5. 计算侧向偏移（垂直于飞行方向的弧线：左/右弯曲）
	var lateral_offset_vec = normal * sin(progress * PI) * lateral_curve
	
	# 6. 合成最终位置
	global_position = base_pos + vertical_offset + lateral_offset_vec

func _on_reach_target():
	set_physics_process(false)
	if weapon_data:
		weapon_data.trigger_area_effect(attacker, global_position, get_tree().current_scene)
	queue_free()
