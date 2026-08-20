class_name BattlePlayer
extends Node2D
## 玩家（色块占位实现）：固定在画面底部中央的绿色圆形色块 + "玩家"文字。
## 瞄准：枪口指向鼠标方向；射击：按住左键持续射击，冷却由武器 atkSpeed 决定。
## 子弹由 BattleManager 生成（多弹散布也由管理器处理），本类只负责瞄准与开火判定。


signal fire_requested(dir: Vector2)

const BODY_RADIUS := 20.0
const MARGIN_BOTTOM := 70.0
## 弹道指示线长度
const AIM_LINE_LEN := 44.0

var fire_interval: float = 1.0
var _cooldown: float = 0.0
var _body: Polygon2D
var _aim_line: Line2D


func setup(player_pos: Vector2, interval: float) -> void:
	fire_interval = maxf(interval, 0.05)
	position = player_pos
	_build_body()


func _build_body() -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 24:
		var angle: float = TAU * float(i) / 24.0
		pts.append(Vector2(cos(angle), sin(angle)) * BODY_RADIUS)
	_body = Polygon2D.new()
	_body.polygon = pts
	_body.color = Color(0.3, 0.95, 0.4, 1)
	add_child(_body)

	var label: Label = Label.new()
	label.text = "玩家"
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.position = Vector2(-BODY_RADIUS, -BODY_RADIUS)
	label.size = Vector2(BODY_RADIUS * 2.0, BODY_RADIUS * 2.0)

	# 瞄准线（指向鼠标方向）
	_aim_line = Line2D.new()
	_aim_line.width = 3.0
	_aim_line.default_color = Color(1, 1, 1, 0.5)
	_aim_line.points = PackedVector2Array([Vector2.ZERO, Vector2(0, -AIM_LINE_LEN)])
	add_child(_aim_line)


func get_aim_direction() -> Vector2:
	var view: Vector2 = get_viewport_rect().size if get_viewport() != null else Vector2(1920, 1080)
	var mouse: Vector2 = get_global_mouse_position() if get_viewport() != null else Vector2(view.x / 2.0, 100.0)
	var dir: Vector2 = (mouse - global_position)
	if dir.length_squared() < 0.01:
		dir = Vector2(0, -1)
	return dir.normalized()


func _process(delta: float) -> void:
	# 瞄准线朝向鼠标
	var dir: Vector2 = get_aim_direction()
	if _aim_line != null:
		_aim_line.points = PackedVector2Array([Vector2.ZERO, dir * AIM_LINE_LEN])

	# 按住左键持续射击
	_cooldown -= delta
	if _cooldown <= 0.0 and Input.is_action_pressed("click"):
		fire_requested.emit(dir)
		_cooldown = fire_interval
