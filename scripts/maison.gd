extends Node3D
# Portefaix — la maison (scripts/maison.gd)
# Un plan dessiné en lettres, une case par mètre : # un mur, . le sol, D une porte du dedans (le chat peut la claquer), P la porte d'entrée.
# De ce plan sortent les murs, les linteaux, les portes, les lampes, la cour, le camion et sa zone de chargement, et la grille où marche la chose.
# Tout le monde bâtit la même maison : rien ici ne dépend du hasard.

const R = preload("res://scripts/regles.gd")

const PLAN := [
	"###########################",
	"#.......#.........#.......#",
	"#.......#.........#.......#",
	"#.......#.........#.......#",
	"#.......#.........#.......#",
	"#.......#.........#.......#",
	"###DD######DD########DD####",
	"#.........................#",
	"#.........................#",
	"###DD#####....#######DD####",
	"#.......#......#..........#",
	"#.......#......#..........#",
	"#.......#......#..........#",
	"#.......#......#..........#",
	"#.......#......#..........#",
	"###########PP##############",
]
# les pièces où il y a des meubles (en cases : colonne, ligne, largeur, profondeur)
const PIECES := [
	{"nom": "la chambre", "rect": Rect2i(1, 1, 7, 5)},
	{"nom": "le salon", "rect": Rect2i(9, 1, 9, 5)},
	{"nom": "le bureau", "rect": Rect2i(19, 1, 7, 5)},
	{"nom": "la cuisine", "rect": Rect2i(1, 10, 7, 5)},
	{"nom": "la salle à manger", "rect": Rect2i(16, 10, 10, 5)},
]
const LAMPES := [Vector2(4.5, 3.5), Vector2(13.5, 3.5), Vector2(22.5, 3.5), Vector2(4.5, 12.5), Vector2(21.0, 12.5),
	Vector2(6.5, 8.0), Vector2(20.0, 8.0), Vector2(12.0, 12.0)]
const COUR := 12                                   # les lignes de cour devant la maison, clôturées
const ZONE := Rect2(9.5, 17.5, 5.0, 4.5)           # la zone de chargement, derrière le camion (x, z)
const CAMION := Rect2(10.6, 22.6, 2.8, 4.2)
const PORTE_HAUT := 2.2
const TANIERE := Vector3(22.5, 0.0, 3.5)           # là où dort la chose : le bureau, au fond
const SEUIL := Vector3(12.0, 0.0, 14.5)            # juste derrière la porte d'entrée : la chose ne va pas plus loin

var largeur := 0
var profondeur := 0
var grille := AStarGrid2D.new()
var portes: Array = []        # {centre: Vector3, corps: StaticBody3D, forme: CollisionShape3D, verrou: bool}
var lampes: Array = []        # {lumiere: OmniLight3D, ampoule: MeshInstance3D}
var eclairee := true
var _decor: StaticBody3D
var _mats := {}


func construire() -> void:
	profondeur = PLAN.size()
	largeur = PLAN[0].length()
	_decor = StaticBody3D.new()
	_decor.name = "Decor"
	_decor.collision_layer = 1
	_decor.collision_mask = 0
	add_child(_decor)
	_sol()
	_murs()
	_lampes()
	_camion()
	_grille()


# --- où l'on est ---

func case_de(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int(floor(p.x)), 0, largeur - 1), clampi(int(floor(p.z)), 0, profondeur + COUR - 1))


func centre(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, 0.0, c.y + 0.5)


func dedans(p: Vector3) -> bool:
	return p.x > 0.0 and p.x < largeur and p.z > 0.0 and p.z < profondeur


func dans_zone(p: Vector3) -> bool:
	return ZONE.has_point(Vector2(p.x, p.z)) and p.y < 2.5


func depart(k: int) -> Vector3:
	return Vector3(12.0 + [0.0, -1.5, 1.5][k % 3], 0.05, 20.0 + float(k / 3) * 1.2)     # dans la zone, le premier face à la porte


func pres_d_une_porte(p: Vector2, d: float) -> bool:
	for porte in portes:
		if Vector2(porte.centre.x, porte.centre.z).distance_to(p) < d:
			return true
	return false


# le chemin de la chose, de case en case (vide s'il n'y en a pas)
func chemin(de: Vector3, vers: Vector3) -> PackedVector3Array:
	var sortie := PackedVector3Array()
	var a := case_de(de)
	var b := case_de(vers)
	if grille.is_point_solid(b):
		b = _case_libre_pres(b)
	if grille.is_point_solid(a):
		a = _case_libre_pres(a)
	for c in grille.get_id_path(a, b):
		sortie.append(centre(c))
	return sortie


