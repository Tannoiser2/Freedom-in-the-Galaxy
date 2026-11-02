extends Control
## Menu iniziale: scenario, parte da giocare, partita online, partite salvate (sul dispositivo e su Firebase).

const SALVATAGGIO := "user://partita.json"

var main
var scenario := "egrix"
var modo := 0          # 0 Ribelli contro IA, 1 Impero contro IA, 2 due persone, 3 IA contro IA
var vista3d := false
var box_scenari: GridContainer
var box_modi: VBoxContainer
var stato: Label
var codice: LineEdit
var nome: LineEdit
var b_avvia_online: Button
var lobby := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scenario = main.menu_state.get("scenario", "egrix")
	modo = main.menu_state.get("modo", 0)
	vista3d = main.menu_state.get("vista3d", false)
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size.x = 1180
	cc.add_child(v)
	# logo
	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", -18)
	v.add_child(logo)
	var l1 := UI.titolo("Freedom", 112, UI.ROSSO)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var l2 := HBoxContainer.new()
	l2.alignment = BoxContainer.ALIGNMENT_CENTER
	l2.add_theme_constant_override("separation", 18)
	l2.add_child(UI.titolo("in the", 40, UI.GIALLO))
	l2.add_child(UI.titolo("Galaxy", 112, UI.ROSSO))
	logo.add_child(l1)
	logo.add_child(l2)
	var sub := UI.titolo("La Ribellione stellare, 5764 d.C.", 28, Color(0.7, 0.85, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var cred := UI.etichetta("Da Freedom in the Galaxy di Howard Barasch e John H. Butterfield, SPI 1979 · Star System, Province e Galactic Game", 16, UI.GRIGIO)
	cred.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cred)
	# scenari
	v.add_child(UI.titolo("Scenario", 26))
	box_scenari = GridContainer.new()
	box_scenari.columns = 3
	box_scenari.add_theme_constant_override("h_separation", 12)
	box_scenari.add_theme_constant_override("v_separation", 12)
	v.add_child(box_scenari)
	# modo
	v.add_child(UI.titolo("Chi gioca", 26))
	box_modi = VBoxContainer.new()
	v.add_child(box_modi)
	var c3 := CheckBox.new()
	c3.text = "Apri la partita nella vista 3D"
	c3.button_pressed = vista3d
	c3.toggled.connect(func(b): vista3d = b)
	v.add_child(c3)
	var c4 := CheckBox.new()
	c4.text = "Grafica Reborn (carte personaggio, pedine e pianeti ridisegnati)"
	c4.button_pressed = UI.reborn
	c4.toggled.connect(func(b): UI.salva_reborn(b))
	v.add_child(c4)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	v.add_child(hb)
	var b_nuova := UI.bottone("Nuova partita", 24)
	b_nuova.custom_minimum_size = Vector2(260, 56)
	b_nuova.pressed.connect(_nuova)
	hb.add_child(b_nuova)
	var salv := salvataggio()
	if not salv.is_empty():
		var b_rip := UI.bottone("Riprendi la partita salvata", 20)
		b_rip.custom_minimum_size.y = 56
		b_rip.pressed.connect(func(): _riprendi(salv))
		hb.add_child(b_rip)
	var b_reg := UI.bottone("Regole", 20)
	b_reg.custom_minimum_size.y = 56
	b_reg.pressed.connect(func(): main.show_rules())
	hb.add_child(b_reg)
	# online e Firebase
	var po := UI.pannello()
	v.add_child(po)
	var vo := VBoxContainer.new()
	vo.add_theme_constant_override("separation", 8)
	po.add_child(vo)
	vo.add_child(UI.titolo("Online e salvataggi su Firebase", 24, UI.CIANO))
	vo.add_child(UI.testo_lungo("Per giocare con un amico: scegli lo scenario, imposta «Due persone», crea la stanza e passagli il codice. Chi crea la stanza guida i Ribelli. Le partite salvate su Firebase si riprendono da qualsiasi dispositivo con lo stesso codice.", 16, UI.GRIGIO))
	var ho := HBoxContainer.new()
	ho.add_theme_constant_override("separation", 10)
	vo.add_child(ho)
	ho.add_child(UI.etichetta("Nome:", 18))
	nome = LineEdit.new()
	nome.custom_minimum_size.x = 220
	nome.text = str(main.get_net().load_session().get("name", "Comandante"))
	ho.add_child(nome)
	var b_crea := UI.bottone("Crea una stanza", 18)
	b_crea.pressed.connect(_crea)
	ho.add_child(b_crea)
	codice = LineEdit.new()
	codice.placeholder_text = "Codice"
	codice.max_length = 4
	codice.custom_minimum_size.x = 110
	ho.add_child(codice)
	var b_entra := UI.bottone("Entra", 18)
	b_entra.pressed.connect(_entra)
	ho.add_child(b_entra)
	var b_carica := UI.bottone("Carica da Firebase", 18)
	b_carica.pressed.connect(_carica_firebase)
	ho.add_child(b_carica)
	b_avvia_online = UI.bottone("Inizia la partita online", 20)
	b_avvia_online.visible = false
	b_avvia_online.pressed.connect(_avvia_online)
	vo.add_child(b_avvia_online)
	stato = UI.testo_lungo("", 17, UI.GIALLO)
	vo.add_child(stato)
	var vecchia := str(main.get_net().load_session().get("room", ""))
	if vecchia != "":
		codice.text = vecchia
		stato.text = "Ultima stanza o salvataggio: %s." % vecchia
	_aggiorna()


func _aggiorna() -> void:
	for c in box_scenari.get_children():
		c.queue_free()
	for c in box_modi.get_children():
		c.queue_free()
	var S: Dictionary = Dati.d()["scenari"]
	for k in ["egrix", "varu", "backdoor", "orlog", "galattica"]:
		var s: Dictionary = S[k]
		var p := UI.pannello(UI.PANNELLO_CHIARO if k == scenario else UI.PANNELLO, UI.GIALLO if k == scenario else UI.ROSSO_SCURO, 3 if k == scenario else 2)
		p.custom_minimum_size = Vector2(385, 0)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var vv := VBoxContainer.new()
		vv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(vv)
		var liv := {"sistema": "STAR SYSTEM GAME", "provincia": "PROVINCE GAME", "galassia": "GALACTIC GAME"}
		var lv := UI.etichetta(liv.get(str(s.get("livello", "sistema")), ""), 13, UI.ROSSO)
		lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vv.add_child(lv)
		var t := UI.titolo(s["nome"], 26, UI.GIALLO if k == scenario else UI.TESTO)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vv.add_child(t)
		var sub := UI.etichetta("%s · %s · %d turni" % [s["nome_en"], "Inizio della Ribellione" if s["tipo"] == "S" else "Armageddon", int(s["turni"])], 15, UI.CIANO)
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vv.add_child(sub)
		var d := UI.testo_lungo(s["testo"], 14)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vv.add_child(d)
		p.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				scenario = k
				_aggiorna())
		box_scenari.add_child(p)
	var modi := ["Gioco i Ribelli contro l'Impero dell'IA", "Gioco l'Impero contro i Ribelli dell'IA", "Due persone sullo stesso schermo (o online)", "Guardo l'IA giocare contro se stessa"]
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	box_modi.add_child(hb)
	for i in modi.size():
		var b := UI.bottone(modi[i], 16)
		b.toggle_mode = true
		b.button_pressed = i == modo
		b.custom_minimum_size = Vector2(285, 52)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func():
			modo = i
			_aggiorna())
		hb.add_child(b)


