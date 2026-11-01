class_name Avanzato
extends RefCounted
## Regole del Province Game (Sezioni 17-28), usate anche dal Galactic Game:
## Fase delle Operazioni a sette segmenti (movimento interplanetario con intercettazione e attacchi
## radenti, combattimento spaziale, movimento dei personaggi, movimento di superficie, reazione,
## combattimento negli ambienti, riordino delle orbite), iperbalzi con deriva, rilevamento con le flotte
## in orbita e attacchi delle squadriglie, Punti Forza e acquisti, effetto domino, sovrani, riparazioni.

const IPERBALZO := {1: "1", 2: "-", 3: "-", 4: "-", 5: "1", 6: "-", 7: "2", 8: "1", 9: "2", 10: "1D", 11: "2D"}

var m: Motore
var _dist := {}


func _init(motore: Motore) -> void:
	m = motore


# =====================================================================================
# GEOMETRIA DELLA GALASSIA
# =====================================================================================

## Distanza di iperbalzo fra due sistemi: numero di stelle (anche di navigazione) attraversate, arrivo compreso.
func distanza(a: int, b: int) -> int:
	if a == b:
		return 0
	var k := "%d-%d" % [a, b]
	if _dist.has(k):
		return _dist[k]
	var adj := {}
	for r in Dati.d()["galassia"]["rotte"]:
		var x := _nodo(r["da"])
		var y := _nodo(r["a"])
		if not adj.has(x):
			adj[x] = []
		if not adj.has(y):
			adj[y] = []
		adj[x].append(y)
		adj[y].append(x)
	var dist := {str(a): 0}
	var coda := [str(a)]
	while not coda.is_empty():
		var n: String = coda.pop_front()
		for v in adj.get(n, []):
			if not dist.has(v):
				dist[v] = dist[n] + 1
				coda.append(v)
	var d := int(dist.get(str(b), 99))
	_dist[k] = d
	return d


func _nodo(v) -> String:
	if v is float or v is int:
		return str(int(v))
	return str(v)


func stella_di(l: String) -> int:
	if l.begins_with("D2:") or l.begins_with("D:") or l.begins_with("S:"):
		return int(l.get_slice(":", 1))
	if l == "" or l == "morto":
		return -1
	return int(m.pid_di(l) / 10)


func provincia_di_stella(s: int) -> int:
	return int(s / 10)


func luoghi_orbita() -> Array:
	var out := []
	for pid in m.scenario_pianeti():
		out.append("%d:o" % pid)
	return out


func orbita_di(pid: int) -> String:
	return "%d:o" % pid


# =====================================================================================
# UNITÀ
# =====================================================================================

func spazio_mil(ids: Array) -> int:
	var t := 0
	for id in ids:
		t += int(m.unita[id].get("spazio", 0))
	return t


func mil_libere(l: String, f: int) -> Array:
	return m.mil_in(l, f).filter(func(x): return not m.unita[x].get("interc", false))


func mil_interc(l: String, f: int) -> Array:
	return m.mil_in(l, f).filter(func(x): return m.unita[x].get("interc", false))


## Navigazione di una pila che fa l'iperbalzo (21.2): la forza spaziale più bassa, -1 per ogni unità oltre tre.
func nav_pila(ids: Array, con_capo_spazio: bool) -> int:
	var mobili := ids.filter(func(x): return m.unita[x]["mobile"])
	if mobili.is_empty():
		return 0
	var nav := 99
	for id in mobili:
		var u: Dictionary = m.unita[id]
		var n := int(u.get("spazio", 0))
		if u.get("suicida", false):
			n = 5
		nav = mini(nav, n)
	var soglia := 4 if con_capo_spazio else 3
	nav -= maxi(0, mobili.size() - soglia)
	if m.evento_attivo(116):
		nav -= 1
	return nav


func tira_iperbalzo(dist: int, nav: int) -> String:
	if nav > dist:
		return "-"
	var d := m.dado() + (dist - nav)
	if d >= 12:
		return "2E"
	return IPERBALZO.get(d, "-")


# =====================================================================================
# PREPARAZIONE DEL PROVINCE GAME
# =====================================================================================

func schiera_provincia() -> void:
	m.fase = "schieramento"
	var S: Dictionary = m.scenario
	# --- Impero
	var fi: Dictionary = S["fazioni"]["1"]
	var pos: Dictionary = fi.get("posizioni", {})
	var pg_imp := []
	for nome in fi["personaggi"]:
		var id := m.nuovo_pg(nome, Motore.I)
		pg_imp.append(id)
	for n in fi.get("navi", []):
		var nave := m.nave_imperiale(str(n) == "redjac")
		var pil := m._pilota_per_nave(pg_imp, nave)
		if pil >= 0:
			m.unita[pil]["nave"] = nave
	for id in pg_imp:
		var nome: String = m.unita[id]["nome"]
		var dove: String = str(pos.get(nome, ""))
		var luoghi := []
		if dove.contains(":"):
			luoghi = [dove]
		else:
			var pids: Array = [int(dove)] if dove != "" else fi.get("pianeti_pg", fi.get("capitali", []))
			for pid in pids:
				luoghi.append(orbita_di(pid))
				for i in Dati.pianeta(pid)["ambienti"].size():
					luoghi.append("%d:%d" % [pid, i])
		var opz := []
		for l in luoghi:
			opz.append({"t": m.nome_luogo(l), "luogo": l})
		var k := await m.scegli(Motore.I, "Dove schieri %s?" % nome, opz, {"chiave": "schiera_pg"})
		m.unita[id]["luogo"] = luoghi[k]
		m.cambiato.emit()
	await acquista(Motore.I, int(fi["pf_iniziali"]), _luoghi_controllati(Motore.I, true), {"elite": int(fi.get("max_elite", 99)), "suicida": int(fi.get("max_suicide", 99))}, true)
	# --- Ribelli
	var fr: Dictionary = S["fazioni"]["0"]
	var pg_rib := []
	for nome in fr["personaggi"]:
		pg_rib.append(m.nuovo_pg(nome, Motore.R))
	var navi := []
	for n in fr.get("navi", []):
		m.mazzo_poss.erase(int(n))
		navi.append(m.nave_da_possesso(int(n)))
	# possessi casuali (non astronavi)
	for k2 in int(fr.get("possessi_casuali", 0)):
		for i in m.mazzo_poss.size():
			var nr: int = m.mazzo_poss[i]
			if Dati.d()["poss"].get(nr, {}).get("tipo", "") != "astronave":
				m.mazzo_poss.remove_at(i)
				var opz2 := []
				for id in pg_rib:
					opz2.append({"t": m.unita[id]["nome"], "id": id})
				var kp := await m.scegli(Motore.R, "Possesso iniziale: %s. A chi lo dai?" % Dati.d()["poss"][nr]["nome_it"], opz2, {"chiave": "assegna_possesso", "nr": nr})
				m.unita[pg_rib[kp]]["poss"].append(nr)
				break
	for nave in navi:
		var pil2 := m._pilota_per_nave(pg_rib, nave)
		if pil2 >= 0:
			m.unita[pil2]["nave"] = nave
	if fr.get("navi_in_orbita", false):
		# ogni astronave con il suo equipaggio in orbita a un pianeta della provincia (non vietato)
		var piloti := pg_rib.filter(func(x): return not m.unita[x]["nave"].is_empty())
		var senza := pg_rib.filter(func(x): return m.unita[x]["nave"].is_empty())
		var usati := []
		for pil3 in piloti:
			var cap := int(m.unita[pil3]["nave"]["pas"]) - 1
			var opz3 := []
			for id in senza:
				opz3.append({"t": m.unita[id]["nome"], "id": id})
			var sel := [] if senza.is_empty() else await m.scegli_multi(Motore.R, "Chi viaggia su %s (pilota %s)? Posti: %d" % [m.unita[pil3]["nave"]["nome"], m.unita[pil3]["nome"], cap], opz3, {"chiave": "equipaggio", "max": cap})
			var equip := [pil3]
			for i in sel:
				if equip.size() - 1 < cap:
					equip.append(senza[i])
			for id in equip:
				senza.erase(id)
			var dest := []
			for pid in m.scenario_pianeti():
				if not fr.get("vietati", []).has(pid) and not usati.has(pid):
					dest.append({"t": "Orbita di %s" % Dati.pianeta(pid)["nome"], "luogo": orbita_di(pid)})
			var kd := await m.scegli(Motore.R, "Dove si trova %s all'inizio?" % m.unita[pil3]["nave"]["nome"], dest, {"chiave": "schiera_nave"})
			usati.append(m.pid_di(dest[kd]["luogo"]))
			for id in equip:
				m.unita[id]["luogo"] = dest[kd]["luogo"]
		# chi è rimasto a terra sale sulla prima astronave
		for id in senza:
			m.unita[id]["luogo"] = m.unita[piloti[0]]["luogo"]
	else:
		var luoghi2 := []
		for pid in fr.get("pianeti_pg", []):
			for i in Dati.pianeta(pid)["ambienti"].size():
				luoghi2.append("%d:%d" % [pid, i])
		var opz4 := []
		for l in luoghi2:
			opz4.append({"t": m.nome_luogo(l), "luogo": l})
		var k4 := await m.scegli(Motore.R, "Dove entrano in gioco i tuoi personaggi?", opz4, {"chiave": "schiera_pg"})
		for id in pg_rib:
			m.unita[id]["luogo"] = luoghi2[k4]
	for pid in fr.get("campi", []):
		var opz5 := []
		for i in Dati.pianeta(pid)["ambienti"].size():
			opz5.append({"t": m.nome_luogo("%d:%d" % [pid, i]), "luogo": "%d:%d" % [pid, i]})
		var k5 := await m.scegli(Motore.R, "Campo ribelle su %s: in quale ambiente?" % Dati.pianeta(pid)["nome"], opz5, {"chiave": "campo_iniziale"})
		m.campi[opz5[k5]["luogo"]] = 0
	# truppe ribelli iniziali
	var dove_pf: String = fr.get("pf_luogo", "")
	if dove_pf != "":
		var pid_pf := int(dove_pf.get_slice(":", 0))
		var l_pf := dove_pf
		if not dove_pf.get_slice(":", 1).is_valid_int():
			for i in Dati.pianeta(pid_pf)["ambienti"].size():
				if Dati.pianeta(pid_pf)["ambienti"][i]["tipo"] == dove_pf.get_slice(":", 1):
					l_pf = "%d:%d" % [pid_pf, i]
		await compra_ribelli(l_pf, int(fr["pf_iniziali"]), false)
	m.scrivi("Schieramento completato.")
	m.cambiato.emit()


