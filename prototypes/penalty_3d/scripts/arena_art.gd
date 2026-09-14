class_name PenaltyArenaArt
extends RefCounted

const Shot = preload("res://scripts/shot_math.gd")

static func material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.92
	if unshaded:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

static func box(parent: Node3D, at: Vector3, dimensions: Vector3, surface: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = surface
	instance.position = at
	parent.add_child(instance)
	return instance

static func sphere(parent: Node3D, radius: float, surface: Material) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = surface
	parent.add_child(instance)
	return instance

static func beam(parent: Node3D, a: Vector3, b: Vector3, radius: float, surface: Material, round_ends: bool = false) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 12
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = surface
	instance.position = (a + b) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	parent.add_child(instance)
	if round_ends:
		sphere(parent, radius, surface).position = a
		sphere(parent, radius, surface).position = b

static func ring(parent: Node3D, color: Color) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = 0.12
	mesh.outer_radius = 0.17
	mesh.rings = 24
	mesh.ring_segments = 8
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color, true)
	instance.rotation.x = PI * 0.5
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

static func build(root: Node3D) -> Dictionary:
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#071b2a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b9dcea")
	environment.ambient_light_energy = 0.70
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	root.add_child(world)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -25, 0)
	light.light_color = Color("#fff3d9")
	light.light_energy = 1.5
	# Simple contact discs give a stable grounding cue on all target renderers.
	light.shadow_enabled = false
	root.add_child(light)

	var grass_a: StandardMaterial3D = material(Color("#116747"))
	var grass_b: StandardMaterial3D = material(Color("#0d5c42"))
	var white: StandardMaterial3D = material(Color("#edf6db"))
	var dark: StandardMaterial3D = material(Color("#142d3e"))
	var lime: StandardMaterial3D = material(Color("#d9ff6a"), true)
	for stripe in range(12):
		box(root, Vector3(0, -0.06, -4.5 + stripe * 2.0), Vector3(19, 0.1, 2.0), grass_a if stripe % 2 == 0 else grass_b)
	# Goal line, six-yard box and penalty-area boundaries.
	for x in [-8.0, 8.0]:
		box(root, Vector3(x, 0.005, 8), Vector3(0.045, 0.01, 17), white)
	box(root, Vector3(0, 0.008, 0), Vector3(16, 0.012, 0.045), white)
	for x in [-5.5, 5.5]:
		box(root, Vector3(x, 0.008, 2.75), Vector3(0.045, 0.012, 5.5), white)
	box(root, Vector3(0, 0.008, 5.5), Vector3(11, 0.012, 0.045), white)
	box(root, Vector3(0, 0.008, 11), Vector3(0.18, 0.014, 0.18), white)
	for side in [-1.0, 1.0]:
		box(root, Vector3(side * 9.5, 0.6, 3), Vector3(0.4, 1.2, 20), dark)
		box(root, Vector3(side * 9.27, 0.7, 3), Vector3(0.03, 0.08, 20), lime)
	for row in range(4):
		box(root, Vector3(0, row * 0.50 + 0.25, -4.0 - row * 0.90), Vector3(21, 0.5, 0.85), dark)
	_build_crowd(root)

	var goal: Node3D = Node3D.new()
	root.add_child(goal)
	beam(goal, Vector3(-Shot.HALF_GOAL, 0, 0), Vector3(-Shot.HALF_GOAL, Shot.GOAL_HEIGHT, 0), Shot.POST_RADIUS, white, true)
	beam(goal, Vector3(Shot.HALF_GOAL, 0, 0), Vector3(Shot.HALF_GOAL, Shot.GOAL_HEIGHT, 0), Shot.POST_RADIUS, white, true)
	beam(goal, Vector3(-Shot.HALF_GOAL, Shot.GOAL_HEIGHT, 0), Vector3(Shot.HALF_GOAL, Shot.GOAL_HEIGHT, 0), Shot.POST_RADIUS, white, true)
	var net_root: Node3D = Node3D.new()
	goal.add_child(net_root)
	_build_net(net_root)

	var title: Label3D = Label3D.new()
	title.text = "ONE-TOUCH  /  ARENA"
	title.font_size = 64
	title.pixel_size = 0.008
	title.position = Vector3(0, 3.4, -6)
	title.modulate = Color("#d9ff6a")
	root.add_child(title)

	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0, 3.05, 15.0)
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 42.0
	camera.near = 0.10
	camera.far = 60.0
	root.add_child(camera)
	camera.look_at(Vector3(0, 0.8, 4.0))
	camera.current = true

	var ball_material: ShaderMaterial = ShaderMaterial.new()
	ball_material.shader = preload("res://shaders/ball.gdshader")
	var ball: MeshInstance3D = sphere(root, Shot.BALL_RADIUS, ball_material)
	ball.position = Shot.START
	var shadow_mesh: CylinderMesh = CylinderMesh.new()
	shadow_mesh.top_radius = 0.18
	shadow_mesh.bottom_radius = 0.18
	shadow_mesh.height = 0.006
	shadow_mesh.radial_segments = 24
	var shadow: MeshInstance3D = MeshInstance3D.new()
	shadow.mesh = shadow_mesh
	shadow.material_override = material(Color("#0a402f"), true)
	root.add_child(shadow)
	var aim_ring: MeshInstance3D = ring(root, Color("#d9ff6a"))
	var dots: Array[MeshInstance3D] = []
	var dot_material: StandardMaterial3D = material(Color("#bbdfb4"), true)
	for _i in range(14):
		var dot: MeshInstance3D = sphere(root, 0.022, dot_material)
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dots.append(dot)
	return {"camera": camera, "ball": ball, "shadow": shadow, "net": net_root, "aim_ring": aim_ring, "dots": dots}

