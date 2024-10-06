extends Camera3D

@export_range(0, 10, 0.01) var sensitivity : float = 3

const RAY_LENGTH = 1000.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
    #rotate_y(-delta)

func _input(event):
    if not current:
        return

    # if event is InputEventMouseButton and event.pressed and event.button_index == 1:
    #     var camera3d = $Camera3D
    #     var from = camera3d.project_ray_origin(event.position)
    #     var to = from + camera3d.project_ray_normal(event.position) * RAY_LENGTH
    #     print(to)

    if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        if event is InputEventMouseMotion:
            rotation.y -= event.relative.x / 1000.0 * sensitivity * fov / 75.0
            rotation.x -= event.relative.y / 1000.0 * sensitivity * fov / 75.0
            rotation.x = clamp(rotation.x, PI/-2, PI/2)

    if event is InputEventMouseButton:
        match event.button_index:
            MOUSE_BUTTON_RIGHT:
                Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE)
            MOUSE_BUTTON_WHEEL_DOWN:
                fov += 1
            MOUSE_BUTTON_WHEEL_UP:
                fov -= 1
