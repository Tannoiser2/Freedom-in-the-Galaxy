class_name UI
## Tema dell'interfaccia: spazio profondo, pannelli blu notte con cornici nel rosso-arancio e nel giallo
## della scatola SPI del 1979, titoli condensati in maiuscolo come il logo del gioco.

const NOTTE := Color(0.027, 0.035, 0.08)
const PANNELLO := Color(0.06, 0.08, 0.16, 0.94)
const PANNELLO_CHIARO := Color(0.10, 0.13, 0.25, 0.96)
const ROSSO := Color(0.88, 0.27, 0.17)
const ROSSO_SCURO := Color(0.52, 0.13, 0.08)
const GIALLO := Color(0.96, 0.78, 0.22)
const CIANO := Color(0.36, 0.78, 0.96)
const TESTO := Color(0.92, 0.90, 0.84)
const GRIGIO := Color(0.62, 0.66, 0.74)
const VERDE := Color(0.42, 0.82, 0.46)
const COL_RIBELLI := Color(0.88, 0.30, 0.22)
const COL_IMPERO := Color(0.96, 0.74, 0.20)
const COL_AMBIENTI := {"urbano": Color(0.25, 0.48, 0.92), "selvaggio": Color(0.30, 0.66, 0.30),
	"sotterraneo": Color(0.78, 0.22, 0.20), "liquido": Color(0.55, 0.62, 0.20),
	"aereo": Color(0.45, 0.75, 0.95), "fuoco": Color(0.96, 0.55, 0.15)}

static var font_titolo: Font
static var font_titolo2: Font
static var font_testo: Font
static var font_grassetto: Font
static var _tex := {}
## Grafica Reborn (impostazione del menu): pedine, carte personaggio e pianeti ridisegnati.
static var reborn := false


static func carica_impostazioni() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://impostazioni.cfg") == OK:
		reborn = bool(cf.get_value("vista", "reborn", false))


static func salva_reborn(on: bool) -> void:
	reborn = on
	var cf := ConfigFile.new()
	cf.load("user://impostazioni.cfg")
	cf.set_value("vista", "reborn", on)
	cf.save("user://impostazioni.cfg")


## Immagine Reborn (o null se non esiste o se la grafica Reborn è spenta).
static func reborn_tex(percorso: String) -> Texture2D:
	if not reborn:
		return null
	return tex("res://assets/reborn/%s.webp" % percorso)


static func carta_reborn(nome: String) -> Texture2D:
	return reborn_tex("carte/" + nome.to_lower().replace(" ", "-"))


## Carta Reborn di qualsiasi mazzo: personaggi per nome, le altre per file della scansione.
static func carta_reborn_di(tipo: String, dati: Dictionary) -> Texture2D:
	if tipo == "personaggio":
		return carta_reborn(str(dati.get("nome", "")))
	return reborn_tex("carte/" + str(dati.get("file", "")))


