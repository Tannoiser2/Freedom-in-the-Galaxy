extends Control
## Mappa 2D del sistema stellare: a sinistra la stella con le orbite e i pianeti, a destra le «Planet
## Track» come sulla mappa SPI: traccia politica con Lealtà e BDP, ambienti con tipo, taglia, razze,
## risorse, Coup, creature e le pedine originali delle due parti.

signal luogo_cliccato(luogo: String)
signal pedina_cliccata(id: int)
signal sopra(info: String)

var m: Motore
var vista := -1          # fazione di chi guarda (-1 = tutto visibile)
var evidenziati: Dictionary = {}
var selezionati: Dictionary = {}   # id unità evidenziati
var _rect_luoghi := {}
var _rect_pedine := []   # [Rect2, id]
var _rect_pianeti := {}
var _rect_segreti := {}
var _stelle_fondo: Array = []
var _tempo := 0.0
var _voli: Array = []    # animazioni {da: Vector2, a: Vector2, t: float, col}
var _pos_pianeti := {}
var _hover := ""
var stella_vista := -1
const PED := 50.0


## Stella del sistema mostrato (nello Star System Game quella dello scenario).
func stella() -> int:
	if m.livello == "sistema" or stella_vista < 0:
		return int(m.scenario.get("stella", stella_vista))
	return stella_vista


func pianeti_vista() -> Array:
	if m.livello == "sistema":
		return m.scenario_pianeti()
	return m.scenario_pianeti().filter(func(x): return int(x / 10) == stella())


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var g := RandomNumberGenerator.new()
	g.seed = 5764
	for i in 420:
		_stelle_fondo.append([Vector2(g.randf(), g.randf()), g.randf_range(0.4, 1.8), g.randf_range(0.25, 0.95)])
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_tempo += delta
	if not _voli.is_empty():
		for v in _voli:
			v["t"] += delta / 1.1
		_voli = _voli.filter(func(v): return v["t"] < 1.0)
	queue_redraw()


func evidenzia(e: Dictionary) -> void:
	evidenziati = e
	queue_redraw()


func anima_volo(da_luogo: String, a_luogo: String, f: int) -> void:
	var a := m.pid_di(da_luogo) if da_luogo != "" else -1
	var b := m.pid_di(a_luogo)
	if not _pos_pianeti.has(b):
		return
	var p0: Vector2 = _pos_pianeti.get(a, _centro_orbite() + Vector2(-_raggio_max() * 1.3, -_raggio_max()))
	_voli.append({"da": p0, "a": _pos_pianeti[b], "t": 0.0, "col": UI.colore_fazione(f)})


# ------------------------------------------------------------------------------------
# Geometria
# ------------------------------------------------------------------------------------

func _larghezza_orbite() -> float:
	return size.x * 0.34


func _centro_orbite() -> Vector2:
	return Vector2(_larghezza_orbite() * 0.5, size.y * 0.5)


func _raggio_max() -> float:
	return minf(_larghezza_orbite() * 0.44, size.y * 0.42)


# ------------------------------------------------------------------------------------
# Disegno
# ------------------------------------------------------------------------------------

func _draw() -> void:
	if m == null or m.pianeti.is_empty():
		return
	_rect_luoghi.clear()
	_rect_pedine.clear()
	_rect_pianeti.clear()
	_rect_segreti.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.02, 0.05))
	for s in _stelle_fondo:
		var tw := 0.75 + 0.25 * sin(_tempo * 1.3 + s[0].x * 40.0)
		draw_circle(s[0] * size, s[1] * 0.6, Color(0.85, 0.88, 1.0, s[2] * tw))
	_disegna_sistema()
	var pids := pianeti_vista()
	var x0 := _larghezza_orbite()
	var w := size.x - x0 - 8
	var h: float = (size.y - 8) / max(3, pids.size())
	for i in pids.size():
		_disegna_traccia(pids[i], Rect2(x0, 4 + i * h, w, h - 8))


