class_name Galattico
extends RefCounted
## Regole del Galactic Game (Sezioni 29-38): stadio galattico (eventi, risorse e tasse, incarichi
## strategici), Segreti planetari, base segreta ribelle, Atrocità, segreti nemici e preparazione della
## campagna. Fuori dal Galactic Game le funzioni di controllo restituiscono valori neutri.

var m: Motore
var segreti := {}            # pid -> chiave del Segreto planetario
var svelati := {}            # pid -> true
var base := -1               # pianeta della base segreta ribelle
var base_svelata := false
var base_distrutta := false
var segreti_ribelli := 0     # segreti ribelli scoperti dall'Impero
var nominati: Array = []     # pianeti dichiarati «non base»
var mazzo_strategico: Array = []
var strategico: Dictionary = {}
var strategico_libero := false
var mazzo_eventi: Array = []
var evento_corrente: Dictionary = {}
var ipnosi := {}             # pid -> id dell'unità Atrocità posta sulla Lealtà
var spia_strategica := false
var _da_liberare := false


func _init(motore: Motore) -> void:
	m = motore


func attivo() -> bool:
	return m.livello == "galassia"


func status(pid: int) -> String:
	var v = Dati.pianeta(pid).get("status", null)
	return "" if v == null else str(v)


func capitale(pid: int) -> bool:
	return status(pid) in ["capital", "throne"]


func patria(pid: int) -> bool:
	return not status(pid) in ["", "capital", "throne", "secret"]


func capitale_di(prov: int) -> int:
	for p in Dati.d()["galassia"]["pianeti"]:
		if int(int(p["id"]) / 100) == prov and status(int(p["id"])) == "capital":
			return int(p["id"])
	return -1


func urbano(pid: int) -> String:
	var amb: Array = Dati.pianeta(pid)["ambienti"]
	for i in amb.size():
		if amb[i]["tipo"] == "urbano":
			return "%d:%d" % [pid, i]
	return "%d:0" % pid


# =====================================================================================
# FUNZIONI DI CONTROLLO USATE DALLE ALTRE REGOLE
# =====================================================================================

func segreto_attivo(pid: int, chiave: String) -> bool:
	return attivo() and str(segreti.get(pid, "")) == chiave


## Incarichi strategici (35.0): l'Impero può muovere da pid_da a pid_a?
func mossa_imperiale_ammessa(f: int, pid_da: int, pid_a: int, da: String) -> bool:
	if not attivo() or f == Motore.R:
		return true
	var prov_a := int(pid_a / 100)
	var prov_da := prov_a
	if pid_da >= 0:
		prov_da = int(pid_da / 100)
	elif da.begins_with("D") or da.begins_with("S:"):
		prov_da = int(int(da.get_slice(":", 1)) / 10)
	if pid_da == pid_a:
		return true
	if m.evento_attivo(121) and prov_da != prov_a:
		return false
	if strategico_libero or m.evento_attivo(102):
		return true
	# 35.31: dalle capitali e dal Trono verso pianeti in ribellione o ribelli
	if pid_da >= 0 and capitale(pid_da) and m.pianeti[pid_a]["stato"] in ["ribellione", "ribelle"]:
		return true
	var nominate: Array = [int(strategico.get("da", 0)), int(strategico.get("a", 0))]
	if nominate.has(prov_da):
		return nominate.has(prov_a)
	if prov_a != prov_da:
		return false
	return _sistema_importante(int(pid_a / 10))


func _sistema_importante(stella: int) -> bool:
	for p in Dati.d()["galassia"]["pianeti"]:
		if int(p["stella"]) == stella and (capitale(int(p["id"])) or patria(int(p["id"]))):
			return true
	return false


func extra_distanza(s_a: int, s_b: int) -> int:
	if not attivo() or not m.evento_attivo(105):
		return 0
	if (int(s_a / 10) == 1) != (int(s_b / 10) == 1):
		return 2
	return 0


func spostamento_vivo(pid: int, att: int) -> int:
	if not segreto_attivo(pid, "vivo"):
		return 0
	return 2 if att == Motore.R else -2


func navi_bloccate(u: Dictionary) -> bool:
	return attivo() and m.evento_attivo(125) and u["fz"] == Motore.I and not u["nave"].get("redjac", false)


func spostamento_deltronics(pid: int, f: int, nave: Dictionary) -> int:
	if f == Motore.R and segreto_attivo(pid, "deltronics") and int(nave.get("nr", 0)) != 40:
		return 2
	return 0


func domino_bloccato() -> bool:
	return attivo() and m.evento_attivo(121)


func lealta_bloccata(pid: int) -> bool:
	if ipnosi.has(pid):
		return true
	if m.evento_attivo(120):
		for a in Dati.pianeta(pid)["ambienti"]:
			for r in a.get("razze", []):
				if r["nome"] == "Kayns":
					return true
	return false


## Mareg in orbita svela il Segreto planetario (31.21).
func rivela_in_orbita(l: String) -> void:
	if not attivo() or not m.is_orbita(l):
		return
	var pid := m.pid_di(l)
	if segreti.has(pid) and not svelati.has(pid):
		for id in m.pg_in(l, Motore.R, true):
			if m.unita[id]["nome"] == "Professor Mareg":
				await svela(pid)
				return


func entrate_ribellione(pid: int, totale: int) -> void:
	var molt := 1
	match str(segreti.get(pid, "")):
		"gemme", "schiavi":
			molt = 3
		"industria", "benvenuti":
			molt = 2
		"impero":
			molt = 0
	if segreti.get(pid, "") in ["casino", "trappola", "impero"]:
		segreti.erase(pid)
	if base_distrutta:
		pass
	m.pf[Motore.R] = mini(199, int(m.pf[Motore.R]) + totale * molt)
	m.scrivi("I Ribelli ricevono %d Punti Forza sul tracciato delle risorse (ora %d)." % [totale * molt, m.pf[Motore.R]])


