class_name Missioni
extends RefCounted
## Fase delle Missioni (Sezione 13.0): assegnazione, carte Azione con i loro eventi, lettere di missione,
## pescate bonus ed effetti delle missioni nello Star System Game.

const MULTI := {"C": 9, "D": 2, "F": 9, "I": 2, "S": 2, "T": 2, "E": 2, "H": 2}
const CAMPO := ["C", "D", "F", "I", "S", "T"]

var m: Motore
var f := 0
var nemico := 1
var luogo := ""
var gruppi: Array = []      # {lettera, pg:[id], campo:bool, lettere:int, stato:"corso"|"fatta"|"abortita", bersaglio, cercato}
var flag := {}              # eventi persistenti nell'ambiente per questa fase
var pescate := 0


func _init(motore: Motore) -> void:
	m = motore


func fase_missioni(fz: int) -> void:
	f = fz
	nemico = m.avversario(fz)
	var fatti := {}
	while m.esito == "":
		var luoghi := []
		for l in m.luoghi_sistema():
			if fatti.has(l):
				continue
			if not _disponibili(l).is_empty() or _campo_attivo(l):
				luoghi.append(l)
		if luoghi.is_empty():
			break
		var opz := []
		for l in luoghi:
			opz.append({"t": "Missioni in %s" % m.nome_luogo(l), "luogo": l})
		opz.append({"t": "Fine delle missioni", "fine": true})
		var k := await m.scegli(f, "Fase delle Missioni: dove agisci?", opz, {"chiave": "luogo_missioni", "conferma": true})
		if opz[k].get("fine", false):
			break
		fatti[opz[k]["luogo"]] = true
		await missioni_in(opz[k]["luogo"])
		m.aggiorna_controllo()
		m.controlla_vittoria_istantanea()
		m.cambiato.emit()


func _disponibili(l: String) -> Array:
	var out := []
	for id in m.pg_in(l, f, true):
		var u: Dictionary = m.unita[id]
		if u["truppe"]:
			continue
		var custode := false
		for o in m.unita:
			if m.unita[o]["k"] == "pg" and m.unita[o]["prig"] == id:
				custode = true
		if custode and m.pg_in(l, f, true).size() == 1:
			continue
		out.append(id)
	return out


func _campo_attivo(l: String) -> bool:
	return f == Motore.R and m.campi.has(l) and int(m.campi[l]) < m.turno


# --------------------------------------------------------------------------------------
# Assegnazione
# --------------------------------------------------------------------------------------

func missioni_in(l: String) -> void:
	luogo = l
	gruppi = []
	flag = {}
	pescate = 0
	var pid := m.pid_di(l)
	var liberi := _disponibili(l)
	for id in liberi:
		var opz := [{"t": "Nessuna missione (riposa o resta pronto)"}]
		for g in gruppi:
			if not g["campo"]:
				opz.append({"t": "Si unisce a: %s (%s)" % [_nome_mis(g["lettera"]), ", ".join(g["pg"].map(func(x): return m.unita[x]["nome"]))], "unisci": g})
		for lt in valide(l, [id]):
			# una sola missione dello stesso tipo per ambiente
			if gruppi.any(func(g): return g["lettera"] == lt):
				continue
			opz.append({"t": "Nuova missione: %s" % _nome_mis(lt), "lettera": lt})
		var k := await m.scegli(f, "%s in %s: quale missione?" % [m.unita[id]["nome"], m.nome_luogo(l)], opz, {"chiave": "assegna", "id": id, "luogo": l, "conferma": true})
		var o: Dictionary = opz[k]
		if o.has("unisci"):
			o["unisci"]["pg"].append(id)
		elif o.has("lettera"):
			var g := {"lettera": o["lettera"], "pg": [id], "campo": false, "lettere": 0, "stato": "corso", "bersaglio": -1, "cercato": false}
			gruppi.append(g)
	if _campo_attivo(l):
		var opz2 := [{"t": "Il Campo ribelle non agisce"}]
		for lt in valide(l, []):
			if lt in CAMPO and not gruppi.any(func(g): return g["lettera"] == lt):
				opz2.append({"t": "Campo ribelle: %s" % _nome_mis(lt), "lettera": lt})
		var k2 := await m.scegli(f, "Il Campo ribelle in %s può svolgere una missione." % m.nome_luogo(l), opz2, {"chiave": "campo", "conferma": true})
		if k2 > 0:
			gruppi.append({"lettera": opz2[k2]["lettera"], "pg": [], "campo": true, "lettere": 0, "stato": "corso", "bersaglio": -1, "cercato": false})
	if gruppi.is_empty():
		return
	# bersagli dell'Assassinio, nominati prima di pescare
	for g in gruppi:
		for id in g["pg"]:
			m.unita[id]["attivo_turno"] = true
		if g["lettera"] == "A":
			var bers := _individuati_nemici(l)
			var opz3 := []
			for b in bers:
				opz3.append({"t": m.unita[b]["nome"], "id": b})
			var kb := await m.scegli(f, "Chi è il bersaglio dell'Assassinio?", opz3, {"chiave": "bersaglio"})
			g["bersaglio"] = bers[kb]
	m.scrivi("%s: %s." % [m.nome_luogo(l), "; ".join(gruppi.map(func(g): return "%s (%s)" % [_nome_mis(g["lettera"]), "Campo ribelle" if g["campo"] else ", ".join(g["pg"].map(func(x): return m.unita[x]["nome"]))]))])
	m.evento.emit("missioni", {"luogo": l, "gruppi": gruppi.map(func(g): return g["lettera"])})
	await _pesca(l)
	m.cambiato.emit()


