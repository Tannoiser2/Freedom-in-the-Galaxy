extends Control
## Schermata di gioco: mappa 2D (o tavolo 3D) del sistema stellare, pannello delle decisioni,
## registro degli eventi, carte dei personaggi in italiano e salvataggi (dispositivo e Firebase).

signal scelta_fatta(v: int)

const SALVATAGGIO := "user://partita.json"
const RITMI := [["lento", 1.6], ["normale", 1.0], ["veloce", 0.45], ["istantaneo", 0.0]]

var main
var config: Dictionary = {}
var motore: Motore
var locale := ControlloLocale.new()
var online: SessioneOnline = null
var mappa
var tavolo3d
var vista := -1
var _ritmo := 1
var _in_attesa := false
var _richiesta: Dictionary = {}
var _posto_richiesta := -1
var _multi_sel: Dictionary = {}
var _ripresa := false

var lbl_turno: Label
var lbl_pv: Label
var lbl_online: Label
var scelta_titolo: Label
var scelta_testo: Label
var scelta_box: VBoxContainer
var registro: RichTextLabel
var carte_box: HBoxContainer
var area_mappa: Control
var popup_carta: Control
var b_3d: Button
var b_ritmo: Button
var b_firebase: Button
var _popup_timer := 0.0
var galassia_v
var b_galassia: Button
var lbl_risorse: Label
var _galassia_aperta := false
var _anteprima_aperta := false
var _anteprima_truppa_id := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cf := ConfigFile.new()
	if cf.load("user://impostazioni.cfg") == OK:
		_ritmo = int(cf.get_value("vista", "ritmo", 1))
	motore = Motore.new()
	add_child(motore)
	var cfg := config.duplicate()
	online = cfg.get("online", null)
	cfg.erase("online")
	motore.prepara(cfg)
	locale.vista = self
	var umani := []
	for i in 2:
		if not motore.giocatori[i]["ia"]:
			umani.append(i)
	if online != null:
		add_child(online)
		online.view = self
		online.locale = locale
		motore.controllori = [online, online]
		vista = online.seat
	else:
		for i in 2:
			if motore.giocatori[i]["ia"]:
				var cia := ControlloIA.new()
				cia.vista = self
				motore.controllori[i] = cia
			else:
				motore.controllori[i] = locale
		vista = umani[0] if umani.size() == 1 else -1
	_costruisci()
	motore.cambiato.connect(_aggiorna)
	motore.messaggio.connect(_al_messaggio)
	motore.evento.connect(_al_evento)
	motore.finita.connect(_alla_fine)
	motore.ritmo = RITMI[_ritmo][1]
	var scelte: Array = config.get("riprendi", [])
	if not scelte.is_empty():
		_ripresa = true
		motore.riprendi(scelte)
		motore.ripresa_finita.connect(func():
			_ripresa = false
			_al_messaggio("— Partita ripresa —")
			_aggiorna())
	if config.get("vista3d", false):
		_imposta_3d(true)
	_aggiorna()
	if online != null:
		online.battito()
	motore.gioca()


# =====================================================================================
# COSTRUZIONE
# =====================================================================================

