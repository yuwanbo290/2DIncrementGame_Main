@tool
class_name TableExporterCore
extends RefCounted
## 导表核心逻辑：扫描 data/ 目录下的源表（.xlsx / .csv），逐行解析，生成 .tres（TableResource）。
##
## 源表结构（五段式，缺一不可）：
##   第 1 行 字段名 / 第 2 行 类型 / 第 3 行 中文备注 / 第 4 行 默认值 / 第 5 行起 数据
## 其中「中文备注」「默认值」两行是给策划看的元信息，导出时跳过；
## 字段值按第 2 行声明的类型（int / float / bool / string）转换。
##
## 推荐用 .xlsx：其内部是 UTF-8 的 XML，天然没有 CSV 的中文编码问题，
## 且 Godot 不会把 .xlsx 误当翻译表导入（不会产生 .translation 冗余）。
## 同名时 .xlsx 优先于 .csv。


const TableResource = preload("res://Scripts/core/table_resource.gd")

## 源表目录（策划维护的 .xlsx / .csv 放这里）
const DATA_DIR := "res://data"
## 表资源输出目录
const OUT_DIR := "res://Resources/Tables"

## 五段式行号约定（0 基）
const ROW_HEADER := 0
const ROW_TYPE := 1
const ROW_DATA_START := 4
## 五段式最少行数（字段名/类型/备注/默认值 + 至少一行数据）
const MIN_ROWS := 5

## xlsx 内部固定路径
const XLSX_WORKBOOK := "xl/workbook.xml"
const XLSX_WORKBOOK_RELS := "xl/_rels/workbook.xml.rels"
const XLSX_SHARED_STRINGS := "xl/sharedStrings.xml"
const XLSX_SHEET_DIR := "xl/worksheets/"


## 导出 DATA_DIR 下的全部源表（.xlsx / .csv）
static func export_all() -> void:
	var sources: Dictionary = _collect_sources(DATA_DIR)
	if sources.is_empty():
		push_warning("[导表] 未在 %s 找到源表（.xlsx / .csv）" % DATA_DIR)
		return
	var names: Array = sources.keys()
	names.sort()
	var ok_count: int = 0
	for table_name in names:
		if export_file(sources[table_name]):
			ok_count += 1
	print("[导表] 完成：成功 %d / 共 %d 张表 → %s" % [ok_count, names.size(), OUT_DIR])


## 导出单个源表文件（按扩展名分派 xlsx / csv）
static func export_file(source_path: String) -> bool:
	var ext: String = source_path.get_extension().to_lower()
	var grid: Array = []
	match ext:
		"xlsx":
			grid = _read_xlsx(source_path)
		"csv":
			grid = _read_csv(source_path)
		_:
			push_error("[导表] 不支持的源表格式（请用 .xlsx 或 .csv）: %s" % source_path)
			return false
	if grid.is_empty():
		return false

	if grid.size() < MIN_ROWS:
		push_warning("[导表] 内容不足（需字段名/类型/备注/默认值 + 至少一行数据）: %s" % source_path)
		return false

	var headers: Array = grid[ROW_HEADER]
	var types: Array = grid[ROW_TYPE]
	for i in headers.size():
		headers[i] = str(headers[i]).strip_edges()
	for i in types.size():
		types[i] = str(types[i]).strip_edges().to_lower()

	var table: TableResource = TableResource.new()
	table.table_name = source_path.get_file().get_basename()

	for r in range(ROW_DATA_START, grid.size()):
		var cells: Array = grid[r]
		if _is_blank_row(cells):
			continue
		var row: Dictionary = {}
		for c in headers.size():
			var key: String = headers[c]
			if key == "":
				continue
			var raw: String = str(cells[c]) if c < cells.size() else ""
			var type_name: String = str(types[c]) if c < types.size() else "string"
			row[key] = _cast_by_type(raw, type_name)
		table.rows.append(row)

	_ensure_dir(OUT_DIR)
	var out_path: String = OUT_DIR.path_join(table.table_name + ".tres")
	var err: int = ResourceSaver.save(table, out_path)
	if err != OK:
		push_error("[导表] 保存失败 %s (err=%d)" % [out_path, err])
		return false
	print("[导表] 生成 %s（%d 行，源 %s）" % [out_path, table.rows.size(), source_path.get_file()])
	return true