func valide(l: String, pg: Array) -> Array:
	var out := []
	var pid := m.pid_di(l)
	var p: Dictionary = m.pianeti[pid]
	var amb := Dati.ambiente(l)
	var su_traccia: bool = p["stato"] in ["imperiale", "fermata"]
	var nemici_mil := m.mil_in(l, nemico)
	var bdp_nemica := m.controllo(pid) == nemico
	if not nemici_mil.is_empty() or bdp_nemica:
		out.append("S")
	if su_traccia:
		out.append("D")
	if f == Motore.R and su_traccia and p["lealta"] >= 3:
		out.append("R")
	if f == Motore.I and p["stato"] == "ribellione":
		out.append("R")
	if f == Motore.R and not m.mazzo_poss.is_empty():
		out.append("P")
	if not m.mazzo_pg[f].is_empty():
		if f == Motore.R:
			out.append("G")
		else:
			var vivi := 0
			for id in m.unita:
				if m.unita[id]["k"] == "pg" and m.unita[id]["fz"] == Motore.I and m.vivo(id) and m.unita[id]["prig"] < 0:
					vivi += 1
			if vivi <= m.scenario["fazioni"]["1"]["personaggi"].size():
				out.append("G")
	if not (m.controllo(pid) == f and nemici_mil.is_empty() and m.pg_in(l, nemico).is_empty()):
		out.append("I")
	for id in m.pg_in(l, f):
		if m.unita[id]["prig"] >= 0:
			out.append("F")
			break
	if not _individuati_nemici(l).is_empty() and not pg.is_empty():
		out.append("A")
	if f == Motore.R and p["stato"] == "imperiale" and p["lealta"] <= 1 and not m.campi.has(l) and not pg.is_empty():
		out.append("B")
	if f == Motore.R and not nemici_mil.is_empty():
		out.append("T")
	if m.livello != "sistema":
		if not pg.is_empty() and m.av.puo_convocare(l, f):
			out.append("E")
		var prig_nemici := m.pg_in(l, nemico).filter(func(x): return m.unita[x]["prig"] >= 0)
		if m.livello == "galassia" and not prig_nemici.is_empty() and pg.size() == 1:
			out.append("Q")
		if m.livello == "galassia" and not pg.is_empty() and int(m.pf[nemico]) >= 2:
			if f == Motore.R and m.controllo(pid) == Motore.I and (m.galattico.capitale(pid) or int(pid / 100) == m.galattico.provincia_tassata()):
				out.append("H")
			if f == Motore.I and m.galattico.base_svelata and pid == m.galattico.base:
				out.append("H")
	if m.galattico.segreto_attivo(pid, "vivo"):
		out.erase("C")
		out.erase("E")
	if f == Motore.R and m.evento_attivo(107) and pid == 421:
		out.erase("D")
	if m.evento_attivo(120) and pg.any(func(x): return m.unita[x]["c"].get("razza_en", "") == "Kayn"):
		return []
	if amb.get("coup", null) != null and not p["coup"].has(l) and su_traccia and not m.galattico.segreto_attivo(pid, "vivo") and not (f == Motore.R and m.evento_attivo(107) and pid == 421):
		var ok := pg.is_empty()
		for id in pg:
			if m.val(id, "intelligenza") > 1:
				ok = true
		if ok:
			out.append("C")
	return out


func _individuati_nemici(l: String) -> Array:
	var out := []
	for id in m.pg_in(l, nemico, true):
		if m.unita[id]["ind"]:
			out.append(id)
	return out


func _nome_mis(lt: String) -> String:
	var c: Dictionary = Dati.d()["missioni"].get(lt, {})
	var n: String = c.get("nome_it", lt)
	if lt == "R":
		n = "Avvia Ribellione" if f == Motore.R else "Ferma Ribellione"
	return "%s (%s)" % [n, lt]


# --------------------------------------------------------------------------------------
# Pescate
# --------------------------------------------------------------------------------------

func _sezione(l: String) -> String:
	var t := m.tipo_amb(l)
	if t == "urbano":
		return "urbano"
	if t == "selvaggio":
		return "selvaggio"
	return "speciale"


func _in_corso() -> Array:
	return gruppi.filter(func(g): return g["stato"] == "corso" and (g["campo"] or g["pg"].any(func(x): return m.vivo(x) and m.unita[x]["prig"] < 0 and m.unita[x]["luogo"] == luogo)))


