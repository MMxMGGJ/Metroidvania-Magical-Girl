class_name FXManager
extends Node


## Spawn one-shot FX
func spawn_fx(fx_prefab: PackedScene, spawn_position: Vector2, flip_x: bool = false,
		spawn_angle: float = 0.0, sfx: AudioStream = null) -> OneShotFX:
	# Need explicit typing because of https://github.com/godotengine/godot/issues/114422
	var room: Room = InGameManager.room
	var fx: OneShotFX = NodeUtils.instantiate_under_at(fx_prefab, room.fxs_parent, spawn_position)

	if flip_x:
		fx.scale.x *= -1

	# Note: rotation complementarity based on flip must done by caller
	fx.rotation = spawn_angle

	if sfx != null:
		InGameManager.sfx_manager.spawn_sfx(sfx)
	return fx
