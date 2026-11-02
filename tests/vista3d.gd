extends SceneTree
## Headless checks for planet scale and the PDB presentation state machine.

func _init() -> void:
	var table = load("res://scripts/ui/tavolo3d.gd")
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/galassia.json"))
	var radii := {}
	for p in data["pianeti"]:
		var total := 0.0
		for env in p["ambienti"]:
			total += float(env["taglia"])
		var actual: float = table.raggio_pianeta(p)
		if not _check(abs(actual * actual / total - 2.3 * 2.3 / 9.0) < 0.00001, "Planet area scale: " + str(p["nome"])):
			return
		var moved: Dictionary = p.duplicate(true)
		moved["anello"] = 99
		if not _check(is_equal_approx(actual, table.raggio_pianeta(moved)), "Orbit must not change planet size"):
			return
		radii[int(p["id"])] = actual
	if not _check(abs(float(radii[432]) / float(radii[352]) - sqrt(6.0)) < 0.00001, "Solvia/Kelta diameter ratio"):
		return
	print("SCALE OK: 51 planets, Solvia/Kelta = sqrt(6), independent of orbital ring")
	var component = load("res://scripts/ui/difesa_planetaria3d.gd")
	var pdb = component.new()
	root.add_child(pdb)
	pdb.configura(2.3, 0, true)
	for strength in [0, 1, 2]:
		pdb.aggiorna(strength, true)
		if not _check(pdb._basi.get_child_count() == strength + 1, "PDB count at strength " + str(strength)):
			return
	var before: float = pdb.angolo
	pdb._process(0.5)
	if not _check(pdb.angolo > before and pdb._basi.rotation.y > 0, "UP must rotate stations"):
		return
	pdb.aggiorna(2, false)
	before = pdb.angolo
	pdb._process(10.0)
	if not _check(pdb.angolo == before and pdb.colore_stato.r > pdb.colore_stato.g, "DOWN must freeze and turn red"):
		return
	if not _check("DOWN" in pdb._label.text, "DOWN must also have a text indication"):
		return
	pdb.aggiorna(2, true)
	pdb._process(0.5)
	if not _check(pdb.angolo > before and pdb.colore_stato.g > pdb.colore_stato.r, "UP must resume and turn green"):
		return
	print("PDB OK: 0/1/2 -> 1/2/3 bases; UP green/rotating; DOWN red/frozen; resume OK")
	pdb.queue_free()
	var motor := Motore.new()
	root.add_child(motor)
	motor.prepara({"scenario": "egrix", "seme": 142, "giocatori": [{"nome": "R", "ia": true}, {"nome": "I", "ia": true}]})
	var view = table.new()
	view.m = motor
	root.add_child(view)
	await process_frame
	if not _check(view._difese.size() == motor.scenario_pianeti().size(), "Each displayed planet needs its PDB"):
		return
	var pid: int = int(view._difese.keys()[0])
	motor.pianeti[pid]["bdp"] = 1
	motor.pianeti[pid]["su"] = false
	view.aggiorna()
	if not _check(not view._difese[pid].operativa and view._difese[pid]._basi.get_child_count() == 2, "Game state must drive PDB presentation"):
		return
	var status = view._pianeti[pid].get_node("Stato")
	if not _check("BDP 1" in status.text and "fuori uso" in status.text and not view._difese[pid]._label.visible, "Planet status must show strength/DOWN without overlapping labels"):
		return
	motor.pianeti[pid]["su"] = true
	view.aggiorna()
	if not _check(view._difese[pid].operativa, "Game UP state must restore the PDB"):
		return
	view.queue_free()
	motor.queue_free()
	await process_frame
	print("VIEW INTEGRATION OK: scenario planets, game bdp/su binding and state refresh")
	quit(0)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