func _pesca(l: String) -> void:
	var mazzo: Array = Dati.d()["carte"]["azione"].duplicate()
	m._mescola(mazzo)
	var sez := _sezione(l)
	var limite := m.taglia(l)
	var completo := true
	while pescate < limite:
		if _in_corso().is_empty():
			completo = false
			break
		if pescate > 0:
			var k := await m.scegli(f, "Hai pescato %d carte Azione su %d. Continui?" % [pescate, limite], [{"t": "Pesco un'altra carta"}, {"t": "Mi fermo (niente pescate bonus)"}], {"chiave": "continua_pesca", "conferma": true})
			if k == 1:
				completo = false
				break
		var carta: Dictionary = mazzo[pescate]
		pescate += 1
		var cod: String = str(carta["codice"].get(sez, ""))
		var lettere: Array = carta["en"][sez].get("lettere", [])
		m.scrivi("Carta Azione nr. %d: %s %s" % [carta["nr"], carta["it"][sez].get("evento", ""), ("— lettere: " + " ".join(lettere)) if not lettere.is_empty() else ""])
		m.evento.emit("carta_azione", {"nr": carta["nr"], "sezione": sez, "lettere": lettere, "codice": cod})
		await m.attesa(0.9)
		await _evento(cod, carta)
		if m.esito != "":
			return
		await _lettere(lettere)
		m.cambiato.emit()
	# 13.52: missioni a più lettere ancora aperte
	for g in gruppi:
		if g["stato"] == "corso" and g["lettere"] > 0 and not completo:
			await _completa(g)
	if completo:
		await _bonus()
	for g in gruppi:
		if g["stato"] == "corso":
			if g["lettere"] > 0:
				await _completa(g)
			elif g["lettera"] == "A" and _vivi(g):
				await _fallimento_assassinio(g)


func _vivi(g: Dictionary) -> bool:
	return g["campo"] or g["pg"].any(func(x): return m.vivo(x) and m.unita[x]["prig"] < 0)


func _lettere(lettere: Array) -> void:
	for g in _in_corso():
		var lt: String = g["lettera"]
		if not lettere.has(lt):
			continue
		g["lettere"] += 1
		var serve := 2 if (lt == "R" and f == Motore.I) else 1
		if g["lettere"] < serve:
			m.scrivi("Prima lettera R: per fermare la ribellione ne serve un'altra.")
			continue
		if MULTI.has(lt) and g["lettere"] < int(MULTI[lt]) and pescate < m.taglia(luogo):
			var k := await m.scegli(f, "%s: %d lettera/e. Completi ora la missione o continui a pescare per un risultato migliore?" % [_nome_mis(lt), g["lettere"]], [{"t": "Completo ora"}, {"t": "Continuo a pescare"}], {"chiave": "completa_ora", "lettera": lt, "n": g["lettere"], "conferma": true})
			if k == 1:
				continue
		await _completa(g)


func _bonus() -> void:
	if m.evento_attivo(126):
		flag.erase("no_bonus")
		for g in gruppi:
			g.erase("no_bonus")
	if m.evento_attivo(110) and m.pid_di(luogo) == 312:
		flag["no_bonus"] = true
	if flag.get("no_bonus", false):
		m.scrivi("Nessuna pescata bonus in questo ambiente.")
		return
	var mazzo: Array = Dati.d()["carte"]["azione"].duplicate()
	m._mescola(mazzo)
	var sez := _sezione(luogo)
	var pos := 0
	for g in gruppi:
		if g["stato"] != "corso" or g["campo"] or not _vivi(g) or g.get("no_bonus", false):
			continue
		var n := _conta_bonus(g)
		if n <= 0:
			continue
		var trovate := 0
		for i in n:
			var carta: Dictionary = mazzo[pos % mazzo.size()]
			pos += 1
			if carta["en"][sez].get("lettere", []).has(g["lettera"]):
				trovate += 1
		m.scrivi("Pescate bonus per %s: %d carte, %d lettere %s." % [_nome_mis(g["lettera"]), n, trovate, g["lettera"]])
		m.evento.emit("bonus", {"lettera": g["lettera"], "n": n, "trovate": trovate})
		await m.attesa(0.6)
		if trovate > 0:
			var mx := int(MULTI.get(g["lettera"], 1))
			var serve := 2 if (g["lettera"] == "R" and f == Motore.I) else 1
			g["lettere"] = mini(g["lettere"] + trovate, maxi(mx, serve))
			if g["lettere"] >= serve:
				await _completa(g)


