extends Node
class_name GrsActor

## Emitted when a new response is ready from GRS.
signal response(type: String, content: String)

## How we refer to this actor in the rules database.
@export var actorName := ""

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

func _enter_tree():
	# create idle timer
	_idle_timer = Timer.new()
	add_child(_idle_timer)
	_idle_timer.one_shot = true
	_idle_timer.timeout.connect(emit_idle)

	# start barking
	if dispatchBarks:
		# for the first time to wait, make it totally random
		var time_to_wait = randf() * idle_wait_time()
		_idle_timer.start(time_to_wait)

	# add self to GRS
	grs = get_node("/root/GodotResponseSystem")
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

## Sends an event to GRS.
func dispatch(concept: String):
	print_debug("Dispatching concept from ", actorName, " to GRS: ", concept)
