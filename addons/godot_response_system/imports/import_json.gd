class_name ImportGrsJson
extends EditorImportPlugin

func _get_importer_name():
	return "pix.grs.json"

func _get_visible_name():
	return "GRS JSON"

func _get_recognized_extensions():
	return ["json", "grs-json"]

func _get_priority():
	return 2.0

func _get_import_order():
	return 0

func _get_save_extension():
	return "res"

func _get_resource_type():
	return "Resource"

func _get_preset_count():
	return 1

func _get_preset_name(preset_index):
	return "Default"

func _get_import_options(path, preset_index):
	return [{"name": "my_option", "default_value": false}]

func _get_option_visibility(path, option_name, options):
	return true

func _import(source_file, save_path, options, platform_variants, gen_files):
	var file = FileAccess.open(source_file, FileAccess.READ)
	if not file:
		printerr("Failed to open file: ", source_file)
		return

	# get lines
	var json_string = file.get_as_text()
	file.close()

	var json_entries: Array[Variant]
	var json = JSON.new()
	var error = json.parse(json_string)
	if error == OK:
		var data_received = json.data
		if typeof(data_received) == TYPE_ARRAY:
			json_entries = data_received
		else:
			print("Unexpected data")
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())

	if json_entries.size() == 0:
		print("Aborting import of ", source_file)
		return

	var data = GrsImportData.new()

	for entry in json_entries:
		match entry.type:
			"concept":
				var c = GrsConcept.new()
				c.cname = entry.get("name", "NameNotFound").strip_edges()

				var priority = entry.get("priority", "")
				if priority is float:
					pass
				elif priority == "":
					priority = 0
				elif priority == "nopriority":
					priority = -999
				else:
					printerr("Priority [", priority, "] on concept [", c.cname, "] is not a valid int")
					return FAILED
				c.priority = int(priority)

				if data.concepts.has(c.cname.to_lower()):
					printerr("Concept [", c.cname, "] defined multiple times in the same JSON file")
					return FAILED

				data.concepts[c.cname.to_lower()] = c
			"criteria":
				var c = GrsCriterion.new()
				c.cname = entry.get("name", "NameNotFound").strip_edges()
				c.fact = entry.get("fact", "FactNotFound").strip_edges()
				c.matchValue = entry.get("match", "Match string not found").strip_edges()
				# TODO: compile match value into value that's easier/quicker to test at runtime

				var weight = entry.get("weight", 1.0)
				if weight is float:
					pass
				elif weight == "":
					weight = 1
				elif weight == "nopriority":
					weight = -999
				else:
					printerr("Weight [", weight, "] on criterion [", c.cname, "] is not a valid float")
					return FAILED
				c.weight = weight

				if data.criteria.has(c.cname.to_lower()):
					printerr("Criterion [", c.cname, "] defined multiple times in the same JSON file")
					return FAILED
				data.criteria[c.cname.to_lower()] = c
			"rule":
				var c = GrsRule.new()
				c.cname = entry.get("name", "NameNotFound").strip_edges()

				for criterion in entry.get("criteria", "").split(" "):
					criterion = criterion.to_lower()
					if criterion != "" and not c.criteria.has(criterion):
						c.criteria.append(criterion)

				for response in entry.get("responses", "").split(" "):
					response = response.to_lower()
					if response != "" and not c.responses.has(response):
						c.responses.append(response)

				if data.rules.has(c.cname.to_lower()):
					printerr("Rule [", c.cname, "] defined multiple times in the same JSON file")
					return FAILED
				data.rules[c.cname.to_lower()] = c
			"responsegroup":
				var responseGroup = GrsResponseGroup.new()
				responseGroup.cname = entry.get("name", "NameNotFound").strip_edges()

				for rentry in entry.responses:
					var c = GrsResponse.new()

					c.responseType = rentry.get("responsetype", "").strip_edges()
					c.response = rentry.get("response", "").strip_edges()
					c.delay = rentry.get("busyfor", 3)
					
					var then: PackedStringArray = rentry.get("then", "").split(" ", false)
					if then.size():
						c.thenActor = then[0]
						c.thenConcept = then[1]
						if then.size() > 2:
							c.thenDelay = then[2].to_float()

					responseGroup.responses.append(c)

				if data.responses.has(responseGroup.cname.to_lower()):
					printerr("Response / group [", responseGroup.cname, "] defined multiple times in the same JSON file")
					return FAILED
				data.responses[responseGroup.cname.to_lower()] = responseGroup
			_:
				#print("unknown entry type...")
				pass

	var filename = save_path + "." + _get_save_extension()
	var err = ResourceSaver.save(data, filename)
	if err != OK:
		printerr("Failed to save resource: ", err)
	return err
