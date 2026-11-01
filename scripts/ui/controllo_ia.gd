class_name ControlloIA
extends RefCounted
## Le decisioni dell'IA in una partita su questo dispositivo: avvisa la vista, attende un attimo
## (per far vedere cosa succede) e lascia decidere l'IA.

var vista
var ia := IA.new()


func decide(m: Motore, posto: int, req: Dictionary):
	if vista != null:
		vista.mostra_pensiero(posto, req)
	if m.ritmo > 0.0 and not m.in_simulazione:
		await m.get_tree().create_timer(0.25 * m.ritmo).timeout
	else:
		await m.get_tree().process_frame
	return ia.scegli(m, posto, req)
