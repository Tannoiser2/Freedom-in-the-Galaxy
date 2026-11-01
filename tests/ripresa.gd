extends SceneTree
## Verifica dei salvataggi: una partita IA contro IA viene interrotta, le sue scelte riapplicate a un
## motore nuovo con lo stesso seme, e la partita ripresa deve arrivare allo stesso identico finale.

class ControlloSim:
	var ia := IA.new()
	func decide(m, posto, req):
		return ia.scegli(m, posto, req)


func _init() -> void:
	var ok := true
	for sc in ["egrix", "varu", "backdoor", "orlog", "galattica"]:
		for seme in ([11, 12, 13] if sc in ["egrix", "varu"] else [11]):
			var a := _nuovo(sc, seme)
			await a.gioca()
			var b := _nuovo(sc, seme)
			var taglio := a.storia.size()
			b.riprendi(a.storia.slice(0, taglio))
			await b.gioca()
			var uguali: bool = a.esito == b.esito and a.turno == b.turno and a.storia == b.storia and a.punti_vittoria()["totale"] == b.punti_vittoria()["totale"]
			print("%s seme %d: %s (scelte %d, riapplicate %d)" % [sc, seme, "IDENTICA" if uguali else "DIVERSA", a.storia.size(), taglio])
			ok = ok and uguali
			a.queue_free()
			b.queue_free()
	print("RIPRESA OK" if ok else "RIPRESA FALLITA")
	quit(0 if ok else 1)


func _nuovo(sc: String, seme: int) -> Motore:
	var m := Motore.new()
	m.in_simulazione = true
	root.add_child(m)
	m.prepara({"scenario": sc, "seme": seme, "giocatori": [{"nome": "R", "ia": true}, {"nome": "I", "ia": true}]})
	m.controllori = [ControlloSim.new(), ControlloSim.new()]
	return m