func _disegna_sistema() -> void:
	var c := _centro_orbite()
	var st: Dictionary = Dati.d()["stelle"].get(stella(), {})
	var rmax := _raggio_max()
	# alone e stella
	for k in 12:
		var r := 46.0 + k * 9.0
		draw_circle(c, r, Color(1.0, 0.72, 0.2, 0.05 - k * 0.0035))
	var pulsa := 1.0 + 0.03 * sin(_tempo * 2.0)
	draw_circle(c, 40 * pulsa, Color(1.0, 0.62, 0.12))
	draw_circle(c, 34 * pulsa, Color(1.0, 0.82, 0.25))
	draw_circle(c, 24 * pulsa, Color(1.0, 0.95, 0.65))
	var ft := UI.font_titolo
	var nome: String = st.get("nome", "")
	_testo_centro(ft, c + Vector2(0, -56), nome.to_upper(), 28, Color(0.7, 0.85, 1.0))
	_testo_centro(UI.font_grassetto, c + Vector2(0, 7), str(stella()), 18, Color(0.2, 0.15, 0.05))
	var pids := pianeti_vista()
	for i in pids.size():
		var pid: int = pids[i]
		var dp := Dati.pianeta(pid)
		var anello := int(dp.get("anello", i + 1))
		var r: float = rmax * (0.38 + 0.62 * float(anello) / max(3, pids.size()))
		draw_arc(c, r, 0, TAU, 128, Color(0.85, 0.75, 0.25, 0.55), 2.0, true)
		var ang := -PI * 0.5 + anello * 2.1 + _tempo * 0.02 / anello
		var pos: Vector2 = c + Vector2(cos(ang), sin(ang)) * r
		_pos_pianeti[pid] = pos
		_disegna_pianeta(pid, pos, 22.0 + anello * 3.0)
		var rect := Rect2(pos - Vector2(36, 36), Vector2(72, 72))
		_rect_pianeti[pid] = rect
		_testo_centro(UI.font_titolo, pos + Vector2(0, 46 + anello * 3), "%s %d" % [dp["nome"].to_upper(), pid], 20, Color(0.9, 0.82, 0.45))
		var ctrl := m.controllo(pid)
		var stato := _nome_stato(pid)
		_testo_centro(UI.font_testo, pos + Vector2(0, 66 + anello * 3), stato, 15, UI.colore_fazione(ctrl) if ctrl >= 0 else UI.GRIGIO)
		# personaggi e truppe in sintesi
		var nr := 0
		var ni := 0
		for id in m.unita:
			var u: Dictionary = m.unita[id]
			if u["luogo"] != "" and u["luogo"] != "morto" and (m.is_amb(u["luogo"]) or m.is_orbita(u["luogo"])) and m.pid_di(u["luogo"]) == pid:
				if u["fz"] == Motore.R:
					nr += 1
				else:
					ni += 1
		if nr > 0:
			draw_circle(pos + Vector2(-30, -26), 11, UI.COL_RIBELLI)
			_testo_centro(UI.font_grassetto, pos + Vector2(-30, -20), str(nr), 15, Color.WHITE)
		if ni > 0:
			draw_circle(pos + Vector2(30, -26), 11, UI.COL_IMPERO)
			_testo_centro(UI.font_grassetto, pos + Vector2(30, -20), str(ni), 15, Color(0.15, 0.1, 0))
	# astronavi in volo
	for v in _voli:
		var t: float = v["t"]
		var e := t * t * (3.0 - 2.0 * t)
		var mid: Vector2 = (v["da"] + v["a"]) * 0.5 + Vector2(0, -60)
		var p: Vector2 = v["da"].lerp(mid, e).lerp(mid.lerp(v["a"], e), e)
		for k in 6:
			var tt := maxf(0.0, e - k * 0.03)
			var pk: Vector2 = v["da"].lerp(mid, tt).lerp(mid.lerp(v["a"], tt), tt)
			draw_circle(pk, 5 - k * 0.7, Color(v["col"], 0.8 - k * 0.12))
		draw_circle(p, 6, Color.WHITE)
	# legenda turno
	var fasi := {"schieramento": "Schieramento", "movimento": "Movimento", "reazione": "Reazione nemica", "combattimento": "Combattimento militare", "ricerca": "Ricerca", "missioni": "Missioni", "finita": "Partita finita", "preparazione": ""}
	var y := 26.0
	_testo(UI.font_titolo, Vector2(16, y), "TURNO %d DI %d" % [m.turno, int(m.scenario["turni"])], 24, UI.GIALLO)
	_testo(UI.font_testo, Vector2(16, y + 26), "%s — %s" % [Dati.FAZIONI[m.di_turno], fasi.get(m.fase, m.fase)], 17, UI.colore_fazione(m.di_turno))
	if m.livello != "sistema":
		_disegna_derive()