func _costruisci() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	# barra superiore
	var barra := PanelContainer.new()
	barra.add_theme_stylebox_override("panel", UI.stile(Color(0.03, 0.04, 0.09, 0.95), UI.ROSSO_SCURO, 0, 0, 8))
	v.add_child(barra)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	barra.add_child(hb)
	var stretto := motore.livello != "sistema"
	var logo := UI.titolo("Freedom in the Galaxy", 24 if stretto else 30, UI.ROSSO)
	hb.add_child(logo)
	hb.add_child(UI.titolo("· " + motore.scenario["nome"], 20 if stretto else 24, UI.GIALLO))
	lbl_turno = UI.etichetta("", 17 if stretto else 19, UI.TESTO, true)
	hb.add_child(lbl_turno)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	lbl_online = UI.etichetta("", 17, UI.CIANO)
	hb.add_child(lbl_online)
	lbl_pv = UI.etichetta("", 16 if stretto else 18, UI.GIALLO, true)
	hb.add_child(lbl_pv)
	if motore.livello != "sistema":
		lbl_risorse = UI.etichetta("", 17, UI.CIANO)
		hb.add_child(lbl_risorse)
		b_galassia = UI.bottone("Galassia", 17)
		b_galassia.pressed.connect(func(): _mostra_galassia(not _galassia_aperta))
		hb.add_child(b_galassia)
	b_3d = UI.bottone("Vista 3D", 17)
	b_3d.pressed.connect(func(): _imposta_3d(tavolo3d == null or not tavolo3d.visible))
	hb.add_child(b_3d)
	b_ritmo = UI.bottone("", 17)
	b_ritmo.pressed.connect(func():
		_ritmo = (_ritmo + 1) % RITMI.size()
		_applica_ritmo())
	hb.add_child(b_ritmo)
	var b_mis := UI.bottone("Missioni", 17)
	b_mis.pressed.connect(_mostra_missioni)
	hb.add_child(b_mis)
	if online == null:
		b_firebase = UI.bottone("Salva online" if stretto else "Salva su Firebase", 17)
		b_firebase.pressed.connect(_salva_firebase)
		hb.add_child(b_firebase)
	var b_reg := UI.bottone("Regole", 17)
	b_reg.pressed.connect(_mostra_regole)
	hb.add_child(b_reg)
	var b_menu := UI.bottone("Menu", 17)
	b_menu.pressed.connect(_torna_menu)
	hb.add_child(b_menu)
	_applica_ritmo()
	# corpo
	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 6)
	v.add_child(corpo)
	area_mappa = Control.new()
	area_mappa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area_mappa.size_flags_stretch_ratio = 3.2
	area_mappa.clip_contents = true
	corpo.add_child(area_mappa)
	mappa = preload("res://scripts/ui/mappa.gd").new()
	mappa.m = motore
	mappa.vista = vista
	mappa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mappa.luogo_cliccato.connect(_clic_luogo)
	mappa.pedina_cliccata.connect(_clic_pedina)
	mappa.pedina_sorvolata.connect(_anteprima_truppa)
	mappa.mouse_exited.connect(func():
		mappa._hover_unita = -1
		_anteprima_truppa(-1))
	area_mappa.add_child(mappa)
	if motore.livello != "sistema":
		mappa.stella_vista = _stella_iniziale()
		galassia_v = preload("res://scripts/ui/galassia_vista.gd").new()
		galassia_v.m = motore
		galassia_v.vista = vista
		galassia_v.stella_corrente = mappa.stella_vista
		galassia_v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		galassia_v.stella_scelta.connect(_apri_stella)
		galassia_v.visible = false
		area_mappa.add_child(galassia_v)
	popup_carta = Control.new()
	popup_carta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_carta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area_mappa.add_child(popup_carta)
	# colonna destra
	var dx := VBoxContainer.new()
	dx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dx.custom_minimum_size.x = 420
	dx.add_theme_constant_override("separation", 6)
	corpo.add_child(dx)
	var ps := UI.pannello(Color(0.05, 0.07, 0.15, 0.96), UI.GIALLO, 2)
	ps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ps.size_flags_stretch_ratio = 1.4
	dx.add_child(ps)
	var vs := VBoxContainer.new()
	vs.add_theme_constant_override("separation", 6)
	ps.add_child(vs)
	scelta_titolo = UI.titolo("", 22, UI.GIALLO)
	scelta_titolo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vs.add_child(scelta_titolo)
	scelta_testo = UI.testo_lungo("", 17)
	vs.add_child(scelta_testo)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vs.add_child(sc)
	scelta_box = VBoxContainer.new()
	scelta_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scelta_box.add_theme_constant_override("separation", 5)
	sc.add_child(scelta_box)
	var pr := UI.pannello(Color(0.03, 0.04, 0.09, 0.94), UI.ROSSO_SCURO, 1)
	pr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dx.add_child(pr)
	registro = RichTextLabel.new()
	registro.bbcode_enabled = true
	registro.scroll_following = true
	registro.add_theme_font_size_override("normal_font_size", 15)
	registro.add_theme_font_size_override("bold_font_size", 15)
	pr.add_child(registro)
	# carte in basso
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.stile(Color(0.03, 0.04, 0.09, 0.9), UI.ROSSO_SCURO, 0, 0, 6))
	pc.custom_minimum_size.y = 236
	v.add_child(pc)
	var sc2 := ScrollContainer.new()
	sc2.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(sc2)
	carte_box = HBoxContainer.new()
	carte_box.add_theme_constant_override("separation", 8)
	sc2.add_child(carte_box)


