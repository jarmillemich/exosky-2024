extends Node3D

const ApiHelper = preload("res://ApiHelper.gd")

var star: ApiHelper.StarData = null

signal star_enter(star: ApiHelper.StarData)
signal star_exit(star: ApiHelper.StarData)
signal star_click(star: ApiHelper.StarData)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Area3D.mouse_entered.connect(_mouse_enter)
	$Area3D.mouse_exited.connect(_mouse_exit)
	$Area3D.input_event.connect(_input_event)

func _mouse_enter():
	$Sprite3D.visible = true
	star_enter.emit(star)

func _mouse_exit():
	$Sprite3D.visible = false
	star_exit.emit(star)

func _input_event(camera, event: InputEvent, event_position, normal, shape_idx):
	if event is InputEventMouseButton:
		if event.pressed:
			star_click.emit(star)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
