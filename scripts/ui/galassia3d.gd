extends SubViewportContainer
## Galassia in 3D: la mappa originale stesa come un tavolo da gioco, con le pedine in piedi sulle
## caselle (i personaggi a figura intera con la grafica Reborn), i segnalini di Lealtà, BDP e segreti
## posati sulle caselle giuste e le caselle della decisione in corso illuminate.
## Trascina con il tasto sinistro per spostare la mappa, con il destro per ruotarla, rotellina per lo zoom;
## clic su una casella per sceglierla, doppio clic per aprire il sistema.

signal stella_scelta(stella: int)
signal luogo_cliccato(luogo: String)

const S := 0.01   # unità 3D per pixel della mappa

var m: Motore
var vista := -1
var evidenziati: Dictionary = {}
var stella_corrente := -1
var _vp: SubViewport
var _root: Node3D
var _cam: Camera3D
var _pezzi: Node3D
var _luci: Node3D
var _yaw := 0.0
var _pitch := 0.95
var _dist := 18.0
var _target := Vector3.ZERO
var _sinistro := false
var _destro := false
var _mosso := false
var _caselle: Array = []
var _tempo := 0.0
var _mat_luci: Array = []
var _dim := Vector2(3874, 2844)


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	_root = Node3D.new()
	_vp.add_child(_root)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.75)
	env.ambient_light_energy = 0.35
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	_root.add_child(we)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-55, 30, 0)
	sole.light_energy = 0.75
	sole.shadow_enabled = true
	_root.add_child(sole)
	# la mappa
	var tex: Texture2D = load("res://assets/mappa/galassia.jpg")
	_dim = Vector2(tex.get_width(), tex.get_height())
	var piano := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = _dim * S
	piano.mesh = pm
	var mt := StandardMaterial3D.new()
	mt.albedo_texture = tex
	mt.albedo_color = Color(0.78, 0.78, 0.8)
	mt.roughness = 0.95
	mt.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	piano.material_override = mt
	_root.add_child(piano)
	# bordo del tavolo
	var bordo := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(_dim.x * S + 0.6, 0.3, _dim.y * S + 0.6)
	bordo.mesh = bm
	var mb := StandardMaterial3D.new()
	mb.albedo_color = Color(0.12, 0.08, 0.05)
	mb.roughness = 0.6
	bordo.material_override = mb
	bordo.position = Vector3(0, -0.16, 0)
	_root.add_child(bordo)
	_cam = Camera3D.new()
	_cam.fov = 40
	_cam.far = 300
	_root.add_child(_cam)
	_pezzi = Node3D.new()
	_root.add_child(_pezzi)
	_luci = Node3D.new()
	_root.add_child(_luci)
	_inquadra()
	aggiorna()


func _a_mondo(p: Vector2, h := 0.0) -> Vector3:
	return Vector3(p.x * S - _dim.x * S * 0.5, h, p.y * S - _dim.y * S * 0.5)


func _da_mondo(v: Vector3) -> Vector2:
	return Vector2((v.x + _dim.x * S * 0.5) / S, (v.z + _dim.y * S * 0.5) / S)


## Inquadra le stelle dello scenario (la provincia oppure tutta la galassia).
func _inquadra() -> void:
	var stelle := []
	for pid in m.scenario_pianeti():
		var st := int(pid / 10)
		if not stelle.has(st):
			stelle.append(st)
	var r := Rect2()
	for i in stelle.size():
		var sd: Dictionary = Dati.d()["stelle"][stelle[i]]
		var p := Vector2(float(sd["x"]), float(sd["y"]))
		r = Rect2(p, Vector2.ZERO) if i == 0 else r.expand(p)
	r = r.grow(330)
	_target = _a_mondo(r.get_center())
	_dist = clampf(maxf(r.size.x, r.size.y * 1.4) * S * 1.05, 6.0, 60.0)
	_aggiorna_camera()


func centra_stella(st: int) -> void:
	var sd: Dictionary = Dati.d()["stelle"].get(st, {})
	if sd.is_empty():
		return
	_target = _a_mondo(Vector2(float(sd["x"]), float(sd["y"])))
	_dist = 8.0
	_aggiorna_camera()


func _aggiorna_camera() -> void:
	_pitch = clampf(_pitch, 0.35, 1.5)
	_dist = clampf(_dist, 2.5, 60.0)
	var off := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	_cam.position = _target + off
	_cam.look_at(_target, Vector3.UP)


func evidenzia(e: Dictionary) -> void:
	evidenziati = e
	_disegna_luci()


func _disegna_luci() -> void:
	if _luci == null:
		return
	for c in _luci.get_children():
		c.queue_free()
	_mat_luci.clear()
	if _caselle.is_empty():
		_caselle = SegnaliniMappa.caselle(m)
	for b in _caselle:
		var ev = evidenziati.get(b["luogo"], null)
		if ev == null:
			continue
		var q := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(b["w"] + 8.0, b["h"] + 8.0) * S
		q.mesh = pm
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color(ev, 0.35)
		mt.emission_enabled = true
		mt.emission = ev
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		q.material_override = mt
		q.position = _a_mondo(b["c"], 0.012)
		q.rotation.y = -float(b["a"])
		_luci.add_child(q)
		_mat_luci.append(mt)


var _sporco := true
var _ultimo := -1.0


## Ricostruisce le pedine al massimo quattro volte al secondo.
func aggiorna() -> void:
	_sporco = true