func _conta_bonus(g: Dictionary) -> int:
	var lt: String = g["lettera"]
	var pg: Array = g["pg"].filter(func(x): return m.vivo(x) and m.unita[x]["prig"] < 0)
	if pg.is_empty():
		return 0
	var meglio := func(attr: String) -> int:
		var b := 0
		for id in pg:
			b = maxi(b, _attr(id, attr))
		return b
	var n := 0
	var p: Dictionary = m.pianeti[m.pid_di(luogo)]
	match lt:
		"D":
			var leal: int = (2 - p["lealta"]) if f == Motore.I else (p["lealta"] - 2)
			n = meglio.call("diplomazia") + pg.size() - 1 + leal
		"I", "A":
			n = meglio.call("intelligenza")
		"B", "T":
			n = meglio.call("comando")
		"C":
			n = meglio.call("comando") + int(Dati.ambiente(luogo).get("coup", 0))
		"R":
			n = 0 if f == Motore.I else 0
		"E":
			n = meglio.call("diplomazia") + meglio.call("comando")
		"H":
			n = meglio.call("intelligenza") + pg.size() - 1
		"Q":
			var prig := m.pg_in(luogo, nemico).filter(func(x): return m.unita[x]["prig"] >= 0)
			n = 3 + meglio.call("intelligenza") - (m.val(prig[0], "intelligenza") if not prig.is_empty() else 0)
	# 26.0: pianeta natale e regalità
	if m.livello != "sistema":
		var pid_l := m.pid_di(luogo)
		var nat := 0
		for id in pg:
			nat = maxi(nat, m.natale(id, pid_l))
		if nat >= 1 and lt in ["A", "B", "E", "F", "G", "P", "S", "H"]:
			n += 1
		if nat == 2 and lt in ["C", "D", "I", "R", "T", "E"]:
			n += 1
		if m.galattico.segreto_attivo(pid_l, "iper"):
			n += 1
	var E: Dictionary = Dati.d()["possessi_effetti"]
	for id in pg:
		n += int(E.get("pg_" + m.unita[id]["nome"], {}).get("bonus", {}).get(lt, 0))
		for nr in m.unita[id]["poss"]:
			n += int(E.get(str(nr), {}).get("bonus", {}).get(lt, 0))
	if flag.get("bonus_extra", false):
		n += 1
	n -= int(g.get("meno_bonus", 0))
	if lt == "R" and f == Motore.I:
		n = 0
	return n


## Valore di un personaggio, con Kogus più forte accanto a Zina Adora.
func _attr(id: int, attr: String) -> int:
	var v := m.val(id, attr)
	if m.unita[id]["nome"] == "Kogus":
		for o in m.pg_in(m.unita[id]["luogo"], m.unita[id]["fz"], true):
			if m.unita[o]["nome"] == "Zina Adora":
				v += 1
	return v


# --------------------------------------------------------------------------------------
# Eventi delle carte Azione (13.4)
# --------------------------------------------------------------------------------------

func _gruppo_a_caso(soli_pg := true) -> Dictionary:
	var cand := _in_corso().filter(func(g): return not g["campo"] or not soli_pg)
	if cand.is_empty():
		return {}
	return cand[m.rng.randi_range(0, cand.size() - 1)]