func _luoghi_controllati(f: int, con_orbite: bool) -> Array:
	var out := []
	for pid in m.scenario_pianeti():
		if m.controllo(pid) != f:
			continue
		if con_orbite:
			out.append(orbita_di(pid))
		for i in Dati.pianeta(pid)["ambienti"].size():
			out.append("%d:%d" % [pid, i])
	return out


# =====================================================================================
# PUNTI FORZA E ACQUISTI
# =====================================================================================

## Acquisti dell'Impero (o dei Ribelli con Punti Forza «da fuori mappa»): unità e BDP.
## luoghi: dove si possono piazzare le unità. Restituisce i Punti Forza avanzati.
func acquista(f: int, pf: int, luoghi: Array, limiti: Dictionary, iniziale := false, solo_bdp := false, pianeti_bdp := []) -> int:
	var U: Dictionary = Dati.d()["regole_avanzate"]["unita"]
	var comprati := {"elite": 0, "suicida": 0, "atrocita": 0}
	var bdp_toccati := {}
	var spesa_bdp := 0
	while pf > 0 and m.esito == "":
		var opz := [{"t": "Fine degli acquisti (avanzano %d Punti Forza)" % pf, "fine": true}]
		if not solo_bdp and not luoghi.is_empty():
			for cat in U:
				var d: Dictionary = U[cat]
				if int(d["fz"]) != f or int(d["costo"]) > pf:
					continue
				if d.get("galattico", false) and m.livello != "galassia":
					continue
				if f == Motore.R and cat == "r44" and not limiti.get("elite_ribelli", false):
					continue
				if d.get("elite", false) and comprati["elite"] >= int(limiti.get("elite", 99)):
					continue
				if d.get("suicida", false) and comprati["suicida"] >= int(limiti.get("suicida", 99)):
					continue
				if d.get("atrocita", false) and comprati["atrocita"] >= int(limiti.get("atrocita", 1)):
					continue
				if d.get("atrocita", false) and limiti.get("no_atrocita", false):
					continue
				if limiti.get("no_unita", false):
					continue
				var nome: String = d["nome"]
				if f == Motore.R:
					nome = "Unità ribelle " + nome
				opz.append({"t": "%s (%d-%d) — %d PF" % [nome, int(d["f"]), int(d["s"]), int(d["costo"])], "cat": cat})
		# BDP
		if not limiti.get("no_bdp", false):
			var cand_bdp: Array = pianeti_bdp if not pianeti_bdp.is_empty() else m.scenario_pianeti()
			for pid in cand_bdp:
				var p: Dictionary = m.pianeti[pid]
				var c := m.controllo(pid)
				var puo: bool = c == f or (f == Motore.R and p["stato"] == "ribellione" and m.mil_su_pianeta(pid, Motore.I).is_empty())
				if not puo:
					continue
				if iniziale and spesa_bdp >= int(limiti.get("max_bdp", 999)):
					continue
				if not p["su"] and pf >= 1:
					opz.append({"t": "Rimetti in funzione il BDP di %s — 1 PF" % Dati.pianeta(pid)["nome"], "bdp_su": pid})
				elif p["su"] and int(p["bdp"]) < 2 and pf >= 3 and (iniziale or not bdp_toccati.has(pid)) and c == f and (not limiti.has("liv_bdp_prov") or limiti["liv_bdp_prov"].has(int(pid / 100))):
					opz.append({"t": "Porta il BDP di %s al livello %d — 3 PF" % [Dati.pianeta(pid)["nome"], int(p["bdp"]) + 1], "bdp_liv": pid})
		if opz.size() == 1:
			break
		var k := await m.scegli(f, "Hai %d Punti Forza da spendere." % pf, opz, {"chiave": "acquista", "pf": pf, "conferma": true})
		var o: Dictionary = opz[k]
		if o.get("fine", false):
			break
		if o.has("bdp_su"):
			m.pianeti[o["bdp_su"]]["su"] = true
			pf -= 1
			spesa_bdp += 1
			m.scrivi("%s rimette in funzione il BDP di %s." % [Dati.FAZIONI[f], Dati.pianeta(o["bdp_su"])["nome"]])
			continue
		if o.has("bdp_liv"):
			m.pianeti[o["bdp_liv"]]["bdp"] += 1
			bdp_toccati[o["bdp_liv"]] = true
			pf -= 3
			spesa_bdp += 3
			m.scrivi("%s potenzia il BDP di %s al livello %d." % [Dati.FAZIONI[f], Dati.pianeta(o["bdp_liv"])["nome"], m.pianeti[o["bdp_liv"]]["bdp"]])
			continue
		var cat2: String = o["cat"]
		var d2: Dictionary = U[cat2]
		var ammessi := luoghi.filter(func(l): return _piazzabile(l, f, cat2))
		if d2.get("atrocita", false):
			ammessi = ammessi.filter(func(l): return l in ["152:o", "162:o"])
		if ammessi.is_empty():
			m.scrivi("Nessun posto dove schierare l'unità.")
			break
		var amb := ""
		if f == Motore.R:
			var tipi := ["urbano", "selvaggio"] if limiti.get("solo_urbano_selvaggio", false) else Dati.AMBIENTI
			if not ammessi.any(func(l): return not m.is_amb(l)):
				tipi = tipi.filter(func(t): return ammessi.any(func(l): return m.tipo_amb(l) == t))
			if tipi.is_empty():
				break
			var opz_a := []
			for t in tipi:
				opz_a.append({"t": Dati.AMBIENTI_NOMI[t], "amb": t})
			amb = opz_a[await m.scegli(f, "Di quale tipo di ambiente?", opz_a, {"chiave": "tipo_unita"})]["amb"]
			ammessi = ammessi.filter(func(l): return not m.is_amb(l) or m.tipo_amb(l) == amb)
			if ammessi.is_empty():
				break
		var opz_l := []
		for l in ammessi:
			opz_l.append({"t": "%s (%d/%d)" % [m.nome_luogo(l), m.mil_in(l, f).size(), m.taglia(l)] if m.is_amb(l) else m.nome_luogo(l), "luogo": l})
		var kl := await m.scegli(f, "Dove schieri %s?" % d2["nome"], opz_l, {"chiave": "piazza", "cat": cat2})
		var id := m.nuova_unita(f, cat2, amb)
		m.unita[id]["luogo"] = opz_l[kl]["luogo"]
		pf -= int(d2["costo"])
		if d2.get("elite", false):
			comprati["elite"] += 1
		if d2.get("suicida", false):
			comprati["suicida"] += 1
		if d2.get("atrocita", false):
			comprati["atrocita"] += 1
		m.cambiato.emit()
	return pf