func punti_vittoria() -> Dictionary:
	var tot := 0
	var dett := []
	for pid in m.scenario_pianeti():
		if m.pianeti[pid]["stato"] != "ribelle":
			continue
		var v := 1
		if status(pid) == "throne" or (status(pid) == "capital" and int(pid / 100) == 1):
			v = 5
		elif status(pid) == "capital":
			v = 4
		elif patria(pid):
			v = 3
		tot += v
		dett.append("%s sotto controllo ribelle: +%d" % [Dati.pianeta(pid)["nome"], v])
	return {"totale": tot, "dettaglio": dett, "soglia": int(m.scenario["soglia_pv"])}


# =====================================================================================
# PREPARAZIONE DELLA CAMPAGNA (38.0)
# =====================================================================================

func prepara_galassia() -> void:
	m.fase = "schieramento"
	var RA: Dictionary = Dati.d()["regole_avanzate"]
	# 31.1 Segreti planetari
	var chiavi: Array = RA["segreti"].keys()
	chiavi.sort()
	m._mescola(chiavi)
	var pl: Array = RA["segreti_pianeti"]
	for i in pl.size():
		segreti[int(pl[i])] = chiavi[i]
	# 32 Eventi galattici
	for e in Dati.d()["carte"]["evento"]:
		mazzo_eventi.append(int(e["nr"]))
	m._mescola(mazzo_eventi)
	# 35.1 Incarichi strategici, ordinati dall'Impero
	var carte: Array = Dati.d()["carte"]["strategico"].duplicate()
	var k0 := await m.scegli(Motore.I, "Incarichi strategici: come ordini il mazzo?", [{"t": "In ordine casuale"}, {"t": "Scelgo io l'ordine, carta per carta"}], {"chiave": "ordine_strategico", "conferma": true})
	if k0 == 0:
		m._mescola(carte)
		mazzo_strategico = carte
	else:
		while carte.size() > 1:
			var opz := []
			for c in carte:
				opz.append({"t": c["it"], "da": int(c["da"]), "a": int(c["a"])})
			var k := await m.scegli(Motore.I, "Quale Incarico strategico peschi per %s?" % ("primo" if mazzo_strategico.is_empty() else "successivo"), opz, {"chiave": "strategico"})
			mazzo_strategico.append(carte[k])
			carte.remove_at(k)
		mazzo_strategico.append(carte[0])
	# 34.1 base segreta ribelle
	var opz_b := []
	for pid in RA["basi_possibili"]:
		opz_b.append({"t": "%s (%s)" % [Dati.pianeta(int(pid))["nome"], _nome_prov(int(pid / 100))], "pid": int(pid)})
	base = opz_b[await m.scegli(Motore.R, "Dove nascondi la base segreta ribelle? (l'Impero non lo sa)", opz_b, {"chiave": "base_segreta"})]["pid"]
	m.scrivi("I Ribelli hanno scelto in segreto la loro base.")
	# 38.2 truppe imperiali
	var k1 := await m.scegli(Motore.I, "Schieramento iniziale dell'Impero: 70 Punti Forza nella Prima Provincia, 35 in ciascuna delle altre.", [{"t": "Schieramento automatico (consigliato)"}, {"t": "Compro e schiero io, provincia per provincia"}], {"chiave": "schieramento_auto", "conferma": true})
	for prov in range(1, 6):
		await _schiera_provincia(prov, 70 if prov == 1 else 35, k1 == 0)
	# 38.3 personaggi imperiali
	await _schiera_pg_imperiali()
	# 38.4 personaggi ribelli
	await _schiera_ribelli()
	m.scrivi("Schieramento completato: la Ribellione stellare ha inizio.")
	m.cambiato.emit()


func _nome_prov(p: int) -> String:
	return ["", "Prima Provincia", "Seconda Provincia", "Terza Provincia", "Quarta Provincia", "Quinta Provincia"][clampi(p, 0, 5)]


func _pianeti_prov(prov: int) -> Array:
	return m.scenario_pianeti().filter(func(x): return int(x / 100) == prov)


func _schiera_provincia(prov: int, budget: int, auto: bool) -> void:
	var pp := _pianeti_prov(prov)
	# almeno un'unità per pianeta: una Milizia nell'ambiente urbano o nel primo ambiente
	for pid in pp:
		var id := m.nuova_unita(Motore.I, "milizia")
		m.unita[id]["luogo"] = urbano(pid)
		budget -= 1
	var max_bdp := int((budget + pp.size()) / 2)
	var elite := 2 if prov == 1 else 1
	if auto:
		_auto_provincia(prov, pp, budget, max_bdp, elite)
		return
	var luoghi := []
	for pid in pp:
		luoghi.append("%d:o" % pid)
		for i in Dati.pianeta(pid)["ambienti"].size():
			luoghi.append("%d:%d" % [pid, i])
	m.scrivi("%s: %d Punti Forza (al massimo %d per le BDP)." % [_nome_prov(prov), budget, max_bdp])
	await m.av.acquista(Motore.I, budget, luoghi, {"elite": elite, "suicida": 0, "no_atrocita": true, "max_bdp": max_bdp}, true, false, pp)


