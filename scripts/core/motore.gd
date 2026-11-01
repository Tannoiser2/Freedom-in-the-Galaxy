class_name Motore
extends Node
## Motore di Freedom in the Galaxy (SPI, 1979): stato della partita e regole dello Star System Game.
##
## Il motore non conosce l'interfaccia: quando serve una decisione chiama `chiedi(posto, richiesta)`,
## che gira la domanda al controllore del posto (persona, IA o partita online) e attende un numero:
## l'indice dell'opzione scelta oppure, per le scelte multiple, una maschera di bit.
## Tutti i dadi e i mescolamenti usano il generatore con il seme della partita: con lo stesso seme e le
## stesse risposte la partita è identica ovunque (gioco online, ripresa dei salvataggi).

signal cambiato
signal messaggio(testo: String)
signal evento(tipo: String, dati: Dictionary)
signal finita(esito: String)
signal ripresa_finita

const R := 0   # Ribelli
const I := 1   # Impero

var rng := RandomNumberGenerator.new()
var seme := 0
var controllori: Array = [null, null]
var giocatori: Array = []        # [{nome, ia}] per Ribelli e Impero
var scenario: Dictionary = {}
var scenario_id := ""

# --- stato
var pianeti: Dictionary = {}     # pid -> {lealta, stato, bdp, su, coup:{i:true}}
var campi: Dictionary = {}       # luogo -> true (Campo Ribelle)
var unita: Dictionary = {}       # id -> unità
var prossimo_id := 1
var mazzo_pg: Array = [[], []]   # personaggi ancora disponibili per «Ottieni alleati»
var mazzo_poss: Array = []       # possessi non in gioco
var vittoria_info := [false, false]  # Raccogli informazioni completata: [ribelli, impero]
var zop_usato := false
var turno := 1
var fase := "preparazione"
var di_turno := R
var esito := ""
var registro: Array = []
var rinforzi_attesi := 0         # Linee imperiali dovute (Flight to Egrix)
var ritmo := 0.0
var in_simulazione := false
var _scelte_fatte := 0
var storia: Array = []           # tutte le scelte fatte, nell'ordine (salvataggi)
var da_rigiocare: Array = []
var in_simulazione_prima := false
var richiesta_corrente: Dictionary = {}
var richiesta_posto := -1
# --- Province Game e Galactic Game
var livello := "sistema"         # sistema, provincia, galassia
var provincia := 0
var av: Avanzato
var galattico: Galattico
var sovrani := {}                # nome -> stato del sovrano convocato
var eventi_attivi: Array = []    # eventi galattici in vigore in questo turno
var pf := [0, 0]                 # tracciati delle risorse [Ribelli, Impero]
var _cache_pianeti: Array = []
var giro := 0                    # primo o secondo giro di turni nel Galactic Game


func _init() -> void:
	Dati.d()
	av = Avanzato.new(self)
	galattico = Galattico.new(self)


# =====================================================================================
# UTILITÀ
# =====================================================================================

func scrivi(t: String) -> void:
	registro.append(t)
	if registro.size() > 400:
		registro.remove_at(0)
	messaggio.emit(t)


func dado() -> int:
	return rng.randi_range(1, 6)


func chiedi(posto: int, req: Dictionary) -> int:
	_scelte_fatte += 1
	if not da_rigiocare.is_empty():
		var v := int(da_rigiocare.pop_front())
		storia.append(v)
		if da_rigiocare.is_empty():
			in_simulazione = in_simulazione_prima
			ripresa_finita.emit()
		return v
	var c = controllori[posto]
	if c == null:
		return 0
	richiesta_corrente = req
	richiesta_posto = posto
	var r = await c.decide(self, posto, req)
	richiesta_corrente = {}
	storia.append(int(r))
	return int(r)


## Riprende una partita salvata: le scelte registrate vengono riapplicate senza chiedere nulla.
func riprendi(scelte: Array) -> void:
	da_rigiocare = scelte.duplicate()
	if not da_rigiocare.is_empty():
		in_simulazione_prima = in_simulazione
		in_simulazione = true


## Scelta fra opzioni testuali; restituisce l'indice. Con una sola opzione obbligata non chiede nulla.
func scegli(posto: int, testo: String, opzioni: Array, extra := {}) -> int:
	if opzioni.size() == 1 and not extra.get("conferma", false):
		return 0
	var req := {"tipo": "scelta", "testo": testo, "opzioni": opzioni}
	req.merge(extra)
	var v := await chiedi(posto, req)
	return clampi(v, 0, opzioni.size() - 1)


## Scelta multipla: restituisce gli indici scelti.
func scegli_multi(posto: int, testo: String, opzioni: Array, extra := {}) -> Array:
	var req := {"tipo": "multi", "testo": testo, "opzioni": opzioni}
	req.merge(extra)
	var m := await chiedi(posto, req)
	var out := []
	for i in opzioni.size():
		if m & (1 << i):
			out.append(i)
	return out


func avversario(f: int) -> int:
	return 1 - f


func attesa(sec: float) -> void:
	if ritmo > 0.0 and not in_simulazione:
		await get_tree().create_timer(sec * ritmo).timeout


# =====================================================================================
# UNITÀ
# =====================================================================================

func nuovo_pg(nome: String, fz: int) -> int:
	var c := Dati.carta_pg(nome)
	var id := prossimo_id
	prossimo_id += 1
	unita[id] = {"id": id, "k": "pg", "fz": fz, "nome": nome, "luogo": "", "ferite": 0, "ind": false,
		"prig": -1, "truppe": false, "nave": {}, "poss": [], "mosso": false, "attivo_turno": false,
		"guarda": -1, "c": c}
	mazzo_pg[fz].erase(nome)
	return id


func nuova_mil(fz: int, tipo: String, forza: int, amb := "", mobile := false) -> int:
	var id := prossimo_id
	prossimo_id += 1
	unita[id] = {"id": id, "k": "mil", "fz": fz, "tipo": tipo, "forza": forza, "amb": amb,
		"mobile": mobile, "luogo": "", "mosso": false, "scoperta": false}
	return id


func nave_da_possesso(nr: int) -> Dictionary:
	var c: Dictionary = Dati.d()["poss"].get(nr, {})
	return {"nome": c.get("nome_it", c.get("nome_en", "Astronave")), "nr": nr, "man": int(c.get("manovra", 1)),
		"pas": int(c.get("passeggeri", 2)), "dmg": false, "imp": false, "redjac": false}


func nave_imperiale(redjac := false) -> Dictionary:
	if redjac:
		return {"nome": "Astronave di Redjac", "nr": 0, "man": 3, "pas": 4, "dmg": false, "imp": true, "redjac": true}
	return {"nome": "Astronave imperiale", "nr": 0, "man": 1, "pas": 4, "dmg": false, "imp": true, "redjac": false}


func vivo(id: int) -> bool:
	return unita.has(id) and unita[id]["luogo"] != "morto"


func pg_in(luogo: String, fz := -1, liberi := false) -> Array:
	var out := []
	for id in unita:
		var u: Dictionary = unita[id]
		if u["k"] == "pg" and u["luogo"] == luogo and (fz < 0 or u["fz"] == fz):
			if liberi and u["prig"] >= 0:
				continue
			out.append(id)
	return out


func mil_in(luogo: String, fz := -1) -> Array:
	var out := []
	for id in unita:
		var u: Dictionary = unita[id]
		if u["k"] == "mil" and u["luogo"] == luogo and (fz < 0 or u["fz"] == fz):
			out.append(id)
	return out


func mil_su_pianeta(pid: int, fz: int) -> Array:
	var out := []
	for id in unita:
		var u: Dictionary = unita[id]
		if u["k"] == "mil" and u["fz"] == fz and is_amb(u["luogo"]) and int(u["luogo"].get_slice(":", 0)) == pid:
			out.append(id)
	return out


func forza_mil(ids: Array) -> int:
	var t := 0
	for id in ids:
		t += int(unita[id]["forza"])
	return t


func luoghi_sistema() -> Array:
	var out := []
	for pid in scenario_pianeti():
		var p := Dati.pianeta(pid)
		for i in p["ambienti"].size():
			out.append("%d:%d" % [pid, i])
	return out


func scenario_pianeti() -> Array:
	if not _cache_pianeti.is_empty():
		return _cache_pianeti
	var out := []
	for p in Dati.d()["galassia"]["pianeti"]:
		var pid := int(p["id"])
		if pianeti.has(pid) and pianeti[pid].get("distrutto", false):
			continue
		match livello:
			"sistema":
				if int(p["stella"]) != int(scenario.get("stella", 0)):
					continue
			"provincia":
				if int(pid / 100) != provincia:
					continue
		out.append(pid)
	out.sort()
	if not pianeti.is_empty():
		_cache_pianeti = out
	return out


func azzera_cache() -> void:
	_cache_pianeti = []


func is_amb(l: String) -> bool:
	if l == "" or l == "morto" or l.begins_with("D") or l.begins_with("S:"):
		return false
	return l.get_slice(":", 1).is_valid_int()


