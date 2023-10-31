@tool
extends BaseCsvImporter

# base info

func _get_importer_name():
	return "pix.grs.criteria.csv"

func _get_visible_name():
	return "GRS Criteria CSV"

func _get_recognized_extensions():
	return ["csv"]

func _get_save_extension():
	return "res"

func _get_resource_type():
	return "Resource"

func _get_import_order():
	return 0

# importing

func _import(source_file, save_path, options, platform_variants, gen_files):
	var csv = _import_csv_file(source_file, save_path, options, platform_variants, gen_files)
	
	if csv.records.size() > 0 and not csv.records[0].has_all(["name", "fact", "match"]):
		printerr("Missing required column. Try checking the delimiter and other import settings.")
		return FAILED

	var data = preload("../grs_criterion_dict.gd").new()

	for line: Dictionary in csv.records:
		var c = GrsCritereon.new()
		
		c.cname = line.get("name", "NameNotFound").strip_edges()
		c.fact = line.get("fact", "FactNotFound").strip_edges()
		
		c.matchValue = line.get("match", "Match string not found").strip_edges()
		# TODO: compile match value into value that's easier/quicker to test at runtime
		
		var weightString = line.get("weight", "1").strip_edges().to_lower()
		if weightString == "":
			weightString = "1"
		elif weightString == "nopriority":
			weightString = "-999"
		if not weightString.is_valid_float():
			printerr("Weight string [", weightString, "] on criterion [", c.cname, "] is not a valid float")
			return FAILED
		c.weight = float(weightString)

		if data.criteria.has(c.cname.to_lower()):
			printerr("Concept [", c.cname, "] was found multiple times in the same CSV file")
			return FAILED

		data.criteria[c.cname.to_lower()] = c

	var filename = save_path + "." + _get_save_extension()
	var err = ResourceSaver.save(data, filename)
	if err != OK:
		printerr("Failed to save resource: ", err)
	return err
