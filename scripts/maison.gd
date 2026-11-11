extends Node3D
# Portefaix — la maison (scripts/maison.gd)
# Chaque nuit a sa maison, inventée d'après la graine de la partie : tout le monde bâtit donc la même.
# Le plan est une grille de lettres, une case par mètre : # un mur, . le sol, D une porte du dedans (le chat peut la claquer), P la
# porte d'entrée. L'invention : un couloir en travers, une entrée qui donne sur la cour, et de part et d'autre des pièces de tailles
# inégales, certaines en enfilade. Chaque pièce ouvre sur le couloir ou sur une voisine, souvent sur les deux : des portes partout,
# et plus d'un chemin pour fuir. Puis chaque pièce reçoit son métier (salon, cuisine, chambre…), que scripts/amenagement.gd meuble.
# De ce plan sortent les murs, les linteaux, les portes, les sols, les lampes, la cour, le camion, et la grille où marche la chose.
# Une graine négative donne la maison d'essai, toujours la même : celle que jouent les essais sans écran.

const R = preload("res://scripts/regles.gd")

const PLAN_ESSAI := [
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
const PIECES_ESSAI := [
	["chambre", Rect2i(1, 1, 7, 5)], ["salon", Rect2i(9, 1, 9, 5)], ["bureau", Rect2i(19, 1, 7, 5)],
	["cuisine", Rect2i(1, 10, 7, 5)], ["manger", Rect2i(16, 10, 10, 5)], ["entree", Rect2i(9, 10, 6, 5)], ["couloir", Rect2i(1, 7, 25, 2)],
]
const NOMS := {"salon": "le salon", "manger": "la salle à manger", "cuisine": "la cuisine", "chambre": "une chambre", "bureau": "le bureau",
	"bain": "la salle de bain", "debarras": "le débarras", "entree": "l'entrée", "couloir": "le couloir"}
# le sol de chaque métier : du parquet, du carrelage
const SOLS := {"salon": Color(0.36, 0.25, 0.16), "manger": Color(0.38, 0.27, 0.17), "chambre": Color(0.4, 0.3, 0.2), "bureau": Color(0.3, 0.21, 0.14),
	"cuisine": Color(0.5, 0.5, 0.46), "bain": Color(0.45, 0.52, 0.55), "debarras": Color(0.3, 0.29, 0.27), "entree": Color(0.3, 0.22, 0.15),
	"couloir": Color(0.28, 0.2, 0.14)}
const COUR := 12                  # les lignes de cour devant la maison, clôturées
const PORTE_HAUT := 2.2

var plan: Array = []              # les lignes du plan
var pieces: Array = []            # {type, nom, rect: Rect2i} ; le couloir et l'entrée en sont
var largeur := 0
var profondeur := 0
var porte_x := 12.0               # le milieu de la porte d'entrée
var zone := Rect2()               # la zone de chargement, derrière le camion (x, z)
var camion := Rect2()
var taniere := Vector3.ZERO       # là où dort la chose : la pièce la plus loin de l'entrée
var seuil := Vector3.ZERO         # juste derrière la porte d'entrée : la chose ne va pas plus loin
var grille := AStarGrid2D.new()
var portes: Array = []            # {centre: Vector3, corps: StaticBody3D, forme: CollisionShape3D, verrou: bool}
var lampes: Array = []            # {lumiere: OmniLight3D, ampoule: MeshInstance3D}
var eclairee := true
var _decor: StaticBody3D
var _mats := {}


func construire(graine: int) -> void:
	if graine < 0:
		for l in PLAN_ESSAI:
			plan.append(l)
		for p in PIECES_ESSAI:
			pieces.append({"type": p[0], "nom": NOMS[p[0]], "rect": p[1]})
	else:
		_inventer(graine)
	profondeur = plan.size()
	largeur = plan[0].length()
	var p0: int = plan[profondeur - 1].find("P")
	porte_x = p0 + plan[profondeur - 1].count("P") * 0.5
	zone = Rect2(porte_x - 2.5, profondeur + 1.5, 5.0, 4.5)
	camion = Rect2(porte_x - 1.4, profondeur + 6.6, 2.8, 4.2)
	seuil = Vector3(porte_x, 0.0, profondeur - 1.5)
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
	_tanier()


# --- l'invention d'un plan ---

func _inventer(graine: int) -> void:
	var h := RandomNumberGenerator.new()
	h.seed = graine
	var L: int = [25, 27, 29, 31][h.randi_range(0, 3)]
	var P: int = [17, 19, 21, 23][h.randi_range(0, 3)]
	var g: Array = []
	for z in P:
		var ligne: Array = []
		for x in L:
			ligne.append("#")
		g.append(ligne)
	# le couloir, en travers, large de deux cases
	var c := h.randi_range(maxi(6, P / 2 - 3), P / 2)
	var couloir := Rect2i(1, c, L - 2, 2)
	_creuser(g, couloir)
	# l'entrée : du couloir à la porte, côté cour
	var le := h.randi_range(4, 6)
	var ex := h.randi_range(6, L - le - 6)
	var entree := Rect2i(ex, c + 2, le, P - c - 3)
	_creuser(g, entree)
	var px := ex + le / 2 - 1
	g[P - 1][px] = "P"
	g[P - 1][px + 1] = "P"
	# les pièces : au fond, toute la largeur ; devant, de part et d'autre de l'entrée
	var chambres: Array = []
	_bande(g, h, chambres, 1, L - 2, 1, c - 2, true)
	_bande(g, h, chambres, 1, ex - 2, c + 3, P - 2, false)
	_bande(g, h, chambres, ex + le + 1, L - 2, c + 3, P - 2, false)
	# les portes : chaque pièce qui touche le couloir y ouvre ; entre voisines, et sur l'entrée, une fois sur deux
	var lieux: Array = [couloir, entree]
	lieux.append_array(chambres)
	var liens := {}                # « i-j » → vrai, pour deux lieux qu'une porte relie
	for i in lieux.size():
		for j in range(i + 1, lieux.size()):
			var mur := _mur_commun(lieux[i], lieux[j])
			if mur.is_empty():
				continue
			var chance := 0.5
			if i == 0:
				chance = 1.0
			elif i == 1:
				chance = 0.6
			if h.randf() < chance:
				_percer(g, h, mur, i == 0)
				liens["%d-%d" % [i, j]] = true
	# personne n'est enfermé : une pièce que rien ne relie encore à l'entrée reçoit une porte vers une voisine qui l'est
	var relies := {0: true, 1: true}
	var change := true
	while change:
		change = false
		for cle in liens:
			var a := int(cle.get_slice("-", 0))
			var b := int(cle.get_slice("-", 1))
			if relies.has(a) != relies.has(b):
				relies[a] = true
				relies[b] = true
				change = true
		if not change:
			for i in range(2, lieux.size()):
				if relies.has(i):
					continue
				for j in lieux.size():
					if relies.has(j) and not _mur_commun(lieux[mini(i, j)], lieux[maxi(i, j)]).is_empty():
						_percer(g, h, _mur_commun(lieux[mini(i, j)], lieux[maxi(i, j)]), false)
						liens["%d-%d" % [mini(i, j), maxi(i, j)]] = true
						change = true
						break
				if change:
					break
	for ligne in g:
		plan.append("".join(ligne))
	pieces.append({"type": "couloir", "nom": NOMS["couloir"], "rect": couloir})
	pieces.append({"type": "entree", "nom": NOMS["entree"], "rect": entree})
	_metiers(chambres)


func _creuser(g: Array, r: Rect2i) -> void:
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			g[z][x] = "."


# une bande de pièces côte à côte, de x0 à x1 ; les plus profondes sont parfois coupées en deux, en enfilade
func _bande(g: Array, h: RandomNumberGenerator, sortie: Array, x0: int, x1: int, z0: int, z1: int, fond: bool) -> void:
	var x := x0
	while x <= x1:
		var reste := x1 - x + 1
		var l := reste
		if reste >= 9:                      # de quoi faire deux pièces de quatre, et leur mur
			l = h.randi_range(4, mini(8, reste - 5))
		var profond := z1 - z0 + 1
		if profond >= 9 and l >= 4 and h.randf() < 0.6:
			var p := h.randi_range(4, profond - 5)
			# (celle qui touche le couloir d'abord : au fond de la maison c'est la plus au sud, devant c'est la plus au nord)
			if fond:
				sortie.append(Rect2i(x, z1 - p + 1, l, p))
				sortie.append(Rect2i(x, z0, l, profond - p - 1))
			else:
				sortie.append(Rect2i(x, z0, l, p))
				sortie.append(Rect2i(x, z0 + p + 1, l, profond - p - 1))
		else:
			sortie.append(Rect2i(x, z0, l, profond))
		x += l + 1
	for r in sortie:
		_creuser(g, r)


# le mur que deux lieux ont en commun : ses cases, là où une porte peut s'ouvrir (vide s'ils ne se touchent pas par un mur)
func _mur_commun(a: Rect2i, b: Rect2i) -> Array:
	var cases: Array = []
	if a.end.x + 1 == b.position.x or b.end.x + 1 == a.position.x:          # côte à côte : un mur debout entre eux
		var x := a.end.x if a.end.x + 1 == b.position.x else b.end.x
		for z in range(maxi(a.position.y, b.position.y), mini(a.end.y, b.end.y)):
			cases.append(Vector2i(x, z))
	elif a.end.y + 1 == b.position.y or b.end.y + 1 == a.position.y:        # l'un devant l'autre : un mur couché
		var z := a.end.y if a.end.y + 1 == b.position.y else b.end.y
		for x in range(maxi(a.position.x, b.position.x), mini(a.end.x, b.end.x)):
			cases.append(Vector2i(x, z))
	return cases


# une porte dans ce mur : de deux cases si la place y est (un canapé y passe), sinon d'une
func _percer(g: Array, h: RandomNumberGenerator, mur: Array, grande: bool) -> void:
	var n := 2 if mur.size() >= 2 and (grande or mur.size() >= 3) else 1
	if n == 2 and not grande and h.randf() < 0.35:
		n = 1
	var d := h.randi_range(0, mur.size() - n)
	for i in n:
		g[mur[d + i].y][mur[d + i].x] = "D"


# à chaque pièce son métier : la plus grande est le salon, la suivante la salle à manger, la cuisine la touche si elle peut,
# la plus petite est la salle de bain ; le reste : des chambres, un bureau, un débarras
func _metiers(chambres: Array) -> void:
	var ordre: Array = range(chambres.size())
	ordre.sort_custom(func(a, b): return chambres[a].get_area() > chambres[b].get_area() or (chambres[a].get_area() == chambres[b].get_area() and a < b))
	var metier := {}
	metier[ordre[0]] = "salon"
	if ordre.size() >= 2:
		metier[ordre[1]] = "manger"
	if ordre.size() >= 4:
		metier[ordre[ordre.size() - 1]] = "bain"
	if ordre.size() >= 3:
		var cuisine := -1
		for i in ordre:
			if not metier.has(i) and not _mur_commun(chambres[mini(i, ordre[1])], chambres[maxi(i, ordre[1])]).is_empty():
				cuisine = i
				break
		if cuisine < 0:
			for i in ordre:
				if not metier.has(i):
					cuisine = i
					break
		if cuisine >= 0:
			metier[cuisine] = "cuisine"
	var suite := ["chambre", "bureau", "chambre", "debarras", "chambre", "chambre"]
	var k := 0
	for i in ordre:
		if not metier.has(i):
			metier[i] = suite[k % suite.size()]
			k += 1
	for i in chambres.size():
		pieces.append({"type": metier[i], "nom": NOMS[metier[i]], "rect": chambres[i]})


# --- où l'on est ---

func case_de(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int(floor(p.x)), 0, largeur - 1), clampi(int(floor(p.z)), 0, profondeur + COUR - 1))