## Caselle di Deriva, Deriva 2 e, se serve, Fuori mappa per il sistema mostrato.
func _disegna_derive() -> void:
	var w := _larghezza_orbite()
	var bw := (w - 36) / 2.0
	var bh := 96.0
	var y := size.y - bh - 10
	var caselle := [["D:%d" % stella(), "DERIVA"], ["D2:%d" % stella(), "DERIVA 2"]]
	var fuori := {}
	for id in m.unita:
		var l: String = str(m.unita[id]["luogo"])
		if l.begins_with("S:"):
			fuori[l] = true
	for l in fuori:
		caselle.append([l, "FUORI MAPPA (%s)" % Dati.d()["stelle"].get(int(l.get_slice(":", 1)), {}).get("nome", "")])
	for i in caselle.size():
		var col := i % 2
		var riga := int(i / 2)
		var r := Rect2(12 + col * (bw + 12), y - riga * (bh + 8), bw, bh)
		var l: String = caselle[i][0]
		_rect_luoghi[l] = r
		var ev = evidenziati.get(l, null)
		draw_rect(r, Color(0.06, 0.05, 0.12, 0.92))
		draw_rect(r, ev if ev != null else Color(0.6, 0.5, 0.9, 0.7), false, 3.0 if ev != null else 1.5)
		_testo(UI.font_titolo2, r.position + Vector2(8, 18), caselle[i][1], 14, Color(0.8, 0.75, 1.0))
		var area := Rect2(r.position + Vector2(4, 24), r.size - Vector2(8, 28))
		var meta := area.size.y / 2.0
		_disegna_pedine(l, Motore.R, Rect2(area.position, Vector2(area.size.x, meta - 1)))
		_disegna_pedine(l, Motore.I, Rect2(area.position + Vector2(0, meta), Vector2(area.size.x, meta - 1)))


func _nome_stato(pid: int) -> String:
	var p: Dictionary = m.pianeti[pid]
	match p["stato"]:
		"ribellione":
			return "IN RIBELLIONE"
		"ribelle":
			return "Controllo ribelle"
		"fermata":
			return "Ribellione fermata"
	return Dati.LEALTA_NOMI[p["lealta"]]


func _disegna_pianeta(pid: int, pos: Vector2, r: float) -> void:
	var dp := Dati.pianeta(pid)
	var tipo: String = dp["ambienti"][0]["tipo"]
	var base: Color = UI.COL_AMBIENTI.get(tipo, Color.GRAY).lerp(Color(0.6, 0.6, 0.7), 0.25)
	var sel := evidenziati.keys().any(func(l): return m.pid_di(l) == pid)
	if sel:
		draw_circle(pos, r + 9 + 2 * sin(_tempo * 5), Color(0.5, 1, 0.5, 0.35))
	var ctrl := m.controllo(pid)
	if ctrl >= 0:
		draw_arc(pos, r + 5, 0, TAU, 64, UI.colore_fazione(ctrl), 3.0, true)
	draw_circle(pos, r, base.darkened(0.55))
	draw_circle(pos + Vector2(-r * 0.12, -r * 0.12), r * 0.9, base.darkened(0.3))
	draw_circle(pos + Vector2(-r * 0.25, -r * 0.25), r * 0.68, base)
	draw_circle(pos + Vector2(-r * 0.38, -r * 0.38), r * 0.32, base.lightened(0.35))
	# bande degli altri ambienti
	for i in range(1, dp["ambienti"].size()):
		var c2: Color = UI.COL_AMBIENTI.get(dp["ambienti"][i]["tipo"], Color.GRAY)
		draw_arc(pos, r * (0.45 + i * 0.18), PI * 0.1, PI * 0.9, 24, Color(c2, 0.55), 3.0, true)
	if m.pianeti[pid]["stato"] in ["ribellione", "ribelle"]:
		draw_arc(pos, r + 12, _tempo * 2.0, _tempo * 2.0 + PI * 1.3, 32, Color(1, 0.3, 0.2, 0.8), 2.5, true)