func _piazzabile(l: String, f: int, cat: String) -> bool:
	var d: Dictionary = Dati.d()["regole_avanzate"]["unita"][cat]
	if l.begins_with("S:"):
		return d["mobile"]
	if m.is_orbita(l):
		return true
	if d.get("atrocita", false):
		return false
	if d.get("suicida", false):
		return true
	return m.mil_in(l, f).filter(func(x): return not m.unita[x].get("suicida", false)).size() < m.taglia(l)


## Truppe create da una ribellione o da un sovrano: Punti Forza spesi in un solo ambiente.
func compra_ribelli(l: String, punti: int, stellare: bool) -> Array:
	var tipo := m.tipo_amb(l)
	var nuove := []
	var spazio: int = m.taglia(l) - m.mil_in(l, Motore.R).size()
	var U: Dictionary = Dati.d()["regole_avanzate"]["unita"]
	var cats := ["r43", "r23", "r21", "r10"] if stellare else ["r21", "r10"]
	while punti > 0 and spazio > 0:
		var opz := []
		for c in cats:
			if int(U[c]["costo"]) <= punti:
				opz.append({"t": "Unità %s %s (%d punti)" % [Dati.AMBIENTI_NOMI[tipo], U[c]["nome"], int(U[c]["costo"])], "cat": c})
		if opz.is_empty():
			break
		opz.append({"t": "Basta così"})
		var k := await m.scegli(Motore.R, "%s: %d Punti Forza da spendere (spazio per %d unità)." % [m.nome_luogo(l), punti, spazio], opz, {"chiave": "acquisto_ribelle", "punti": punti})
		if not opz[k].has("cat"):
			break
		var id := m.nuova_unita(Motore.R, opz[k]["cat"], tipo)
		m.unita[id]["luogo"] = l
		nuove.append(id)
		punti -= int(U[opz[k]["cat"]]["costo"])
		spazio -= 1
	return nuove


func compra_imperiali(l: String, punti: int) -> Array:
	var nuove := []
	var U: Dictionary = Dati.d()["regole_avanzate"]["unita"]
	while punti > 0 and m.mil_in(l, Motore.I).size() < m.taglia(l):
		var opz := []
		for c in ["linea", "pattuglia", "milizia", "veterano"]:
			if int(U[c]["costo"]) <= punti:
				opz.append({"t": "%s (%d punti)" % [U[c]["nome"], int(U[c]["costo"])], "cat": c})
		if opz.is_empty():
			break
		opz.append({"t": "Basta così"})
		var k := await m.scegli(Motore.I, "%s: %d Punti Forza dal sovrano." % [m.nome_luogo(l), punti], opz, {"chiave": "acquista", "pf": punti})
		if not opz[k].has("cat"):
			break
		var id := m.nuova_unita(Motore.I, opz[k]["cat"])
		m.unita[id]["luogo"] = l
		nuove.append(id)
		punti -= int(U[opz[k]["cat"]]["costo"])
	return nuove


## Punti Forza a inizio turno nel Province Game (19.31, 28.13 e scenari).
func rinforzi_provincia(f: int) -> void:
	var fs: Dictionary = m.scenario["fazioni"][str(f)]
	if f == Motore.I:
		if m.turno == 1:
			return
		var capitali: Array = fs.get("capitali", [])
		var luoghi := []
		for pid in capitali:
			if m.controllo(pid) == Motore.I:
				luoghi.append(orbita_di(pid))
				for i in Dati.pianeta(pid)["ambienti"].size():
					luoghi.append("%d:%d" % [pid, i])
		if luoghi.is_empty():
			m.scrivi("L'Impero non controlla la capitale: niente rinforzi.")
			return
		m.scrivi("L'Impero riceve %d Punti Forza." % int(fs["pf_turno"]))
		await acquista(Motore.I, int(fs["pf_turno"]), luoghi, {})
	else:
		var pf := 0
		if m.turno == 2:
			pf = int(fs.get("pf_turno2", 0))
		elif m.turno > 2:
			pf = int(fs.get("pf_turno", 0))
		if pf <= 0:
			return
		var stelle := _stelle_ingresso(fs)
		var luoghi2 := []
		for s in stelle:
			luoghi2.append("S:%d" % s)
		m.scrivi("I Ribelli ricevono %d Punti Forza fuori mappa." % pf)
		await acquista(Motore.R, pf, luoghi2, {"elite_ribelli": true, "solo_urbano_selvaggio": true}, false, false, [])


func _stelle_ingresso(fs: Dictionary) -> Array:
	var ing = fs.get("ingressi", [])
	if ing is Array:
		return ing
	# «confinanti»: sistemi fuori provincia collegati direttamente a un sistema della provincia
	var prov := int(m.scenario["provincia"])
	var out := []
	for r in Dati.d()["galassia"]["rotte"]:
		var a := _nodo(r["da"])
		var b := _nodo(r["a"])
		if not a.is_valid_int() or not b.is_valid_int():
			continue
		var pa := int(int(a) / 10)
		var pb := int(int(b) / 10)
		if pa == prov and pb != prov and not out.has(int(b)):
			out.append(int(b))
		if pb == prov and pa != prov and not out.has(int(a)):
			out.append(int(a))
	out.sort()
	return out


# =====================================================================================
# FASE DELLE OPERAZIONI
# =====================================================================================

func operazioni(f: int) -> void:
	var nemico := m.avversario(f)
	if m.livello == "provincia":
		await rinforzi_provincia(f)
	m.fase = "interplanetario"
	m.cambiato.emit()
	await movimento_interplanetario(f)
	if m.esito != "":
		return
	m.fase = "spazio"
	m.cambiato.emit()
	await combattimento_spaziale(f)
	m.fase = "personaggi"
	m.cambiato.emit()
	await movimento_personaggi(f)
	m.fase = "superficie"
	m.cambiato.emit()
	await movimento_superficie(f)
	m.fase = "reazione"
	m.cambiato.emit()
	await m.reazione(nemico, f)
	m.fase = "combattimento"
	m.cambiato.emit()
	await m.combattimenti_militari(f)
	# riordino delle orbite
	for id in m.unita:
		m.unita[id]["interc"] = false
	# unità rimaste fuori mappa: perdute
	for id in m.unita:
		var u: Dictionary = m.unita[id]
		if u["fz"] == f and str(u["luogo"]).begins_with("S:"):
			u["luogo"] = "morto"
			m.scrivi("%s non entra in gioco ed è perduta." % m.descr_mil(id))
	_con_le_truppe(f)
	await _scegli_con_truppe(f)
	if m.livello == "galassia":
		await m.galattico.controlla_ipnosi()


func _con_le_truppe(f: int) -> void:
	for id in m.unita:
		var u: Dictionary = m.unita[id]
		if u["k"] == "pg" and u["fz"] == f and m.is_orbita(str(u["luogo"])):
			u["truppe"] = not m.mil_in(u["luogo"], f).is_empty()


func _scegli_con_truppe(f: int) -> void:
	for l in m.luoghi_sistema():
		var mm := m.mil_in(l, f)
		var pp := m.pg_in(l, f, true)
		if mm.is_empty() or pp.is_empty():
			continue
		var opz := []
		for id in pp:
			opz.append({"t": m.unita[id]["nome"], "id": id})
		var sel := await m.scegli_multi(f, "%s: quali personaggi restano con le truppe? (niente missioni, ma non possono essere cercati)" % m.nome_luogo(l), opz, {"chiave": "con_truppe", "luogo": l})
		for i in sel:
			m.unita[pp[i]]["truppe"] = true


# -------------------------------------------------------------------------------------
# Movimento interplanetario delle truppe (20.1)
# -------------------------------------------------------------------------------------

func _mobili_in(l: String, f: int) -> Array:
	return m.mil_in(l, f).filter(func(x): return not m.unita[x]["mosso"] and not m.unita[x].get("interc", false))


func movimento_interplanetario(f: int) -> void:
	for id in m.unita:
		if m.unita[id]["k"] == "mil":
			m.unita[id]["mosso"] = false
	while m.esito == "":
		var luoghi := {}
		for id in m.unita:
			var u: Dictionary = m.unita[id]
			if u["k"] != "mil" or u["fz"] != f or u["mosso"] or u.get("interc", false):
				continue
			var l: String = u["luogo"]
			if l == "" or l == "morto":
				continue
			luoghi[l] = true
		var opz := []
		var obbligo := []
		for l in luoghi:
			var t := "Truppe in %s" % m.nome_luogo(l)
			if l.begins_with("D") or l.begins_with("S:"):
				t += " (devono muovere)"
				obbligo.append(l)
			opz.append({"t": t, "luogo_da": l})
		opz.append({"t": "Fine del movimento interplanetario", "fine": true})
		var k := await m.scegli(f, "Movimento interplanetario delle truppe: chi muovi?", opz, {"chiave": "mov_truppe", "conferma": true})
		if opz[k].get("fine", false):
			break
		await _muovi_pila(f, opz[k]["luogo_da"])
		m.cambiato.emit()
	# chi era in deriva e non si è mosso resta dov'è (in deriva non fa nulla)