func centre(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, 0.0, c.y + 0.5)


func lettre(x: int, z: int) -> String:
	if z < 0 or z >= profondeur or x < 0 or x >= largeur:
		return " "
	return plan[z][x]


func dedans(p: Vector3) -> bool:
	return p.x > 0.0 and p.x < largeur and p.z > 0.0 and p.z < profondeur


func dans_zone(p: Vector3) -> bool:
	return zone.has_point(Vector2(p.x, p.z)) and p.y < 2.5


func depart(k: int) -> Vector3:
	return Vector3(porte_x + [0.0, -1.5, 1.5][k % 3], 0.05, profondeur + 4.0 + float(k / 3) * 1.2)     # dans la zone, le premier face à la porte


# dans une pièce, ce qu'il faut laisser libre devant chacune de ses portes et de ses ouvertures (des rectangles, en mètres)
func devants_de_porte(r: Rect2i) -> Array:
	var libres: Array = []
	for x in range(r.position.x, r.end.x):
		if lettre(x, r.position.y - 1) in ["D", "P", "."]:
			libres.append(Rect2(x, r.position.y, 1.0, 1.4))
		if lettre(x, r.end.y) in ["D", "P", "."]:
			libres.append(Rect2(x, r.end.y - 1.4, 1.0, 1.4))
	for z in range(r.position.y, r.end.y):
		if lettre(r.position.x - 1, z) in ["D", "P"]:
			libres.append(Rect2(r.position.x, z, 1.4, 1.0))
		if lettre(r.end.x, z) in ["D", "P"]:
			libres.append(Rect2(r.end.x - 1.4, z, 1.4, 1.0))
	return libres


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
	return taniere


