extends Node2D   # 如果你用 CharacterBody2D，就改成 extends CharacterBody2D
class_name Player

@export var current_weapon: WeaponBase   # 你的武器数据

var attack_cooldown_timer: float = 0.0

func _ready():
	# 如果怕找不到鼠标位置，先隐藏默认光标（可选）
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float):
	# 1. 冷却倒计时
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	
	# 2. 检测鼠标位置下是否有敌人
	var mouse_pos = get_global_mouse_position()
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = mouse_pos
	params.collide_with_areas = true   # 如果敌人是 Area2D
	params.collide_with_bodies = true  # 如果敌人是 CharacterBody2D/RigidBody2D
	# 建议只检测特定碰撞层（比如敌人层），以免点到地面等
	# params.collision_layer = 1 << 2  # 如果设置了专门的敌人层，可以过滤
	
	var results = space_state.intersect_point(params)
	
	# 3. 如果检测到碰撞体，并且属于敌人组，且冷却已好，则攻击
	if results.size() > 0:
		var collider = results[0].collider
		if collider.is_in_group("enemies"):
			if attack_cooldown_timer <= 0 and current_weapon:
				_perform_attack()

func _perform_attack():
	if not current_weapon:
		return
	
	# 获取鼠标在游戏世界中的位置
	var target_pos = get_global_mouse_position()
	# 调用武器数据里的攻击方法（它会生成投掷物）
	current_weapon.perform_attack(self, target_pos)
	
	# 进入冷却
	attack_cooldown_timer = current_weapon.cooldown