func _auto_provincia(prov: int, pp: Array, budget: int, max_bdp: int, elite: int) -> void:
	var spesa_bdp := 0
	var cap := capitale_di(prov)
	var importanti := pp.filter(func(x): return capitale(x))
	for pid in importanti:
		if spesa_bdp + 7 <= max_bdp and budget >= 7:
			m.pianeti[pid]["su"] = true
			m.pianeti[pid]["bdp"] = 2
			spesa_bdp += 7
			budget -= 7
	for pid in pp.filter(func(x): return not capitale(x) and (patria(x) or segreti.has(x))):
		if spesa_bdp + 4 <= max_bdp and budget >= 4:
			m.pianeti[pid]["su"] = true
			m.pianeti[pid]["bdp"] = 1
			spesa_bdp += 4
			budget -= 4
	for pid in pp:
		if not m.pianeti[pid]["su"] and spesa_bdp + 1 <= max_bdp and budget >= 1:
			m.pianeti[pid]["su"] = true
			spesa_bdp += 1
			budget -= 1
	# le truppe vanno prima dove la Lealtà è peggiore, poi sulle capitali e sui pianeti natali
	var a_rischio := pp.filter(func(x): return m.pianeti[x]["lealta"] >= 3)
	a_rischio.sort_custom(func(a, b): return m.pianeti[a]["lealta"] > m.pianeti[b]["lealta"])
	var dove := a_rischio + [cap] + pp.filter(func(x): return x != cap and not a_rischio.has(x) and (patria(x) or capitale(x)))
	for e in elite:
		var cat := "elite_flotta" if e == 0 else "elite_esercito"
		if budget >= 10:
			var id := m.nuova_unita(Motore.I, cat)
			m.unita[id]["luogo"] = "%d:o" % cap if cat == "elite_flotta" else urbano(cap)
			budget -= int(Dati.d()["regole_avanzate"]["unita"][cat]["costo"])
	var i := 0
	while budget >= 3:
		var cat2 := "veterano" if budget >= 7 and i % 3 == 0 else ("linea" if budget >= 5 else "pattuglia")
		var pid: int = dove[i % dove.size()]
		var id2 := m.nuova_unita(Motore.I, cat2)
		var l := "%d:o" % pid
		if i % 2 == 1 or a_rischio.has(pid):
			var u := urbano(pid)
			if m.mil_in(u, Motore.I).size() < m.taglia(u):
				l = u
		m.unita[id2]["luogo"] = l
		budget -= int(Dati.d()["regole_avanzate"]["unita"][cat2]["costo"])
		i += 1
	while budget >= 1:
		var pid2: int = pp[i % pp.size()]
		var l2 := urbano(pid2)
		i += 1
		if m.mil_in(l2, Motore.I).size() >= m.taglia(l2):
			if i > 60:
				break
			continue
		var id3 := m.nuova_unita(Motore.I, "milizia")
		m.unita[id3]["luogo"] = l2
		budget -= 1
	m.scrivi("%s: schieramento imperiale automatico completato." % _nome_prov(prov))


func _schiera_pg_imperiali() -> void:
	var fissi := {"Thysa Kymbo": urbano(162), "Emperor Coreguya": urbano(162), "Senator Dermond": urbano(152), "Jon Kidu": urbano(311), "Gelba": urbano(542)}
	for nome in fissi:
		var id := m.nuovo_pg(nome, Motore.I)
		m.unita[id]["luogo"] = fissi[nome]
	# Barca sulla pila con più forza spaziale della Prima Provincia
	var best := ""
	var bv := -1
	for pid in _pianeti_prov(1):
		for l in ["%d:o" % pid] + range(Dati.pianeta(pid)["ambienti"].size()).map(func(i): return "%d:%d" % [pid, i]):
			var v := m.av.spazio_mil(m.mil_in(l, Motore.I))
			if v > bv:
				bv = v
				best = l
	var b := m.nuovo_pg("Barca", Motore.I)
	m.unita[b]["luogo"] = best
	# quattro cavalieri con astronave in quattro province diverse (non la Prima)
	var usate := []
	for nome2 in ["Redjac", "Jin Voles", "Vans Ka-Tie-A", "Els Taroff"]:
		var id2 := m.nuovo_pg(nome2, Motore.I)
		m.unita[id2]["nave"] = m.nave_imperiale(nome2 == "Redjac")
		var opz := []
		for pid in m.scenario_pianeti():
			var prov := int(pid / 100)
			if prov == 1 or usate.has(prov) or not (patria(pid) or segreti.has(pid)):
				continue
			opz.append({"t": "%s (%s)" % [Dati.pianeta(pid)["nome"], _nome_prov(prov)], "luogo": "%d:o" % pid, "prov": prov})
		var k := await m.scegli(Motore.I, "Dove schieri %s con la sua astronave?" % nome2, opz, {"chiave": "schiera_pg"})
		usate.append(opz[k]["prov"])
		var amb := urbano(int(opz[k]["luogo"].get_slice(":", 0)))
		m.unita[id2]["luogo"] = amb
	m.cambiato.emit()


