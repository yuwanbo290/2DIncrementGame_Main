class_name DragScroll
extends ScrollContainer
## 通用拖拽滚动：按住内容空白处拖动可平移滚动视图。
## 适用于商店 / 武器 / 局外养成等列表界面；按钮区域点击不受影响。


var _dragging: bool = false
var _last_mouse: Vector2 = Vector2.ZERO


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			_last_mouse = mb.position
			accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging:
			var delta: Vector2 = motion.position - _last_mouse
			_last_mouse = motion.position
			scroll_horizontal -= int(delta.x)
			scroll_vertical -= int(delta.y)
			accept_event()