# voit-on d'un point à l'autre ? Seuls les murs et les portes claquées cachent.
func voit(de: Vector3, vers: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(de, vers, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# --- ce que le chat peut faire à la maison ---

func lumieres(oui: bool) -> void:
	eclairee = oui
	for l in lampes:
		l.lumiere.visible = oui
		l.ampoule.material_override = mat(Color(1.0, 0.85, 0.55), 2.5) if oui else mat(Color(0.12, 0.11, 0.1))


func verrouiller(i: int, oui: bool) -> void:
	if i < 0 or i >= portes.size():
		return
	var p: Dictionary = portes[i]
	p.verrou = oui
	p.corps.visible = oui
	p.forme.disabled = not oui


# --- la construction ---

func mat(c: Color, lueur: float = 0.0) -> StandardMaterial3D:
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


# un meuble fixe (une baignoire, un plan de travail, un tapis) : des boîtes posées en un point, tournées ; solide ou non
func ajouter_decor(d: Dictionary) -> void:
	var corps := StaticBody3D.new()
	corps.collision_layer = 1 if d.get("solide", true) else 0
	corps.collision_mask = 0
	corps.position = d.pos
	corps.rotation.y = d.yaw
	add_child(corps)
	for b in d.boites:
		_boite(corps, b[0], b[1], mat(b[2]), d.get("solide", true))


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
	_boite(_decor, Vector3(l * 0.5, -0.06, p * 0.5 + 10.0), Vector3(90.0, 0.1, 90.0), mat(Color(0.07, 0.11, 0.08)), false)   # l'herbe
	_boite(_decor, Vector3(porte_x, -0.04, p + 1.0), Vector3(3.0, 0.1, 2.0), mat(Color(0.3, 0.3, 0.31)), false)              # le seuil
	# le plancher et le plafond, par morceaux : une lampe n'éclaire que ce qui est près d'elle, et chaque morceau n'en compte que peu
	var sombre := mat(Color(0.22, 0.16, 0.11))
	var plafond := mat(Color(0.2, 0.19, 0.18))
	for z in range(0, profondeur, 6):
		for x in range(0, largeur, 6):
			var t := Vector2(mini(6, largeur - x), mini(6, profondeur - z))
			var milieu := Vector3(x + t.x * 0.5, 0.0, z + t.y * 0.5)
			_boite(_decor, milieu + Vector3(0, -0.06, 0), Vector3(t.x, 0.1, t.y), sombre, false)
			_boite(_decor, milieu + Vector3(0, R.HAUTEUR + 0.15, 0), Vector3(t.x, 0.3, t.y), plafond)
	for piece in pieces:                   # le sol de chaque pièce, à sa couleur
		var r: Rect2i = piece.rect
		_boite(_decor, Vector3(r.position.x + r.size.x * 0.5, -0.045, r.position.y + r.size.y * 0.5), Vector3(r.size.x, 0.1, r.size.y), mat(SOLS[piece.type]), false)
	# la clôture de la cour : trois côtés
	var bois := mat(Color(0.16, 0.12, 0.09))
	var fond := p + float(COUR)
	_boite(_decor, Vector3(0.5, 1.5, p + COUR * 0.5), Vector3(0.3, 3.0, COUR), bois)
	_boite(_decor, Vector3(l - 0.5, 1.5, p + COUR * 0.5), Vector3(0.3, 3.0, COUR), bois)
	_boite(_decor, Vector3(l * 0.5, 1.5, fond - 0.5), Vector3(l, 3.0, 0.3), bois)


func _murs() -> void:
	var mur := mat(Color(0.5, 0.47, 0.4))
	var battant := mat(Color(0.28, 0.17, 0.1))
	var haut: float = R.HAUTEUR - PORTE_HAUT
	for z in profondeur:
		var x := 0
		while x < largeur:
			var l: String = plan[z][x]
			var n := 1
			while x + n < largeur and plan[z][x + n] == l:
				n += 1
			if l == "#":
				_boite(_decor, Vector3(x + n * 0.5, R.HAUTEUR * 0.5, z + 0.5), Vector3(n, R.HAUTEUR, 1.0), mur)
			elif l == "D" or l == "P":
				_boite(_decor, Vector3(x + n * 0.5, PORTE_HAUT + haut * 0.5, z + 0.5), Vector3(n, haut, 1.0), mur)
			x += n
	# les portes du dedans : un battant par porte, couché ou debout selon son mur
	var vues := {}
	for z in profondeur:
		for x in largeur:
			if plan[z][x] != "D" or vues.has(Vector2i(x, z)):
				continue
			var nx := 1
			while lettre(x + nx, z) == "D":
				nx += 1
			var nz := 1
			while nx == 1 and lettre(x, z + nz) == "D":
				nz += 1
			var debout := nz > 1 or (nx == 1 and lettre(x, z - 1) == "#" and lettre(x, z + 1) == "#")    # le mur court du nord au sud
			for i in nx:
				for k in nz:
					vues[Vector2i(x + i, z + k)] = true
			_porte(Vector3(x + nx * 0.5, PORTE_HAUT * 0.5, z + nz * 0.5), Vector3(0.2 if debout else float(nx), PORTE_HAUT, float(nz) if debout else 0.2), battant)


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
	for piece in pieces:
		var r: Rect2i = piece.rect
		var n := maxi(1, int(ceil(maxi(r.size.x, r.size.y) / 11.0)))
		for i in n:
			var f := (i + 0.5) / n
			var ou := Vector2(r.position.x + r.size.x * (f if r.size.x >= r.size.y else 0.5), r.position.y + r.size.y * (0.5 if r.size.x >= r.size.y else f))
			_lampe(ou)


func _lampe(p: Vector2) -> void:
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
	a.material_override = mat(Color(1.0, 0.85, 0.55), 2.5)
	add_child(a)
	lampes.append({"lumiere": l, "ampoule": a})


func _camion() -> void:
	# la zone de chargement : quatre bandes jaunes au sol
	var jaune := mat(Color(0.95, 0.75, 0.15), 0.6)
	var z := zone
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
	var k := camion
	var cx := k.position.x + k.size.x * 0.5
	_boite(corps, Vector3(cx, 1.6, k.position.y + 1.4), Vector3(k.size.x, 2.4, 2.8), mat(Color(0.75, 0.73, 0.68)))
	_boite(corps, Vector3(cx, 1.2, k.end.y - 0.6), Vector3(k.size.x - 0.3, 1.9, 1.2), mat(Color(0.7, 0.25, 0.12)))
	_boite(corps, Vector3(cx, 0.25, k.position.y + k.size.y * 0.5), Vector3(k.size.x - 0.4, 0.5, k.size.y - 0.4), mat(Color(0.06, 0.06, 0.07)))
	var rouge := mat(Color(1.0, 0.15, 0.1), 2.0)
	_boite(self, Vector3(cx - 1.1, 0.8, k.position.y - 0.03), Vector3(0.25, 0.18, 0.05), rouge, false)
	_boite(self, Vector3(cx + 1.1, 0.8, k.position.y - 0.03), Vector3(0.25, 0.18, 0.05), rouge, false)
	var phare := OmniLight3D.new()
	phare.position = Vector3(cx, 2.9, k.position.y - 0.6)
	phare.light_color = Color(0.8, 0.88, 1.0)
	phare.light_energy = 1.1
	phare.omni_range = 9.0
	add_child(phare)
	var porche := OmniLight3D.new()
	porche.position = Vector3(porte_x, 2.5, profondeur + 0.6)
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
				mur = plan[ligne][c] == "#"
			else:
				mur = c == 0 or c == largeur - 1 or ligne == profondeur + COUR - 1 \
					or camion.grow(0.3).intersects(Rect2(c, ligne, 1.0, 1.0))
			if mur:
				grille.set_point_solid(Vector2i(c, ligne), true)


# la tanière : le milieu de la pièce la plus loin de l'entrée, par le chemin
func _tanier() -> void:
	var loin := -1
	for piece in pieces:
		if piece.type == "couloir" or piece.type == "entree":
			continue
		var r: Rect2i = piece.rect
		var milieu := Vector3(r.position.x + r.size.x * 0.5, 0.0, r.position.y + r.size.y * 0.5)
		var n := chemin(seuil, milieu).size()
		if n > loin:
			loin = n
			taniere = centre(case_de(milieu))
