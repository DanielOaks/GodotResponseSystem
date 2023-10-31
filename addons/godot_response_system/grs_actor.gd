extends Node
class_name GrsActor

## Emitted when a new response is ready from GRS.
signal response(type: String, content: String)

@export_group("Idle barks")

## Idle barks ask the response system whether we have any incidental responses to fire.
@export var dispatchBarks := true

## The concept to use when dispatching idle barks.
@export var idleConcept := "IdleBark"

## How often to send an idle bark
@export var idlePeriod: float = 3.0

## Randomly add this amount of time to each period.
@export var idleJitter: float = 0.5

## Sends an event to GRS.
func dispatch(concept: String):
	pass
