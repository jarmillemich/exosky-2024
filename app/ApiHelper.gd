extends Node

signal populate_stars_inner(stars: Array[StarData])
signal populate_stars(stars: Array[StarData])

# XXX Assuming things about threading...
var running_query = false
var query_queue = []

# Called when the node enters the scene tree for the first time.
func _ready():
	var some_target: Target = Target.new(195.0149029, 12.6823534, 600)

func TestEarthQuery():
	var query = """
		select top 5000 ra, dec, phot_g_mean_mag, r_med_photogeo, teff_gspphot, source_id
		from gaiadr3.gaia_source
		left join external.gaiaedr3_distance using (source_id)
		where phot_g_mean_mag < 5.0
	"""

	run_query(query)

	# Forward directly
	populate_stars.emit(await populate_stars_inner)

	#_load_builtin_starmap("test_earth_small")

func TargettedQuery(target: Target):
	# NB we'll just be emitting the stars as we get them, caller is responsible for aggregating
	# We do de-duplicate though!
	var step_size = 20

	# Gather up the stars 
	var seen_stars := { 0: null }
	
	# NB We'll not include anything within 1pc using this method
	for distance in range(1, target.dist_pc - step_size, step_size):
		var step = target.make_query_step(distance, distance + step_size)
		var cone_query = step.make_cone_query()
		print("My query is %s" % cone_query)
		run_query(cone_query)
		print("Finished loading %d/%d" % [distance, target.dist_pc])

		var pop = await populate_stars_inner

		var bucket: Array[StarData] = []

		for star: StarData in pop:
			if !seen_stars.has(star.source_id):
				bucket.append(star)
			
			seen_stars[star.source_id] = star
			star.origin = target.get_inertial_coordinates_ly()
		
		populate_stars.emit(bucket)

	# Emit the sources all at once
	print("Finished loading")
	#populate_stars.emit(seen_stars.values())

func run_query(query: String):
	if running_query:
		query_queue.append(query)
		return
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
	#request.download_chunk_size = 1024 * 1024
	# XXX Required for responses above like 5KiB?
	request.use_threads = true
	add_child(request)

	print("[API] Requesting: ", full_query)

	var error = request.request(full_query)

	if error != OK:
		print("Error: ", error)
	
	var reply: Array = await request.request_completed;

	request.queue_free()

	var result: int = reply[0]
	var response_code: int = reply[1]
	var body: PackedByteArray = reply[3]

	running_query = false
	
	# Maybe queue another
	if query_queue.size() > 0:
		var next_query = query_queue.pop_front()
		run_query(next_query)

	if result != HTTPRequest.RESULT_SUCCESS:
		print("Failed to load data from server: %d %d" % [result, response_code])
		return
	
	var res = body.get_string_from_utf8()
	print("Got data with status %d" % response_code)

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
		var distance_pc = row[3] if row[3] != null else 100.0
		var temperature = row[4] if row[4] != null else 5000.0
		var source_id = row[5]

		# print("Star %f %f %f" % [ra, dec, apparent_magnitude])

		stars.append(StarData.new(source_id, ra, dec, apparent_magnitude, distance_pc, temperature))

	#emit_signal("populate_stars", stars)
	populate_stars_inner.emit(stars)

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

	static func get_unit_direction(ra_deg: float, dec_deg: float):
		var ra_rad = ra_deg * PI / 180
		var dec_rad = dec_deg * PI / 180

		return Vector3(
			cos(ra_rad) * cos(dec_rad),
			sin(ra_rad) * cos(dec_rad),
			sin(dec_rad)
		)


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
		var ra_rad = self.ra * PI / 180
		var dec_rad = self.dec * PI / 180

		return Vector3(
			cos(ra_rad) * cos(dec_rad),
			sin(ra_rad) * cos(dec_rad),
			sin(dec_rad)
		)

	## Return the inertial coordinates of the star in light years, relative to Earth.
	## Subtract these from your target exoplant coordinates to get the relative position.
	func get_inertial_coordinates_ly():
		var direction = get_unit_direction()

		# Conversion factor from https://en.wikipedia.org/wiki/Parsec
		var dist_ly = self.dist_pc * 3.261563777

		return direction * dist_ly

	# TODO adjust magnitude threshold here, probably should be 6.5 to be comprehensive, but adjustmenets are needed for population selection
	func make_query_step(min_radius_pc: float, max_radius_pc: float, min_magnitude_at_target: float = 4.0):
		var near_radius = self.dist_pc - max_radius_pc
		var far_radius = self.dist_pc + max_radius_pc

		# Law of cosines
		var r = max_radius_pc
		var d = self.dist_pc
		var o = sqrt(d ** 2 - r ** 2)
		var num = o ** 2 + d ** 2 - r ** 2
		var den = 2 * d * o
		var cos_half_theta = num / den
		var theta_deg = 2 * acos(cos_half_theta) * 180 / PI

		# Note, this will include many stars that are NOT visible from the target, we'll filter these out later
		# This is necessary because this appears to be a good-ish way to query the GAIA dataset, vs doing calculations in ADQL

		# 1. We need anything at least as bright as the dimmest star visible from the target in our search shell
		# How bright we'd have to be at the inner search disc/shell edge
		var min_absolute_magnititude_at_target = Math.apparent_to_abs_magnitude(min_magnitude_at_target, min_radius_pc)

		# How apparently bright we'd have to be rom Sol if we were at the farthest point of the search disc/shell, which is what the dataset has
		var min_apparent_magnitude_from_source = Math.abs_to_apparent_magnitude(min_absolute_magnititude_at_target, far_radius)

		# 2. We don't need anything brighter than any subsequent shells are going to find
		var max_absolute_magnititude_at_target = Math.apparent_to_abs_magnitude(min_magnitude_at_target, max_radius_pc)
		var max_apparent_magnitude_from_source = Math.abs_to_apparent_magnitude(max_absolute_magnititude_at_target, near_radius)

		# TODO figure out max apparent magnitude limit
		return ConeQuery.new(self.ra, self.dec, theta_deg, near_radius, far_radius, min_apparent_magnitude_from_source, max_apparent_magnitude_from_source)

	

