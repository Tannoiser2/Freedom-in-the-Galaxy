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
var _rect_pedine := []     # [Rect2, id]
var _rect_pannelli := []   # [Rect2, stella, pid]
const TOK := 54.0          # lato delle pedine in pixel della mappa originale


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
	_rect_pedine.clear()
	_rect_pannelli.clear()
	var rr := maxf(16.0, 70.0 * _zoom)
	for sid in Dati.d()["stelle"]:
		var stella: int = sid
		var c := _a_schermo(_pos_img(stella))
		if not scen.has(stella):
			draw_circle(c, rr * 0.5, Color(0, 0, 0, 0.55))
			continue
		_pannello_sistema(stella, evid_stelle.has(stella))
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


## Riquadro di un sistema sopra la mappa: per ogni pianeta Lealtà, BDP, segreto e tutte le pedine
## (ambienti e orbita), più le caselle di Deriva se occupate. Si ridimensiona con lo zoom.
func _pannello_sistema(stella: int, evid: bool) -> void:
	var z := _zoom
	var sd: Dictionary = Dati.d()["stelle"][stella]
	var w := maxf(380.0, float(sd.get("raggio_px", 200)) * 1.9)
	var pids := m.scenario_pianeti().filter(func(x): return int(x / 10) == stella)
	var per_riga := int((w - 20.0) / (TOK + 4.0))
	# altezza
	var righe := []
	for pid in pids:
		righe.append([pid, _pedine_pianeta(pid)])
	var derive := []
	for id in m.unita:
		var l: String = str(m.unita[id]["luogo"])
		if (l.begins_with("D:") or l.begins_with("D2:")) and int(l.get_slice(":", 1)) == stella:
			derive.append(id)
	var h := 64.0
	for r in righe:
		h += 62.0 + ceil(r[1].size() / float(per_riga)) * (TOK + 4.0) + 8.0
	if not derive.is_empty():
		h += 34.0 + ceil(derive.size() / float(per_riga)) * (TOK + 4.0)
	var centro := _pos_img(stella)
	var orig := centro - Vector2(w, h) * 0.5
	var rp := Rect2(_a_schermo(orig), Vector2(w, h) * z)
	var bordo := UI.GIALLO if stella == stella_corrente else (Color(0.4, 1, 0.5) if evid else Color(0.85, 0.75, 0.3, 0.8))
	draw_rect(rp, Color(0.02, 0.03, 0.08, 0.86))
	draw_rect(rp, bordo, false, maxf(1.5, 4.0 * z) if evid or stella == stella_corrente else 1.5)
	if stella == _hover:
		draw_rect(rp.grow(2), Color.WHITE, false, 1.5)
	_rect_pannelli.append([rp, stella, -1])
	var fs := int(30.0 * z)
	var y := 10.0
	if fs >= 7:
		draw_circle(_a_schermo(orig + Vector2(30, 32)), 16.0 * z, Color(1.0, 0.8, 0.35))
		_testo(UI.font_titolo, _a_schermo(orig + Vector2(56, 44)), "%s %d" % [str(sd.get("nome", "")).to_upper(), stella], int(34.0 * z), Color(0.9, 0.85, 0.55))
	y = 64.0
	for r in righe:
		var pid: int = r[0]
		var lista: Array = r[1]
		var p: Dictionary = m.pianeti[pid]
		var y0 := y
		var hp: float = 62.0 + ceil(lista.size() / float(per_riga)) * (TOK + 4.0)
		var rr := Rect2(_a_schermo(orig + Vector2(6, y0 - 4)), Vector2(w - 12, hp) * z)
		var ev_p := evidenziati.keys().any(func(l): return (m.is_amb(str(l)) or m.is_orbita(str(l))) and m.pid_di(str(l)) == pid)
		var ctrl := m.controllo(pid)
		draw_rect(rr, Color(UI.colore_fazione(ctrl), 0.10) if ctrl >= 0 else Color(1, 1, 1, 0.04))
		if ev_p:
			draw_rect(rr, Color(0.4, 1, 0.5, 0.35 + 0.25 * sin(_tempo * 5.0)), false, maxf(2.0, 4.0 * z))
		_rect_pannelli.append([rr, stella, pid])
		# nome e stato
		if fs >= 7:
			var stato := ""
			match p["stato"]:
				"ribellione":
					stato = "IN RIBELLIONE"
				"ribelle":
					stato = "CONTROLLO RIBELLE"
				"fermata":
					stato = "RIBELLIONE FERMATA"
			_testo(UI.font_titolo, _a_schermo(orig + Vector2(12, y0 + 26)), "%s %d" % [str(Dati.pianeta(pid)["nome"]).to_upper(), pid], int(28.0 * z), Color(0.98, 0.86, 0.42))
			if stato != "":
				_testo(UI.font_grassetto, _a_schermo(orig + Vector2(12, y0 + 50)), stato, int(20.0 * z), UI.ROSSO if p["stato"] != "fermata" else UI.GRIGIO)
		# traccia politica: cinque caselle, quella attuale accesa
		var tx := w - 12.0 - 5.0 * 30.0 - 64.0
		for i in 5:
			var cr := Rect2(_a_schermo(orig + Vector2(tx + i * 30.0, y0 + 6)), Vector2(27, 40) * z)
			var base := Color(0.2, 0.25, 0.45) if i < 2 else (Color(0.3, 0.3, 0.32) if i == 2 else Color(0.45, 0.18, 0.14))
			var acceso: bool = i == int(p["lealta"]) and p["stato"] in ["imperiale", "fermata"]
			if p["stato"] in ["ribellione", "ribelle"] and i == 4:
				acceso = true
			draw_rect(cr, base.lightened(0.55) if acceso else base.darkened(0.2))
			if acceso:
				draw_rect(cr, Color.WHITE, false, maxf(1.0, 3.0 * z))
		# BDP
		var bt := UI.pedina_tex("bdp", not p["su"])
		var br := Rect2(_a_schermo(orig + Vector2(w - 60.0, y0 + 2)), Vector2(48, 48) * z)
		if bt != null:
			draw_texture_rect(bt, br, false)
		if fs >= 7:
			_testo(UI.font_titolo, br.position + Vector2(br.size.x * 0.62, br.size.y * 0.98), str(int(p["bdp"])), int(24.0 * z), Color.WHITE)
		# segreto planetario
		if m.livello == "galassia" and m.galattico.segreti.has(pid):
			var vis: bool = m.galattico.svelati.has(pid) or vista == Motore.I
			var ts := UI.pedina_tex("segreto_" + str(m.galattico.segreti[pid]) if vis else "segreto")
			if ts != null:
				draw_texture_rect(ts, Rect2(_a_schermo(orig + Vector2(tx - 52.0, y0 + 4)), Vector2(44, 44) * z), false)
		_disegna_pedine(lista, orig + Vector2(10, y0 + 58), per_riga)
		y += hp + 8.0
	if not derive.is_empty():
		if fs >= 7:
			_testo(UI.font_titolo, _a_schermo(orig + Vector2(12, y + 24)), "IN DERIVA", int(22.0 * z), Color(0.75, 0.7, 1.0))
		_disegna_pedine(derive, orig + Vector2(10, y + 32), per_riga)


