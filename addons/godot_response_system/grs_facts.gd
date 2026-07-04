@icon("res://addons/godot_response_system/icons/book.svg")
class_name GrsFacts
extends Node

# Intended for transient query facts, actor/world facts use the
# get/set fact functions that can be passed in

var _facts := { }


func set_fact(key: String, value: Variant):
	_facts[key.strip_edges().to_lower()] = value


func get_fact(key: String):
	return _facts.get(key.strip_edges().to_lower())


func list_facts() -> void:
	for key in _facts:
		print("    ", key, "\t", _facts[key])


func evaluate_query(query: GrsQuery):
	return true
