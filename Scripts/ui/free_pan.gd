class_name FreePan
extends Control
## 自由平移视口：拖动空白区域时直接移动子画布，不受滚动范围限制。


@export var target_path: NodePath = NodePath("TreeCanvas")

var _dragging: bool = false
var _last_pointer: Vector2 = Vector2.ZERO

@onready var _target: Control = get_node_or_null(target_path) as Control


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_MOVE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mouse_button.pressed
			_last_pointer = mouse_button.position
			mouse_default_cursor_shape = Control.CURSOR_DRAG if _dragging else Control.CURSOR_MOVE
			accept_event()
	elif event is InputEventMouseMotion and _dragging and _target:
		var motion := event as InputEventMouseMotion
		_target.position += motion.position - _last_pointer
		_last_pointer = motion.position
		accept_event()
