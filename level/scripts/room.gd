class_name Room
extends Node2D


# Later, reference Area resource which itself reference BGM, but for now it's simpler to just
# reference BGM
@export var bgm: AudioStream


var level_transitions: Array[LevelTransition]


func _ready() -> void:
	# Store all level transition references and back-references to this Room
	# (_ready is called bottom-up, so this works without needing to wait 1 frame)
	for child in get_children():
		var level_transition := child as LevelTransition
		if level_transition:
			level_transitions.append(level_transition)
			level_transition.room = self

	SceneManager.load_scene_finished.connect(_on_load_scene_finished)


func _on_load_scene_finished():
	# Assign new current room
	InGameManager.room = self

	MusicManager.play_music(bgm)
