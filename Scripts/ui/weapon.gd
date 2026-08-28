extends UIBase
## 武器界面：以 weapons 表为数据源，展示全部武器并装备已拥有的武器。
##
## 「是否拥有」= 表内 isDefault=1 的默认武器 ∪ 存档已购武器，判定统一走 WeaponService。
## 未拥有的武器置灰并提示到商店购买；装备结果写入存档并立即落盘。


const ROW_HEIGHT := 112.0
const BUTTON_SIZE := Vector2(120, 44)
const STAT_LABEL_WIDTH := 290.0
const STATUS_LABEL_WIDTH := 140.0

const COLOR_TEXT := Color(0.94902, 0.917647, 0.843137, 1)
const COLOR_DESC := Color(0.666667, 0.713725, 0.67451, 1)
const COLOR_STAT := Color(0.658824, 0.827451, 0.356863, 1)
const COLOR_EQUIPPED := Color(0.901961, 0.721569, 0.290196, 1)
const COLOR_DISABLED := Color(0.666667, 0.713725, 0.67451, 0.65)

@onready var _stats_label: Label = %StatsLabel
@onready var _back_btn: Button = %BackBtn
@onready var _equipped_label: Label = %EquippedLabel
@onready var _weapon_list: VBoxContainer = %WeaponList

## 当前列表行用于排版完成后执行错峰入场。
var _weapon_rows: Array[Control] = []
## 仅记录可装备按钮，键盘导航会跳过锁定与已装备项。
var _action_buttons: Array[Button] = []


func _ready() -> void:
	_back_btn.pressed.connect(_on_back_pressed)
	super()


func refresh() -> void:
	_stats_label.text = PlayerStatsService.format_stats(PlayerStatsService.get_meta_stats())
	_refresh_equipped_label()
	_build_weapon_list()


func _refresh_equipped_label() -> void:
	var row: Dictionary = WeaponService.get_equipped_stats()
	if row.is_empty():
		_equipped_label.text = "当前武器: 无"
		return
	_equipped_label.text = "当前武器: %s" % str(row.get(WeaponService.FIELD_NAME, "-"))


func _get_list() -> VBoxContainer:
	return _weapon_list


func _clear_weapon_list() -> void:
	_clear_container(_get_list())


func _build_weapon_list() -> void:
	_clear_weapon_list()
	_weapon_rows.clear()
	_action_buttons.clear()

	var list: VBoxContainer = _get_list()
	if list == null:
		push_error("[武器] 找不到武器列表容器 WeaponList")
		return

	var rows: Array[Dictionary] = WeaponService.get_all()
	if rows.is_empty():
		list.add_child(_create_empty_hint("暂无武器数据"))
		_configure_action_focus()
		return

	var equipped_id: int = WeaponService.get_equipped_id()
	for weapon in rows:
		var weapon_row: Panel = _create_weapon_row(weapon, equipped_id)
		list.add_child(weapon_row)
		_weapon_rows.append(weapon_row)
	_configure_action_focus()
	call_deferred("_reveal_weapon_rows")