func _pedine_pianeta(pid: int) -> Array:
	var out := []
	for f in [Motore.R, Motore.I]:
		var pg := []
		var mil := []
		for id in m.unita:
			var u: Dictionary = m.unita[id]
			var l: String = str(u["luogo"])
			if u["fz"] != f or not (m.is_amb(l) or m.is_orbita(l)) or m.pid_di(l) != pid:
				continue
			if u["k"] == "pg":
				pg.append(id)
			else:
				mil.append(id)
		out.append_array(pg + mil)
	return out


func _disegna_pedine(lista: Array, origine: Vector2, per_riga: int) -> void:
	var z := _zoom
	for i in lista.size():
		var id: int = lista[i]
		var u: Dictionary = m.unita[id]
		var pos := origine + Vector2((i % per_riga) * (TOK + 4.0), int(i / per_riga) * (TOK + 4.0))
		var r := Rect2(_a_schermo(pos), Vector2(TOK, TOK) * z)
		var t: Texture2D
		if u["k"] == "pg":
			t = UI.pedina_tex(str(u["ped"]) if u.has("ped") else UI.chiave_pg(u["nome"]), u["ind"])
		else:
			var nascosta: bool = u["fz"] == Motore.I and u["mobile"] and not u["scoperta"] and vista == Motore.R
			t = UI.truppa_tex(u, nascosta)
		if t != null:
			draw_texture_rect(t, r, false)
		else:
			draw_rect(r, UI.colore_fazione(u["fz"]))
		if u["k"] == "pg" and u["prig"] >= 0:
			draw_line(r.position, r.end, Color(0, 0, 0, 0.9), maxf(1.0, 4.0 * z))
		if m.is_orbita(str(u["luogo"])):
			draw_rect(r, Color(0.55, 0.65, 1.0), false, maxf(1.0, 3.0 * z))
		_rect_pedine.append([r, id])


func _testo(f: Font, p: Vector2, t: String, s: int, c: Color) -> void:
	draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, 4, Color(0, 0, 0, 0.8))
	draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, c)


func _testo_c(p: Vector2, t: String, c: Color) -> void:
	var w := UI.font_grassetto.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(UI.font_grassetto, p - Vector2(w / 2, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c)


func _stella_a(p: Vector2) -> int:
	for i in range(_rect_pannelli.size() - 1, -1, -1):
		if _rect_pannelli[i][0].has_point(p):
			return _rect_pannelli[i][1]
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
		_hover = h
		var info := ""
		for rp in _rect_pedine:
			if rp[0].has_point(ev.position):
				info = _descrivi_pedina(rp[1])
		if info == "":
			for rp in _rect_pannelli:
				if rp[0].has_point(ev.position) and rp[2] >= 0:
					info = _descrivi_pianeta(rp[2])
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