func _applica_ritmo() -> void:
	b_ritmo.text = "Ritmo: %s" % RITMI[_ritmo][0]
	if motore != null:
		motore.ritmo = RITMI[_ritmo][1]
	var cf := ConfigFile.new()
	cf.load("user://impostazioni.cfg")
	cf.set_value("vista", "ritmo", _ritmo)
	cf.save("user://impostazioni.cfg")


func _stella_iniziale() -> int:
	var cap := motore.galattico.capitale_di(motore.provincia) if motore.livello == "provincia" else 16
	return int(cap / 10) if cap > 0 else int(motore.scenario_pianeti()[0] / 10)


func _mostra_galassia(on: bool) -> void:
	if galassia_v == null:
		return
	_galassia_aperta = on
	galassia_v.visible = on
	if on:
		galassia_v.stella_corrente = mappa.stella_vista
		mappa.visible = false
		if tavolo3d != null:
			tavolo3d.visible = false
	else:
		var tre_d: bool = tavolo3d != null and b_3d.text == "Mappa 2D"
		mappa.visible = not tre_d
		if tavolo3d != null:
			tavolo3d.visible = tre_d
			if tre_d:
				tavolo3d.aggiorna()
	b_galassia.text = "Sistema" if on else "Galassia"
	area_mappa.move_child(popup_carta, -1)


func _apri_stella(st: int) -> void:
	mappa.stella_vista = st
	if galassia_v != null:
		galassia_v.stella_corrente = st
	if tavolo3d != null:
		tavolo3d.imposta_stella(st)
	_mostra_galassia(false)
	mappa.queue_redraw()


func _imposta_3d(on: bool) -> void:
	if on and tavolo3d == null:
		tavolo3d = preload("res://scripts/ui/tavolo3d.gd").new()
		tavolo3d.m = motore
		tavolo3d.vista = vista
		tavolo3d.stella_vista = mappa.stella_vista
		tavolo3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tavolo3d.luogo_cliccato.connect(_clic_luogo)
		area_mappa.add_child(tavolo3d)
		area_mappa.move_child(popup_carta, -1)
	if tavolo3d != null:
		tavolo3d.visible = on
		if on:
			tavolo3d.aggiorna()
	mappa.visible = not on
	b_3d.text = "Mappa 2D" if on else "Vista 3D"
	if _galassia_aperta:
		_mostra_galassia(false)


# =====================================================================================
# AGGIORNAMENTO
# =====================================================================================

