extends Control
## Vista della galassia per il Province Game e il Galactic Game: la mappa originale con le stelle,
## lo stato dei pianeti (anello colorato per chi li controlla), le truppe e i personaggi di ogni
## sistema e i luoghi coinvolti nella decisione in corso. Clic su una stella = apre il suo sistema.
## Rotellina = zoom, trascinamento = spostamento.

signal stella_scelta(stella: int)

var m: Motore
var vista := -1
var evidenziati: Dictionary = {}
var stella_corrente := -1
var _tex: Texture2D
var _zoom := 1.0
var _offset := Vector2.ZERO
var _trascina := false
var _mosso := false
var _tempo := 0.0
var _hover := -1
var _pronta := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tex = load("res://assets/mappa/galassia.jpg")
	resized.connect(_adatta)


func _process(delta: float) -> void:
	_tempo += delta
	if visible:
		queue_redraw()


func evidenzia(e: Dictionary) -> void:
	evidenziati = e
	queue_redraw()


func _adatta() -> void:
	if _tex == null or size.x <= 0:
		return
	var ts := _tex.get_size()
	var stelle := _stelle_scenario()
	if m != null and m.livello == "provincia" and not stelle.is_empty():
		# inquadra la provincia
		var r := Rect2(_pos_img(stelle[0]), Vector2.ZERO)
		for s in stelle:
			r = r.expand(_pos_img(s))
		r = r.grow(260)
		_zoom = minf(size.x / r.size.x, size.y / r.size.y)
		_offset = size * 0.5 - r.get_center() * _zoom
	else:
		_zoom = minf(size.x / ts.x, size.y / ts.y)
		_offset = (size - ts * _zoom) * 0.5
	_pronta = true


func _stelle_scenario() -> Array:
	var out := []
	if m == null:
		return out
	for pid in m.scenario_pianeti():
		var s := int(pid / 10)
		if not out.has(s):
			out.append(s)
	return out


func _pos_img(stella: int) -> Vector2:
	var s: Dictionary = Dati.d()["stelle"].get(stella, {})
	return Vector2(float(s.get("x", 0)), float(s.get("y", 0)))


func _a_schermo(p: Vector2) -> Vector2:
	return _offset + p * _zoom


