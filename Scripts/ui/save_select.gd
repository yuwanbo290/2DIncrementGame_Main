extends UIBase

const GAME_SCENE: String = "res://Scenes/ui/preparation.tscn"

@onready var _slot_container: HBoxContainer = $MainContainer/VBox/SlotContainer
@onready var _back_btn: Button = %BackBtn


func _ready() -> void:
	_back_btn.pressed.connect(_on_back_pressed)
	for slot_index in SaveSystem.SLOT_COUNT:
		_bind_slot(slot_index)
	super()


func refresh() -> void:
	refresh_all_slots()
	# 等容器完成首帧排版后，再按卡片顺序播放入场。
	call_deferred("_reveal_slots")


func _bind_slot(slot_index: int) -> void:
	var panel: Panel = _slot_container.get_child(slot_index) as Panel
	var select_btn: Button = panel.get_node("Margin/VBox/Buttons/SelectBtn") as Button
	var delete_btn: Button = panel.get_node("Margin/VBox/Buttons/DeleteBtn") as Button
	select_btn.pressed.connect(_on_slot_selected.bind(slot_index))
	delete_btn.pressed.connect(_on_slot_delete.bind(slot_index))


func refresh_all_slots() -> void:
	for i in SaveSystem.SLOT_COUNT:
		_refresh_slot(i)
	_configure_focus_neighbors()


## 三张存档卡按索引错峰入场；仅页面打开时调用，普通内容刷新不重复播放。
func _reveal_slots() -> void:
	if not visible:
		return
	for slot_index in SaveSystem.SLOT_COUNT:
		UIBase.reveal_card(_slot_container.get_child(slot_index) as Control, slot_index)


func _focus_slot(slot_index: int) -> void:
	if not visible or slot_index < 0 or slot_index >= SaveSystem.SLOT_COUNT:
		return
	var panel: Panel = _slot_container.get_child(slot_index) as Panel
	(panel.get_node("Margin/VBox/Buttons/SelectBtn") as Button).grab_focus()


## 左右键在三张卡的主操作间移动；有删除操作时向下进入危险按钮。
func _configure_focus_neighbors() -> void:
	var select_buttons: Array[Button] = []
	var delete_buttons: Array[Button] = []
	for slot_index in SaveSystem.SLOT_COUNT:
		var panel: Panel = _slot_container.get_child(slot_index) as Panel
		var buttons: HBoxContainer = panel.get_node("Margin/VBox/Buttons") as HBoxContainer
		select_buttons.append(buttons.get_node("SelectBtn") as Button)
		delete_buttons.append(buttons.get_node("DeleteBtn") as Button)

	for slot_index in SaveSystem.SLOT_COUNT:
		var select_btn: Button = select_buttons[slot_index]
		var delete_btn: Button = delete_buttons[slot_index]
		select_btn.focus_neighbor_left = NodePath("")
		select_btn.focus_neighbor_right = NodePath("")
		select_btn.focus_neighbor_bottom = NodePath("")
		delete_btn.focus_neighbor_top = NodePath("")
		if slot_index > 0:
			select_btn.focus_neighbor_left = select_btn.get_path_to(select_buttons[slot_index - 1])
		if slot_index + 1 < SaveSystem.SLOT_COUNT:
			select_btn.focus_neighbor_right = select_btn.get_path_to(select_buttons[slot_index + 1])
		if delete_btn.visible:
			select_btn.focus_neighbor_bottom = select_btn.get_path_to(delete_btn)
			delete_btn.focus_neighbor_top = delete_btn.get_path_to(select_btn)

	_back_btn.focus_neighbor_bottom = _back_btn.get_path_to(select_buttons[0])
	select_buttons[0].focus_neighbor_top = select_buttons[0].get_path_to(_back_btn)


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
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10

	if is_empty:
		name_label.text = "存档 %d" % (slot_index + 1)
		status_label.text = "空存档 · 点击创建新游戏"
		status_label.add_theme_color_override("font_color", Color(0.667, 0.714, 0.675, 1))
		playtime_label.text = "游玩时间: --"
		last_played_label.text = "上次游玩: --"
		select_btn.text = "创建"
		delete_btn.visible = false
		style.bg_color = Color(0.078, 0.102, 0.094, 0.97)
		style.border_color = Color(0.35, 0.4, 0.36, 1)
	else:
		name_label.text = slot_data.get("name", "存档 %d" % (slot_index + 1))
		status_label.text = "存档中"
		status_label.add_theme_color_override("font_color", Color(0.659, 0.827, 0.357, 1))
		playtime_label.text = "游玩时间: %s" % SaveSystem.get_playtime_text(slot_data.get("playtime", 0.0))
		last_played_label.text = "上次游玩: %s" % SaveSystem.get_last_played_text(slot_data.get("last_played", 0))
		select_btn.text = "继续"
		delete_btn.visible = true
		style.bg_color = Color(0.125, 0.161, 0.137, 0.98)
		style.border_color = Color(0.659, 0.827, 0.357, 1)

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
			call_deferred("_focus_slot", slot_index)
	)


func _on_back_pressed() -> void:
	UIManager.close_ui("save_select")
	UIManager.open_ui("start_ui", "res://Scenes/ui/start_ui.tscn")


func _save_and_enter_game() -> void:
	SaveSystem.save()
	UIManager.close_ui("save_select")
	UIManager.open_ui("preparation", GAME_SCENE)
