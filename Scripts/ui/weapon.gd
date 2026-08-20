extends UIBase
## 武器界面：以 weapons 表为数据源，展示全部武器并装备已拥有的武器。
##
## 「是否拥有」= 表内 isDefault=1 的默认武器 ∪ 存档已购武器，判定统一走 WeaponService。
## 未拥有的武器置灰并提示到商店购买；装备结果写入存档并立即落盘。


const ROW_HEIGHT := 110.0
const BUTTON_SIZE := Vector2(150, 50)
const STAT_LABEL_WIDTH := 190.0

const COLOR_TEXT := Color(1, 1, 1, 1)
const COLOR_DESC := Color(0.7, 0.7, 0.7, 1)
const COLOR_STAT := Color(0.75, 0.85, 1, 1)
const COLOR_EQUIPPED := Color(0.5, 1, 0.6, 1)
const COLOR_DISABLED := Color(0.5, 0.5, 0.5, 1)


func on_create():
	var back_btn: TextureButton = $TopBar/BackBtn as TextureButton
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
		_add_hover(back_btn)


func on_open():
	super()
	_refresh_equipped_label()
	_build_weapon_list()


func on_close():
	super()


func on_destroy():
	super()
	_clear_weapon_list()


func _refresh_equipped_label() -> void:
	var label: Label = $TopBar/EquippedLabel as Label
	if label == null:
		return
	var row: Dictionary = WeaponService.get_equipped_stats()
	if row.is_empty():
		label.text = "当前武器: 无"
		return
	label.text = "当前武器: %s" % str(row.get(WeaponService.FIELD_NAME, "-"))


func _get_list() -> VBoxContainer:
	return $MainContainer/Panel/VBox/Margin/ScrollContainer/WeaponList as VBoxContainer


func _clear_weapon_list() -> void:
	_clear_container(_get_list())


func _build_weapon_list() -> void:
	_clear_weapon_list()

	var list: VBoxContainer = _get_list()
	if list == null:
		push_error("[武器] 找不到武器列表容器 WeaponList")
		return

	var rows: Array[Dictionary] = WeaponService.get_all()
	if rows.is_empty():
		list.add_child(_create_empty_hint("暂无武器数据"))
		return

	var equipped_id: int = WeaponService.get_equipped_id()
	for weapon in rows:
		list.add_child(_create_weapon_row(weapon, equipped_id))


## 构建一行武器（信息列 + 属性列 + 装备按钮）
func _create_weapon_row(weapon: Dictionary, equipped_id: int) -> Panel:
	var weapon_id: int = int(weapon.get(WeaponService.FIELD_ID, 0))
	var is_owned: bool = WeaponService.is_owned(weapon_id)
	var is_equipped: bool = weapon_id == equipped_id

	# 已装备的武器用绿色边框区分
	var row_node: Panel = _create_list_row(ROW_HEIGHT) if not is_equipped else _create_list_row(
		ROW_HEIGHT, Color(0.1, 0.18, 0.14, 0.95), COLOR_EQUIPPED
	)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 10)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 信息列：武器名（含默认/已装备标记）+ 描述
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 5)

	var name_label: Label = Label.new()
	name_label.text = _build_name_text(weapon, weapon_id, is_equipped)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", COLOR_EQUIPPED if is_equipped else COLOR_TEXT)

	var desc_label: Label = Label.new()
	desc_label.text = str(weapon.get(WeaponService.FIELD_DESC, ""))
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", COLOR_DESC)

	info_vbox.add_child(name_label)
	info_vbox.add_child(desc_label)

	# 属性列：攻击力 / 射速 / 每秒伤害
	var stat_label: Label = Label.new()
	stat_label.text = "攻击 %.1f\n射速 %.2f/秒\n每秒伤害 %.2f" % [
		float(weapon.get(WeaponService.FIELD_ATK, 0.0)),
		float(weapon.get(WeaponService.FIELD_ATK_SPEED, 0.0)),
		WeaponService.get_dps(weapon),
	]
	stat_label.add_theme_font_size_override("font_size", 14)
	stat_label.add_theme_color_override("font_color", COLOR_STAT)
	stat_label.custom_minimum_size = Vector2(STAT_LABEL_WIDTH, 0)
	stat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 装备按钮
	var btn_text: String = "已装备"
	var btn_color: Color = COLOR_EQUIPPED
	var can_equip: bool = false
	if not is_owned:
		btn_text = "商店购买"
		btn_color = COLOR_DISABLED
	elif not is_equipped:
		btn_text = "装备"
		btn_color = COLOR_TEXT
		can_equip = true

	var equip_btn: TextureButton = _create_text_button(btn_text, BUTTON_SIZE, btn_color)
	equip_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	equip_btn.disabled = not can_equip
	if can_equip:
		equip_btn.pressed.connect(_on_equip_pressed.bind(weapon_id))
		_add_hover(equip_btn)

	hbox.add_child(info_vbox)
	hbox.add_child(stat_label)
	hbox.add_child(equip_btn)
	margin.add_child(hbox)
	row_node.add_child(margin)
	# Panel 不是容器，子节点需手动铺满
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return row_node


## 武器名后缀标记：已装备 / 初始武器 / 未拥有
func _build_name_text(weapon: Dictionary, weapon_id: int, is_equipped: bool) -> String:
	var text: String = str(weapon.get(WeaponService.FIELD_NAME, "未知武器"))
	if is_equipped:
		text += "（已装备）"
	elif not WeaponService.is_owned(weapon_id):
		text += "（未拥有）"
	elif WeaponService.is_default(weapon_id):
		text += "（初始武器）"
	return text


func _on_equip_pressed(weapon_id: int) -> void:
	if not WeaponService.equip(weapon_id):
		return
	SaveSystem.save()
	_refresh_equipped_label()
	_build_weapon_list()


func _on_back_pressed() -> void:
	UIManager.close_ui("weapon")