# ---- 源表收集 ----

## 收集 data/ 下的源表：表名 -> 文件路径（同名时 .xlsx 优先于 .csv）
static func _collect_sources(dir: String) -> Dictionary:
	var out: Dictionary = {}
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		push_error("[导表] 无法打开目录: %s" % dir)
		return out
	d.list_dir_begin()
	var f: String = d.get_next()
	while f != "":
		if not d.current_is_dir():
			var base: String = f.get_basename()
			var ext: String = f.get_extension().to_lower()
			# 跳过 Excel / WPS 打开文件时生成的临时锁文件（~$xxx.xlsx）
			if base.begins_with("~$"):
				pass
			elif ext == "xlsx":
				out[base] = dir.path_join(f)  # xlsx 优先，直接覆盖同名 csv
			elif ext == "csv":
				if not out.has(base):
					out[base] = dir.path_join(f)
			elif ext == "xls":
				push_warning("[导表] 不支持旧版 .xls，请在 Excel/WPS 中另存为 .xlsx: %s" % f)
		f = d.get_next()
	d.list_dir_end()
	return out


# ---- xlsx 读取（ZIPReader + XMLParser，无需第三方库）----

## 读取 xlsx 首个工作表为二维数组
static func _read_xlsx(path: String) -> Array:
	var zip: ZIPReader = ZIPReader.new()
	var err: int = zip.open(path)
	if err != OK:
		push_error("[导表] 无法打开 xlsx（文件是否正被 Excel/WPS 占用？）: %s (err=%d)" % [path, err])
		return []

	var sheet_path: String = _find_first_sheet(zip)
	if sheet_path == "":
		push_error("[导表] xlsx 内未找到工作表: %s" % path)
		zip.close()
		return []

	var shared: PackedStringArray = _read_shared_strings(zip)
	var grid: Array = _parse_sheet(zip.read_file(sheet_path), shared)
	zip.close()
	return grid


## 定位首个工作表在包内的路径（走 workbook.xml + rels，失败则回退扫描）
static func _find_first_sheet(zip: ZIPReader) -> String:
	var rel_id: String = ""
	if zip.file_exists(XLSX_WORKBOOK):
		var parser: XMLParser = XMLParser.new()
		if parser.open_buffer(zip.read_file(XLSX_WORKBOOK)) == OK:
			while parser.read() == OK:
				# OOXML 允许标签带命名空间前缀（例如 x:sheet）；统一取本地名称后再比较。
				if parser.get_node_type() == XMLParser.NODE_ELEMENT and _xml_local_name(parser.get_node_name()) == "sheet":
					rel_id = parser.get_named_attribute_value_safe("r:id")
					break

	if rel_id != "" and zip.file_exists(XLSX_WORKBOOK_RELS):
		var parser: XMLParser = XMLParser.new()
		if parser.open_buffer(zip.read_file(XLSX_WORKBOOK_RELS)) == OK:
			while parser.read() == OK:
				if parser.get_node_type() == XMLParser.NODE_ELEMENT and _xml_local_name(parser.get_node_name()) == "Relationship":
					if parser.get_named_attribute_value_safe("Id") == rel_id:
						var target: String = parser.get_named_attribute_value_safe("Target")
						if target != "":
							if target.begins_with("/"):
								return target.substr(1)
							return "xl/".path_join(target)

	# 回退：包内第一个 xl/worksheets/*.xml
	var candidates: Array = []
	for name in zip.get_files():
		if name.begins_with(XLSX_SHEET_DIR) and name.get_extension().to_lower() == "xml":
			candidates.append(name)
	if candidates.is_empty():
		return ""
	candidates.sort()
	return candidates[0]


