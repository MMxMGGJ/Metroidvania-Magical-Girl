class_name PlayerCharacterState
extends Node
## Component that runs an action for a player character


## Signal emitted when state is entered
signal entered

## Signal emitted when state is exited
signal exited


## Owning player character
## Set on player character initialization
var character: PlayerCharacterBase


func enter():
	entered.emit()
	on_enter()


func exit():
	exited.emit()
	on_exit()


# abstract
func get_state_name() -> StringName:
	push_error("[PlayerCharacterState] get_state_name: not implemented on '%s'" %
		get_path())
	return &""


# abstract
## Return base animation to play while this action is running
## Note that since Player Character States have their own start/interrupt/complete system,
## using this with base animation supersedes the override animation system,
## which is not needed for Player Character States
func get_base_animation() -> StringName:
	push_error("[PlayerCharacterState] get_base_animation: not implemented on '%s'" %
		get_path())
	return &""


# virtual
## Return the list of tags that are activated while this action is running
func get_tags() -> Array[StringName]:
	return []


# virtual
## Return the list of attribute modifiers that are activated while this action is running
func get_attribute_modifiers() -> Array[AttributeModifier]:
	return []


# virtual
## Called when state is entered
func on_enter():
	pass


# abstract
## Custom action on_physics_process when override_move returns true
## Only needs implementation if override_move may return true
func on_physics_process(_delta: float):
	push_error("[PlayerCharacterState] process_move: not implemented on '%s', make sure to override
		it on child class when override_move returns true",
		get_path())


# virtual
## Called when state is exited
func on_exit():
	pass


# virtual
## Called when changing state from this state to new_state (between this state's on_exit
## and new state's on_enter)
func on_transition_to(_new_state: PlayerCharacterState):
	pass
