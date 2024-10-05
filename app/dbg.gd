extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Area3D.mouse_entered.connect(_mouse_enter)
	$Area3D.mouse_exited.connect(_mouse_exit)

func _mouse_enter():
	$Sprite3D.visible = true

func _mouse_exit():
	$Sprite3D.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
