@tool
class_name CsvExporter
extends RefCounted
## CSV 导出核心逻辑：扫描 data/ 目录下的 .csv 文件，逐行解析，生成 .tres（TableResource）。
## CSV 结构：第 1 行字段名、第 2 行类型、第 3 行中文注释、第 4 行默认值、第 5 行起数据。
## 其中「中文注释」「默认值」两行是给策划看的元信息，导出时跳过；
## 字段值按第 2 行声明的类型（int / float / bool / string）转换。


const TableResource = preload("res://Scripts/core/table_resource.gd")

## CSV 源目录（与 Excel 另存的 .csv 文件放在这里）
const DATA_DIR := "res://data"
## 表资源输出目录
const OUT_DIR := "res://Resources/Tables"


## 导出 DATA_DIR 下的全部 CSV
static func export_all() -> void:
	var files := _list_csv(DATA_DIR)
	if files.is_empty():
		push_warning("[导表] 未在 %s 找到 CSV 文件" % DATA_DIR)
		return
	var ok_count := 0
	for path in files:
		if export_file(path):
			ok_count += 1
	print("[导表] 完成：成功 %d / 共 %d 张表 → %s" % [ok_count, files.size(), OUT_DIR])


## 导出单个 CSV 文件
static func export_file(csv_path: String) -> bool:
	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		push_error("[导表] 无法读取 CSV: %s" % csv_path)
		return false
	var text := file.get_as_text()
	file.close()

	# 去掉 UTF-8 BOM（Excel 另存的 CSV 常带 BOM，会污染首个表头）
	if text.begins_with("\uFEFF"):
		text = text.substr(1)

	var grid := _parse_csv(text)
	# CSV 约定：第 0 行=字段名，第 1 行=类型，第 2 行=中文注释，第 3 行=默认值，第 4 行起=数据
	# 第 2、3 行是给策划看的元信息，导出时跳过
	if grid.size() < 5:
		push_warning("[导表] 内容不足（需字段名/类型/注释/默认值 + 至少一行数据）: %s" % csv_path)
		return false

	var headers: Array = grid[0]
	var types: Array = grid[1]
	for i in headers.size():
		headers[i] = str(headers[i]).strip_edges()
	for i in types.size():
		types[i] = str(types[i]).strip_edges().to_lower()

	var table: TableResource = TableResource.new()
	table.table_name = csv_path.get_file().get_basename()

	for r in range(4, grid.size()):
		var cells: Array = grid[r]
		if _is_blank_row(cells):
			continue
		var row := {}
		for c in headers.size():
			var key: String = headers[c]
			var raw := str(cells[c]) if c < cells.size() else ""
			var type_name := str(types[c]) if c < types.size() else "string"
			row[key] = _cast_by_type(raw, type_name)
		table.rows.append(row)

	_ensure_dir(OUT_DIR)
	var out_path := OUT_DIR.path_join(table.table_name + ".tres")
	var err := ResourceSaver.save(table, out_path)
	if err != OK:
		push_error("[导表] 保存失败 %s (err=%d)" % [out_path, err])
		return false
	print("[导表] 生成 %s（%d 行）" % [out_path, table.rows.size()])
	return true


## 解析 CSV 文本为二维数组（保留空行，处理引号/逗号/换行）
static func _parse_csv(text: String) -> Array:
	text = text.replace("\r\n", "\n").replace("\r", "\n")
	var result: Array = []
	var row: Array = []
	var field := ""
	var in_quotes := false
	var i := 0
	while i < text.length():
		var c := text[i]
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


## 是否空行（所有单元格去空白后为空）
static func _is_blank_row(row: Array) -> bool:
	for cell in row:
		if str(cell).strip_edges() != "":
			return false
	return true


## 按表中声明的类型转换单元格值（int / float / bool，其余按字符串）
static func _cast_by_type(raw: String, type_name: String) -> Variant:
	var s := raw.strip_edges()
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
			var lower := s.to_lower()
			return lower == "true" or lower == "1"
		_:
			return s


## 列出目录下（不递归）的所有 .csv 文件全路径
static func _list_csv(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not d.current_is_dir() and f.get_extension().to_lower() == "csv":
			out.append(dir.path_join(f))
		f = d.get_next()
	d.list_dir_end()
	return out


## 确保目录存在（创建多级目录）
static func _ensure_dir(dir: String) -> void:
	var d := DirAccess.open("res://")
	if d == null:
		push_error("[导表] 无法打开 res://")
		return
	d.make_dir_recursive(dir.replace("res://", ""))