func _disegna_traccia(pid: int, r: Rect2) -> void:
	var dp := Dati.pianeta(pid)
	var p: Dictionary = m.pianeti[pid]
	var ctrl := m.controllo(pid)
	var bordo := UI.colore_fazione(ctrl) if ctrl >= 0 else Color(0.45, 0.48, 0.6)
	var sel := evidenziati.keys().any(func(l): return m.pid_di(l) == pid)
	draw_style_box(UI.stile(Color(0.04, 0.05, 0.11, 0.9), bordo.darkened(0.25), 2, 10, 0), r)
	# intestazione: orbita
	var hdr := Rect2(r.position + Vector2(8, 6), Vector2(250, 34))
	_testo(UI.font_titolo, hdr.position + Vector2(4, 27), "%s %d" % [dp["nome"].to_upper(), pid], 27, Color(0.98, 0.86, 0.42))
	var status = dp.get("status", null)
	if status != null and str(status) != "":
		_testo(UI.font_testo, hdr.position + Vector2(4, 48), str(status).to_upper(), 13, UI.GRIGIO)
	if m.livello == "galassia" and m.galattico.segreti.has(pid):
		var vis: bool = m.galattico.svelati.has(pid) or vista == Motore.I
		var ts := UI.pedina_tex("segreto_" + str(m.galattico.segreti[pid]) if vis else "segreto")
		var sr := Rect2(r.position.x + 214, r.position.y + 6, 40, 40)
		if ts != null:
			draw_texture_rect(ts, sr, false)
		if vis:
			_rect_segreti[sr] = pid
	# traccia politica: 5 caselle
	var tx := r.position.x + 8
	var ty := r.position.y + 58
	var bw := 46.0
	var nomi := ["PATR.", "LEALE", "NEUTR.", "DISS.", "AGIT."]
	var num := ["2", "1", "0", "1", "2"]
	var pol: Dictionary = dp["politica"]
	for i in 5:
		var br := Rect2(tx + i * (bw + 2), ty, bw, 62)
		var colb := Color(0.15, 0.18, 0.3) if i < 2 else (Color(0.2, 0.2, 0.22) if i == 2 else Color(0.3, 0.14, 0.12))
		draw_rect(br, colb)
		draw_rect(br, Color(0.85, 0.75, 0.3, 0.7), false, 1.5)
		_testo_centro(UI.font_titolo2, br.position + Vector2(bw / 2, 14), nomi[i], 12, Color(0.92, 0.85, 0.55))
		_testo_centro(UI.font_titolo, br.position + Vector2(bw / 2, 38), num[i], 20, Color(0.92, 0.85, 0.55, 0.55))
		var marche := ""
		if Dati.LEALTA.find(str(pol["S"])) == i:
			marche += "S"
		if Dati.LEALTA.find(str(pol["A"])) == i:
			marche += "A" + ("C" if pol.get("AC", false) else "")
		if marche != "":
			_testo_centro(UI.font_grassetto, br.position + Vector2(bw / 2, 56), marche, 11, Color(0.8, 0.8, 0.9, 0.7))
	# segnalino Lealtà / Ribellione / Controllo ribelle
	var li: int = p["lealta"]
	var mr := Rect2(tx + li * (bw + 2) + 3, ty + 14, bw - 6, bw - 6)
	var chiave_seg := "lealta"
	var retro := false
	if p["stato"] == "ribellione":
		retro = true
	elif p["stato"] == "ribelle":
		chiave_seg = "rib_urbano_10"
		retro = true
	var t := UI.pedina_tex(chiave_seg, retro)
	if t != null:
		draw_texture_rect(t, mr, false)
	if p["stato"] == "fermata":
		_testo_centro(UI.font_grassetto, mr.position + Vector2(mr.size.x / 2, mr.size.y + 12), "Fermata", 11, UI.ROSSO)
	# BDP
	var bdp_r := Rect2(tx, ty + 70, 46, 46)
	var tb := UI.pedina_tex("bdp", not p["su"])
	if tb != null:
		draw_texture_rect(tb, bdp_r, false)
	_testo(UI.font_grassetto, bdp_r.position + Vector2(54, 20), "BDP livello %d" % int(p["bdp"]), 15, Color(0.85, 0.9, 1))
	var chi: String = "nessuno" if ctrl < 0 else Dati.FAZIONI[ctrl]
	_testo(UI.font_testo, bdp_r.position + Vector2(54, 40), ("attiva" if p["su"] else "fuori uso") + " · controllo: " + chi, 13, UI.GRIGIO)
	if m.livello != "sistema":
		var oy := bdp_r.end.y + 6
		var orb := Rect2(tx, oy, 5 * (bw + 2) - 2, r.end.y - oy - 4)
		if orb.size.y > 40:
			var lo := "%d:o" % pid
			_rect_luoghi[lo] = orb
			var ev = evidenziati.get(lo, null)
			draw_rect(orb, Color(0.03, 0.04, 0.1, 0.95))
			draw_rect(orb, ev if ev != null else (Color.WHITE if _hover == lo else Color(0.5, 0.6, 0.9, 0.7)), false, 3.0 if ev != null else 1.5)
			_testo(UI.font_titolo2, orb.position + Vector2(6, 15), "ORBITA", 12, Color(0.7, 0.8, 1.0))
			var ar := Rect2(orb.position + Vector2(60, 2), Vector2(orb.size.x - 62, orb.size.y - 4))
			var meta := ar.size.y / 2.0
			_disegna_pedine(lo, Motore.R, Rect2(ar.position, Vector2(ar.size.x, meta - 1)))
			_disegna_pedine(lo, Motore.I, Rect2(ar.position + Vector2(0, meta), Vector2(ar.size.x, meta - 1)))
	# ambienti
	var amb: Array = dp["ambienti"]
	var ax := r.position.x + 8 + 5 * (bw + 2) + 14
	var aw := (r.end.x - ax - 8) / 3.0
	for i in amb.size():
		var l := "%d:%d" % [pid, i]
		var ar := Rect2(ax + i * aw, r.position.y + 6, aw - 8, r.size.y - 12)
		_disegna_ambiente(l, amb[i], ar)