func _aggiorna() -> void:
	if _ripresa:
		return
	var fasi := {"schieramento": "schieramento", "movimento": "movimento", "reazione": "reazione", "combattimento": "combattimento militare", "ricerca": "ricerca", "missioni": "missioni", "finita": "partita finita",
		"interplanetario": "movimento interplanetario", "spazio": "combattimento spaziale", "personaggi": "movimento dei personaggi", "superficie": "movimento di superficie", "stadio": "stadio galattico", "risorse": "risorse"}
	lbl_turno.text = "  Turno %d/%d%s · %s · %s" % [motore.turno, int(motore.scenario["turni"]), (" · mese %d" % (motore.giro + 1)) if motore.livello == "galassia" else "", Dati.FAZIONI[motore.di_turno], fasi.get(motore.fase, "")]
	var pv := motore.punti_vittoria()
	lbl_pv.text = ("PV ribelli: %d / %d" if motore.livello != "sistema" else "Punti Vittoria ribelli: %d / %d") % [pv["totale"], pv["soglia"]]
	lbl_pv.tooltip_text = "\n".join(pv["dettaglio"]) if not pv["dettaglio"].is_empty() else "Nessun punto per ora."
	mappa.queue_redraw()
	if tavolo3d != null and tavolo3d.visible:
		tavolo3d.aggiorna()
	if lbl_risorse != null:
		if motore.livello == "galassia":
			lbl_risorse.text = "Risorse R %d · I %d" % [int(motore.pf[Motore.R]), int(motore.pf[Motore.I])]
			var g := motore.galattico
			var tt := []
			if not g.strategico.is_empty():
				tt.append("Incarico strategico: " + str(g.strategico["it"]))
			if not g.evento_corrente.is_empty():
				tt.append("Evento galattico: %s\n%s" % [g.evento_corrente["titolo_it"], g.evento_corrente["it"]])
			lbl_risorse.tooltip_text = "\n\n".join(tt)
		else:
			lbl_risorse.text = ""
	_aggiorna_carte()


func _aggiorna_carte() -> void:
	for c in carte_box.get_children():
		c.queue_free()
	var lati := [vista] if vista >= 0 else [motore.di_turno]
	if _posto_richiesta >= 0 and vista < 0:
		lati = [_posto_richiesta]
	for f in lati:
		var ids := []
		for id in motore.unita:
			var u: Dictionary = motore.unita[id]
			if u["k"] == "pg" and u["fz"] == f:
				ids.append(id)
		ids.sort()
		for id in ids:
			var u2: Dictionary = motore.unita[id]
			var c = preload("res://scripts/ui/carta.gd").new("personaggio", u2["c"])
			c.m = motore
			c.id_unita = id
			c.custom_minimum_size = Vector2(158, 224)
			_carta_reborn(c, "personaggio", u2["c"])
			c.modulate = Color(1, 1, 1, 0.45) if u2["luogo"] == "morto" else Color.WHITE
			carte_box.add_child(c)
			for nr in u2["poss"]:
				var cp = preload("res://scripts/ui/carta.gd").new("possesso", Dati.d()["poss"][int(nr)])
				cp.custom_minimum_size = Vector2(150, 224)
				_carta_reborn(cp, "possesso", Dati.d()["poss"][int(nr)])
				carte_box.add_child(cp)
			if not u2["nave"].is_empty() and int(u2["nave"].get("nr", 0)) > 0:
				var cn = preload("res://scripts/ui/carta.gd").new("possesso", Dati.d()["poss"][int(u2["nave"]["nr"])])
				cn.custom_minimum_size = Vector2(150, 224)
				_carta_reborn(cn, "possesso", Dati.d()["poss"][int(u2["nave"]["nr"])])
				carte_box.add_child(cn)


# =====================================================================================
# DECISIONI DELLA PERSONA
# =====================================================================================

func chiedi_persona(_m: Motore, posto: int, req: Dictionary) -> int:
	_richiesta = req
	_posto_richiesta = posto
	_in_attesa = true
	_salva_locale()
	_mostra_richiesta(posto, req)
	_aggiorna()
	var r: int = await scelta_fatta
	_in_attesa = false
	_richiesta = {}
	_svuota(scelta_box)
	mappa.evidenzia({})
	mappa.selezionati = {}
	if tavolo3d != null:
		tavolo3d.evidenzia({})
	scelta_titolo.text = ""
	scelta_testo.text = ""
	return r