func _muovi_pila(f: int, da: String) -> void:
	var mm := _mobili_in(da, f)
	if mm.is_empty():
		return
	var opz := []
	for id in mm:
		opz.append({"t": m.descr_mil(id), "id": id})
	var sel := await m.scegli_multi(f, "Quali truppe muovi da %s?" % m.nome_luogo(da), opz, {"chiave": "truppe_sel", "min": 1})
	var pila := []
	for i in sel:
		pila.append(mm[i])
	if pila.is_empty():
		for id in mm:
			m.unita[id]["mosso"] = true
		return
	var mobili := pila.filter(func(x): return m.unita[x]["mobile"] and not m.unita[x].get("suicida", false) and not m.unita[x].get("atrocita", false))
	var fisse := pila.filter(func(x): return not m.unita[x]["mobile"])
	if fisse.size() > mobili.size():
		m.scrivi("Ogni unità 1-0 deve essere trasportata da un'unità mobile: muovi meno unità fisse.")
		for id in fisse.slice(mobili.size()):
			pila.erase(id)
	if pila.filter(func(x): return m.unita[x]["mobile"]).is_empty():
		for id in pila:
			m.unita[id]["mosso"] = true
		return
	var atrocita := pila.any(func(x): return m.unita[x].get("atrocita", false))
	# destinazioni
	var dest := []
	var pid_da := m.pid_di(da) if m.is_amb(da) or m.is_orbita(da) else -1
	var stella_da := stella_di(da)
	var solo_sistema := da.begins_with("D:") or da.begins_with("D2:")
	for pid in m.scenario_pianeti():
		if m.distrutto(pid):
			continue
		if solo_sistema and int(pid / 10) != stella_da:
			continue
		if not m.galattico.mossa_imperiale_ammessa(f, pid_da, pid, da):
			continue
		var o := orbita_di(pid)
		if o != da:
			dest.append({"t": m.nome_luogo(o), "luogo": o})
		if atrocita:
			continue
		for i in Dati.pianeta(pid)["ambienti"].size():
			var l := "%d:%d" % [pid, i]
			if pid == pid_da and m.is_amb(da):
				continue
			if l == da:
				continue
			var occ := m.mil_in(l, f).filter(func(x): return not m.unita[x].get("suicida", false)).size()
			var nuovi := pila.filter(func(x): return not m.unita[x].get("suicida", false)).size()
			if occ + nuovi > m.taglia(l):
				continue
			dest.append({"t": "%s (%d/%d)" % [m.nome_luogo(l), occ, m.taglia(l)], "luogo": l})
	if dest.is_empty():
		m.scrivi("Nessuna destinazione possibile.")
		for id in pila:
			m.unita[id]["mosso"] = true
		return
	for d in dest:
		var s := stella_di(d["luogo"])
		if s != stella_da:
			d["t"] += " — iperbalzo %d" % distanza(stella_da, s)
	var kd := await m.scegli(f, "Dove vanno le truppe?", dest, {"chiave": "dest_truppe", "da": da})
	var a: String = dest[kd]["luogo"]
	# personaggi che viaggiano con le truppe
	var accomp := []
	var pp := m.pg_in(da, f, true).filter(func(x): return not m.unita[x]["mosso"])
	if not pp.is_empty():
		var opz2 := []
		for id in pp:
			opz2.append({"t": m.unita[id]["nome"], "id": id})
		var s2 := await m.scegli_multi(f, "Quali personaggi viaggiano con le truppe?", opz2, {"chiave": "accompagna"})
		for i in s2:
			accomp.append(pp[i])
	for id in pila + accomp:
		m.unita[id]["mosso"] = true
	for id in accomp:
		m.unita[id]["ind"] = true
		m.unita[id]["attivo_turno"] = true
	await _percorso(f, pila, accomp, da, a)


## Esegue il viaggio di una pila: decollo (attacco radente), orbita di partenza (intercettazione),
## iperbalzo, orbita d'arrivo (intercettazione), atterraggio (attacco radente).
func _percorso(f: int, pila: Array, accomp: Array, da: String, a: String) -> void:
	var nemico := m.avversario(f)
	var pid_a := m.pid_di(a)
	var stella_a := stella_di(a)
	var pos := da
	# 1. decollo
	if m.is_amb(da):
		await attacco_radente(f, pila, m.pid_di(da))
		pila = pila.filter(func(x): return m.vivo(x))
		if pila.is_empty():
			_fine_pila(accomp, da)
			return
		pos = orbita_di(m.pid_di(da))
		_sposta(pila, accomp, pos)
		if pos != a and await _intercetta(nemico, pila, pos):
			return
	elif m.is_orbita(da) and da != a:
		if await _intercetta(nemico, pila, da):
			return
	if pos == a:
		return
	# 2. iperbalzo
	if stella_di(pos) != stella_a:
		var cap := accomp.any(func(x): return m.unita[x]["c"].get("comando_spazio", null) != null)
		var nav := nav_pila(pila, cap)
		var dist := distanza(stella_di(pos), stella_a)
		if pos.begins_with("D2:"):
			dist = 2
		dist += m.galattico.extra_distanza(stella_di(pos), stella_a)
		var r := tira_iperbalzo(dist, nav)
		m.scrivi("Iperbalzo di %d truppe verso %s: distanza %d, navigazione %d » %s." % [pila.size(), Dati.d()["stelle"].get(stella_a, {}).get("nome", "?"), dist, nav, _nome_esito_iperbalzo(r)])
		m.evento.emit("iperbalzo", {"f": f, "esito": r})
		await m.attesa(0.6)
		if r.ends_with("D"):
			var debole := _piu_debole(pila)
			m.unita[debole]["luogo"] = "morto"
			pila.erase(debole)
		elif r.ends_with("E"):
			var n := int(ceil(pila.size() / 2.0))
			for i in n:
				var d2 := _piu_debole(pila)
				m.unita[d2]["luogo"] = "morto"
				pila.erase(d2)
		if pila.is_empty():
			for id in accomp:
				m.uccidi(id, "disperso nell'iperspazio")
			return
		if r.begins_with("1"):
			_sposta(pila, accomp, "D:%d" % stella_a)
			return
		if r.begins_with("2"):
			if pos.begins_with("D2:") and stella_di(pos) == stella_a:
				_sposta(pila, accomp, pos)
				return
			_sposta(pila, accomp, "D2:%d" % stella_a)
			return
	# 3. orbita d'arrivo
	var orb_a := orbita_di(pid_a)
	if pos != orb_a:
		pos = orb_a
		_sposta(pila, accomp, pos)
		m.evento.emit("volo_truppe", {"da": da, "a": orb_a, "f": f})
		if await _intercetta(nemico, pila, pos):
			return
	if a == orb_a:
		return
	# 4. atterraggio
	await attacco_radente(f, pila, pid_a)
	pila = pila.filter(func(x): return m.vivo(x))
	if pila.is_empty():
		_fine_pila(accomp, pos)
		return
	_sposta(pila, accomp, a)
	m.scrivi("%s: truppe da %s a %s." % [Dati.FAZIONI[f], m.nome_luogo(da), m.nome_luogo(a)])


func _nome_esito_iperbalzo(r: String) -> String:
	var t := {"-": "arrivo regolare", "1": "deriva", "2": "deriva 2", "1D": "deriva con danni", "2D": "deriva 2 con danni", "2E": "disastro"}
	return t.get(r, r)


func _fine_pila(accomp: Array, dove: String) -> void:
	for id in accomp:
		if m.vivo(id):
			m.uccidi(id, "a bordo delle truppe distrutte")


func _sposta(pila: Array, accomp: Array, l: String) -> void:
	for id in pila:
		m.unita[id]["luogo"] = l
	for id in accomp:
		m._sposta_pg(id, l)


func _piu_debole(ids: Array) -> int:
	var best: int = ids[0]
	for id in ids:
		if int(m.unita[id].get("spazio", 0)) + int(m.unita[id]["forza"]) < int(m.unita[best].get("spazio", 0)) + int(m.unita[best]["forza"]):
			best = id
	return best