static func carica_font() -> void:
	if font_testo != null:
		return
	font_titolo = load("res://assets/font/SairaCondensed-ExtraBold.ttf")
	font_titolo2 = load("res://assets/font/SairaCondensed-Bold.ttf")
	font_testo = load("res://assets/font/Exo2.ttf")
	var fv := FontVariation.new()
	fv.base_font = font_testo
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	font_grassetto = fv
	var fr := FontVariation.new()
	fr.base_font = font_testo
	fr.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 420}
	font_testo = fr


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func stile(bg: Color, bordo: Color, spessore := 2, raggio := 6, margine := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = bordo
	s.set_border_width_all(spessore)
	s.set_corner_radius_all(raggio)
	s.content_margin_left = margine
	s.content_margin_right = margine
	s.content_margin_top = margine * 0.7
	s.content_margin_bottom = margine * 0.7
	return s


static func make_theme() -> Theme:
	carica_font()
	var t := Theme.new()
	t.default_font = font_testo
	t.default_font_size = 19
	t.set_color("font_color", "Label", TESTO)
	t.set_color("default_color", "RichTextLabel", TESTO)
	t.set_font("bold_font", "RichTextLabel", font_grassetto)
	t.set_font("normal_font", "RichTextLabel", font_testo)
	t.set_stylebox("normal", "Button", stile(Color(0.10, 0.13, 0.26), Color(0.36, 0.42, 0.62)))
	t.set_stylebox("hover", "Button", stile(Color(0.16, 0.20, 0.38), GIALLO))
	t.set_stylebox("pressed", "Button", stile(Color(0.42, 0.14, 0.09), GIALLO))
	t.set_stylebox("disabled", "Button", stile(Color(0.07, 0.08, 0.13), Color(0.2, 0.22, 0.3)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TESTO)
	t.set_color("font_hover_color", "Button", Color(1, 0.97, 0.85))
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.47, 0.55))
	t.set_font("font", "Button", font_grassetto)
	t.set_font_size("font_size", "Button", 18)
	for tipo in ["CheckBox", "CheckButton"]:
		t.set_font("font", tipo, font_testo)
		t.set_color("font_color", tipo, TESTO)
		t.set_color("font_hover_color", tipo, GIALLO)
		t.set_color("font_pressed_color", tipo, GIALLO)
	var le := stile(Color(0.04, 0.05, 0.10, 0.95), Color(0.36, 0.42, 0.62), 2, 4, 10)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", stile(Color(0.04, 0.05, 0.10, 0.95), GIALLO, 2, 4, 10))
	t.set_color("font_color", "LineEdit", TESTO)
	t.set_stylebox("panel", "PanelContainer", stile(PANNELLO, ROSSO_SCURO))
	t.set_stylebox("panel", "TooltipPanel", stile(Color(0.05, 0.06, 0.12, 0.98), GIALLO, 1, 4, 8))
	t.set_color("font_color", "TooltipLabel", TESTO)
	t.set_font_size("font_size", "TooltipLabel", 17)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.36, 0.42, 0.62, 0.7)
	sb.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", sb)
	t.set_stylebox("grabber_highlight", "VScrollBar", sb)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	return t


static func titolo(t: String, size := 34, col := GIALLO) -> Label:
	var l := Label.new()
	l.text = t.to_upper()
	l.add_theme_font_override("font", font_titolo)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


static func etichetta(t: String, size := 19, col := TESTO, grassetto := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if grassetto:
		l.add_theme_font_override("font", font_grassetto)
	return l


static func testo_lungo(t: String, size := 18, col := TESTO) -> Label:
	var l := etichetta(t, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 100
	return l


static func bottone(t: String, size := 18) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func pannello(bg := PANNELLO, bordo := ROSSO_SCURO, spessore := 2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", stile(bg, bordo, spessore, 8, 14))
	return p


static func colore_fazione(f: int) -> Color:
	return COL_RIBELLI if f == 0 else COL_IMPERO


static func pedina_tex(chiave: String, retro := false) -> Texture2D:
	var r := reborn_tex("pedine/%s%s" % [chiave, "_r" if retro else ""])
	if r != null:
		return r
	return tex("res://assets/pedine/%s%s.jpg" % [chiave, "_r" if retro else ""])


## Chiave della pedina originale di un personaggio (dal nome della carta).
static func chiave_pg(nome: String) -> String:
	var mappa := {"Professor Mareg": "prof_mareg", "Senator Dermond": "dermond", "Emperor Coreguya": "coreguya",
		"Vans Ka-Tie-A": "vans_ka_tie_a", "Doctor Sontag": "doctor_sontag"}
	if mappa.has(nome):
		return "pg_" + mappa[nome]
	return "pg_" + nome.to_lower().replace(" ", "_").replace("-", "_")


static func chiave_mil(u: Dictionary) -> String:
	if u.has("cat"):
		var d: Dictionary = Dati.d()["regole_avanzate"]["unita"][u["cat"]]
		if int(u["fz"]) == Motore.I:
			return str(d["ped"])
		var c := str(d["ped"])
		if reborn:
			return "rib_%s_%s" % [u["amb"], c]
		if c == "elite" and not u["amb"] in ["urbano", "selvaggio"]:
			c = "43"
		if c == "43" and u["amb"] == "fuoco":
			c = "23"
		return "rib_%s_%s" % [u["amb"], c]
	match u["tipo"]:
		"milizia":
			return "imp_milizia"
		"pattuglia":
			return "imp_pattuglia"
		"linea":
			return "imp_linea"
	return "rib_%s_%s" % [u["amb"], "21" if int(u["forza"]) == 2 else "10"]


static func chiave_nave(nave: Dictionary) -> String:
	if nave.get("redjac", false):
		return "nave_redjac"
	if nave.get("imp", false):
		return "nave_imperiale"
	return "nave_%d" % int(nave.get("nr", 0))
