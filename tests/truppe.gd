extends SceneTree
## Real game presentation: every category, original values, space/ground and secrecy.
func _init() -> void:
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
			assert(UI.truppa_path(u) == "res://assets_reborn/truppe/pedine/%s-%s.png" % [c["key"], position])
			assert(UI.truppa_path(u, false, true) == "res://assets_reborn/truppe/" + c["ground" if position == "terra" else "orbit"])
			assert(ResourceLoader.exists(UI.truppa_path(u)))
			assert(ResourceLoader.exists(UI.truppa_path(u, false, true)))
			assert(UI.truppa_tex(u).resource_path == UI.truppa_path(u))
			assert(UI.truppa_tex(u, false, true).resource_path == UI.truppa_path(u, false, true))
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
	print("TRUPPE OK: 40 tipi, superficie/orbita/deriva, valori invariati, unità nascoste e scenari base")
	quit(0)
