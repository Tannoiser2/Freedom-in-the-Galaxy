class_name IA
extends RefCounted
## Avversario artificiale per entrambe le parti. Ogni richiesta del motore porta una «chiave» che dice
## che tipo di decisione è; l'IA valuta lo stato della partita e restituisce l'indice dell'opzione
## (o la maschera di bit per le scelte multiple).
##
## Ribelli: si muovono verso i pianeti più vicini all'Agitazione, evitano le truppe e i BDP più forti,
## fanno Diplomazia, Colpi di Stato e appena possibile Avviano la Ribellione.
## Impero: presidia i pianeti a rischio, dà la caccia ai Ribelli individuati, cerca, cattura,
## riporta la Lealtà verso il Patriottismo e ferma le ribellioni.

var obiettivi := {}   # id unità -> luogo desiderato in questo turno
var turno_piano := -1
var _meta_truppe := ""


func decide(m: Motore, posto: int, req: Dictionary):
	await m.get_tree().process_frame
	return scegli(m, posto, req)


func scegli(m: Motore, f: int, req: Dictionary) -> int:
	var opz: Array = req.get("opzioni", [])
	if opz.is_empty():
		return 0
	if req.get("tipo", "") == "multi":
		return _multi(m, f, req)
	var chiave: String = req.get("chiave", "")
	match chiave:
		"schiera_pg", "dallo_spazio", "rinforzo":
			return _miglior_luogo(m, f, opz, chiave)
		"schiera_mil":
			return _miglior_luogo(m, f, opz, "presidio")
		"movimento":
			return _movimento(m, f, opz)
		"dest", "dest_nave", "dest_truppe":
			return _destinazione(m, f, opz, req)
		"reazione":
			return _reazione(m, f, opz, req)
		"dichiara_battaglia", "attacco_ribellione":
			return 0 if _conviene_battaglia(m, f, req.get("luogo", "")) else 1
		"capo":
			var best := 0
			var bv := -1
			for i in range(1, opz.size()):
				var v := m.comando(opz[i]["id"])
				if v > bv:
					bv = v
					best = i
			return best
		"ricerca":
			return opz.size() - 1
		"attacca_trovati":
			return _attacca_trovati(m, f, req)
		"tipo_mischia":
			return 0
		"sganciamento":
			return 1 if int(req.get("diff", 0)) >= 3 else 0
		"luogo_missioni":
			return 0
		"assegna":
			return _assegna(m, f, opz, req)
		"campo":
			for i in opz.size():
				if opz[i].get("lettera", "") == "D":
					return i
			return mini(1, opz.size() - 1)
		"continua_pesca":
			return 0
		"completa_ora":
			var lt: String = req.get("lettera", "")
			if lt in ["C", "F"] and int(req.get("n", 1)) < 2:
				return 1
			return 0
		"acquisto_ribelle":
			return 0
		"razzia":
			return _razzia(m, opz)
		"sabotaggio":
			return _piu_forte(m, opz)
		"incidente":
			var b := 0
			var bv2 := -99
			for i in opz.size():
				var r := m.resistenza_residua(opz[i]["id"])
				if r > bv2:
					bv2 = r
					b = i
			return b
		"rialza_bdp":
			return 1 if opz.size() > 1 else 0
		"rinforzo_varu":
			return 1 if not m._bdp_da_rialzare(Motore.I).is_empty() else 0
		"assegna_possesso":
			return _assegna_possesso(m, opz, req)
		"giustiziato":
			var b2 := 0
			var bv3 := 99
			for i in opz.size():
				var c := m.combattimento_pg(opz[i]["id"]) + m.val(opz[i]["id"], "diplomazia")
				if c < bv3:
					bv3 = c
					b2 = i
			return b2
	return 0


# ------------------------------------------------------------------------------------
# Valutazione dei luoghi
# ------------------------------------------------------------------------------------

## Quanto è interessante un ambiente per i personaggi della fazione f.
func valore_luogo(m: Motore, f: int, l: String) -> float:
	var pid := m.pid_di(l)
	var p: Dictionary = m.pianeti[pid]
	var v := 0.0
	var nemico := m.avversario(f)
	var forza_nemica := m.forza_mil(m.mil_in(l, nemico))
	if f == Motore.R:
		match p["stato"]:
			"imperiale", "fermata":
				v += [0.0, 2.5, 5.5, 8.0, 11.0][p["lealta"]]
			"ribellione":
				v += 3.0
			"ribelle":
				v += 0.5
		v += m.taglia(l) * 0.6
		v -= forza_nemica * 0.7
		var liv := m.bdp_attiva(pid, f)
		if liv > 0:
			v -= liv * 0.8
		if Dati.ambiente(l).get("coup", null) != null:
			v += 0.5
		var cre = Dati.ambiente(l).get("creatura", null)
		if cre != null:
			v -= 0.7
	else:
		match p["stato"]:
			"imperiale":
				v += [0.0, 1.0, 3.0, 5.0, 7.0][p["lealta"]]
			"ribellione":
				v += 8.0
			"fermata":
				v += 5.0
			"ribelle":
				v += 2.0
		v += m.taglia(l) * 0.5
		for id in m.pg_in(l, nemico, true):
			if m.unita[id]["ind"]:
				v += 3.0
		v += m.mil_in(l, nemico).size() * 1.0
	return v