func _disegna_ambiente(l: String, a: Dictionary, r: Rect2) -> void:
	_rect_luoghi[l] = r
	var col: Color = UI.COL_AMBIENTI.get(a["tipo"], Color.GRAY)
	var ev = evidenziati.get(l, null)
	draw_rect(r, Color(0.07, 0.09, 0.17, 0.95))
	if ev != null:
		var a2 := 0.25 + 0.15 * sin(_tempo * 5.0)
		draw_rect(r, Color(ev, a2))
		draw_rect(r, ev, false, 3.0)
	elif _hover == l:
		draw_rect(r, Color(1, 1, 1, 0.5), false, 2.0)
	else:
		draw_rect(r, Color(col, 0.7), false, 1.5)
	# intestazione: simbolo, tipo, taglia
	var hr := Rect2(r.position, Vector2(r.size.x, 30))
	draw_rect(hr, Color(col, 0.85))
	_simbolo(a["tipo"], hr.position + Vector2(16, 15), 10)
	_testo(UI.font_titolo, hr.position + Vector2(32, 23), Dati.AMBIENTI_NOMI[a["tipo"]].to_upper(), 19, Color.WHITE)
	var sq := Rect2(hr.end.x - 30, hr.position.y + 3, 26, 24)
	draw_rect(sq, Color(0.1, 0.25, 0.75))
	_testo_centro(UI.font_titolo, sq.position + Vector2(13, 20), str(int(a["taglia"])), 19, Color.WHITE)
	# dati
	var razze := []
	for rz in a.get("razze", []):
		razze.append(rz["nome"] + ("*" if rz.get("stellare", false) else ""))
	var y := hr.end.y + 18
	var x := r.position.x + 6
	_testo(UI.font_grassetto, Vector2(x, y), ", ".join(razze), 14, Color(0.9, 0.9, 1))
	var info := "Risorse %d%s" % [int(a.get("risorse", 0)), "*" if a.get("risorse_stella", false) else ""]
	if a.get("coup", null) != null:
		info += " · Coup %d" % int(a["coup"])
	_testo(UI.font_testo, Vector2(x, y + 18), info, 13, UI.GRIGIO)
	var riga3 := ""
	if a.get("sovrano", null) != null:
		riga3 = "Sovrano: " + str(a["sovrano"])
	if a.get("creatura", null) != null:
		riga3 += ("   " if riga3 != "" else "") + "Creatura: " + str(a["creatura"])
	if riga3 != "":
		_testo(UI.font_testo, Vector2(x, y + 34), riga3, 13, Color(0.95, 0.65, 0.5))
	# marcatori
	var mx := r.end.x - 4
	if m.campi.has(l):
		var tc := UI.pedina_tex("campo_ribelle")
		mx -= 30
		if tc != null:
			draw_texture_rect(tc, Rect2(mx, y - 14, 28, 28), false)
	if m.pianeti[m.pid_di(l)]["coup"].has(l):
		var tcp := UI.pedina_tex("campo_ribelle", true)
		mx -= 30
		if tcp != null:
			draw_texture_rect(tcp, Rect2(mx, y - 14, 28, 28), false)
	# pedine: Ribelli sopra, Impero sotto
	var area := Rect2(r.position.x + 4, y + 44, r.size.x - 8, r.end.y - y - 48)
	var meta := area.size.y / 2.0
	_disegna_pedine(l, Motore.R, Rect2(area.position, Vector2(area.size.x, meta - 2)))
	_disegna_pedine(l, Motore.I, Rect2(area.position + Vector2(0, meta), Vector2(area.size.x, meta - 2)))


