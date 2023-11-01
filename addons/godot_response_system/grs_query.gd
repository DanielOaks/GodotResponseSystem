extends Node
class_name GrsQuery

var facts: GrsFacts
var extra_fact_dictionaries: Array[GrsFacts]

func _init():
	facts = GrsFacts.new()
