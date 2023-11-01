@tool
extends BaseCsvImporter

# base info

func _get_importer_name():
	return "pix.grs.rules.csv"

func _get_visible_name():
	return "GRS Rules CSV"

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
	
	if csv.records.size() > 0 and not csv.records[0].has_all(["name", "criteria", "responses"]):
		printerr("Missing required column. Try checking the delimiter and other import settings.")
		return FAILED

	var data = GrsData.new()

	for line: Dictionary in csv.records:
		var c = GrsRule.new()
		
		c.cname = line.get("name", "NameNotFound").strip_edges()
		
		for criterion in line.get("criteria", "").split(" "):
			if criterion != "" and not c.criteria.has(criterion):
				c.criteria.append(criterion)
		
		for response in line.get("responses", "").split(" "):
			if response != "" and not c.responses.has(response):
				c.responses.append(response)

		if data.rules.has(c.cname.to_lower()):
			printerr("Rule [", c.cname, "] was found multiple times in the same CSV file")
			return FAILED

		data.rules[c.cname.to_lower()] = c

	var filename = save_path + "." + _get_save_extension()
	var err = ResourceSaver.save(data, filename)
	if err != OK:
		printerr("Failed to save resource: ", err)
	return err