func _disegna_pedine(l: String, f: int, r: Rect2) -> void:
	draw_rect(r, Color(UI.colore_fazione(f), 0.06))
	var lista := []
	for id in m.unita:
		var u: Dictionary = m.unita[id]
		if u["luogo"] != l:
			continue
		if u["k"] == "pg" and u["prig"] >= 0:
			# un prigioniero si disegna accanto ai suoi custodi
			if m.avversario(u["fz"]) == f:
				lista.append(id)
			continue
		if u["fz"] == f:
			lista.append(id)
	if lista.is_empty():
		return
	# ordine: truppe, personaggi con le truppe, personaggi
	lista.sort_custom(func(a, b): return _ordine(a) < _ordine(b))
	var lato := minf(PED, r.size.y - 4)
	var n := lista.size()
	var extra := 0
	for id in lista:
		if m.unita[id]["k"] == "pg" and not m.unita[id]["nave"].is_empty():
			extra += 1
	var passo := minf(lato + 3, (r.size.x - lato) / max(1, n + extra - 1))
	var x := r.position.x
	for id in lista:
		var u: Dictionary = m.unita[id]
		var pr := Rect2(x, r.position.y + 2, lato, lato)
		_disegna_pedina(id, pr)
		_rect_pedine.append([pr, id])
		x += passo
		if u["k"] == "pg" and not u["nave"].is_empty():
			var nr := Rect2(x, r.position.y + 2, lato, lato)
			var tn := UI.pedina_tex(UI.chiave_nave(u["nave"]), u["nave"].get("dmg", false))
			if tn != null:
				draw_texture_rect(tn, nr, false)
			_rect_pedine.append([nr, id])
			x += passo


func _ordine(id: int) -> int:
	var u: Dictionary = m.unita[id]
	if u["k"] == "mil":
		return 0
	if u["truppe"]:
		return 1
	if u["prig"] >= 0:
		return 3
	return 2


func _disegna_pedina(id: int, pr: Rect2) -> void:
	var u: Dictionary = m.unita[id]
	var t: Texture2D = null
	if u["k"] == "pg":
		t = UI.pedina_tex(str(u["ped"]) if u.has("ped") else UI.chiave_pg(u["nome"]), u["ind"])
	else:
		var nascosta: bool = u["fz"] == Motore.I and u["mobile"] and not u["scoperta"] and vista == Motore.R
		t = UI.pedina_tex(UI.chiave_mil(u), nascosta)
	draw_rect(Rect2(pr.position + Vector2(3, 3), pr.size), Color(0, 0, 0, 0.5))
	if t != null:
		draw_texture_rect(t, pr, false)
	else:
		draw_rect(pr, UI.colore_fazione(u["fz"]))
		_testo_centro(UI.font_grassetto, pr.get_center(), m.nome_u(id).left(8), 11, Color.BLACK)
	if selezionati.has(id):
		draw_rect(pr.grow(2), UI.GIALLO, false, 3.0)
	if u["k"] == "pg":
		if u["ferite"] > 0:
			var fr := Rect2(pr.position + Vector2(pr.size.x - 18, -4), Vector2(20, 18))
			draw_rect(fr, Color(0.7, 0.05, 0.05))
			_testo_centro(UI.font_grassetto, fr.position + Vector2(10, 14), str(u["ferite"]), 13, Color.WHITE)
		if u["prig"] >= 0:
			draw_line(pr.position, pr.end, Color(0.1, 0.1, 0.1, 0.9), 4)
			draw_line(Vector2(pr.end.x, pr.position.y), Vector2(pr.position.x, pr.end.y), Color(0.1, 0.1, 0.1, 0.9), 4)
		if u["truppe"]:
			draw_rect(Rect2(pr.position + Vector2(0, pr.size.y - 6), Vector2(pr.size.x, 6)), Color(0.2, 0.9, 0.4, 0.9))


