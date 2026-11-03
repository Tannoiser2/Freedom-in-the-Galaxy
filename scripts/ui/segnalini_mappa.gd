class_name SegnaliniMappa
extends RefCounted
## Posizione di pedine e segnalini sulle caselle della mappa originale della galassia
## (data/mappa_caselle.json, coordinate in pixel della mappa). Serve sia alla vista 2D sia a quella 3D:
## Lealtà sulla casella giusta della traccia politica, BDP, segreto e truppe in orbita nella casella
## d'Orbita, pedine e personaggi sulle caselle degli ambienti, truppe in deriva sulle caselle di Deriva.

const LATO := 44.0   # lato di una pedina in pixel della mappa (le caselle sono alte circa 55)


## Caselle cliccabili: [{luogo, c: Vector2, w, h, a}]
static func caselle(m: Motore) -> Array:
	var C: Dictionary = Dati.d()["mappa_caselle"]
	var out := []
	for pid in m.scenario_pianeti():
		var P: Dictionary = C["pianeti"].get(str(pid), {})
		if P.is_empty():
			continue
		out.append(_box("%d:o" % pid, P["orbita"]))
		for i in P["ambienti"].size():
			out.append(_box("%d:%d" % [pid, i], P["ambienti"][i]))
	var stelle := {}
	for pid in m.scenario_pianeti():
		stelle[int(pid / 10)] = true
	for s in stelle:
		var S: Dictionary = C["stelle"].get(str(s), {})
		if not S.is_empty():
			out.append(_box("D:%d" % s, S["deriva"]))
			out.append(_box("D2:%d" % s, S["deriva2"]))
	return out


static func _box(l: String, b: Dictionary) -> Dictionary:
	return {"luogo": l, "c": Vector2(float(b["x"]), float(b["y"])), "w": float(b["w"]), "h": float(b["h"]), "a": float(b["a"])}


## Vertici di una casella (rettangolo ruotato), utili per evidenziarla.
static func contorno(b: Dictionary, crescita := 0.0) -> PackedVector2Array:
	var t := Vector2(cos(b["a"]), sin(b["a"]))
	var n := Vector2(-t.y, t.x)
	var hw: float = b["w"] * 0.5 + crescita
	var hh: float = b["h"] * 0.5 + crescita
	var c: Vector2 = b["c"]
	return PackedVector2Array([c - t * hw - n * hh, c + t * hw - n * hh, c + t * hw + n * hh, c - t * hw + n * hh, c - t * hw - n * hh])


static func dentro(b: Dictionary, p: Vector2) -> bool:
	var t := Vector2(cos(b["a"]), sin(b["a"]))
	var d: Vector2 = p - b["c"]
	return absf(d.dot(t)) <= b["w"] * 0.5 and absf(d.dot(Vector2(-t.y, t.x))) <= b["h"] * 0.5