func _mostra_richiesta(posto: int, req: Dictionary) -> void:
	var persone := 0
	for g in motore.giocatori:
		if not g["ia"]:
			persone += 1
	scelta_titolo.text = ("Tocca a: %s" % Dati.FAZIONI[posto]) if persone > 1 and online == null else "La tua decisione"
	scelta_titolo.add_theme_color_override("font_color", UI.colore_fazione(posto))
	scelta_testo.text = req.get("testo", "")
	_svuota(scelta_box)
	var opz: Array = req.get("opzioni", [])
	if req.get("tipo", "") == "multi":
		_multi_sel = {}
		for k in opz.size():
			var cb := CheckBox.new()
			cb.text = opz[k]["t"]
			cb.add_theme_font_size_override("font_size", 17)
			cb.toggled.connect(func(b):
				if b:
					_multi_sel[k] = true
				else:
					_multi_sel.erase(k)
				_evidenzia_multi())
			if opz[k].has("id"):
				var id: int = opz[k]["id"]
				cb.mouse_entered.connect(func(): _mostra_info_pedina(id))
			scelta_box.add_child(cb)
		var hb := HBoxContainer.new()
		var b_tutti := UI.bottone("Tutti", 16)
		b_tutti.pressed.connect(func():
			for c in scelta_box.get_children():
				if c is CheckBox:
					c.button_pressed = true)
		hb.add_child(b_tutti)
		var b_ok := UI.bottone("Conferma", 18)
		b_ok.add_theme_color_override("font_color", UI.GIALLO)
		b_ok.pressed.connect(func():
			var mx := int(req.get("max", 999))
			var mn := int(req.get("min", 0))
			if _multi_sel.size() < mn:
				scelta_testo.text = req.get("testo", "") + "\nScegline almeno %d." % mn
				return
			if _multi_sel.size() > mx:
				scelta_testo.text = req.get("testo", "") + "\nAl massimo %d." % mx
				return
			var mask := 0
			for k in _multi_sel:
				mask |= 1 << int(k)
			_premi(mask))
		hb.add_child(b_ok)
		scelta_box.add_child(hb)
	else:
		for k in opz.size():
			var b := UI.bottone(opz[k]["t"], 16)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size.y = 38
			if opz[k].get("fine", false) or k == opz.size() - 1 and str(opz[k]["t"]).begins_with("Fine"):
				b.add_theme_color_override("font_color", UI.GIALLO)
			b.pressed.connect(_premi.bind(k))
			if opz[k].has("luogo"):
				var l: String = opz[k]["luogo"]
				b.mouse_entered.connect(func():
					mappa.evidenzia({l: Color(1, 1, 1)})
					if tavolo3d != null:
						tavolo3d.evidenzia({l: Color(1, 1, 1)}))
				b.mouse_exited.connect(_evidenzia_richiesta)
			if opz[k].has("id"):
				var id2: int = opz[k]["id"]
				b.mouse_entered.connect(func(): _mostra_info_pedina(id2))
			scelta_box.add_child(b)
	_evidenzia_richiesta()


func _mostra_info_pedina(id: int) -> void:
	if motore.unita.has(id):
		mappa.selezionati = {id: true}
		mappa.queue_redraw()


func _evidenzia_multi() -> void:
	var sel := {}
	var opz: Array = _richiesta.get("opzioni", [])
	for k in _multi_sel:
		if opz[k].has("id"):
			sel[opz[k]["id"]] = true
	mappa.selezionati = sel
	mappa.queue_redraw()


func _evidenzia_richiesta() -> void:
	var ev := {}
	var chiave: String = _richiesta.get("chiave", "")
	for o in _richiesta.get("opzioni", []):
		if o.has("luogo"):
			var col := Color(0.4, 1, 0.45)
			if chiave in ["dichiara_battaglia", "ricerca"]:
				col = Color(1, 0.4, 0.3)
			ev[o["luogo"]] = col
	if _richiesta.has("luogo") and ev.is_empty():
		ev[_richiesta["luogo"]] = Color(1, 0.85, 0.3)
	mappa.evidenzia(ev)
	if tavolo3d != null:
		tavolo3d.evidenzia(ev)
	if galassia_v != null:
		galassia_v.evidenzia(ev)
		if not ev.is_empty() and _in_attesa:
			var stelle := {}
			for l in ev:
				var st := motore.av.stella_di(str(l))
				if st > 0 and galassia_v._stelle_scenario().has(st):
					stelle[st] = true
			if not stelle.is_empty() and not stelle.has(mappa.stella_vista):
				if stelle.size() == 1:
					_apri_stella(stelle.keys()[0])
				elif not _galassia_aperta:
					_mostra_galassia(true)