func _simbolo(tipo: String, c: Vector2, r: float) -> void:
	var w := Color.WHITE
	match tipo:
		"urbano":
			draw_rect(Rect2(c - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), w)
		"selvaggio":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r, r * 0.8), c + Vector2(-r * 0.35, -r * 0.8), c + Vector2(0.2 * r, r * 0.8)]), w)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.1 * r, r * 0.8), c + Vector2(r * 0.5, -r * 0.5), c + Vector2(r, r * 0.8)]), w)
		"sotterraneo":
			draw_arc(c + Vector2(0, r * 0.6), r, PI, TAU, 16, w, 4)
			draw_line(c + Vector2(-r, r * 0.6), c + Vector2(r, r * 0.6), w, 3)
		"liquido":
			draw_circle(c + Vector2(0, r * 0.2), r * 0.7, w)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, 0), c + Vector2(0, -r), c + Vector2(r * 0.6, 0)]), w)
		"aereo":
			draw_arc(c, r * 0.8, 0, TAU, 24, w, 4)
		"fuoco":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), w)


func _testo(f: Font, p: Vector2, t: String, s: int, c: Color) -> void:
	draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, 4, Color(0, 0, 0, 0.75))
	draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, c)


func _testo_centro(f: Font, p: Vector2, t: String, s: int, c: Color) -> void:
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	_testo(f, p - Vector2(w / 2.0, 0), t, s, c)


# ------------------------------------------------------------------------------------
# Input
# ------------------------------------------------------------------------------------

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var nuovo := ""
		for l in _rect_luoghi:
			if _rect_luoghi[l].has_point(ev.position):
				nuovo = l
		if nuovo != _hover:
			_hover = nuovo
			queue_redraw()
		var info := ""
		for rp in _rect_pedine:
			if rp[0].has_point(ev.position):
				info = descrivi(rp[1])
		for sr in _rect_segreti:
			if sr.has_point(ev.position):
				var k: String = m.galattico.segreti[_rect_segreti[sr]]
				var d: Dictionary = Dati.d()["regole_avanzate"]["segreti"][k]
				info = "Segreto planetario: %s\n%s" % [d["nome"], d["it"]]
		if info == "" and _hover != "":
			info = m.nome_luogo(_hover)
		tooltip_text = info
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for rp in _rect_pedine:
			if rp[0].has_point(ev.position):
				pedina_cliccata.emit(rp[1])
		for l in _rect_luoghi:
			if _rect_luoghi[l].has_point(ev.position):
				luogo_cliccato.emit(l)
				return
		for pid in _rect_pianeti:
			if _rect_pianeti[pid].has_point(ev.position):
				luogo_cliccato.emit("%d:0" % pid)
				return


func descrivi(id: int) -> String:
	var u: Dictionary = m.unita[id]
	if u["k"] == "mil":
		if u["fz"] == Motore.I and u["mobile"] and not u["scoperta"] and vista == Motore.R:
			return "Unità imperiale mobile (valore nascosto)"
		return "%s — %s" % [m.descr_mil(id), Dati.FAZIONI[u["fz"]]]
	var c: Dictionary = u["c"]
	var s := "%s (%s)\nCombattimento %d · Resistenza %d/%d · Intelligenza %d\nComando %d · Diplomazia %d · Navigazione %d" % [u["nome"], Dati.FAZIONI[u["fz"]], m.combattimento_pg(id), m.resistenza_residua(id), int(c.get("resistenza", 0)), m.val(id, "intelligenza"), m.comando(id), m.val(id, "diplomazia"), m.val(id, "navigazione")]
	if u["ind"]:
		s += "\nINDIVIDUATO"
	if u["prig"] >= 0:
		s += "\nPRIGIONIERO"
	if u["truppe"]:
		s += "\nCon le truppe"
	if not u["nave"].is_empty():
		s += "\nPilota: %s (manovra %d, passeggeri %d)%s" % [u["nave"]["nome"], u["nave"]["man"], u["nave"]["pas"], " DANNEGGIATA" if u["nave"].get("dmg", false) else ""]
	if not u["poss"].is_empty() and (vista < 0 or vista == u["fz"]):
		var nomi := []
		for nr in u["poss"]:
			nomi.append(Dati.d()["poss"].get(int(nr), {}).get("nome_it", "?"))
		s += "\nPossessi: " + ", ".join(nomi)
	var sp: String = c.get("speciale_it", "")
	if sp != "":
		s += "\n" + sp
	return s
