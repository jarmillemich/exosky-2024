extends Node3D
# Obviously all this needs to be externalized somehow?

const ApiHelper = preload("res://ApiHelper.gd")


# Called when the node enters the scene tree for the first time.
func _ready():
	var api_helper = ApiHelper.new()
	add_child(api_helper)
	api_helper.TestEarthQuery()

	api_helper.populate_stars.connect(_on_populate_stars)

func _on_populate_stars(stars: Array[ApiHelper.StarData]):
	print("Got a bunch of stars %d" % stars.size())
	
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


