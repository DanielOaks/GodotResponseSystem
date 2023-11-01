extends Node
class_name GrsActor

## Emitted when a new response is ready from GRS.
signal response(type: String, content: String)

## Emitted when we are no longer marked busy.
signal no_longer_busy()

## Unique key to refer to this actor
var key: String :
	get:
		return actorName.strip_edges().to_lower()

## How we refer to this actor in the rules database.
@export var actorName := ""

## Whether this actor should automatically add itself to GRS. If unchecking this, you'll need to
## make a `GRS.add_actor()` call yourself. In either case, the actor will automatically remove
## itself from GRS on exiting the node tree.
@export var autoAddToGrs := true

@export_group("Idle barks")

## Idle barks ask the response system whether we have any incidental responses to fire.
@export var dispatchBarks := true

## The concept to use when dispatching idle barks.
@export var idleConcept := "IdleBark"

## How often to send an idle bark
@export var idlePeriod: float = 3.0

## Randomly add this amount of time to each period.
@export var idleJitter: float = 0.5

var grs: GRS
var _idle_timer: Timer

var busy_priority_level = -999
var _busy_reset_timer: Timer

func _enter_tree():
	# create idle timer
	_idle_timer = Timer.new()
	add_child(_idle_timer)
	_idle_timer.one_shot = true
	_idle_timer.timeout.connect(emit_idle)
	
	# create busy timer
	_busy_reset_timer = Timer.new()
	add_child(_busy_reset_timer)
	_busy_reset_timer.one_shot = true
	_busy_reset_timer.timeout.connect(emit_not_busy)

	# start barking
	if dispatchBarks:
		# for the first time to wait, make it totally random
		var time_to_wait = randf() * idle_wait_time()
		_idle_timer.start(time_to_wait)

	# add self to GRS
	grs = get_node("/root/GodotResponseSystem")
	if autoAddToGrs:
		grs.add_actor(self)

func _exit_tree():
	# remove self from GRS
	grs.remove_actor(self)

	# stop idle timer
	_idle_timer.stop()

## Seconds to wait before next idle bark.
func idle_wait_time() -> float:
	var nextWaitTime := idlePeriod
	nextWaitTime += randf() * idleJitter
	return nextWaitTime

func emit_idle():
	# dispatch idle event to GRS
	dispatch(idleConcept)

	# start the next run
	_idle_timer.start(idle_wait_time())

func emit_not_busy():
	emit_signal("no_longer_busy")
	busy_priority_level = -999

## Sends an event to GRS.
func dispatch(concept: String):
	# check concept priority
	var concept_key = concept.strip_edges().to_lower()
	var c: GrsConcept = grs.concepts.get(concept_key)
	if c == null:
		print_debug("Concept ", concept, " is not defined, ignoring dispatch request")

	if _busy_reset_timer.is_stopped() or busy_priority_level == -999 or c.priority > busy_priority_level:
		# keep going
		pass
	else:
		# new concept cannot interrupt current concept
		return
	
	# dispatch to grs
	var q := GrsQuery.new()
	q.facts.set_fact("who", key)
	q.facts.set_fact("concept", concept_key)
	grs.execute_query(q, self)
	
	# set priority level, timer controls whether or not this is used above so this is fine
	busy_priority_level = c.priority

## Emits a response from the actor.
func emit_response(response: GrsResponse):
	emit_signal("response", response.responseType, response.response)
	_busy_reset_timer.start(response.delay)
