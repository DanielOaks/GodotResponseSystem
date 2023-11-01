@tool
extends BaseCsvImporter

# base info

func _get_importer_name():
	return "pix.grs.responses.csv"

func _get_visible_name():
	return "GRS Responses CSV"

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
	
	if csv.records.size() > 0 and not csv.records[0].has_all(["name", "responsetype", "response"]):
		printerr("Missing required column. Try checking the delimiter and other import settings.")
		return FAILED

	var data = GrsData.new()

	var responseGroup = GrsResponseGroup.new()

	for line: Dictionary in csv.records:
		var cname: String = line.get("name", "").strip_edges()
		if cname != "" and responseGroup.responses.size() > 0:
			# save last response group
			if data.responses.has(responseGroup.cname.to_lower()):
				printerr("Response / group [", responseGroup.cname, "] was found multiple times in the same CSV file")
				return FAILED
			data.responses[responseGroup.cname.to_lower()] = responseGroup
			
			responseGroup = GrsResponseGroup.new()
		
		if cname != "":
			responseGroup.cname = cname
		
		var responseType: String = line.get("responsetype", "").strip_edges()
		var response: String = line.get("responsetype", "").strip_edges()
		
		if responseType != "":
			var c = GrsResponse.new()
			
			c.responseType = responseType
			c.response = response
			
			responseGroup.responses.append(c)

	if responseGroup.cname != "" and responseGroup.responses.size() > 0:
		# save last response group
		if data.responses.has(responseGroup.cname.to_lower()):
			printerr("Response / group [", responseGroup.cname, "] was found multiple times in the same CSV file")
			return FAILED
		data.responses[responseGroup.cname.to_lower()] = responseGroup
		
		responseGroup = GrsResponseGroup.new()

	var filename = save_path + "." + _get_save_extension()
	var err = ResourceSaver.save(data, filename)
	if err != OK:
		printerr("Failed to save resource: ", err)
	return err
