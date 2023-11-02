extends Node2D

@onready var grs: GRS = get_node("/root/GodotResponseSystem")
@onready var player = $Character2D
@onready var em_actor = $Em/GrsActor

func _ready():
	# load data into GRS
	grs.load(preload("res://examples/basic/grs/concepts.csv"))
	grs.load(preload("res://examples/basic/grs/criteria.csv"))
	grs.load(preload("res://examples/basic/grs/rules.csv"))
	grs.load(preload("res://examples/basic/grs/responses.csv"))
	
	em_actor.update_facts = _update_em_facts

func _update_em_facts(actor: GrsActor):
	var distanceFromPlayer = player.global_position.distance_to($Em.global_position)
	actor.facts.set_fact("playerDistance", distanceFromPlayer)

func _on_grs_actor_response(type: String, content: String):
	if type == "say":
		$Em/say.text = content
	else:
		print_debug("em got unknown response type : ", type, " : ", content)

func _on_grs_actor_no_longer_busy():
	$Em/say.text = ""
