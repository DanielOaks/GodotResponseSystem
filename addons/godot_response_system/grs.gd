class_name GRS
extends Node
## GRS (Godot Response System) is a singleton that evaluates and runs queries from actors.
## It keeps a list of actors, concepts, criteria, rules, and responses, and uses these to test
## incoming [GrsQuery]s.
##
## You shouldn't need to do much with this class directly, apart from loading the data into it.

## Contains the active [GrsActor]s which can receive responses.
var actors: Dictionary

## Contains our current set of concepts, populated by [method GRS.load]
var concepts: Dictionary

## Contains our current set of criteria, populated by [method GRS.load]
var criteria: Dictionary

## Contains our current set of rules, populated by [method GRS.load]
var rules: Dictionary

## Contains our current set of responses, populated by [method GRS.load]
var responses: Dictionary

## Add an actor to GRS. This allows the actor to receive responses from the response system.
## Note, most actors will automatically add themselves to the response system on joining the scene
## tree, so you should not need to use this method.
func add_actor(actor: GrsActor):
	if actors.has(actor.key) and not actors.get(actor.key) == actor:
		print_debug("Replacing existing actor with newly-added one: ", actor.actorName)
	actors[actor.key] = actor

## Remove an actor from GRS. Note, actors remove themselves from the response system on leaving the
## scene tree, so only use this method if you're sure you want to unload an actor early.
func remove_actor(actor: GrsActor):
	actors.erase(actor.key)

## Loads new data into the response system. This is a type of imported data, e.g. concepts,
## criteria, rules, or responses. This should be called once on game start for each type of
## resource to load.
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

func does_match(value: Variant, matches: String) -> bool:
	if matches.begins_with('"') and matches.ends_with('"'):
		# comparing strings directly
		return matches.left(-1).right(-1) == value
	elif matches.begins_with('<'):
		# TODO: handle numeric comparisons much better than this
		return value < matches.right(-1).to_float()
	elif matches.begins_with('>'):
		# TODO: handle numeric comparisons much better than this
		return value > matches.right(-1).to_float()
	print_debug("GRS: unknown match, yet to be implemented: [", matches, "]")
	return false

## Execute the given query, coming from the given actor. We search the current rule database,
## and if there's a matching rule the system sends the response to the actor.
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
				# search other fact dictionaries for this value
				this_rule_matches = false
				for extra_facts in query.extra_fact_dictionaries:
					value = extra_facts.get_fact(criterion.fact)
					if value != null:
						this_rule_matches = true

				if this_rule_matches == false:
					break

			var match_is_successful = does_match(value, criterion.matchValue)
			evaluated_criteria[key] = match_is_successful

			if not match_is_successful:
				# skip to next rule
				this_rule_matches = false
				break

		if this_rule_matches:
			# TODO: improve this by doing the weightings more smartly. this is a very naive way
			# of implementing this kind of preference for higher-weighted rules
			for i in rule.criteria.size():
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