func _evento(cod: String, carta: Dictionary) -> void:
	var pid := m.pid_di(luogo)
	var p: Dictionary = m.pianeti[pid]
	match cod:
		"CREATURA", "CREATURA_O_ROBOT", "CREATURA_O_DUE_ROBOT":
			if flag.get("creatura", false) or flag.get("no_creatura", false):
				return
			var g := _gruppo_a_caso()
			if g.is_empty():
				return
			var nome = Dati.ambiente(luogo).get("creatura", null)
			var robot := 0
			if nome == null:
				robot = 1 if cod == "CREATURA_O_ROBOT" else (2 if cod == "CREATURA_O_DUE_ROBOT" else 0)
				if robot == 0 or m.controllo(pid) != nemico:
					return
				if g["pg"].any(func(x): return m.unita[x]["nome"] == "Yarro Latac"):
					m.scrivi("Yarro Latac neutralizza i robot sentinella.")
					return
				nome = "Sentry Robot"
			flag["creatura"] = true
			if _ignora_prima_creatura(g):
				return
			var cb := Combattimento.new(m)
			var r := await cb.creatura_contro(str(nome), _pg_vivi(g), luogo, robot)
			_post_attacco(g, r)
		"NESSUNA_CREATURA":
			flag["no_creatura"] = true
		"LOCALI_ARRABBIATI":
			if f == Motore.R and p["stato"] in ["ribellione", "ribelle"]:
				return
			var g2 := _gruppo_a_caso()
			if g2.is_empty():
				return
			if g2["pg"].any(func(x): return m.unita[x]["nome"] == "Oneste Woada"):
				m.scrivi("Oneste Woada calma i locali.")
				return
			var cb2 := Combattimento.new(m)
			var r2 := await cb2.locali_contro(_pg_vivi(g2), luogo)
			_post_attacco(g2, r2)
		"RAZZIA_LOCALI":
			var opz := []
			for id in m.mil_in(luogo, nemico):
				opz.append({"t": "Elimino %s" % m.descr_mil(id), "id": id})
			if m.controllo(pid) == nemico and p["su"]:
				opz.append({"t": "Metto fuori uso il BDP di %s" % Dati.pianeta(pid)["nome"], "bdp": true})
			if opz.is_empty():
				return
			var k := await m.scegli(nemico, "Razzia dei locali in %s: cosa perdi?" % m.nome_luogo(luogo), opz, {"chiave": "razzia"})
			if opz[k].has("bdp"):
				p["su"] = false
				m.scrivi("I locali mettono fuori uso il BDP.")
			else:
				m.unita[opz[k]["id"]]["luogo"] = "morto"
				m.scrivi("I locali eliminano %s." % m.descr_mil(opz[k]["id"]))
		"RIPARO_LOCALI", "NESSUNA_RICERCA":
			flag["no_ricerca"] = true
		"PERSONAGGI_INDIVIDUATI":
			_individua_tutti()
		"RICERCA_NEMICA":
			_individua_tutti()
			if flag.get("no_ricerca", false):
				return
			var cand := _in_corso().filter(func(g): return not g["campo"] and not g["cercato"])
			if cand.is_empty():
				return
			var g3: Dictionary = cand[m.rng.randi_range(0, cand.size() - 1)]
			g3["cercato"] = true
			await m.ricerca_in(nemico, f, luogo, _pg_vivi(g3), true)
			_aggiorna_gruppo(g3)
		"BONUS_EXTRA":
			if not flag.get("no_bonus", false):
				flag["bonus_extra"] = true
		"NESSUN_BONUS":
			if not flag.get("bonus_extra", false):
				flag["no_bonus"] = true
		"POPOLAZIONE_IN_RIVOLTA":
			flag["rivolta"] = true
		"GUERRA_CIVILE":
			if not p["stato"] in ["imperiale", "fermata"]:
				return
			var verso_f: int = (2 - p["lealta"]) if f == Motore.I else (p["lealta"] - 2)
			if verso_f in [1, 2]:
				p["lealta"] = 2
				m.scrivi("Guerra civile: %s torna Neutrale." % Dati.pianeta(pid)["nome"])
		"SQUADRA_NEMICA":
			if m.controllo(pid) != nemico or m.mil_in(luogo, nemico).is_empty():
				return
			var g4 := _gruppo_a_caso()
			if g4.is_empty():
				return
			var cb4 := Combattimento.new(m)
			await cb4.squadra_contro(nemico, m.mil_in(luogo, nemico), _pg_vivi(g4), luogo)
			_aggiorna_gruppo(g4)
		"INCIDENTE":
			var tutti := []
			for g in _in_corso():
				tutti.append_array(_pg_vivi(g))
			if tutti.is_empty():
				return
			var opz5 := []
			for id in tutti:
				opz5.append({"t": "%s (resistenza %d)" % [m.unita[id]["nome"], m.resistenza_residua(id)], "id": id})
			var k5 := await m.scegli(f, "Incidente: chi viene ferito?", opz5, {"chiave": "incidente"})
			Combattimento.new(m)._distribuisci([tutti[k5]], 1)
			m.scrivi("%s si ferisce in un incidente." % m.unita[tutti[k5]]["nome"])
		"MISSIONE_R_ABORTITA":
			for g in _in_corso():
				if g["lettera"] == "R" and not g["campo"]:
					_abortisci(g)
					for id in _pg_vivi(g):
						m.unita[id]["ind"] = true
		"MISSIONE_T_ABORTITA":
			for g in _in_corso():
				if g["lettera"] == "T" and not g["campo"]:
					_abortisci(g)
					var capo_nemico := m.pg_in(luogo, nemico, true).filter(func(x): return m.unita[x]["truppe"])
					if not capo_nemico.is_empty():
						for id in _pg_vivi(g):
							m.cattura(id, capo_nemico[0])
					elif not m.mil_in(luogo, nemico).is_empty():
						await Combattimento.new(m).squadra_contro(nemico, m.mil_in(luogo, nemico), _pg_vivi(g), luogo)
		"MISSIONE_D_ABORTITA":
			for g in _in_corso():
				if g["lettera"] == "D" and not g["campo"]:
					if g["pg"].any(func(x): return m.unita[x]["poss"].has(52)) and not flag.get("androide", false):
						flag["androide"] = true
						m.scrivi("L'Androide consigliere salva la trattativa.")
						continue
					_abortisci(g)
					m.sposta_lealta(pid, 1, nemico)
		"DIPLOMAZIA_CONTROVERSA":
			for g in _in_corso():
				if g["lettera"] == "D" and not g["campo"]:
					var ok := false
					for id in _pg_vivi(g):
						if _attr(id, "diplomazia") >= 2:
							ok = true
					if not ok:
						_abortisci(g)
		"ATROCITA":
			if m.livello == "galassia":
				await m.galattico.atrocita(pid)
		"MISSIONE_CASUALE_ABORTITA":
			var cand2 := _in_corso().filter(func(g): return not g["campo"])
			if not cand2.is_empty():
				_abortisci(cand2[m.rng.randi_range(0, cand2.size() - 1)])
			_individua_tutti()
		_:
			if cod.begins_with("COUP_ABORTITO"):
				await _coup_abortito(cod)


func _ignora_prima_creatura(g: Dictionary) -> bool:
	for id in _pg_vivi(g):
		var u: Dictionary = m.unita[id]
		if u["poss"].has(50) and not flag.get("norrocks_" + str(id), false):
			flag["norrocks_" + str(id)] = true
			m.scrivi("Norrocks tiene a bada la creatura.")
			return true
		if u["nome"] == "Professor Mareg" and _sezione(luogo) != "urbano" and not flag.get("mareg", false):
			flag["mareg"] = true
			m.scrivi("Il Professor Mareg conosce la creatura e la evita.")
			return true
	return false


