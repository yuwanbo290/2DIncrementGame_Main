@tool
extends EditorPlugin
## 导表插件：在工具栏加「导表」按钮，并在「项目 > 工具」菜单加同名项。
## 点击后把 data/ 下的所有 .xlsx 源表导出为 Resources/Tables/ 下的 .tres。


const TableExporterCore = preload("res://addons/table_exporter/table_exporter_core.gd")

const MENU_NAME := "导表：xlsx → .tres"

var _button: Button


func _enter_tree() -> void:
	_button = Button.new()
	_button.text = "导表"
	_button.tooltip_text = "将 data/ 下的 .xlsx 源表导出为 Resources/Tables/ 下的 .tres"
	_button.pressed.connect(_on_export)
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, _button)
	add_tool_menu_item(MENU_NAME, _on_export)


func _exit_tree() -> void:
	if is_instance_valid(_button):
		_button.queue_free()
		_button = null
	remove_tool_menu_item(MENU_NAME)


func _on_export() -> void:
	TableExporterCore.export_all()
	# 刷新文件系统，让新生成的 .tres 立即出现在 FileSystem 面板
	EditorInterface.get_resource_filesystem().scan()
