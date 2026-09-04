class_name State
extends Node
## Base class for a single state inside a StateMachine. Extend this for
## each concrete behavior (Idle, Move, Attack, Hurt, Dead...) and
## override whichever virtual methods you need. The owning StateMachine
## assigns `entity` before the state is ever entered.

## The entity this state controls. Assigned by the parent StateMachine.
var entity: EntityBase

## Emit this to ask the StateMachine to switch states, e.g.
## `transition_requested.emit(&"Attack")`.
signal transition_requested(state_name: StringName, data: Dictionary)

## Called once when this state becomes active. `data` is whatever the
## previous state (or caller) passed along.
func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	pass

## Called once when this state is about to be replaced.
func exit() -> void:
	pass

func process_frame(_delta: float) -> void:
	pass

func process_physics(_delta: float) -> void:
	pass

func process_input(_event: InputEvent) -> void:
	pass
