extends SceneTree
## Fotografie dell'interfaccia per controllo visivo: menu, partita 2D e vista 3D.
## Uso: xvfb-run godot --path . --rendering-driver opengl3 -s tests/foto.gd -- cartella [scenario]

var out := "/tmp/foto"


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	var sc := a[1] if a.size() > 1 else "varu"
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1920, 1080)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await _attendi(1.5)
	if OS.get_environment("FOTO_REBORN") != "":
		UI.reborn = true
	_scatta("1_menu")
	var cfg := {"scenario": sc, "giocatori": [{"nome": "Ribelli", "ia": false}, {"nome": "Impero", "ia": true}], "seme": 77}
	main.start_game(cfg)
	await _attendi(2.0)
	_scatta("2_partita")
	var p = main.current
	# l'IA gioca anche al posto della persona per far avanzare la partita
	var ia := IA.new()
	for k in 140:
		if p._in_attesa:
			p._premi(ia.scegli(p.motore, p._posto_richiesta, p._richiesta))
		await _attendi(0.12)
		if k == 60:
			_scatta("3_avanti")
	_scatta("4_avanti")
	var carte_pg: Array = p.carte_box.get_children()
	if not carte_pg.is_empty():
		carte_pg[0].mouse_entered.emit()
		await _attendi(0.6)
		_scatta("4a_carta")
		if is_instance_valid(carte_pg[0]):
			carte_pg[0].mouse_exited.emit()
	if p.galassia_v != null:
		p._mostra_galassia(true)
		await _attendi(1.0)
		_scatta("4b_galassia")
		p._mostra_galassia(false)
	p._imposta_3d(true)
	await _attendi(2.5)
	if p.motore.livello != "sistema":
		p.tavolo3d._dist = 32.0
		p.tavolo3d._aggiorna_camera()
		await _attendi(0.5)
	_scatta("5_3d")
	p._imposta_3d(false)
	p._mostra_missioni()
	await _attendi(1.0)
	_scatta("6_missioni")
	quit()


func _attendi(s: float) -> void:
	await create_timer(s).timeout


func _scatta(nome: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out, nome])
	print("foto ", nome)