## L'avversario può intercettare la pila in un'orbita dove ha truppe (20.4). True se intercettata.
func _intercetta(nemico: int, pila: Array, orbita: String) -> bool:
	var loro := mil_libere(orbita, nemico).filter(func(x): return not m.unita[x].get("suicida", false) and not m.unita[x].get("atrocita", false))
	if loro.is_empty():
		return false
	var opz := []
	for id in loro:
		opz.append({"t": m.descr_mil(id), "id": id})
	var sel := await m.scegli_multi(nemico, "Truppe nemiche (%d punti di forza spaziale) passano per %s: con quali unità le intercetti? (nessuna = lasciale passare)" % [spazio_mil(pila), m.nome_luogo(orbita)], opz, {"chiave": "intercetta", "luogo": orbita, "forza": spazio_mil(pila)})
	if sel.is_empty():
		return false
	for i in sel:
		m.unita[loro[i]]["interc"] = true
	for id in pila:
		m.unita[id]["interc"] = true
		m.unita[id]["luogo"] = orbita
	m.scrivi("Intercettazione in %s!" % m.nome_luogo(orbita))
	m.evento.emit("intercettazione", {"luogo": orbita})
	return true


## Attacco radente di un BDP nemico (20.6): solo a senso unico, colonna 4-1 (livello 2) o 2-1 (livello 1).
func attacco_radente(f: int, pila: Array, pid: int) -> void:
	var liv := m.bdp_attiva(pid, f)
	if liv < 1:
		return
	var nemico := m.avversario(f)
	var k := await m.scegli(nemico, "Truppe nemiche passano davanti al BDP di %s: attacco radente?" % Dati.pianeta(pid)["nome"], [{"t": "Sì, fuoco"}, {"t": "No"}], {"chiave": "radente", "conferma": true})
	if k == 1:
		return
	var col := 8 if liv == 2 else 6
	var d := m.dado()
	var perdita: int = Dati.d()["tabelle"]["combattimento_militare"]["righe_dado"][d - 1][col][1]
	m.scrivi("Attacco radente del BDP di %s: dado %d » %d punti di perdite." % [Dati.pianeta(pid)["nome"], d, perdita])
	m.evento.emit("bdp_spara", {"pid": pid})
	await m.attesa(0.5)
	applica_perdite_spazio(pila, perdita)


func applica_perdite_spazio(ids: Array, perdita: int) -> void:
	if perdita <= 0 or ids.is_empty():
		return
	var n := ids.size()
	var best_mask := 0
	var best := -1
	for mask in range(1, 1 << mini(n, 14)):
		var s := 0
		for i in mini(n, 14):
			if mask & (1 << i):
				s += int(m.unita[ids[i]].get("spazio", 0))
		if s <= perdita and s > best:
			best = s
			best_mask = mask
	for i in mini(n, 14):
		if best_mask & (1 << i):
			m.scrivi("Eliminata: %s (%s)." % [m.descr_mil(ids[i]), Dati.FAZIONI[m.unita[ids[i]]["fz"]]])
			m.unita[ids[i]]["luogo"] = "morto"
	# unità con forza spaziale 0 trasportate: seguono la sorte del trasporto
	var trasp := ids.filter(func(x): return m.vivo(x) and int(m.unita[x].get("spazio", 0)) == 0)
	var vettori := ids.filter(func(x): return m.vivo(x) and int(m.unita[x].get("spazio", 0)) > 0)
	if not trasp.is_empty() and vettori.is_empty():
		for id in trasp:
			m.unita[id]["luogo"] = "morto"


# -------------------------------------------------------------------------------------
# Combattimento spaziale (22.0)
# -------------------------------------------------------------------------------------

func combattimento_spaziale(f: int) -> void:
	var nemico := m.avversario(f)
	for o in luoghi_orbita():
		if m.esito != "":
			return
		# 1. pila d'intercettazione: attacco obbligatorio dell'avversario
		var mie := mil_interc(o, f)
		var loro := mil_interc(o, nemico)
		if not mie.is_empty() and not loro.is_empty():
			await battaglia_spazio(o, nemico, loro, mie, false, false)
			for id in m.mil_in(o, f) + m.mil_in(o, nemico):
				if mil_interc(o, f).is_empty() or mil_interc(o, nemico).is_empty():
					m.unita[id]["interc"] = false
		# 3. combattimento fra unità non intercettate
		var a := mil_libere(o, f)
		var b := mil_libere(o, nemico)
		var fatto := false
		if not a.is_empty() and not b.is_empty():
			var k := await m.scegli(f, "Flotte nemiche in %s: dichiari battaglia spaziale?" % m.nome_luogo(o), [{"t": "Sì, attacco"}, {"t": "No"}], {"chiave": "dichiara_spazio", "luogo": o, "conferma": true})
			if k == 0:
				await battaglia_spazio(o, f, a, b, true, true)
				fatto = true
			else:
				var k2 := await m.scegli(nemico, "Flotte nemiche in %s: dichiari battaglia spaziale?" % m.nome_luogo(o), [{"t": "Sì, attacco"}, {"t": "No"}], {"chiave": "dichiara_spazio", "luogo": o, "conferma": true})
				if k2 == 0:
					await battaglia_spazio(o, nemico, b, a, true, true)
					fatto = true
		# 4. attacco al BDP nemico
		var pid := m.pid_di(o)
		a = mil_libere(o, f)
		if not fatto and not a.is_empty() and m.controllo(pid) == nemico:
			var k3 := await m.scegli(f, "Attacchi il BDP di %s con le tue flotte in orbita?" % Dati.pianeta(pid)["nome"], [{"t": "Sì, attacco il BDP"}, {"t": "No"}], {"chiave": "attacca_bdp", "luogo": o, "conferma": true})
			if k3 == 0:
				await attacca_bdp(o, f, a)
		m.cambiato.emit()


func _capo_spazio(f: int, l: String) -> int:
	var cand := []
	for id in m.pg_in(l, f, true):
		if m.unita[id]["c"].get("comando_spazio", null) != null and int(m.unita[id]["c"]["comando_spazio"]) > 0:
			cand.append(id)
	if cand.is_empty():
		return -1
	var opz := [{"t": "Nessun comandante"}]
	for id in cand:
		opz.append({"t": "%s (comando spaziale %d)" % [m.unita[id]["nome"], int(m.unita[id]["c"]["comando_spazio"])], "id": id})
	var k := await m.scegli(f, "Chi comanda la flotta in %s?" % m.nome_luogo(l), opz, {"chiave": "capo", "luogo": l, "conferma": true})
	return -1 if k == 0 else opz[k]["id"]


func battaglia_spazio(o: String, att: int, aa: Array, dd: Array, pdb_aiuta: bool, assalto_possibile: bool) -> void:
	var dif := m.avversario(att)
	for id in aa + dd:
		m.unita[id]["scoperta"] = true
	var capo_a := await _capo_spazio(att, o)
	var capo_d := await _capo_spazio(dif, o)
	var fa := spazio_mil(aa)
	var fd := spazio_mil(dd)
	var col := _colonna_rapporto(fa, fd)
	var ca := int(m.unita[capo_a]["c"]["comando_spazio"]) if capo_a >= 0 else 0
	var cd := int(m.unita[capo_d]["c"]["comando_spazio"]) if capo_d >= 0 else 0
	ca += m.bonus_reale(capo_a, o)
	cd += m.bonus_reale(capo_d, o)
	col += ca - cd
	var pid := m.pid_di(o)
	if pdb_aiuta and m.controllo(pid) == dif and m.pianeti[pid]["su"]:
		var liv := int(m.pianeti[pid]["bdp"])
		col -= 3 if liv == 2 else (1 if liv == 1 else 0)
	col += m.galattico.spostamento_vivo(pid, att)
	var assalto := false
	if assalto_possibile and aa.all(func(x): return int(m.unita[x].get("spazio", 0)) >= 3):
		var k := await m.scegli(att, "Dichiari un Assalto deciso? (due colonne a sinistra, perdite raddoppiate per tutti)", [{"t": "No"}, {"t": "Sì, assalto deciso"}], {"chiave": "assalto", "conferma": true})
		assalto = k == 1
	if assalto:
		col -= 2
	col = clampi(col, 0, 10)
	var tab: Array = Dati.d()["tabelle"]["combattimento_militare"]["righe_dado"]
	var d1 := m.dado()
	var d2 := m.dado()
	var perd_d: int = tab[d1 - 1][col][1]
	var perd_a: int = tab[d2 - 1][col][0]
	if assalto:
		perd_d *= 2
		perd_a *= 2
	var cols: Array = Dati.d()["tabelle"]["combattimento_militare"]["colonne"]
	m.scrivi("Battaglia spaziale in %s: %s %d contro %s %d, colonna %s; dadi %d/%d » perdite %d all'attaccante, %d al difensore." % [m.nome_luogo(o), Dati.FAZIONI[att], fa, Dati.FAZIONI[dif], fd, cols[col], d1, d2, perd_a, perd_d])
	m.evento.emit("battaglia", {"luogo": o, "att": att, "col": cols[col], "dadi": [d1, d2], "perdite": [perd_a, perd_d]})
	await m.attesa(1.0)
	applica_perdite_spazio(aa, perd_a)
	applica_perdite_spazio(dd, perd_d)
	for id in aa + dd:
		if m.vivo(id):
			m.unita[id]["scoperta"] = false
	# 22.43: chi resta senza truppe nello spazio è perduto
	for fz in [att, dif]:
		if m.mil_in(o, fz).is_empty():
			for id in m.pg_in(o, fz):
				m.uccidi(id, "la sua flotta è stata distrutta")
	m._controlla_navi_orfane()


