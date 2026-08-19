extends Control

class_name UIBase

var is_open: bool = false
var _initialized: bool = false
var _ui_managed: bool = false  # 标记是否由 UIManager 管理


func _ready() -> void:
	# 如果不是由 UIManager 管理（如 change_scene_to_file 直接加载），自动初始化
	if not _ui_managed:
		on_create()
		on_open()


func on_create():
	_initialized = true
	pass


func on_open():
	is_open = true
	visible = true


func on_close():
	is_open = false
	visible = false


func on_destroy():
	queue_free()


# ---- 公共辅助方法（子类可直接调用） ----

## 给按钮添加背景亮度和 hover 高亮效果
func _add_hover(btn: TextureButton, brightness: float = 1.3) -> void:
	btn.modulate = Color(1.15, 1.15, 1.15, 1)  # 正常态稍亮，使按钮更显眼
	btn.mouse_entered.connect(func(): btn.modulate = Color(brightness, brightness, brightness, 1))
	btn.mouse_exited.connect(func(): btn.modulate = Color(1.15, 1.15, 1.15, 1))


## 刷新金币标签
func _refresh_gold_label(label: Label) -> void:
	if label:
		label.text = "金币: %d" % SaveSystem.get_gold()


## 创建列表行 Panel（带像素风深色样式）
func _create_list_row(min_height: float, bg_color: Color = Color(0.12, 0.14, 0.18, 0.95), border_color: Color = Color(0.3, 0.3, 0.4, 1)) -> Panel:
	var row_node: Panel = Panel.new()
	row_node.custom_minimum_size = Vector2(0, min_height)
	row_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	row_node.add_theme_stylebox_override("panel", style)
	return row_node


## 清理容器所有子节点
func _clear_container(container: Node) -> void:
	if container:
		for child in container.get_children():
			child.queue_free()
