extends UIBase

func on_create():
	var back_btn: TextureButton = $TopBar/BackBtn as TextureButton
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
		_add_hover(back_btn)


func on_open():
	super()
	_refresh_gold()
	_build_weapon_list()


func on_close():
	super()


func on_destroy():
	super()
	_clear_weapon_list()


func _refresh_gold() -> void:
	_refresh_gold_label($TopBar/GoldLabel as Label)


func _clear_weapon_list() -> void:
	_clear_container($MainContainer/Panel/VBox/ScrollContainer/WeaponList as VBoxContainer)


func _build_weapon_list() -> void:
	_clear_weapon_list()

	var list: VBoxContainer = $MainContainer/Panel/VBox/ScrollContainer/WeaponList as VBoxContainer
	var rows: Array[Dictionary] = TableDB.rows_of("weapon_table")
	var owned: Array = _get_owned_weapons()
	var icon_tex: Texture2D = load("res://Textures/ui/btn_shop.jpg")
	var btn_tex: Texture2D = load("res://Textures/ui/btn_start.jpg")

	for row in rows:
		var row_node: Panel = _create_list_row(90)

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
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))

		var desc_label: Label = Label.new()
		desc_label.text = row.get("desc", "")
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))

		# Stats VBox
		var stats_vbox: VBoxContainer = VBoxContainer.new()
		stats_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		stats_vbox.add_theme_constant_override("separation", 3)

		var dmg_label: Label = Label.new()
		dmg_label.text = "伤害: %d" % row.get("damage", 0)
		dmg_label.add_theme_font_size_override("font_size", 14)
		dmg_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))

		var rate_label: Label = Label.new()
		var rate: float = row.get("fire_rate", 1.0)
		rate_label.text = "射速: %.1f/s" % (1.0 / rate)
		rate_label.add_theme_font_size_override("font_size", 14)
		rate_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))

		stats_vbox.add_child(dmg_label)
		stats_vbox.add_child(rate_label)

		# Price / Status
		var status_vbox: VBoxContainer = VBoxContainer.new()
		status_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		status_vbox.add_theme_constant_override("separation", 5)

		var weapon_id: String = row.get("id", "")
		var is_owned: bool = weapon_id in owned
		var is_default: bool = row.get("unlocked", false)

		if is_owned or is_default:
			var owned_label: Label = Label.new()
			owned_label.text = "已拥有"
			owned_label.add_theme_font_size_override("font_size", 20)
			owned_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1))
			owned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			status_vbox.add_child(owned_label)
		else:
			var price: int = row.get("price", 0)
			var price_label: Label = Label.new()
			price_label.text = "价格: %d" % price
			price_label.add_theme_font_size_override("font_size", 16)
			price_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
			price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

			var buy_btn: TextureButton = TextureButton.new()
			buy_btn.texture_normal = btn_tex
			buy_btn.stretch_mode = TextureButton.STRETCH_KEEP
			buy_btn.custom_minimum_size = Vector2(100, 40)

			var buy_label: Label = Label.new()
			buy_label.text = "购买"
			buy_label.add_theme_font_size_override("font_size", 16)
			buy_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			buy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			buy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			buy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			buy_btn.add_child(buy_label)

			var gold: int = SaveSystem.get_gold()
			if gold < price:
				buy_btn.disabled = true
				price_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))

			buy_btn.pressed.connect(_on_buy_weapon.bind(weapon_id, price))
			_add_hover(buy_btn)

			status_vbox.add_child(price_label)
			status_vbox.add_child(buy_btn)

		# Assemble
		info_vbox.add_child(name_label)
		info_vbox.add_child(desc_label)

		hbox.add_child(icon)
		hbox.add_child(info_vbox)
		hbox.add_child(stats_vbox)
		hbox.add_child(status_vbox)

		margin.add_child(hbox)
		row_node.add_child(margin)
		list.add_child(row_node)


func _get_owned_weapons() -> Array:
	var slot: Dictionary = SaveSystem.get_current_slot()
	var weapons: Array = slot.get("owned_weapons", [])
	return weapons


func _on_buy_weapon(weapon_id: String, price: int) -> void:
	var gold: int = SaveSystem.get_gold()
	if gold < price:
		return

	SaveSystem.set_gold(gold - price)

	var slot: Dictionary = SaveSystem.get_current_slot()
	var weapons: Array = slot.get("owned_weapons", [])
	if not weapons.has(weapon_id):
		weapons.append(weapon_id)
	slot["owned_weapons"] = weapons
	SaveSystem.set_slot(SaveSystem.current_slot, slot)
	SaveSystem.save()

	_refresh_gold()
	_build_weapon_list()


func _on_back_pressed() -> void:
	UIManager.close_ui("shop")
