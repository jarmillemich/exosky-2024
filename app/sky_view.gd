extends Node3D
# Obviously all this needs to be externalized somehow?

const ApiHelper = preload("res://ApiHelper.gd")
const StarGenerator = preload("res://StarGenerator.gd")


# Called when the node enters the scene tree for the first time.
func _ready():
	var api_helper = ApiHelper.new()
	add_child(api_helper)
	api_helper.TestEarthQuery()

	# Test with HD 1690
	# var my_target = ApiHelper.Target.new(5.3055886, -8.2811442, 752.615)
	# $Camera3D.position = my_target.get_inertial_coordinates_ly()
	# api_helper.TargettedQuery(my_target)

	api_helper.populate_stars.connect(_on_populate_stars)

	$Stars.star_enter.connect(_on_star_enter)

func _on_populate_stars(stars: Array[ApiHelper.StarData]):
	print("Got a bunch of stars %d" % stars.size())
	if(stars.size() > 0 ):
		StarGenerator.gatherStars(stars)
	
func _on_star_enter(star: ApiHelper.StarData):
	$StarLabel.text = "%f %f" % [star.ra, star.dec]
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
