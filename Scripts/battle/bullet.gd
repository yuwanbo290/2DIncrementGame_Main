class_name Bullet
extends Node2D
## 子弹（色块占位实现）：黄色小圆，直线飞行。
## 支持弹射（ricochet_left 次边界反弹，来自局外技能「弹性子弹」）；超时自动消失。


const RADIUS := 6.0
const MAX_LIFETIME := 3.0
## 屏幕边距（反弹判定边界）
const MARGIN := 10.0

var velocity: Vector2 = Vector2.ZERO
var damage: float = 1.0
var ricochet_left: int = 0

var _lifetime: float = 0.0


func setup(dir: Vector2, speed: float, dmg: float, ricochet: int) -> void:
	velocity = dir * speed
	damage = dmg
	ricochet_left = ricochet
	# 黄色圆形色块
	var body: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 20:
		var angle: float = TAU * float(i) / 20.0
		pts.append(Vector2(cos(angle), sin(angle)) * RADIUS)
	body.polygon = pts
	body.color = Color(1.0, 0.95, 0.4, 1)
	add_child(body)


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
