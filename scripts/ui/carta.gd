extends Control
## Carta ricomposta in italiano nello stile delle carte SPI: personaggi (con il ritratto originale),
## possessi, missioni e carte Azione. Un clic destro mostra la scansione originale in inglese.

var tipo := "personaggio"     # personaggio | possesso | missione | azione
var dati: Dictionary = {}
var m: Motore = null
var id_unita := -1
var sezione := ""             # per le carte Azione: sezione da mettere in risalto
var originale := false


func _init(p_tipo := "personaggio", p_dati := {}) -> void:
	tipo = p_tipo
	dati = p_dati
	custom_minimum_size = Vector2(230, 330)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Clic destro: carta originale (inglese)"


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		originale = not originale
		queue_redraw()


const BASE := Vector2(230, 330)


func _draw() -> void:
	var sc := minf(size.x / BASE.x, size.y / BASE.y)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc, sc))
	var r := Rect2(Vector2.ZERO, BASE)
	if originale:
		var f: String = dati.get("file", "")
		var lato := "_retro" if tipo != "personaggio" else "_fronte"
		var t := UI.tex("res://assets/carte/scansioni/%s%s.webp" % [f, lato])
		if t != null:
			if t.get_width() < t.get_height() and tipo in ["azione", "missione", "possesso"]:
				draw_set_transform(r.get_center() * sc, PI * 0.5 if tipo != "possesso" else -PI * 0.5, Vector2(sc, sc))
				var sz := Vector2(r.size.y, r.size.x)
				draw_texture_rect(UI.tex("res://assets/carte/scansioni/%s_retro.webp" % f), Rect2(-sz / 2, sz), false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc, sc))
			else:
				draw_texture_rect(t, r, false)
			return
	match tipo:
		"personaggio":
			_personaggio(r)
		"possesso":
			_possesso(r)
		"missione":
			_missione(r)
		"azione":
			_azione(r)


func _cornice(r: Rect2, col: Color, fondo := Color(0.96, 0.93, 0.85)) -> void:
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.45))
	draw_style_box(UI.stile(fondo, col, 4, 10, 0), r)


