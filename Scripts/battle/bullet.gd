class_name Bullet
extends Area2D
## 子弹（色块占位实现）：黄色小圆，直线飞行。
## 支持弹射（ricochet_left 次边界反弹，来自局外技能「弹性子弹」）；超时自动消失。


const RADIUS := 6.0
const MAX_LIFETIME := 3.0
## 屏幕边距（反弹判定边界）
const MARGIN := 10.0

signal hit_enemy(enemy: Enemy, damage: float, is_crit: bool)

var velocity: Vector2 = Vector2.ZERO
var damage: float = 1.0
var ricochet_left: int = 0
## 本发子弹是否暴击（命中时用于伤害数字的独特显示）
var is_crit: bool = false

var _lifetime: float = 0.0


func setup(dir: Vector2, speed: float, dmg: float, ricochet: int, crit: bool = false) -> void:
	velocity = dir * speed
	damage = dmg
	ricochet_left = ricochet
	is_crit = crit
	collision_layer = 2
	collision_mask = 1
	monitoring = true
	monitorable = false
	var collision_shape := CollisionShape2D.new()
	var circle_shape := CircleShape2D.new()
	circle_shape.radius = RADIUS
	collision_shape.shape = circle_shape
	add_child(collision_shape)
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.95, 0.4, 1))


func _on_area_entered(area: Area2D) -> void:
	if area is not Enemy:
		return
	collision_mask = 0
	hit_enemy.emit(area as Enemy, damage, is_crit)
	queue_free()


func _process(delta: float) -> void:
	_lifetime += delta
	if _lifetime > MAX_LIFETIME:
		queue_free()
		return
	position += velocity * delta
	_bounce()


func _bounce() -> void:
	if ricochet_left <= 0:
		return
	var view: Vector2 = get_viewport_rect().size if get_viewport() != null else Vector2(1920, 1080)
	var bounced: bool = false
	if position.x < MARGIN and velocity.x < 0.0:
		velocity.x = -velocity.x
		bounced = true
	elif position.x > view.x - MARGIN and velocity.x > 0.0:
		velocity.x = -velocity.x
		bounced = true
	if position.y < MARGIN and velocity.y < 0.0:
		velocity.y = -velocity.y
		bounced = true
	elif position.y > view.y - MARGIN and velocity.y > 0.0:
		velocity.y = -velocity.y
		bounced = true
	if bounced:
		ricochet_left -= 1
