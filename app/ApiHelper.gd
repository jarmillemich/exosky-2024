extends Node

signal populate_stars(stars: Array[StarData])

# Called when the node enters the scene tree for the first time.
func _ready():
	var some_target: Target = Target.new(195.0149029, 12.6823534, 600)

func TestEarthQuery():
	var query = """
		select top 5 ra, dec, phot_g_mean_mag
		from gaiadr3.gaia_source
		where phot_g_mean_mag < 6.5
	"""

	run_query(query)

func run_query(query: String):
	var format_re = RegEx.new()
	format_re.compile("\\s+")
	var query_formatted = format_re.sub(query, " ", true).strip_edges()

	var params = HTTPClient.new().query_string_from_dict({
		"REQUEST": "doQuery",
		"LANG": "ADQL",
		"FORMAT": "json",
		"QUERY": query_formatted
	})

	var full_query = "https://gea.esac.esa.int/tap-server/tap/sync?" + params

	var request = HTTPRequest.new()
	add_child(request)

	print("[API] Requesting: ", full_query)
	
	request.request_completed.connect(_on_req_complete)
	
	var error = request.request(full_query)

	if error != OK:
		print("Error: ", error)

func _on_req_complete(result, response_code, headers, body):
	print("Things happened: ", response_code)
	print(body.get_string_from_utf8())

	# TODO Gather our star data and emit it
	var stars: Array[StarData] = []

	var data = JSON.parse_string(body.get_string_from_utf8())["data"]

	for row in data:
		# Data is returned as arrays of values, these must match the select column output order
		var ra = row[0]
		var dec = row[1]
		var apparent_magnitude = row[2]

		stars.append(StarData.new(ra, dec, apparent_magnitude))

	#emit_signal("populate_stars", stars)
	populate_stars.emit(stars)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

### Math helpers

class Math:
	static func log10(value: float):
		return log(value) / log(10)

	static func abs_to_apparent_magnitude(abs_mag: float, distance: float):
		# https://en.wikipedia.org/wiki/Absolute_magnitude#Apparent_magnitude
		return abs_mag + 5 * log10(distance) - 5

	static func apparent_to_abs_magnitude(app_mag: float, distance: float):
		# https://en.wikipedia.org/wiki/Absolute_magnitude#Apparent_magnitude
		return app_mag - 5 * log10(distance) + 5


class Target:
	var _ra: float
	var _dec: float
	var _distance: float

	func _init(ra: float, dec: float, distance: float):
		self._ra = ra
		self._dec = dec
		self._distance = distance

	func make_query_step(radius: float, min_magnitude_at_target: float = 6.5):
		var near_radius = self._distance - radius
		var far_radius = self._distance + radius

		# Law of cosines
		var r = radius
		var d = self._distance
		var o = sqrt(d ** 2 - r ** 2)
		var num = o && 2 + d ** 2 - r ** 2
		var den = 2 * d * o
		var cos_half_theta = num / den
		var theta_deg = 2 * acos(cos_half_theta) * 180 / PI

		# How bright we'd have to be at the far edge of the radius
		var min_absolute_magnititude_at_target = Math.apparent_to_abs_magnitude(min_magnitude_at_target, self._distance)

		# How apparently bright we'd have to be rom Sol, which is what the dataset has
		var min_apparent_magnitude_from_source = Math.abs_to_apparent_magnitude(min_absolute_magnititude_at_target, self._distance)

		return ConeQuery.new(self._ra, self._dec, theta_deg, near_radius, far_radius, min_apparent_magnitude_from_source)

	

class ConeQuery:
	var _target_ra: float
	var _target_dec: float
	var _theta_deg: float
	var _near_radius: float
	var _far_radius: float
	var _min_apparent_magnitude: float

	func _init(target_ra: float, target_dec: float, theta_deg: float, near_radius: float, far_radius: float, min_apparent_magnitude: float):
		self._target_ra = target_ra
		self._target_dec = target_dec
		self._theta_deg = theta_deg
		self._near_radius = near_radius
		self._far_radius = far_radius
		self._min_apparent_magnitude = min_apparent_magnitude

	func make_cone_query():
		return """
			select count(*)
			from gaiadr3.gaia_source
			where distance({target_ra}, {target_dec}, ra, dec) < {theta_deg}
			and distance_gspphot between {near_radius} and {far_radius}
			and phot_g_mean_mag < {min_apparent_magnitude}
		""" % {
			"target_ra": self._target_ra,
			"target_dec": self._target_dec,
			"theta_deg": self._theta_deg,
			"near_radius": self._near_radius,
			"far_radius": self._far_radius,
			"min_apparent_magnitude": self._min_apparent_magnitude
		}
		
class StarData:
	var ra: float
	var dec: float
	var apparent_magnitude: float

	func _init(_ra: float, _dec: float, _apparent_magnitude: float):
		self.ra = _ra
		self.dec = _dec
		self.apparent_magnitude = _apparent_magnitude

	func get_unit_direction():
		# TODO verify this is correct
		return Vector3(
			cos(self.ra) * cos(self.dec),
			sin(self.ra) * cos(self.dec),
			sin(self.dec)
		)