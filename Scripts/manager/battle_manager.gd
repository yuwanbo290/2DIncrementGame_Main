extends Node2D

func _ready() -> void:
	# 显示当前金币和存档信息
	var gold_label: Label = $UI/TopBar/GoldLabel as Label
	if gold_label:
		gold_label.text = "金币: %d" % SaveSystem.get_gold()

	# 绑定返回按钮
	var back_btn: TextureButton = $UI/TopBar/BackBtn as TextureButton
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
		back_btn.modulate = Color(1.15, 1.15, 1.15, 1)
		back_btn.mouse_entered.connect(func(): back_btn.modulate = Color(1.3, 1.3, 1.3, 1))
		back_btn.mouse_exited.connect(func(): back_btn.modulate = Color(1.15, 1.15, 1.15, 1))


func _on_back_pressed() -> void:
	# 返回备战界面
	get_tree().change_scene_to_file("res://Scenes/ui/preparation.tscn")
