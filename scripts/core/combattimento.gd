class_name Combattimento
extends RefCounted
## Combattimento fra personaggi (Sezione 12.0): personaggi, squadre, creature e locali infuriati
## contro un gruppo di personaggi che difende. Round dopo round con la Tabella dei risultati (12.9).

var m: Motore
var tab: Dictionary


func _init(motore: Motore) -> void:
	m = motore
	tab = Dati.d()["tabelle"]["combattimento_personaggi"]


## Forza attaccante: {nome, forza, res, fuoco, fz (−1 = nessun giocatore), pg: [id], cattura, creatura: {}}
func risolvi(att: Dictionary, difensori: Array, luogo: String) -> Dictionary:
	var fd: int = m.unita[difensori[0]]["fz"]
	var cre: Dictionary = att.get("creatura", {})
	var cod: String = str(cre.get("cod", ""))
	var esito := {"vinto_difensori": false, "superstiti": [], "rotto": false}
	var ferite_att := 0
	var forza_base: int = att.get("forza", 0)
	var res_att: int = att.get("res", 99)
	var round_n := 0
	var dif := difensori.filter(func(x): return m.vivo(x) and m.unita[x]["prig"] < 0)
	var sganciati := []
	var cattura: bool = att.get("cattura", false)
	var fuoco: bool = att.get("fuoco", false)
	var lama_usata := {}
	var forza_iniz := forza_base
	for id in att.get("pg", []):
		forza_iniz += m.combattimento_pg(id)
	m.scrivi("Combattimento in %s: %s (forza %d%s) contro %s." % [m.nome_luogo(luogo), att["nome"], forza_iniz, ", per catturare" if cattura else "", ", ".join(dif.map(func(x): return m.unita[x]["nome"]))])
	m.evento.emit("mischia", {"luogo": luogo, "att": att["nome"], "dif": dif.duplicate()})
	while true:
		round_n += 1
		dif = dif.filter(func(x): return m.vivo(x) and m.unita[x]["prig"] < 0 and not sganciati.has(x))
		var att_pg: Array = att.get("pg", []).filter(func(x): return m.vivo(x))
		if dif.is_empty():
			break
		if att.has("pg") and att_pg.is_empty():
			esito["vinto_difensori"] = true
			break
		if not att.has("pg") and ferite_att >= res_att:
			esito["vinto_difensori"] = true
			m.scrivi("%s è sconfitto." % att["nome"])
			break
		if round_n > 1 and cod in ["UN_ROUND"]:
			break
		if cod == "LADRI" and round_n > 3:
			_ladri(dif)
			break
		if cod == "ROTRON" and round_n > 2:
			break
		# forza attuale dell'attaccante
		var forza := 0
		if att.has("pg"):
			for id in att_pg:
				forza += m.combattimento_pg(id)
		else:
			forza = _forza_creatura(cod, forza_base, ferite_att, round_n, att)
		# difensori attivi e inattivi (12.4)
		var attivi := dif.duplicate()
		if dif.size() > 1 and not cod in ["NON_REAGISCE", "VIRUS"]:
			var opz := []
			for id in dif:
				opz.append({"t": "%s (combattimento %d, resistenza %d)" % [m.unita[id]["nome"], m.combattimento_pg(id), m.resistenza_residua(id)], "id": id})
			var sel := await m.scegli_multi(fd, "Round %d contro %s (forza %d): chi combatte attivamente?" % [round_n, att["nome"], forza], opz, {"chiave": "attivi", "min": 1, "forza": forza})
			if not sel.is_empty():
				attivi = []
				for i in sel:
					attivi.append(dif[i])
		var inattivi := dif.filter(func(x): return not attivi.has(x))
		var difesa := 0
		for id in attivi:
			difesa += _difesa_pg(id, cod, round_n, lama_usata)
		if cod in ["INTELLIGENZA", "VOROZION", "TELEBOT"]:
			difesa = 0
			for id in attivi:
				difesa += m.val(id, "intelligenza")
		if cod in ["NON_REAGISCE", "VOROZION"]:
			difesa = 0
		var diff := forza - difesa
		var col := _colonna(diff)
		if cattura:
			col -= 2
		var no_sgancio: bool = cre.get("nb", "") == "sempre" or (cre.get("nb", "") == "primo" and round_n == 1)
		var sorpresa := int(cre.get("sp", 0)) if round_n == 1 else 0
		for id in attivi:
			if Dati.d()["possessi_effetti"].get("51", {}).get("no_sorpresa", false) and m.unita[id]["poss"].has(51):
				sorpresa = 0
		# sganciamento (12.5)
		if not no_sgancio:
			var k := await m.scegli(fd, "Round %d: forza %d contro difesa %d. Tenti di sganciarti?" % [round_n, forza, difesa], [{"t": "Combatto"}, {"t": "Tento lo sganciamento"}], {"chiave": "sganciamento", "diff": diff, "conferma": true})
			if k == 1:
				var cb := clampi(col, 0, 9)
				var mod := int(cre.get("ms", 0)) + (int(cre.get("ms_primo", 0)) if round_n == 1 else 0) + (int(cre.get("ms_dopo", 0)) if round_n > 1 else 0)
				var d := m.dado() - mod
				var ok_att: bool = d <= int(tab["sganciamento_attivi"][cb])
				var ok_inatt: bool = d <= int(tab["sganciamento_inattivi"][cb])
				if ok_inatt and not inattivi.is_empty():
					sganciati.append_array(inattivi)
					m.scrivi("Gli inattivi si sganciano.")
				if ok_att:
					sganciati.append_array(attivi)
					m.scrivi("Sganciamento riuscito (dado %d)." % (d + mod))
					esito["rotto"] = true
					continue
				m.scrivi("Sganciamento fallito (dado %d)." % (d + mod))
				col += 1
		col = clampi(col + sorpresa, 0, 9)
		# tiri: l'attaccante tira per le ferite del difensore, il difensore per quelle dell'attaccante
		var da := m.dado()
		var dd := m.dado()
		var cella_a: Array = tab["righe_dado"][da - 1][col]
		var cella_d: Array = tab["righe_dado"][dd - 1][col]
		var fer_dif: int = cella_a[2]
		var fer_att: int = cella_d[0]
		var catt: bool = cattura and (cella_a[3] or cella_d[1])
		if cod == "DOPPIO_TIRO":
			var da2 := m.dado()
			fer_dif += int(tab["righe_dado"][da2 - 1][col][2])
		if fuoco:
			fer_dif *= 2
			fer_att *= 2
		if cod in ["NON_REAGISCE", "VOROZION", "ELILAD"]:
			fer_att = 0
		if cod == "GELO":
			fer_dif = attivi.size() + inattivi.size()
		# scudo corporeo (47)
		for id in attivi:
			if m.unita[id]["poss"].has(47):
				fer_dif = maxi(0, fer_dif - (2 if fuoco else 1))
				break
		m.scrivi("Round %d (colonna %s): dadi %d/%d » %d ferite ai difensori, %d all'attaccante%s." % [round_n, tab["colonne"][col], da, dd, fer_dif, fer_att, ", CATTURA" if catt else ""])
		m.evento.emit("round", {"luogo": luogo, "dadi": [da, dd], "ferite": [fer_att, fer_dif]})
		await m.attesa(0.7)
		# ferite all'attaccante
		if att.has("pg"):
			_distribuisci(att_pg, fer_att)
		else:
			ferite_att += fer_att
		# ferite ai difensori
		var bersagli := attivi if cod != "GELO" else attivi + inattivi
		if cod == "MAGRON":
			bersagli = [att["afferrato"]] if m.vivo(att.get("afferrato", -1)) else attivi
		_distribuisci(bersagli, fer_dif)
		if catt and att.get("fz", -1) >= 0:
			var vivi := attivi.filter(func(x): return m.vivo(x) and m.unita[x]["prig"] < 0)
			if not vivi.is_empty():
				var preso: int = vivi[m.rng.randi_range(0, vivi.size() - 1)]
				var custode := m.custode_in(luogo, att["fz"])
				if custode >= 0:
					m.cattura(preso, custode)
		if cod == "VOROZION" and fer_dif == 0:
			m.scrivi("Il Vorozion si annoia e se ne va.")
			break
		if cod == "GACH":
			ferite_att += int(tab["righe_dado"][m.dado() - 1][5][0])
		if cod == "SYNESTINS" and ferite_att >= res_att and fd == Motore.R:
			m.sposta_lealta(m.pid_di(luogo), 1, Motore.R)
		m.cambiato.emit()
		if round_n > 30:
			break
	if cod == "ROTRON" and ferite_att < res_att:
		for id in difensori:
			if m.vivo(id) and not m.unita[id]["nave"].is_empty():
				m.unita[id]["nave"]["dmg"] = true
				m.scrivi("Il Rotron danneggia %s." % m.unita[id]["nave"]["nome"])
				break
	esito["superstiti"] = difensori.filter(func(x): return m.vivo(x) and m.unita[x]["prig"] < 0)
	esito["att_vivo"] = ferite_att < res_att
	m._controlla_navi_orfane()
	m.cambiato.emit()
	return esito


