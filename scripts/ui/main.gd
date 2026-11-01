extends Control
## Radice dell'applicazione: alterna menu, partita e regole.

var current: Control
## Collegamento a Firebase (resta vivo fra menu e partita).
var net: Net
## Stanza online in preparazione: {role, code, seat}.
var lobby := {}
var menu_state := {}


func get_net() -> Net:
	if net == null:
		net = Net.new()
		add_child(net)
	return net


func _ready() -> void:
	theme = UI.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment(){
	vec2 uv = UV * vec2(1.78, 1.0);
	vec3 c = mix(vec3(0.01, 0.015, 0.05), vec3(0.05, 0.03, 0.10), smoothstep(0.0, 1.2, uv.y + 0.3 * sin(uv.x * 2.0)));
	c += vec3(0.25, 0.08, 0.05) * smoothstep(0.55, 0.0, length(uv - vec2(1.35, 0.25))) * 0.35;
	c += vec3(0.05, 0.1, 0.3) * smoothstep(0.7, 0.0, length(uv - vec2(0.3, 0.85))) * 0.4;
	vec2 q = uv * 220.0;
	vec2 g = floor(q);
	float s = step(0.994, h(g)) * smoothstep(0.35, 0.0, length(fract(q) - 0.5)) * (0.6 + 0.4 * sin(TIME * 2.0 + h(g + 3.0) * 30.0));
	vec2 q2 = uv * 70.0;
	vec2 g2 = floor(q2);
	s += step(0.993, h(g2 + 7.0)) * smoothstep(0.22, 0.0, length(fract(q2) - 0.5));
	COLOR = vec4(c + vec3(s), 1.0);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	fondo.material = mat
	add_child(fondo)
	show_menu()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_F11:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _clear() -> void:
	if current != null:
		current.queue_free()
		current = null


func show_menu() -> void:
	_clear()
	var m := preload("res://scripts/ui/menu.gd").new()
	m.main = self
	add_child(m)
	current = m


func start_game(config: Dictionary) -> void:
	_clear()
	var g := preload("res://scripts/ui/partita.gd").new()
	g.main = self
	g.config = config
	add_child(g)
	current = g


func show_rules() -> void:
	_clear()
	var t := preload("res://scripts/ui/regole.gd").new()
	t.main = self
	add_child(t)
	current = t