## Quanto costa (in rischio) volare da `da` ad `a`: BDP nemici in partenza e in arrivo, peggio se già individuati.
func _rischio_volo(m: Motore, f: int, id: int, da: String, a: String) -> float:
	if da == "" or da == a:
		return 0.0
	var stesso := m.pid_di(da) == m.pid_di(a)
	var nave_qui := false
	for o in m.pg_in(da, f, true):
		if not m.unita[o]["nave"].is_empty():
			nave_qui = true
	if not nave_qui:
		return 0.0 if stesso else 99.0
	var r := 0.0
	var ind: bool = m.unita[id]["ind"]
	for pid in ([m.pid_di(da)] if stesso else [m.pid_di(da), m.pid_di(a)]):
		var liv := m.bdp_attiva(pid, f)
		if liv >= 0:
			r += 0.4 + liv * 1.2 + (1.0 if ind else 0.0)
	if stesso:
		r *= 0.5
	return r


func _miglior_luogo(m: Motore, f: int, opz: Array, scopo: String) -> int:
	var best := 0
	var bv := -9999.0
	for i in opz.size():
		var l: String = opz[i].get("luogo", "")
		if l == "":
			continue
		var v := valore_luogo(m, f, l)
		if scopo == "presidio":
			# le truppe imperiali si spargono dove il rischio è maggiore
			v -= m.mil_in(l, f).size() * 2.5
			v += m.taglia(l) * 0.3
		if scopo == "dallo_spazio":
			var liv := int(m.pianeti[m.pid_di(l)]["bdp"])
			v -= liv * 2.5
		if v > bv:
			bv = v
			best = i
	return best


# ------------------------------------------------------------------------------------
# Movimento
# ------------------------------------------------------------------------------------

func _pianifica(m: Motore, f: int) -> void:
	if turno_piano == m.turno * 2 + f:
		return
	turno_piano = m.turno * 2 + f
	obiettivi.clear()
	var luoghi := m.luoghi_sistema()
	if f == Motore.R:
		# tutti i personaggi verso l'ambiente migliore, raggiungibile in un colpo
		for id in m.unita:
			var u: Dictionary = m.unita[id]
			if u["fz"] == f and u["k"] == "pg" and m.vivo(id):
				var dove: String = u["luogo"]
				var best := dove
				var bv := -9999.0
				for l in luoghi:
					var v := valore_luogo(m, f, l) - _rischio_volo(m, f, id, dove, l)
					if l == dove:
						v += 1.5
					if v > bv:
						bv = v
						best = l
				obiettivi[id] = best
		# truppe ribelli: restano nel loro ambiente o vanno a difendere pianeti in ribellione
		for id in m.unita:
			var u2: Dictionary = m.unita[id]
			if u2["fz"] == f and u2["k"] == "mil" and m.vivo(id):
				obiettivi[id] = u2["luogo"]
	else:
		# truppe: verso Ribelli individuati e truppe ribelli se conviene, altrimenti presidio
		var minacce := []
		for l in luoghi:
			var peso := 0.0
			for id in m.pg_in(l, Motore.R, true):
				if m.unita[id]["ind"]:
					peso += 3.0
			peso += m.forza_mil(m.mil_in(l, Motore.R)) * 1.5
			var p: Dictionary = m.pianeti[m.pid_di(l)]
			if p["stato"] == "ribellione":
				peso += 4.0
			peso += max(0, p["lealta"] - 2) * 1.0
			minacce.append([peso, l])
		minacce.sort_custom(func(a, b): return a[0] > b[0])
		var usati := {}
		for id in m.unita:
			var u3: Dictionary = m.unita[id]
			if u3["fz"] != f or not m.vivo(id):
				continue
			if u3["k"] == "mil":
				obiettivi[id] = u3["luogo"]
				if not u3["mobile"]:
					continue
				for mn in minacce:
					var l: String = mn[1]
					if mn[0] <= 0.5:
						break
					if usati.get(l, 0) >= 2 or l == u3["luogo"]:
						continue
					# non sguarnire un ambiente minacciato
					if m.mil_in(u3["luogo"], f).size() <= 1 and valore_luogo(m, f, u3["luogo"]) > valore_luogo(m, f, l):
						break
					obiettivi[id] = l
					usati[l] = usati.get(l, 0) + 1
					break
			elif u3["k"] == "pg":
				var best_l: String = u3["luogo"]
				var bv2 := -9999.0
				for l in luoghi:
					var v := valore_luogo(m, f, l) - (0.0 if l == u3["luogo"] else 0.8)
					if v > bv2:
						bv2 = v
						best_l = l
				obiettivi[id] = best_l


