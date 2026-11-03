extends SceneTree
## Real game presentation: every category, original values, space/ground and secrecy.
func _init() -> void:
	UI.reborn = true
	var records = JSON.parse_string(FileAccess.get_file_as_string("res://reborn/truppe/data.json"))
	var rules: Dictionary = Dati.d()["regole_avanzate"]["unita"]
	for c in records:
		var d: Dictionary = rules[c["cat"]]
		var u := {"k": "mil", "fz": int(d["fz"]), "cat": c["cat"], "tipo": c["cat"], "amb": c["environ"], "forza": int(d["f"]), "spazio": int(d["s"]), "mobile": d["mobile"], "luogo": "142:0"}
		assert(UI.chiave_truppa(u) == c["key"])
		var before := u.duplicate(true)
		for position in ["terra", "orbita"]:
			u["luogo"] = "142:0" if position == "terra" else "142:o"
			assert(UI.truppa_in_spazio(u) == (position == "orbita"))
			assert(UI.truppa_path(u) == "res://assets/reborn/truppe/pedine/%s-%s.webp" % [c["key"], position])
			assert(UI.truppa_path(u, false, true) == "res://assets/reborn/truppe/figure/" + c["ground" if position == "terra" else "orbit"])
			assert(ResourceLoader.exists(UI.truppa_path(u)))
			assert(ResourceLoader.exists(UI.truppa_path(u, false, true)))
			assert(UI.truppa_tex(u).resource_path == UI.truppa_path(u))
			assert(UI.truppa_tex(u, false, true).resource_path == UI.truppa_path(u, false, true))
			assert(UI.truppa_carta(u) != null and UI.truppa_carta(u, true) == null)
			assert(UI.truppa_path(u, true).begins_with("res://assets/pedine/"))
			assert(UI.truppa_path(u, true).ends_with("_r.jpg"))
			assert(u["forza"] == before["forza"] and u["spazio"] == before["spazio"])
		for luogo in ["D:14", "D2:14", "S:14"]:
			u["luogo"] = luogo
			assert(UI.truppa_in_spazio(u))
			u["luogo"] = "morto"
			assert(not UI.truppa_in_spazio(u))
	# Basic scenarios do not have the advanced category or space fields.
	for tipo in ["milizia", "pattuglia", "linea"]:
		var u := {"fz": 1, "tipo": tipo, "forza": 1, "amb": "", "luogo": "142:o"}
		assert(UI.truppa_tex(u) != null)
	var rebel := {"fz": 0, "tipo": "rib", "forza": 2, "amb": "liquido", "luogo": "142:o"}
	assert(UI.chiave_truppa(rebel) == "rib_liquido_21")
	assert(UI.truppa_tex(rebel) != null)
	UI.reborn = false
	assert(UI.truppa_tex(rebel).resource_path.begins_with("res://assets/pedine/"))
	UI.reborn = true
	UI.carica_font()
	root.theme = UI.make_theme()
	var partita = load("res://scripts/ui/partita.gd").new()
	partita.config = {"scenario": "egrix", "seme": 142, "giocatori": [{"nome": "R", "ia": false}, {"nome": "I", "ia": false}]}
	root.add_child(partita)
	await process_frame
	var id := -1
	for candidate in partita.motore.unita:
		if partita.motore.unita[candidate]["k"] == "mil":
			id = int(candidate)
			break
	assert(id >= 0)
	var unit: Dictionary = partita.motore.unita[id]
	unit["scoperta"] = true
	partita._anteprima_truppa(id)
	await process_frame
	assert(partita._anteprima_truppa_id == id)
	assert(partita.popup_carta.get_child(0).texture == UI.truppa_carta(unit))
	unit["luogo"] = "221:o"
	partita._anteprima_truppa(id)
	await process_frame
	assert(partita.popup_carta.get_child(0).texture == UI.truppa_carta(unit))
	partita.vista = Motore.R
	unit["scoperta"] = false
	partita._anteprima_truppa(id)
	await process_frame
	assert(partita.popup_carta.get_child_count() == 0)
	partita.queue_free()
	await process_frame
	var motor := Motore.new()
	root.add_child(motor)
	motor.prepara({"scenario": "backdoor", "seme": 142, "giocatori": [{"nome": "R", "ia": false}, {"nome": "I", "ia": false}]})
	var view = load("res://scripts/ui/tavolo3d.gd").new()
	view.m = motor
	view.stella_vista = int(Dati.pianeta(int(motor.scenario_pianeti()[0]))["stella"])
	root.add_child(view)
	await process_frame
	var land := ""
	for luogo in view._piattaforme:
		if motor.is_amb(luogo):
			land = luogo
			break
	assert(land != "")
	var orbital := "%d:o" % motor.pid_di(land)
	assert(view._piattaforme.has(orbital))
	var troop := motor.nuova_unita(Motore.R, "r44", "liquido")
	for luogo in [land, orbital, land]:
		motor.unita[troop]["luogo"] = luogo
		view.aggiorna()
		await process_frame
		var sprites: Array = view._pedine_root.get_children().filter(func(n): return n is Sprite3D and n.get_meta("unit_id", -1) == troop)
		assert(sprites.size() == 1)
		assert(sprites[0].texture.resource_path == UI.truppa_path(motor.unita[troop], false, true))
		assert(is_equal_approx(sprites[0].pixel_size * sprites[0].texture.get_height(), 1.25 if luogo == orbital else 2.8))
	assert(motor.unita[troop]["forza"] == 4 and motor.unita[troop]["spazio"] == 4)
	view.queue_free()
	motor.queue_free()
	await process_frame
	print("TRUPPE OK: 40 tipi, superficie/orbita/deriva, valori invariati, unità nascoste e scenari base")
	quit(0)
