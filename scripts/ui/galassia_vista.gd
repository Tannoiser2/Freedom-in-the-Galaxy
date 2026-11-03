extends Control
## Vista della galassia per il Province Game e il Galactic Game: la mappa originale con le pedine sulle
## sue caselle, come sul tavolo: Lealtà sulla traccia politica, BDP e truppe in orbita nella casella
## d'Orbita, personaggi e truppe sulle caselle degli ambienti, derive sulle caselle di Deriva.
## Clic su una casella = la sceglie (se la decisione in corso la prevede), altrimenti apre il sistema.
## Rotellina = zoom, trascinamento = spostamento.

signal stella_scelta(stella: int)
signal luogo_cliccato(luogo: String)

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
var _rect_pedine := []     # [Rect2, segnalino]
var _caselle: Array = []
var _hover_luogo := ""


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
	_rect_pedine.clear()
	var rr := maxf(16.0, 70.0 * _zoom)
	for sid in Dati.d()["stelle"]:
		if not scen.has(sid):
			draw_circle(_a_schermo(_pos_img(sid)), rr * 0.5, Color(0, 0, 0, 0.55))
	if _caselle.is_empty():
		_caselle = SegnaliniMappa.caselle(m)
	# caselle della decisione in corso
	for b in _caselle:
		var ev = evidenziati.get(b["luogo"], null)
		if ev == null and b["luogo"] != _hover_luogo:
			continue
		var pts := SegnaliniMappa.contorno(b, 3.0)
		for i in pts.size():
			pts[i] = _a_schermo(pts[i])
		if ev != null:
			var colp: Color = ev
			draw_colored_polygon(pts, Color(colp, 0.18 + 0.12 * sin(_tempo * 5.0)))
			draw_polyline(pts, colp, maxf(2.0, 5.0 * _zoom), true)
		else:
			draw_polyline(pts, Color.WHITE, 2.0, true)
	# stella del sistema aperto
	if stella_corrente > 0 and scen.has(stella_corrente):
		draw_arc(_a_schermo(_pos_img(stella_corrente)), 60.0 * _zoom, 0, TAU, 40, UI.GIALLO, 3.0, true)
	# pedine e segnalini
	for e in SegnaliniMappa.segnalini(m, vista):
		var lato: float = e["lato"] * _zoom
		var c := _a_schermo(e["pos"])
		var r := Rect2(c - Vector2(lato, lato) * 0.5, Vector2(lato, lato))
		draw_rect(Rect2(r.position + Vector2(1.5, 2), r.size), Color(0, 0, 0, 0.55))
		if e["tex"] != null:
			draw_texture_rect(e["tex"], r, false)
		else:
			draw_rect(r, Color(0.5, 0.5, 0.5))
		if e["tipo"] == "pedina":
			var u: Dictionary = m.unita[e["id"]]
			if u["k"] == "pg" and u["prig"] >= 0:
				draw_line(r.position, r.end, Color(0, 0, 0, 0.9), maxf(1.0, 3.0 * _zoom))
			if u["k"] == "pg" and int(u["ferite"]) > 0 and lato > 18:
				draw_circle(r.position + Vector2(r.size.x * 0.88, r.size.y * 0.12), lato * 0.18, Color(0.75, 0.05, 0.05))
		elif e["tipo"] == "bdp" and lato > 16:
			var lv := str(int(m.pianeti[e["id"]]["bdp"]))
			draw_circle(r.end - Vector2(lato * 0.16, lato * 0.16), lato * 0.2, Color(0.05, 0.08, 0.2))
			draw_string(UI.font_titolo, r.end - Vector2(lato * 0.26, lato * 0.04), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, int(lato * 0.34), Color.WHITE)
		_rect_pedine.append([r, e])
	# legenda
	var y := 28.0
	_testo(UI.font_titolo, Vector2(16, y), "LA GALASSIA" if m.livello == "galassia" else "LA PROVINCIA", 26, UI.GIALLO)
	_testo(UI.font_testo, Vector2(16, y + 24), "Clic su una casella o una stella · doppio clic apre il sistema · rotellina per lo zoom · trascina per spostare", 15, UI.GRIGIO)
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


func _luogo_a(p: Vector2) -> String:
	var q := (p - _offset) / _zoom
	for b in _caselle:
		if SegnaliniMappa.dentro(b, q):
			return b["luogo"]
	return ""


func _stella_a(p: Vector2) -> int:
	var l := _luogo_a(p)
	if l != "":
		return m.av.stella_di(l)
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
				if ev.double_click:
					_mosso = true
					var sd := _stella_a(ev.position)
					if sd > 0:
						stella_scelta.emit(sd)
			else:
				_trascina = false
				if not _mosso:
					var l := _luogo_a(ev.position)
					if l == "":
						var s := _stella_a(ev.position)
						if s > 0:
							stella_scelta.emit(s)
					else:
						luogo_cliccato.emit(l)
	elif ev is InputEventMouseMotion:
		if _trascina and ev.relative.length() > 0.5:
			_offset += ev.relative
			_mosso = true
		var h := _stella_a(ev.position)
		_hover = h
		var info := ""
		for rp in _rect_pedine:
			if rp[0].has_point(ev.position):
				var e: Dictionary = rp[1]
				info = _descrivi_pedina(e["id"]) if e["tipo"] == "pedina" else _descrivi_pianeta(e["id"])
		_hover_luogo = _luogo_a(ev.position)
		if info == "" and _hover_luogo != "":
			info = m.nome_luogo(_hover_luogo)
			if m.is_orbita(_hover_luogo) or m.is_amb(_hover_luogo):
				info += "\n" + _descrivi_pianeta(m.pid_di(_hover_luogo))
		if info == "" and h > 0:
			info = _descrivi(h)
		tooltip_text = info
	elif ev is InputEventMagnifyGesture:
		_zoom = clampf(_zoom * ev.factor, 0.12, 2.5)


func _descrivi_pedina(id: int) -> String:
	var u: Dictionary = m.unita[id]
	var dove := m.nome_luogo(str(u["luogo"]))
	if u["k"] == "mil":
		if u["fz"] == Motore.I and u["mobile"] and not u["scoperta"] and vista == Motore.R:
			return "Unità imperiale mobile (valore nascosto)\n" + dove
		return "%s (%s)\n%s" % [m.descr_mil(id), Dati.FAZIONI[u["fz"]], dove]
	var s := "%s (%s)\n%s" % [u["nome"], Dati.FAZIONI[u["fz"]], dove]
	if u["ind"]:
		s += "\nINDIVIDUATO"
	if u["prig"] >= 0:
		s += "\nPRIGIONIERO"
	if int(u["ferite"]) > 0:
		s += "\nFerite: %d" % int(u["ferite"])
	if not u["nave"].is_empty():
		s += "\nPilota: %s" % u["nave"]["nome"]
	return s


func _descrivi_pianeta(pid: int) -> String:
	var p: Dictionary = m.pianeti[pid]
	var st: String = Dati.LEALTA_NOMI[p["lealta"]]
	if p["stato"] == "ribellione":
		st = "in ribellione"
	elif p["stato"] == "ribelle":
		st = "controllo ribelle"
	var amb := []
	for a in Dati.pianeta(pid)["ambienti"]:
		amb.append("%s %d" % [Dati.AMBIENTI_NOMI[a["tipo"]], int(a["taglia"])])
	return "%s %d: %s\nBDP livello %d%s\nAmbienti: %s\nClic per aprire il sistema" % [Dati.pianeta(pid)["nome"], pid, st, int(p["bdp"]), "" if p["su"] else " fuori uso", ", ".join(amb)]


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