func _movimento(m: Motore, f: int, opz: Array) -> int:
	_pianifica(m, f)
	for i in opz.size():
		var o: Dictionary = opz[i]
		if o.get("fine", false):
			continue
		match o["tipo"]:
			"nave":
				var id: int = o["id"]
				var ob: String = obiettivi.get(id, "")
				if ob != "" and ob != m.unita[id]["luogo"]:
					return i
			"piedi":
				var id2: int = o["id"]
				var ob2: String = obiettivi.get(id2, "")
				if ob2 != "" and ob2 != m.unita[id2]["luogo"] and m.pid_di(ob2) == m.pid_di(m.unita[id2]["luogo"]) and m.unita[id2]["nave"].is_empty():
					# a piedi solo se nessuno del gruppo ha un'astronave
					var navi := m.pg_in(m.unita[id2]["luogo"], f, true).filter(func(x): return not m.unita[x]["nave"].is_empty() and not m.unita[x]["mosso"])
					if navi.is_empty():
						return i
			"truppe":
				for id3 in m.mil_in(o["luogo"], f):
					if not m.unita[id3]["mosso"] and obiettivi.get(id3, o["luogo"]) != o["luogo"]:
						return i
	return opz.size() - 1


func _destinazione(m: Motore, f: int, opz: Array, req: Dictionary) -> int:
	var id: int = req.get("id", -1)
	var ob: String = obiettivi.get(id, "")
	if req.get("chiave", "") == "dest_truppe":
		ob = _meta_truppe
	for i in opz.size():
		if opz[i].get("luogo", "") == ob:
			return i
	return _miglior_luogo(m, f, opz, "")


func _reazione(m: Motore, f: int, opz: Array, req: Dictionary) -> int:
	var l: String = req.get("luogo", "")
	if f == Motore.R:
		return 0
	# l'Impero manda la truppa più forte (con comandante se c'è) verso i Ribelli individuati
	var best := 0
	var bv := 0.0
	for i in range(1, opz.size()):
		var u: Dictionary = m.unita[opz[i]["id"]]
		var v := 0.0
		if u["k"] == "mil":
			v = u["forza"] * 2.0 + (m.comando(opz[i]["capo"]) * 1.5 if opz[i].has("capo") else 0.0)
			if m.mil_in(u["luogo"], f).size() <= 1 and not m.mil_in(u["luogo"], Motore.R).is_empty():
				v -= 10.0
		else:
			v = m.combattimento_pg(opz[i]["id"]) * 0.6
		if v > bv:
			bv = v
			best = i
	return best


func _conviene_battaglia(m: Motore, f: int, l: String) -> bool:
	if l == "":
		return false
	var mie := m.forza_mil(m.mil_in(l, f))
	var loro := m.forza_mil(m.mil_in(l, m.avversario(f)))
	var capo := 0
	for id in m.pg_in(l, f, true):
		capo = maxi(capo, m.comando(id))
	var bonus := capo
	if f == Motore.R:
		for id in m.mil_in(l, f):
			if m.unita[id]["amb"] == m.tipo_amb(l):
				bonus += 1
				break
		if m.tipo_amb(l) in Dati.SPECIALI:
			bonus += 1
	var rapporto: float = float(mie) / max(1, loro)
	return rapporto + bonus * 0.5 >= 1.5


# ------------------------------------------------------------------------------------
# Missioni
# ------------------------------------------------------------------------------------

