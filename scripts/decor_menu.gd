extends Control
# Portefaix — le décor du menu (scripts/decor_menu.gd)
# Derrière le menu et les pages du compte : le manoir, la nuit, peint par le code (le jeu n'a aucun fichier d'image). Un ciel bleu
# nuit, des étoiles qui scintillent, la lune et son halo, des nuages qui passent devant elle ; le manoir en ombre chinoise, ses
# fenêtres qui vacillent (l'une s'allume, une autre s'éteint), et, à la fenêtre de la tour, de temps en temps, une silhouette pâle ;
# des arbres morts, des tombes, la grille ; devant, le camion des déménageurs, phares allumés, son liseré jaune ; la brume qui rampe
# au ras du sol ; un éclair, de loin en loin. À gauche, l'ombre s'épaissit : le menu s'y lit.
# Le tableau est composé sur 1600 × 900, calé en bas à droite de l'écran : sur un écran plus large, le ciel et le sol s'étendent.

const NUIT_HAUT := Color(0.012, 0.016, 0.04)
const NUIT_BAS := Color(0.07, 0.08, 0.14)
const LOIN := Color(0.045, 0.05, 0.08)
const OMBRE := Color(0.03, 0.03, 0.05)
const PRES := Color(0.016, 0.016, 0.028)
const FENETRE := Color(1.0, 0.74, 0.36)
const LUNE := Color(0.93, 0.92, 0.84)

const BRUME := """
shader_type canvas_item;
uniform float t = 0.0;
uniform float gauche = 0.6;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int k = 0; k < 4; k++) { s += a * n(p); p *= 2.03; a *= 0.5; } return s; }
void fragment() {
	vec2 uv = UV;
	// la brume : au ras du sol, elle rampe vers la gauche
	float bas = smoothstep(0.55, 1.0, uv.y);
	float b = fbm(vec2(uv.x * 3.0 + t * 0.035, uv.y * 6.0 - t * 0.01)) * fbm(vec2(uv.x * 5.0 - t * 0.02, uv.y * 3.0));
	float brume = clamp(b * 2.2, 0.0, 1.0) * bas * 0.55;
	vec3 c = vec3(0.55, 0.6, 0.75);
	// l'ombre à gauche, où le menu se lit ; le bord de l'écran assombri
	float ombre = (1.0 - smoothstep(0.0, gauche, uv.x)) * 0.86;
	float bord = smoothstep(0.45, 0.95, distance(uv, vec2(0.6, 0.45)));
	float noir = clamp(ombre + bord * 0.55, 0.0, 0.92);
	float a = clamp(max(brume, noir) + brume * noir * 0.3, 0.0, 0.95);
	COLOR = vec4(mix(c, vec3(0.005, 0.006, 0.012), noir / max(noir + brume, 0.0001)), a);
}
"""

var t := 0.0
var gauche := 0.6            # jusqu'où l'ombre du menu s'étend (en part de la largeur) ; 0 : pas d'ombre
var _etoiles: Array = []
var _arbres: Array = []      # [base, [[a, b, épaisseur]…]] : les branches, calculées une fois
var _brume: ColorRect
var _eclair := 0.0
var _prochain_eclair := 9.0
var _r := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_r.seed = 1977
	for k in 170:
		_etoiles.append([Vector2(_r.randf(), _r.randf() * 0.62), _r.randf_range(0.6, 1.8), _r.randf() * TAU, _r.randf_range(0.5, 2.2)])
	_arbres = [_arbre(Vector2(560, 772), 210.0, 3), _arbre(Vector2(1540, 790), 260.0, 11), _arbre(Vector2(300, 800), 150.0, 23)]
	_brume = ColorRect.new()
	_brume.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brume.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s := Shader.new()
	s.code = BRUME
	var m := ShaderMaterial.new()
	m.shader = s
	_brume.material = m
	add_child(_brume)


