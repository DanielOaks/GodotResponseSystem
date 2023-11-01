@tool
extends EditorPlugin

var import_concepts_csv_plugin
var import_criteria_csv_plugin
var import_rules_csv_plugin
var import_responses_csv_plugin

const AUTOLOAD_NAME = "GodotResponseSystem"

func _enter_tree():
	# add importers
	import_concepts_csv_plugin = preload("imports/import_concepts.gd").new()
	add_import_plugin(import_concepts_csv_plugin)

	import_criteria_csv_plugin = preload("imports/import_criteria.gd").new()
	add_import_plugin(import_criteria_csv_plugin)

	import_rules_csv_plugin = preload("imports/import_rules.gd").new()
	add_import_plugin(import_rules_csv_plugin)

	import_responses_csv_plugin = preload("imports/import_responses.gd").new()
	add_import_plugin(import_responses_csv_plugin)

	# add GRS
	add_autoload_singleton(AUTOLOAD_NAME, "grs.gd")

func _exit_tree():
	# clean up importers
	remove_import_plugin(import_concepts_csv_plugin)
	import_concepts_csv_plugin = null

	remove_import_plugin(import_criteria_csv_plugin)
	import_criteria_csv_plugin = null

	remove_import_plugin(import_rules_csv_plugin)
	import_rules_csv_plugin = null

	remove_import_plugin(import_responses_csv_plugin)
	import_responses_csv_plugin = null

	# clean up GRS
	remove_autoload_singleton(AUTOLOAD_NAME)