func _intestazione(r: Rect2, col: Color, sopra: String, titolo: String, nr: int) -> float:
	var h := Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, 50))
	draw_rect(h, col)
	_t(UI.font_titolo2, h.position + Vector2(8, 16), sopra.to_upper(), 12, Color(1, 1, 1, 0.85))
	_t(UI.font_titolo2, h.position + Vector2(h.size.x - 40, 16), "nr. %d" % nr, 12, Color(1, 1, 1, 0.85))
	var s := 24
	while UI.font_titolo.get_string_size(titolo.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > h.size.x - 14 and s > 13:
		s -= 1
	_t(UI.font_titolo, h.position + Vector2(8, 42), titolo.to_upper(), s, Color.WHITE)
	return h.end.y + 6


func _personaggio(r: Rect2) -> void:
	var rib: bool = dati.get("fazione", "") == "ribelli"
	var col := Color(0.78, 0.18, 0.12) if rib else Color(0.86, 0.62, 0.10)
	_cornice(r, col)
	var y := _intestazione(r, col, ("Ribelle" if rib else "Imperiale") + " · " + str(dati.get("razza_en", "")), str(dati.get("nome", "")), int(dati.get("nr", 0)))
	var tit: String = str(dati.get("titolo_it", "")) if dati.get("titolo_it", null) != null else ""
	if tit != "":
		_t(UI.font_testo, Vector2(r.position.x + 10, y + 12), tit, 12, Color(0.3, 0.2, 0.15))
		y += 16
	# ritratto
	var por := UI.tex("res://assets/carte/scansioni/%s_fronte.webp" % dati.get("file", ""))
	var pr := Rect2(r.position.x + 8, y, 92, 128)
	if por != null:
		var tw := float(por.get_width())
		var th := float(por.get_height())
		draw_texture_rect_region(por, pr, Rect2(tw * 0.06, th * 0.04, tw * 0.88, th * 0.78))
	draw_rect(pr, Color(0.2, 0.15, 0.1), false, 1.5)
	# valori
	var nomi := [["Combattimento", "combattimento"], ["Resistenza", "resistenza"], ["Intelligenza", "intelligenza"], ["Comando", "comando"], ["Diplomazia", "diplomazia"], ["Navigazione", "navigazione"]]
	var vx := pr.end.x + 8
	for i in nomi.size():
		var yy := y + 14 + i * 21
		_t(UI.font_testo, Vector2(vx, yy), nomi[i][0], 13, Color(0.2, 0.15, 0.1))
		var v := str(int(dati.get(nomi[i][1], 0)))
		if nomi[i][1] == "comando" and dati.get("comando_spazio", null) != null:
			v += " (%d)" % int(dati["comando_spazio"])
		if m != null and id_unita >= 0 and m.unita.has(id_unita):
			if nomi[i][1] == "combattimento":
				v = str(m.combattimento_pg(id_unita))
			elif nomi[i][1] == "resistenza":
				v = "%d/%d" % [m.resistenza_residua(id_unita), int(dati.get("resistenza", 0))]
		_t(UI.font_titolo, Vector2(r.end.x - 12 - UI.font_titolo.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x, yy + 1), v, 17, Color(0.15, 0.1, 0.05))
	y = pr.end.y + 8
	var pn: Array = dati.get("pianeti_natali", [])
	_t(UI.font_grassetto, Vector2(r.position.x + 10, y + 12), "Pianeta natale: " + ", ".join(pn), 12, Color(0.25, 0.15, 0.1))
	y += 18
	if dati.get("cavaliere_imperiale", false):
		_t(UI.font_grassetto, Vector2(r.position.x + 10, y + 12), "Cavaliere Imperiale", 12, Color(0.5, 0.3, 0.0))
		y += 16
	_testo_a_capo(str(dati.get("speciale_it", "")), Rect2(r.position.x + 10, y + 4, r.size.x - 20, r.end.y - y - 10), 12, Color(0.15, 0.1, 0.08))
	if m != null and id_unita >= 0 and m.unita.has(id_unita):
		var u: Dictionary = m.unita[id_unita]
		var stato := []
		if u["luogo"] == "morto":
			stato.append("MORTO")
		elif u["prig"] >= 0:
			stato.append("PRIGIONIERO")
		if u["ind"] and u["luogo"] != "morto":
			stato.append("INDIVIDUATO")
		if not stato.is_empty():
			var sr := Rect2(r.position.x + 8, r.end.y - 28, r.size.x - 16, 22)
			draw_rect(sr, Color(0.7, 0.08, 0.05, 0.9))
			_t(UI.font_titolo, sr.position + Vector2(8, 18), " · ".join(stato), 15, Color.WHITE)


func _possesso(r: Rect2) -> void:
	var col := Color(0.15, 0.42, 0.62)
	_cornice(r, col, Color(0.92, 0.95, 0.97))
	var tipi := {"astronave": "Astronave", "arma": "Arma", "oggetto": "Oggetto", "compagno": "Compagno"}
	var y := _intestazione(r, col, "Possesso · " + tipi.get(dati.get("tipo", ""), ""), str(dati.get("nome_it", "")), int(dati.get("nr", 0)))
	if dati.get("tipo", "") == "astronave":
		var righe := [["Manovra", int(dati.get("manovra", 0))], ["Passeggeri", int(dati.get("passeggeri", 0))], ["Cannoni / Scudi", "%d / %d" % [int(dati.get("cannoni", 0)), int(dati.get("scudi", 0))]]]
		for i in righe.size():
			_t(UI.font_testo, Vector2(r.position.x + 12, y + 16 + i * 22), str(righe[i][0]), 14, Color(0.1, 0.15, 0.25))
			_t(UI.font_titolo, Vector2(r.end.x - 70, y + 17 + i * 22), str(righe[i][1]), 17, Color(0.1, 0.15, 0.25))
		y += 74
	var testo_p := str(dati.get("it", ""))
	if dati.get("tipo", "") == "astronave":
		testo_p = testo_p.get_slice("Proprietari", 0).strip_edges() if "Proprietari" in testo_p else ""
		if dati.get("proprietario", null) != null:
			testo_p = "Appartiene a %s." % dati["proprietario"]
	_testo_a_capo(testo_p, Rect2(r.position.x + 10, y + 6, r.size.x - 20, r.end.y - y - 40), 13, Color(0.1, 0.12, 0.18))
	_t(UI.font_grassetto, Vector2(r.position.x + 10, r.end.y - 14), str(dati.get("riparazione_it", "")), 11, Color(0.3, 0.3, 0.4))


func _missione(r: Rect2) -> void:
	var col := Color(0.55, 0.12, 0.35)
	_cornice(r, col, Color(0.98, 0.92, 0.9))
	var y := _intestazione(r, col, "Missione (%s)" % dati.get("lettera", ""), str(dati.get("nome_it", "")), int(dati.get("nr", 0)))
	var it: Dictionary = dati.get("it", {})
	var testo := "%s\n\n%s\n\nRisultato: %s" % [it.get("descrizione", ""), it.get("restrizioni", ""), it.get("risultato", "")]
	if str(it.get("bonus", "")) != "":
		testo += "\n\nPescate bonus: " + str(it["bonus"])
	_testo_a_capo(testo.replace("\n\n\n\n", "\n\n"), Rect2(r.position.x + 10, y + 4, r.size.x - 20, r.end.y - y - 10), 11, Color(0.18, 0.08, 0.1))


func _azione(r: Rect2) -> void:
	var col := Color(0.82, 0.30, 0.12)
	_cornice(r, col, Color(0.99, 0.94, 0.86))
	var y := _intestazione(r, col, "Azione", "Carta Azione", int(dati.get("nr", 0)))
	var sez := [["urbano", "Urbano"], ["speciale", "Speciale"], ["selvaggio", "Selvaggio"]]
	var hh := (r.end.y - y - 8) / 3.0
	for i in 3:
		var k: String = sez[i][0]
		var box := Rect2(r.position.x + 6, y + i * hh, r.size.x - 12, hh - 4)
		if sezione == k:
			draw_rect(box, Color(1, 0.85, 0.3, 0.45))
		var lett: Array = dati.get("en", {}).get(k, {}).get("lettere", [])
		_t(UI.font_titolo, box.position + Vector2(4, 16), sez[i][1].to_upper() + ":  " + " ".join(lett), 15, Color(0.55, 0.12, 0.05))
		_testo_a_capo(str(dati.get("it", {}).get(k, {}).get("evento", "")), Rect2(box.position.x + 4, box.position.y + 20, box.size.x - 8, box.size.y - 22), 10, Color(0.15, 0.08, 0.05))


func _t(f: Font, p: Vector2, s: String, sz: int, c: Color) -> void:
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)


func _testo_a_capo(s: String, r: Rect2, sz: int, c: Color) -> void:
	var f := UI.font_testo
	# riduce il corpo finché il testo entra
	var size_ok := sz
	while size_ok > 8:
		var h := f.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, size_ok).y
		if h <= r.size.y:
			break
		size_ok -= 1
	draw_multiline_string(f, r.position + Vector2(0, size_ok), s, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, size_ok, -1, c)
