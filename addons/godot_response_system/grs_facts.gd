class_name GrsFacts
extends Node

var _facts := {}

func set_fact(key: String, value: Variant):
	_facts[key.strip_edges().to_lower()] = value

func get_fact(key: String):
	return _facts.get(key.strip_edges().to_lower())

func evaluate_query(query: GrsQuery):
	return true
