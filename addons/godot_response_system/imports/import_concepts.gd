@tool
extends BaseCsvImporter

# base info

func _get_importer_name():
	return "pix.grs.concepts.csv"

func _get_visible_name():
	return "GRS Concept CSV"

func _get_recognized_extensions():
	return ["csv", "grsc-csv"]

func _get_save_extension():
	return "res"

func _get_resource_type():
	return "Resource"

func _get_import_order():
	return 0

# importing

func _import(source_file, save_path, options, platform_variants, gen_files):
	var csv = _import_csv_file(source_file, save_path, options, platform_variants, gen_files)

	if csv.records.size() > 0 and not csv.records[0].has_all(["name"]):
		printerr("Missing column 'name'. Try checking the delimiter and other import settings.")
		return FAILED

	var data = GrsImportData.new()

	for line: Dictionary in csv.records:
		var c = GrsConcept.new()

		c.cname = line.get("name", "NameNotFound").strip_edges()

		var priorityString = line.get("priority", "0").strip_edges().to_lower()
		if priorityString == "":
			priorityString = "0"
		elif priorityString == "nopriority":
			priorityString = "-999"
		if not priorityString.is_valid_int():
			printerr("Priority string [", priorityString, "] on concept [", c.cname, "] is not a valid int")
			return FAILED
		c.priority = int(priorityString)

		if data.concepts.has(c.cname.to_lower()):
			printerr("Concept [", c.cname, "] was found multiple times in the same CSV file")
			return FAILED

		data.concepts[c.cname.to_lower()] = c

	var filename = save_path + "." + _get_save_extension()
	var err = ResourceSaver.save(data, filename)
	if err != OK:
		printerr("Failed to save resource: ", err)
	return err
