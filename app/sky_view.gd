extends Node3D
# Obviously all this needs to be externalized somehow?

const ApiHelper = preload("res://ApiHelper.gd")
const StarGenerator = preload("res://StarGenerator.gd")
var api_helper = ApiHelper.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	print("We are %s" % OS.get_name())

	call_deferred("_init_mouse_line")
	mouse_line = await Draw3D.line(Vector3.ZERO, Vector3.ZERO, Color.WHITE)
	add_child(api_helper)

	# Test with HD 1690
	var my_target = ApiHelper.Target.new(5.3055886, -8.2811442, 752.615)
	# $Camera3D.position = my_target.get_inertial_coordinates_ly()

	api_helper.populate_stars.connect(_on_populate_stars)
	
	if OS.get_name() == "Web" || true:
		print("Loading builtin starmap for web demo")
		api_helper.load_builtin_starmap("hd-1690")
	else:
		api_helper.TargettedQuery(my_target)

	

	#$Stars.star_enter.connect(_on_star_enter)
	$Stars.star_click.connect(_on_star_click)

var newConstellation = false

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_BACKSPACE:
		_clear_points_and_lines()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		print("enter pressed")
		newConstellation = true


# func do_earth_test():
# 	api_helper.TestEarthQuery()
	
# 	# Add some know constellations (Earth) to test rendering
	
# 	var hour = 15.0
# 	var minute = hour / 60.0
# 	var second = minute / 60.0
# 	var points = [
# 		# Libra first
# 		# 15h 05m29.9s   -25°22'42.8"
# 		# 14h 52m13.7s   -16°08'36.2"
# 		# 15h 18m19.2s   -09°28'22.3"
# 		# 15h 36m53.6s   -14°52'15.9"
# 		# 15h 55m13.1s   -16°48'04.2"
# 		[15 * hour + 5 * minute + 29.9 * second, -25 - 22 / 60.0 - 42.8 / 3600.0],
# 		[14 * hour + 52 * minute + 13.7 * second, -16 - 8 / 60.0 - 36.2 / 3600.0],
# 		[15 * hour + 18 * minute + 19.2 * second, -9 - 28 / 60.0 - 22.3 / 3600.0],
# 		[15 * hour + 36 * minute + 53.6 * second, -14 - 52 / 60.0 - 15.9 / 3600.0],
# 		[15 * hour + 55 * minute + 13.1 * second, -16 - 48 / 60.0 - 4.2 / 3600.0],

# 		# Grus
# 		# 23h 02m22.1s   -52°37'20.9"
# 		# 22h 50m04.4s   -51°11'16.3"
# 		# 23h 11m47.0s   -45°06'47.3"
# 		# 22h 44m10.0s   -46°45'22.2"
# 		# 22h 09m48.6s   -46°50'33.3"
# 		# 23h 08m17.8s   -43°23'13.7"
# 		# 22h 30m46.0s   -43°22'12.3"
# 		# 22h 07m37.3s   -39°25'29.6"
# 		# 21h 55m26.4s   -37°14'57.7"
# 		[23 * hour + 2 * minute + 22.1 * second, -52 - 37 / 60.0 - 20.9 / 3600.0],
# 		[22 * hour + 50 * minute + 4.4 * second, -51 - 11 / 60.0 - 16.3 / 3600.0],
# 		[23 * hour + 11 * minute + 47.0 * second, -45 - 6 / 60.0 - 47.3 / 3600.0],
# 		[22 * hour + 44 * minute + 10.0 * second, -46 - 45 / 60.0 - 22.2 / 3600.0],
# 		[22 * hour + 9 * minute + 48.6 * second, -46 - 50 / 60.0 - 33.3 / 3600.0],
# 		[23 * hour + 8 * minute + 17.8 * second, -43 - 23 / 60.0 - 13.7 / 3600.0],
# 		[22 * hour + 30 * minute + 46.0 * second, -43 - 22 / 60.0 - 12.3 / 3600.0],
# 		[22 * hour + 7 * minute + 37.3 * second, -39 - 25 / 60.0 - 29.6 / 3600.0],
# 		[21 * hour + 55 * minute + 26.4 * second, -37 - 14 / 60.0 - 57.7 / 3600.0],

# 	]

# 	print(points)

# 	for point in points:
# 		var unit = ApiHelper.Math.get_unit_direction(point[0], point[1])
# 		var dist = 20

# 		const Selector = preload("res://Selector.tscn")

# 		var selector_inst = Selector.instantiate()
# 		selector_inst.position = unit * dist
		
# 		$Stars.add_child(selector_inst)
# 		selector_inst.look_at(Vector3.ZERO, Vector3.FORWARD)


func _on_populate_stars(stars: Array[ApiHelper.StarData]):
	print("Got a bunch of stars %d" % stars.size())
	if(stars.size() > 0 ):
		$LoadingLabel.text = "Loading..."
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
