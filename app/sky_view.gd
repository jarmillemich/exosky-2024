extends Node3D
# Obviously all this needs to be externalized somehow?

const ApiHelper = preload("res://ApiHelper.gd")
const StarGenerator = preload("res://StarGenerator.gd")


# Called when the node enters the scene tree for the first time.
func _ready():
	var api_helper = ApiHelper.new()
	add_child(api_helper)
	api_helper.TestEarthQuery()

	# Test with Lich
	var my_target = ApiHelper.Target.new(195.0149029, 12.6823534, 600)
	#api_helper.TargettedQuery(my_target)

	api_helper.populate_stars.connect(_on_populate_stars)

func _on_populate_stars(stars: Array[ApiHelper.StarData]):
	print("Got a bunch of stars %d" % stars.size())
	if(stars.size() > 0 ):
		StarGenerator.gatherStars(stars)
	
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