func _post_attacco(g: Dictionary, r: Dictionary) -> void:
	if r.get("no_bonus", false):
		g["no_bonus"] = true
	if r.get("meno_bonus", 0) > 0:
		g["meno_bonus"] = int(g.get("meno_bonus", 0)) + int(r["meno_bonus"])
	if r.get("zop", false):
		await _pesca_possesso(g, true)
	_aggiorna_gruppo(g)


func _aggiorna_gruppo(g: Dictionary) -> void:
	if not _vivi(g) and g["stato"] == "corso":
		g["stato"] = "abortita"


func _abortisci(g: Dictionary) -> void:
	g["stato"] = "abortita"
	g["lettere"] = 0
	m.scrivi("Missione abortita: %s." % _nome_mis(g["lettera"]))


func _pg_vivi(g: Dictionary) -> Array:
	return g["pg"].filter(func(x): return m.vivo(x) and m.unita[x]["prig"] < 0)


func _individua_tutti() -> void:
	for g in _in_corso():
		for id in _pg_vivi(g):
			m.unita[id]["ind"] = true


func _coup_abortito(cod: String) -> void:
	var tabella: Dictionary = Dati.d()["carte"]["codici_azione"][cod]["parametri"]["tabella_dado"]
	for g in _in_corso():
		if g["lettera"] != "C" or g["campo"]:
			continue
		_abortisci(g)
		var pg := _pg_vivi(g)
		for id in pg:
			m.unita[id]["ind"] = true
		var d := m.dado()
		var res := "nessun_effetto"
		for k in tabella:
			var a := int(str(k).get_slice("-", 0))
			var b := int(str(k).get_slice("-", 1)) if "-" in str(k) else a
			if d >= a and d <= b:
				res = tabella[k]
		m.scrivi("Colpo di Stato fallito: dado %d » %s." % [d, res.replace("_", " ").replace("+", ", ")])
		if "sposta" in res:
			m.sposta_lealta(m.pid_di(luogo), 1, nemico)
		var custode := m.custode_in(luogo, nemico)
		if "gruppo_ucciso" in res:
			for id in pg:
				m.uccidi(id, "colpo di Stato fallito")
		elif "gruppo_catturato" in res and custode >= 0:
			if "un_personaggio_ucciso" in res and not pg.is_empty():
				var opz := []
				for id in pg:
					opz.append({"t": m.unita[id]["nome"], "id": id})
				var k2 := await m.scegli(f, "Chi viene giustiziato?", opz, {"chiave": "giustiziato"})
				m.uccidi(pg[k2], "giustiziato")
				pg.remove_at(k2)
			for id in pg:
				m.cattura(id, custode)
		elif "gruppo_trovato" in res:
			var opz2 := []
			if not m.mil_in(luogo, nemico).is_empty():
				opz2.append({"t": "Con una squadra", "modo": "s"})
			var pgn := m.pg_in(luogo, nemico, true).filter(func(x): return not m.unita[x]["truppe"])
			if not pgn.is_empty():
				opz2.append({"t": "Con i miei personaggi", "modo": "p"})
			if opz2.is_empty():
				continue
			var k3 := await m.scegli(nemico, "Il gruppo del colpo di Stato è trovato: chi lo attacca?", opz2, {"chiave": "trovato_coup"})
			var cb := Combattimento.new(m)
			if opz2[k3]["modo"] == "s":
				await cb.squadra_contro(nemico, m.mil_in(luogo, nemico), pg, luogo)
			else:
				await cb.personaggi_contro(nemico, pgn, pg, luogo)


# --------------------------------------------------------------------------------------
# Effetti delle missioni
# --------------------------------------------------------------------------------------

