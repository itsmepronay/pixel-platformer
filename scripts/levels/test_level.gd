extends Node2D
## Test level script handling player spawn alignment and out-of-bounds respawning.

@onready var spawn_point: Marker2D = $SpawnPoint
@onready var player: CharacterBody2D = $Player
@onready var out_of_bounds_zone: Area2D = $OutOfBoundsZone


func _ready() -> void:
	if player and spawn_point:
		if player.has_method("set_spawn_position"):
			player.set_spawn_position(spawn_point.global_position)
		player.global_position = spawn_point.global_position

	if out_of_bounds_zone:
		out_of_bounds_zone.body_entered.connect(_on_out_of_bounds_body_entered)


func _on_out_of_bounds_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("respawn"):
		body.respawn()