func is_orbita(l: String) -> bool:
	return l.ends_with(":o")


func distrutto(pid: int) -> bool:
	return pianeti.has(pid) and pianeti[pid].get("distrutto", false)


func evento_attivo(nr: int) -> bool:
	return eventi_attivi.has(nr)


## Pianeta natale e regalità (26.0): 0 nessuno, 1 pianeta natale, 2 reale sul suo pianeta.
func natale(id: int, pid: int) -> int:
	var u: Dictionary = unita[id]
	if u["k"] != "pg" or u.get("sovrano", false):
		return 0
	var nome_p: String = str(Dati.pianeta(pid).get("nome", ""))
	if not u["c"].get("pianeti_natali", []).has(nome_p):
		return 0
	var titolo: String = str(u["c"].get("titolo_en", ""))
	for t in ["Prince", "Princess", "King", "Queen", "Lord", "Duke", "Duchess", "Baron", "Heir", "Emperor", "Empress", "Count"]:
		if titolo.contains(t) and titolo.contains(nome_p):
			return 2
	return 1


## +1 al Comando di un personaggio reale sul suo pianeta natale (26.0).
func bonus_reale(id: int, l: String) -> int:
	if id < 0 or livello == "sistema" or not unita.has(id):
		return 0
	if natale(id, pid_di(l)) == 2 and comando(id) > 0:
		return 1
	return 0


## Nuova unità militare dal catalogo delle regole avanzate (19.7).
func nuova_unita(fz: int, cat: String, amb := "") -> int:
	var d: Dictionary = Dati.d()["regole_avanzate"]["unita"][cat]
	var id := prossimo_id
	prossimo_id += 1
	unita[id] = {"id": id, "k": "mil", "fz": fz, "tipo": "rib" if fz == R else cat, "cat": cat, "forza": int(d["f"]),
		"spazio": int(d["s"]), "amb": amb, "mobile": bool(d["mobile"]), "luogo": "", "mosso": false, "scoperta": false,
		"elite": d.get("elite", false), "suicida": d.get("suicida", false), "atrocita": d.get("atrocita", false)}
	return id


func pid_di(luogo: String) -> int:
	return int(luogo.get_slice(":", 0))


func taglia(luogo: String) -> int:
	return int(Dati.ambiente(luogo).get("taglia", 1))


func tipo_amb(luogo: String) -> String:
	return str(Dati.ambiente(luogo).get("tipo", "urbano"))


func nome_luogo(luogo: String) -> String:
	if luogo == "":
		return "nello spazio"
	return Dati.nome_ambiente(luogo)


func nome_u(id: int) -> String:
	var u: Dictionary = unita[id]
	if u["k"] == "pg":
		return u["nome"]
	return descr_mil(id)


func descr_mil(id: int) -> String:
	var u: Dictionary = unita[id]
	if u.has("cat"):
		var d: Dictionary = Dati.d()["regole_avanzate"]["unita"][u["cat"]]
		if u["fz"] == R:
			return "%s %d-%d%s" % [Dati.AMBIENTI_NOMI.get(u["amb"], ""), int(d["f"]), int(d["s"]), " d'élite" if d.get("elite", false) else ""]
		return "%s %d-%d" % [d["nome"], int(d["f"]), int(d["s"])]
	match u["tipo"]:
		"milizia":
			return "Milizia 1-0"
		"pattuglia":
			return "Pattuglia 1-2"
		"linea":
			return "Linea 3-2"
		_:
			return "%s %s" % [Dati.AMBIENTI_NOMI.get(u["amb"], ""), "2-1" if u["forza"] == 2 else "1-0"]


# --- valori dei personaggi (ferite e possessi compresi)

func val(id: int, attr: String) -> int:
	var u: Dictionary = unita[id]
	var v := int(u["c"].get(attr, 0)) + (_kogus(id) if attr != "resistenza" else 0)
	if u["fz"] == R:
		for nr in u["poss"]:
			v += int(Dati.d()["possessi_effetti"].get(str(nr), {}).get(attr, 0))
	return v


func combattimento_pg(id: int) -> int:
	var u: Dictionary = unita[id]
	var base := maxi(0, int(u["c"].get("combattimento", 0)) - int(u["ferite"]) + _kogus(id))
	if u["fz"] == R:
		for nr in u["poss"]:
			base += int(Dati.d()["possessi_effetti"].get(str(nr), {}).get("combattimento", 0))
	return base


## Kogus: +1 a tutti i valori (tranne la Resistenza) quando è con Zina Adora.
func _kogus(id: int) -> int:
	var u: Dictionary = unita[id]
	if u["nome"] != "Kogus" or u["luogo"] == "" or u["luogo"] == "morto":
		return 0
	for o in pg_in(u["luogo"], u["fz"], true):
		if unita[o]["nome"] == "Zina Adora":
			return 1
	return 0


func resistenza_residua(id: int) -> int:
	return int(unita[id]["c"].get("resistenza", 1)) - int(unita[id]["ferite"])


func comando(id: int) -> int:
	return int(unita[id]["c"].get("comando", 0))


# =====================================================================================
# CONTROLLO DEI PIANETI (15.5)
# =====================================================================================

## Chi controlla il pianeta: R, I oppure -1 (nessuno).
func controllo(pid: int) -> int:
	var p: Dictionary = pianeti[pid]
	var rr := not mil_su_pianeta(pid, R).is_empty()
	var ii := not mil_su_pianeta(pid, I).is_empty()
	match p["stato"]:
		"imperiale":
			if rr and not ii:
				return I if p["su"] else -1
			return I
		"ribellione":
			return -1
		"ribelle":
			if ii and not rr:
				return R if p["su"] else -1
			return R
		"fermata":
			if ii and not rr:
				return I
			return -1
	return -1


## Lo stato «Ribellione fermata» con sole truppe imperiali torna Controllo imperiale (15.54).
func aggiorna_controllo() -> void:
	for pid in pianeti:
		var p: Dictionary = pianeti[pid]
		if p["stato"] == "fermata" and not mil_su_pianeta(pid, I).is_empty() and mil_su_pianeta(pid, R).is_empty():
			p["stato"] = "imperiale"
			scrivi("%s torna sotto Controllo imperiale." % Dati.pianeta(pid)["nome"])


func bdp_attiva(pid: int, contro: int) -> int:
	## Livello del BDP utilizzabile contro la fazione `contro`, -1 se non utilizzabile.
	var p: Dictionary = pianeti[pid]
	var c := controllo(pid)
	if c < 0 or c == contro or not p["su"]:
		return -1
	return int(p["bdp"])


# =====================================================================================
# PREPARAZIONE
# =====================================================================================

## config: {scenario, seme, giocatori: [{nome, ia}, {nome, ia}]}
func prepara(config: Dictionary) -> void:
	seme = int(config.get("seme", 0))
	if seme == 0:
		seme = randi()
	rng.seed = seme
	scenario_id = config.get("scenario", "egrix")
	scenario = Dati.d()["scenari"][scenario_id]
	livello = str(scenario.get("livello", "sistema"))
	provincia = int(scenario.get("provincia", 0))
	_cache_pianeti = []
	giocatori = config.get("giocatori", [{"nome": "Ribelli", "ia": false}, {"nome": "Impero", "ia": true}])
	var D := Dati.d()
	for c in D["carte"]["personaggi"]:
		mazzo_pg[R if c["fazione"] == "ribelli" else I].append(c["nome"])
	for c in D["carte"]["possessi"]:
		mazzo_poss.append(int(c["nr"]))
	var armageddon: bool = scenario.get("tipo", "S") == "A"
	for pid in scenario_pianeti():
		var dp := Dati.pianeta(pid)
		var pol: Dictionary = dp["politica"]
		var stato := "imperiale"
		var lea := Dati.LEALTA.find(str(pol["A"] if armageddon else pol["S"]))
		if armageddon and pol.get("AC", false):
			stato = "ribelle"
			lea = 4
		var bdp := 0
		var bd = scenario.get("bdp", {})
		if bd is Dictionary:
			bdp = int(bd.get(str(pid), 0))
		elif str(bd) == "tutti2":
			bdp = 2
		pianeti[pid] = {"lealta": maxi(lea, 0), "stato": stato, "bdp": bdp, "su": livello != "galassia", "coup": {}, "distrutto": false}
	_mescola(mazzo_pg[R])
	_mescola(mazzo_pg[I])
	_mescola(mazzo_poss)
	_cache_pianeti = []


