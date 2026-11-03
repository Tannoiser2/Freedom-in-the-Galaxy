class_name Dati
extends RefCounted
## Dati del gioco caricati una volta sola dai file JSON in res://data:
## galassia (stelle, pianeti, ambienti), carte (azione, missione, personaggi, possessi…),
## tabelle (rilevamento, combattimenti, ricerca…), creature della Galactic Guide e scenari.

const LEALTA := ["patriottico", "leale", "neutrale", "dissenso", "agitazione"]
const LEALTA_NOMI := ["Patriottico", "Leale", "Neutrale", "Dissenso", "Agitazione"]
const AMBIENTI := ["urbano", "selvaggio", "sotterraneo", "liquido", "aereo", "fuoco"]
const AMBIENTI_NOMI := {"urbano": "Urbano", "selvaggio": "Selvaggio", "sotterraneo": "Sotterraneo",
	"liquido": "Liquido", "aereo": "Aereo", "fuoco": "Fuoco"}
const SPECIALI := ["sotterraneo", "liquido", "aereo", "fuoco"]
const FAZIONI := ["Ribelli", "Impero"]
const RIBELLI := 0
const IMPERO := 1

static var _d := {}


static func d() -> Dictionary:
	if _d.is_empty():
		for nome in ["galassia", "carte", "tabelle", "creature", "scenari", "possessi_effetti", "regole_avanzate", "mappa_caselle"]:
			var f := FileAccess.open("res://data/%s.json" % nome, FileAccess.READ)
			if f == null:
				push_error("Dati: manca data/%s.json" % nome)
				_d[nome] = {}
				continue
			_d[nome] = JSON.parse_string(f.get_as_text())
		_indicizza()
	return _d


static func _indicizza() -> void:
	var pianeti := {}
	for p in _d["galassia"].get("pianeti", []):
		pianeti[int(p["id"])] = p
	_d["pianeti"] = pianeti
	var stelle := {}
	for s in _d["galassia"].get("stelle", []):
		if not s.get("navigazione", false):
			stelle[int(s["id"])] = s
	_d["stelle"] = stelle
	var pg := {}
	for c in _d["carte"].get("personaggi", []):
		pg[c["nome"]] = c
	_d["pg"] = pg
	var poss := {}
	for c in _d["carte"].get("possessi", []):
		poss[int(c["nr"])] = c
	_d["poss"] = poss
	var mis := {}
	for c in _d["carte"].get("missione", []):
		mis[c["lettera"]] = c
	_d["missioni"] = mis


static func pianeta(pid: int) -> Dictionary:
	return d()["pianeti"].get(pid, {})


static func ambiente(luogo: String) -> Dictionary:
	var p := pianeta(int(luogo.get_slice(":", 0)))
	if not luogo.get_slice(":", 1).is_valid_int():
		return {}
	var i := int(luogo.get_slice(":", 1))
	if p.is_empty() or i >= p["ambienti"].size():
		return {}
	return p["ambienti"][i]


static func carta_pg(nome: String) -> Dictionary:
	return d()["pg"].get(nome, {})


static func nome_ambiente(luogo: String) -> String:
	if luogo.begins_with("D:") or luogo.begins_with("D2:") or luogo.begins_with("S:"):
		var st: Dictionary = d()["stelle"].get(int(luogo.get_slice(":", 1)), {})
		var ns: String = str(st.get("nome", "?"))
		if luogo.begins_with("D2:"):
			return "Deriva 2 verso %s" % ns
		if luogo.begins_with("D:"):
			return "Deriva presso %s" % ns
		return "Fuori mappa, verso %s" % ns
	if luogo.ends_with(":o"):
		return "Orbita di %s" % pianeta(int(luogo.get_slice(":", 0))).get("nome", "?")
	var p := pianeta(int(luogo.get_slice(":", 0)))
	var a := ambiente(luogo)
	if p.is_empty() or a.is_empty():
		return "?"
	return "%s, %s" % [p["nome"], AMBIENTI_NOMI.get(a["tipo"], a["tipo"])]


static func file_pedina(nome: String) -> String:
	var s := nome.to_lower().replace(". ", "_").replace(".", "").replace("-", "_").replace(" ", "_")
	s = s.replace("boccanegra", "boccanegra").replace("emperor_", "")
	return "res://assets/pedine/pg_%s.jpg" % s
