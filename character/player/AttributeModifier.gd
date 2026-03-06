class_name AttributeModifier
extends Resource


## Attribute name
@export var attribute_name: StringName

## Attribute multiplier
@export var multiplier: float = 1.0


func _init(p_attribute_name: StringName = &"", p_multiplier: float = 1.0):
	attribute_name = p_attribute_name
	multiplier = p_multiplier