func _clic_luogo(l: String) -> void:
	if not _in_attesa or _richiesta.get("tipo", "") == "multi":
		return
	var opz: Array = _richiesta.get("opzioni", [])
	for k in opz.size():
		if opz[k].get("luogo", "") == l:
			_premi(k)
			return


func _clic_pedina(id: int) -> void:
	if not _in_attesa:
		return
	var opz: Array = _richiesta.get("opzioni", [])
	if _richiesta.get("tipo", "") == "multi":
		var i := 0
		for c in scelta_box.get_children():
			if c is CheckBox:
				if opz[i].get("id", -1) == id:
					c.button_pressed = not c.button_pressed
				i += 1
		return
	for k in opz.size():
		if opz[k].get("id", -1) == id and not opz[k].has("luogo"):
			_premi(k)
			return
	# movimento: clic sulla truppa
	for k in opz.size():
		if opz[k].get("tipo", "") == "truppe" and motore.unita[id]["k"] == "mil" and motore.unita[id]["luogo"] == opz[k]["luogo"] and motore.unita[id]["fz"] == _posto_richiesta:
			_premi(k)
			return


func _premi(k: int) -> void:
	if not _in_attesa:
		return
	scelta_fatta.emit(k)


func mostra_pensiero(posto: int, req: Dictionary) -> void:
	if _in_attesa or _ripresa:
		return
	scelta_titolo.text = "%s: l'IA decide…" % Dati.FAZIONI[posto]
	scelta_titolo.add_theme_color_override("font_color", UI.colore_fazione(posto))
	scelta_testo.text = str(req.get("testo", ""))
	_svuota(scelta_box)


func online_attesa(s: int) -> void:
	lbl_online.text = "" if s < 0 else "In attesa di %s…" % motore.giocatori[s]["nome"]


func online_stato(t: String) -> void:
	lbl_online.text = t


