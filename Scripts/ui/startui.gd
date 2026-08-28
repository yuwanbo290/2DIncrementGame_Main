extends UIBase

@onready var _start_btn: Button = %BtnStart
@onready var _settings_btn: Button = %BtnSettings
@onready var _exit_btn: Button = %BtnExit


func _ready() -> void:
	_start_btn.pressed.connect(_on_start_pressed)
	_settings_btn.pressed.connect(_on_settings_pressed)
	_exit_btn.pressed.connect(_on_exit_pressed)
	super()


func _on_start_pressed() -> void:
	# 关闭当前UI，打开存档选择界面
	UIManager.close_ui("start_ui")
	UIManager.open_ui("save_select", "res://Scenes/ui/save_select.tscn")


func _on_settings_pressed() -> void:
	UIManager.open_ui("settings", "res://Scenes/ui/settings.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()