func _schiera_ribelli() -> void:
	var gruppi := [
		{"pg": ["Boccanegra"], "nave": 36, "altri": 2, "poss": 1},
		{"pg": ["Ly Mantok"], "nave": 33, "altri": 3, "poss": 0},
		{"pg": ["Kogus", "Zina Adora", "Rayner Derban"], "nave": 38, "altri": 0, "poss": 1},
		{"pg": ["Tourag"], "nave": 37, "altri": 3, "poss": 1},
	]
	var province := [2, 3, 4, 5]
	for g in gruppi:
		for nome in g["pg"]:
			m.mazzo_pg[Motore.R].erase(nome)
	for g in gruppi:
		var ids := []
		for nome in g["pg"]:
			ids.append(m.nuovo_pg(nome, Motore.R))
		for k in int(g["altri"]):
			if m.mazzo_pg[Motore.R].is_empty():
				break
			ids.append(m.nuovo_pg(m.mazzo_pg[Motore.R][0], Motore.R))
		m.mazzo_poss.erase(int(g["nave"]))
		var nave := m.nave_da_possesso(int(g["nave"]))
		var pil := m._pilota_per_nave(ids, nave)
		if pil < 0:
			pil = ids[0]
		m.unita[pil]["nave"] = nave
		for k2 in int(g["poss"]):
			for i in m.mazzo_poss.size():
				var nr: int = m.mazzo_poss[i]
				if Dati.d()["poss"].get(nr, {}).get("tipo", "") != "astronave":
					m.mazzo_poss.remove_at(i)
					var opz2 := []
					for id in ids:
						opz2.append({"t": m.unita[id]["nome"], "id": id})
					var kp := await m.scegli(Motore.R, "Possesso iniziale: %s. A chi lo dai?" % Dati.d()["poss"][nr]["nome_it"], opz2, {"chiave": "assegna_possesso", "nr": nr})
					m.unita[ids[kp]]["poss"].append(nr)
					break
		var opz_p := []
		for prov in province:
			opz_p.append({"t": _nome_prov(prov), "prov": prov})
		var nomi := ", ".join(ids.map(func(x): return m.unita[x]["nome"]))
		var kq := await m.scegli(Motore.R, "In quale provincia entra il gruppo di %s?" % nomi, opz_p, {"chiave": "provincia_gruppo"})
		var prov2: int = province[kq]
		province.remove_at(kq)
		var opz_l := []
		for pid in _pianeti_prov(prov2):
			if capitale(pid) or patria(pid) or segreti.has(pid):
				continue
			for i in Dati.pianeta(pid)["ambienti"].size():
				var l := "%d:%d" % [pid, i]
				opz_l.append({"t": m.nome_luogo(l), "luogo": l})
		var kl := await m.scegli(Motore.R, "In quale ambiente si nasconde il gruppo di %s?" % nomi, opz_l, {"chiave": "schiera_pg"})
		for id in ids:
			m.unita[id]["luogo"] = opz_l[kl]["luogo"]
		m.cambiato.emit()


# =====================================================================================
# STADIO GALATTICO (30.1)
# =====================================================================================

func stadio_galattico() -> void:
	m.fase = "stadio"
	m.eventi_attivi = []
	m.scrivi("— Stadio galattico del turno %d —" % m.turno)
	m.cambiato.emit()
	if _da_liberare:
		strategico_libero = true
	# A. Evento galattico
	if not mazzo_eventi.is_empty():
		var nr: int = mazzo_eventi.pop_front()
		for e in Dati.d()["carte"]["evento"]:
			if int(e["nr"]) == nr:
				evento_corrente = e
		m.eventi_attivi.append(nr)
		m.scrivi("Evento galattico: %s. %s" % [evento_corrente["titolo_it"], evento_corrente["it"]])
		m.evento.emit("evento_galattico", {"nr": nr})
		await m.attesa(1.2)
		await _applica_evento(nr)
		if m.esito != "":
			return
	# B. Risorse
	m.fase = "risorse"
	m.cambiato.emit()
	await _tasse()
	await _manutenzione()
	await _acquisti_imperiali()
	await _acquisti_ribelli()
	# C. Incarico strategico
	if not strategico_libero:
		if mazzo_strategico.is_empty():
			mazzo_strategico = Dati.d()["carte"]["strategico"].duplicate()
			m._mescola(mazzo_strategico)
			mazzo_strategico = mazzo_strategico.slice(0, 6)
		strategico = mazzo_strategico.pop_front()
		m.scrivi("Incarico strategico imperiale: %s." % strategico["it"])
		m.evento.emit("strategico", {"da": strategico["da"], "a": strategico["a"]})
	if base_svelata:
		_da_liberare = true
	m.cambiato.emit()


func provincia_tassata() -> int:
	var t: Array = Dati.d()["regole_avanzate"]["tasse"]
	return int(t[(m.turno - 1) % t.size()])


func _tasse() -> void:
	var prov := provincia_tassata()
	if prov == 0:
		return
	if m.controllo(152) != Motore.I and m.controllo(162) != Motore.I:
		m.scrivi("L'Impero non controlla né Diomas né Orlog: niente tasse.")
		return
	var cap := capitale_di(prov)
	var tassabili := []
	if cap >= 0 and m.controllo(cap) == Motore.I:
		for pid in _pianeti_prov(prov):
			if m.controllo(pid) == Motore.I and m.pianeti[pid]["stato"] == "imperiale":
				tassabili.append(pid)
	else:
		m.scrivi("La capitale della %s non è imperiale: la provincia non paga le tasse." % _nome_prov(prov))
	var entrate := 0
	if not tassabili.is_empty():
		var k := await m.scegli(Motore.I, "Tasse della %s (%d pianeti tassabili)." % [_nome_prov(prov), tassabili.size()], [{"t": "Tasso tutti al massimo (la Lealtà peggiora)"}, {"t": "Tasso tutti a metà (Lealtà invariata)"}, {"t": "Nessuna tassa (la Lealtà migliora)"}, {"t": "Decido pianeta per pianeta"}], {"chiave": "tasse_modo", "conferma": true})
		for pid in tassabili:
			var modo := k
			var ris := _risorse(pid)
			if k == 3:
				var opz := [{"t": "Tassa piena: %d PF" % ris}, {"t": "Mezza tassa: %d PF" % int(ris / 2)}, {"t": "Nessuna tassa"}]
				modo = await m.scegli(Motore.I, "%s (%s): quanto tassi?" % [Dati.pianeta(pid)["nome"], Dati.LEALTA_NOMI[m.pianeti[pid]["lealta"]]], opz, {"chiave": "tassa", "pid": pid})
			match modo:
				0:
					entrate += ris
					if segreto_attivo(pid, "impero") and svelati.has(pid):
						continue
					if m.pianeti[pid]["lealta"] == 4:
						m.scrivi("Tasse insopportabili su %s!" % Dati.pianeta(pid)["nome"])
						await m.avvia_ribellione(pid, {})
					else:
						m.sposta_lealta(pid, 1, Motore.R)
				1:
					entrate += int(ris / 2)
					if segreto_attivo(pid, "benvenuti") and svelati.has(pid):
						m.sposta_lealta(pid, 1, Motore.R)
				2:
					var inizio := Dati.LEALTA.find(str(Dati.pianeta(pid)["politica"]["S"]))
					if m.pianeti[pid]["lealta"] > inizio:
						m.sposta_lealta(pid, 1, Motore.I)
	for pid in segreti:
		if segreti[pid] in ["gemme", "schiavi", "industria"] and m.controllo(pid) == Motore.I and m.pianeti[pid]["stato"] == "imperiale":
			entrate += 3 if segreti[pid] == "industria" else 5
	m.pf[Motore.I] = clampi(int(m.pf[Motore.I]) + entrate, 0, 99)
	m.scrivi("L'Impero incassa %d Punti Forza (tracciato: %d)." % [entrate, m.pf[Motore.I]])


