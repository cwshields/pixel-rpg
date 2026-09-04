class_name StateMachine
extends Node
## Generic finite-state machine. Add State-derived scripts as direct
## children in the editor — each child's node name becomes its lookup
## key (a node named "Idle" is reached with transition_to(&"Idle")).
## Assumes it's a direct child of the entity it drives (uses `owner`).

@export var initial_state: StringName

var current_state: State
var states: Dictionary = {}   # StringName -> State

func _ready() -> void:
	var entity := owner as EntityBase
	for child in get_children():
		if child is State:
			var state := child as State
			states[StringName(state.name)] = state
			state.entity = entity
			state.transition_requested.connect(_on_transition_requested)
	if initial_state != &"" and states.has(initial_state):
		_change_state(initial_state, {})

func _process(delta: float) -> void:
	if current_state:
		current_state.process_frame(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.process_physics(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.process_input(event)

func transition_to(state_name: StringName, data: Dictionary = {}) -> void:
	_change_state(state_name, data)

func _on_transition_requested(state_name: StringName, data: Dictionary) -> void:
	_change_state(state_name, data)

func _change_state(state_name: StringName, data: Dictionary) -> void:
	if not states.has(state_name):
		push_warning("StateMachine: unknown state '%s'" % state_name)
		return
	if current_state == states[state_name]:
		return
	var previous_name: StringName = StringName(current_state.name) if current_state else &""
	if current_state:
		current_state.exit()
	current_state = states[state_name]
	current_state.enter(previous_name, data)