class ConeQuery:
	var _target_ra: float
	var _target_dec: float
	var _theta_deg: float
	var _near_radius: float
	var _far_radius: float
	var _min_apparent_magnitude: float
	var _max_apparent_magnitude: float

	func _init(target_ra: float, target_dec: float, theta_deg: float, near_radius: float, far_radius: float, min_apparent_magnitude: float, max_apparent_magnitude: float):
		self._target_ra = target_ra
		self._target_dec = target_dec
		self._theta_deg = theta_deg
		self._near_radius = near_radius
		self._far_radius = far_radius
		self._min_apparent_magnitude = min_apparent_magnitude
		self._max_apparent_magnitude = max_apparent_magnitude

	func make_cone_query():
		return """
			select top 10000 ra, dec, phot_g_mean_mag, r_med_photogeo, teff_gspphot, source_id
			from gaiadr3.gaia_source
			left join external.gaiaedr3_distance using (source_id)
			where distance({target_ra}, {target_dec}, ra, dec) < {theta_deg}
			and distance_gspphot between {near_radius} and {far_radius}
			and phot_g_mean_mag between {max_apparent_magnitude} and {min_apparent_magnitude}
		""".format({
			"target_ra": self._target_ra,
			"target_dec": self._target_dec,
			"theta_deg": self._theta_deg,
			"near_radius": self._near_radius,
			"far_radius": self._far_radius,
			"min_apparent_magnitude": self._min_apparent_magnitude,
			"max_apparent_magnitude": self._max_apparent_magnitude,
		})
		
class StarData:
	var source_id: int
	var ra: float
	var dec: float
	var apparent_magnitude: float
	var dist_pc: float
	var temperature: float
	var origin: Vector3 = Vector3.ZERO

	func _init(_source_id: int, _ra: float, _dec: float, _apparent_magnitude: float, _dist_pc: float, _temperature: float):
		self.source_id = _source_id
		self.ra = _ra
		self.dec = _dec
		self.apparent_magnitude = _apparent_magnitude
		self.dist_pc = _dist_pc
		self.temperature = _temperature

	## Return the unit direction vector of the star
	func get_unit_direction_raw():
		var ra_rad = self.ra * PI / 180
		var dec_rad = self.dec * PI / 180

		return Vector3(
			cos(ra_rad) * cos(dec_rad),
			sin(ra_rad) * cos(dec_rad),
			sin(dec_rad)
		)

	func get_unit_direction():
		return get_inertial_coordinates_ly().normalized()

	## Return the inertial coordinates of the star in light years, relative to Earth.
	## Subtract your target exoplant coordinates from this to get the relative position.
	func get_inertial_coordinates_ly():
		var direction = get_unit_direction_raw()

		# Conversion factor from https://en.wikipedia.org/wiki/Parsec
		var dist_ly = self.dist_pc * 3.261563777

		return direction * dist_ly - origin

	## Return the luminosity of the star relative to Sol
	func get_relative_luminosity():
		
		# TODO
		# https://en.wikipedia.org/wiki/Sun
		const SOL_ABSOLUTE_MAGNITUDE = 4.83

		# https://en.wikipedia.org/wiki/Luminosity
		var absolute_magnitude = Math.apparent_to_abs_magnitude(self.apparent_magnitude, self.dist_pc)
		var relative_luminosity = 10 ** ((absolute_magnitude - SOL_ABSOLUTE_MAGNITUDE) / -2.5)
		#print("%fm %fM at %f pc is lumin ratio %f" % [self.apparent_magnitude, absolute_magnitude, self.dist_pc, relative_luminosity])
		return relative_luminosity
