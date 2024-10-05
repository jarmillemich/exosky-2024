extends Node3D

@export var shader: Shader

### A class that represents a individual star in StarManager
class Star:
	var position: Vector3
	#brightness of the star
	var luminosity:float

	var temperature:float 

	var name: String
	
	var description: String

	func _init(position: Vector3, luminosity: float, temperature: float, name: String, description: String):
		self.position = position
		self.luminosity = luminosity
		self.temperature = temperature
		self.name = name
		self.description = description



## Most stars have an "Effective temperature" which is the black body temperature that most closely
## matches their emitted spectra.
##
## This describes the color of the star as a single value, a temperature in Kelvin, from the range
## of ~500 through to 60,000 and beyond.
static func blackbody_to_rgb(kelvin):
	var temperature = kelvin / 100.0
	var red
	var green
	var blue

	if temperature < 66.0:
		red = 255
	else:
		# a + b x + c Log[x] /.
		# {a -> 351.97690566805693`,
		# b -> 0.114206453784165`,
		# c -> -40.25366309332127
		#x -> (kelvin/100) - 55}
		red = temperature - 55.0
		red = 351.97690566805693 + 0.114206453784165 * red - 40.25366309332127 * log(red)
		if red < 0:
			red = 0
		if red > 255:
			red = 255

	# Calculate green

	if temperature < 66.0:
		# a + b x + c Log[x] /.
		# {a -> -155.25485562709179`,
		# b -> -0.44596950469579133`,
		# c -> 104.49216199393888`,
		# x -> (kelvin/100) - 2}
		green = temperature - 2
		green = (
			-155.25485562709179
			- 0.44596950469579133 * green
			+ 104.49216199393888 * log(green)
		)
		if green < 0:
			green = 0
		if green > 255:
			green = 255

	else:
		# a + b x + c Log[x] /.
		# {a -> 325.4494125711974`,
		# b -> 0.07943456536662342`,
		# c -> -28.0852963507957`,
		# x -> (kelvin/100) - 50}
		green = temperature - 50.0
		green = 325.4494125711974 + 0.07943456536662342 * green - 28.0852963507957 * log(green)
		if green < 0:
			green = 0
		if green > 255:
			green = 255

	# Calculate blue

	if temperature >= 66.0:
		blue = 255
	else:
		if temperature <= 20.0:
			blue = 0
		else:
			# a + b x + c Log[x] /.
			# {a -> -254.76935184120902`,
			# b -> 0.8274096064007395`,
			# c -> 115.67994401066147`,
			# x -> kelvin/100 - 10}
			blue = temperature - 10
			blue = (
				-254.76935184120902
				+ 0.8274096064007395 * blue
				+ 115.67994401066147 * log(blue)
			)
			if blue < 0:
				blue = 0
			if blue > 255:
				blue = 255

	return Color(red / 255.0, green / 255.0, blue / 255.0)


var material: ShaderMaterial
var mesh: MultiMesh
# Hide these parameters because they're set by StarManager:
var internal_shader_params = {
	'camera_vertical_fov': true
}


# This forwards the shader parameters, which would otherwise be inaccessible because the Material
# is generated at runtime.
func _get_property_list():
	var props = []
	var shader_params := RenderingServer.get_shader_parameter_list(shader.get_rid())
	for p in shader_params:
		if internal_shader_params.has(p.name):
			continue
		var cp = {}
		for k in p:
			cp[k] = p[k]
		cp.name = str("shader_params/", p.name)
		props.append(cp)
	return props


func _get(p_key: StringName):
	var key = String(p_key)
	if key.begins_with("shader_params/"):
		var param_name = key.substr(len("shader_params/"))
		var value = material.get_shader_parameter(param_name)
		if value == null:
			value = RenderingServer.shader_get_parameter_default(material.shader, param_name)
		return value


func _set(p_key: StringName, value):
	var key = String(p_key)
	if key.begins_with("shader_params/"):
		var param_name := key.substr(len("shader_params/"))
		material.set_shader_parameter(param_name, value)


# In order to render the stars without polluting the .tscn file with MultiMesh buffer data, this
# technique is used of creating the instance and adding it as a child in _init(). This somehow
# doesn't actually add the child to the scene in the editor, even though the code is running as a
# tool script.
func _init():
	material = ShaderMaterial.new()
	material.shader = shader

	var quad = QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Z
	quad.size = Vector2(1, 1)
	quad.material = material

	mesh = MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_colors = true
	mesh.use_custom_data = true
	mesh.mesh = quad

	var inst = MultiMeshInstance3D.new()
	inst.multimesh = mesh

	add_child(inst)

	# Re-use the same shape
	#var shape = inst.multimesh.mesh.create_trimesh_shape()
	# Create one static body
	var collisionNode = StaticBody3D.new()
	inst.add_child(collisionNode)

	# for mesh_index in range(inst.multimesh.instance_count):
	# 	var positionT = Transform3D().translated(Vector3(mesh_index*2, 10+2, 0)).scaled(Vector3(1,1,1))
	# 	inst.multimesh.set_instance_transform(mesh_index, positionT)

	# 	# Create many collision shapes
	# 	var collisionShape = CollisionShape3D.new()
	# 	collisionShape.shape = shape
	# 	collisionShape.transform = positionT
	# 	collisionNode.add_child(collisionShape)




func set_stars(stars: Array[Star]):
	mesh.instance_count = 0
	mesh.instance_count = stars.size()
	print("Set stars")
	for i in range(stars.size()):
		#print(i)
		var star = stars[i]
		var transform = Transform3D().translated(star.position)
		mesh.set_instance_transform(i, transform)
		mesh.set_instance_color(i, blackbody_to_rgb(star.temperature))
		mesh.set_instance_custom_data(i, Color(star.luminosity, 0, 0))

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var camera = get_viewport().get_camera_3d()
	var fov = 70
	# The camera can be null if the scene doesn't have one set.
	# This value will also not match the editor camera.
	if camera:
		fov = camera.fov

	material.shader = shader
	material.set_shader_parameter('camera_vertical_fov', fov)