func _completa(g: Dictionary) -> void:
	if g["stato"] != "corso":
		return
	g["stato"] = "fatta"
	var n: int = g["lettere"]
	var pid := m.pid_di(luogo)
	var p: Dictionary = m.pianeti[pid]
	m.scrivi("Missione riuscita: %s (%d lettera/e)." % [_nome_mis(g["lettera"]), n])
	m.evento.emit("missione_riuscita", {"lettera": g["lettera"], "luogo": luogo, "n": n})
	match g["lettera"]:
		"D":
			if f == Motore.R and m.galattico.segreto_attivo(pid, "vivo") and p["stato"] in ["imperiale", "fermata"]:
				p["lealta"] = 4
				await m.avvia_ribellione(pid, {})
				controlla_campi()
				return
			var eff := m.sposta_lealta(pid, mini(n, 2), f)
			if eff >= 2 and m.livello != "sistema":
				await m.av.domino(pid, "lealta", f)
		"C":
			var eff2 := m.sposta_lealta(pid, n, f)
			p["coup"][luogo] = true
			if eff2 >= 2 and m.livello != "sistema":
				await m.av.domino(pid, "lealta", f)
		"E":
			var fed := m.av.fedelta_sovrano(m.av.sovrano_di(luogo))
			if fed == "N" and n < 2:
				m.scrivi("Un sovrano neutrale richiede due lettere: non risponde all'appello.")
			elif m.av.puo_convocare(luogo, f):
				await m.av.convoca(luogo, f)
		"H":
			var q := 8 if n >= 2 else 2
			q = mini(q, int(m.pf[nemico]))
			m.pf[nemico] -= q
			m.pf[f] = mini(199 if f == Motore.R else 99, int(m.pf[f]) + q)
			m.scrivi("Rubati %d Punti Forza al nemico." % q)
		"Q":
			await m.galattico.segreto_nemico(f)
		"R":
			if f == Motore.R:
				if p["lealta"] == 4 and p["stato"] in ["imperiale", "fermata"]:
					var rad := {}
					if flag.get("rivolta", false):
						rad[luogo] = true
					await m.avvia_ribellione(pid, rad)
				else:
					m.scrivi("Il pianeta non è in Agitazione: la ribellione non parte.")
			else:
				if p["stato"] == "ribellione":
					p["stato"] = "fermata"
					m.scrivi("La ribellione su %s è fermata." % Dati.pianeta(pid)["nome"])
					if m.livello != "sistema":
						await m.av.domino(pid, "fermata", Motore.I)
		"S":
			await _sabotaggio(n)
		"P":
			await _pesca_possesso(g, false)
		"G":
			if m.mazzo_pg[f].is_empty():
				return
			var nome: String = m.mazzo_pg[f][0]
			var id := m.nuovo_pg(nome, f)
			m.unita[id]["luogo"] = luogo
			m.unita[id]["mosso"] = true
			m.unita[id]["attivo_turno"] = true
			m.scrivi("%s si unisce alla causa dell'%s!" % [nome, "Impero" if f == Motore.I else "Alleanza ribelle"])
			m.evento.emit("nuovo_pg", {"id": id})
			_nave_del_proprietario(id)
		"I":
			if _info_annullata():
				m.scrivi("Lo Scrigno di gemme rare compra il silenzio degli informatori.")
				return
			for id in m.unita:
				var u: Dictionary = m.unita[id]
				if u["fz"] == nemico and u["luogo"] != "" and u["luogo"] != "morto" and m.pid_di(u["luogo"]) == pid:
					if u["k"] == "pg":
						u["ind"] = true
					else:
						u["scoperta"] = true
			if m.livello == "galassia":
				if f == Motore.R and m.galattico.segreto_attivo(pid, "archivi"):
					m.scrivi("Gli Archivi imperiali svelano tutti i Segreti planetari!")
					for x in m.galattico.segreti.keys():
						await m.galattico.svela(x)
				if f == Motore.R and m.galattico.segreto_attivo(pid, "deltronics"):
					await _pesca_possesso(g, false)
				if n >= 2:
					await m.galattico.segreto_nemico(f)
			elif n >= 2:
				m.vittoria_info[f] = true
				m.scrivi("Un segreto nemico è svelato: Punto Vittoria per Raccogli informazioni.")
		"F":
			for i in n:
				var prig := m.pg_in(luogo, f).filter(func(x): return m.unita[x]["prig"] >= 0)
				if prig.is_empty():
					break
				var opz := []
				for id in prig:
					opz.append({"t": m.unita[id]["nome"], "id": id})
				var k := await m.scegli(f, "Chi liberi?", opz, {"chiave": "libera"})
				m.unita[prig[k]]["prig"] = -1
				m.scrivi("%s è stato liberato!" % m.unita[prig[k]]["nome"])
		"A":
			var b: int = g["bersaglio"]
			if m.vivo(b) and m.unita[b]["luogo"] == luogo:
				m.uccidi(b, "assassinato")
		"B":
			m.campi[luogo] = m.turno
			m.scrivi("Fondato un Campo ribelle in %s." % m.nome_luogo(luogo))
		"T":
			await _sovverti(n)
	controlla_campi()


func _info_annullata() -> bool:
	for id in m.pg_in(luogo, nemico, true):
		if m.unita[id]["poss"].has(48):
			return true
	return false


func _fallimento_assassinio(g: Dictionary) -> void:
	var d := m.dado()
	var pg := _pg_vivi(g)
	if d in [4, 5]:
		var c := m.custode_in(luogo, nemico)
		if c >= 0:
			m.scrivi("Assassinio fallito (dado %d): il gruppo è catturato." % d)
			for id in pg:
				m.cattura(id, c)
			return
	if d == 6:
		m.scrivi("Assassinio fallito (dado 6): il gruppo è ucciso.")
		for id in pg:
			m.uccidi(id, "assassinio fallito")
		return
	m.scrivi("Assassinio fallito (dado %d): il gruppo si dilegua." % d)


