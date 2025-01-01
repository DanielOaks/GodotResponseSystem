class_name GrsActor
extends Node
## Represents an entity (NPC, object, etc) that can receive and emit responses.
##
## Actors send queries to the response system, and can receive responses. In addition a
## [b]GrsActor[/b] can automatically emit idle queries now and then, which makes incidental dialogue
## and actions super simple to implement.

## Emitted when a new response is ready from GRS.
signal response(type: String, content: String)

## Emitted when we are no longer marked busy.
signal no_longer_busy()

## Unique key to refer to this actor. This is based on the actor name.
var key: String :
	get:
		return actor_name.strip_edges().to_lower()

## How we refer to this actor in the rules database.
@export var actor_name := ""

## Whether this actor should automatically add itself to GRS. If unchecking this, you'll need to
## make a [method GRS.add_actor] call yourself. In either case, the actor will automatically remove
## itself from GRS on exiting the node tree.
@export var auto_add_to_grs := true

@export_group("Idle barks")

## Whether this actor should automatically dispatch idle events. These make incidental dialogue
## much easier to implement, as you won't need to periodically make the actor call this yourself.
@export var dispatch_barks := true

## The concept to use when dispatching idle queries. This concept should exist in your [GRS] data.
@export var idle_concept := "IdleBark"

## How often to send an idle query.
@export var idle_period: float = 3.0

## Add up to this much time, randomly, between each idle query.
@export var idle_jitter: float = 0.5

## If under 1, some idle events will be skipped. For example, 0.8 means only 80% of idle events
## will fire.
@export var idle_trigger_chance: float = 1.0

var _grs: GRS
var _idle_timer: Timer

var _busy_priority_level = -999
var _busy_reset_timer: Timer

## This actor's facts.
## [b]NOTE:[/b] May be removed later, as this seems difficult to save between sessions.
var facts: GrsFacts

## Connect a function here which returns this actor's facts. This function takes one parameter,
## the actor which calls it.
var get_query_facts: Callable

func _enter_tree():
	# create facts
	facts = GrsFacts.new()

	# create idle timer
	_idle_timer = Timer.new()
	add_child(_idle_timer)
	_idle_timer.one_shot = true
	_idle_timer.timeout.connect(emit_idle)

	# create busy timer
	_busy_reset_timer = Timer.new()
	add_child(_busy_reset_timer)
	_busy_reset_timer.one_shot = true
	_busy_reset_timer.timeout.connect(_emit_not_busy)

	# start barking
	if dispatch_barks:
		# for the first time to wait, make it totally random
		var time_to_wait = randf() * _idle_wait_time()
		_idle_timer.start(time_to_wait)

	# add self to GRS
	_grs = get_node("/root/GodotResponseSystem")
	if auto_add_to_grs:
		_grs.add_actor(self)

func _exit_tree():
	# remove self from GRS
	_grs.remove_actor(self)

	# stop idle timer
	_idle_timer.stop()

# Seconds to wait before next idle bark.
func _idle_wait_time() -> float:
	var next_wait_time := idle_period
	next_wait_time += randf() * idle_jitter
	return next_wait_time

## Emit an idle query to [GRS]. Automatically called if [param dispatch_barks] is true.
func emit_idle():
	# dispatch idle event to GRS
	if randf() < idle_trigger_chance:
		dispatch(idle_concept)

	# start the next run
	if dispatch_barks:
		_idle_timer.start(_idle_wait_time())

# Lets us dispatch any and all queries again.
func _emit_not_busy():
	emit_signal("no_longer_busy")
	_busy_priority_level = -999

## Sends an event to [GRS] for evaluation.
func dispatch(concept: String):
	# check concept priority
	var concept_key = concept.strip_edges().to_lower()
	var c: GrsConcept = _grs.concepts.get(concept_key)
	if c == null:
		print_debug("Concept ", concept, " is not defined, ignoring dispatch request")

	if _busy_reset_timer.is_stopped() or _busy_priority_level == -999 or c.priority > _busy_priority_level:
		# keep going
		pass
	else:
		# new concept cannot interrupt current concept
		return

	# get  queryfacts
	var q: GrsQuery = GrsQuery.new()
	q.facts = GrsFacts.new()
	if get_query_facts.is_valid():
		q.facts = get_query_facts.call(self)

	q.facts.set_fact("who", key)
	q.facts.set_fact("concept", concept_key)
	q.extra_fact_dictionaries.append(facts)

	# execute query
	_grs.execute_query(q, self)

	# set priority level, timer controls whether or not this is used above so this is fine
	_busy_priority_level = c.priority

## Emits the given response from this actor. This is used by [GRS] when the actor receives
## a response.
func emit_response(response: GrsResponse):
	emit_signal("response", response.responseType, response.response)
	_busy_reset_timer.start(response.delay)
