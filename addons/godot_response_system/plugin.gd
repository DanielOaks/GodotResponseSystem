@tool
extends EditorPlugin

var import_concepts_csv_plugin

func _enter_tree():
	# add importers
	import_concepts_csv_plugin = preload("imports/import_concepts.gd").new()
	add_import_plugin(import_concepts_csv_plugin)

func _exit_tree():
	# clean up importers
	remove_import_plugin(import_concepts_csv_plugin)
	import_concepts_csv_plugin = null