func _assegna(m: Motore, f: int, opz: Array, req: Dictionary) -> int:
	var id: int = req.get("id", -1)
	var l: String = req.get("luogo", "")
	var p: Dictionary = m.pianeti[m.pid_di(l)]
	var prior := {}
	if f == Motore.R:
		prior = {"R": 100, "D": 40 + m.val(id, "diplomazia") * 6, "C": 35 + m.val(id, "comando") * 5, "B": 20 + m.val(id, "comando") * 4,
			"I": 18 + m.val(id, "intelligenza") * 3, "A": 10 + m.val(id, "intelligenza") * 3, "T": 15 + m.val(id, "comando") * 5,
			"P": 12, "G": 22, "S": 14, "F": 60}
		if p["lealta"] <= 1:
			prior["B"] += 15
		if p["lealta"] < 4:
			prior["R"] = 0
	else:
		prior = {"R": 100, "D": 25 + m.val(id, "diplomazia") * 6 + p["lealta"] * 6, "C": 20 + m.val(id, "comando") * 4 + p["lealta"] * 4,
			"A": 30 + m.val(id, "intelligenza") * 3, "I": 14 + m.val(id, "intelligenza") * 3, "S": 18, "G": 16, "F": 60}
	var best := 0
	var bv := 5.0 if m.unita[id]["ferite"] > 0 and m.resistenza_residua(id) <= 2 else 0.0
	for i in opz.size():
		var o: Dictionary = opz[i]
		var v := 0.0
		if o.has("lettera"):
			v = prior.get(o["lettera"], 5)
			if o["lettera"] == "R" and f == Motore.R and opz.any(func(x): return x.has("unisci") and x["unisci"]["lettera"] == "R"):
				v = 0.0
		elif o.has("unisci"):
			var g: Dictionary = o["unisci"]
			var lt: String = g["lettera"]
			v = prior.get(lt, 5) * 0.75
			if lt == "D":
				v = prior.get("D", 30) * 0.95 if m.val(id, "diplomazia") <= 1 else 30.0
			if lt == "R":
				v = 60.0 if f == Motore.I else 95.0
		if v > bv:
			bv = v
			best = i
	return best


func _attacca_trovati(m: Motore, f: int, req: Dictionary) -> int:
	var l: String = req.get("luogo", "")
	var loro := 0
	for id in m.pg_in(l, m.avversario(f), true):
		if m.unita[id]["ind"] and not m.unita[id]["truppe"]:
			loro += m.combattimento_pg(id)
	var nostri := m.forza_mil(m.mil_in(l, f))
	var squadra := 4
	for r in Dati.d()["tabelle"]["squadra"]:
		if nostri >= int(r["da"]) and nostri <= int(r["a"]):
			squadra = int(r["comb"])
	var pg := 0
	for id in m.pg_in(l, f, true):
		if not m.unita[id]["truppe"]:
			pg += m.combattimento_pg(id)
	var forza := maxi(squadra if nostri > 0 else 0, pg)
	if forza - loro >= 6:
		return 1
	if forza - loro >= 0:
		return 0
	return 2


func _razzia(m: Motore, opz: Array) -> int:
	var best := 0
	var bv := 999
	for i in opz.size():
		var v := 50
		if opz[i].has("id"):
			v = int(m.unita[opz[i]["id"]]["forza"]) * 10
		if v < bv:
			bv = v
			best = i
	return best


func _piu_forte(m: Motore, opz: Array) -> int:
	var best := 0
	var bv := -1
	for i in opz.size():
		var v := 15
		if opz[i].has("id"):
			v = int(m.unita[opz[i]["id"]]["forza"]) * 10
		if v > bv:
			bv = v
			best = i
	return best


func _assegna_possesso(m: Motore, opz: Array, req: Dictionary) -> int:
	var nr: int = req.get("nr", 0)
	var c: Dictionary = Dati.d()["poss"].get(nr, {})
	var best := 0
	var bv := -1
	for i in opz.size():
		var id: int = opz[i]["id"]
		var v := m.combattimento_pg(id)
		if c.get("tipo", "") == "astronave":
			v = m.val(id, "navigazione") * 3 - (20 if not m.unita[id]["nave"].is_empty() else 0)
		if v > bv:
			bv = v
			best = i
	return best


func _multi(m: Motore, f: int, req: Dictionary) -> int:
	var opz: Array = req["opzioni"]
	var chiave: String = req.get("chiave", "")
	var mask := 0
	match chiave:
		"con_truppe":
			var l: String = req.get("luogo", "")
			if m.mil_in(l, m.avversario(f)).is_empty():
				return 0
			for i in opz.size():
				if m.comando(opz[i]["id"]) >= 1 and f == Motore.I:
					mask |= 1 << i
					break
			return mask
		"accompagna":
			return 0
		"passeggeri":
			var mx := int(req.get("max", opz.size()))
			for i in mini(mx, opz.size()):
				var id: int = opz[i]["id"]
				var ob: String = obiettivi.get(id, "")
				mask |= 1 << i if ob == "" or ob != m.unita[id]["luogo"] else 0
			return mask
		"truppe_sel":
			_meta_truppe = ""
			for i in opz.size():
				var id2: int = opz[i]["id"]
				var ob2: String = obiettivi.get(id2, m.unita[id2]["luogo"])
				if ob2 != m.unita[id2]["luogo"] and (_meta_truppe == "" or mask == 0 or ob2 == _meta_truppe):
					if mask == 0:
						_meta_truppe = ob2
					mask |= 1 << i
			return mask if mask != 0 else 1
		"attivi":
			for i in opz.size():
				if m.combattimento_pg(opz[i]["id"]) > 0:
					mask |= 1 << i
			return mask if mask != 0 else 1
	for i in opz.size():
		mask |= 1 << i
	return mask
