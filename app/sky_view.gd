extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	$HTTPRequest.request_completed.connect(_on_req_complete)
	$HTTPRequest.request("https://gea.esac.esa.int/tap-server/tap/sync?REQUEST=doQuery&LANG=ADQL&FORMAT=csv&QUERY=SELECT+TOP+5+source_id,ra,dec+FROM+gaiadr3.gaia_source")

func _on_req_complete(result, response_code, headers, body):
	print("Things happened: ", response_code)
	print(body.get_string_from_utf8())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
