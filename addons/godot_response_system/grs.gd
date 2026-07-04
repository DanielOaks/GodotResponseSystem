extends Node
## GRS (Godot Response System) is a singleton that evaluates and runs queries from actors.
## It keeps a list of actors, concepts, criteria, rules, and responses, and uses these to test
## incoming [GrsQuery]s.
##
## You shouldn't need to do much with this class directly, apart from loading the data into it.

const GrsRule = preload("res://addons/godot_response_system/grs_rule.gd")
const GrsCriterion = preload("res://addons/godot_response_system/grs_criterion.gd")
const GrsResponseGroup = preload("res://addons/godot_response_system/grs_response_group.gd")

func _log(...message: Array):
	print("GRS: " + " ".join(message.map(str)))

var debug: bool = false
var suppress_concepts: Array[String]

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

## World facts
var world_fact_getter: Callable
var world_fact_setter: Callable


# Get facts from, and save facts to, the world fact store
func register_world_facts(getter: Callable, setter: Callable) -> void:
	world_fact_getter = getter
	world_fact_setter = setter


## Safe wrapper to get a world fact
func get_world_fact(key: String) -> Variant:
	if world_fact_getter.is_valid():
		return world_fact_getter.call(key)
	return null


## Safe wrapper to set a world fact
func set_world_fact(key: String, value: Variant) -> void:
	if world_fact_setter.is_valid():
		world_fact_setter.call(key, value)


## Add an actor to GRS. This allows the actor to receive responses from the response system.
## Note, most actors will automatically add themselves to the response system on joining the scene
## tree, so you should not need to use this method.
func add_actor(actor: GrsActor):
	if actors.has(actor.key) and not actors.get(actor.key) == actor:
		_log("Replacing existing actor with newly-added one: ", actor.actor_name)
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
			_log("Replacing existing concept with a newly-loaded one: ", cname)
		concepts[slug] = new_data.concepts[cname]
	if debug and new_data.concepts.size():
		print("Concepts loaded: ", concepts.size())

	for cname in new_data.criteria:
		var slug = cname.to_lower()
		if slug in criteria:
			_log("Replacing existing criterion with a newly-loaded one: ", cname)
		criteria[slug] = new_data.criteria[cname]
	if debug and new_data.criteria.size():
		print("Criteria loaded: ", criteria.size())

	for cname in new_data.rules:
		var slug = cname.to_lower()
		if slug in rules:
			_log("Replacing existing rule with a newly-loaded one: ", cname)
		rules[slug] = new_data.rules[cname]
	if debug and new_data.rules.size():
		print("Rules loaded: ", rules.size())

	for cname in new_data.responses:
		var slug = cname.to_lower()
		if slug in responses:
			_log("Replacing existing response with a newly-loaded one: ", cname)
		responses[slug] = new_data.responses[cname]
	if debug and new_data.responses.size():
		print("Responses loaded: ", responses.size())


const FLOAT_MATCH_TOLERANCE = 0.001


# matchers are intentionally not documented here. they're in the readme
func does_match(value: Variant, matches: String) -> bool:
	# match ranges
	if "," in matches:
		var conditions = matches.split(",")
		for condition in conditions:
			# if any individual condition fails the whole match fails
			if not does_match(value, condition.strip_edges()):
				return false
		return true

	var invert := false
	matches = matches.strip_edges()
	if matches.begins_with("!"):
		invert = true
		matches = matches.trim_prefix("!")
	if matches.begins_with("="):
		matches = matches.trim_prefix("=")

	var result: bool = false

	# do string comparison first, to avoid type issues.
	# (comparing invalid types breaks things)
	if matches.begins_with('"') and matches.ends_with('"'):
		# comparing strings directly, case insensitive
		if typeof(value) == TYPE_STRING:
			result = matches.trim_prefix('"').trim_suffix('"').to_lower() == value.to_lower()
		else:
			_log("Can't match [", matches, "] to value [", value, "] as value is a ", typeof(value))
		return !result if invert else result

	if typeof(value) == TYPE_BOOL:
		if matches.is_empty():
			pass
		else:
			var first_char = matches.to_lower()[0]
			if first_char in ["t", "y", "1"]:
				result = (value == true)
			elif first_char in ["f", "n", "0"]:
				result = (value == false)
			else:
				_log("Unrecognized boolean match string [", matches, "]")
		return !result if invert else result

	# all numeric matches are below, so ignore others here
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		_log("Can't check numeric matcher [", matches, "] against non-number [", value, "]")
		return !result if invert else result

	# now do all the non-string comparisons
	if matches.is_valid_float():
		# comparing numbers directly
		result = is_equal_approx(float(value), matches.to_float())
	elif matches.begins_with("<="):
		var target = matches.trim_prefix("<=").to_float()
		result = value < target or is_equal_approx(float(value), target)
	elif matches.begins_with("<"):
		var target = matches.trim_prefix("<").to_float()
		result = value < target and not is_equal_approx(float(value), target)
	elif matches.begins_with(">="):
		var target = matches.trim_prefix(">=").to_float()
		result = value > target or is_equal_approx(float(value), target)
	elif matches.begins_with(">"):
		var target = matches.trim_prefix(">").to_float()
		result = value > target and not is_equal_approx(float(value), target)
	else:
		_log("Unknown match type, yet to be implemented: [", matches, "]")

	return !result if invert else result


