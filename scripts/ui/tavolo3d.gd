extends SubViewportContainer
## Vista 3D del sistema stellare: la stella al centro, i pianeti sulle loro orbite, e attorno a ogni
## pianeta le piattaforme degli ambienti con le pedine originali in piedi (Ribelli davanti, Impero
## dietro). Trascina per ruotare, rotella per lo zoom, clic su una piattaforma per sceglierla.

signal luogo_cliccato(luogo: String)

const DifesaPlanetaria3D = preload("res://scripts/ui/difesa_planetaria3d.gd")

var m: Motore
var vista := -1
var evidenziati: Dictionary = {}
var _vp: SubViewport
var _root: Node3D
var _cam: Camera3D
var _yaw := 0.6
var _pitch := 1.0
var _dist := 66.0
var _target := Vector3.ZERO
var _trascina := false
var _pianeti := {}          # pid -> Node3D
var _difese := {}           # pid -> animated planetary defense
var _piattaforme := {}      # luogo -> {nodo, mat}
var _pedine_root: Node3D
var _tempo := 0.0
var _voli := []
var _mat_cache := {}
var _sis: Node3D
var stella_vista := -1


func stella() -> int:
	if m.livello == "sistema" or stella_vista < 0:
		return int(m.scenario.get("stella", stella_vista))
	return stella_vista


## Mostra un altro sistema stellare (Province e Galactic Game).
func imposta_stella(s: int) -> void:
	if s == stella_vista:
		return
	stella_vista = s
	if _root != null:
		_costruisci_sistema()
		aggiorna()


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.handle_input_locally = true
	_vp.physics_object_picking = true
	add_child(_vp)
	_root = Node3D.new()
	_vp.add_child(_root)
	_ambiente()
	_cam = Camera3D.new()
	_cam.fov = 48
	_root.add_child(_cam)
	_costruisci_sistema()
	_pedine_root = Node3D.new()
	_root.add_child(_pedine_root)
	_aggiorna_camera()
	aggiorna()