func _risorse(pid: int) -> int:
	var t := 0
	for a in Dati.pianeta(pid)["ambienti"]:
		t += int(a.get("risorse", 0))
	return t


## 33.4: un Punto Forza per ogni unità d'élite e per ogni BDP imperiale di livello 2.
func _manutenzione() -> void:
	var pagare := 0
	var bloccato := m.controllo(152) != Motore.I and m.controllo(162) != Motore.I
	for id in m.unita.keys():
		var u: Dictionary = m.unita[id]
		if u["k"] == "mil" and u["fz"] == Motore.I and m.vivo(id) and u.get("elite", false):
			if m.pf[Motore.I] > 0 and not bloccato:
				m.pf[Motore.I] -= 1
				pagare += 1
			else:
				var l: String = u["luogo"]
				u["luogo"] = "morto"
				var nuova := m.nuova_unita(Motore.I, "veterano")
				m.unita[nuova]["luogo"] = l
				m.scrivi("Niente manutenzione: un'unità d'élite diventa Veterana.")
	for pid in m.scenario_pianeti():
		if m.controllo(pid) == Motore.I and int(m.pianeti[pid]["bdp"]) == 2:
			if m.pf[Motore.I] > 0 and not bloccato:
				m.pf[Motore.I] -= 1
				pagare += 1
			else:
				m.pianeti[pid]["bdp"] = 1
				m.scrivi("Niente manutenzione: il BDP di %s scende al livello 1." % Dati.pianeta(pid)["nome"])
	if pagare > 0:
		m.scrivi("Manutenzione imperiale: %d Punti Forza." % pagare)


func _acquisti_imperiali() -> void:
	if m.pf[Motore.I] <= 0:
		return
	if m.controllo(152) != Motore.I and m.controllo(162) != Motore.I:
		return
	var prov := provincia_tassata()
	var luoghi := []
	var caps := [152, 162]
	var cap := capitale_di(prov)
	if cap > 0 and not caps.has(cap):
		caps.append(cap)
	for pid in caps:
		if m.controllo(pid) != Motore.I:
			continue
		luoghi.append("%d:o" % pid)
		for i in Dati.pianeta(pid)["ambienti"].size():
			luoghi.append("%d:%d" % [pid, i])
	var bdp := []
	for pid in m.scenario_pianeti():
		if m.controllo(pid) == Motore.I:
			bdp.append(pid)
	var lim := {"elite": 2, "suicida": 1, "atrocita": 1, "no_unita": m.evento_attivo(103), "no_bdp": m.evento_attivo(122), "liv_bdp_prov": [1, prov]}
	m.pf[Motore.I] = await m.av.acquista(Motore.I, int(m.pf[Motore.I]), luoghi, lim, false, false, bdp)


func _acquisti_ribelli() -> void:
	if m.pf[Motore.R] <= 0:
		return
	var luoghi := []
	if not base_distrutta and not m.distrutto(base):
		for i in Dati.pianeta(base)["ambienti"].size():
			luoghi.append("%d:%d" % [base, i])
		if m.mil_in("%d:o" % base, Motore.I).is_empty() and m.bdp_attiva(base, Motore.R) < 0:
			luoghi.append("%d:o" % base)
	var prima := 0
	for id in m.unita:
		if m.unita[id]["k"] == "mil" and m.unita[id]["fz"] == Motore.R:
			prima += 1
	var livelli_prima := {}
	for pid in m.scenario_pianeti():
		livelli_prima[pid] = int(m.pianeti[pid]["bdp"])
	m.pf[Motore.R] = await m.av.acquista(Motore.R, int(m.pf[Motore.R]), luoghi, {"elite_ribelli": true}, false, false, [])
	var dopo := 0
	for id in m.unita:
		if m.unita[id]["k"] == "mil" and m.unita[id]["fz"] == Motore.R:
			dopo += 1
	var alzato := false
	for pid in livelli_prima:
		if int(m.pianeti[pid]["bdp"]) > livelli_prima[pid]:
			alzato = true
	if (dopo > prima or alzato) and not base_svelata:
		svela_base()


func svela_base() -> void:
	if base_svelata:
		return
	base_svelata = true
	m.scrivi("La base segreta ribelle è su %s: l'Impero ora lo sa!" % Dati.pianeta(base)["nome"])
	m.evento.emit("base_svelata", {"pid": base})


# =====================================================================================
# EVENTI GALATTICI (32.0)
# =====================================================================================