func _svuota(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


# =====================================================================================
# EVENTI DEL MOTORE
# =====================================================================================

func _al_messaggio(t: String) -> void:
	if registro == null or _ripresa:
		return
	if t.begins_with("—"):
		registro.append_text("\n[color=#f5c738][b]%s[/b][/color]" % t)
	elif t.ends_with(": turno %d." % motore.turno):
		var col := "#e2513a" if t.begins_with("Ribelli") else "#f5bd33"
		registro.append_text("\n[color=%s][b]%s[/b][/color]" % [col, t])
	elif "RIBELLIONE" in t or "vittoria" in t.to_lower() or "Vince" in t or "vincono" in t:
		registro.append_text("\n[color=#ff8060][b]%s[/b][/color]" % t)
	elif t.begins_with("Carta Azione"):
		registro.append_text("\n[color=#9fd4ff]%s[/color]" % t)
	else:
		registro.append_text("\n" + t)


func _al_evento(tipo: String, dati: Dictionary) -> void:
	if _ripresa:
		return
	match tipo:
		"carta_azione":
			var carta := {}
			for c in Dati.d()["carte"]["azione"]:
				if int(c["nr"]) == int(dati["nr"]):
					carta = c
			_mostra_popup_carta("azione", carta, dati.get("sezione", ""))
		"volo", "volo_truppe":
			mappa.anima_volo(dati["da"], dati["a"], dati["f"])
			if tavolo3d != null:
				tavolo3d.anima_volo(dati["da"], dati["a"], dati["f"])
		"turno":
			_salva_locale()
		"fine":
			pass
	_aggiorna()


## Con la grafica Reborn la carta prende le proporzioni nuove e si ingrandisce al passaggio del mouse.
func _carta_reborn(c: Control, tipo: String, dati: Dictionary) -> void:
	var t := UI.carta_reborn_di(tipo, dati)
	if t == null:
		return
	c.custom_minimum_size = Vector2(round(c.custom_minimum_size.y * t.get_width() / t.get_height()), c.custom_minimum_size.y)
	c.tooltip_text = ""
	c.mouse_entered.connect(func(): _anteprima_carta(t))
	c.mouse_exited.connect(func(): _svuota(popup_carta))


## Carta Reborn ingrandita mentre il mouse le passa sopra.
func _anteprima_truppa(id: int) -> void:
	if _anteprima_truppa_id >= 0:
		_svuota(popup_carta)
		_anteprima_truppa_id = -1
	if not UI.reborn or not motore.unita.has(id):
		return
	var u: Dictionary = motore.unita[id]
	if u["k"] != "mil":
		return
	var nascosta: bool = u["fz"] == Motore.I and u["mobile"] and not u["scoperta"] and vista == Motore.R
	var texture := UI.truppa_carta(u, nascosta)
	if texture != null:
		_anteprima_carta(texture)
		_anteprima_aperta = false
		_anteprima_truppa_id = id


## Carta Reborn ingrandita mentre il mouse le passa sopra.
func _anteprima_carta(t: Texture2D) -> void:
	_svuota(popup_carta)
	if t == null:
		return
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := minf(area_mappa.size.y - 20, 760.0)
	tr.size = Vector2(h * t.get_width() / t.get_height(), h)
	tr.position = Vector2(area_mappa.size.x - tr.size.x - 12, area_mappa.size.y - h - 10)
	popup_carta.add_child(tr)
	_anteprima_aperta = true


func _mostra_popup_carta(tipo: String, dati: Dictionary, sezione := "") -> void:
	_svuota(popup_carta)
	var c = preload("res://scripts/ui/carta.gd").new(tipo, dati)
	c.sezione = sezione
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(250, 360)
	var tr := UI.carta_reborn_di(tipo, dati)
	if tr != null:
		var h := minf(600.0, area_mappa.size.y - 24)
		c.size = Vector2(h * tr.get_width() / tr.get_height(), h)
	c.position = Vector2(area_mappa.size.x - c.size.x - 12, area_mappa.size.y - c.size.y - 12)
	popup_carta.add_child(c)
	var tw := create_tween()
	c.modulate.a = 0.0
	tw.tween_property(c, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.4 * maxf(0.5, motore.ritmo))
	tw.tween_property(c, "modulate:a", 0.0, 0.4)
	tw.tween_callback(c.queue_free)


func _alla_fine(_esito: String) -> void:
	if online != null:
		online.chiudi()
	else:
		cancella_salvataggio()
	var pv := motore.punti_vittoria()
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.6)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(cc)
	var p := UI.pannello(UI.PANNELLO_CHIARO, UI.GIALLO, 3)
	p.custom_minimum_size.x = 720
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var vinc := motore.esito == "ribelli"
	v.add_child(UI.titolo("Vittoria dei Ribelli" if vinc else "Vittoria dell'Impero", 48, UI.COL_RIBELLI if vinc else UI.COL_IMPERO))
	var ultimo := ""
	for r in motore.registro:
		ultimo = r
	v.add_child(UI.testo_lungo(ultimo, 19))
	v.add_child(UI.testo_lungo("Punti Vittoria ribelli: %d (soglia %d)\n%s" % [pv["totale"], pv["soglia"], "\n".join(pv["dettaglio"])], 16, UI.GRIGIO))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	v.add_child(hb)
	var b1 := UI.bottone("Torna al menu", 20)
	b1.pressed.connect(_torna_menu)
	hb.add_child(b1)
	var b2 := UI.bottone("Chiudi e guarda la mappa", 20)
	b2.pressed.connect(fondo.queue_free)
	hb.add_child(b2)


# =====================================================================================
# SALVATAGGI
# =====================================================================================

func _cfg_salvabile() -> Dictionary:
	var cfg := config.duplicate()
	cfg.erase("online")
	cfg.erase("riprendi")
	cfg.erase("vista3d")
	cfg["seme"] = motore.seme
	return cfg