func _forza_creatura(cod: String, base: int, ferite: int, round_n: int, att: Dictionary) -> int:
	match cod:
		"CRESCE_1":
			return base + (round_n - 1) - ferite
		"PRIME_DUE_NO_FORZA":
			return base - maxi(0, ferite - 2)
		"QUEEMER":
			return base + ferite
		"THUNK":
			return base + (round_n - 1)
		"BRANCO":
			var extra := 0
			for r in range(3, round_n + 1, 2):
				extra += 2
			return base + extra - ferite
		"SANGUE":
			return base + mini(att.get("sangue", 0), 2) - ferite
		"UN_ROUND", "NON_REAGISCE", "VOROZION", "GELO", "INTELLIGENZA", "TELEBOT":
			return base
		"WYTHS":
			return maxi(0, base - att.get("meno_int", 0) - ferite)
	return maxi(0, base - ferite)


func _difesa_pg(id: int, cod: String, round_n: int, lama: Dictionary) -> int:
	var v := m.combattimento_pg(id)
	var u: Dictionary = m.unita[id]
	if u["poss"].has(50):
		v += 2
	if u["poss"].has(42) and not lama.has(id):
		lama[id] = true
		v += 3
		u["poss"].erase(42)
		m.scrivi("%s usa la Lama dell'assassino." % u["nome"])
	return v


