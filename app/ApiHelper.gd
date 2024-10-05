extends Node

signal populate_stars(stars: Array[StarData])

# XXX Assuming things about threading...
var running_query = false
var query_queue = []

# Called when the node enters the scene tree for the first time.
func _ready():
	var some_target: Target = Target.new(195.0149029, 12.6823534, 600)

func TestEarthQuery():
	var query = """
		select top 5 ra, dec, phot_g_mean_mag, distance_gspphot, teff_gspphot
		from gaiadr3.gaia_source
		where phot_g_mean_mag < 6.5
		  and distance_gspphot is not null
	"""

	run_query(query)

	#_load_builtin_starmap("test_earth_small")

func TargettedQuery(target: Target):
	# NB we'll just be emitting the stars as we get them, caller is responsible for aggregating
	for distance in range(100, target.dist_pc, 100):
		var step = target.make_query_step(distance)
		var cone_query = step.make_cone_query()
		print("My query is %s" % cone_query)
		run_query(cone_query)

func run_query(query: String):
	if running_query:
		query_queue.append(query)
	else:
		running_query = true

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

func _on_req_complete(result, _response_code, _headers, body):
	running_query = false
	
	# Maybe queue another
	if query_queue.size() > 0:
		var next_query = query_queue.pop_front()
		run_query(next_query)

	if result != HTTPRequest.RESULT_SUCCESS:
		print("Failed to load data from server: %d" % result)
		return
	
	var res = body.get_string_from_utf8()
	print("Parse this stuff %d" % _response_code)

	

	print(res)
	var json = JSON.parse_string(res)
	_parse_and_emit_starmap(json)
	

func _load_builtin_starmap(filename: String):
	var starmap: JSON = load("res://data/builtin_starmaps/" + filename + ".json")
	# NB on load the JSON data IS inside another "data" entry, this isn't a mistake
	_parse_and_emit_starmap(starmap["data"])

func _parse_and_emit_starmap(json):
	# TODO Gather our star data and emit it
	var stars: Array[StarData] = []

	var data = json["data"]

	for row in data:
		# Data is returned as arrays of values, these must match the select column output order
		var ra = row[0]
		var dec = row[1]
		var apparent_magnitude = row[2]
		var distance_pc = row[3]
		var temperature = row[4]

		# print("Star %f %f %f" % [ra, dec, apparent_magnitude])

		stars.append(StarData.new(ra, dec, apparent_magnitude, distance_pc, temperature))

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
	var ra: float
	var dec: float
	var dist_pc: float

	func _init(_ra: float, _dec: float, _dist_pc: float):
		self.ra = _ra
		self.dec = _dec
		self.dist_pc = _dist_pc

	## Return the unit direction vector of the star
	func get_unit_direction():
		# TODO verify this is correct
		return Vector3(
			cos(self.ra) * cos(self.dec),
			sin(self.ra) * cos(self.dec),
			sin(self.dec)
		)

	## Return the inertial coordinates of the star in light years, relative to Earth.
	## Subtract these from your target exoplant coordinates to get the relative position.
	func get_inertial_coordinates_ly():
		var direction = get_unit_direction()

		# Conversion factor from https://en.wikipedia.org/wiki/Parsec
		var dist_ly = self.dist_pc * 3.261563777

		return direction * dist_ly

	func make_query_step(radius_pc: float, min_magnitude_at_target: float = 6.5):
		var near_radius = self.dist_pc - radius_pc
		var far_radius = self.dist_pc + radius_pc

		# Law of cosines
		var r = radius_pc
		var d = self.dist_pc
		var o = sqrt(d ** 2 - r ** 2)
		var num = o ** 2 + d ** 2 - r ** 2
		var den = 2 * d * o
		var cos_half_theta = num / den
		var theta_deg = 2 * acos(cos_half_theta) * 180 / PI

		# print({
		# 	"near_radius": near_radius,
		# 	"far_radius": far_radius,
		# 	"theta_deg": theta_deg,
		# })

		# How bright we'd have to be at the far edge of the radius
		var min_absolute_magnititude_at_target = Math.apparent_to_abs_magnitude(min_magnitude_at_target, self.dist_pc)

		# How apparently bright we'd have to be rom Sol, which is what the dataset has
		var min_apparent_magnitude_from_source = Math.abs_to_apparent_magnitude(min_absolute_magnititude_at_target, far_radius)

		return ConeQuery.new(self.ra, self.dec, theta_deg, near_radius, far_radius, min_apparent_magnitude_from_source)

	

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
			select top 200 ra, dec, phot_g_mean_mag, distance_gspphot, teff_gspphot
			from gaiadr3.gaia_source
			where distance({target_ra}, {target_dec}, ra, dec) < {theta_deg}
			and distance_gspphot between {near_radius} and {far_radius}
			and phot_g_mean_mag < {min_apparent_magnitude}
			and distance_gspphot is not null
		""".format({
			"target_ra": self._target_ra,
			"target_dec": self._target_dec,
			"theta_deg": self._theta_deg,
			"near_radius": self._near_radius,
			"far_radius": self._far_radius,
			"min_apparent_magnitude": self._min_apparent_magnitude
		})
		
class StarData:
	var ra: float
	var dec: float
	var apparent_magnitude: float
	var dist_pc: float
	var temperature: float

	func _init(_ra: float, _dec: float, _apparent_magnitude: float, _dist_pc: float, _temperature: float):
		self.ra = _ra
		self.dec = _dec
		self.apparent_magnitude = _apparent_magnitude
		self.dist_pc = _dist_pc
		self.temperature = _temperature

	## Return the unit direction vector of the star
	func get_unit_direction():
		# TODO verify this is correct
		return Vector3(
			cos(self.ra) * cos(self.dec),
			sin(self.ra) * cos(self.dec),
			sin(self.dec)
		)

	## Return the inertial coordinates of the star in light years, relative to Earth.
	## Subtract your target exoplant coordinates from this to get the relative position.
	func get_inertial_coordinates_ly():
		var direction = get_unit_direction()

		# Conversion factor from https://en.wikipedia.org/wiki/Parsec
		var dist_ly = self.dist_pc * 3.261563777

		return direction * dist_ly

	## Return the luminosity of the star relative to Sol
	func get_relative_luminosity():
		# https://en.wikipedia.org/wiki/Luminosity
		# TODO
		return 1
