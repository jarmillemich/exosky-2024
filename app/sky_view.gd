extends Node3D
# Obviously all this needs to be externalized somehow?

const ApiHelper = preload("res://ApiHelper.gd")
const StarGenerator = preload("res://StarGenerator.gd")

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

var newConstellation = false

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_BACKSPACE:
		_clear_points_and_lines()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		print("enter pressed")
		newConstellation = true

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

func _draw_point_and_line(star: ApiHelper.StarData):
	print(newConstellation)
	var t = star.get_unit_direction() * 100
	points.append(await Draw3D.point(t,0.05))
	
	#If there are at least 2 points...
	if points.size() > 1 && newConstellation == false:
		#Draw a line from the position of the last point placed to the position of the second to last point placed
		var point1 = points[points.size()-1]
		var point2 = points[points.size()-2]
		var line = await Draw3D.line(point1.position, point2.position)
		lines.append(line)

	newConstellation = false

func _clear_points_and_lines():
	for p in points:
		p.queue_free()
	points.clear()
		
	for l in lines:
		l.queue_free()
	lines.clear()
	newConstellation = true