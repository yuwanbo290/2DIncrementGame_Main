extends UIBase

var _upgrade_rows: Array[Dictionary] = []

func on_create():
	var back_btn: TextureButton = $TopBar/BackBtn as TextureButton
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
		_add_hover(back_btn)


func on_open():
	super()
	_refresh_gold()
	_build_upgrade_list()


func on_close():
	super()


func on_destroy():
	super()
	_clear_upgrade_list()


func _refresh_gold() -> void:
	_refresh_gold_label($TopBar/GoldLabel as Label)


func _clear_upgrade_list() -> void:
	_clear_container($MainContainer/Panel/VBox/ScrollContainer/UpgradeList as VBoxContainer)
	_upgrade_rows.clear()


func _build_upgrade_list() -> void:
	_clear_upgrade_list()

	var list: VBoxContainer = $MainContainer/Panel/VBox/ScrollContainer/UpgradeList as VBoxContainer
	var rows: Array[Dictionary] = TableDB.rows_of("upgrade_table")

	var icon_tex: Texture2D = load("res://Textures/ui/btn_upgrade.jpg")

	for row in rows:
		var row_node: Panel = _create_list_row(90)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 20)
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_bottom", 10)
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var inner_hbox: HBoxContainer = HBoxContainer.new()
		inner_hbox.add_theme_constant_override("separation", 20)
		inner_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Icon
		var icon: TextureRect = TextureRect.new()
		icon.texture = icon_tex
		icon.stretch_mode = TextureRect.STRETCH_KEEP
		icon.custom_minimum_size = Vector2(50, 50)

		# Info VBox
		var info_vbox: VBoxContainer = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 5)

		var name_label: Label = Label.new()
		name_label.text = row.get("name", "未知")
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))

		var desc_label: Label = Label.new()
		desc_label.text = row.get("desc", "")
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))

		# Level VBox
		var level_vbox: VBoxContainer = VBoxContainer.new()
		level_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		level_vbox.add_theme_constant_override("separation", 5)

		var level: int = SaveSystem.get_upgrade_level(row.get("id", ""))
		var max_level: int = row.get("max_level", 10)
		var level_label: Label = Label.new()
		level_label.text = "等级 %d / %d" % [level, max_level]
		level_label.add_theme_font_size_override("font_size", 18)
		level_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var cost: int = _calc_upgrade_cost(row, level)
		var cost_label: Label = Label.new()
		if level >= max_level:
			cost_label.text = "已满级"
			cost_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		else:
			cost_label.text = "花费: %d" % cost
			var gold: int = SaveSystem.get_gold()
			if gold >= cost:
				cost_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
			else:
				cost_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
		cost_label.add_theme_font_size_override("font_size", 14)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		# Upgrade button
		var upg_btn: TextureButton = TextureButton.new()
		var btn_tex: Texture2D = load("res://Textures/ui/btn_start.jpg")
		upg_btn.texture_normal = btn_tex
		upg_btn.stretch_mode = TextureButton.STRETCH_KEEP
		upg_btn.custom_minimum_size = Vector2(100, 50)

		var upg_label: Label = Label.new()
		upg_label.text = "升级"
		upg_label.add_theme_font_size_override("font_size", 18)
		upg_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		upg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		upg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		upg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		upg_btn.add_child(upg_label)

		if level >= max_level:
			upg_btn.disabled = true
		else:
			var upg_id: String = row.get("id", "")
			upg_btn.pressed.connect(_on_upgrade_pressed.bind(upg_id))
		_add_hover(upg_btn)

		# Assemble
		info_vbox.add_child(name_label)
		info_vbox.add_child(desc_label)

		level_vbox.add_child(level_label)
		level_vbox.add_child(cost_label)

		inner_hbox.add_child(icon)
		inner_hbox.add_child(info_vbox)
		inner_hbox.add_child(level_vbox)
		inner_hbox.add_child(upg_btn)

		margin.add_child(inner_hbox)
		hbox.add_child(margin)
		row_node.add_child(hbox)
		list.add_child(row_node)

		_upgrade_rows.append({
			"id": row.get("id", ""),
			"level_label": level_label,
			"cost_label": cost_label,
			"upg_btn": upg_btn,
		})


func _calc_upgrade_cost(row: Dictionary, current_level: int) -> int:
	var base_cost: int = row.get("base_cost", 100)
	var multiplier: float = row.get("cost_multiplier", 1.5)
	var cost: float = base_cost * pow(multiplier, current_level)
	return int(cost)


func _on_upgrade_pressed(upgrade_id: String) -> void:
	var row: Dictionary = TableDB.get_first("upgrade_table", "id", upgrade_id)
	if row.is_empty():
		return

	var current_level: int = SaveSystem.get_upgrade_level(upgrade_id)
	var max_level: int = row.get("max_level", 10)
	if current_level >= max_level:
		return

	var cost: int = _calc_upgrade_cost(row, current_level)
	var gold: int = SaveSystem.get_gold()
	if gold < cost:
		return

	SaveSystem.set_gold(gold - cost)
	SaveSystem.set_upgrade_level(upgrade_id, current_level + 1)
	SaveSystem.save()

	_refresh_gold()
	_build_upgrade_list()


func _on_back_pressed() -> void:
	UIManager.close_ui("out_of_battle_upgrade")
