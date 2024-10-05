extends Node3D
# Obviously all this needs to be externalized somehow?

const ApiHelper = preload("res://ApiHelper.gd")
const StarGenerator = preload("res://StarGenerator.gd")

func _process(_delta: float) -> void:
	_update_mouse_line()

# Called when the node enters the scene tree for the first time.
func _ready():
	call_deferred("_init_mouse_line")
	mouse_line = await Draw3D.line(Vector3.ZERO, Vector3.ZERO, Color.WHITE)
	var api_helper = ApiHelper.new()
	add_child(api_helper)
	api_helper.TestEarthQuery()

	# Test with HD 1690
	# var my_target = ApiHelper.Target.new(5.3055886, -8.2811442, 752.615)
	# $Camera3D.position = my_target.get_inertial_coordinates_ly()
	# api_helper.TargettedQuery(my_target)

	api_helper.populate_stars.connect(_on_populate_stars)

	#$Stars.star_enter.connect(_on_star_enter)
	$Stars.star_click.connect(_on_star_click)

func _on_populate_stars(stars: Array[ApiHelper.StarData]):
	print("Got a bunch of stars %d" % stars.size())
	if(stars.size() > 0 ):
		StarGenerator.gatherStars(stars)
	
#func _on_star_enter(star: ApiHelper.StarData):
	#$StarLabel.text = "%f %f" % [star.ra, star.dec]

var points:Array
var lines:Array
var mouse_line: MeshInstance3D

func _init_mouse_line():
	mouse_line = await Draw3D.line(Vector3.ZERO, Vector3.ZERO, Color.WHITE)

func _on_star_click(star: ApiHelper.StarData):
	$StarLabel.text = "%f %f" % [star.ra, star.dec]
	_draw_point_and_line(star)

func _update_mouse_line():
	var mouse_pos = get_mouse_pos()
	var mouse_line_immediate_mesh = mouse_line.mesh as ImmediateMesh
	if mouse_pos != null:
		var mouse_pos_V3:Vector3 = mouse_pos
		mouse_line_immediate_mesh.clear_surfaces()
		mouse_line_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		mouse_line_immediate_mesh.surface_add_vertex(Vector3.ZERO)
		mouse_line_immediate_mesh.surface_add_vertex(mouse_pos_V3)
		mouse_line_immediate_mesh.surface_end()	

#Returns the position in 3d that the mouse is hovering, or null if it isnt hovering anything
func get_mouse_pos():
	var space_state = get_parent().get_world_3d().get_direct_space_state()
	var mouse_position = get_viewport().get_mouse_position()
	var camera = get_tree().root.get_camera_3d()
	
	var ray_origin = camera.project_ray_origin(mouse_position)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_position) * 1000
		
	var params = PhysicsRayQueryParameters3D.new()
	params.from = ray_origin
	params.to = ray_end
	params.collision_mask = 1
	params.exclude = []
	
	var rayDic = space_state.intersect_ray(params)	
	
	if rayDic.has("position"):
		return rayDic["position"]
	return null

func _draw_point_and_line(star: ApiHelper.StarData):
	print("click")
	#var mouse_pos = get_mouse_pos()
	#if mouse_pos != null:
	#print("mouse")
	#var mouse_pos_V3:Vector3 = mouse_pos
	var t = star.get_unit_direction() * 100
	points.append(await Draw3D.point(t,0.05))
	
	#If there are at least 2 points...
	if points.size() > 1:
		#Draw a line from the position of the last point placed to the position of the second to last point placed
		var point1 = points[points.size()-1]
		var point2 = points[points.size()-2]
		var line = await Draw3D.line(point1.position, point2.position)
		lines.append(line)
