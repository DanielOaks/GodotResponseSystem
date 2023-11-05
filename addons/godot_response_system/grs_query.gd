class_name GrsQuery
extends Node

var facts: GrsFacts
var extra_fact_dictionaries: Array[GrsFacts]

func _init():
	facts = GrsFacts.new()