## 读取共享字符串表（xlsx 把文本集中存在这里，单元格只存索引）
static func _read_shared_strings(zip: ZIPReader) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not zip.file_exists(XLSX_SHARED_STRINGS):
		return out
	var parser: XMLParser = XMLParser.new()
	if parser.open_buffer(zip.read_file(XLSX_SHARED_STRINGS)) != OK:
		push_error("[导表] sharedStrings.xml 解析失败")
		return out

	var buf: String = ""
	var in_si: bool = false
	var in_text: bool = false
	var in_phonetic: bool = false  # <rPh> 是拼音注音，不算正文
	while parser.read() == OK:
		var node_type: int = parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var tag: String = _xml_local_name(parser.get_node_name())
			if tag == "si":
				in_si = true
				buf = ""
				if parser.is_empty():
					out.append("")
					in_si = false
			elif tag == "rPh":
				in_phonetic = true
			elif tag == "t" and in_si and not in_phonetic:
				in_text = not parser.is_empty()
		elif node_type == XMLParser.NODE_TEXT:
			if in_text:
				buf += parser.get_node_data()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var tag_end: String = _xml_local_name(parser.get_node_name())
			if tag_end == "t":
				in_text = false
			elif tag_end == "rPh":
				in_phonetic = false
			elif tag_end == "si":
				out.append(buf)
				buf = ""
				in_si = false
	return out


## 解析工作表 XML 为二维数组（按 r="B3" 单元格坐标补齐被省略的空行/空列）
static func _parse_sheet(bytes: PackedByteArray, shared: PackedStringArray) -> Array:
	var grid: Array = []
	var parser: XMLParser = XMLParser.new()
	if parser.open_buffer(bytes) != OK:
		push_error("[导表] 工作表 XML 解析失败")
		return grid

	var cur_row: Array = []
	var row_number: int = 0   # 1 基行号
	var col_index: int = 0    # 0 基列号
	var cell_type: String = ""
	var value_buf: String = ""
	var in_value: bool = false
	var in_cell: bool = false

	while parser.read() == OK:
		var node_type: int = parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var tag: String = _xml_local_name(parser.get_node_name())
			var is_self_closing: bool = parser.is_empty()
			if tag == "row":
				var r: String = parser.get_named_attribute_value_safe("r")
				row_number = r.to_int() if r.is_valid_int() else grid.size() + 1
				cur_row = []
				if is_self_closing:
					_put_row(grid, row_number, cur_row)
			elif tag == "c":
				in_cell = true
				cell_type = parser.get_named_attribute_value_safe("t")
				value_buf = ""
				var ref: String = parser.get_named_attribute_value_safe("r")
				col_index = _col_from_ref(ref) if ref != "" else cur_row.size()
				if is_self_closing:
					_put_cell(cur_row, col_index, "")
					in_cell = false
			elif (tag == "v" or tag == "t") and in_cell:
				in_value = not is_self_closing
		elif node_type == XMLParser.NODE_TEXT:
			if in_value:
				value_buf += parser.get_node_data()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var tag_end: String = _xml_local_name(parser.get_node_name())
			if tag_end == "v" or tag_end == "t":
				in_value = false
			elif tag_end == "c":
				_put_cell(cur_row, col_index, _resolve_cell(value_buf, cell_type, shared))
				value_buf = ""
				in_cell = false
			elif tag_end == "row":
				_put_row(grid, row_number, cur_row)
				cur_row = []
	return grid


## 返回 XML 标签的本地名称："x:row" -> "row"，"row" 保持不变。
## 不依赖固定前缀名称，因此兼容 Excel、WPS 与其他符合 OOXML 标准的生成器。
static func _xml_local_name(qualified_name: String) -> String:
	var separator_index: int = qualified_name.rfind(":")
	if separator_index < 0:
		return qualified_name
	return qualified_name.substr(separator_index + 1)


## 把单元格原始值按类型标记还原为字符串（s=共享字符串索引，b=布尔）
static func _resolve_cell(raw: String, cell_type: String, shared: PackedStringArray) -> String:
	match cell_type:
		"s":
			if raw.is_valid_int():
				var idx: int = raw.to_int()
				if idx >= 0 and idx < shared.size():
					return shared[idx]
			return ""
		"b":
			return "true" if raw == "1" else "false"
		_:
			return raw