func _colonna(diff: int) -> int:
	var lim: Array = tab["limiti_superiori"]
	for i in lim.size():
		if diff <= int(lim[i]):
			return i
	return lim.size() - 1


## Distribuisce le ferite cercando di non uccidere nessuno: prima a chi ha più resistenza residua.
func _distribuisci(ids: Array, n: int) -> void:
	var vivi := ids.filter(func(x): return m.vivo(x))
	while n > 0 and not vivi.is_empty():
		vivi.sort_custom(func(a, b): return m.resistenza_residua(a) > m.resistenza_residua(b))
		var id: int = vivi[0]
		m.unita[id]["ferite"] += 1
		n -= 1
		if m.resistenza_residua(id) <= 0:
			m.uccidi(id, "ferite in combattimento")
			vivi.erase(id)


func _ladri(dif: Array) -> void:
	for id in dif:
		var u: Dictionary = m.unita[id]
		var cand: Array = u["poss"].filter(func(nr): return Dati.d()["poss"].get(int(nr), {}).get("tipo", "") != "astronave")
		if not cand.is_empty():
			var nr: int = cand[m.rng.randi_range(0, cand.size() - 1)]
			u["poss"].erase(nr)
			m.mazzo_poss.append(nr)
			m.scrivi("I ladri rubano a %s un possesso." % u["nome"])
			return


# --------------------------------------------------------------------------------------
# Forme d'attacco
# --------------------------------------------------------------------------------------

## Squadra generata da truppe che hanno trovato dei personaggi (12.12, 12.16).
func squadra_contro(f: int, truppe: Array, bersagli: Array, luogo: String, cattura := false, capo := false) -> Dictionary:
	var forza := m.forza_mil(truppe)
	var riga: Dictionary = {}
	for r in Dati.d()["tabelle"]["squadra"]:
		if forza >= int(r["da"]) and forza <= int(r["a"]):
			riga = r
	if riga.is_empty():
		riga = Dati.d()["tabelle"]["squadra"][-1]
	var res := int(riga["res"]) + (2 if capo else 0)
	return await risolvi({"nome": "una squadra %s" % ("imperiale" if f == Motore.I else "ribelle"), "forza": int(riga["comb"]), "res": res, "fuoco": true, "fz": f, "cattura": cattura}, bersagli, luogo)


func personaggi_contro(f: int, attaccanti: Array, bersagli: Array, luogo: String, cattura := false) -> Dictionary:
	var fuoco := true
	var k := await m.scegli(f, "Che tipo di combattimento?", [{"t": "Scontro a fuoco (risultati raddoppiati)"}, {"t": "Corpo a corpo"}], {"chiave": "tipo_mischia", "conferma": true})
	fuoco = k == 0
	for id in attaccanti:
		m.unita[id]["attivo_turno"] = true
	return await risolvi({"nome": ", ".join(attaccanti.map(func(x): return m.unita[x]["nome"])), "pg": attaccanti, "fuoco": fuoco, "fz": f, "cattura": cattura, "res": 99}, bersagli, luogo)