func _colonna_rapporto(fa: int, fd: int) -> int:
	if fa >= fd:
		return 5 + mini(int(fa / max(fd, 1)), 5) - 1
	return 5 - (mini(int(ceil(float(fd) / max(fa, 1))), 5) - 1)


## Attacco a un BDP (22.22): difende con 1, 4 o 8, più le flotte amiche in orbita che non subiscono perdite.
func attacca_bdp(o: String, f: int, aa: Array) -> void:
	var pid := m.pid_di(o)
	var p: Dictionary = m.pianeti[pid]
	var dif := m.avversario(f)
	var forza_bdp: int = [1, 4, 8][clampi(int(p["bdp"]), 0, 2)]
	var aiuto := spazio_mil(mil_libere(o, dif))
	var fa := spazio_mil(aa)
	var col := _colonna_rapporto(fa, forza_bdp + aiuto)
	if not p["su"] or m.controllo(pid) < 0:
		col += 2
	var capo := await _capo_spazio(f, o)
	if capo >= 0:
		col += int(m.unita[capo]["c"]["comando_spazio"])
	col = clampi(col, 0, 10)
	var tab: Array = Dati.d()["tabelle"]["combattimento_militare"]["righe_dado"]
	var d1 := m.dado()
	var d2 := m.dado()
	var perd_bdp: int = tab[d1 - 1][col][1]
	var perd_a: int = tab[d2 - 1][col][0]
	m.scrivi("Attacco al BDP di %s (forza %d): dadi %d/%d » %d al BDP, %d agli attaccanti." % [Dati.pianeta(pid)["nome"], forza_bdp + aiuto, d1, d2, perd_bdp, perd_a])
	m.evento.emit("bdp_spara", {"pid": pid})
	await m.attesa(0.8)
	applica_perdite_spazio(aa, perd_a)
	if perd_bdp >= 2:
		p["su"] = false
		var livelli := int((perd_bdp - 2) / 3)
		p["bdp"] = maxi(0, int(p["bdp"]) - livelli)
		m.scrivi("Il BDP di %s è messo fuori uso%s." % [Dati.pianeta(pid)["nome"], (" e scende al livello %d" % p["bdp"]) if livelli > 0 else ""])


# -------------------------------------------------------------------------------------
# Movimento dei personaggi (20.2) e rilevamento (20.7)
# -------------------------------------------------------------------------------------

func movimento_personaggi(f: int) -> void:
	while m.esito == "":
		var opz := []
		for id in m.unita:
			var u: Dictionary = m.unita[id]
			if u["k"] != "pg" or u["fz"] != f or u["mosso"] or u["prig"] >= 0 or u.get("sovrano", false):
				continue
			var l: String = u["luogo"]
			if l == "" or l == "morto":
				continue
			if not u["nave"].is_empty() and m.val(id, "navigazione") > 0:
				if u["nave"].get("dmg", false) and m.mil_in(l, f).is_empty():
					continue
				if m.galattico.navi_bloccate(u):
					continue
				var t := "%s pilota %s" % [u["nome"], u["nave"]["nome"]]
				if l.begins_with("D"):
					t += " (in deriva: deve muovere)"
				opz.append({"t": t, "tipo": "nave", "id": id})
			if m.is_amb(l) and Dati.pianeta(m.pid_di(l))["ambienti"].size() > 1:
				opz.append({"t": "%s si sposta a piedi" % u["nome"], "tipo": "piedi", "id": id})
		opz.append({"t": "Fine del movimento dei personaggi", "fine": true})
		var k := await m.scegli(f, "Movimento dei personaggi: chi muovi?", opz, {"chiave": "movimento", "conferma": true})
		var o: Dictionary = opz[k]
		if o.get("fine", false):
			break
		if o["tipo"] == "piedi":
			await m._muovi_a_piedi(f, o["id"])
		else:
			await _muovi_nave(f, o["id"])
		m.cambiato.emit()


func _muovi_nave(f: int, pilota: int) -> void:
	var u: Dictionary = m.unita[pilota]
	var nave: Dictionary = u["nave"]
	var da: String = u["luogo"]
	var stella_da := stella_di(da)
	var dest := []
	var solo_sistema := da.begins_with("D:") or da.begins_with("D2:")
	var pid_da := m.pid_di(da) if (m.is_amb(da) or m.is_orbita(da)) else -1
	for pid in m.scenario_pianeti():
		if m.distrutto(pid):
			continue
		if solo_sistema and int(pid / 10) != stella_da:
			continue
		if not m.galattico.mossa_imperiale_ammessa(f, pid_da, pid, da):
			continue
		var ls := [orbita_di(pid)]
		for i in Dati.pianeta(pid)["ambienti"].size():
			ls.append("%d:%d" % [pid, i])
		for l in ls:
			if l == da:
				continue
			var t := m.nome_luogo(l)
			var s := int(pid / 10)
			if s != stella_da:
				t += " — iperbalzo %d" % (2 if da.begins_with("D2:") else distanza(stella_da, s))
			dest.append({"t": t, "luogo": l})
	if dest.is_empty():
		u["mosso"] = true
		return
	var k := await m.scegli(f, "Dove va %s?" % nave["nome"], dest, {"chiave": "dest_nave", "id": pilota})
	var a: String = dest[k]["luogo"]
	var cand := m.pg_in(da, f, true).filter(func(x): return x != pilota and not m.unita[x]["mosso"] and not m.unita[x].get("sovrano", false))
	var posti := int(nave["pas"]) - 1 - m._compagni(pilota)
	var gruppo := [pilota]
	if not cand.is_empty() and posti > 0:
		var opz := []
		for o in cand:
			opz.append({"t": m.unita[o]["nome"], "id": o})
		var sel := await m.scegli_multi(f, "Chi sale a bordo? (posti liberi: %d)" % posti, opz, {"chiave": "passeggeri", "max": posti})
		for i in sel:
			if gruppo.size() - 1 + m._compagni(cand[i]) < posti:
				gruppo.append(cand[i])
	for id in gruppo:
		m.unita[id]["mosso"] = true
	u["attivo_turno"] = true
	var pid_a := m.pid_di(a)
	var stella_a := int(pid_a / 10)
	m.scrivi("%s parte da %s verso %s con %d a bordo." % [nave["nome"], m.nome_luogo(da), m.nome_luogo(a), gruppo.size()])
	# decollo / spostamento sul pianeta di partenza
	if pid_da >= 0:
		if not await rilevamento(f, pilota, gruppo, pid_da):
			return
		if pid_da == pid_a:
			_arrivo_nave(gruppo, a, da)
			return
	# iperbalzo
	if stella_da != stella_a:
		var nav := m.val(pilota, "navigazione") + (1 if int(nave.get("nr", 0)) == 40 else 0)
		var dist := 2 if da.begins_with("D2:") else distanza(stella_da, stella_a)
		dist += m.galattico.extra_distanza(stella_da, stella_a)
		var r := tira_iperbalzo(dist, nav)
		m.scrivi("Iperbalzo di %s: distanza %d, navigazione %d » %s." % [nave["nome"], dist, nav, _nome_esito_iperbalzo(r)])
		m.evento.emit("iperbalzo", {"f": f, "esito": r})
		await m.attesa(0.6)
		for id in gruppo:
			m.unita[id]["ind"] = false
		if r.ends_with("E"):
			for id in gruppo:
				m.uccidi(id, "disastro nell'iperspazio")
			return
		if r.ends_with("D"):
			if nave.get("dmg", false):
				for id in gruppo:
					m.uccidi(id, "astronave distrutta nell'iperspazio")
				return
			nave["dmg"] = true
		if r.begins_with("1"):
			_arrivo_nave(gruppo, "D:%d" % stella_a, da)
			return
		if r.begins_with("2"):
			_arrivo_nave(gruppo, "D2:%d" % stella_a, da)
			return
	if not await rilevamento(f, pilota, gruppo, pid_a):
		return
	_arrivo_nave(gruppo, a, da)