## "D5" -> 3（0 基列号）
static func _col_from_ref(ref: String) -> int:
	var col: int = 0
	for i in ref.length():
		var code: int = ref.unicode_at(i)
		if code >= 65 and code <= 90:        # A-Z
			col = col * 26 + (code - 64)
		elif code >= 97 and code <= 122:     # a-z
			col = col * 26 + (code - 96)
		else:
			break
	if col > 0:
		return col - 1
	return 0


## 写入单元格，不足处用空串补齐
static func _put_cell(row: Array, col: int, value: String) -> void:
	while row.size() <= col:
		row.append("")
	row[col] = value


## 写入整行（1 基行号），被省略的中间行用空行补齐
static func _put_row(grid: Array, row_number: int, row: Array) -> void:
	if row_number <= 0:
		grid.append(row)
		return
	while grid.size() < row_number:
		grid.append([])
	grid[row_number - 1] = row


# ---- csv 读取 ----

## 读取 CSV 为二维数组（强制 UTF-8；非 UTF-8 直接报错，避免静默产出乱码）
static func _read_csv(path: String) -> Array:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[导表] 无法读取 CSV: %s" % path)
		return []
	var text: String = file.get_as_text()
	file.close()

	# 去掉 UTF-8 BOM（Excel 另存的 CSV 常带 BOM，会污染首个表头）
	if text.begins_with("\uFEFF"):
		text = text.substr(1)

	# 非 UTF-8（如 Excel 在中文系统默认另存的 GBK）会解出替换字符 U+FFFD，
	# 此时中文已不可逆损坏，必须中止而不是导出乱码表。
	if text.contains("\uFFFD"):
		push_error("[导表] CSV 不是 UTF-8 编码，中文会变乱码，已跳过：%s\n  → 请在 Excel/WPS 中另存为 .xlsx（推荐），或另存为「CSV UTF-8」" % path)
		return []

	return _parse_csv(text)


## 解析 CSV 文本为二维数组（保留空行，处理引号/逗号/换行）
static func _parse_csv(text: String) -> Array:
	text = text.replace("\r\n", "\n").replace("\r", "\n")
	var result: Array = []
	var row: Array = []
	var field: String = ""
	var in_quotes: bool = false
	var i: int = 0
	while i < text.length():
		var c: String = text[i]
		if in_quotes:
			if c == '"':
				if i + 1 < text.length() and text[i + 1] == '"':
					field += '"'
					i += 1
				else:
					in_quotes = false
			else:
				field += c
		else:
			if c == '"':
				in_quotes = true
			elif c == ',':
				row.append(field)
				field = ""
			elif c == '\n':
				row.append(field)
				field = ""
				result.append(row)
				row = []
			else:
				field += c
		i += 1

	if field != "" or not row.is_empty():
		row.append(field)
		result.append(row)
	return result


# ---- 公共工具 ----

## 是否空行（所有单元格去空白后为空）
static func _is_blank_row(row: Array) -> bool:
	for cell in row:
		if str(cell).strip_edges() != "":
			return false
	return true


## 按表中声明的类型转换单元格值（int / float / bool，其余按字符串）
static func _cast_by_type(raw: String, type_name: String) -> Variant:
	var s: String = raw.strip_edges()
	match type_name:
		"int":
			if s == "":
				return 0
			if s.is_valid_int():
				return s.to_int()
			if s.is_valid_float():
				return int(s.to_float())
			return 0
		"float":
			if s == "":
				return 0.0
			if s.is_valid_float():
				return s.to_float()
			return 0.0
		"bool":
			var lower: String = s.to_lower()
			return lower == "true" or lower == "1"
		_:
			return s


## 确保目录存在（创建多级目录）
static func _ensure_dir(dir: String) -> void:
	var d: DirAccess = DirAccess.open("res://")
	if d == null:
		push_error("[导表] 无法打开 res://")
		return
	d.make_dir_recursive(dir.replace("res://", ""))