static func _build_crowd(root: Node3D) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.13
	mesh.height = 0.32
	mesh.radial_segments = 6
	mesh.rings = 3
	var surface: StandardMaterial3D = material(Color.WHITE)
	surface.vertex_color_use_as_albedo = true
	mesh.material = surface
	var crowd: MultiMesh = MultiMesh.new()
	crowd.transform_format = MultiMesh.TRANSFORM_3D
	crowd.use_colors = true
	crowd.mesh = mesh
	crowd.instance_count = 160
	var palette: Array[Color] = [Color("#e9d3a3"), Color("#ef9267"), Color("#82bfd1"), Color("#d9ff6a")]
	for i in range(160):
		var row: int = int(i / 40)
		var column: int = i % 40
		var at: Vector3 = Vector3(-9.5 + column * 0.48, 0.78 + row * 0.50, -4.0 - row * 0.90)
		crowd.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
		crowd.set_instance_color(i, palette[i % palette.size()])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.multimesh = crowd
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)

static func _build_net(root: Node3D) -> void:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var w: float = Shot.HALF_GOAL
	var h: float = Shot.GOAL_HEIGHT
	for i in range(33):
		var x: float = lerpf(-w, w, i / 32.0)
		mesh.surface_add_vertex(Vector3(x, 0, -1.6))
		mesh.surface_add_vertex(Vector3(x, h, -1.6))
		mesh.surface_add_vertex(Vector3(x, h, -1.6))
		mesh.surface_add_vertex(Vector3(x, h, 0))
	for i in range(12):
		var y: float = lerpf(0.0, h, i / 11.0)
		mesh.surface_add_vertex(Vector3(-w, y, -1.6))
		mesh.surface_add_vertex(Vector3(w, y, -1.6))
		for side in [-1.0, 1.0]:
			mesh.surface_add_vertex(Vector3(side * w, y, -1.6))
			mesh.surface_add_vertex(Vector3(side * w, y, 0))
	for i in range(8):
		var z: float = lerpf(-1.6, 0.0, i / 7.0)
		for side in [-1.0, 1.0]:
			mesh.surface_add_vertex(Vector3(side * w, 0, z))
			mesh.surface_add_vertex(Vector3(side * w, h, z))
	mesh.surface_end()
	var net: MeshInstance3D = MeshInstance3D.new()
	net.mesh = mesh
	net.material_override = material(Color("#658d8c"), true)
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(net)
