extends Node
class_name GRS

@onready var actors := {}
@export var concepts: Dictionary
@export var criteria: Dictionary
@export var rules: Dictionary
@export var responses: Dictionary

## Add an actor to GRS.
func add_actor(actor: GrsActor):
	if actors.has(actor.key) and not actors.get(actor.key) == actor:
		print_debug("Replacing existing actor with newly-added one: ", actor.actorName)
	actors[actor.key] = actor

## Remove an actor from GRS.
func remove_actor(actor: GrsActor):
	actors.erase(actor.key)

## Load new concept, criteria, rule, or response information.
func load(new_data: GrsImportData):
	for cname in new_data.concepts:
		var slug = cname.to_lower()
		if slug in concepts:
			print_debug("Replacing existing concept with a newly-loaded one: ", cname)
		concepts[slug] = new_data.concepts[cname]

	for cname in new_data.criteria:
		var slug = cname.to_lower()
		if slug in criteria:
			print_debug("Replacing existing criterion with a newly-loaded one: ", cname)
		criteria[slug] = new_data.criteria[cname]

	for cname in new_data.rules:
		var slug = cname.to_lower()
		if slug in rules:
			print_debug("Replacing existing rule with a newly-loaded one: ", cname)
		rules[slug] = new_data.rules[cname]

	for cname in new_data.responses:
		var slug = cname.to_lower()
		if slug in responses:
			print_debug("Replacing existing response with a newly-loaded one: ", cname)
		responses[slug] = new_data.responses[cname]

func execute_query(query: GrsQuery, actor: GrsActor):
	var possible_rules: Array[GrsRule] = []
	var evaluated_criteria := {}
	
	for rule: GrsRule in rules.values():
		var this_rule_matches := true
		
		for key in rule.criteria:
			var criterion: GrsCriterion = criteria.get(key)
			if criterion == null:
				print_debug("Can't find criterion ", key)
				this_rule_matches = false
				break
			
			var value = query.facts.get_fact(criterion.fact)
			if value == null:
				# TODO: check other fact dictionaries here
				this_rule_matches = false
				break
			
			if criterion.matchValue.begins_with('"') and criterion.matchValue.ends_with('"'):
				# comparing strings directly
				var matching_string = criterion.matchValue.left(-1).right(-1)
				var match_is_successful = matching_string == value
				evaluated_criteria[key] = match_is_successful
				
				if not match_is_successful:
					# skip to next rule
					this_rule_matches = false
					break
			else:
				print_debug("Cannot match value, skipping rule ", rule.cname)
				
				this_rule_matches = false
				break

		if this_rule_matches:
			possible_rules.append(rule)

	if possible_rules.size() == 0:
		return

	var matched_rule: GrsRule = possible_rules.pick_random()
	
	for key in matched_rule.responses:
		var rg: GrsResponseGroup = responses.get(key)
		if rg == null:
			print_debug("Response not found: ", key)
			continue
		
		# TODO: call response group so it can handle flags, etc
		var r = rg.responses.pick_random()
		
		actor.emit_response(r)
