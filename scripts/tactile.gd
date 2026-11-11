extends CanvasLayer
# Portefaix — jouer du doigt (scripts/tactile.gd)
# Sur un écran tactile, tenu à l'horizontale : le pouce gauche marche (un joystick qui naît où le doigt se pose, dans la moitié
# gauche de l'écran, et qui le suit s'il va trop loin) ; le pouce droit regarde, en glissant, et presse les boutons.
# « Courir » et « Bas » (s'accroupir) restent enfoncés jusqu'à ce qu'on les retouche. Sur un petit écran, l'image grossit ;
# tenu debout, le téléphone demande qu'on le tourne.
# Il s'allume seul sur un écran tactile, ou au premier toucher.

const ENCRE := Color(0.93, 0.9, 0.82)
const OR := Color(1.0, 0.8, 0.4)
const RAYON_STICK := 62.0
const REGARD := 0.0052            # radians par pixel glissé
# l'action, ce qui est écrit, le coin d'où l'on compte (0 : en bas à droite, 1 : en haut à gauche), la place, le rayon
const BOUTONS := [
	["agir", "Agir", 0, Vector2(-96, -104), 52.0],
	["lancer", "Lancer", 0, Vector2(-214, -84), 33.0],
	["saut", "Saut", 0, Vector2(-196, -176), 33.0],
	["courir", "Courir", 0, Vector2(-98, -226), 33.0],
	["accroupi", "Bas", 0, Vector2(-306, -120), 31.0],
	["torche", "Torche", 1, Vector2(58, 118), 28.0],
	["crier", "Crier", 1, Vector2(132, 118), 28.0],
]

var jeu
var actif := false
var portrait := false
var vecteur := Vector2.ZERO       # la marche : x à droite, y vers le bas de l'écran (donc en arrière)
var court := false
var accroupi := false
var saut := false
var _doigt_stick := -1
var _doigt_regard := -1
var _centre := Vector2.ZERO
var _doigts := {}                 # le doigt → le bouton qu'il tient
var _ou := {}                     # le doigt → où il était la dernière fois
var _dessin: Control
var _tourner: ColorRect


func _ready() -> void:
	layer = 11
	_dessin = Control.new()
	_dessin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dessin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dessin.draw.connect(_dessiner)
	add_child(_dessin)
	_tourner = ColorRect.new()
	_tourner.color = Color(0.01, 0.012, 0.02)
	_tourner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tourner.visible = false
	var l := Label.new()
	l.text = "Tourne ton téléphone\nà l'horizontale."
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", ENCRE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tourner.add_child(l)
	add_child(_tourner)
	get_tree().root.size_changed.connect(_ajuster)
	if DisplayServer.is_touchscreen_available():
		activer.call_deferred()


func activer() -> void:
	if actif:
		return
	actif = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if jeu != null and jeu.ui != null:
		jeu.ui.passer_au_tactile()
	_ajuster()


# sur un petit écran, l'image grossit : la hauteur montrée suit celle de l'écran (en pixels CSS), entre 480 et 720
func _ajuster() -> void:
	var px := Vector2(DisplayServer.window_get_size())
	var css := px / maxf(1.0, DisplayServer.screen_get_scale())
	portrait = css.y > css.x * 1.05
	if actif and css.x > 0.0 and css.y > 0.0:
		var h := clampf(minf(css.x, css.y), 480.0, 720.0)
		get_tree().root.content_scale_size = Vector2i(int(h * 16.0 / 9.0), int(h))
	_tourner.visible = actif and portrait


func _en_jeu() -> bool:
	return jeu != null and jeu.etat == jeu.PARTIE and jeu.moi != null


func _taille() -> Vector2:
	return _dessin.get_viewport_rect().size


func position_bouton(action: String) -> Vector2:
	for b in BOUTONS:
		if b[0] == action:
			return (_taille() if b[2] == 0 else Vector2.ZERO) + b[3]
	return Vector2(-1, -1)


func _bouton_sous(p: Vector2) -> String:
	for b in BOUTONS:
		if p.distance_to(position_bouton(b[0])) < float(b[4]) * 1.15:
			return b[0]
	return ""


