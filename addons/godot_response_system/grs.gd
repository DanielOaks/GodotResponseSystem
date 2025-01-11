class_name GRS
extends Node
## GRS (Godot Response System) is a singleton that evaluates and runs queries from actors.
## It keeps a list of actors, concepts, criteria, rules, and responses, and uses these to test
## incoming [GrsQuery]s.
##
## You shouldn't need to do much with this class directly, apart from loading the data into it.

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

## Add an actor to GRS. This allows the actor to receive responses from the response system.
## Note, most actors will automatically add themselves to the response system on joining the scene
## tree, so you should not need to use this method.
func add_actor(actor: GrsActor):
	if actors.has(actor.key) and not actors.get(actor.key) == actor:
		print_debug("Replacing existing actor with newly-added one: ", actor.actor_name)
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
	if debug and new_data.concepts.size():
		print("[GRS] Concepts loaded: ", concepts.size())

	for cname in new_data.criteria:
		var slug = cname.to_lower()
		if slug in criteria:
			print_debug("Replacing existing criterion with a newly-loaded one: ", cname)
		criteria[slug] = new_data.criteria[cname]
	if debug and new_data.criteria.size():
		print("[GRS] Criteria loaded: ", criteria.size())

	for cname in new_data.rules:
		var slug = cname.to_lower()
		if slug in rules:
			print_debug("Replacing existing rule with a newly-loaded one: ", cname)
		rules[slug] = new_data.rules[cname]
	if debug and new_data.rules.size():
		print("[GRS] Rules loaded: ", rules.size())

	for cname in new_data.responses:
		var slug = cname.to_lower()
		if slug in responses:
			print_debug("Replacing existing response with a newly-loaded one: ", cname)
		responses[slug] = new_data.responses[cname]
	if debug and new_data.responses.size():
		print("[GRS] Responses loaded: ", responses.size())

const FLOAT_MATCH_TOLERANCE = 0.001

# matchers are intentionally not documented here. they're in the readme
func does_match(value: Variant, matches: String) -> bool:
	var invert := false
	if matches.begins_with("!"):
		invert = true
		matches = matches.right(-1)
	if matches.begins_with("="):
		matches = matches.right(-1)

	var result: bool = false

	# do string comparison first, to avoid type issues.
	# (comparing invalid types breaks things)
	if matches.begins_with('"') and matches.ends_with('"'):
		# comparing strings directly, case insensitive
		if typeof(value) == TYPE_STRING:
			result = matches.left(-1).right(-1).to_lower() == value.to_lower()
		else:
			print_debug("GRS: can't match [", matches, "] to value [", value, "] as value is a ", typeof(value))
		return !result if invert else result

	# all numeric matches are below, so ignore strings here
	if typeof(value) == TYPE_STRING:
		print_debug("GRS: can't check numeric matcher [", matches, "] against string type [", value, "]")
		return !result if invert else result

	# now do all the non-string comparisons
	if matches.is_valid_float():
		# comparing numbers directly
		result = absf(matches.to_float() - value) < FLOAT_MATCH_TOLERANCE
	elif matches.begins_with('<='):
		# TODO: handle numeric comparisons much better than this
		result = value <= matches.right(-2).to_float()
	elif matches.begins_with('<'):
		# TODO: handle numeric comparisons much better than this
		result = value < matches.right(-1).to_float()
	elif matches.begins_with('>='):
		# TODO: handle numeric comparisons much better than this
		result = value >= matches.right(-2).to_float()
	elif matches.begins_with('>'):
		# TODO: handle numeric comparisons much better than this
		result = value > matches.right(-1).to_float()
	else:
		print_debug("GRS: unknown match type, yet to be implemented: [", matches, "]")

	return !result if invert else result

## Execute the given query, coming from the given actor. We search the current rule database,
## and if there's a matching rule the system sends the response to the actor.
## Returns true if this resulted in a response from the actor.
func execute_query(query: GrsQuery, actor: GrsActor) -> bool:
	var concept = query.facts.get_fact("concept")
	if concept in suppress_concepts:
		return false

	if debug:
		print("[GRS] Executing query: concept [", query.facts.get_fact("concept"), "] against actor ", actor.actor_name)
		print("[GRS] with facts:")
		query.facts.list_facts()

	var largest_matching_rule_weight := 0
	var possible_rules: Array[GrsRule] = []
	var evaluated_criteria := {}

	# random number attached to this query. used to create rare criterion, etc
	query.facts.set_fact("randomnum", randf_range(0, 100))

	for rule: GrsRule in rules.values():
		var this_rule_matches := true

		if debug:
			print("  [GRS] Checking rule ", rule.cname)
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
					if debug:
						print("    [GRS] Rule not matched, missing fact: ", key, "  fact [", criterion.fact, "]")
					break

			var match_is_successful = does_match(value, criterion.matchValue)
			evaluated_criteria[key] = match_is_successful

			if not match_is_successful:
				# skip to next rule
				this_rule_matches = false
				if debug:
					print("    [GRS] Rule not matched, fact doesn't match: ", key, "  values [", value, "] [", criterion.matchValue, "]")
				break

		if this_rule_matches:
			var current_rule_weight = rule.criteria.size()
			if largest_matching_rule_weight < current_rule_weight:
				possible_rules = []
				largest_matching_rule_weight = current_rule_weight

			if current_rule_weight == largest_matching_rule_weight:
				possible_rules.append(rule)
				if debug:
					print("    [GRS] RULE MATCHED!")
			else:
				if debug:
					print("    [GRS] Rule not matched, isn't specific enough")

	if possible_rules.size() == 0:
		return false

	var matched_rule: GrsRule = possible_rules.pick_random()

	var did_response = false

	for key in matched_rule.responses:
		var rg: GrsResponseGroup = responses.get(key)
		if rg == null:
			print_debug("Response not found: ", key)
			continue

		# TODO: call response group so it can handle flags, etc
		var r: GrsResponse = rg.responses.pick_random()

		actor.emit_response(r)
		did_response = true

		if r.thenActor and r.thenConcept:
			var wait_seconds = actor.busy_time_left() + r.thenDelay

			if debug:
				print("[GRS] Response [", r.response, "] sent, now sending THEN concept ", r.thenConcept, " to actor ", r.thenActor, " after ", wait_seconds, " seconds.")

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