func _config() -> Dictionary:
	var g := [{"nome": "Ribelli", "ia": modo in [1, 3]}, {"nome": "Impero", "ia": modo in [0, 3]}]
	main.menu_state = {"scenario": scenario, "modo": modo, "vista3d": vista3d}
	return {"scenario": scenario, "giocatori": g, "seme": 1 + randi() % 2000000000, "vista3d": vista3d}


func _nuova() -> void:
	main.start_game(_config())


static func salvataggio() -> Dictionary:
	if not FileAccess.file_exists(SALVATAGGIO):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(SALVATAGGIO))
	return d if d is Dictionary and d.has("config") else {}


func _riprendi(s: Dictionary) -> void:
	var cfg: Dictionary = s["config"]
	cfg["riprendi"] = s.get("scelte", [])
	cfg["vista3d"] = vista3d
	main.start_game(cfg)


# ------------------------------------------------------------------------------------
# Firebase
# ------------------------------------------------------------------------------------

func _carica_firebase() -> void:
	var code := codice.text.strip_edges().to_upper()
	if code.length() != 4:
		stato.text = "Scrivi il codice di 4 lettere del salvataggio."
		return
	stato.text = "Carico %s…" % code
	var net: Net = main.get_net()
	if not await net.sign_in():
		stato.text = "Firebase non raggiungibile: %s" % net.last_error
		return
	var room := await net.room(code)
	var g = room.get("game", {})
	if not (g is Dictionary) or not g.has("cfg"):
		stato.text = "Nessuna partita con il codice %s." % code
		return
	var cfg = str_to_var(str(g["cfg"]))
	if not (cfg is Dictionary):
		stato.text = "Salvataggio non valido."
		return
	if room.get("status", "") == "playing":
		# partita online: si rientra al proprio posto
		_entra()
		return
	var scelte := []
	for x in str(g.get("scelte", "")).split(",", false):
		scelte.append(int(x))
	cfg["riprendi"] = scelte
	cfg["vista3d"] = vista3d
	cfg["codice_salvataggio"] = code
	net.remember_room(code)
	main.start_game(cfg)


