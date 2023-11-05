class_name BaseCsvImporter
extends EditorImportPlugin

enum Presets { CSV, TSV }
enum Delimiters { COMMA, TAB }

func _get_preset_count():
	return Presets.size()

func _get_preset_name(preset):
	match preset:
		Presets.CSV:
			return "CSV with headers"
		Presets.TSV:
			return "TSV with headers"
		_:
			return "Unknown"

func _get_import_options(_path, preset):
	var delimiter = Delimiters.COMMA
	match preset:
		Presets.TSV:
			delimiter = Delimiters.TAB

	return [
		{name="delimiter", default_value=delimiter, property_hint=PROPERTY_HINT_ENUM, hint_string="Comma,Tab"},
	]

func _get_option_visibility(path, option_name, options):
	return true

func _import_csv_file(source_file, save_path, options, platform_variants, gen_files) -> BaseCsvData:
	var delim: String
	match options.delimiter:
		Delimiters.COMMA:
			delim = ","
		Delimiters.TAB:
			delim = "\t"

	var file = FileAccess.open(source_file, FileAccess.READ)
	if not file:
		printerr("Failed to open file: ", source_file)
		return

	# get lines
	var lines := []
	while not file.eof_reached():
		var line = file.get_csv_line(delim)
		if line.size() > 0:
			lines.append(line)
	file.close()

	# create records
	var data := preload("base_csv_data.gd").new()

	var headers = lines[0]
	for i in range(1, lines.size()):
		var fields = lines[i]
		if fields.size() > headers.size():
			printerr("Line %d has more fields than headers" % i)
			return
		var dict = {}
		for j in headers.size():
			var name = headers[j]
			var value = fields[j] if j < fields.size() else null
			dict[name] = value
		data.records.append(dict)

	return data
