extends UIBase

const GAME_SCENE: String = "res://Scenes/ui/preparation.tscn"

func on_create():
	var back_btn: TextureButton = $TopBar/BackBtn as TextureButton
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
		_add_hover(back_btn)

	_bind_slot(0)
	_bind_slot(1)
	_bind_slot(2)


func on_open():
	super()
	refresh_all_slots()


func on_close():
	super()


func on_destroy():
	super()


func _bind_slot(slot_index: int) -> void:
	var path_prefix: String = "MainContainer/VBox/SlotContainer/Slot%d/Slot%dMargin/Slot%dVBox/Slot%dBtns" % [slot_index, slot_index, slot_index, slot_index]
	var select_btn: TextureButton = get_node(path_prefix + "/Slot%dSelectBtn" % slot_index) as TextureButton
	var delete_btn: TextureButton = get_node(path_prefix + "/Slot%dDeleteBtn" % slot_index) as TextureButton

	if select_btn:
		select_btn.pressed.connect(_on_slot_selected.bind(slot_index))
		_add_hover(select_btn)
	if delete_btn:
		delete_btn.pressed.connect(_on_slot_delete.bind(slot_index))
		_add_hover(delete_btn)

	# 存档槽 Panel hover 选中效果
	var panel: Panel = get_node("MainContainer/VBox/SlotContainer/Slot%d" % slot_index) as Panel
	if panel:
		panel.mouse_entered.connect(func(): panel.modulate = Color(1.12, 1.12, 1.12, 1))
		panel.mouse_exited.connect(func(): panel.modulate = Color(1, 1, 1, 1))


func refresh_all_slots() -> void:
	for i in range(3):
		_refresh_slot(i)


func _refresh_slot(slot_index: int) -> void:
	var slot_data: Dictionary = SaveSystem.get_slot(slot_index)
	var is_empty: bool = SaveSystem.is_slot_empty(slot_index)

	var p: String = "MainContainer/VBox/SlotContainer/Slot%d/Slot%dMargin/Slot%dVBox" % [slot_index, slot_index, slot_index]
	var name_label: Label = get_node(p + "/Slot%dName" % slot_index) as Label
	var status_label: Label = get_node(p + "/Slot%dStatus" % slot_index) as Label
	var playtime_label: Label = get_node(p + "/Slot%dInfo/Slot%dPlaytime" % [slot_index, slot_index]) as Label
	var last_played_label: Label = get_node(p + "/Slot%dInfo/Slot%dLastPlayed" % [slot_index, slot_index]) as Label
	var select_label: Label = get_node(p + "/Slot%dBtns/Slot%dSelectBtn/Slot%dSelectLabel" % [slot_index, slot_index, slot_index]) as Label
	var delete_btn: TextureButton = get_node(p + "/Slot%dBtns/Slot%dDeleteBtn" % [slot_index, slot_index]) as TextureButton
	var panel: Panel = get_node("MainContainer/VBox/SlotContainer/Slot%d" % slot_index) as Panel

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8

	if is_empty:
		name_label.text = "存档 %d" % (slot_index + 1)
		status_label.text = "空存档 · 点击创建新游戏"
		status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		playtime_label.text = "游玩时间: --"
		last_played_label.text = "上次游玩: --"
		select_label.text = "创建"
		if delete_btn:
			delete_btn.visible = false
		style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
		style.border_color = Color(0.4, 0.4, 0.5, 1)
	else:
		name_label.text = slot_data.get("name", "存档 %d" % (slot_index + 1))
		status_label.text = "存档中"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1))
		playtime_label.text = "游玩时间: %s" % SaveSystem.get_playtime_text(slot_data.get("playtime", 0.0))
		last_played_label.text = "上次游玩: %s" % SaveSystem.get_last_played_text(slot_data.get("last_played", 0))
		select_label.text = "继续"
		if delete_btn:
			delete_btn.visible = true
		style.bg_color = Color(0.12, 0.18, 0.25, 0.95)
		style.border_color = Color(0.3, 0.6, 1.0, 1)

	if panel:
		panel.add_theme_stylebox_override("panel", style)


func _on_slot_selected(slot_index: int) -> void:
	if SaveSystem.is_slot_empty(slot_index):
		SaveSystem.create_slot(slot_index, "存档 %d" % (slot_index + 1))
	SaveSystem.select_slot(slot_index)
	_save_and_enter_game()


func _on_slot_delete(slot_index: int) -> void:
	if SaveSystem.is_slot_empty(slot_index):
		return # 空存档无需删除

	var dialog_scene: PackedScene = load("res://Scenes/ui/confirm_dialog.tscn")
	var dialog: ConfirmDialog = dialog_scene.instantiate() as ConfirmDialog
	add_child(dialog)
	dialog.setup(
		"确认删除",
		"确定要删除存档 %d 吗？\n此操作无法撤销。" % (slot_index + 1),
		func():
			SaveSystem.delete_slot(slot_index)
			refresh_all_slots()
	)


func _on_back_pressed() -> void:
	UIManager.close_ui("save_select")
	UIManager.open_ui("start_ui", "res://Scenes/ui/start_ui.tscn")


func _save_and_enter_game() -> void:
	SaveSystem.save()
	UIManager.close_ui("save_select")
	UIManager.open_ui("preparation", GAME_SCENE)