func _salva_locale() -> void:
	if online != null or motore.esito != "":
		return
	var f := FileAccess.open(SALVATAGGIO, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"config": _cfg_salvabile(), "scelte": motore.storia}))
		f.close()


static func cancella_salvataggio() -> void:
	if FileAccess.file_exists(SALVATAGGIO):
		DirAccess.remove_absolute(SALVATAGGIO)


func _salva_firebase() -> void:
	var net: Net = main.get_net()
	b_firebase.disabled = true
	b_firebase.text = "Salvo…"
	var code: String = config.get("codice_salvataggio", "")
	if not await net.sign_in():
		b_firebase.text = "Firebase non raggiungibile"
		b_firebase.disabled = false
		return
	if code == "":
		code = await net.create_room(str(net.load_session().get("name", "Comandante")), [0])
	if code == "":
		b_firebase.text = "Errore: riprova"
		b_firebase.disabled = false
		_al_messaggio("Salvataggio non riuscito: %s" % net.last_error)
		return
	var scelte := ",".join(motore.storia.map(func(x): return str(x)))
	var r := await net.db_patch(Net.ROOT + "/" + code, {"game": {"cfg": var_to_str(_cfg_salvabile()), "scelte": scelte}, "status": "salvata"})
	b_firebase.disabled = false
	if r["code"] == 200:
		config["codice_salvataggio"] = code
		net.remember_room(code)
		b_firebase.text = "Salvata: %s" % code
		_al_messaggio("— Partita salvata su Firebase con il codice %s: dal menu «Carica da Firebase» la riprendi su qualsiasi dispositivo. —" % code)
	else:
		b_firebase.text = "Errore: riprova"
		_al_messaggio("Salvataggio non riuscito: %s" % net.last_error)


# =====================================================================================
# PANNELLI
# =====================================================================================

func _mostra_missioni() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.7)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	fondo.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			fondo.queue_free())
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.offset_left = 40
	sc.offset_top = 70
	sc.offset_right = -40
	sc.offset_bottom = -40
	fondo.add_child(sc)
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	sc.add_child(g)
	for c in Dati.d()["carte"]["missione"]:
		if not c.get("usata_star_system", true):
			continue
		var cm = preload("res://scripts/ui/carta.gd").new("missione", c)
		cm.custom_minimum_size = Vector2(270, 390)
		var tm := UI.carta_reborn_di("missione", c)
		if tm != null:
			cm.custom_minimum_size = Vector2(270, round(270.0 * tm.get_height() / tm.get_width()))
		g.add_child(cm)
	var t := UI.titolo("Le missioni dello Star System Game (clic per chiudere, clic destro su una carta per l'originale)", 22)
	t.position = Vector2(40, 24)
	fondo.add_child(t)


func _mostra_regole() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.75)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var r = preload("res://scripts/ui/regole.gd").new()
	r.in_partita = true
	r.chiudi.connect(fondo.queue_free)
	fondo.add_child(r)


func _torna_menu() -> void:
	if online != null:
		online.alive = false
	else:
		_salva_locale()
	main.show_menu()


func _unhandled_key_input(ev: InputEvent) -> void:
	if not _in_attesa or not (ev is InputEventKey) or not ev.pressed or ev.echo or _richiesta.get("tipo", "") == "multi":
		return
	var n: int = ev.keycode - KEY_1
	if n >= 0 and n < 9 and n < _richiesta.get("opzioni", []).size():
		_premi(n)
		get_viewport().set_input_as_handled()


func _process(_d: float) -> void:
	# l'anteprima Reborn sparisce appena il mouse non è più su una carta (anche se la striscia è stata rifatta)
	if _anteprima_aperta:
		var h := get_viewport().gui_get_hovered_control()
		if h == null or not (h.get_script() == preload("res://scripts/ui/carta.gd")):
			_anteprima_aperta = false
			_svuota(popup_carta)