func _mescola(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _pianeti_controllati(f: int) -> Array:
	var out := []
	for pid in pianeti:
		if controllo(pid) == f:
			out.append(pid)
	return out


## Schieramento iniziale (16.12-16.14): prima l'Impero, poi i Ribelli.
func schiera() -> void:
	fase = "schieramento"
	for f in [I, R]:
		var dati_f: Dictionary = scenario["fazioni"][str(f)]
		var pg_ids := []
		for nome in dati_f.get("personaggi", []):
			pg_ids.append(nuovo_pg(nome, f))
		# astronavi
		var navi: Array = dati_f.get("navi", [])
		for i in navi.size():
			var n = navi[i]
			var nave := {}
			if str(n) == "imperiale":
				nave = nave_imperiale(false)
			elif str(n) == "redjac":
				nave = nave_imperiale(true)
			else:
				nave = nave_da_possesso(int(n))
				mazzo_poss.erase(int(n))
			var pilota := _pilota_per_nave(pg_ids, nave)
			if pilota >= 0:
				unita[pilota]["nave"] = nave
		# truppe
		var mil := []
		for m in dati_f.get("militari", []):
			for k in int(m.get("n", 1)):
				mil.append(_crea_mil_da(f, m))
		var controllati := _pianeti_controllati(f)
		if controllati.is_empty():
			for id in pg_ids:
				unita[id]["luogo"] = ""   # entreranno «dallo spazio» al primo movimento
			scrivi("%s: i personaggi entreranno dallo spazio al primo turno." % Dati.FAZIONI[f])
		else:
			var luoghi := []
			for pid in controllati:
				for i in Dati.pianeta(pid)["ambienti"].size():
					luoghi.append("%d:%d" % [pid, i])
			var opz := []
			for l in luoghi:
				opz.append({"t": nome_luogo(l), "luogo": l})
			if not pg_ids.is_empty():
				var k := await scegli(f, "Dove entrano in gioco i tuoi personaggi?", opz, {"chiave": "schiera_pg"})
				for id in pg_ids:
					unita[id]["luogo"] = luoghi[k]
		for id in mil:
			var possibili := []
			for pid in controllati:
				for i in Dati.pianeta(pid)["ambienti"].size():
					var l := "%d:%d" % [pid, i]
					if unita[id]["amb"] != "" and tipo_amb(l) != unita[id]["amb"]:
						continue
					if mil_in(l, f).size() >= taglia(l):
						continue
					possibili.append(l)
			if possibili.is_empty():
				unita.erase(id)
				continue
			var opz2 := []
			for l in possibili:
				opz2.append({"t": "%s (%d/%d)" % [nome_luogo(l), mil_in(l, f).size(), taglia(l)], "luogo": l})
			var k2 := await scegli(f, "Schiera %s:" % descr_mil(id), opz2, {"chiave": "schiera_mil", "unita": id})
			unita[id]["luogo"] = possibili[k2]
			cambiato.emit()
	scrivi("Schieramento completato.")
	cambiato.emit()


func _crea_mil_da(f: int, m: Dictionary) -> int:
	match str(m["tipo"]):
		"milizia":
			return nuova_mil(f, "milizia", 1, "", false)
		"pattuglia":
			return nuova_mil(f, "pattuglia", 1, "", true)
		"linea":
			return nuova_mil(f, "linea", 3, "", true)
		_:
			var forza := int(m.get("forza", 1))
			return nuova_mil(f, "rib", forza, str(m["amb"]), forza >= 2)


func _pilota_per_nave(ids: Array, nave: Dictionary) -> int:
	var best := -1
	var bv := -1
	for id in ids:
		var u: Dictionary = unita[id]
		if not u["nave"].is_empty():
			continue
		if nave.get("redjac", false):
			if u["nome"] == "Redjac":
				return id
			continue
		var c: Dictionary = Dati.carta_pg(u["nome"])
		var proprietario = Dati.d()["poss"].get(int(nave.get("nr", 0)), {}).get("proprietario", null)
		if proprietario != null and str(proprietario) == u["nome"]:
			return id
		if nave.get("imp", false) and not c.get("cavaliere_imperiale", false) and best >= 0:
			continue
		var nv := int(c.get("navigazione", 0))
		if nv > bv:
			bv = nv
			best = id
	return best if bv > 0 else -1


# =====================================================================================
# SVOLGIMENTO
# =====================================================================================

func gioca() -> void:
	match livello:
		"provincia":
			await av.schiera_provincia()
		"galassia":
			await galattico.prepara_galassia()
		_:
			await schiera()
	while esito == "":
		if livello == "galassia":
			await galattico.stadio_galattico()
			if esito != "":
				break
		for g in (2 if livello == "galassia" else 1):
			giro = g
			for f in [R, I]:
				di_turno = f
				await turno_giocatore(f)
				if esito != "":
					break
			if esito != "":
				break
			await interfase()
			if livello == "galassia" and esito == "" and punti_vittoria()["totale"] >= int(scenario["soglia_pv"]):
				_fine("ribelli", "I Ribelli raggiungono %d Punti Vittoria: la galassia è libera!" % punti_vittoria()["totale"])
			if esito != "":
				break
		if esito != "":
			break
		if turno >= int(scenario["turni"]):
			fine_partita()
			break
		turno += 1
		scrivi("— Turno %d —" % turno)
		cambiato.emit()
	finita.emit(esito)


## Interfase (15.52): i pianeti in ribellione senza truppe imperiali passano sotto controllo ribelle.
func interfase() -> void:
	for pid in scenario_pianeti():
		var p: Dictionary = pianeti[pid]
		if p["stato"] == "ribellione" and mil_su_pianeta(pid, I).is_empty() and p["su"]:
			p["stato"] = "ribelle"
			scrivi("%s è ora sotto Controllo ribelle!" % Dati.pianeta(pid)["nome"])
			evento.emit("controllo_ribelle", {"pid": pid})
			if livello != "sistema":
				await av.domino(pid, "controllo", R)
	controlla_vittoria_istantanea()


func turno_giocatore(f: int) -> void:
	for id in unita:
		var u: Dictionary = unita[id]
		u["mosso"] = false
		if u["k"] == "pg":
			u["truppe"] = false
			u["attivo_turno"] = false
	scrivi("%s: turno %d." % [Dati.FAZIONI[f], turno])
	evento.emit("turno", {"f": f, "turno": turno})
	if f == R:
		_cura_sontag()
	if livello == "sistema":
		fase = "movimento"
		cambiato.emit()
		await movimento(f)
		if esito != "":
			return
		fase = "reazione"
		cambiato.emit()
		await reazione(avversario(f), f)
		fase = "combattimento"
		cambiato.emit()
		await combattimenti_militari(f)
	else:
		await av.operazioni(f)
	controlla_vittoria_istantanea()
	if esito != "":
		return
	if livello == "galassia" and f == R:
		await galattico.rivela_segreti()
	fase = "ricerca"
	cambiato.emit()
	await ricerca_fase(avversario(f), f)
	controlla_vittoria_istantanea()
	if esito != "":
		return
	fase = "missioni"
	cambiato.emit()
	if livello != "sistema":
		await av.riparazioni(f)
	var mis := Missioni.new(self)
	await mis.fase_missioni(f)
	_guarigioni(f)
	if f == I and livello != "galassia":
		_navi_ai_cavalieri()
	aggiorna_controllo()
	controlla_vittoria_istantanea()
	cambiato.emit()


func _cura_sontag() -> void:
	for id in unita.keys():
		if not vivo(id) or unita[id]["k"] != "pg" or unita[id]["fz"] != R or unita[id]["prig"] >= 0:
			continue
		var medico: bool = unita[id]["nome"] == "Doctor Sontag" or unita[id]["poss"].has(46)
		if not medico:
			continue
		for altro in pg_in(unita[id]["luogo"], R, true):
			if unita[altro]["ferite"] > 0:
				unita[altro]["ferite"] = 0
				scrivi("%s cura le ferite di %s." % [unita[id]["nome"], unita[altro]["nome"]])


## 13.71: chi non ha fatto nulla per tutto il turno guarisce.
func _guarigioni(f: int) -> void:
	for id in unita:
		var u: Dictionary = unita[id]
		if u["k"] == "pg" and u["fz"] == f and vivo(id) and u["ferite"] > 0 and not u["attivo_turno"] and u["prig"] < 0:
			u["ferite"] = 0
			scrivi("%s si riposa e guarisce." % u["nome"])


## 14.61: un Cavaliere imperiale su un pianeta imperiale riceve un'astronave se ne mancano.
func _navi_ai_cavalieri() -> void:
	var iniziali: int = scenario["fazioni"][str(I)].get("navi", []).size()
	var in_gioco := 0
	for id in unita:
		if unita[id]["k"] == "pg" and unita[id]["fz"] == I and vivo(id) and not unita[id]["nave"].is_empty():
			in_gioco += 1
	if in_gioco >= iniziali:
		return
	for id in unita:
		var u: Dictionary = unita[id]
		if u["k"] == "pg" and u["fz"] == I and vivo(id) and u["nave"].is_empty() and u["prig"] < 0 and u["luogo"] != "":
			if u["c"].get("cavaliere_imperiale", false) and controllo(pid_di(u["luogo"])) == I:
				u["nave"] = nave_imperiale(false)
				scrivi("%s riceve un'astronave imperiale." % u["nome"])
				return


# =====================================================================================
# MOVIMENTO (9.0)
# =====================================================================================

func movimento(f: int) -> void:
	await _rinforzi(f)
	await _rialza_bdp(f)
	# personaggi che entrano dallo spazio
	var nello_spazio := []
	for id in unita:
		if unita[id]["k"] == "pg" and unita[id]["fz"] == f and unita[id]["luogo"] == "":
			nello_spazio.append(id)
	if not nello_spazio.is_empty():
		await _entra_dallo_spazio(f, nello_spazio)
	while esito == "":
		var opz := _opzioni_movimento(f)
		opz.append({"t": "Fine del movimento", "fine": true})
		var k := await scegli(f, "Movimento: scegli chi muovere.", opz, {"chiave": "movimento", "conferma": true})
		var o: Dictionary = opz[k]
		if o.get("fine", false):
			break
		match o["tipo"]:
			"piedi":
				await _muovi_a_piedi(f, o["id"])
			"nave":
				await _muovi_nave(f, o["id"])
			"truppe":
				await _muovi_truppe(f, o["luogo"])
		cambiato.emit()
	# 9.57: personaggi che restano con le truppe
	for l in luoghi_sistema():
		var mm := mil_in(l, f)
		var pp := pg_in(l, f, true)
		if mm.is_empty() or pp.is_empty():
			continue
		var opz2 := []
		for id in pp:
			opz2.append({"t": unita[id]["nome"], "id": id})
		var sel := await scegli_multi(f, "%s: quali personaggi restano con le truppe? (non faranno missioni, ma non possono essere cercati)" % nome_luogo(l), opz2, {"chiave": "con_truppe", "luogo": l})
		for i in sel:
			unita[pp[i]]["truppe"] = true


func _opzioni_movimento(f: int) -> Array:
	var opz := []
	var truppe_luoghi := {}
	for id in unita:
		var u: Dictionary = unita[id]
		if u["fz"] != f or u["mosso"] or u["luogo"] == "" or u["luogo"] == "morto":
			continue
		if u["k"] == "mil":
			truppe_luoghi[u["luogo"]] = true
		elif u["prig"] < 0:
			if not u["nave"].is_empty() and val(id, "navigazione") > 0:
				opz.append({"t": "%s pilota %s" % [u["nome"], u["nave"]["nome"]], "tipo": "nave", "id": id})
			if Dati.pianeta(pid_di(u["luogo"]))["ambienti"].size() > 1:
				opz.append({"t": "%s si sposta a piedi" % u["nome"], "tipo": "piedi", "id": id})
	for l in truppe_luoghi:
		opz.append({"t": "Truppe in %s" % nome_luogo(l), "tipo": "truppe", "luogo": l})
	return opz


func _muovi_a_piedi(f: int, id: int) -> void:
	var u: Dictionary = unita[id]
	var pid := pid_di(u["luogo"])
	var dest := []
	for i in Dati.pianeta(pid)["ambienti"].size():
		var l := "%d:%d" % [pid, i]
		if l != u["luogo"]:
			dest.append({"t": nome_luogo(l), "luogo": l})
	if dest.is_empty():
		return
	var k := await scegli(f, "Dove va %s?" % u["nome"], dest, {"chiave": "dest", "id": id})
	_sposta_pg(id, dest[k]["luogo"])
	u["mosso"] = true
	u["attivo_turno"] = true
	# 9.35: chi si sposta a piedi non è più individuato (salvo altri individuati nel nuovo ambiente)
	if u["ind"]:
		var altri_ind := false
		for o in pg_in(u["luogo"], f):
			if o != id and unita[o]["ind"]:
				altri_ind = true
		if not altri_ind:
			u["ind"] = false
	scrivi("%s si sposta in %s." % [u["nome"], nome_luogo(u["luogo"])])


func _sposta_pg(id: int, luogo: String) -> void:
	unita[id]["luogo"] = luogo
	# prigionieri custoditi seguono il custode
	for o in unita:
		if unita[o]["k"] == "pg" and unita[o]["prig"] == id:
			unita[o]["luogo"] = luogo


func _muovi_nave(f: int, pilota: int) -> void:
	var u: Dictionary = unita[pilota]
	var nave: Dictionary = u["nave"]
	var da: String = u["luogo"]
	var dest := []
	for l in luoghi_sistema():
		if l != da:
			dest.append({"t": nome_luogo(l), "luogo": l})
	var k := await scegli(f, "Dove vola %s?" % nave["nome"], dest, {"chiave": "dest_nave", "id": pilota})
	var a: String = dest[k]["luogo"]
	# passeggeri (9.56)
	var cand := []
	for o in pg_in(da, f, true):
		if o != pilota and not unita[o]["mosso"]:
			cand.append(o)
	var posti := int(nave["pas"]) - 1 - _compagni(pilota)
	var passeggeri := []
	if not cand.is_empty() and posti > 0:
		var opz := []
		for o in cand:
			opz.append({"t": unita[o]["nome"], "id": o})
		var sel := await scegli_multi(f, "Chi sale a bordo? (posti liberi: %d)" % posti, opz, {"chiave": "passeggeri", "max": posti})
		for i in sel:
			if passeggeri.size() + _compagni(cand[i]) < posti:
				passeggeri.append(cand[i])
	var gruppo := [pilota] + passeggeri
	for id in gruppo:
		unita[id]["mosso"] = true
		unita[id]["attivo_turno"] = id == pilota or unita[id]["attivo_turno"]
	scrivi("%s vola da %s a %s con %d a bordo." % [nave["nome"], nome_luogo(da), nome_luogo(a), gruppo.size()])
	var pda := pid_di(da)
	var pa := pid_di(a)
	if pda == pa:
		if not await _rilevamento(f, pilota, gruppo, pda):
			return
	else:
		if not await _rilevamento(f, pilota, gruppo, pda):
			return
		if not await _rilevamento(f, pilota, gruppo, pa):
			return
	for id in gruppo:
		_sposta_pg(id, a)
	if nave.get("distrutta_arrivo", false):
		u["nave"] = {}
		scrivi("L'astronave danneggiata è perduta all'arrivo.")
		if nave["nr"] > 0:
			mazzo_poss.append(int(nave["nr"]))
	evento.emit("volo", {"da": da, "a": a, "f": f})


func _compagni(id: int) -> int:
	var n := 0
	for nr in unita[id]["poss"]:
		if Dati.d()["poss"].get(int(nr), {}).get("tipo", "") == "compagno":
			n += 1
	return n


func valore_evasione(pilota: int) -> int:
	var nave: Dictionary = unita[pilota]["nave"]
	var nav := val(pilota, "navigazione")
	var man := int(nave["man"])
	if int(nave.get("nr", 0)) == 40:   # S-XIII (14.58)
		nav = mini(nav, man + 1)
		return nav + man
	if nav > man + 1:
		nav = man + 1
	if man > nav + 1:
		man = nav + 1
	return nav + man


## Routine di rilevamento (9.3). Restituisce false se l'astronave e tutti a bordo sono eliminati.
func _rilevamento(f: int, pilota: int, gruppo: Array, pid: int) -> bool:
	var liv := bdp_attiva(pid, f)
	if liv < 0:
		return true
	var ev := valore_evasione(pilota)
	var col := 7
	var limiti := [0, 1, 2, 3, 4, 6, 8]
	for i in limiti.size():
		if ev <= limiti[i]:
			col = i
			break
	if liv == 2:
		col -= 2
	if unita[pilota]["ind"]:
		col -= 1
	col = maxi(col, 0)
	var d := dado()
	var ris: String = Dati.d()["tabelle"]["rilevamento"]["righe_dado"][d - 1][col]
	ris = ris.replace("*", "")
	if liv == 0 and (ris == "Dd" or ris == "E"):
		ris = "D"
	var nave: Dictionary = unita[pilota]["nave"]
	if ris == "Dd" and nave.get("dmg", false):
		ris = "E"
	var nomi := {"U": "non individuata", "D": "individuata", "Dd": "individuata e danneggiata", "E": "distrutta"}
	scrivi("BDP di %s (livello %d): dado %d, valore di evasione %d » %s." % [Dati.pianeta(pid)["nome"], liv, d, ev, nomi[ris]])
	evento.emit("rilevamento", {"pid": pid, "dado": d, "esito": ris, "f": f})
	await attesa(0.6)
	match ris:
		"U":
			for id in gruppo:
				unita[id]["ind"] = false
		"D":
			for id in gruppo:
				unita[id]["ind"] = true
		"Dd":
			for id in gruppo:
				unita[id]["ind"] = true
			nave["dmg"] = true
			nave["distrutta_arrivo"] = true
		"E":
			for id in gruppo:
				uccidi(id, "abbattuto con l'astronave")
			return false
	return true


func _entra_dallo_spazio(f: int, ids: Array) -> void:
	var opz := []
	for l in luoghi_sistema():
		opz.append({"t": nome_luogo(l), "luogo": l})
	var k := await scegli(f, "I tuoi personaggi arrivano dallo spazio: in quale ambiente atterrano?", opz, {"chiave": "dallo_spazio"})
	var a: String = opz[k]["luogo"]
	var pilota := -1
	for id in ids:
		if not unita[id]["nave"].is_empty():
			pilota = id
	for id in ids:
		unita[id]["mosso"] = true
	if pilota >= 0:
		if not await _rilevamento(f, pilota, ids, pid_di(a)):
			return
	for id in ids:
		_sposta_pg(id, a)
	scrivi("%s arrivano in %s." % [Dati.FAZIONI[f], nome_luogo(a)])


func _muovi_truppe(f: int, da: String) -> void:
	var mm := []
	for id in mil_in(da, f):
		if not unita[id]["mosso"]:
			mm.append(id)
	if mm.is_empty():
		return
	var opz := []
	for id in mm:
		opz.append({"t": descr_mil(id), "id": id})
	var sel := await scegli_multi(f, "Quali truppe muovi da %s?" % nome_luogo(da), opz, {"chiave": "truppe_sel", "min": 1})
	if sel.is_empty():
		return
	var gruppo := []
	var tutte_mobili := true
	for i in sel:
		gruppo.append(mm[i])
		if not unita[mm[i]]["mobile"]:
			tutte_mobili = false
	var pid := pid_di(da)
	var dest := []
	for l in luoghi_sistema():
		if l == da:
			continue
		if not tutte_mobili and pid_di(l) != pid:
			continue
		var occ := mil_in(l, f).size()
		if occ + gruppo.size() > taglia(l):
			continue
		dest.append({"t": "%s (%d/%d)" % [nome_luogo(l), occ, taglia(l)], "luogo": l})
	if dest.is_empty():
		scrivi("Nessuna destinazione con spazio per queste truppe.")
		return
	var k := await scegli(f, "Dove vanno le truppe?", dest, {"chiave": "dest_truppe"})
	var a: String = dest[k]["luogo"]
	# personaggi che accompagnano le truppe
	var accomp := []
	var pp := []
	for o in pg_in(da, f, true):
		if not unita[o]["mosso"]:
			pp.append(o)
	if not pp.is_empty():
		var opz2 := []
		for o in pp:
			opz2.append({"t": unita[o]["nome"], "id": o})
		var s2 := await scegli_multi(f, "Quali personaggi viaggiano con le truppe?", opz2, {"chiave": "accompagna"})
		for i in s2:
			accomp.append(pp[i])
	for id in gruppo + accomp:
		unita[id]["mosso"] = true
	for id in accomp:
		unita[id]["ind"] = true
	if pid_di(a) != pid:
		await _attacco_bdp(f, gruppo, pid)
		gruppo = gruppo.filter(func(x): return vivo(x))
		if not gruppo.is_empty():
			await _attacco_bdp(f, gruppo, pid_di(a))
			gruppo = gruppo.filter(func(x): return vivo(x))
	for id in gruppo:
		unita[id]["luogo"] = a
	if gruppo.is_empty():
		# truppe distrutte: i personaggi che le accompagnavano restano dove erano (non raggiungono la meta)
		scrivi("Le truppe sono state distrutte durante il movimento.")
		return
	for id in accomp:
		_sposta_pg(id, a)
	scrivi("%s: truppe da %s a %s." % [Dati.FAZIONI[f], nome_luogo(da), nome_luogo(a)])
	evento.emit("volo_truppe", {"da": da, "a": a, "f": f})


## 9.2: il BDP nemico attacca le truppe che lasciano o raggiungono il pianeta.
func _attacco_bdp(f: int, gruppo: Array, pid: int) -> void:
	var liv := bdp_attiva(pid, f)
	if liv < 1:
		return
	var col := 7 if liv == 2 else 5   # 3-1 oppure 1-1
	var tab: Array = Dati.d()["tabelle"]["combattimento_militare"]["righe_dado"]
	var d1 := dado()
	var d2 := dado()
	var perdita_dif: int = tab[d1 - 1][col][1]
	var perdita_bdp: int = tab[d2 - 1][col][0]
	scrivi("Il BDP di %s spara sulle truppe: dadi %d/%d, perdite %d alle truppe, %d al BDP." % [Dati.pianeta(pid)["nome"], d1, d2, perdita_dif, perdita_bdp])
	evento.emit("bdp_spara", {"pid": pid})
	await attesa(0.6)
	_applica_perdite(gruppo, perdita_dif)
	var p: Dictionary = pianeti[pid]
	if perdita_bdp >= 2:
		p["su"] = false
		scrivi("Il BDP di %s è messo fuori uso." % Dati.pianeta(pid)["nome"])
	if perdita_bdp >= 3 and p["bdp"] > 0:
		p["bdp"] -= 1


## Elimina le unità per soddisfare la perdita il più possibile senza superarla (10.3).
func _applica_perdite(ids: Array, perdita: int) -> void:
	if perdita <= 0 or ids.is_empty():
		return
	var n := ids.size()
	var best_mask := 0
	var best := -1
	var best_val := 99999
	for mask in range(1, 1 << n):
		var s := 0
		var valore := 0
		for i in n:
			if mask & (1 << i):
				var u: Dictionary = unita[ids[i]]
				s += int(u["forza"])
				valore += (3 if u["mobile"] else 1)
		if s > perdita:
			continue
		if s > best or (s == best and valore < best_val):
			best = s
			best_mask = mask
			best_val = valore
	for i in n:
		if best_mask & (1 << i):
			scrivi("Eliminata: %s (%s)." % [descr_mil(ids[i]), Dati.FAZIONI[unita[ids[i]]["fz"]]])
			unita[ids[i]]["luogo"] = "morto"


func _rinforzi(f: int) -> void:
	if f != I:
		return
	var n := 0
	var tipo := "linea"
	if scenario_id == "egrix":
		n = rinforzi_attesi
		rinforzi_attesi = 0
	elif scenario_id == "varu" and turno in [2, 4, 6]:
		n = 1
	if n <= 0:
		return
	for k in n:
		if scenario_id == "varu" and turno % 2 == 0 and _bdp_da_rialzare(I).size() > 0:
			var sc := await scegli(I, "Rinforzo: una Linea, oppure rialzi un BDP e ricevi una Pattuglia?", [{"t": "Ricevo una Linea"}, {"t": "Rialzo un BDP e ricevo una Pattuglia"}], {"chiave": "rinforzo_varu"})
			if sc == 1:
				tipo = "pattuglia"
				await _rialza_bdp(I, true)
		var id := nuova_mil(I, tipo, 3 if tipo == "linea" else 1, "", true)
		var possibili := []
		for l in luoghi_sistema():
			var pid := pid_di(l)
			var c := controllo(pid)
			if (c == I or (c == R and mil_in(l, R).is_empty())) and mil_in(l, I).size() < taglia(l):
				possibili.append(l)
		if possibili.is_empty():
			unita.erase(id)
			scrivi("Nessun ambiente valido: il rinforzo imperiale è perduto.")
			continue
		var opz := []
		for l in possibili:
			opz.append({"t": nome_luogo(l), "luogo": l})
		var k2 := await scegli(I, "Rinforzo: dove schieri %s?" % descr_mil(id), opz, {"chiave": "rinforzo"})
		unita[id]["luogo"] = possibili[k2]
		scrivi("L'Impero riceve un rinforzo: %s in %s." % [descr_mil(id), nome_luogo(possibili[k2])])


var _bdp_rialzato_turno := -1


func _bdp_da_rialzare(f: int) -> Array:
	var out := []
	for pid in pianeti:
		if not pianeti[pid]["su"]:
			var c := controllo(pid)
			if c == f or (c == -1 and f == R and pianeti[pid]["stato"] == "ribellione" and mil_su_pianeta(pid, I).is_empty()):
				out.append(pid)
	return out


## 16.16: nei turni dispari i Ribelli, nei pari l'Impero, possono rialzare un BDP.
func _rialza_bdp(f: int, forzato := false) -> void:
	if _bdp_rialzato_turno == turno * 2 + f:
		return
	if not forzato and ((f == R and turno % 2 == 0) or (f == I and turno % 2 == 1)):
		return
	if not forzato and scenario_id == "varu" and f == I:
		return   # in Varu l'Impero lo fa scegliendo la Pattuglia al posto della Linea (16.34)
	var cand := _bdp_da_rialzare(f)
	if cand.is_empty():
		return
	var opz := [{"t": "Nessuno"}]
	for pid in cand:
		opz.append({"t": "Rialza il BDP di %s" % Dati.pianeta(pid)["nome"], "pid": pid})
	var k := 1 if forzato else await scegli(f, "Puoi rimettere in funzione un BDP.", opz, {"chiave": "rialza_bdp", "conferma": true})
	if forzato and opz.size() > 2:
		k = await scegli(f, "Quale BDP rialzi?", opz.slice(1), {"chiave": "rialza_bdp"}) + 1
	if k > 0:
		pianeti[opz[k]["pid"]]["su"] = true
		_bdp_rialzato_turno = turno * 2 + f
		scrivi("Il BDP di %s torna in funzione." % Dati.pianeta(opz[k]["pid"])["nome"])


# =====================================================================================
# REAZIONE (9.6)
# =====================================================================================

func reazione(f: int, nemico: int) -> void:
	var bersagli := []
	for l in luoghi_sistema():
		var ha := not mil_in(l, nemico).is_empty()
		if not ha:
			for id in pg_in(l, nemico, true):
				if unita[id]["ind"]:
					ha = true
		if ha:
			bersagli.append(l)
	for l in bersagli:
		var pid := pid_di(l)
		var opz := [{"t": "Nessuna reazione"}]
		for id in unita:
			var u: Dictionary = unita[id]
			if u["fz"] != f or u["luogo"] == "" or u["luogo"] == "morto" or u["luogo"] == l or pid_di(u["luogo"]) != pid:
				continue
			if u.get("atrocita", false) or u.get("interc", false) or str(u["luogo"]).begins_with("D") or str(u["luogo"]).begins_with("S:"):
				continue
			if u["k"] == "pg" and (u.get("sovrano", false) or (is_orbita(u["luogo"]) and u["nave"].is_empty() and mil_in(u["luogo"], f).is_empty())):
				continue
			if u["k"] == "pg":
				if u["prig"] < 0 and not u["truppe"]:
					opz.append({"t": "%s (da %s)" % [u["nome"], nome_luogo(u["luogo"])], "id": id})
			elif mil_in(l, f).size() < taglia(l):
				opz.append({"t": "%s (da %s)" % [descr_mil(id), nome_luogo(u["luogo"])], "id": id})
				for capo in pg_in(u["luogo"], f, true):
					if comando(capo) >= 1:
						opz.append({"t": "%s con %s come comandante" % [descr_mil(id), unita[capo]["nome"]], "id": id, "capo": capo})
		if opz.size() == 1:
			continue
		var k := await scegli(f, "Reazione verso %s: chi muovi?" % nome_luogo(l), opz, {"chiave": "reazione", "luogo": l, "conferma": true})
		if k == 0:
			continue
		var o: Dictionary = opz[k]
		var u2: Dictionary = unita[o["id"]]
		if u2["k"] == "pg":
			_sposta_pg(o["id"], l)
		else:
			u2["luogo"] = l
			if o.has("capo"):
				_sposta_pg(o["capo"], l)
				unita[o["capo"]]["truppe"] = true
		scrivi("Reazione %s: %s in %s." % [Dati.FAZIONI[f], o["t"].get_slice(" (", 0), nome_luogo(l)])
		cambiato.emit()


# =====================================================================================
# COMBATTIMENTO MILITARE (10.0)
# =====================================================================================

func combattimenti_militari(f: int) -> void:
	for l in luoghi_sistema():
		if mil_in(l, R).is_empty() or mil_in(l, I).is_empty():
			continue
		var att := -1
		var k := await scegli(f, "Truppe nemiche in %s: dichiari battaglia?" % nome_luogo(l), [{"t": "Sì, attacco"}, {"t": "No"}], {"chiave": "dichiara_battaglia", "luogo": l, "conferma": true})
		if k == 0:
			att = f
		else:
			var k2 := await scegli(avversario(f), "Truppe nemiche in %s: dichiari battaglia?" % nome_luogo(l), [{"t": "Sì, attacco"}, {"t": "No"}], {"chiave": "dichiara_battaglia", "luogo": l, "conferma": true})
			if k2 == 0:
				att = avversario(f)
		if att >= 0:
			await battaglia(l, att)


func _scegli_capo(f: int, l: String) -> int:
	var cand := []
	for id in pg_in(l, f, true):
		if comando(id) >= 1:
			cand.append(id)
	if cand.is_empty():
		return -1
	var opz := [{"t": "Nessun comandante"}]
	for id in cand:
		opz.append({"t": "%s (comando %d)" % [unita[id]["nome"], comando(id)], "id": id})
	var k := await scegli(f, "Chi comanda le tue truppe in %s?" % nome_luogo(l), opz, {"chiave": "capo", "luogo": l, "conferma": true})
	if k == 0:
		return -1
	unita[opz[k]["id"]]["truppe"] = true
	unita[opz[k]["id"]]["attivo_turno"] = true
	return opz[k]["id"]


func battaglia(l: String, att: int, ribellione := false) -> void:
	var dif := avversario(att)
	var capo_a := await _scegli_capo(att, l)
	var capo_d := await _scegli_capo(dif, l)
	var ma := mil_in(l, att)
	var md := mil_in(l, dif)
	for id in ma + md:
		unita[id]["scoperta"] = true
	var fa := forza_mil(ma)
	var fd := forza_mil(md)
	var col := 5
	if fa >= fd:
		col = 5 + mini(int(fa / max(fd, 1)), 5) - 1
	else:
		col = 5 - (mini(int(ceil(float(fd) / max(fa, 1))), 5) - 1)
	var spost := 0   # positivo = a favore dell'attaccante
	var ca := (comando(capo_a) + bonus_reale(capo_a, l)) if capo_a >= 0 else 0
	var cd := (comando(capo_d) + bonus_reale(capo_d, l)) if capo_d >= 0 else 0
	if ribellione and capo_a < 0:
		ca = 1
	spost += ca - cd
	var segno_rib := 1 if att == R else -1
	var tipo := tipo_amb(l)
	for id in mil_in(l, R):
		if unita[id]["amb"] == tipo:
			spost += segno_rib
			break
	var capo_imp := capo_a if att == I else capo_d
	var elite_imp := mil_in(l, I).any(func(x): return unita[x].get("elite", false))
	if tipo in Dati.SPECIALI and capo_imp < 0 and not elite_imp:
		spost += segno_rib
	if livello == "galassia":
		spost += galattico.spostamento_vivo(pid_di(l), att)
	col = clampi(col + spost, 0, 10)
	var tab: Array = Dati.d()["tabelle"]["combattimento_militare"]["righe_dado"]
	var da := dado()
	var dd := dado()
	var perd_d: int = tab[da - 1][col][1]
	var perd_a: int = tab[dd - 1][col][0]
	var cols: Array = Dati.d()["tabelle"]["combattimento_militare"]["colonne"]
	scrivi("Battaglia in %s: %s %d contro %s %d, colonna %s; dadi %d/%d » perdite %d all'attaccante, %d al difensore." % [nome_luogo(l), Dati.FAZIONI[att], fa, Dati.FAZIONI[dif], fd, cols[col], da, dd, perd_a, perd_d])
	evento.emit("battaglia", {"luogo": l, "att": att, "col": cols[col], "dadi": [da, dd], "perdite": [perd_a, perd_d]})
	await attesa(1.0)
	_applica_perdite(ma, perd_a)
	_applica_perdite(md, perd_d)
	for id in ma + md:
		if vivo(id):
			unita[id]["scoperta"] = false
	# 10.6: se una parte è annientata, i suoi personaggi con le truppe sono attaccati da una squadra
	for coppia in [[att, dif], [dif, att]]:
		var perdente: int = coppia[0]
		var vincitore: int = coppia[1]
		if mil_in(l, perdente).is_empty():
			var con_truppe := []
			for id in pg_in(l, perdente, true):
				if unita[id]["truppe"]:
					con_truppe.append(id)
			var sopravvissute := mil_in(l, vincitore)
			if not con_truppe.is_empty() and not sopravvissute.is_empty():
				for id in con_truppe:
					unita[id]["truppe"] = false
				var cb := Combattimento.new(self)
				await cb.squadra_contro(vincitore, sopravvissute, con_truppe, l)
	_controlla_navi_orfane()
	aggiorna_controllo()
	cambiato.emit()


# =====================================================================================
# RICERCA (11.0)
# =====================================================================================

func ricerca_fase(f: int, nemico: int) -> void:
	for l in luoghi_sistema():
		await ricerca_in(f, nemico, l, [])


## Ricerca in un ambiente. `bersagli` vuoto = tutti i personaggi nemici individuati non con le truppe.
## Restituisce true se ha trovato e attaccato qualcuno.
func ricerca_in(f: int, nemico: int, l: String, bersagli: Array, da_evento := false) -> bool:
	var nascosti := bersagli.duplicate()
	if nascosti.is_empty():
		for id in pg_in(l, nemico, true):
			if unita[id]["ind"] and not unita[id]["truppe"]:
				nascosti.append(id)
	nascosti = nascosti.filter(func(x): return vivo(x) and unita[x]["luogo"] == l)
	if nascosti.is_empty():
		return false
	var mm := mil_in(l, f)
	var pp := []
	for id in pg_in(l, f, true):
		if not unita[id]["truppe"]:
			pp.append(id)
	var con_truppe_pg := []
	for id in pg_in(l, f, true):
		if unita[id]["truppe"]:
			con_truppe_pg.append(id)
	if mm.is_empty() and pp.is_empty():
		return false
	var opz := [{"t": "Nessuna ricerca"}]
	if not mm.is_empty():
		opz.append({"t": "Ricerca con le truppe (%d punti forza)" % forza_mil(mm), "modo": "truppe"})
	if not pp.is_empty():
		var intel := 0
		for id in pp:
			intel += val(id, "intelligenza")
		opz.append({"t": "Ricerca con i personaggi (Intelligenza %d; si fanno individuare)" % intel, "modo": "pg"})
	if not mm.is_empty() and not pp.is_empty():
		opz.append({"t": "Entrambe, separatamente", "modo": "entrambe"})
	var k := await scegli(f, "%s: personaggi nemici individuati. Li cerchi?" % nome_luogo(l), opz, {"chiave": "ricerca", "luogo": l, "conferma": true})
	if k == 0:
		return false
	var modo: String = opz[k]["modo"]
	var trovato := false
	# valore di occultamento: Intelligenza di uno + taglia - numero di nascosti (+2 con Bridne Murcada)
	var occ := 0
	for id in nascosti:
		occ = maxi(occ, val(id, "intelligenza"))
	occ += taglia(l) - nascosti.size()
	for id in nascosti:
		occ += int(Dati.d()["possessi_effetti"].get("pg_" + unita[id]["nome"], {}).get("occultamento", 0))
		for nr in unita[id]["poss"]:
			occ += int(Dati.d()["possessi_effetti"].get(str(nr), {}).get("occultamento", 0))
	var gruppi := []
	if modo in ["truppe", "entrambe"]:
		var capo := -1
		for id in con_truppe_pg:
			if comando(id) > comando(capo) if capo >= 0 else comando(id) > 0:
				capo = id
		var v := forza_mil(mm) + (comando(capo) if capo >= 0 else 0)
		gruppi.append({"modo": "truppe", "v": v, "capo": capo})
	if modo in ["pg", "entrambe"]:
		var v2 := 0
		for id in pp:
			v2 += val(id, "intelligenza")
			unita[id]["ind"] = true
		gruppi.append({"modo": "pg", "v": v2})
	for g in gruppi:
		var esito_r := _tira_ricerca(g["v"], occ)
		scrivi("Ricerca %s in %s: valore %d contro occultamento %d » %s." % ["con le truppe" if g["modo"] == "truppe" else "con i personaggi", nome_luogo(l), g["v"], occ, "TROVATI" if esito_r else "nessuno trovato"])
		evento.emit("ricerca", {"luogo": l, "trovati": esito_r})
		await attesa(0.6)
		if not esito_r:
			continue
		nascosti = nascosti.filter(func(x): return vivo(x) and unita[x]["luogo"] == l and unita[x]["prig"] < 0)
		if nascosti.is_empty():
			break
		var ka := await scegli(f, "Hai trovato %s. Attacchi?" % ", ".join(nascosti.map(func(x): return unita[x]["nome"])), [{"t": "Attacco per uccidere"}, {"t": "Attacco per catturare"}, {"t": "Non attacco"}], {"chiave": "attacca_trovati", "conferma": true, "luogo": l})
		if ka == 2:
			continue
		trovato = true
		var cb := Combattimento.new(self)
		if g["modo"] == "truppe":
			await cb.squadra_contro(f, mil_in(l, f), nascosti, l, ka == 1, g.get("capo", -1) >= 0)
		else:
			await cb.personaggi_contro(f, pp, nascosti, l, ka == 1)
	return trovato


func _tira_ricerca(v: int, occ: int) -> bool:
	var cols := [1, 3, 6, 9, 13, 17, 22]
	var c := 7
	for i in cols.size():
		if v <= cols[i]:
			c = i
			break
	var r := 4
	if occ <= 1:
		r = 0
	elif occ <= 3:
		r = 1
	elif occ <= 5:
		r = 2
	elif occ <= 7:
		r = 3
	var x = Dati.d()["tabelle"]["ricerca"]["tabella"][r][c]
	if str(x) == "T":
		return true
	if int(x) == 0:
		return false
	return dado() <= int(x)


# =====================================================================================
# MORTE, CATTURA, NAVI
# =====================================================================================

func uccidi(id: int, motivo := "") -> void:
	var u: Dictionary = unita[id]
	if u["luogo"] == "morto":
		return
	u["morto_in"] = u["luogo"]
	u["luogo"] = "morto"
	u["prig"] = -1
	scrivi("%s è morto%s." % [u["nome"], (" (" + motivo + ")") if motivo != "" else ""])
	evento.emit("morte", {"id": id})
	# 14.55: l'astronave può passare a un compagno nello stesso ambiente
	if not u["nave"].is_empty():
		var l: String = u["morto_in"]
		var eredi := pg_in(l, u["fz"], true).filter(func(x): return unita[x]["nave"].is_empty() and not u["nave"].get("redjac", false))
		if not eredi.is_empty() and motivo != "abbattuto con l'astronave":
			unita[eredi[0]]["nave"] = u["nave"]
			scrivi("%s prende il comando di %s." % [unita[eredi[0]]["nome"], u["nave"]["nome"]])
		elif u["nave"]["nr"] > 0 and motivo != "abbattuto con l'astronave":
			mazzo_poss.append(int(u["nave"]["nr"]))
		u["nave"] = {}
	u["poss"] = []
	# i suoi prigionieri sono liberi
	for o in unita:
		if unita[o]["k"] == "pg" and unita[o]["prig"] == id:
			unita[o]["prig"] = -1
			scrivi("%s è di nuovo libero." % unita[o]["nome"])


func cattura(id: int, custode: int) -> void:
	var u: Dictionary = unita[id]
	u["prig"] = custode
	u["ind"] = true
	u["truppe"] = false
	scrivi("%s è stato catturato!" % u["nome"])
	evento.emit("cattura", {"id": id})
	if not u["nave"].is_empty():
		var l: String = u["luogo"]
		var eredi := pg_in(l, u["fz"], true).filter(func(x): return unita[x]["nave"].is_empty() and x != id)
		if not eredi.is_empty():
			unita[eredi[0]]["nave"] = u["nave"]
		elif u["nave"]["nr"] > 0:
			mazzo_poss.append(int(u["nave"]["nr"]))
		u["nave"] = {}


## Custode di un prigioniero: un personaggio o, se assente, un'unità militare nemica nell'ambiente.
func custode_in(l: String, f: int) -> int:
	var pp := pg_in(l, f, true)
	if not pp.is_empty():
		return pp[0]
	var mm := mil_in(l, f)
	if not mm.is_empty():
		return mm[0]
	return -1


func _controlla_navi_orfane() -> void:
	# prigionieri senza custodi nemici nell'ambiente tornano liberi (12.82)
	for id in unita:
		var u: Dictionary = unita[id]
		if u["k"] != "pg" or u["prig"] < 0 or u["luogo"] == "morto":
			continue
		var c: int = u["prig"]
		if not vivo(c) or unita[c]["luogo"] != u["luogo"]:
			var nuovo := custode_in(u["luogo"], avversario(u["fz"]))
			if nuovo < 0:
				u["prig"] = -1
				scrivi("%s non è più sorvegliato ed è libero." % u["nome"])
			else:
				u["prig"] = nuovo


# =====================================================================================
# RIBELLIONE (15.0)
# =====================================================================================

func sposta_lealta(pid: int, passi: int, verso: int, _domino := true) -> int:
	## verso: R = verso Agitazione, I = verso Patriottico. Restituisce i passi effettivi.
	var p: Dictionary = pianeti[pid]
	if p["stato"] in ["ribellione", "ribelle"] or p.get("distrutto", false):
		return 0
	if livello == "galassia" and galattico.lealta_bloccata(pid):
		return 0
	var prima: int = p["lealta"]
	var dir := 1 if verso == R else -1
	p["lealta"] = clampi(prima + dir * passi, 0, 4)
	var eff := absi(p["lealta"] - prima)
	if eff > 0:
		scrivi("Lealtà di %s: %s » %s." % [Dati.pianeta(pid)["nome"], Dati.LEALTA_NOMI[prima], Dati.LEALTA_NOMI[p["lealta"]]])
		evento.emit("lealta", {"pid": pid})
	return eff


## Avvia la ribellione (15.2-15.4) e crea le truppe ribelli.
func avvia_ribellione(pid: int, raddoppio: Dictionary) -> void:
	var p: Dictionary = pianeti[pid]
	var era_fermata: bool = p["stato"] == "fermata"
	p["stato"] = "ribellione"
	scrivi("%s insorge: RIBELLIONE!" % Dati.pianeta(pid)["nome"])
	evento.emit("ribellione", {"pid": pid})
	if scenario_id == "egrix":
		rinforzi_attesi += 1
	var amb: Array = Dati.pianeta(pid)["ambienti"]
	if livello == "galassia" and not era_fermata:
		var totale := 0
		for i in amb.size():
			totale += int(amb[i].get("risorse", 0))
		galattico.entrate_ribellione(pid, totale)
	for i in amb.size():
		var l := "%d:%d" % [pid, i]
		var punti := int(amb[i].get("risorse", 0))
		if raddoppio.has(l):
			punti *= 2
		elif era_fermata:
			punti = 0
		if punti <= 0:
			continue
		var tipo: String = amb[i]["tipo"]
		var nuove := []
		var spazio: int = taglia(l) - mil_in(l, R).size()
		if livello != "sistema":
			nuove = await av.compra_ribelli(l, punti, bool(amb[i].get("risorse_stella", false)))
			punti = 0
		while punti > 0 and spazio > 0:
			# acquisto: 2-1 per 3 punti, 1-0 per 1 punto; la scelta la fa il giocatore ribelle
			var opz := []
			if punti >= 3:
				opz.append({"t": "Unità %s 2-1 (3 punti)" % Dati.AMBIENTI_NOMI[tipo], "forza": 2})
			opz.append({"t": "Unità %s 1-0 (1 punto)" % Dati.AMBIENTI_NOMI[tipo], "forza": 1})
			opz.append({"t": "Basta così"})
			var k := await scegli(R, "%s: %d Punti Forza da spendere (spazio per %d unità)." % [nome_luogo(l), punti, spazio], opz, {"chiave": "acquisto_ribelle", "punti": punti})
			if not opz[k].has("forza"):
				break
			var fz: int = opz[k]["forza"]
			var id := nuova_mil(R, "rib", fz, tipo, fz == 2)
			unita[id]["luogo"] = l
			nuove.append(id)
			punti -= 3 if fz == 2 else 1
			spazio -= 1
		if not nuove.is_empty():
			scrivi("%d truppe ribelli compaiono in %s." % [nuove.size(), nome_luogo(l)])
			cambiato.emit()
			if not mil_in(l, I).is_empty():
				var k2 := await scegli(R, "Le nuove truppe attaccano subito gli Imperiali in %s?" % nome_luogo(l), [{"t": "Sì, all'attacco"}, {"t": "No"}], {"chiave": "attacco_ribellione", "conferma": true})
				if k2 == 0:
					await battaglia(l, R, true)
	if livello != "sistema" and not era_fermata:
		await av.domino(pid, "ribellione", R)
	cambiato.emit()


# =====================================================================================
# VITTORIA (16.17)
# =====================================================================================

func punti_vittoria() -> Dictionary:
	if livello == "galassia":
		return galattico.punti_vittoria()
	var pv: Dictionary = Dati.d()["tabelle"]["punti_vittoria_star_system"]
	if livello == "provincia":
		pv = Dati.d()["regole_avanzate"]["pv_provincia"]
	var tot := 0
	var dett := []
	for pid in scenario_pianeti():
		var p: Dictionary = pianeti[pid]
		var nome: String = Dati.pianeta(pid)["nome"]
		if p["stato"] == "ribelle":
			tot += int(pv["pianeta_controllo_ribelle"])
			dett.append("%s sotto controllo ribelle: +%d" % [nome, pv["pianeta_controllo_ribelle"]])
		elif p["stato"] == "ribellione":
			tot += int(pv["pianeta_in_ribellione"])
			dett.append("%s in ribellione: +%d" % [nome, pv["pianeta_in_ribellione"]])
		elif p["lealta"] == 4:
			tot += int(pv["pianeta_in_agitazione"])
			dett.append("%s in agitazione: +%d" % [nome, pv["pianeta_in_agitazione"]])
		elif p["lealta"] == 0:
			tot += int(pv["pianeta_patriottico"])
			dett.append("%s patriottico: %d" % [nome, pv["pianeta_patriottico"]])
	for id in unita:
		var u: Dictionary = unita[id]
		if u["k"] != "pg":
			continue
		if u["luogo"] == "morto":
			var v := int(pv["imperiale_ucciso"] if u["fz"] == I else pv["ribelle_ucciso"])
			tot += v
			dett.append("%s ucciso: %+d" % [u["nome"], v])
		elif u["prig"] >= 0:
			var v2 := int(pv["imperiale_catturato"] if u["fz"] == I else pv["ribelle_catturato"])
			tot += v2
			dett.append("%s catturato: %+d" % [u["nome"], v2])
	if vittoria_info[R]:
		tot += 1
		dett.append("Raccogli informazioni (Ribelli): +1")
	if vittoria_info[I]:
		tot -= 1
		dett.append("Raccogli informazioni (Impero): -1")
	return {"totale": tot, "dettaglio": dett, "soglia": int(scenario["soglia_pv"])}


func controlla_vittoria_istantanea() -> void:
	if esito != "":
		return
	var ribelli_vivi := 0
	var ribelli_persi := 0
	for id in unita:
		var u: Dictionary = unita[id]
		if u["k"] == "pg" and u["fz"] == R:
			if u["luogo"] == "morto" or u["prig"] >= 0:
				ribelli_persi += 1
			else:
				ribelli_vivi += 1
	var tutti_imp := true
	for pid in pianeti:
		if pianeti[pid]["stato"] != "imperiale" or controllo(pid) != I:
			tutti_imp = false
	if livello != "sistema":
		_vittoria_avanzata(ribelli_vivi)
		return
	if scenario_id == "egrix":
		for pid in pianeti:
			if pianeti[pid]["stato"] == "ribelle":
				_fine("ribelli", "%s è sotto controllo ribelle: vittoria immediata dei Ribelli!" % Dati.pianeta(pid)["nome"])
				return
		if ribelli_vivi == 0 and tutti_imp:
			_fine("impero", "Tutti i Ribelli sono morti o catturati: vittoria immediata dell'Impero.")
	elif scenario_id == "varu":
		var cercis := -1
		for pid in pianeti:
			if Dati.pianeta(pid)["nome"] == "Cercis":
				cercis = pid
		var altri := 0
		for pid in pianeti:
			if pid != cercis and pianeti[pid]["stato"] == "ribelle":
				altri += 1
		if cercis >= 0 and pianeti[cercis]["stato"] == "ribelle" and altri >= 1:
			_fine("ribelli", "Cercis e un altro pianeta sono sotto controllo ribelle: vittoria immediata dei Ribelli!")
			return
		if tutti_imp and ribelli_persi >= 3:
			_fine("impero", "Tutti i pianeti sono imperiali e tre Ribelli sono caduti: vittoria immediata dell'Impero.")


func _stato_ribelle(pid: int) -> bool:
	return pianeti.has(pid) and pianeti[pid]["stato"] == "ribelle" and not distrutto(pid)


func pid_per_status(st: String) -> int:
	for p in Dati.d()["galassia"]["pianeti"]:
		if p.get("status", null) != null and str(p["status"]) == st:
			return int(p["id"])
	return -1


func _vittoria_avanzata(ribelli_vivi: int) -> void:
	var ribelli_pianeti := 0
	var qualcosa := 0
	for pid in scenario_pianeti():
		if pianeti[pid]["stato"] == "ribelle":
			ribelli_pianeti += 1
		if pianeti[pid]["stato"] in ["ribelle", "ribellione"]:
			qualcosa += 1
	if ribelli_vivi == 0:
		_fine("impero", "Tutti i personaggi ribelli sono morti o catturati: vittoria immediata dell'Impero.")
		return
	match scenario_id:
		"backdoor":
			var cieson := 211
			if _stato_ribelle(241) and _stato_ribelle(cieson) and ribelli_pianeti >= 3:
				_fine("ribelli", "Orning, Cieson e un altro pianeta sono sotto controllo ribelle: vittoria immediata dei Ribelli!")
				return
			var truppe := false
			for id in unita:
				if unita[id]["k"] == "mil" and unita[id]["fz"] == R and vivo(id) and unita[id]["luogo"] != "":
					truppe = true
			if turno >= 3 and qualcosa == 0 and not truppe:
				_fine("impero", "Dal terzo turno non resta nulla di ribelle nella Seconda Provincia: vittoria immediata dell'Impero.")
		"orlog":
			if _stato_ribelle(152) and _stato_ribelle(162):
				_fine("ribelli", "Diomas e il Trono di Orlog sono sotto controllo ribelle: vittoria immediata dei Ribelli!")
		"galattica":
			if galattico.base_svelata and ribelli_pianeti == 0:
				_fine("impero", "La base segreta è svelata e non resta un solo pianeta ribelle: vittoria immediata dell'Impero.")


func fine_partita() -> void:
	var pv := punti_vittoria()
	if pv["totale"] >= pv["soglia"]:
		_fine("ribelli", "Fine della partita: i Ribelli totalizzano %d Punti Vittoria (ne servivano %d) e vincono!" % [pv["totale"], pv["soglia"]])
	else:
		_fine("impero", "Fine della partita: i Ribelli si fermano a %d Punti Vittoria su %d. Vince l'Impero." % [pv["totale"], pv["soglia"]])


func _fine(chi: String, testo: String) -> void:
	esito = chi
	fase = "finita"
	scrivi(testo)
	evento.emit("fine", {"esito": chi, "testo": testo})
	cambiato.emit()