func _ricostruisci() -> void:
	_sporco = false
	_ultimo = _tempo
	if _pezzi == null:
		return
	for c in _pezzi.get_children():
		c.queue_free()
	for e in SegnaliniMappa.segnalini(m, vista):
		var lato: float = float(e["lato"]) * S
		if e["tipo"] != "pedina":
			# segnalini posati sulla mappa
			var sp := Sprite3D.new()
			sp.texture = e["tex"]
			if sp.texture == null:
				continue
			sp.pixel_size = lato / float(sp.texture.get_width())
			sp.rotation_degrees = Vector3(-90, 0, 0)
			sp.position = _a_mondo(e["pos"], 0.02)
			sp.shaded = true
			_pezzi.add_child(sp)
			continue
		var u: Dictionary = m.unita[e["id"]]
		var fig: Texture2D = null
		if u["k"] == "pg" and not u.has("ped"):
			fig = UI.reborn_tex("figure/" + UI.chiave_pg(u["nome"]))
		elif u["k"] == "mil" and UI.reborn and not (u["fz"] == Motore.I and u["mobile"] and not u["scoperta"] and vista == Motore.R):
			var tf := UI.truppa_tex(u, false, true)
			if tf != null and tf != e["tex"]:
				fig = tf
		var tx: Texture2D = fig if fig != null else e["tex"]
		if tx == null:
			continue
		var alto := lato * (2.0 if fig != null else 1.0)
		var sp2 := Sprite3D.new()
		sp2.texture = tx
		sp2.pixel_size = alto / float(tx.get_height())
		sp2.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp2.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sp2.shaded = false
		sp2.position = _a_mondo(e["pos"], alto * 0.5 + 0.03)
		if u["k"] == "pg" and u["prig"] >= 0:
			sp2.modulate = Color(0.55, 0.55, 0.6)
		elif u["k"] == "pg" and u["ind"]:
			sp2.modulate = Color(1.0, 0.8, 0.75)
		_pezzi.add_child(sp2)
		# basetta
		var base := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = lato * 0.42
		cm.bottom_radius = lato * 0.46
		cm.height = 0.03
		base.mesh = cm
		var mb := StandardMaterial3D.new()
		mb.albedo_color = UI.colore_fazione(u["fz"]).darkened(0.35)
		base.material_override = mb
		base.position = _a_mondo(e["pos"], 0.015)
		_pezzi.add_child(base)
	_disegna_luci()


func _process(delta: float) -> void:
	_tempo += delta
	if _sporco and visible and _tempo - _ultimo > 0.25:
		_ricostruisci()
	for mt in _mat_luci:
		mt.emission_energy_multiplier = 0.8 + 0.6 * sin(_tempo * 5.0)


func _punto_mappa(pos: Vector2) -> Vector2:
	var o := _cam.project_ray_origin(pos)
	var d := _cam.project_ray_normal(pos)
	if absf(d.y) < 0.0001:
		return Vector2(-1, -1)
	var t := -o.y / d.y
	return _da_mondo(o + d * t)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if ev.pressed:
					_zoom_verso(ev.position, 0.88)
			MOUSE_BUTTON_WHEEL_DOWN:
				if ev.pressed:
					_zoom_verso(ev.position, 1.0 / 0.88)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_destro = ev.pressed
			MOUSE_BUTTON_LEFT:
				if ev.pressed:
					_sinistro = true
					_mosso = false
					if ev.double_click:
						_mosso = true
						var st := _stella_vicina(_punto_mappa(ev.position))
						if st > 0:
							stella_scelta.emit(st)
				else:
					_sinistro = false
					if not _mosso:
						var p := _punto_mappa(ev.position)
						for b in _caselle:
							if SegnaliniMappa.dentro(b, p):
								luogo_cliccato.emit(b["luogo"])
								return
	elif ev is InputEventMouseMotion:
		if _destro:
			_yaw -= ev.relative.x * 0.006
			_pitch += ev.relative.y * 0.005
			_aggiorna_camera()
		elif _sinistro and ev.relative.length() > 0.5:
			_mosso = true
			# spostamento sul piano del tavolo, alla velocità del mouse
			var a := _punto_mappa(ev.position - ev.relative)
			var b2 := _punto_mappa(ev.position)
			var d := (a - b2) * S
			_target += Vector3(d.x, 0, d.y)
			_aggiorna_camera()
		else:
			var p2 := _punto_mappa(ev.position)
			var info := ""
			for b in _caselle:
				if SegnaliniMappa.dentro(b, p2):
					info = m.nome_luogo(b["luogo"])
			tooltip_text = info
	elif ev is InputEventMagnifyGesture:
		_dist /= ev.factor
		_aggiorna_camera()
	elif ev is InputEventPanGesture:
		_target += Vector3(ev.delta.x, 0, ev.delta.y) * _dist * 0.02
		_aggiorna_camera()


func _zoom_verso(pos: Vector2, k: float) -> void:
	var p := _a_mondo(_punto_mappa(pos))
	_target = _target.lerp(p, 1.0 - k) if k < 1.0 else _target
	_dist *= k
	_aggiorna_camera()


func _stella_vicina(p: Vector2) -> int:
	var best := -1
	var bd := 400.0
	for sid in Dati.d()["stelle"]:
		var sd: Dictionary = Dati.d()["stelle"][sid]
		var d := p.distance_to(Vector2(float(sd["x"]), float(sd["y"])))
		if d < bd and m.scenario_pianeti().any(func(x): return int(x / 10) == sid):
			bd = d
			best = sid
	return best