func _applica_evento(nr: int) -> void:
	match nr:
		98:
			var opz := []
			for pid in m.scenario_pianeti():
				if m.controllo(pid) != Motore.I or not m.mil_in("%d:o" % pid, Motore.I).is_empty():
					continue
				for i in Dati.pianeta(pid)["ambienti"].size():
					var l := "%d:%d" % [pid, i]
					if m.mil_in(l, Motore.I).is_empty():
						opz.append({"t": "%s (%d risorse)" % [m.nome_luogo(l), int(Dati.ambiente(l).get("risorse", 0))], "luogo": l, "v": int(Dati.ambiente(l).get("risorse", 0))})
			if opz.is_empty():
				return
			opz.sort_custom(func(a, b): return a["v"] > b["v"])
			opz = opz.slice(0, 12)
			var k := await m.scegli(Motore.R, "I pirati spaziali saccheggiano un ambiente: quale?", opz, {"chiave": "pirati"})
			m.pf[Motore.R] = mini(199, int(m.pf[Motore.R]) + int(opz[k]["v"]))
		99:
			await _sposta_n(Motore.I, 3, _con_razza("Segundens"), Motore.R, "Times-Dispatch: quale pianeta dei Segunden si sposta verso i Ribelli?")
		104:
			await _sposta_n(Motore.R, 3, _pianeti_prov(1), Motore.I, "Giochi Galattici: quale pianeta della Prima Provincia si sposta verso l'Impero?")
		107:
			if m.pianeti.has(421) and m.pianeti[421]["lealta"] > 1 and m.pianeti[421]["stato"] == "imperiale":
				m.pianeti[421]["lealta"] = 1
				m.scrivi("Lonica torna Leale.")
		108:
			for pid in m.scenario_pianeti().filter(func(x): return int(x / 10) == 51):
				m.sposta_lealta(pid, 1, Motore.R)
		109:
			for pid in m.scenario_pianeti().filter(func(x): return int(x / 10) == 44):
				var p: Dictionary = m.pianeti[pid]
				if p["stato"] != "imperiale":
					continue
				if p["lealta"] == 0:
					p["lealta"] = 2
				elif p["lealta"] == 4:
					var k2 := await m.scegli(Motore.R, "%s è in Agitazione: la fai insorgere?" % Dati.pianeta(pid)["nome"], [{"t": "Sì, ribellione!"}, {"t": "No"}], {"chiave": "insorgi", "conferma": true})
					if k2 == 0:
						await m.avvia_ribellione(pid, {})
				else:
					m.sposta_lealta(pid, 1, Motore.R)
		112:
			await segreto_nemico(Motore.I)
		113:
			var tolti := mini(5, int(m.pf[Motore.I]))
			m.pf[Motore.I] -= tolti
			m.pf[Motore.R] = mini(199, int(m.pf[Motore.R]) + 5)
		117:
			for id in m.unita.keys():
				var u: Dictionary = m.unita[id]
				if u["k"] != "pg" or not m.vivo(id) or u["luogo"] == "" or not m.is_amb(u["luogo"]) or int(m.pid_di(u["luogo"]) / 100) != 3:
					continue
				var protetto := m.pg_in(u["luogo"], Motore.R, true).any(func(x): return m.unita[x]["nome"] == "Doctor Sontag" or m.unita[x]["poss"].has(46))
				if protetto and u["fz"] == Motore.R:
					continue
				u["ferite"] += 1
				if m.resistenza_residua(id) <= 0:
					m.uccidi(id, "la pestilenza")
		119:
			await _cloni()
		123:
			for id in m.unita:
				if m.unita[id].get("suicida", false) and m.vivo(id):
					m.unita[id]["luogo"] = "morto"
					m.scrivi("Una Squadra suicida è sciolta.")
					break
		124:
			var patria_s := m.pid_per_status("Suvans")
			var k3 := await m.scegli(Motore.R, "Il capo religioso suvan: cosa scegli?", [{"t": "Sposta Mrane, patria dei Suvan"}, {"t": "Sposta due altri pianeti dei Suvan"}], {"chiave": "suvan", "conferma": true})
			if k3 == 0 and patria_s > 0:
				m.sposta_lealta(patria_s, 1, Motore.R)
			else:
				await _sposta_n(Motore.R, 2, _con_razza("Suvans").filter(func(x): return x != patria_s), Motore.R, "Quale pianeta dei Suvan si sposta verso i Ribelli?")
		106:
			var orbite := []
			for pid in _pianeti_prov(5):
				var mm := m.mil_in("%d:o" % pid, Motore.I)
				if not mm.is_empty():
					orbite.append({"t": "Orbita di %s (%d forza spaziale)" % [Dati.pianeta(pid)["nome"], m.av.spazio_mil(mm)], "luogo": "%d:o" % pid})
			if orbite.is_empty():
				return
			var k4 := await m.scegli(Motore.R, "La flotta fantasma attacca: quale orbita?", orbite, {"chiave": "flotta_fantasma"})
			var mm2 := m.mil_in(orbite[k4]["luogo"], Motore.I)
			var col := m.av._colonna_rapporto(20, m.av.spazio_mil(mm2))
			var d := m.dado()
			var perd: int = Dati.d()["tabelle"]["combattimento_militare"]["righe_dado"][d - 1][col][1]
			m.scrivi("La flotta fantasma colpisce (dado %d): %d punti di perdite." % [d, perd])
			m.av.applica_perdite_spazio(mm2, perd)
		_:
			if not nr in [100, 101, 102, 103, 105, 110, 111, 114, 115, 116, 118, 120, 121, 122, 125, 126]:
				return
			if nr in [101, 111, 114, 118]:
				m.scrivi("(Effetto descritto sulla carta: nella versione digitale non ha conseguenze sul gioco.)")