# un arbre mort : un tronc, des branches qui se divisent et s'amincissent (le même à chaque fois : sa graine)
func _arbre(base: Vector2, haut: float, graine: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	var traits: Array = []
	var pile: Array = [[base, -PI * 0.5 + r.randf_range(-0.08, 0.08), haut * 0.42, 9.0, 0]]
	while not pile.is_empty():
		var b: Array = pile.pop_back()
		var a: Vector2 = b[0]
		var fin: Vector2 = a + Vector2.from_angle(float(b[1])) * float(b[2])
		traits.append([a, fin, float(b[3])])
		if int(b[4]) < 5 and float(b[2]) > 10.0:
			for k in (2 if int(b[4]) > 0 else 3):
				pile.append([fin, float(b[1]) + r.randf_range(-0.75, 0.75), float(b[2]) * r.randf_range(0.55, 0.78), maxf(1.0, float(b[3]) * 0.62), int(b[4]) + 1])
	return [base, traits]


func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	t += dt
	_prochain_eclair -= dt
	if _prochain_eclair <= 0.0:
		_eclair = 1.0
		_prochain_eclair = _r.randf_range(14.0, 26.0)
	_eclair = maxf(0.0, _eclair - dt * 2.4)
	var m: ShaderMaterial = _brume.material
	m.set_shader_parameter("t", t)
	m.set_shader_parameter("gauche", gauche)
	queue_redraw()


# du tableau (1600 × 900) à l'écran : calé en bas à droite, à la hauteur de l'écran
func _p(x: float, y: float) -> Vector2:
	var k := size.y / 900.0
	return Vector2(size.x - (1600.0 - x) * k, size.y - (900.0 - y) * k)


func _k() -> float:
	return size.y / 900.0


func _rect(x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
	var a := _p(x0, y0)
	draw_rect(Rect2(a, _p(x1, y1) - a), c)


func _poly(pts: Array, c: Color) -> void:
	var p := PackedVector2Array()
	for q in pts:
		p.append(_p(q.x, q.y))
	draw_colored_polygon(p, c)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var k := _k()
	var eclair := _eclair * _eclair
	# le ciel
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([NUIT_HAUT.lerp(Color(0.5, 0.55, 0.75), eclair * 0.35), NUIT_HAUT.lerp(Color(0.5, 0.55, 0.75), eclair * 0.35),
			NUIT_BAS.lerp(Color(0.6, 0.65, 0.85), eclair * 0.3), NUIT_BAS.lerp(Color(0.6, 0.65, 0.85), eclair * 0.3)]))
	# les étoiles
	for e in _etoiles:
		var p: Vector2 = e[0]
		var a := 0.35 + 0.45 * (0.5 + 0.5 * sin(t * float(e[3]) + float(e[2])))
		draw_circle(Vector2(p.x * w, p.y * h), float(e[1]) * maxf(k, 0.7) * 0.6, Color(0.85, 0.88, 1.0, a))
	# la lune, son halo
	var lune := _p(1330, 165)
	for i in 16:
		draw_circle(lune, (250.0 - 12.0 * i) * k, Color(0.72, 0.78, 1.0, 0.012 + 0.0015 * i))
	draw_circle(lune, 64.0 * k, LUNE)
	for c in [[Vector2(-18, -14), 12.0], [Vector2(20, 8), 16.0], [Vector2(-6, 26), 8.0], [Vector2(26, -24), 7.0]]:
		draw_circle(lune + c[0] * k, float(c[1]) * k, Color(0.8, 0.8, 0.74, 0.55))
	# les nuages : ils passent, devant la lune aussi
	for i in 5:
		var vitesse := 9.0 + i * 3.5
		var x := fposmod(i * 410.0 + t * vitesse, 2200.0) - 400.0
		var y := 90.0 + i * 46.0
		for j in 4:
			var c := _p(x + j * 70.0, y + sin(j * 1.7 + i) * 10.0)
			draw_set_transform(c, 0.0, Vector2(1.0, 0.32))
			for r in [1.0, 0.8, 0.6]:
				draw_circle(Vector2.ZERO, (90.0 - j * 8.0) * k * r, Color(0.11, 0.12, 0.18, 0.16))
			draw_set_transform_matrix(Transform2D.IDENTITY)
	# les collines au loin
	var loin := PackedVector2Array()
	loin.append(Vector2(0, h))
	for i in 33:
		var x := -200.0 + i * 60.0
		loin.append(_p(x, 640.0 - 40.0 * sin(x * 0.004 + 1.3) - 22.0 * sin(x * 0.011)))
	loin.append(Vector2(w, h))
	draw_colored_polygon(loin, LOIN.lerp(Color(0.2, 0.22, 0.32), eclair * 0.5))
	_manoir(eclair)
	# le sol, les tombes, la grille, les arbres
	var sol := PackedVector2Array()
	sol.append(Vector2(0, h))
	for i in 33:
		var x := -200.0 + i * 60.0
		sol.append(_p(x, 772.0 + 8.0 * sin(x * 0.009) + (14.0 if x < 700.0 else 0.0) * sin(x * 0.006)))
	sol.append(Vector2(w, h))
	draw_colored_polygon(sol, PRES)
	_poly([Vector2(1095, 762), Vector2(1145, 762), Vector2(1240, 900), Vector2(1010, 900)], Color(0.05, 0.045, 0.05))   # le chemin
	for tb in [[640.0, 0], [690.0, 1], [460.0, 0], [740.0, 0], [410.0, 1]]:
		_tombe(float(tb[0]), int(tb[1]))
	_grille()
	for a in _arbres:
		for b in a[1]:
			draw_line(_p(b[0].x, b[0].y), _p(b[1].x, b[1].y), PRES, maxf(1.0, float(b[2]) * k), true)
	_camion()


func _manoir(eclair: float) -> void:
	var c := OMBRE.lerp(Color(0.16, 0.17, 0.26), eclair * 0.6)
	_rect(860, 520, 1380, 762, c)                                   # le corps
	_poly([Vector2(832, 522), Vector2(1120, 378), Vector2(1408, 522)], c)       # le toit
	_rect(700, 600, 862, 762, c)                                    # l'aile
	_poly([Vector2(684, 602), Vector2(780, 528), Vector2(878, 602)], c)
	_rect(1378, 430, 1482, 762, c)                                  # la tour
	_poly([Vector2(1366, 432), Vector2(1430, 290), Vector2(1494, 432)], c)
	draw_line(_p(1430, 290), _p(1430, 262), c, maxf(1.0, 3.0 * _k()))
	_rect(958, 400, 986, 470, c)                                    # les cheminées
	_rect(1248, 410, 1276, 480, c)
	_poly([Vector2(1066, 692), Vector2(1120, 656), Vector2(1174, 692)], c)      # le porche
	_rect(1076, 692, 1164, 700, c)
	# les fenêtres : certaines éclairées, qui vacillent ; l'une s'allume et s'éteint lentement
	var fenetres := [[900, 556, 0], [968, 556, 1], [1036, 556, 0], [1204, 556, 1], [1272, 556, 0], [1340, 556, 0],
		[900, 634, 1], [968, 634, 0], [1036, 634, 0], [1204, 634, 0], [1272, 634, 1], [1340, 634, 1],
		[730, 640, 0], [800, 640, 1], [1416, 584, 1], [1105, 470, 2]]
	for i in fenetres.size():
		var f: Array = fenetres[i]
		var x: float = f[0]
		var y: float = f[1]
		var allume := int(f[2]) == 1
		var force := 0.0
		if allume:
			force = 0.78 + 0.16 * sin(t * (2.0 + i * 0.37) + i) + 0.06 * sin(t * 17.0 + i * 3.0)
			if fmod(t + i * 5.3, 23.0) < 0.35:           # (de temps en temps, elle clignote)
				force *= 0.3
		elif int(f[2]) == 2:
			force = clampf(sin(t * 0.21) * 1.6, 0.0, 1.0)  # (la lucarne : elle s'allume, puis s'éteint)
		var lumiere := Color(0.05, 0.045, 0.06).lerp(FENETRE, force)
		_rect(x, y, x + 34, y + 50, lumiere)
		if force > 0.2:
			var centre := _p(x + 17, y + 25)
			for r in [44.0, 36.0, 28.0]:
				draw_circle(centre, r * _k(), Color(FENETRE, 0.018 * force))
		draw_line(_p(x + 17, y), _p(x + 17, y + 50), c, maxf(1.0, 2.5 * _k()))
		draw_line(_p(x, y + 22), _p(x + 34, y + 22), c, maxf(1.0, 2.5 * _k()))
	# la fenêtre de la tour, en haut : sombre ; de temps en temps, une silhouette pâle y paraît
	_rect(1414, 470, 1446, 520, Color(0.04, 0.04, 0.06))
	var cycle := fmod(t, 13.0)
	if cycle > 9.0 and cycle < 12.0:
		var a := sin((cycle - 9.0) / 3.0 * PI)
		draw_circle(_p(1430, 486), 7.0 * _k(), Color(0.78, 0.86, 1.0, 0.85 * a))
		_poly([Vector2(1421, 520), Vector2(1430, 490), Vector2(1439, 520)], Color(0.78, 0.86, 1.0, 0.7 * a))
		for r in [30.0, 22.0, 15.0]:
			draw_circle(_p(1430, 490), r * _k(), Color(0.6, 0.75, 1.0, 0.03 * a))
	# la porte, entrouverte : une lueur chaude sur le seuil
	_rect(1100, 702, 1140, 762, Color(0.05, 0.04, 0.04))
	var porte := 0.55 + 0.12 * sin(t * 3.0) + 0.05 * sin(t * 11.0)
	_rect(1102, 705, 1116, 762, Color(FENETRE, porte))
	_poly([Vector2(1102, 762), Vector2(1116, 762), Vector2(1150, 800), Vector2(1090, 800)], Color(FENETRE, 0.12 * porte))


func _tombe(x: float, sorte: int) -> void:
	if sorte == 0:
		_rect(x - 14, 742, x + 14, 782, PRES)
		draw_circle(_p(x, 744), 14.0 * _k(), PRES)
	else:
		_rect(x - 4, 726, x + 4, 784, PRES)
		_rect(x - 16, 738, x + 16, 746, PRES)


func _grille() -> void:
	var c := PRES
	draw_line(_p(600, 738), _p(1086, 738), c, maxf(1.0, 3.0 * _k()))
	draw_line(_p(1154, 738), _p(1600, 738), c, maxf(1.0, 3.0 * _k()))
	var x := 604.0
	while x < 1600.0:
		if x < 1086.0 or x > 1154.0:
			draw_line(_p(x, 724), _p(x, 784), c, maxf(1.0, 2.5 * _k()))
			_poly([Vector2(x - 4, 726), Vector2(x, 714), Vector2(x + 4, 726)], c)
		x += 18.0


# le camion des déménageurs, devant : sa caisse, sa cabine tournée vers le manoir, ses phares, son liseré jaune
func _camion() -> void:
	var c := Color(0.04, 0.04, 0.06)
	var lune := Color(0.42, 0.46, 0.62, 0.55)          # (la lune accroche le haut des tôles)
	# le faisceau des phares, vers la gauche
	var phare := _p(1324, 842)
	var loin_haut := _p(900, 786)
	var loin_bas := _p(900, 900)
	draw_polygon(PackedVector2Array([phare, loin_haut, loin_bas]), PackedColorArray([Color(1.0, 0.93, 0.7, 0.32), Color(1.0, 0.93, 0.7, 0.0), Color(1.0, 0.93, 0.7, 0.0)]))
	_rect(1380, 742, 1600, 858, c)                                  # la caisse
	draw_line(_p(1380, 743), _p(1600, 743), lune, maxf(1.0, 2.0 * _k()))
	for x in [1440.0, 1500.0, 1560.0]:                              # ses nervures
		draw_line(_p(x, 748), _p(x, 852), Color(0.06, 0.06, 0.09), maxf(1.0, 2.0 * _k()))
	_rect(1384, 850, 1600, 856, Color(1.0, 0.82, 0.2, 0.9))         # son liseré jaune
	_poly([Vector2(1318, 800), Vector2(1350, 774), Vector2(1384, 774), Vector2(1384, 858), Vector2(1318, 858)], c)   # la cabine
	draw_line(_p(1350, 774), _p(1384, 774), lune, maxf(1.0, 2.0 * _k()))
	draw_line(_p(1318, 800), _p(1350, 774), lune, maxf(1.0, 2.0 * _k()))
	_poly([Vector2(1330, 802), Vector2(1352, 782), Vector2(1374, 782), Vector2(1374, 806)], Color(0.16, 0.19, 0.27))  # son pare-brise
	draw_circle(_p(1360, 862), 20.0 * _k(), c)                      # les roues
	draw_circle(_p(1540, 862), 20.0 * _k(), c)
	draw_circle(phare, 7.0 * _k(), Color(1.0, 0.95, 0.8))
	draw_circle(phare, 18.0 * _k(), Color(1.0, 0.9, 0.6, 0.18))
	draw_string(get_theme_default_font(), _p(1408, 806), "PORTEFAIX & FILS", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(9, int(19 * _k())), Color(0.85, 0.72, 0.45, 0.7))
	draw_string(get_theme_default_font(), _p(1408, 828), "déménagements de nuit", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(8, int(14 * _k())), Color(0.7, 0.66, 0.6, 0.5))
