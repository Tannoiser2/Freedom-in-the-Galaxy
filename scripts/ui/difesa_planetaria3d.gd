extends Node3D
## PDB presentation only. Strength and UP/DOWN come from the game engine.

var livello := -1
var operativa := true
var angolo := 0.0
var colore_stato := Color(0.15, 0.95, 0.4)
var _raggio := 1.0
var _basi: Node3D
var _stato: StandardMaterial3D
var _label: Label3D


static func numero_basi(forza: int) -> int:
	return clampi(forza, 0, 2) + 1


func configura(raggio_pianeta: float, forza: int, su: bool) -> void:
	_raggio = raggio_pianeta + 0.65
	_stato = StandardMaterial3D.new()
	_stato.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = _raggio - 0.025
	mesh.outer_radius = _raggio + 0.025
	ring.mesh = mesh
	ring.material_override = _stato
	add_child(ring)
	_basi = Node3D.new()
	add_child(_basi)
	_label = Label3D.new()
	_label.font = preload("res://assets/font/SairaCondensed-Bold.ttf")
	_label.font_size = 48
	_label.pixel_size = 0.009
	_label.position = Vector3(0, _raggio + 0.4, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 10
	add_child(_label)
	aggiorna(forza, su)


func aggiorna(forza: int, su: bool) -> void:
	if _basi == null:
		return
	forza = clampi(forza, 0, 2)
	if forza != livello:
		livello = forza
		for child in _basi.get_children():
			_basi.remove_child(child)
			child.queue_free()
		for i in numero_basi(livello):
			var base := _base()
			var a := TAU * i / numero_basi(livello)
			base.position = Vector3(cos(a) * _raggio, 0, sin(a) * _raggio)
			_basi.add_child(base)
	operativa = su
	colore_stato = Color(0.15, 0.95, 0.4) if su else Color(1.0, 0.12, 0.1)
	_stato.albedo_color = colore_stato
	_label.modulate = colore_stato
	_label.text = "PDB · FORZA %d · %s" % [livello, "OPERATIVA" if su else "DOWN"]


func mostra_etichetta(mostra: bool) -> void:
	if _label != null:
		_label.visible = mostra


func _base() -> Node3D:
	var base := Node3D.new()
	var hull := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.24, 0.2, 0.22)
	hull.mesh = box
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.65, 0.7, 0.73)
	metal.metallic = 0.65
	hull.material_override = metal
	base.add_child(hull)
	for side in [-1, 1]:
		var panel := MeshInstance3D.new()
		var wing := BoxMesh.new()
		wing.size = Vector3(0.24, 0.045, 0.19)
		panel.mesh = wing
		panel.position.x = side * 0.25
		panel.material_override = _stato
		base.add_child(panel)
	var mast := MeshInstance3D.new()
	var antenna := CylinderMesh.new()
	antenna.top_radius = 0.015
	antenna.bottom_radius = 0.025
	antenna.height = 0.22
	mast.mesh = antenna
	mast.position.y = 0.17
	mast.material_override = _stato
	base.add_child(mast)
	return base


func _process(delta: float) -> void:
	if operativa and _basi != null:
		angolo = fmod(angolo + delta * 0.22, TAU)
		_basi.rotation.y = angolo