func _con_razza(razza: String) -> Array:
	return m.scenario_pianeti().filter(func(pid): return Dati.pianeta(pid)["ambienti"].any(func(a): return a.get("razze", []).any(func(r): return r["nome"] == razza)))


func _sposta_n(chi: int, n: int, cand: Array, verso: int, testo: String) -> void:
	var lista := cand.filter(func(x): return m.pianeti[x]["stato"] in ["imperiale", "fermata"])
	for i in n:
		lista = lista.filter(func(x): return m.pianeti[x]["lealta"] != (4 if verso == Motore.R else 0))
		if lista.is_empty():
			return
		var opz := []
		for pid in lista:
			opz.append({"t": "%s (%s)" % [Dati.pianeta(pid)["nome"], Dati.LEALTA_NOMI[m.pianeti[pid]["lealta"]]], "pid": pid})
		var k := await m.scegli(chi, testo, opz, {"chiave": "sposta_evento", "verso": verso})
		m.sposta_lealta(lista[k], 1, verso)
		lista.remove_at(k)


func _cloni() -> void:
	var morti := []
	for id in m.unita:
		if m.unita[id]["k"] == "pg" and m.unita[id]["luogo"] == "morto" and not m.unita[id].get("sovrano", false):
			morti.append(id)
	m._mescola(morti)
	for id in morti.slice(0, 3):
		var u: Dictionary = m.unita[id]
		var dove := []
		for pid in m.scenario_pianeti():
			if m.controllo(pid) == u["fz"] or (u["fz"] == Motore.R and m.pianeti[pid]["stato"] == "ribellione"):
				dove.append(urbano(pid))
		if dove.is_empty():
			continue
		var opz := []
		for l in dove:
			opz.append({"t": m.nome_luogo(l), "luogo": l})
		var k := await m.scegli(u["fz"], "Il clone di %s: dove ricompare?" % u["nome"], opz, {"chiave": "schiera_pg"})
		u["luogo"] = dove[k]
		u["ferite"] = 0
		u["prig"] = -1
		m.scrivi("%s ritorna, clonato!" % u["nome"])


# =====================================================================================
# SEGRETI PLANETARI (31.0)
# =====================================================================================

func rivela_segreti() -> void:
	for pid in segreti.keys():
		if svelati.has(pid) or m.distrutto(pid):
			continue
		for i in Dati.pianeta(pid)["ambienti"].size():
			if not m.pg_in("%d:%d" % [pid, i], Motore.R, true).is_empty():
				await svela(pid)
				break


func svela(pid: int) -> void:
	if svelati.has(pid) or not segreti.has(pid):
		return
	svelati[pid] = true
	var k: String = segreti[pid]
	var d: Dictionary = Dati.d()["regole_avanzate"]["segreti"][k]
	m.scrivi("Segreto planetario di %s: %s. %s" % [Dati.pianeta(pid)["nome"], d["nome"], d["it"]])
	m.evento.emit("segreto", {"pid": pid, "chiave": k})
	await m.attesa(1.0)
	match k:
		"morto":
			await distruggi_pianeta(pid)
		"impero":
			if m.pianeti[pid]["stato"] == "imperiale":
				m.pianeti[pid]["lealta"] = 0
		"benvenuti":
			if m.pianeti[pid]["stato"] == "imperiale":
				m.pianeti[pid]["lealta"] = 3
		"trappola":
			for i in Dati.pianeta(pid)["ambienti"].size():
				var l := "%d:%d" % [pid, i]
				for id in m.pg_in(l, Motore.R, true):
					if m.unita[id]["ind"]:
						var c := m.custode_in(l, Motore.I)
						if c >= 0:
							m.cattura(id, c)
	m.cambiato.emit()


func distruggi_pianeta(pid: int) -> void:
	m.scrivi("%s non esiste più." % Dati.pianeta(pid)["nome"])
	m.evento.emit("distrutto", {"pid": pid})
	for id in m.unita.keys():
		var u: Dictionary = m.unita[id]
		var l: String = u["luogo"]
		if l != "" and l != "morto" and (m.is_amb(l) or m.is_orbita(l)) and m.pid_di(l) == pid:
			if u["k"] == "pg":
				m.uccidi(id, "il pianeta è stato distrutto")
			else:
				u["luogo"] = "morto"
	if pid == base:
		base_distrutta = true
		m.pf[Motore.R] = 0
	m.pianeti[pid]["distrutto"] = true
	m.pianeti[pid]["stato"] = "distrutto"
	m.azzera_cache()
	await m.av.domino(pid, "controllo", Motore.R)


# =====================================================================================
# ATROCITÀ (36.0)
# =====================================================================================

