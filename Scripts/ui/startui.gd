extends UIBase

func on_create():
	var btn_start: TextureButton = $CenterContainer/MainVBox/BtnStart as TextureButton
	var btn_settings: TextureButton = $CenterContainer/MainVBox/BtnSettings as TextureButton
	var btn_exit: TextureButton = $CenterContainer/MainVBox/BtnExit as TextureButton

	if btn_start:
		btn_start.pressed.connect(_on_start_pressed)
		_add_hover(btn_start)
	if btn_settings:
		btn_settings.pressed.connect(_on_settings_pressed)
		_add_hover(btn_settings)
	if btn_exit:
		btn_exit.pressed.connect(_on_exit_pressed)
		_add_hover(btn_exit)


func on_open():
	super()


func on_close():
	super()


func on_destroy():
	super()


func _on_start_pressed() -> void:
	# 关闭当前UI，打开存档选择界面
	UIManager.close_ui("start_ui")
	UIManager.open_ui("save_select", "res://Scenes/ui/save_select.tscn")


func _on_settings_pressed() -> void:
	UIManager.open_ui("settings", "res://Scenes/ui/settings.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()
