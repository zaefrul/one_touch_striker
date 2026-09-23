class_name ArenaShotReplay
extends RefCounted

const MAX_FRAMES: int = 128
const DURATION: float = 2.0
var recording: bool = false
var _frames: Array[Dictionary] = []
var _time: float = 0.0

func begin(ball: Vector3, rotation: Quaternion, keeper: Dictionary) -> void:
	clear()
	recording = true
	_frames.append({"time": 0.0, "ball": ball, "rotation": rotation, "keeper": keeper.duplicate(true), "net": 1.0})

func capture(delta: float, ball: Vector3, rotation: Quaternion, keeper: Dictionary, net: float = 1.0) -> void:
	if not recording:
		return
	_time += maxf(delta, 0.000001)
	if _frames.size() >= MAX_FRAMES:
		recording = false
		return
	_frames.append({"time": _time, "ball": ball, "rotation": rotation, "keeper": keeper.duplicate(true), "net": net})

func finish() -> bool:
	recording = false
	return _frames.size() >= 2 and _time > 0.0

func sample(progress: float) -> Dictionary:
	if _frames.is_empty():
		return {}
	var wanted: float = clampf(progress, 0.0, 1.0) * float(_frames.back()["time"])
	var index: int = 0
	while index + 1 < _frames.size() and float(_frames[index + 1]["time"]) < wanted:
		index += 1
	var a: Dictionary = _frames[index]
	var b: Dictionary = _frames[mini(index + 1, _frames.size() - 1)]
	var span: float = float(b["time"]) - float(a["time"])
	var weight: float = 0.0 if span <= 0.0 else clampf((wanted - float(a["time"])) / span, 0.0, 1.0)
	var at: Vector3 = a["ball"]
	var rotation: Quaternion = a["rotation"]
	return {"ball": at.lerp(b["ball"], weight), "rotation": rotation.slerp(b["rotation"], weight), "keeper_a": a["keeper"], "keeper_b": b["keeper"], "weight": weight, "net": lerpf(a["net"], b["net"], weight)}

func frame_count() -> int:
	return _frames.size()

func clear() -> void:
	recording = false
	_frames.clear()
	_time = 0.0