func _input(e: InputEvent) -> void:
	if not (e is InputEventScreenTouch or e is InputEventScreenDrag):
		return
	if not actif:
		activer()
	# (un doigt qui se lève lâche ce qu'il tenait, quoi qu'il arrive à l'écran)
	if e is InputEventScreenTouch and not e.pressed:
		_ou.erase(e.index)
		if _doigts.get(e.index, "") == "saut":
			saut = false
		_doigts.erase(e.index)
		if e.index == _doigt_stick:
			_doigt_stick = -1
			vecteur = Vector2.ZERO
		if e.index == _doigt_regard:
			_doigt_regard = -1
		return
	if not _en_jeu() or portrait:
		return
	var moi = jeu.moi
	# de combien ce doigt a glissé : compté ici, d'après sa propre place d'avant. (Dans un navigateur, à deux doigts, le « relative »
	# de Godot 4.3 compare un doigt à la place de l'autre : le regard sautait d'un pouce à l'autre.)
	var glisse: Vector2 = e.position - _ou.get(e.index, e.position)
	_ou[e.index] = e.position
	if e is InputEventScreenTouch:
		var b := _bouton_sous(e.position)
		if b != "":
			_doigts[e.index] = b
			_presser(b)
		elif e.position.x < _taille().x * 0.5 and _doigt_stick < 0:
			_doigt_stick = e.index
			_centre = e.position
			vecteur = Vector2.ZERO
		elif _doigt_regard < 0:
			_doigt_regard = e.index
	elif e.index == _doigt_stick:
		var d: Vector2 = e.position - _centre
		if d.length() > RAYON_STICK:
			# (le joystick suit le doigt qui va trop loin : on ne le perd jamais)
			_centre = e.position - d.normalized() * RAYON_STICK
			d = e.position - _centre
		vecteur = d / RAYON_STICK
	elif e.index == _doigt_regard:
		moi.yaw -= glisse.x * REGARD
		moi.pitch = clampf(moi.pitch - glisse.y * REGARD, -1.4, 1.4)


func _presser(b: String) -> void:
	var moi = jeu.moi
	match b:
		"agir":
			moi.agir()
		"lancer":
			moi.lancer()
		"saut":
			saut = true
		"courir":
			court = not court
			if court:
				accroupi = false
		"accroupi":
			accroupi = not accroupi
			if accroupi:
				court = false
		"torche":
			moi.torche_voulue = not moi.torche_voulue
		"crier":
			moi.crier()


func _process(_delta: float) -> void:
	if not actif:
		return
	if not _en_jeu() or portrait:
		_lacher()
	_dessin.queue_redraw()


# tout lâcher : la partie s'arrête, ou le téléphone se lève
func _lacher() -> void:
	_doigts.clear()
	_ou.clear()
	_doigt_stick = -1
	_doigt_regard = -1
	vecteur = Vector2.ZERO
	saut = false
	court = false
	accroupi = false


func _utile(action: String) -> bool:
	var moi = jeu.moi
	match action:
		"lancer":
			return moi.vivant and moi.porte >= 0
		"saut", "courir", "accroupi", "crier", "torche":
			return moi.vivant
	return true


func _dessiner() -> void:
	if not actif or not _en_jeu() or portrait:
		return
	var t := _taille()
	var police := ThemeDB.fallback_font
	var tenus := _doigts.values()
	# le joystick : là où le pouce s'est posé ; au repos, une trace pâle, en bas à gauche
	var tenu := _doigt_stick >= 0
	var c := _centre if tenu else Vector2(130, t.y - 150)
	var a := 0.55 if tenu else 0.2
	_dessin.draw_circle(c, RAYON_STICK, Color(0, 0, 0, a * 0.6))
	_dessin.draw_arc(c, RAYON_STICK, 0.0, TAU, 48, Color(ENCRE, a), 2.0, true)
	_dessin.draw_circle(c + vecteur * RAYON_STICK, 26.0, Color(ENCRE, a * 0.8))
	for b in BOUTONS:
		var p := position_bouton(b[0])
		var r: float = b[4]
		var k := 1.0 if _utile(b[0]) else 0.35
		var enfonce: bool = tenus.has(b[0]) or (b[0] == "courir" and court) or (b[0] == "accroupi" and accroupi) \
			or (b[0] == "torche" and jeu.moi.torche_voulue and jeu.moi.vivant)
		_dessin.draw_circle(p, r, Color(OR, 0.3) if enfonce else Color(0.03, 0.03, 0.05, 0.55))
		_dessin.draw_arc(p, r, 0.0, TAU, 40, Color(OR, (0.95 if enfonce else 0.6) * k), 2.0, true)
		var corps := 18 if b[0] == "agir" else 13
		var mot: String = b[1]
		if b[0] == "agir" and not jeu.moi.vivant:
			mot = "Pousser"
		elif b[0] == "agir" and jeu.moi.porte >= 0:
			mot = "Poser"
		_dessin.draw_string(police, p + Vector2(-r, corps * 0.36), mot, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, corps, Color(ENCRE, 0.95 * k))
