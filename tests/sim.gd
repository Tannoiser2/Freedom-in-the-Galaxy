extends SceneTree
## Partite automatiche IA contro IA: verifica che il motore arrivi sempre in fondo senza errori.
## Uso: godot --headless --path . -s tests/sim.gd -- [partite] [scenario]

class ControlloSim:
	var ia := IA.new()
	func decide(m, posto, req):
		return ia.scegli(m, posto, req)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 10
	var solo := args[1] if args.size() > 1 else ""
	var primo := int(args[2]) if args.size() > 2 else 1000
	var conta := {"ribelli": 0, "impero": 0}
	for k in n:
		for sc in (["egrix", "varu"] if solo == "" else solo.split(",")):
			var m := Motore.new()
			m.in_simulazione = true
			root.add_child(m)
			if OS.get_environment("SIM_TRACE") != "":
				m.messaggio.connect(func(t): print("   > ", t))
			m.prepara({"scenario": sc, "seme": primo + k, "giocatori": [{"nome": "R", "ia": true}, {"nome": "I", "ia": true}]})
			m.controllori = [ControlloSim.new(), ControlloSim.new()]
			await m.gioca()
			conta[m.esito] = conta.get(m.esito, 0) + 1
			var pv := m.punti_vittoria()
			print("%s seme %d: %s al turno %d, PV %d, scelte %d" % [sc, primo + k, m.esito, m.turno, pv["totale"], m._scelte_fatte])
			if k == 0 and OS.get_environment("SIM_LOG") != "":
				for r in m.registro.slice(maxi(0, m.registro.size() - 400)):
					print("   ", r)
			m.queue_free()
	print("RISULTATI ", conta)
	quit()
