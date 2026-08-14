extends UIBase


func on_create():
	print("开始界面创建")
	# 连接退出按钮的点击信号
	var exit_btn := $Bg/CenterContainer/VBoxContainer/ExitBtn as Button
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_pressed)
	print("开始界面打开")

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