## 构建一行武器（名称说明 + 属性 + 状态 + 装备按钮）。
func _create_weapon_row(weapon: Dictionary, equipped_id: int) -> Panel:
	var weapon_id: int = int(weapon.get(WeaponService.FIELD_ID, 0))
	var is_owned: bool = WeaponService.is_owned(weapon_id)
	var is_equipped: bool = weapon_id == equipped_id

	# 已装备的武器用旧金边框区分。
	var row_node: Panel = _create_list_row(ROW_HEIGHT) if not is_equipped else _create_list_row(
		ROW_HEIGHT, Color(0.12549, 0.160784, 0.137255, 0.98), COLOR_EQUIPPED
	)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 9)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 信息列：武器名与描述，状态单独成列。
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 4)

	var name_label: Label = Label.new()
	name_label.text = str(weapon.get(WeaponService.FIELD_NAME, "未知武器"))
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", COLOR_EQUIPPED if is_equipped else COLOR_TEXT)

	var desc_label: Label = Label.new()
	desc_label.text = str(weapon.get(WeaponService.FIELD_DESC, ""))
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", COLOR_DESC)
	desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	info_vbox.add_child(name_label)
	info_vbox.add_child(desc_label)

	# 属性列：攻击力 / 射速 / 每秒伤害
	var stat_label: Label = Label.new()
	stat_label.text = "攻击 %.1f  ·  射速 %.2f/秒\n每秒伤害 %.2f" % [
		float(weapon.get(WeaponService.FIELD_ATK, 0.0)),
		float(weapon.get(WeaponService.FIELD_ATK_SPEED, 0.0)),
		WeaponService.get_dps(weapon),
	]
	stat_label.add_theme_font_size_override("font_size", 15)
	stat_label.add_theme_color_override("font_color", COLOR_STAT)
	stat_label.custom_minimum_size = Vector2(STAT_LABEL_WIDTH, 0)
	stat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 状态列保留已装备、初始武器与未拥有信息。
	var status_text: String = "已拥有"
	var status_color: Color = COLOR_STAT
	if is_equipped:
		status_text = "已装备"
		status_color = COLOR_EQUIPPED
	elif not is_owned:
		status_text = "未拥有"
		status_color = COLOR_DISABLED
	elif WeaponService.is_default(weapon_id):
		status_text = "初始武器"

	var status_label: Label = Label.new()
	status_label.text = status_text
	status_label.custom_minimum_size = Vector2(STATUS_LABEL_WIDTH, 0)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", status_color)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 操作列只承担装备动作，状态在点击时仍由 WeaponService 二次校验。
	var btn_text: String = "已装备"
	var btn_color: Color = COLOR_DISABLED
	var can_equip: bool = false
	if not is_owned:
		btn_text = "不可用"
		btn_color = COLOR_DISABLED
	elif not is_equipped:
		btn_text = "装备"
		btn_color = COLOR_TEXT
		can_equip = true

	var equip_btn: Button = _create_text_button(btn_text, BUTTON_SIZE, btn_color)
	equip_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	equip_btn.disabled = not can_equip
	if can_equip:
		equip_btn.theme_type_variation = &"PrimaryButton"
		equip_btn.pressed.connect(_on_equip_pressed.bind(weapon_id))
		_action_buttons.append(equip_btn)

	hbox.add_child(info_vbox)
	hbox.add_child(stat_label)
	hbox.add_child(status_label)
	hbox.add_child(equip_btn)
	margin.add_child(hbox)
	row_node.add_child(margin)
	# Panel 不是容器，子节点需手动铺满
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return row_node


## 列表完成布局后错峰展示前八项；更多项目沿用第八项延迟。
func _reveal_weapon_rows() -> void:
	for index in _weapon_rows.size():
		var row: Control = _weapon_rows[index]
		if is_instance_valid(row) and not row.is_queued_for_deletion():
			UIBase.reveal_card(row, index)


## 仅在可装备按钮之间建立上下循环，返回键始终可达。
func _configure_action_focus() -> void:
	_back_btn.focus_neighbor_top = NodePath()
	_back_btn.focus_neighbor_bottom = NodePath()
	if _action_buttons.is_empty():
		return

	_back_btn.focus_neighbor_top = _back_btn.get_path_to(_action_buttons.back())
	_back_btn.focus_neighbor_bottom = _back_btn.get_path_to(_action_buttons[0])
	for index in _action_buttons.size():
		var button: Button = _action_buttons[index]
		var previous: Control = _back_btn if index == 0 else _action_buttons[index - 1]
		var next: Control = _back_btn if index == _action_buttons.size() - 1 else _action_buttons[index + 1]
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(next)


## 装备后原按钮变为状态项，焦点移到下一个有效操作或返回键。
func _focus_after_equip() -> void:
	if not _action_buttons.is_empty():
		_action_buttons[0].grab_focus()
	else:
		_back_btn.grab_focus()


func _on_equip_pressed(weapon_id: int) -> void:
	if not WeaponService.equip(weapon_id):
		return
	SaveSystem.save()
	refresh()
	call_deferred("_focus_after_equip")


func _on_back_pressed() -> void:
	UIManager.close_ui("weapon")