func _case_libre_pres(c: Vector2i) -> Vector2i:
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var v := Vector2i(c.x + dx, c.y + dy)
				if grille.is_in_boundsv(v) and not grille.is_point_solid(v):
					return v
	return c


# une case de sol dans la maison, au hasard (là où va rôder la chose)
func case_au_hasard(h: RandomNumberGenerator) -> Vector3:
	for i in 50:
		var c := Vector2i(h.randi_range(1, largeur - 2), h.randi_range(1, profondeur - 2))
		if not grille.is_point_solid(c):
			return centre(c)
	return TANIERE


# voit-on d'un point à l'autre ? Seuls les murs et les portes claquées cachent.
func voit(de: Vector3, vers: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(de, vers, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# --- ce que le chat peut faire à la maison ---

func lumieres(oui: bool) -> void:
	eclairee = oui
	for l in lampes:
		l.lumiere.visible = oui
		l.ampoule.material_override = _mat(Color(1.0, 0.85, 0.55), 2.5) if oui else _mat(Color(0.12, 0.11, 0.1))


func verrouiller(i: int, oui: bool) -> void:
	if i < 0 or i >= portes.size():
		return
	var p: Dictionary = portes[i]
	p.verrou = oui
	p.corps.visible = oui
	p.forme.disabled = not oui


# --- la construction ---

func _mat(c: Color, lueur: float = 0.0) -> StandardMaterial3D:
	var cle := "%s/%s" % [c.to_html(), lueur]
	if not _mats.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		if lueur > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = lueur
		_mats[cle] = m
	return _mats[cle]


func _boite(parent: Node3D, c: Vector3, t: Vector3, m: Material, solide: bool = true) -> void:
	var mesh := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = t
	mesh.mesh = b
	mesh.material_override = m
	mesh.position = c
	parent.add_child(mesh)
	if solide and parent is CollisionObject3D:
		var forme := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = t
		forme.shape = s
		forme.position = c
		parent.add_child(forme)


func _sol() -> void:
	var l := float(largeur)
	var p := float(profondeur)
	# un seul sol solide pour la maison et la cour
	var forme := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(120.0, 1.0, 120.0)
	forme.shape = s
	forme.position = Vector3(l * 0.5, -0.5, p * 0.5)
	_decor.add_child(forme)
	_boite(_decor, Vector3(l * 0.5, -0.06, p * 0.5 + 10.0), Vector3(90.0, 0.1, 90.0), _mat(Color(0.07, 0.11, 0.08)), false)   # l'herbe
	_boite(_decor, Vector3(l * 0.5, -0.03, p * 0.5), Vector3(l, 0.1, p), _mat(Color(0.33, 0.24, 0.16)), false)               # le plancher
	_boite(_decor, Vector3(12.0, -0.04, p + 1.0), Vector3(3.0, 0.1, 2.0), _mat(Color(0.3, 0.3, 0.31)), false)                # le seuil
	_boite(_decor, Vector3(l * 0.5, R.HAUTEUR + 0.15, p * 0.5), Vector3(l, 0.3, p), _mat(Color(0.2, 0.19, 0.18)))            # le plafond
	# la clôture de la cour : trois côtés
	var bois := _mat(Color(0.16, 0.12, 0.09))
	var fond := p + float(COUR)
	_boite(_decor, Vector3(0.5, 1.5, p + COUR * 0.5), Vector3(0.3, 3.0, COUR), bois)
	_boite(_decor, Vector3(l - 0.5, 1.5, p + COUR * 0.5), Vector3(0.3, 3.0, COUR), bois)
	_boite(_decor, Vector3(l * 0.5, 1.5, fond - 0.5), Vector3(l, 3.0, 0.3), bois)


func _murs() -> void:
	var mur := _mat(Color(0.5, 0.47, 0.4))
	var battant := _mat(Color(0.28, 0.17, 0.1))
	for ligne in profondeur:
		var c := 0
		while c < largeur:
			var lettre: String = PLAN[ligne][c]
			var n := 1
			while c + n < largeur and PLAN[ligne][c + n] == lettre:
				n += 1
			var x := c + n * 0.5
			var z := ligne + 0.5
			if lettre == "#":
				_boite(_decor, Vector3(x, R.HAUTEUR * 0.5, z), Vector3(n, R.HAUTEUR, 1.0), mur)
			elif lettre == "D" or lettre == "P":
				var haut: float = R.HAUTEUR - PORTE_HAUT
				_boite(_decor, Vector3(x, PORTE_HAUT + haut * 0.5, z), Vector3(n, haut, 1.0), mur)
				if lettre == "D":
					_porte(Vector3(x, PORTE_HAUT * 0.5, z), Vector3(n, PORTE_HAUT, 0.2), battant)
			c += n


func _porte(c: Vector3, t: Vector3, m: Material) -> void:
	var corps := StaticBody3D.new()
	corps.name = "Porte%d" % portes.size()
	corps.collision_layer = 1
	corps.collision_mask = 0
	add_child(corps)
	_boite(corps, c, t, m)
	var forme: CollisionShape3D = corps.get_child(1)
	forme.disabled = true
	corps.visible = false
	portes.append({"centre": c, "corps": corps, "forme": forme, "verrou": false})


func _lampes() -> void:
	for p in LAMPES:
		var l := OmniLight3D.new()
		l.position = Vector3(p.x, R.HAUTEUR - 0.45, p.y)
		l.light_color = Color(1.0, 0.82, 0.55)
		l.light_energy = 1.6
		l.omni_range = 7.5
		l.omni_attenuation = 1.2
		add_child(l)
		var a := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.1
		s.height = 0.2
		a.mesh = s
		a.position = Vector3(p.x, R.HAUTEUR - 0.15, p.y)
		a.material_override = _mat(Color(1.0, 0.85, 0.55), 2.5)
		add_child(a)
		lampes.append({"lumiere": l, "ampoule": a})


func _camion() -> void:
	# la zone de chargement : quatre bandes jaunes au sol
	var jaune := _mat(Color(0.95, 0.75, 0.15), 0.6)
	var z := ZONE
	_boite(self, Vector3(z.position.x + z.size.x * 0.5, 0.02, z.position.y), Vector3(z.size.x, 0.04, 0.12), jaune, false)
	_boite(self, Vector3(z.position.x + z.size.x * 0.5, 0.02, z.end.y), Vector3(z.size.x, 0.04, 0.12), jaune, false)
	_boite(self, Vector3(z.position.x, 0.02, z.position.y + z.size.y * 0.5), Vector3(0.12, 0.04, z.size.y), jaune, false)
	_boite(self, Vector3(z.end.x, 0.02, z.position.y + z.size.y * 0.5), Vector3(0.12, 0.04, z.size.y), jaune, false)
	# le camion : une caisse ouverte vers la zone, une cabine, deux feux ; on klaxonne en le touchant
	var corps := StaticBody3D.new()
	corps.name = "Camion"
	corps.collision_layer = 1
	corps.collision_mask = 0
	corps.set_meta("klaxon", true)
	add_child(corps)
	var k := CAMION
	var cx := k.position.x + k.size.x * 0.5
	_boite(corps, Vector3(cx, 1.6, k.position.y + 1.4), Vector3(k.size.x, 2.4, 2.8), _mat(Color(0.75, 0.73, 0.68)))
	_boite(corps, Vector3(cx, 1.2, k.end.y - 0.6), Vector3(k.size.x - 0.3, 1.9, 1.2), _mat(Color(0.7, 0.25, 0.12)))
	_boite(corps, Vector3(cx, 0.25, k.position.y + k.size.y * 0.5), Vector3(k.size.x - 0.4, 0.5, k.size.y - 0.4), _mat(Color(0.06, 0.06, 0.07)))
	var rouge := _mat(Color(1.0, 0.15, 0.1), 2.0)
	_boite(self, Vector3(cx - 1.1, 0.8, k.position.y - 0.03), Vector3(0.25, 0.18, 0.05), rouge, false)
	_boite(self, Vector3(cx + 1.1, 0.8, k.position.y - 0.03), Vector3(0.25, 0.18, 0.05), rouge, false)
	var phare := OmniLight3D.new()
	phare.position = Vector3(cx, 2.9, k.position.y - 0.6)
	phare.light_color = Color(0.8, 0.88, 1.0)
	phare.light_energy = 1.1
	phare.omni_range = 9.0
	add_child(phare)
	var porche := OmniLight3D.new()
	porche.position = Vector3(12.0, 2.5, profondeur + 0.6)
	porche.light_color = Color(1.0, 0.8, 0.5)
	porche.light_energy = 0.6
	porche.omni_range = 5.0
	add_child(porche)


func _grille() -> void:
	grille.region = Rect2i(0, 0, largeur, profondeur + COUR)
	grille.cell_size = Vector2.ONE
	grille.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grille.update()
	for ligne in profondeur + COUR:
		for c in largeur:
			var mur := false
			if ligne < profondeur:
				mur = PLAN[ligne][c] == "#"
			else:
				mur = c == 0 or c == largeur - 1 or ligne == profondeur + COUR - 1 \
					or CAMION.grow(0.3).intersects(Rect2(c, ligne, 1.0, 1.0))
			if mur:
				grille.set_point_solid(Vector2i(c, ligne), true)
