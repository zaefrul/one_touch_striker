class_name CaptainArt
extends Node3D

## Authored articulated character details. All roots follow the keeper's posed
## capsule endpoints; replay uses those same recorded poses. No imported model.
const Art = preload("res://scripts/arena_art.gd")
var _head: Node3D
var _chest: Node3D
var _hands: Array[Node3D] = []
var _boots: Array[Node3D] = []
var _arm_bands: Array[MeshInstance3D] = []
var _eyes: Array[MeshInstance3D] = []

func build() -> void:
	var gold: StandardMaterial3D = Art.material(Color("#ffcd68"))
	var dark: StandardMaterial3D = Art.material(Color("#0a1226"))
	var white: StandardMaterial3D = Art.material(Color("#f4f1e8"))
	var hair: StandardMaterial3D = Art.material(Color("#192130"))
	var skin: StandardMaterial3D = Art.material(Color("#c98b63"))
	_head = Node3D.new()
	add_child(_head)
	var cap: MeshInstance3D = Art.sphere(_head, 0.17, hair)
	cap.scale = Vector3(0.95, 0.50, 0.94)
	cap.position = Vector3(0.0, 0.09, -0.015)
	for side in [-1.0, 1.0]:
		var eye: MeshInstance3D = Art.sphere(_head, 0.022, white)
		eye.position = Vector3(side * 0.062, 0.015, 0.132)
		eye.scale = Vector3(1.0, 0.62, 0.50)
		_eyes.append(eye)
		var pupil: MeshInstance3D = Art.sphere(_head, 0.009, dark)
		pupil.position = Vector3(side * 0.059, 0.016, 0.148)
		Art.beam(_head, Vector3(side * 0.025, 0.047, 0.133), Vector3(side * 0.092, 0.057, 0.112), 0.012, hair)
		Art.beam(_head, Vector3(side * 0.065, -0.092, 0.108), Vector3(side * 0.024, -0.11, 0.115), 0.018, hair)
	var nose: MeshInstance3D = Art.sphere(_head, 0.026, skin)
	nose.position = Vector3(0.0, -0.022, 0.14)
	Art.beam(_head, Vector3(-0.035, -0.067, 0.137), Vector3(0.035, -0.067, 0.137), 0.009, hair)
	_chest = Node3D.new()
	add_child(_chest)
	# Number, crest, piping and collar provide a readable kit at phone size.
	var number: Label3D = Label3D.new()
	number.text = "1"
	number.font_size = 72
	number.pixel_size = 0.0035
	number.modulate = Color("#f4f1e8")
	number.position = Vector3(0.055, -0.015, 0.252)
	_chest.add_child(number)
	var crest: MeshInstance3D = Art.box(_chest, Vector3(-0.10, 0.09, 0.235), Vector3(0.065, 0.065, 0.012), gold)
	crest.rotation.z = PI * 0.25
	for side in [-1.0, 1.0]:
		Art.beam(_chest, Vector3(side * 0.19, -0.17, 0.14), Vector3(side * 0.19, 0.18, 0.14), 0.016, gold)
		Art.beam(_chest, Vector3(0, 0.27, 0.12), Vector3(side * 0.115, 0.34, 0.09), 0.018, white)
	for side in [-1.0, 1.0]:
		var hand: Node3D = Node3D.new()
		add_child(hand)
		_hands.append(hand)
		Art.box(hand, Vector3(0, -0.015, 0), Vector3(0.18, 0.14, 0.10), gold)
		Art.box(hand, Vector3(0, -0.079, 0), Vector3(0.16, 0.035, 0.10), dark)
		for finger in range(4):
			var x: float = -0.063 + float(finger) * 0.042
			Art.beam(hand, Vector3(x, 0.025, 0.018), Vector3(x, 0.11 - absf(x) * 0.3, 0.035), 0.021, gold, true)
		Art.beam(hand, Vector3(side * 0.075, -0.02, 0.02), Vector3(side * 0.115, 0.04, 0.03), 0.026, gold, true)
		Art.beam(hand, Vector3(-0.055, 0.0, 0.057), Vector3(0.055, 0.0, 0.057), 0.012, white)
		var boot: Node3D = Node3D.new()
		add_child(boot)
		_boots.append(boot)
		for lace in range(3):
			var z: float = 0.035 + float(lace) * 0.035
			Art.beam(boot, Vector3(-0.05, 0.095, z), Vector3(0.05, 0.095, z), 0.008, white)
		var band: MeshInstance3D = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.117
		mesh.bottom_radius = 0.117
		mesh.height = 0.065
		mesh.radial_segments = 12
		band.mesh = mesh
		band.material_override = gold
		add_child(band)
		_arm_bands.append(band)

func sync_pose(capsules: Array[Dictionary], pitch: float, lean: float, extension: float) -> void:
	if not visible or capsules.size() < 14:
		return
	var facing: Basis = Basis(Vector3.BACK, lean) * Basis(Vector3.RIGHT, pitch)
	_head.position = capsules[1]["a"]
	_head.basis = facing
	_chest.position = (capsules[0]["a"] + capsules[0]["b"]) * 0.5
	_chest.basis = facing
	for eye in _eyes:
		eye.scale.y = lerpf(0.62, 0.38, extension)
	for i in range(2):
		var hand_index: int = 4 + i * 3
		_hands[i].position = capsules[hand_index]["a"] + facing * Vector3(0, 0, 0.065)
		_hands[i].basis = facing
		# Keep the gold glove's visible core: it is also the contact sphere.
		_boots[i].position = capsules[10 + i * 3]["a"]
		_boots[i].basis = facing
		var arm: Dictionary = capsules[2 + i * 3]
		var axis: Vector3 = arm["b"] - arm["a"]
		_arm_bands[i].position = (arm["a"] + arm["b"]) * 0.5
		if axis.length_squared() > 0.00001:
			_arm_bands[i].quaternion = Quaternion(Vector3.UP, axis.normalized())
