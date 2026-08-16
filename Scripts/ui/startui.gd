extends UIBase


func on_create():
	print("开始界面创建")
	var start_btn := $Bg/CenterContainer/VBoxContainer/StartBtn as Button
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
	# 连接退出按钮的点击信号
	var exit_btn := $Bg/CenterContainer/VBoxContainer/ExitBtn as Button
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_pressed)
	print("开始界面打开")
	
func _on_start_pressed() -> void:
	# 切换到 Main 场景（假设 Main.tscn 在项目根目录）
	get_tree().change_scene_to_file("res://Scenes/weapon_test.tscn")

# 点击退出按钮时退出游戏
func _on_exit_pressed() -> void:
	get_tree().quit()

func on_open():
	super()


func on_close():
	super()

	print("开始界面关闭")


func on_destroy():
	print("开始界面销毁")

	super()