func _arrivo_nave(gruppo: Array, a: String, da: String) -> void:
	for id in gruppo:
		m._sposta_pg(id, a)
	m.evento.emit("volo", {"da": da, "a": a, "f": m.unita[gruppo[0]]["fz"]})
	if m.livello != "sistema":
		m.galattico.rivela_in_orbita(a)


## Rilevamento con BDP e flotte in orbita (9.3 e 20.7). False se l'astronave è distrutta.
func rilevamento(f: int, pilota: int, gruppo: Array, pid: int) -> bool:
	var nemico := m.avversario(f)
	var liv := m.bdp_attiva(pid, f)
	var orb := mil_libere(orbita_di(pid), nemico)
	var forza_orb := spazio_mil(orb)
	if liv < 0 and forza_orb < 5:
		return true
	var nave: Dictionary = m.unita[pilota]["nave"]
	var ev := m.valore_evasione(pilota)
	var col := 7
	var limiti := [0, 1, 2, 3, 4, 6, 8]
	for i in limiti.size():
		if ev <= limiti[i]:
			col = i
			break
	var liv_eff := liv
	var extra := forza_orb
	if liv < 0:
		liv_eff = 0
		extra = forza_orb - 5
	if liv_eff == 2:
		col -= 2
	if m.unita[pilota]["ind"]:
		col -= 1
	col -= int(maxi(0, extra) / 3)
	for id in gruppo:
		if m.unita[id]["poss"].has(44):
			if liv_eff > 0:
				col += 2 if liv_eff == 2 else 0
			break
	col += m.galattico.spostamento_deltronics(pid, f, nave)
	col = clampi(col, 0, 7)
	var d := m.dado()
	var cella: String = Dati.d()["tabelle"]["rilevamento"]["righe_dado"][d - 1][col]
	var stella := cella.ends_with("*")
	var ris := cella.replace("*", "")
	if liv_eff == 0 and (ris == "Dd" or ris == "E"):
		ris = "D"
		if cella == "E*":
			stella = true
	elif ris == "E" and stella:
		stella = false
	if orb.is_empty():
		stella = false
	if ris == "Dd" and nave.get("dmg", false):
		ris = "E"
	var nomi := {"U": "non individuata", "D": "individuata", "Dd": "individuata e danneggiata", "E": "distrutta"}
	m.scrivi("Rilevamento su %s (BDP %s, flotte %d): dado %d, evasione %d » %s%s." % [Dati.pianeta(pid)["nome"], str(liv) if liv >= 0 else "assente", forza_orb, d, ev, nomi[ris], ", attacco della squadriglia" if stella else ""])
	m.evento.emit("rilevamento", {"pid": pid, "dado": d, "esito": ris, "f": f})
	await m.attesa(0.6)
	match ris:
		"U":
			for id in gruppo:
				m.unita[id]["ind"] = false
		"D":
			for id in gruppo:
				m.unita[id]["ind"] = true
		"Dd":
			for id in gruppo:
				m.unita[id]["ind"] = true
			nave["dmg"] = true
		"E":
			for id in gruppo:
				m.uccidi(id, "abbattuto con l'astronave")
			return false
	if stella:
		return await squadriglia(f, pilota, gruppo, orb)
	return true


## Attacco di una squadriglia della flotta su un'astronave (20.71).
func squadriglia(f: int, pilota: int, gruppo: Array, orb: Array) -> bool:
	var nave: Dictionary = m.unita[pilota]["nave"]
	var mx := 0
	for id in orb:
		mx = maxi(mx, int(m.unita[id].get("spazio", 0)))
	var scudi := int(Dati.d()["poss"].get(int(nave.get("nr", 0)), {}).get("scudi", 2 if nave.get("redjac", false) else 1))
	var tab: Dictionary = Dati.d()["tabelle"]["combattimento_personaggi"]
	var col := 9
	var diff := mx - scudi
	for i in tab["limiti_superiori"].size():
		if diff <= int(tab["limiti_superiori"][i]):
			col = i
			break
	var k := await m.scegli(f, "Una squadriglia nemica (differenza %d) attacca %s. Tenti di sganciarti?" % [diff, nave["nome"]], [{"t": "Tento lo sganciamento"}, {"t": "Affronto l'attacco"}], {"chiave": "sganciamento", "diff": diff, "conferma": true})
	if k == 0:
		if m.dado() <= int(tab["sganciamento_attivi"][col]):
			m.scrivi("%s sfugge alla squadriglia." % nave["nome"])
			return true
		col = mini(9, col + 1)
	var d := m.dado()
	var fer: int = tab["righe_dado"][d - 1][col][2]
	m.scrivi("Squadriglia: dado %d » %d." % [d, fer])
	if fer >= 2:
		for id in gruppo:
			m.uccidi(id, "abbattuto dalla squadriglia")
		return false
	if fer == 1:
		if nave.get("dmg", false):
			for id in gruppo:
				m.uccidi(id, "abbattuto dalla squadriglia")
			return false
		nave["dmg"] = true
		m.scrivi("%s è danneggiata." % nave["nome"])
	return true


# -------------------------------------------------------------------------------------
# Movimento di superficie (20.3)
# -------------------------------------------------------------------------------------

func movimento_superficie(f: int) -> void:
	while m.esito == "":
		var opz := []
		var visti := {}
		for id in m.unita:
			var u: Dictionary = m.unita[id]
			if u["k"] != "mil" or u["fz"] != f or u.get("interc", false) or u.get("atrocita", false):
				continue
			var l: String = u["luogo"]
			if not (m.is_amb(l) or m.is_orbita(l)) or visti.has(l) or u.get("sup_mosso", false):
				continue
			if Dati.pianeta(m.pid_di(l))["ambienti"].size() < 2 and m.is_amb(l):
				continue
			visti[l] = true
			opz.append({"t": "Truppe in %s" % m.nome_luogo(l), "luogo_da": l})
		opz.append({"t": "Fine del movimento di superficie", "fine": true})
		var k := await m.scegli(f, "Movimento di superficie: chi muovi?", opz, {"chiave": "mov_superficie", "conferma": true})
		if opz[k].get("fine", false):
			break
		var da: String = opz[k]["luogo_da"]
		var mm := m.mil_in(da, f).filter(func(x): return not m.unita[x].get("interc", false) and not m.unita[x].get("sup_mosso", false) and not m.unita[x].get("atrocita", false))
		var o2 := []
		for id in mm:
			o2.append({"t": m.descr_mil(id), "id": id})
		var sel := await m.scegli_multi(f, "Quali truppe muovi da %s?" % m.nome_luogo(da), o2, {"chiave": "truppe_sel", "min": 1})
		var pila := []
		for i in sel:
			pila.append(mm[i])
		if pila.is_empty():
			for id in mm:
				m.unita[id]["sup_mosso"] = true
			continue
		var pid := m.pid_di(da)
		var dest := []
		for i in Dati.pianeta(pid)["ambienti"].size():
			var l := "%d:%d" % [pid, i]
			if l != da and m.mil_in(l, f).size() + pila.size() <= m.taglia(l):
				dest.append({"t": "%s (%d/%d)" % [m.nome_luogo(l), m.mil_in(l, f).size(), m.taglia(l)], "luogo": l})
		if dest.is_empty():
			for id in pila:
				m.unita[id]["sup_mosso"] = true
			continue
		var kd := await m.scegli(f, "Dove vanno le truppe?", dest, {"chiave": "dest_truppe"})
		var a: String = dest[kd]["luogo"]
		var pp := m.pg_in(da, f, true).filter(func(x): return not m.unita[x].get("sovrano", false))
		var accomp := []
		if not pp.is_empty():
			var o3 := []
			for id in pp:
				o3.append({"t": m.unita[id]["nome"], "id": id})
			var s3 := await m.scegli_multi(f, "Quali personaggi scendono con le truppe?", o3, {"chiave": "accompagna"})
			for i in s3:
				accomp.append(pp[i])
		for id in pila:
			m.unita[id]["sup_mosso"] = true
		if m.is_orbita(da):
			await attacco_radente(f, pila, pid)
			pila = pila.filter(func(x): return m.vivo(x))
		_sposta(pila, accomp, a)
		m.cambiato.emit()
	for id in m.unita:
		m.unita[id].erase("sup_mosso")


# =====================================================================================
# EFFETTO DOMINO (23.0)
# =====================================================================================

func _razze_stellari(pid: int) -> Array:
	var out := []
	for a in Dati.pianeta(pid)["ambienti"]:
		for r in a.get("razze", []):
			if r.get("stellare", false) and not out.has(r["nome"]):
				out.append(r["nome"])
	return out


func _patria_di(razza: String) -> int:
	for p in Dati.d()["galassia"]["pianeti"]:
		if p.get("status", null) != null and str(p["status"]) == razza:
			return int(p["id"])
	return -1