## Tutti i segnalini da disegnare: [{tipo, id, pos: Vector2, lato, tex, luogo}]
static func segnalini(m: Motore, vista: int) -> Array:
	var C: Dictionary = Dati.d()["mappa_caselle"]
	var out := []
	var per_luogo := {}
	for id in m.unita:
		var u: Dictionary = m.unita[id]
		var l: String = str(u["luogo"])
		if l == "" or l == "morto":
			continue
		if not per_luogo.has(l):
			per_luogo[l] = []
		per_luogo[l].append(id)
	for pid in m.scenario_pianeti():
		var P: Dictionary = C["pianeti"].get(str(pid), {})
		if P.is_empty():
			continue
		var p: Dictionary = m.pianeti[pid]
		# Lealtà (o Ribellione / Controllo ribelle) sulla casella della traccia politica
		var casella := int(p["lealta"])
		var tl := UI.pedina_tex("lealta", p["stato"] == "ribellione")
		if p["stato"] in ["ribellione", "ribelle"]:
			casella = 4
		if p["stato"] == "ribelle":
			tl = UI.pedina_tex("rib_urbano_10", true)
		var b: Dictionary = P["politica"][casella]
		out.append({"tipo": "lealta", "id": pid, "pos": Vector2(b["x"], b["y"]), "lato": LATO * 0.95, "tex": tl, "luogo": "%d:o" % pid})
		# casella d'Orbita: BDP, segreto e pedine in orbita
		var orb := [{"tipo": "bdp", "id": pid, "tex": UI.pedina_tex("bdp", not p["su"])}]
		if m.livello == "galassia" and m.galattico.segreti.has(pid):
			var vis: bool = m.galattico.svelati.has(pid) or vista == Motore.I
			orb.append({"tipo": "segreto", "id": pid, "tex": UI.pedina_tex("segreto_" + str(m.galattico.segreti[pid]) if vis else "segreto")})
		for id in _ordina(m, per_luogo.get("%d:o" % pid, [])):
			orb.append({"tipo": "pedina", "id": id, "tex": tex_unita(m, id, vista)})
		_distribuisci(out, orb, P["orbita"], "%d:o" % pid)
		for i in P["ambienti"].size():
			var l := "%d:%d" % [pid, i]
			var lista := []
			for id in _ordina(m, per_luogo.get(l, [])):
				lista.append({"tipo": "pedina", "id": id, "tex": tex_unita(m, id, vista)})
			_distribuisci(out, lista, P["ambienti"][i], l)
	var stelle := {}
	for pid in m.scenario_pianeti():
		stelle[int(pid / 10)] = true
	for s in stelle:
		var S: Dictionary = C["stelle"].get(str(s), {})
		for k in [["D:%d" % s, "deriva"], ["D2:%d" % s, "deriva2"]]:
			var lista2 := []
			for id in _ordina(m, per_luogo.get(k[0], [])):
				lista2.append({"tipo": "pedina", "id": id, "tex": tex_unita(m, id, vista)})
			if not S.is_empty():
				_distribuisci(out, lista2, S[k[1]], k[0])
	return out


static func _ordina(m: Motore, ids: Array) -> Array:
	var r := ids.filter(func(x): return m.unita[x]["fz"] == Motore.R)
	var i := ids.filter(func(x): return m.unita[x]["fz"] == Motore.I)
	var k := func(x): return 0 if m.unita[x]["k"] == "pg" else 1
	r.sort_custom(func(a, b): return k.call(a) < k.call(b))
	i.sort_custom(func(a, b): return k.call(a) < k.call(b))
	return r + i


## Dispone le pedine lungo la casella (seguendo l'arco); se non ci stanno si sovrappongono.
static func _distribuisci(out: Array, lista: Array, b: Dictionary, luogo: String) -> void:
	if lista.is_empty():
		return
	var t := Vector2(cos(b["a"]), sin(b["a"]))
	var n := lista.size()
	var lato := minf(LATO, float(b["h"]) * 0.82)
	var spazio: float = maxf(float(b["w"]) - lato - 6.0, 0.0)
	var passo := minf(lato + 3.0, spazio / maxf(1, n - 1)) if n > 1 else 0.0
	var c := Vector2(b["x"], b["y"])
	for k in n:
		var o := (float(k) - (n - 1) * 0.5) * passo
		var e: Dictionary = lista[k]
		e["pos"] = c + t * o
		e["lato"] = lato
		e["luogo"] = luogo
		out.append(e)


static func tex_unita(m: Motore, id: int, vista: int) -> Texture2D:
	var u: Dictionary = m.unita[id]
	if u["k"] == "pg":
		return UI.pedina_tex(str(u["ped"]) if u.has("ped") else UI.chiave_pg(u["nome"]), u["ind"])
	var nascosta: bool = u["fz"] == Motore.I and u["mobile"] and not u["scoperta"] and vista == Motore.R
	return UI.truppa_tex(u, nascosta)