func atrocita(pid_evento: int) -> void:
	if not attivo():
		return
	var pianeti_ok := [pid_evento]
	if m.evento_attivo(100):
		pianeti_ok = m.scenario_pianeti()
	elif base_svelata and not pianeti_ok.has(base):
		pianeti_ok.append(base)
	var opz := [{"t": "Nessuna atrocità"}]
	for pid in pianeti_ok:
		if m.distrutto(pid):
			continue
		var nome: String = Dati.pianeta(pid)["nome"]
		if m.controllo(pid) == Motore.I and int(m.pianeti[pid]["bdp"]) == 2 and m.pianeti[pid]["su"]:
			opz.append({"t": "Il BDP mitraglia %s (tutte le truppe distrutte, una ferita a tutti)" % nome, "tipo": "bdp", "pid": pid})
		for id in m.mil_in("%d:o" % pid, Motore.I):
			var u: Dictionary = m.unita[id]
			if not u.get("atrocita", false) or ipnosi.values().has(id):
				continue
			opz.append({"t": "%s: armi chimiche su %s" % [u_nome(id), nome], "tipo": "chimica", "pid": pid, "id": id})
			opz.append({"t": "%s: ipnosi di massa su %s (Lealtà bloccata)" % [u_nome(id), nome], "tipo": "ipnosi", "pid": pid, "id": id})
			if u["cat"] == "stabilizzatore":
				opz.append({"t": "Planet Stabilizer: distrugge %s" % nome, "tipo": "distruggi", "pid": pid, "id": id})
	if opz.size() == 1:
		return
	var k := await m.scegli(Motore.I, "L'Impero può commettere un'Atrocità.", opz, {"chiave": "atrocita", "conferma": true})
	if k == 0:
		return
	var o: Dictionary = opz[k]
	var pid2: int = o["pid"]
	m.evento.emit("atrocita", {"pid": pid2})
	match o["tipo"]:
		"bdp":
			for id in m.unita.keys():
				var u2: Dictionary = m.unita[id]
				if not m.vivo(id) or not m.is_amb(str(u2["luogo"])) or m.pid_di(u2["luogo"]) != pid2:
					continue
				if u2["k"] == "mil":
					u2["luogo"] = "morto"
				else:
					u2["ferite"] += 1
					if m.resistenza_residua(id) <= 0:
						m.uccidi(id, "atrocità")
			m.pianeti[pid2]["bdp"] = 1
			m.pianeti[pid2]["su"] = false
			await _contraccolpo(pid2)
		"chimica":
			for id in m.unita.keys():
				var u3: Dictionary = m.unita[id]
				if not m.vivo(id) or not m.is_amb(str(u3["luogo"])) or m.pid_di(u3["luogo"]) != pid2:
					continue
				if u3["k"] == "mil" and u3["fz"] == Motore.R and u3["amb"] in Dati.SPECIALI:
					u3["luogo"] = "morto"
				elif u3["k"] == "pg" and u3["c"].get("razza_en", "") != "Rhone":
					u3["ferite"] += 2
					if m.resistenza_residua(id) <= 0:
						m.uccidi(id, "armi chimiche")
			await _contraccolpo(pid2)
		"ipnosi":
			ipnosi[pid2] = o["id"]
			m.scrivi("Ipnosi di massa: la Lealtà di %s è bloccata." % Dati.pianeta(pid2)["nome"])
		"distruggi":
			await distruggi_pianeta(pid2)
	m.scrivi("Atrocità imperiale su %s!" % Dati.pianeta(pid2)["nome"] if not m.distrutto(pid2) else "Atrocità imperiale.")
	m.cambiato.emit()


func u_nome(id: int) -> String:
	return str(Dati.d()["regole_avanzate"]["unita"][m.unita[id]["cat"]]["nome"])


func _contraccolpo(pid: int) -> void:
	if m.pianeti[pid]["stato"] != "imperiale" and m.pianeti[pid]["stato"] != "fermata":
		return
	if m.pianeti[pid]["lealta"] >= 3:
		m.pianeti[pid]["lealta"] = 4
		await m.avvia_ribellione(pid, {})
	else:
		m.sposta_lealta(pid, 2, Motore.R)
		await m.av.domino(pid, "lealta", Motore.R)


## Un'unità Atrocità ipnotizzante che lascia l'orbita (o è distrutta) libera la Lealtà con il contraccolpo.
func controlla_ipnosi() -> void:
	for pid in ipnosi.keys():
		var id: int = ipnosi[pid]
		if not m.vivo(id) or m.unita[id]["luogo"] != "%d:o" % pid:
			ipnosi.erase(pid)
			await _contraccolpo(pid)


# =====================================================================================
# SEGRETI NEMICI (37.4)
# =====================================================================================

## f è chi scopre il segreto.
func segreto_nemico(f: int) -> void:
	if f == Motore.I:
		if base_svelata:
			return
		segreti_ribelli += 1
		if segreti_ribelli >= 9:
			svela_base()
			return
		var cand: Array = Dati.d()["regole_avanzate"]["basi_possibili"].filter(func(x): return int(x) != base and not nominati.has(int(x)))
		for i in 2:
			if cand.is_empty():
				break
			var opz := []
			for pid in cand:
				opz.append({"t": Dati.pianeta(int(pid))["nome"], "pid": int(pid)})
			var k := await m.scegli(Motore.R, "L'Impero ha scoperto un segreto: indica un pianeta che NON ospita la base.", opz, {"chiave": "non_base"})
			nominati.append(int(cand[k]))
			cand.remove_at(k)
		m.scrivi("Segreto ribelle scoperto (%d su 9): la base non è su %s." % [segreti_ribelli, ", ".join(nominati.slice(-2).map(func(x): return Dati.pianeta(x)["nome"]))])
	else:
		var opz2 := [{"t": "Svela due Segreti planetari"}, {"t": "Guarda il prossimo Incarico strategico"}]
		var k2 := await m.scegli(Motore.R, "Hai scoperto un segreto imperiale: cosa vuoi sapere?", opz2, {"chiave": "segreto_imperiale"})
		if k2 == 1:
			if not mazzo_strategico.is_empty():
				m.scrivi("Il prossimo Incarico strategico imperiale sarà: %s." % mazzo_strategico[0]["it"])
			return
		for i in 2:
			var cand2 := segreti.keys().filter(func(x): return not svelati.has(x) and not m.distrutto(x))
			if cand2.is_empty():
				return
			var opz3 := []
			for pid in cand2:
				opz3.append({"t": Dati.pianeta(pid)["nome"], "pid": pid})
			var k3 := await m.scegli(Motore.R, "Quale Segreto planetario vuoi svelare?", opz3, {"chiave": "svela_segreto"})
			await svela(cand2[k3])