func _crea() -> void:
	var cfg := _config()
	var nm := nome.text.strip_edges()
	if nm == "":
		stato.text = "Scrivi il tuo nome."
		return
	var seats := []
	for i in 2:
		if not cfg["giocatori"][i]["ia"]:
			seats.append(i)
	if seats.is_empty():
		stato.text = "Con «IA contro IA» non servono stanze: scegli chi gioca."
		return
	var net: Net = main.get_net()
	stato.text = "Creo la stanza…"
	var code := await net.create_room(nm, seats)
	if code == "":
		stato.text = "Non riesco a creare la stanza.\n%s" % net.last_error
		return
	lobby = {"role": "host", "code": code, "seat": seats[0]}
	net.remember_room(code, seats[0])
	net._save({"name": nm})
	codice.text = code
	b_avvia_online.visible = true
	_lobby_poll(code)


func _entra() -> void:
	var code := codice.text.strip_edges().to_upper()
	var nm := nome.text.strip_edges()
	if code.length() != 4 or nm == "":
		stato.text = "Scrivi il tuo nome e il codice di 4 lettere."
		return
	var net: Net = main.get_net()
	stato.text = "Entro nella stanza %s…" % code
	var seat := await net.join_room(code, nm)
	if seat < 0:
		stato.text = "Stanza %s non trovata, piena, oppure la partita è già iniziata.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""]
		return
	var room: Dictionary = net.last_room
	lobby = {"role": "host" if room.get("host", "") == net.uid else "guest", "code": code, "seat": seat}
	net.remember_room(code, seat)
	net._save({"name": nm})
	if room.get("status", "") == "playing" and room.has("game"):
		_avvia(room["game"], true)
		return
	b_avvia_online.visible = lobby["role"] == "host"
	_lobby_poll(code)


func _lobby_poll(code: String) -> void:
	var net: Net = main.get_net()
	while is_inside_tree() and lobby.get("code", "") == code:
		var room := await net.room(code)
		if not is_inside_tree() or lobby.get("code", "") != code:
			return
		if room.is_empty():
			stato.text = "La stanza %s non esiste più." % code
			lobby = {}
			return
		var seats := Net._as_dict(room.get("seats", {}))
		var nomi := []
		for k in seats:
			nomi.append("%s (%s)" % [seats[k].get("name", "?"), Dati.FAZIONI[int(k)]])
		if lobby["role"] == "host":
			stato.text = "Stanza [ %s ]: dai il codice al tuo avversario.\nPresenti: %s.\nQuando siete pronti premi «Inizia la partita online»." % [code, ", ".join(nomi)]
		else:
			if room.get("status", "") == "playing" and room.has("game"):
				_avvia(room["game"], false)
				return
			stato.text = "Sei nella stanza [ %s ] con %s. Presenti: %s.\nAspetta che chi l'ha creata avvii la partita." % [code, Dati.FAZIONI[int(lobby["seat"])], ", ".join(nomi)]
		await get_tree().create_timer(2.0).timeout


func _avvia_online() -> void:
	var code: String = lobby["code"]
	var net: Net = main.get_net()
	var room := await net.room(code)
	if room.is_empty():
		stato.text = "La stanza %s non esiste più." % code
		lobby = {}
		return
	var seats_db := Net._as_dict(room.get("seats", {}))
	var cfg := _config()
	for i in 2:
		var k := str(i)
		if seats_db.has(k) and not cfg["giocatori"][i]["ia"]:
			cfg["giocatori"][i]["nome"] = str(seats_db[k].get("name", cfg["giocatori"][i]["nome"]))
		else:
			cfg["giocatori"][i]["ia"] = true
	cfg.erase("vista3d")
	var g := {"cfg": var_to_str(cfg)}
	if not await net.start_room(code, g):
		stato.text = "Non riesco ad avviare la partita (%s)." % net.last_error
		return
	_avvia(g, false)


func _avvia(g: Dictionary, rientro: bool) -> void:
	var net: Net = main.get_net()
	var backlog: Array = []
	if rientro:
		backlog = await net.get_acts(lobby["code"])
		net.set_away(lobby["code"], int(lobby["seat"]), false)
	var cfg = str_to_var(str(g.get("cfg", "")))
	if not (cfg is Dictionary):
		stato.text = "Configurazione della partita non valida."
		return
	var ses := SessioneOnline.new()
	ses.setup(net, lobby["code"], int(lobby["seat"]), lobby["role"], backlog)
	cfg["online"] = ses
	cfg["vista3d"] = vista3d
	lobby = {}
	main.start_game(cfg)