func _importante(pid: int) -> bool:
	return m.galattico.capitale(pid)


## Domino: tipo = "lealta" (due spostamenti da una missione), "ribellione", "fermata", "controllo".
func domino(pid: int, tipo: String, f: int) -> void:
	if m.galattico.domino_bloccato() or m.galattico.segreto_attivo(pid, "vivo"):
		return
	var nome: String = Dati.pianeta(pid)["nome"]
	var gia := {pid: true}
	var stella := int(pid / 10)
	var nel_sistema := m.scenario_pianeti().filter(func(x): return int(x / 10) == stella and x != pid and not m.distrutto(x))
	var tutti_sistema := tipo != "lealta"
	var cand_sistema := nel_sistema.filter(func(x): return _ammesso(x, pid, f, tipo))
	var scelti := []
	if tutti_sistema:
		scelti = cand_sistema.duplicate()
	elif not cand_sistema.is_empty():
		scelti.append(await _scegli_pianeta(f, cand_sistema, "Effetto domino da %s: quale pianeta del sistema si sposta di uno a tuo favore?" % nome))
	for x in scelti:
		gia[x] = true
	for razza in _razze_stellari(pid):
		var patria := _patria_di(razza)
		var stessa := m.scenario_pianeti().filter(func(x): return not gia.has(x) and x != patria and _razze_stellari(x).has(razza) and _ammesso(x, pid, f, tipo) and not m.distrutto(x))
		if pid == patria:
			# patria di una razza stellare: tutti i pianeti della razza nella provincia, più uno o due fuori
			var prov := int(pid / 100)
			var dentro := stessa.filter(func(x): return int(x / 100) == prov)
			var fuori := stessa.filter(func(x): return int(x / 100) != prov)
			if tipo == "controllo":
				dentro = stessa
				fuori = []
			for x in dentro:
				scelti.append(x)
				gia[x] = true
			var n_fuori := 0 if m.livello != "galassia" else (1 if tipo == "lealta" else 2)
			for i in n_fuori:
				fuori = fuori.filter(func(x): return not gia.has(x))
				if fuori.is_empty():
					break
				var y := await _scegli_pianeta(f, fuori, "Effetto domino (%s): quale pianeta fuori provincia?" % razza)
				scelti.append(y)
				gia[y] = true
		else:
			var n := 1 if tipo == "lealta" else 2
			for i in n:
				stessa = stessa.filter(func(x): return not gia.has(x))
				if stessa.is_empty():
					break
				var y2 := await _scegli_pianeta(f, stessa, "Effetto domino (%s): quale altro pianeta della stessa razza?" % razza)
				scelti.append(y2)
				gia[y2] = true
	if scelti.is_empty():
		return
	m.scrivi("Effetto domino da %s." % nome)
	m.evento.emit("domino", {"pid": pid})
	var in_rivolta := []
	for x in scelti:
		var p: Dictionary = m.pianeti[x]
		if tipo == "controllo" and f == Motore.R and p["lealta"] == 4 and p["stato"] in ["imperiale", "fermata"]:
			in_rivolta.append(x)
			continue
		m.sposta_lealta(x, 1, f, false)
	for x in in_rivolta:
		await m.avvia_ribellione(x, {})


func _ammesso(x: int, origine: int, f: int, tipo: String) -> bool:
	var p: Dictionary = m.pianeti[x]
	if _importante(x) and not _importante(origine):
		return false
	if not p["stato"] in ["imperiale", "fermata"]:
		return false
	if f == Motore.R:
		if p["lealta"] == 0:
			return false
		if tipo != "controllo" and p["lealta"] == 4:
			return false
		if m.galattico.segreto_attivo(x, "impero"):
			return false
	else:
		if tipo == "lealta" and p["lealta"] >= 3:
			return false
		if tipo == "fermata" and p["lealta"] >= 4:
			return false
		if p["lealta"] == 0:
			return false
		if m.galattico.segreto_attivo(x, "benvenuti"):
			return false
	return true


func _scegli_pianeta(f: int, cand: Array, testo: String) -> int:
	var opz := []
	for x in cand:
		opz.append({"t": "%s (%s)" % [Dati.pianeta(x)["nome"], Dati.LEALTA_NOMI[m.pianeti[x]["lealta"]]], "pid": x})
	var k := await m.scegli(f, testo, opz, {"chiave": "domino"})
	return opz[k]["pid"]


# =====================================================================================
# SOVRANI (25.0)
# =====================================================================================

func sovrano_di(l: String) -> String:
	if not m.is_amb(l) or m.galattico.segreto_attivo(m.pid_di(l), "vivo"):
		return ""
	var s = Dati.ambiente(l).get("sovrano", null)
	return "" if s == null else str(s)


func fedelta_sovrano(nome: String) -> String:
	return str(Dati.d()["regole_avanzate"]["sovrani"].get(nome, {}).get("fed", "N"))


func puo_convocare(l: String, f: int) -> bool:
	var nome := sovrano_di(l)
	if nome == "" or m.sovrani.has(nome):
		return false
	var fed := fedelta_sovrano(nome)
	if (f == Motore.R and fed == "I") or (f == Motore.I and fed == "R"):
		return false
	var pid := m.pid_di(l)
	if m.pianeti[pid]["stato"] in ["ribellione", "ribelle"]:
		return false
	var prov := int(pid / 100)
	var in_rivolta := 0
	var stessa_razza := 0
	var razze := []
	for r in Dati.ambiente(l).get("razze", []):
		razze.append(r["nome"])
	for x in m.scenario_pianeti():
		if m.pianeti[x]["stato"] == "ribellione":
			if int(x / 100) == prov:
				in_rivolta += 1
			for a in Dati.pianeta(x)["ambienti"]:
				for r in a.get("razze", []):
					if razze.has(r["nome"]):
						stessa_razza += 1
	return in_rivolta >= 2 or stessa_razza >= 2


func convoca(l: String, f: int) -> void:
	var nome := sovrano_di(l)
	var d: Dictionary = Dati.d()["regole_avanzate"]["sovrani"][nome]
	m.sovrani[nome] = "convocato"
	var id := m.prossimo_id
	m.prossimo_id += 1
	var c := {"nome": nome, "combattimento": d["comb"], "resistenza": d["res"], "comando": d["com"], "comando_spazio": d["com_s"], "intelligenza": 0, "diplomazia": 0, "navigazione": 0, "fazione": "ribelli" if f == Motore.R else "imperiali", "speciale_it": "Sovrano convocato: non si muove (salvo in orbita se ha comando spaziale) e non svolge missioni da solo."}
	m.unita[id] = {"id": id, "k": "pg", "fz": f, "nome": nome, "luogo": l, "ferite": 0, "ind": false, "prig": -1, "truppe": false, "nave": {}, "poss": [], "mosso": true, "attivo_turno": true, "guarda": -1, "c": c, "sovrano": true, "ped": d["ped"]}
	m.scrivi("Il sovrano %s risponde all'appello dell'%s!" % [nome, "Alleanza ribelle" if f == Motore.R else "Impero"])
	m.evento.emit("sovrano", {"nome": nome})
	m.sposta_lealta(m.pid_di(l), 1, f)
	var punti := int(Dati.ambiente(l).get("risorse", 0))
	if f == Motore.R:
		await compra_ribelli(l, punti, bool(Dati.ambiente(l).get("risorse_stella", false)))
	else:
		await compra_imperiali(l, punti)


# =====================================================================================
# RIPARAZIONI (27.0)
# =====================================================================================

func riparazioni(f: int) -> void:
	for id in m.unita:
		var u: Dictionary = m.unita[id]
		if u["k"] != "pg" or u["fz"] != f or not m.vivo(id) or u["nave"].is_empty() or not u["nave"].get("dmg", false):
			continue
		if int(u["nave"].get("nr", 0)) == 40:
			continue
		var l: String = u["luogo"]
		var tecnici := m.pg_in(l, f, true)
		var yarro := tecnici.any(func(x): return m.unita[x]["nome"] == "Yarro Latac")
		var best := 0
		for t in tecnici:
			best = maxi(best, m.val(t, "navigazione"))
		for e in m.mil_in(l, f):
			if m.unita[e].get("elite", false) and m.is_amb(l):
				best = maxi(best, int(m.unita[e].get("spazio", 0)))
		if yarro:
			u["nave"]["dmg"] = false
			m.scrivi("Yarro Latac ripara %s." % u["nave"]["nome"])
		elif best > 0:
			var d := m.dado()
			if d <= best:
				u["nave"]["dmg"] = false
				m.scrivi("%s riparata (dado %d)." % [u["nave"]["nome"], d])
			else:
				m.scrivi("Riparazione di %s fallita (dado %d)." % [u["nave"]["nome"], d])