func _sabotaggio(n: int) -> void:
	var pid := m.pid_di(luogo)
	var p: Dictionary = m.pianeti[pid]
	var opz := []
	for id in m.mil_in(luogo, nemico):
		if n >= 2 or int(m.unita[id]["forza"]) == 1 and m.unita[id]["tipo"] in ["milizia", "rib"]:
			opz.append({"t": "Elimino %s" % m.descr_mil(id), "id": id})
	if m.controllo(pid) == nemico:
		opz.append({"t": "Metto fuori uso il BDP" if n < 2 else "Riduco di un livello il BDP e lo metto fuori uso", "bdp": true})
	if opz.is_empty():
		return
	var k := await m.scegli(f, "Sabotaggio riuscito: quale bersaglio?", opz, {"chiave": "sabotaggio"})
	if opz[k].has("bdp"):
		p["su"] = false
		if n >= 2 and p["bdp"] > 0:
			p["bdp"] -= 1
		m.scrivi("Il BDP di %s è sabotato." % Dati.pianeta(pid)["nome"])
	else:
		m.unita[opz[k]["id"]]["luogo"] = "morto"
		m.scrivi("Sabotaggio: eliminata %s." % m.descr_mil(opz[k]["id"]))


func _sovverti(n: int) -> void:
	var tipo := m.tipo_amb(luogo)
	var mil := m.mil_in(luogo, Motore.I)
	var milizie := mil.filter(func(x): return m.unita[x]["tipo"] == "milizia")
	var opz := []
	if n >= 2:
		if milizie.size() >= 2:
			opz.append({"t": "Due Milizie passano ai Ribelli (diventano un'unità 2-1)", "via": [milizie[0], milizie[1]], "forza": 2})
		for id in mil:
			if m.unita[id]["tipo"] in ["pattuglia", "linea"]:
				opz.append({"t": "%s passa ai Ribelli (diventa un'unità 2-1)" % m.descr_mil(id), "via": [id], "forza": 2})
	if not milizie.is_empty():
		opz.append({"t": "Una Milizia passa ai Ribelli (diventa un'unità 1-0)", "via": [milizie[0]], "forza": 1})
	if opz.is_empty():
		return
	var k := await m.scegli(f, "Sovvertire truppe: quali unità passano dalla tua parte?", opz, {"chiave": "sovverti"})
	for id in opz[k]["via"]:
		m.unita[id]["luogo"] = "morto"
	if m.mil_in(luogo, Motore.R).size() < m.taglia(luogo):
		var nid := m.nuova_mil(Motore.R, "rib", opz[k]["forza"], tipo, opz[k]["forza"] == 2)
		m.unita[nid]["luogo"] = luogo
	m.scrivi("Truppe imperiali passano ai Ribelli in %s." % m.nome_luogo(luogo))


func _pesca_possesso(g: Dictionary, no_navi: bool) -> void:
	var mazzo: Array = m.mazzo_poss
	var nr := -1
	for i in mazzo.size():
		var c: Dictionary = Dati.d()["poss"].get(int(mazzo[i]), {})
		if no_navi and c.get("tipo", "") == "astronave":
			continue
		nr = int(mazzo[i])
		mazzo.remove_at(i)
		break
	if nr < 0:
		return
	var c2: Dictionary = Dati.d()["poss"][nr]
	var pg := _pg_vivi(g)
	if pg.is_empty():
		mazzo.append(nr)
		return
	var opz := []
	for id in pg:
		opz.append({"t": m.unita[id]["nome"], "id": id})
	var k := await m.scegli(f, "Trovato: %s. A chi lo assegni?" % c2.get("nome_it", ""), opz, {"chiave": "assegna_possesso", "nr": nr})
	var u: Dictionary = m.unita[pg[k]]
	if c2.get("tipo", "") == "astronave":
		if u["nave"].is_empty():
			u["nave"] = m.nave_da_possesso(nr)
		else:
			var altri := pg.filter(func(x): return m.unita[x]["nave"].is_empty())
			if altri.is_empty():
				m.scrivi("Nessuno può pilotare un'altra astronave: torna nel mazzo.")
				mazzo.append(nr)
				return
			m.unita[altri[0]]["nave"] = m.nave_da_possesso(nr)
	else:
		u["poss"].append(nr)
	m.scrivi("%s ottiene: %s." % [u["nome"], c2.get("nome_it", "")])
	m.evento.emit("possesso", {"nr": nr, "id": pg[k]})


func _nave_del_proprietario(id: int) -> void:
	var nome: String = m.unita[id]["nome"]
	for nr in m.mazzo_poss.duplicate():
		var c: Dictionary = Dati.d()["poss"].get(int(nr), {})
		if c.get("proprietario", null) != null and str(c["proprietario"]) == nome:
			m.mazzo_poss.erase(nr)
			m.unita[id]["nave"] = m.nave_da_possesso(int(nr))
			m.scrivi("%s arriva con la sua astronave." % nome)


## Il Campo ribelle sparisce con Lealtà in Dissenso/Agitazione o con troppe truppe imperiali (missione B).
func controlla_campi() -> void:
	for l in m.campi.keys():
		var p: Dictionary = m.pianeti[m.pid_di(l)]
		var forza_imp := m.forza_mil(m.mil_in(l, Motore.I))
		if p["lealta"] >= 3 or p["stato"] != "imperiale" or forza_imp >= m.taglia(l) + 3:
			m.campi.erase(l)
			m.scrivi("Il Campo ribelle in %s si scioglie." % m.nome_luogo(l))
