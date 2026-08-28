extends UIBase

const GAME_SCENE: String = "res://Scenes/ui/preparation.tscn"

@onready var _slot_container: HBoxContainer = $MainContainer/VBox/SlotContainer


func _ready() -> void:
	($TopBar/BackBtn as Button).pressed.connect(_on_back_pressed)
	for slot_index in SaveSystem.SLOT_COUNT:
		_bind_slot(slot_index)
	super()


func refresh() -> void:
	refresh_all_slots()


func _bind_slot(slot_index: int) -> void:
	var panel: Panel = _slot_container.get_child(slot_index) as Panel
	var select_btn: Button = panel.get_node("Margin/VBox/Buttons/SelectBtn") as Button
	var delete_btn: Button = panel.get_node("Margin/VBox/Buttons/DeleteBtn") as Button
	select_btn.pressed.connect(_on_slot_selected.bind(slot_index))
	delete_btn.pressed.connect(_on_slot_delete.bind(slot_index))

	# 存档槽 Panel hover 选中效果
	panel.mouse_entered.connect(func(): panel.modulate = Color(1.12, 1.12, 1.12, 1))
	panel.mouse_exited.connect(func(): panel.modulate = Color(1, 1, 1, 1))


func refresh_all_slots() -> void:
	for i in SaveSystem.SLOT_COUNT:
		_refresh_slot(i)


func _refresh_slot(slot_index: int) -> void:
	var slot_data: Dictionary = SaveSystem.get_slot(slot_index)
	var is_empty: bool = SaveSystem.is_slot_empty(slot_index)

	var panel: Panel = _slot_container.get_child(slot_index) as Panel
	var content: VBoxContainer = panel.get_node("Margin/VBox") as VBoxContainer
	var name_label: Label = content.get_node("Name") as Label
	var status_label: Label = content.get_node("Status") as Label
	var playtime_label: Label = content.get_node("Info/Playtime") as Label
	var last_played_label: Label = content.get_node("Info/LastPlayed") as Label
	var select_btn: Button = content.get_node("Buttons/SelectBtn") as Button
	var delete_btn: Button = content.get_node("Buttons/DeleteBtn") as Button

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
		select_btn.text = "创建"
		delete_btn.visible = false
		style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
		style.border_color = Color(0.4, 0.4, 0.5, 1)
	else:
		name_label.text = slot_data.get("name", "存档 %d" % (slot_index + 1))
		status_label.text = "存档中"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1))
		playtime_label.text = "游玩时间: %s" % SaveSystem.get_playtime_text(slot_data.get("playtime", 0.0))
		last_played_label.text = "上次游玩: %s" % SaveSystem.get_last_played_text(slot_data.get("last_played", 0))
		select_btn.text = "继续"
		delete_btn.visible = true
		style.bg_color = Color(0.12, 0.18, 0.25, 0.95)
		style.border_color = Color(0.3, 0.6, 1.0, 1)

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