## Execute the given query, coming from the given actor. We search the current rule database,
## and if there's a matching rule the system sends the response to the actor.
## Returns true if this resulted in a response from the actor.
func execute_query(query: GrsQuery, actor: GrsActor) -> bool:
	var concept = query.facts.get_fact("concept")
	if concept in suppress_concepts:
		return false

	if debug:
		print("Executing query: concept [", query.facts.get_fact("concept"), "] against actor ", actor.actor_name)
		print("  with transient query facts:")
		query.facts.list_facts()

	var largest_matching_rule_weight := 0
	var possible_rules: Array[GrsRule] = []
	var evaluated_criteria := { }

	for rule: GrsRule in rules.values():
		var this_rule_matches := true

		if debug:
			print("  Checking rule ", rule.cname)
		for key in rule.criteria:
			var criterion: GrsCriterion = criteria.get(key)
			if criterion == null:
				_log("Can't find criterion ", key)
				this_rule_matches = false
				break

			for fact_name in criterion.matches:
				var clean_fact_name = fact_name.strip_edges().to_lower()
				var value = null

				# match dynamic facts
				if clean_fact_name == "randomnum":
					# random number 0-100. used to create rare criterion, etc
					value = randf_range(0, 100)

				if value == null:
					# search transient query facts
					value = query.facts.get_fact(fact_name)

				if value == null:
					# search actor facts
					value = actor.get_fact(fact_name)

				if value == null:
					# search world facts
					value = get_world_fact(fact_name)

				if value == null:
					if debug:
						print("    Rule not matched, missing fact [", fact_name, "] in criteria: ", key)
					break

				var match_is_successful = does_match(value, criterion.matches[fact_name])
				evaluated_criteria[key] = match_is_successful

				if not match_is_successful:
					# skip to next rule
					this_rule_matches = false
					if debug:
						print("    Rule not matched, fact doesn't match: ", key, "  values [", value, "] [", criterion.matches[fact_name], "]")
					break

		if this_rule_matches:
			var current_rule_weight = rule.criteria.size()
			if largest_matching_rule_weight < current_rule_weight:
				possible_rules = []
				largest_matching_rule_weight = current_rule_weight

			if current_rule_weight == largest_matching_rule_weight:
				possible_rules.append(rule)
				if debug:
					print("    RULE MATCHED!")
			else:
				if debug:
					print("    Rule not matched, isn't specific enough")

	if possible_rules.size() == 0:
		return false

	var matched_rule: GrsRule = possible_rules.pick_random()

	var did_response = false

	for key in matched_rule.responses:
		var rg: GrsResponseGroup = responses.get(key)
		if rg == null:
			_log("Response not found: ", key)
			continue

		# TODO: call response group so it can handle flags, etc
		var r: GrsResponse = rg.responses.pick_random()

		actor.emit_response(r)
		did_response = true

		if r.thenActor and r.thenConcept:
			var wait_seconds = actor.busy_time_left() + r.thenDelay

			if debug:
				print("Response [", r.response, "] sent, now sending THEN concept ", r.thenConcept, " to actor ", r.thenActor, " after ", wait_seconds, " seconds.")

			if r.thenActor == "self":
				actor.dispatch_after(r.thenConcept, wait_seconds)
			if r.thenActor == "any":
				# TODO: randomise this iteration so we hit different actors each time?
				await get_tree().create_timer(wait_seconds).timeout
				for thenActor: GrsActor in actors.values():
					if thenActor == actor:
						continue
					# only let one actor respond to this
					var then_actor_did_response = await thenActor.dispatch(r.thenConcept)
					if then_actor_did_response:
						break
			else:
				var thenActor: GrsActor = actors.get(r.thenActor)
				if thenActor:
					thenActor.dispatch_after(r.thenConcept, wait_seconds)

	return did_response