func locali_contro(gruppo: Array, luogo: String) -> Dictionary:
	var amb := Dati.ambiente(luogo)
	var razze: Array = amb.get("razze", [])
	if razze.is_empty():
		return {}
	var razza: String = razze[0]["nome"]
	var L: Dictionary = Dati.d()["tabelle"]["locali_infuriati"]
	var s := {}
	if L["stellari"].has(razza):
		s = L["stellari"][razza].get(amb["tipo"], {})
	elif L["altri"].has(razza):
		s = L["altri"][razza]
	if s.is_empty():
		m.scrivi("I locali (%s) protestano ma non attaccano." % razza)
		return {}
	var forza := int(s["comb"])
	for id in gruppo:
		if m.unita[id]["poss"].has(45):
			forza = int(forza / 2)
	return await risolvi({"nome": "locali infuriati (%s)" % razza, "forza": forza, "res": int(s["res"]), "fuoco": not s.get("corpo_a_corpo", false), "fz": -1}, gruppo, luogo)


func creatura_contro(nome: String, gruppo: Array, luogo: String, n_robot := 1) -> Dictionary:
	var C: Dictionary = Dati.d()["creature"]
	var cre: Dictionary = C.get(nome, {})
	if cre.is_empty():
		m.scrivi("La creatura %s non compare." % nome)
		return {}
	cre = cre.duplicate()
	var cod: String = str(cre.get("cod", ""))
	if nome == "Sentry Robot" and n_robot >= 2:
		cre["s"] = 7
		cre["r"] = 4
	m.scrivi("Attacca: %s. %s" % [nome, cre.get("it", "")])
	m.evento.emit("creatura", {"nome": nome, "luogo": luogo})
	match cod:
		"MENO_UN_BONUS":
			return {"meno_bonus": 1}
		"NO_BONUS", "IPNOSI_SUBITO":
			return {"no_bonus": true}
		"NEBBIA":
			var max_int := 0
			for id in gruppo:
				max_int = maxi(max_int, m.val(id, "intelligenza"))
			return {"no_bonus": max_int < 3}
		"CRUNGE":
			var best := 0
			for id in gruppo:
				best = maxi(best, m.val(id, "intelligenza"))
			var f := maxi(0, 4 - best)
			for id in gruppo:
				_distribuisci([id], f)
			return {}
		"DRANTS":
			for id in gruppo:
				var d := m.dado()
				_distribuisci([id], int(tab["righe_dado"][d - 1][4][2]))
			return {}
		"MORNA":
			for id in gruppo:
				if m.val(id, "diplomazia") >= 3:
					m.scrivi("Il capoclan si fida del gruppo.")
					return {}
		"ZOP":
			if m.unita[gruppo[0]]["fz"] == Motore.R and not m.zop_usato:
				m.zop_usato = true
				return {"zop": true}
			return {}
		"ELILAD":
			for id in gruppo:
				var giri := 0
				while m.vivo(id) and giri < 10:
					giri += 1
					var d := m.dado()
					_distribuisci([id], int(tab["righe_dado"][d - 1][4][2]))
					if m.dado() <= int(tab["sganciamento_attivi"][4]):
						break
			return {}
		"TELEBOT":
			if gruppo.any(func(x): return m.unita[x]["poss"].has(51)):
				return {}
			var scelto: int = gruppo[0]
			return await risolvi({"nome": nome, "forza": int(cre["s"]), "res": int(cre["r"]), "fuoco": false, "fz": -1, "creatura": cre}, [scelto], luogo)
		"INTELLIGENZA", "VOROZION":
			if gruppo.any(func(x): return m.unita[x]["poss"].has(51)):
				return {}
		"MAGRON":
			var preso: int = gruppo[m.rng.randi_range(0, gruppo.size() - 1)]
			if gruppo.size() == 1:
				m.uccidi(preso, "divorato dal Magron")
				return {}
			var altri := gruppo.filter(func(x): return x != preso)
			return await risolvi({"nome": nome, "forza": 0, "res": 5, "fuoco": false, "fz": -1, "creatura": cre, "afferrato": preso}, altri, luogo)
		"WYTHS":
			var mx := 0
			for id in gruppo:
				mx = maxi(mx, m.val(id, "intelligenza"))
			return await risolvi({"nome": nome, "forza": int(cre["s"]), "res": int(cre["r"]), "fuoco": false, "fz": -1, "creatura": cre, "meno_int": mx}, gruppo, luogo)
	var r := await risolvi({"nome": nome, "forza": int(cre["s"]), "res": int(cre["r"]), "fuoco": cre.get("fuoco", false), "fz": -1, "creatura": cre}, gruppo, luogo)
	if cod == "IPNOSI" and r.get("att_vivo", false):
		r["no_bonus"] = true
	return r
