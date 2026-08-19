extends UIBase

func on_create():
	var back_btn: TextureButton = $TopBar/BackBtn as TextureButton
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
		_add_hover(back_btn)


func on_open():
	super()
	_refresh_current_weapon()
	_build_weapon_list()


func on_close():
	super()


func on_destroy():
	super()
	_clear_weapon_list()


func _refresh_current_weapon() -> void:
	var label: Label = $TopBar/CurrentWeaponLabel as Label
	if label:
		var slot: Dictionary = SaveSystem.get_current_slot()
		var weapon_id: String = slot.get("weapon_id", "")
		if weapon_id == "":
			label.text = "当前: 未装备"
		else:
			var weapon: Dictionary = TableDB.get_first("weapon_table", "id", weapon_id)
			var weapon_name: String = weapon.get("name", "未知") if not weapon.is_empty() else "未知"
			label.text = "当前: %s" % weapon_name


func _clear_weapon_list() -> void:
	_clear_container($MainContainer/Panel/VBox/ScrollContainer/WeaponList as VBoxContainer)


func _build_weapon_list() -> void:
	_clear_weapon_list()

	var list: VBoxContainer = $MainContainer/Panel/VBox/ScrollContainer/WeaponList as VBoxContainer
	var rows: Array[Dictionary] = TableDB.rows_of("weapon_table")
	var owned: Array = _get_owned_weapons()
	var current_weapon: String = _get_current_weapon_id()
	var icon_tex: Texture2D = load("res://Textures/ui/btn_equip.jpg")
	var btn_tex: Texture2D = load("res://Textures/ui/btn_start.jpg")

	for row in rows:
		var weapon_id: String = row.get("id", "")
		var is_owned: bool = weapon_id in owned or row.get("unlocked", false)
		var is_equipped: bool = (weapon_id == current_weapon)

		var row_node: Panel
		if is_equipped:
			row_node = _create_list_row(100, Color(0.15, 0.25, 0.15, 0.95), Color(0.3, 1.0, 0.5, 1))
		elif not is_owned:
			row_node = _create_list_row(100, Color(0.12, 0.12, 0.12, 0.95), Color(0.3, 0.3, 0.3, 1))
		else:
			row_node = _create_list_row(100)

		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_bottom", 10)
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 20)
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

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
		name_label.add_theme_font_size_override("font_size", 22)
		if not is_owned:
			name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		else:
			name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))

		var desc_label: Label = Label.new()
		desc_label.text = row.get("desc", "")
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))

		# Stats
		var stats_hbox: HBoxContainer = HBoxContainer.new()
		stats_hbox.add_theme_constant_override("separation", 30)

		var dmg_label: Label = Label.new()
		dmg_label.text = "伤害: %d" % row.get("damage", 0)
		dmg_label.add_theme_font_size_override("font_size", 14)
		dmg_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))

		var rate: float = row.get("fire_rate", 1.0)
		var rate_label: Label = Label.new()
		rate_label.text = "射速: %.1f/s" % (1.0 / rate)
		rate_label.add_theme_font_size_override("font_size", 14)
		rate_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))

		var mag_label: Label = Label.new()
		mag_label.text = "弹夹: %d" % row.get("magazine_size", 0)
		mag_label.add_theme_font_size_override("font_size", 14)
		mag_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))

		stats_hbox.add_child(dmg_label)
		stats_hbox.add_child(rate_label)
		stats_hbox.add_child(mag_label)

		info_vbox.add_child(name_label)
		info_vbox.add_child(desc_label)
		info_vbox.add_child(stats_hbox)

		# Status / Action
		var action_vbox: VBoxContainer = VBoxContainer.new()
		action_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		action_vbox.add_theme_constant_override("separation", 5)

		if is_equipped:
			var equipped_label: Label = Label.new()
			equipped_label.text = "已装备"
			equipped_label.add_theme_font_size_override("font_size", 20)
			equipped_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1))
			equipped_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			action_vbox.add_child(equipped_label)
		elif not is_owned:
			var locked_label: Label = Label.new()
			locked_label.text = "未解锁"
			locked_label.add_theme_font_size_override("font_size", 20)
			locked_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
			locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			action_vbox.add_child(locked_label)
		else:
			var equip_btn: TextureButton = TextureButton.new()
			equip_btn.texture_normal = btn_tex
			equip_btn.stretch_mode = TextureButton.STRETCH_KEEP
			equip_btn.custom_minimum_size = Vector2(120, 50)

			var equip_label: Label = Label.new()
			equip_label.text = "装备"
			equip_label.add_theme_font_size_override("font_size", 20)
			equip_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			equip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			equip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			equip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			equip_btn.add_child(equip_label)

			equip_btn.pressed.connect(_on_equip_weapon.bind(weapon_id))
			_add_hover(equip_btn)
			action_vbox.add_child(equip_btn)

		# Assemble
		hbox.add_child(icon)
		hbox.add_child(info_vbox)
		hbox.add_child(action_vbox)

		margin.add_child(hbox)
		row_node.add_child(margin)
		list.add_child(row_node)


func _get_owned_weapons() -> Array:
	var slot: Dictionary = SaveSystem.get_current_slot()
	var weapons: Array = slot.get("owned_weapons", [])
	var rows: Array[Dictionary] = TableDB.rows_of("weapon_table")
	for row in rows:
		if row.get("unlocked", false) and not weapons.has(row.get("id", "")):
			weapons.append(row.get("id", ""))
	return weapons


func _get_current_weapon_id() -> String:
	var slot: Dictionary = SaveSystem.get_current_slot()
	return slot.get("weapon_id", "")


func _on_equip_weapon(weapon_id: String) -> void:
	var slot: Dictionary = SaveSystem.get_current_slot()
	slot["weapon_id"] = weapon_id
	SaveSystem.set_slot(SaveSystem.current_slot, slot)
	SaveSystem.save()

	_refresh_current_weapon()
	_build_weapon_list()


func _on_back_pressed() -> void:
	UIManager.close_ui("equipment")