func _ambiente() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type sky;
float h(vec3 p){ return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
void sky(){
	vec3 d = EYEDIR;
	vec3 c = mix(vec3(0.005, 0.008, 0.025), vec3(0.03, 0.02, 0.07), 0.5 + 0.5 * d.y);
	c += vec3(0.18, 0.06, 0.04) * pow(max(0.0, dot(d, normalize(vec3(0.6, 0.2, -0.7)))), 6.0) * 0.6;
	c += vec3(0.04, 0.08, 0.22) * pow(max(0.0, dot(d, normalize(vec3(-0.7, -0.1, 0.5)))), 4.0) * 0.7;
	vec3 q = d * 300.0;
	vec3 g = floor(q);
	float st = step(0.996, h(g)) * smoothstep(0.32, 0.0, length(fract(q) - 0.5));
	c += vec3(0.85, 0.9, 1.0) * st * (0.6 + 0.4 * h(g + 1.0));
	COLOR = c;
}"""
	sm.shader = sh
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.5)
	env.ambient_light_energy = 0.55
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	_root.add_child(we)


func _mat(col: Color, emiss := 0.0, rough := 0.7) -> StandardMaterial3D:
	var k := "%s_%s_%s" % [col.to_html(), emiss, rough]
	if _mat_cache.has(k):
		return _mat_cache[k]
	var mt := StandardMaterial3D.new()
	mt.albedo_color = col
	mt.roughness = rough
	if emiss > 0.0:
		mt.emission_enabled = true
		mt.emission = col
		mt.emission_energy_multiplier = emiss
	_mat_cache[k] = mt
	return mt


func _costruisci_sistema() -> void:
	if _sis != null:
		_sis.queue_free()
	_sis = Node3D.new()
	_root.add_child(_sis)
	_pianeti.clear()
	_difese.clear()
	_piattaforme.clear()
	# stella
	var stella := MeshInstance3D.new()
	var sfera := SphereMesh.new()
	sfera.radius = 2.4
	sfera.height = 4.8
	stella.mesh = sfera
	stella.material_override = _mat(Color(1.0, 0.75, 0.25), 3.5)
	_sis.add_child(stella)
	var luce := OmniLight3D.new()
	luce.omni_range = 80
	luce.light_energy = 2.2
	luce.light_color = Color(1, 0.9, 0.75)
	_sis.add_child(luce)
	var dir := DirectionalLight3D.new()
	dir.light_energy = 0.35
	dir.rotation_degrees = Vector3(-50, 30, 0)
	_sis.add_child(dir)
	var nome_stella: String = Dati.d()["stelle"].get(stella(), {}).get("nome", "")
	var ls := _etichetta(nome_stella.to_upper(), 120, Color(0.75, 0.88, 1.0))
	ls.position = Vector3(0, 3.6, 0)
	_sis.add_child(ls)
	var pids := m.scenario_pianeti() if m.livello == "sistema" else m.scenario_pianeti().filter(func(x): return int(x / 10) == stella())
	for i in pids.size():
		var pid: int = pids[i]
		var dp := Dati.pianeta(pid)
		var anello := int(dp.get("anello", i + 1))
		var r := 7.0 + anello * 5.0
		_orbita(r)
		var ang := 0.9 + anello * 2.1
		var pos := Vector3(cos(ang) * r, 0, sin(ang) * r)
		var nodo := Node3D.new()
		nodo.position = pos
		_sis.add_child(nodo)
		_pianeti[pid] = nodo
		var pm := MeshInstance3D.new()
		var ps := SphereMesh.new()
		# Area proportional to environment size; orbital ring is not planet size.
		ps.radius = raggio_pianeta(dp)
		ps.height = ps.radius * 2
		pm.mesh = ps
		pm.material_override = _materiale_pianeta(dp)
		pm.name = "Globo"
		nodo.add_child(pm)
		var difesa := DifesaPlanetaria3D.new()
		difesa.rotation_degrees = Vector3(12, 0, 6)
		nodo.add_child(difesa)
		var stato_pianeta: Dictionary = m.pianeti.get(pid, {})
		difesa.configura(ps.radius, int(stato_pianeta.get("bdp", 0)), bool(stato_pianeta.get("su", true)))
		# The existing planet status label carries strength/DOWN; avoid overlap.
		difesa.mostra_etichetta(false)
		_difese[pid] = difesa
		var lp := _etichetta("%s %d" % [dp["nome"].to_upper(), pid], 90, Color(0.98, 0.86, 0.42))
		lp.position = Vector3(0, ps.radius + 2.2 + (2.6 if m.livello != "sistema" else 0.0), 0)
		if m.livello != "sistema":
			var orb := Node3D.new()
			orb.position = Vector3(0, ps.radius + 1.2, 0)
			nodo.add_child(orb)
			var anello_o := MeshInstance3D.new()
			var to := TorusMesh.new()
			to.inner_radius = 1.6
			to.outer_radius = 1.75
			anello_o.mesh = to
			var mo := _mat(Color(0.55, 0.65, 1.0), 0.8)
			anello_o.material_override = mo
			orb.add_child(anello_o)
			var lo := "%d:o" % pid
			var ao := Area3D.new()
			var co := CollisionShape3D.new()
			var so := CylinderShape3D.new()
			so.radius = 1.7
			so.height = 1.2
			co.shape = so
			ao.add_child(co)
			ao.input_event.connect(func(_c, ev, _p, _n, _i):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					luogo_cliccato.emit(lo))
			orb.add_child(ao)
			_piattaforme[lo] = {"nodo": orb, "mat": mo, "col": Color(0.55, 0.65, 1.0)}
		nodo.add_child(lp)
		var st := _etichetta("", 60, Color(0.8, 0.8, 0.9))
		st.name = "Stato"
		st.position = Vector3(0, ps.radius + 1.1, 0)
		nodo.add_child(st)
		# piattaforme degli ambienti
		var amb: Array = dp["ambienti"]
		for k in amb.size():
			var l := "%d:%d" % [pid, k]
			var a: float = (TAU / max(3, amb.size())) * k - PI * 0.5 - ang
			var off := Vector3(cos(a), 0, sin(a)) * (ps.radius + 3.4)
			var piat := Node3D.new()
			piat.position = off + Vector3(0, -0.9, 0)
			nodo.add_child(piat)
			var disco := MeshInstance3D.new()
			var cil := CylinderMesh.new()
			cil.top_radius = 2.2
			cil.bottom_radius = 2.3
			cil.height = 0.18
			disco.mesh = cil
			var col: Color = UI.COL_AMBIENTI.get(amb[k]["tipo"], Color.GRAY)
			var mt := StandardMaterial3D.new()
			mt.albedo_color = col.darkened(0.35)
			mt.emission_enabled = true
			mt.emission = col
			mt.emission_energy_multiplier = 0.35
			mt.metallic = 0.3
			mt.roughness = 0.4
			disco.material_override = mt
			piat.add_child(disco)
			var la := _etichetta("%s · %d" % [Dati.AMBIENTI_NOMI[amb[k]["tipo"]].to_upper(), int(amb[k]["taglia"])], 54, col.lightened(0.4))
			la.position = Vector3(0, 0.25, 2.5)
			la.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			piat.add_child(la)
			var area := Area3D.new()
			var cs := CollisionShape3D.new()
			var sh := CylinderShape3D.new()
			sh.radius = 1.8
			sh.height = 1.6
			cs.shape = sh
			cs.position = Vector3(0, 0.6, 0)
			area.add_child(cs)
			area.input_event.connect(func(_c, ev, _p, _n, _i):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					luogo_cliccato.emit(l))
			piat.add_child(area)
			_piattaforme[l] = {"nodo": piat, "mat": mt, "col": col}
			# collegamento al pianeta
			var trave := MeshInstance3D.new()
			var bm := CylinderMesh.new()
			bm.top_radius = 0.04
			bm.bottom_radius = 0.04
			bm.height = off.length() - ps.radius
			trave.mesh = bm
			trave.material_override = _mat(Color(0.6, 0.6, 0.7, 1), 0.3)
			trave.position = off * 0.5 * (1.0 + ps.radius / off.length()) + Vector3(0, -0.45, 0)
			trave.look_at_from_position(trave.position, off + Vector3(0, -0.9, 0), Vector3.UP)
			trave.rotate_object_local(Vector3.RIGHT, PI * 0.5)
			nodo.add_child(trave)


static func raggio_pianeta(dp: Dictionary) -> float:
	var superficie := 0.0
	for ambiente in dp.get("ambienti", []):
		superficie += float(ambiente.get("taglia", 0))
	# Adare (9) keeps radius 2.3; Kelta (2) and Solvia (12) set the range.
	return 2.3 * sqrt(maxf(superficie, 1.0) / 9.0)


func _materiale_pianeta(dp: Dictionary) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 128
	nt.seamless = true
	var n := FastNoiseLite.new()
	n.seed = int(dp["id"])
	n.frequency = 0.02
	n.fractal_octaves = 4
	nt.noise = n
	var gr := Gradient.new()
	var colori := []
	for a in dp["ambienti"]:
		colori.append(UI.COL_AMBIENTI.get(a["tipo"], Color.GRAY))
	if colori.size() == 1:
		colori.append(colori[0].darkened(0.4))
	gr.colors = PackedColorArray([colori[0].darkened(0.5), colori[0], colori[-1].lightened(0.15)])
	gr.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	nt.color_ramp = gr
	mt.albedo_texture = nt
	mt.roughness = 0.85
	return mt


func _orbita(r: float) -> void:
	var mi := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = r - 0.03
	tor.outer_radius = r + 0.03
	tor.rings = 128
	mi.mesh = tor
	mi.material_override = _mat(Color(0.85, 0.72, 0.25), 0.8)
	_sis.add_child(mi)


func _etichetta(t: String, px: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font = UI.font_titolo
	l.font_size = px
	l.pixel_size = 0.014
	l.modulate = col
	l.outline_size = 14
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	return l


# ------------------------------------------------------------------------------------
# Aggiornamento pedine
# ------------------------------------------------------------------------------------

func evidenzia(e: Dictionary) -> void:
	evidenziati = e


func aggiorna() -> void:
	if _pedine_root == null:
		return
	for c in _pedine_root.get_children():
		c.queue_free()
	for pid in _pianeti:
		var st: Label3D = _pianeti[pid].get_node("Stato")
		var ctrl := m.controllo(pid)
		var p: Dictionary = m.pianeti[pid]
		if _difese.has(pid):
			_difese[pid].aggiorna(int(p["bdp"]), bool(p["su"]))
		var testo: String = Dati.LEALTA_NOMI[p["lealta"]]
		match p["stato"]:
			"ribellione":
				testo = "IN RIBELLIONE"
			"ribelle":
				testo = "CONTROLLO RIBELLE"
			"fermata":
				testo = "Ribellione fermata"
		st.text = "%s · PDB %d%s" % [testo, int(p["bdp"]), "" if p["su"] else " · DOWN"]
		st.modulate = UI.colore_fazione(ctrl) if ctrl >= 0 else Color(0.75, 0.78, 0.85)
	for l in _piattaforme:
		var piat: Node3D = _piattaforme[l]["nodo"]
		var base: Vector3 = piat.global_position
		for f in [Motore.R, Motore.I]:
			var lista := []
			for id in m.unita:
				var u: Dictionary = m.unita[id]
				if u["luogo"] == l and u["fz"] == f:
					lista.append(id)
			var n := lista.size()
			for i in n:
				var id2: int = lista[i]
				var u2: Dictionary = m.unita[id2]
				var tx: Texture2D
				if u2["k"] == "pg":
					tx = UI.pedina_tex(str(u2["ped"]) if u2.has("ped") else UI.chiave_pg(u2["nome"]), u2["ind"])
				else:
					var nascosta: bool = u2["fz"] == Motore.I and u2["mobile"] and not u2["scoperta"] and vista == Motore.R
					tx = UI.pedina_tex(UI.chiave_mil(u2), nascosta)
				var sp := Sprite3D.new()
				sp.texture = tx
				sp.pixel_size = 0.9 / maxf(1.0, float(tx.get_width()) if tx != null else 64.0)
				sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
				sp.shaded = false
				sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
				var fila := 0.8 if f == Motore.R else -0.8
				var cols := mini(n, 4)
				var x := (float(i % 4) - (cols - 1) * 0.5) * 0.98
				var riga := int(i / 4)
				sp.position = base + Vector3(x, 0.6 + riga * 0.98, fila - riga * 0.05)
				if u2["k"] == "pg" and u2["prig"] >= 0:
					sp.modulate = Color(0.6, 0.6, 0.6)
				_pedine_root.add_child(sp)
				if u2["k"] == "pg" and not u2["nave"].is_empty():
					var sn := Sprite3D.new()
					var tn := UI.pedina_tex(UI.chiave_nave(u2["nave"]), u2["nave"].get("dmg", false))
					sn.texture = tn
					sn.pixel_size = 0.7 / maxf(1.0, float(tn.get_width()) if tn != null else 64.0)
					sn.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
					sn.shaded = false
					sn.position = sp.position + Vector3(0.2, 0.95, -0.05)
					_pedine_root.add_child(sn)


func anima_volo(da: String, a: String, f: int) -> void:
	if not _piattaforme.has(a):
		return
	var p0: Vector3 = _piattaforme[da]["nodo"].global_position if _piattaforme.has(da) else Vector3(-30, 8, -20)
	var p1: Vector3 = _piattaforme[a]["nodo"].global_position
	var nave := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.5, 0.9, 0.25)
	nave.mesh = pm
	nave.material_override = _mat(UI.colore_fazione(f), 2.5)
	_root.add_child(nave)
	_voli.append({"n": nave, "da": p0 + Vector3(0, 0.8, 0), "a": p1 + Vector3(0, 0.8, 0), "t": 0.0})


# ------------------------------------------------------------------------------------
# Camera e animazione
# ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_tempo += delta
	for pid in _pianeti:
		var g: Node3D = _pianeti[pid].get_node("Globo")
		g.rotate_y(delta * 0.15)
	for l in _piattaforme:
		var d: Dictionary = _piattaforme[l]
		var mt: StandardMaterial3D = d["mat"]
		if evidenziati.has(l):
			mt.emission = evidenziati[l]
			mt.emission_energy_multiplier = 1.4 + 0.8 * sin(_tempo * 5.0)
		else:
			mt.emission = d["col"]
			mt.emission_energy_multiplier = 0.35
	for v in _voli:
		v["t"] += delta / 1.4
		var t: float = minf(1.0, v["t"])
		var e := t * t * (3.0 - 2.0 * t)
		var mid: Vector3 = (v["da"] + v["a"]) * 0.5 + Vector3(0, 6, 0)
		var p: Vector3 = v["da"].lerp(mid, e).lerp(mid.lerp(v["a"], e), e)
		var n: Node3D = v["n"]
		if p.distance_to(n.position) > 0.001:
			n.look_at_from_position(n.position, p, Vector3.UP)
			n.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
		n.position = p
		if v["t"] >= 1.0:
			n.queue_free()
	_voli = _voli.filter(func(v): return v["t"] < 1.0)


func _aggiorna_camera() -> void:
	_pitch = clampf(_pitch, 0.12, 1.45)
	_dist = clampf(_dist, 10.0, 70.0)
	var off := Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw)) * _dist
	_cam.position = _target + off
	_cam.look_at(_target, Vector3.UP)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_RIGHT or ev.button_index == MOUSE_BUTTON_MIDDLE:
			_trascina = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			_trascina = ev.pressed and ev.shift_pressed
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			_dist *= 0.9
			_aggiorna_camera()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			_dist *= 1.1
			_aggiorna_camera()
	elif ev is InputEventMouseMotion and (_trascina or (ev.button_mask & MOUSE_BUTTON_MASK_LEFT and not _piattaforma_sotto())):
		_yaw -= ev.relative.x * 0.006
		_pitch += ev.relative.y * 0.005
		_aggiorna_camera()


func _piattaforma_sotto() -> bool:
	return false