func _draw() -> void:
	if m == null or _tex == null:
		return
	if not _pronta:
		_adatta()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.03))
	draw_texture_rect(_tex, Rect2(_offset, _tex.get_size() * _zoom), false, Color(0.55, 0.58, 0.7))
	var scen := _stelle_scenario()
	var evid_stelle := {}
	for l in evidenziati:
		var s := m.av.stella_di(str(l))
		if s > 0:
			evid_stelle[s] = true
	var rr := maxf(16.0, 70.0 * _zoom)
	for sid in Dati.d()["stelle"]:
		var stella: int = sid
		var c := _a_schermo(_pos_img(stella))
		var attiva := scen.has(stella)
		if not attiva:
			draw_circle(c, rr * 0.5, Color(0, 0, 0, 0.55))
			continue
		if evid_stelle.has(stella):
			draw_circle(c, rr * 1.35 + 4 * sin(_tempo * 5), Color(0.4, 1, 0.5, 0.3))
		if stella == stella_corrente:
			draw_arc(c, rr * 1.2, 0, TAU, 48, UI.GIALLO, 3.0, true)
		if stella == _hover:
			draw_arc(c, rr * 1.28, 0, TAU, 48, Color.WHITE, 2.0, true)
		draw_circle(c, rr * 0.42, Color(1.0, 0.75, 0.3))
		draw_circle(c, rr * 0.28, Color(1.0, 0.95, 0.7))
		# pianeti del sistema in cerchio, colorati per stato
		var pids := m.scenario_pianeti().filter(func(x): return int(x / 10) == stella)
		for i in pids.size():
			var pid: int = pids[i]
			var ang := -PI * 0.5 + TAU * i / maxf(1, pids.size())
			var pp := c + Vector2(cos(ang), sin(ang)) * rr * 0.9
			var p: Dictionary = m.pianeti[pid]
			var col := Color(0.55, 0.6, 0.75)
			match p["stato"]:
				"ribelle":
					col = UI.COL_RIBELLI
				"ribellione":
					col = Color(1, 0.35, 0.2)
				"imperiale":
					col = Color(0.35, 0.45, 0.85).lerp(Color(0.95, 0.6, 0.2), p["lealta"] / 4.0)
			draw_circle(pp, rr * 0.22, col)
			var ctrl := m.controllo(pid)
			if ctrl >= 0:
				draw_arc(pp, rr * 0.26, 0, TAU, 20, UI.colore_fazione(ctrl), 2.0, true)
		# conteggio pedine nel sistema
		var nr := 0
		var ni := 0
		for id in m.unita:
			var u: Dictionary = m.unita[id]
			if u["luogo"] == "" or u["luogo"] == "morto":
				continue
			if m.av.stella_di(u["luogo"]) == stella:
				if u["fz"] == Motore.R:
					nr += 1
				else:
					ni += 1
		var fs := int(clampf(15 * maxf(1.0, _zoom * 2.4), 13, 22))
		var nome: String = str(Dati.d()["stelle"][stella].get("nome", ""))
		_testo(UI.font_titolo, c + Vector2(-rr, rr * 1.4 + fs), "%s %d" % [nome.to_upper(), stella], fs, Color(0.9, 0.85, 0.55))
		if nr > 0:
			draw_circle(c + Vector2(-rr * 1.1, -rr * 0.9), 11, UI.COL_RIBELLI)
			_testo_c(c + Vector2(-rr * 1.1, -rr * 0.9 + 6), str(nr), Color.WHITE)
		if ni > 0:
			draw_circle(c + Vector2(rr * 1.1, -rr * 0.9), 11, UI.COL_IMPERO)
			_testo_c(c + Vector2(rr * 1.1, -rr * 0.9 + 6), str(ni), Color(0.15, 0.1, 0))
	# legenda
	var y := 28.0
	_testo(UI.font_titolo, Vector2(16, y), "LA GALASSIA" if m.livello == "galassia" else "LA PROVINCIA", 26, UI.GIALLO)
	_testo(UI.font_testo, Vector2(16, y + 24), "Clic su una stella per aprire il sistema · rotellina per lo zoom · trascina per spostare", 15, UI.GRIGIO)
	if m.livello == "galassia":
		var g := m.galattico
		var righe := ["Risorse ribelli: %d PF · Risorse imperiali: %d PF" % [int(m.pf[Motore.R]), int(m.pf[Motore.I])]]
		if not g.strategico.is_empty():
			righe.append("Incarico strategico: %s" % g.strategico["it"])
		if not g.evento_corrente.is_empty():
			righe.append("Evento galattico: %s" % g.evento_corrente["titolo_it"])
		if g.base_svelata:
			righe.append("Base ribelle svelata: %s" % Dati.pianeta(g.base)["nome"])
		elif vista != Motore.I:
			righe.append("Base ribelle segreta: %s" % Dati.pianeta(g.base)["nome"] if g.base > 0 else "")
		righe.append("Prossima provincia tassata: %d" % g.provincia_tassata() if g.provincia_tassata() > 0 else "Nessuna tassa in questo turno")
		for i in righe.size():
			_testo(UI.font_testo, Vector2(16, y + 50 + i * 20), righe[i], 15, UI.TESTO)


func _testo(f: Font, p: Vector2, t: String, s: int, c: Color) -> void:
	draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, 4, Color(0, 0, 0, 0.8))
	draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, c)


func _testo_c(p: Vector2, t: String, c: Color) -> void:
	var w := UI.font_grassetto.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(UI.font_grassetto, p - Vector2(w / 2, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c)


func _stella_a(p: Vector2) -> int:
	var rr := maxf(16.0, 70.0 * _zoom)
	var best := -1
	var bd := rr * 1.5
	for s in _stelle_scenario():
		var d := _a_schermo(_pos_img(s)).distance_to(p)
		if d < bd:
			bd = d
			best = s
	return best


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var k := 1.15 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
			var nz := clampf(_zoom * k, 0.12, 2.5)
			_offset = ev.position - (ev.position - _offset) * (nz / _zoom)
			_zoom = nz
			queue_redraw()
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_trascina = true
				_mosso = false
			else:
				_trascina = false
				if not _mosso:
					var s := _stella_a(ev.position)
					if s > 0:
						stella_scelta.emit(s)
	elif ev is InputEventMouseMotion:
		if _trascina and ev.relative.length() > 0.5:
			_offset += ev.relative
			_mosso = true
		var h := _stella_a(ev.position)
		if h != _hover:
			_hover = h
			tooltip_text = _descrivi(h) if h > 0 else ""
	elif ev is InputEventMagnifyGesture:
		_zoom = clampf(_zoom * ev.factor, 0.12, 2.5)


func _descrivi(stella: int) -> String:
	var righe := ["%s (%d)" % [Dati.d()["stelle"][stella].get("nome", ""), stella]]
	for pid in m.scenario_pianeti():
		if int(pid / 10) != stella:
			continue
		var p: Dictionary = m.pianeti[pid]
		var st: String = Dati.LEALTA_NOMI[p["lealta"]]
		if p["stato"] == "ribellione":
			st = "in ribellione"
		elif p["stato"] == "ribelle":
			st = "controllo ribelle"
		righe.append("%s: %s, BDP %d%s" % [Dati.pianeta(pid)["nome"], st, int(p["bdp"]), "" if p["su"] else " fuori uso"])
	return "\n".join(righe)
