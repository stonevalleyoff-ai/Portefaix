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
const Boites = preload("res://scripts/boites.gd")

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
# la lampe d'une pièce bonus : sa couleur, sa force (les autres ont la lampe de tout le monde)
const LUEURS := {"cave": [Color(1.0, 0.18, 0.1), 0.9], "arcade": [Color(0.7, 0.3, 1.0), 1.5], "tresor": [Color(1.0, 0.9, 0.6), 2.0], "trone": [Color(1.0, 0.85, 0.5), 2.0],
	"nains": [Color(0.6, 1.0, 0.6), 1.1]}
const NOMS := {"cave": "la cave au rituel", "garage": "le garage", "tresor": "la chambre forte", "arcade": "la salle d'arcade",
	"nains": "le cercle des nains", "trone": "la salle du trône", "salon": "le salon", "manger": "la salle à manger", "cuisine": "la cuisine", "chambre": "une chambre", "bureau": "le bureau",
	"bain": "la salle de bain", "debarras": "le débarras", "entree": "l'entrée", "couloir": "le couloir",
	"palier": "l'escalier", "buanderie": "la buanderie", "chaufferie": "la chaufferie"}
# le sol de chaque métier : du parquet, du carrelage
const SOLS := {"cave": Color(0.15, 0.14, 0.15), "garage": Color(0.4, 0.4, 0.41), "tresor": Color(0.2, 0.22, 0.28), "arcade": Color(0.2, 0.1, 0.3),
	"nains": Color(0.16, 0.4, 0.16), "trone": Color(0.45, 0.07, 0.1), "salon": Color(0.36, 0.25, 0.16), "manger": Color(0.38, 0.27, 0.17), "chambre": Color(0.4, 0.3, 0.2), "bureau": Color(0.3, 0.21, 0.14),
	"cuisine": Color(0.5, 0.5, 0.46), "bain": Color(0.45, 0.52, 0.55), "debarras": Color(0.3, 0.29, 0.27), "entree": Color(0.3, 0.22, 0.15),
	"couloir": Color(0.28, 0.2, 0.14), "buanderie": Color(0.42, 0.44, 0.45), "chaufferie": Color(0.24, 0.23, 0.22), "palier": Color(0.22, 0.16, 0.11)}
const PAS := R.HAUTEUR + 0.3      # d'un plancher au suivant
const CAGE := 10                  # la cage d'escalier, au bout du couloir : dix cases de long, quatre de large
const COUR := 12                  # les lignes de cour devant la maison, clôturées
const PORTE_HAUT := 2.2

var plan: Array = []              # les lignes du plan du rez-de-chaussée
var plans := {}                   # le plan de chaque niveau : -1 le sous-sol, 0 le rez-de-chaussée, 1 l'étage
var niveaux: Array = [0]
var etages_voulus := false        # pour les essais : la maison d'essai aussi a son étage et son sous-sol
var cage := Rect2i()              # la cage d'escalier (vide : une maison de plain-pied)
var escaliers: Array = []         # {de: le niveau du bas, bas: Vector3, haut: Vector3, rect: Rect2 (les marches), xb, xh}
var grilles := {}                 # la grille de chaque niveau
var pieces: Array = []            # {type, nom, rect: Rect2i, niveau} ; les couloirs, l'entrée et les paliers en sont
var bonus: Array = []             # les pièces bonus de cette maison (leur type) ; vide, c'est une maison ordinaire
var bonus_voulu: Array = []       # pour les essais : ces pièces bonus-là, sans tirer au sort
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
var _antre := Rect2i()            # la pièce de la tanière
var _antre_n := 0
var fixes: Array = []             # la place au sol de ce qui tient à la maison (une baignoire, un plan de travail)
var fixes_n: Array = []           # et le niveau de chacun
var _vu_n := 0                     # d'où le joueur regarde : son niveau, et s'il est près de la cage
var _vu_pres := false
var _pans := {}                    # les boîtes du décor, à fondre : par niveau et par carré de six mètres
var _niveau_bati := 0
var _couche := 1                  # la couche de ce qu'on bâtit : les lampes d'un niveau n'éclairent que lui
var _mats := {}


func construire(graine: int) -> void:
	if graine < 0:
		for l in PLAN_ESSAI:
			plan.append(l)
		for p in PIECES_ESSAI:
			pieces.append({"type": p[0], "nom": NOMS[p[0]], "rect": p[1], "niveau": 0})
		if etages_voulus:
			var h := RandomNumberGenerator.new()
			h.seed = 7
			_etager(h, plan[0].length(), plan.size(), 7)
		_primer(bonus_voulu)
	else:
		_inventer(graine)
	plans[0] = plan
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
	for n in niveaux:
		_murs(n)
	_marches()
	_lampes()
	_couche = 1
	_camion()
	for n in niveaux:
		_grille(n)
	grille = grilles[0]
	_tanier()
	_fondre()


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
	var lieux: Array = [couloir, entree]
	lieux.append_array(chambres)
	_relier(g, h, lieux, true)
	for ligne in g:
		plan.append("".join(ligne))
	pieces.append({"type": "couloir", "nom": NOMS["couloir"], "rect": couloir, "niveau": 0})
	pieces.append({"type": "entree", "nom": NOMS["entree"], "rect": entree, "niveau": 0})
	_metiers(chambres, 0)
	_etager(h, L, P, c)
	# la maison bonus : une chance sur quatre (un tirage à part : le plan d'une graine n'en dépend pas)
	if not bonus_voulu.is_empty():
		_primer(bonus_voulu)
	else:
		_primer(tirage_bonus(graine).slice(0, 3 if chambres.size() >= 8 else 2))


# les portes : chaque pièce qui touche le couloir y ouvre ; entre voisines, et sur l'entrée, une fois sur deux
func _relier(g: Array, h: RandomNumberGenerator, lieux: Array, entree: bool) -> void:
	var liens := {}                # « i-j » → vrai, pour deux lieux qu'une porte relie
	for i in lieux.size():
		for j in range(i + 1, lieux.size()):
			var mur := _mur_commun(lieux[i], lieux[j])
			if mur.is_empty():
				continue
			var chance := 0.5
			if i == 0:
				chance = 1.0
			elif i == 1 and entree:
				chance = 0.6
			if h.randf() < chance:
				_percer(g, h, mur, i == 0)
				liens["%d-%d" % [i, j]] = true
	# personne n'est enfermé : une pièce que rien ne relie encore au couloir reçoit une porte vers une voisine qui l'est
	var relies := {0: true}
	if entree:
		relies[1] = true
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
			for i in range(1, lieux.size()):
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


# l'étage et le sous-sol. Au bout du couloir, côté est, la maison s'allonge d'une cage d'escalier : un palier, deux volées côte à côte
# (celle du nord monte à l'étage, celle du sud descend au sous-sol), un palier au bout. Chaque niveau a son couloir, au-dessus de celui
# du rez-de-chaussée, et ses pièces : toute la maison à l'étage, le fond seulement au sous-sol (devant, c'est la terre).
#   L, P : la maison sans sa cage ; c : la ligne du couloir
func _etager(h: RandomNumberGenerator, L: int, P: int, c: int) -> void:
	niveaux = [-1, 0, 1]
	cage = Rect2i(L - 1, c - 1, CAGE, 4)
	var g0: Array = []
	for ligne in plan:
		var cases: Array = []
		for x in L + CAGE:
			cases.append(ligne[x] if x < ligne.length() else "#")
		g0.append(cases)
	_creuser_cage(g0, 0)
	plan = []
	for ligne in g0:
		plan.append("".join(ligne))
	pieces.append({"type": "palier", "nom": NOMS["palier"], "rect": cage, "niveau": 0})
	for n in [1, -1]:
		var g: Array = []
		for z in P:
			var ligne: Array = []
			for x in L + CAGE:
				ligne.append("#")
			g.append(ligne)
		var couloir := Rect2i(1, c, L - 2, 2)
		_creuser(g, couloir)
		var chambres: Array = []
		_bande(g, h, chambres, 1, L - 2, 1, c - 2, true)
		if n == 1:
			_bande(g, h, chambres, 1, L - 2, c + 3, P - 2, false)
		var lieux: Array = [couloir]
		lieux.append_array(chambres)
		_relier(g, h, lieux, false)
		_creuser_cage(g, n)
		var lignes: Array = []
		for ligne in g:
			lignes.append("".join(ligne))
		plans[n] = lignes
		pieces.append({"type": "couloir", "nom": "le couloir de l'étage" if n == 1 else "le couloir du sous-sol", "rect": couloir, "niveau": n})
		pieces.append({"type": "palier", "nom": NOMS["palier"], "rect": cage, "niveau": n})
		_metiers(chambres, n)
	# les deux escaliers : d'où l'on y entre en bas, où l'on en sort en haut, et leurs marches
	var x := float(cage.position.x)
	var z := float(cage.position.y)
	escaliers.append({"de": 0, "bas": Vector3(x + 1.0, 0.0, z + 1.0), "haut": Vector3(x + 9.0, PAS, z + 1.0), "rect": Rect2(x + 2.0, z, 6.0, 2.0), "xb": x + 2.0, "xh": x + 8.0})
	escaliers.append({"de": -1, "bas": Vector3(x + 9.0, -PAS, z + 3.0), "haut": Vector3(x + 1.0, 0.0, z + 3.0), "rect": Rect2(x + 2.0, z + 2.0, 6.0, 2.0), "xb": x + 8.0, "xh": x + 2.0})


# la cage, à ce niveau : « e » des marches qui montent d'ici, « v » le vide au-dessus de marches qui arrivent d'en dessous
func _creuser_cage(g: Array, n: int) -> void:
	for k in CAGE:
		for r in 4:
			var l := "."
			if k >= 2 and k < 8:
				if n == 0:
					l = "e" if r < 2 else "v"
				elif n == 1:
					l = "v" if r < 2 else "."
				else:
					l = "." if r < 2 else "e"
			elif k >= 8 and n == 0:
				l = "#"                  # (sous le palier de l'étage, au-dessus de celui du sous-sol)
			g[cage.position.y + r][cage.position.x + k] = l


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


# à chaque pièce son métier. Au rez-de-chaussée : la plus grande est le salon, la suivante la salle à manger, la cuisine la touche si
# elle peut ; le reste : un bureau, une chambre, un débarras. À l'étage : des chambres, la salle de bain (la plus petite), un bureau.
# Au sous-sol : la buanderie, la chaufferie, des débarras. Une maison de plain-pied a tout au même niveau.
func _metiers(chambres: Array, n: int) -> void:
	var ordre: Array = range(chambres.size())
	ordre.sort_custom(func(a, b): return chambres[a].get_area() > chambres[b].get_area() or (chambres[a].get_area() == chambres[b].get_area() and a < b))
	var metier := {}
	var suite := ["bureau", "chambre", "debarras", "chambre", "bureau", "chambre"]
	if n == 0:
		metier[ordre[0]] = "salon"
		if ordre.size() >= 2:
			metier[ordre[1]] = "manger"
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
	elif n == 1:
		suite = ["chambre", "chambre", "bureau", "chambre", "debarras", "chambre"]
		if ordre.size() >= 2:
			metier[ordre[ordre.size() - 1]] = "bain"
	else:
		suite = ["buanderie", "debarras", "chaufferie", "debarras", "debarras"]
	var k := 0
	for i in ordre:
		if not metier.has(i):
			metier[i] = suite[k % suite.size()]
			k += 1
	for i in chambres.size():
		pieces.append({"type": metier[i], "nom": NOMS[metier[i]], "rect": chambres[i], "niveau": n})


# ce que la graine réserve : rien (trois fois sur quatre), ou les pièces bonus de la maison, dans l'ordre où elles viendront
static func tirage_bonus(graine: int) -> Array:
	var h := RandomNumberGenerator.new()
	h.seed = graine * 7919 + 13
	if h.randf() >= R.CHANCE_BONUS:
		return []
	var sortes: Array = R.BONUS.duplicate()
	for i in range(sortes.size() - 1, 0, -1):
		var k := h.randi_range(0, i)
		var x = sortes[i]
		sortes[i] = sortes[k]
		sortes[k] = x
	return sortes


# des pièces ordinaires deviennent des pièces bonus : les débarras d'abord, puis le bureau, puis les chambres en trop (il en reste une)
func _primer(sortes: Array) -> void:
	var candidates: Array = []
	var gardee := -1
	for metier in ["debarras", "bureau", "chambre"]:
		var du_metier: Array = []
		for i in pieces.size():
			if pieces[i].type == metier:
				du_metier.append(i)
		if metier == "chambre" and not du_metier.is_empty():
			gardee = du_metier.pop_front()
		candidates.append_array(du_metier)
	if not bonus_voulu.is_empty() and gardee >= 0:      # (aux essais, on prend aussi la dernière chambre)
		candidates.append(gardee)
	for k in mini(sortes.size(), candidates.size()):
		var voulu: int = {"cave": -1, "garage": 0}.get(sortes[k], 9)      # la cave au sous-sol, le garage de plain-pied, si la place y est
		for i in range(k, candidates.size()):
			if pieces[candidates[i]].niveau == voulu:
				var x = candidates[k]
				candidates[k] = candidates[i]
				candidates[i] = x
				break
		var p: Dictionary = pieces[candidates[k]]
		p.type = sortes[k]
		p.nom = NOMS[sortes[k]]
		bonus.append(sortes[k])


# --- où l'on est ---

func case_de(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int(floor(p.x)), 0, largeur - 1), clampi(int(floor(p.z)), 0, profondeur + COUR - 1))


func y_de(n: int) -> float:
	return n * PAS


# à cette hauteur, à quel niveau est-on ? (dans un escalier : celui d'en bas, jusqu'aux dernières marches)
func niveau_de(y: float) -> int:
	return clampi(int(floor((y + 0.8) / PAS)), niveaux.min(), niveaux.max())


# la couche de ce qu'on voit à ce niveau. Une seule pour tous : séparer les niveaux par couches, chacune avec ses lampes, laissait l'écran
# noir sous Firefox (Windows). On n'en a plus besoin : seules les lampes du niveau où l'on est sont allumées (regarder_de).
func couche(_n: int) -> int:
	return 1


func centre(c: Vector2i, n: int = 0) -> Vector3:
	return Vector3(c.x + 0.5, y_de(n), c.y + 0.5)


func lettre(x: int, z: int, n: int = 0) -> String:
	if z < 0 or z >= profondeur or x < 0 or x >= largeur or not plans.has(n):
		return " "
	return plans[n][z][x]


# l'escalier où l'on est (sur ses marches), ou rien
func escalier_sous(p: Vector3):
	for e in escaliers:
		if e.rect.has_point(Vector2(p.x, p.z)) and p.y > y_de(e.de) - 0.6 and p.y < y_de(e.de) + PAS + 0.6:
			return e
	return null


# la hauteur du sol sous ce point : celle de son niveau, ou celle de la marche
func sol(p: Vector3) -> float:
	var e = escalier_sous(p)
	if e != null:
		return y_de(e.de) + clampf((p.x - e.xb) / (e.xh - e.xb), 0.0, 1.0) * PAS
	return y_de(niveau_de(p.y))


# pour aller du niveau a vers le niveau b : l'escalier à prendre, par où l'on y entre, par où l'on en sort
func escalier_entre(a: int, b: int) -> Dictionary:
	for e in escaliers:
		if b > a and e.de == a:
			return {"entree": e.bas, "sortie": e.haut}
		if b < a and e.de == a - 1:
			return {"entree": e.haut, "sortie": e.bas}
	return {}


func dedans(p: Vector3) -> bool:
	return p.x > 0.0 and p.x < largeur and p.z > 0.0 and p.z < profondeur


func dans_zone(p: Vector3) -> bool:
	return zone.has_point(Vector2(p.x, p.z)) and p.y < 2.5


func depart(k: int) -> Vector3:
	return Vector3(porte_x + [0.0, -1.5, 1.5][k % 3], 0.05, profondeur + 4.0 + float(k / 3) * 1.2)     # dans la zone, le premier face à la porte


# dans une pièce, ce qu'il faut laisser libre devant chacune de ses portes et de ses ouvertures (des rectangles, en mètres)
func devants_de_porte(r: Rect2i, n: int = 0) -> Array:
	var libres: Array = []
	for x in range(r.position.x, r.end.x):
		if lettre(x, r.position.y - 1, n) in ["D", "P", "."]:
			libres.append(Rect2(x, r.position.y, 1.0, 1.4))
		if lettre(x, r.end.y, n) in ["D", "P", "."]:
			libres.append(Rect2(x, r.end.y - 1.4, 1.0, 1.4))
	for z in range(r.position.y, r.end.y):
		if lettre(r.position.x - 1, z, n) in ["D", "P", "."]:
			libres.append(Rect2(r.position.x, z, 1.4, 1.0))
		if lettre(r.end.x, z, n) in ["D", "P", "."]:       # (le couloir s'ouvre sur le palier)
			libres.append(Rect2(r.end.x - 1.4, z, 1.4, 1.0))
	return libres


# le chemin de la chose, de case en case (vide s'il n'y en a pas) ; d'un niveau à l'autre, par les escaliers
func chemin(de: Vector3, vers: Vector3) -> PackedVector3Array:
	var sortie := PackedVector3Array()
	var n := niveau_de(de.y)
	var but := niveau_de(vers.y)
	var ici := de
	while n != but:
		var e := escalier_entre(n, but)
		if e.is_empty():
			return PackedVector3Array()
		var bout := _chemin_plat(ici, e.entree, n)
		if bout.is_empty():
			return PackedVector3Array()
		sortie.append_array(bout)
		ici = e.sortie
		n += 1 if but > n else -1
	var fin := _chemin_plat(ici, vers, n)
	if fin.is_empty():
		return PackedVector3Array()
	sortie.append_array(fin)
	return sortie


func _chemin_plat(de: Vector3, vers: Vector3, n: int) -> PackedVector3Array:
	var sortie := PackedVector3Array()
	var g: AStarGrid2D = grilles[n]
	var a := case_de(de)
	var b := case_de(vers)
	if not g.is_in_boundsv(a) or not g.is_in_boundsv(b):
		return sortie
	if g.is_point_solid(b):
		b = _case_libre_pres(g, b)
	if g.is_point_solid(a):
		a = _case_libre_pres(g, a)
	for c in g.get_id_path(a, b):
		sortie.append(centre(c, n))
	return sortie


func _case_libre_pres(g: AStarGrid2D, c: Vector2i) -> Vector2i:
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var v := Vector2i(c.x + dx, c.y + dy)
				if g.is_in_boundsv(v) and not g.is_point_solid(v):
					return v
	return c


# une case de sol dans la maison, au hasard, à n'importe quel niveau (là où va rôder la chose)
func case_au_hasard(h: RandomNumberGenerator) -> Vector3:
	for i in 50:
		var n: int = niveaux[h.randi_range(0, niveaux.size() - 1)]
		var c := Vector2i(h.randi_range(1, largeur - 2), h.randi_range(1, profondeur - 2))
		if not grilles[n].is_point_solid(c):
			return centre(c, n)
	return taniere


# voit-on d'un point à l'autre ? Les murs et les portes claquées cachent ; et les meubles, si on le demande.
func voit(de: Vector3, vers: Vector3, masque: int = 1) -> bool:
	var q := PhysicsRayQueryParameters3D.create(de, vers, masque)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# --- ce que le chat peut faire à la maison ---

# près de la cage d'escalier (à moins de tant de mètres), on voit un peu des autres niveaux : leurs lampes et leurs meubles de là
const VUE_CAGE := 7.0
const AUTOUR_CAGE := 9.0

# voit-on ce point, d'où l'on est ? Ce qui est à son niveau, toujours ; d'un autre, seulement autour de la cage, quand on en est près
func en_vue(p: Vector3, n: int) -> bool:
	return n == _vu_n or (_vu_pres and Rect2(cage).grow(AUTOUR_CAGE).has_point(Vector2(p.x, p.z)))


# le joueur est à ce niveau, à cet endroit : n'allumer que les lampes qu'il peut voir (le moteur n'en dessine qu'une trentaine à la fois,
# et un téléphone bien moins sans peine ; au-delà, l'écran s'éteint)
func regarder_de(p: Vector3) -> void:
	_vu_n = niveau_de(p.y)
	_vu_pres = cage.size.x > 0 and Rect2(cage).grow(VUE_CAGE).has_point(Vector2(p.x, p.z))
	for l in lampes:
		l.lumiere.visible = eclairee and en_vue(l.lumiere.position, l.niveau)


func lumieres(oui: bool) -> void:
	eclairee = oui
	for l in lampes:
		l.lumiere.visible = oui and en_vue(l.lumiere.position, l.niveau)
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


func _teinte_qui_luit(lueur: float) -> StandardMaterial3D:
	var cle := "teinte/%s" % lueur
	if not _mats.has(cle):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.9
		m.emission_enabled = true
		m.emission = Color(0.75, 0.05, 0.04)
		m.emission_energy_multiplier = lueur
		_mats[cle] = m
	return _mats[cle]


func _boite(parent: Node3D, c: Vector3, t: Vector3, m: Material, solide: bool = true) -> void:
	if parent == _decor and m is StandardMaterial3D and not m.emission_enabled:
		# une boîte du décor : on ne la dessine pas seule, on la fondra avec ses voisines (_fondre)
		var cle := Vector3i(int(floor(c.x / 6.0)), int(round(c.y / PAS)), int(floor(c.z / 6.0)))
		if not _pans.has(cle):
			_pans[cle] = Boites.new()
		_pans[cle].ajouter(c, t, m.albedo_color)
	else:
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


# le décor, fondu : un maillage par carré de six mètres et par niveau (une lampe n'éclaire que ce qui est près d'elle, et chaque
# maillage n'en compte que peu), au lieu d'un par mur
func _fondre() -> void:
	for cle in _pans:
		var mesh: MeshInstance3D = _pans[cle].noeud()
		mesh.name = "Pan_%d_%d_%d" % [cle.x, cle.y, cle.z]
		add_child(mesh)
	_pans.clear()


# un meuble fixe (une baignoire, un plan de travail, un tapis) : des boîtes posées en un point, tournées ; solide ou non
func ajouter_decor(d: Dictionary) -> void:
	var corps := StaticBody3D.new()
	corps.collision_layer = 1 if d.get("solide", true) else 0
	corps.collision_mask = 0
	corps.position = d.pos
	corps.rotation.y = d.yaw
	add_child(corps)
	_couche = couche(niveau_de(d.pos.y))
	var fondu := Boites.new()        # ce qui ne luit pas : un seul maillage pour tout le meuble
	for b in d.boites:               # (une boîte : son milieu, sa taille, sa couleur ; et, si elle est tournée ou qu'elle luit, de combien)
		var tour: float = b[3] if b.size() > 3 else 0.0
		var lueur: float = b[4] if b.size() > 4 else 0.0
		if lueur > 0.0 and tour == 0.0:
			_boite(corps, b[0], b[1], mat(b[2], lueur), d.get("solide", true))
			continue
		fondu.ajouter(b[0], b[1], b[2], Basis(Vector3.UP, tour))
		if d.get("solide", true):
			var forme := CollisionShape3D.new()
			var s := BoxShape3D.new()
			s.size = b[1]
			forme.shape = s
			forme.position = b[0]
			forme.rotation.y = tour
			corps.add_child(forme)
	if not fondu.vide():
		var mesh := fondu.noeud()
		if d.boites[0].size() > 4 and d.boites[0][4] > 0.0:      # (un tracé qui luit, au sol : toutes ses boîtes luisent pareil)
			mesh.material_override = _teinte_qui_luit(d.boites[0][4])
		corps.add_child(mesh)


func _sol() -> void:
	var l := float(largeur)
	var p := float(profondeur)
	_couche = 1
	# la cour : un sol solide, devant la maison (dans la maison, chaque niveau a son plancher : il faut des trous pour les escaliers)
	var forme := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(160.0, 1.0, 120.0)
	forme.shape = s
	forme.position = Vector3(l * 0.5, -0.5, p + 60.0)
	_decor.add_child(forme)
	_boite(_decor, Vector3(l * 0.5, -0.06, p + 10.0), Vector3(110.0, 0.1, 90.0), mat(Color(0.07, 0.11, 0.08)), false)        # l'herbe
	_boite(_decor, Vector3(porte_x, -0.04, p + 1.0), Vector3(3.0, 0.1, 2.0), mat(Color(0.3, 0.3, 0.31)), false)              # le seuil
	for n in niveaux:
		_plancher(n, n == niveaux.min())
	_plancher(niveaux.max() + 1, false)        # le toit
	for piece in pieces:                   # le sol de chaque pièce, à sa couleur
		if piece.type == "palier":
			continue
		var r: Rect2i = piece.rect
		_couche = couche(piece.niveau)
		_boite(_decor, Vector3(r.position.x + r.size.x * 0.5, y_de(piece.niveau) - 0.045, r.position.y + r.size.y * 0.5), Vector3(r.size.x, 0.1, r.size.y), mat(SOLS[piece.type]), false)
	_couche = 1
	# la clôture de la cour : trois côtés
	var bois := mat(Color(0.16, 0.12, 0.09))
	var fond := p + float(COUR)
	_boite(_decor, Vector3(0.5, 1.5, p + COUR * 0.5), Vector3(0.3, 3.0, COUR), bois)
	_boite(_decor, Vector3(l - 0.5, 1.5, p + COUR * 0.5), Vector3(0.3, 3.0, COUR), bois)
	_boite(_decor, Vector3(l * 0.5, 1.5, fond - 0.5), Vector3(l, 3.0, 0.3), bois)


# le plancher d'un niveau, qui est aussi le plafond de celui d'en dessous : par morceaux (une lampe n'éclaire que ce qui est près
# d'elle, et chaque morceau n'en compte que peu), et troué là où passe un escalier
func _plancher(n: int, fond: bool) -> void:
	for z0 in range(0, profondeur, 6):
		for x0 in range(0, largeur, 6):
			var t := Vector2i(mini(6, largeur - x0), mini(6, profondeur - z0))
			var troue := false
			for z in range(z0, z0 + t.y):
				for x in range(x0, x0 + t.x):
					troue = troue or lettre(x, z, n) == "v"
			if not troue:
				_dalle(n, fond, Rect2(x0, z0, t.x, t.y))
				continue
			for z in range(z0, z0 + t.y):            # autour du trou : ligne à ligne
				var x := x0
				while x < x0 + t.x:
					var k := 0
					while x + k < x0 + t.x and lettre(x + k, z, n) != "v":
						k += 1
					if k > 0:
						_dalle(n, fond, Rect2(x, z, k, 1))
					x += k + 1


func _dalle(n: int, fond: bool, r: Rect2) -> void:
	var y := y_de(n)
	var milieu := Vector3(r.position.x + r.size.x * 0.5, y, r.position.y + r.size.y * 0.5)
	var forme := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(r.size.x, 0.3, r.size.y)
	forme.shape = s
	forme.position = milieu + Vector3(0, -0.15, 0)
	_decor.add_child(forme)
	if n <= niveaux.max():                 # le dessus, qu'éclairent les lampes de ce niveau
		_couche = couche(n)
		_boite(_decor, milieu + Vector3(0, -0.085, 0), Vector3(r.size.x, 0.15, r.size.y), mat(Color(0.22, 0.16, 0.11)), false)
	if not fond:                           # le dessous : le plafond du niveau d'en dessous
		_couche = couche(n - 1)
		_boite(_decor, milieu + Vector3(0, -0.225, 0), Vector3(r.size.x, 0.15, r.size.y), mat(Color(0.2, 0.19, 0.18)), false)


func _murs(n: int) -> void:
	var mur := mat(Color(0.5, 0.47, 0.4) if n >= 0 else Color(0.36, 0.35, 0.34))
	var battant := mat(Color(0.28, 0.17, 0.1))
	var haut: float = R.HAUTEUR - PORTE_HAUT
	var y := y_de(n)
	var p: Array = plans[n]
	_couche = couche(n)
	for z in profondeur:
		var x := 0
		while x < largeur:
			var l: String = p[z][x]
			var k := 1
			while x + k < largeur and p[z][x + k] == l and k < 8:      # (par morceaux de huit mètres au plus : les lampes)
				k += 1
			if l == "#":
				_boite(_decor, Vector3(x + k * 0.5, y + R.HAUTEUR * 0.5, z + 0.5), Vector3(k, R.HAUTEUR, 1.0), mur)
			elif l == "D" or l == "P":
				_boite(_decor, Vector3(x + k * 0.5, y + PORTE_HAUT + haut * 0.5, z + 0.5), Vector3(k, haut, 1.0), mur)
			x += k
	# les portes du dedans : un battant par porte, couché ou debout selon son mur
	var vues := {}
	for z in profondeur:
		for x in largeur:
			if p[z][x] != "D" or vues.has(Vector2i(x, z)):
				continue
			var nx := 1
			while lettre(x + nx, z, n) == "D":
				nx += 1
			var nz := 1
			while nx == 1 and lettre(x, z + nz, n) == "D":
				nz += 1
			var debout := nz > 1 or (nx == 1 and lettre(x, z - 1, n) == "#" and lettre(x, z + 1, n) == "#")    # le mur court du nord au sud
			for i in nx:
				for k in nz:
					vues[Vector2i(x + i, z + k)] = true
			_porte(Vector3(x + nx * 0.5, y + PORTE_HAUT * 0.5, z + nz * 0.5), Vector3(0.2 if debout else float(nx), PORTE_HAUT, float(nz) if debout else 0.2), battant, n)
	if cage.size.x == 0:
		return
	# dans la cage : une cloison entre les deux volées ; à l'étage, un garde-corps au bord du vide ; au sous-sol, le dessous des marches est clos
	var cx := float(cage.position.x)
	var cz := float(cage.position.y)
	_boite(_decor, Vector3(cx + 5.0, y + R.HAUTEUR * 0.5, cz + 2.0), Vector3(6.0, R.HAUTEUR, 0.12), mur)
	if n == 1:
		_boite(_decor, Vector3(cx + 2.06, y + 0.5, cz + 1.0), Vector3(0.12, 1.0, 2.0), mat(Color(0.28, 0.17, 0.1)))
	elif n == -1:
		_boite(_decor, Vector3(cx + 2.06, y + R.HAUTEUR * 0.5, cz + 3.0), Vector3(0.12, R.HAUTEUR, 2.0), mur)


# les escaliers : une pente solide (un meuble s'y traîne, et y glisse), et des marches par-dessus pour l'œil
func _marches() -> void:
	for e in escaliers:
		var yb := y_de(e.de)
		var z: float = e.rect.position.y + 1.0
		var long := Vector2(e.xh - e.xb, PAS)
		var angle := atan2(long.y, long.x)
		var normale := Vector2(-sin(angle), cos(angle))
		if normale.y < 0.0:
			normale = -normale
		var corps := StaticBody3D.new()
		corps.name = "Escalier%d" % e.de
		corps.collision_layer = 1
		corps.collision_mask = 0
		corps.position = Vector3((e.xb + e.xh) * 0.5 - normale.x * 0.15, yb + PAS * 0.5 - normale.y * 0.15, z)
		corps.rotation.z = angle
		add_child(corps)
		_couche = couche(e.de) | couche(e.de + 1)
		_boite(corps, Vector3.ZERO, Vector3(long.length(), 0.3, 2.0), mat(Color(0.2, 0.15, 0.1)))
		var bois := mat(Color(0.42, 0.3, 0.19))
		for i in 12:
			var f := (i + 0.5) / 12.0
			_boite(self, Vector3(lerpf(e.xb, e.xh, f), yb + PAS * f - 0.15, z), Vector3(0.5, 0.3, 1.96), bois, false)


func _porte(c: Vector3, t: Vector3, m: Material, n: int) -> void:
	var corps := StaticBody3D.new()
	corps.name = "Porte%d" % portes.size()
	corps.collision_layer = 1
	corps.collision_mask = 0
	add_child(corps)
	_boite(corps, c, t, m)
	var forme: CollisionShape3D = corps.get_child(1)
	forme.disabled = true
	corps.visible = false
	portes.append({"centre": c, "corps": corps, "forme": forme, "verrou": false, "niveau": n})


func _lampes() -> void:
	for piece in pieces:
		var r: Rect2i = piece.rect
		var n := maxi(1, int(ceil(maxi(r.size.x, r.size.y) / 11.0)))
		_couche = couche(piece.niveau)
		if piece.type == "palier":             # une lampe à chaque palier
			_lampe(Vector2(r.position.x + 1.0, r.position.y + 2.0), piece.niveau)
			_lampe(Vector2(r.position.x + 5.0, r.position.y + (1.0 if piece.niveau < 0 else 3.0)), piece.niveau)      # (pas au-dessus des marches : on s'y cognerait)
			if piece.niveau != 0:
				_lampe(Vector2(r.end.x - 1.0, r.position.y + 2.0), piece.niveau)
			continue
		for i in n:
			var f := (i + 0.5) / n
			var ou := Vector2(r.position.x + r.size.x * (f if r.size.x >= r.size.y else 0.5), r.position.y + r.size.y * (0.5 if r.size.x >= r.size.y else f))
			_lampe(ou, piece.niveau)
			if LUEURS.has(piece.type):       # une pièce bonus a sa lumière à elle
				lampes[lampes.size() - 1].lumiere.light_color = LUEURS[piece.type][0]
				lampes[lampes.size() - 1].lumiere.light_energy = LUEURS[piece.type][1]
			elif piece.niveau < 0:           # au sous-sol, on y voit moins
				lampes[lampes.size() - 1].lumiere.light_energy = 1.1


func _lampe(p: Vector2, n: int) -> void:
	var l := OmniLight3D.new()
	l.position = Vector3(p.x, y_de(n) + R.HAUTEUR - 0.45, p.y)
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
	a.position = Vector3(p.x, y_de(n) + R.HAUTEUR - 0.15, p.y)
	a.material_override = mat(Color(1.0, 0.85, 0.55), 2.5)
	a.layers = couche(n)
	add_child(a)
	lampes.append({"lumiere": l, "ampoule": a, "niveau": n})


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


func _grille(n: int) -> void:
	var g := AStarGrid2D.new()
	var lignes := profondeur + (COUR if n == 0 else 0)
	g.region = Rect2i(0, 0, largeur, lignes)
	g.cell_size = Vector2.ONE
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.update()
	for ligne in lignes:
		for c in largeur:
			var mur := false
			if ligne < profondeur:
				mur = not plans[n][ligne][c] in [".", "D", "P"]
			else:
				mur = c == 0 or c == largeur - 1 or ligne == profondeur + COUR - 1 \
					or camion.grow(0.3).intersects(Rect2(c, ligne, 1.0, 1.0))
			if mur:
				g.set_point_solid(Vector2i(c, ligne), true)
	grilles[n] = g


# la tanière : le milieu de la pièce la plus loin de l'entrée, par le chemin
func _tanier() -> void:
	var loin := -1
	for piece in pieces:
		if piece.type == "couloir" or piece.type == "entree" or piece.type == "palier":
			continue
		var r: Rect2i = piece.rect
		var milieu := Vector3(r.position.x + r.size.x * 0.5, y_de(piece.niveau), r.position.y + r.size.y * 0.5)
		var n := chemin(seuil, milieu).size()
		if n > loin:
			loin = n
			_antre = r
			_antre_n = piece.niveau
			taniere = centre(case_de(milieu), piece.niveau)


# la maison meublée : là où pèsent des meubles, le fantôme passe mal. Ses chemins préfèrent les cases dégagées (il butera quand même
# sur ce qu'on aura déplacé), et sa tanière est une case libre de sa pièce : il ne se réveille pas coincé dans une table.
func encombrer(lourds: Array, tiennent: Array = [], lourds_n: Array = [], tiennent_n: Array = []) -> void:
	fixes = tiennent
	fixes_n = tiennent_n
	while fixes_n.size() < fixes.size():
		fixes_n.append(0)
	var prises := {}
	for i in lourds.size():
		var n: int = lourds_n[i] if i < lourds_n.size() else 0
		var g: AStarGrid2D = grilles[n]
		var large: Rect2 = lourds[i].grow(0.3)
		for z in range(int(floor(large.position.y)), int(floor(large.end.y)) + 1):
			for x in range(int(floor(large.position.x)), int(floor(large.end.x)) + 1):
				var c := Vector2i(x, z)
				if g.is_in_boundsv(c) and not g.is_point_solid(c) and large.has_point(Vector2(x + 0.5, z + 0.5)):
					if n == _antre_n:
						prises[c] = true
					g.set_point_weight_scale(c, 8.0)
	var milieu := Vector2(_antre.position.x + _antre.size.x * 0.5, _antre.position.y + _antre.size.y * 0.5)
	var mieux := 1e9
	for z in range(_antre.position.y, _antre.end.y):
		for x in range(_antre.position.x, _antre.end.x):
			var d := milieu.distance_to(Vector2(x + 0.5, z + 0.5))
			if not prises.has(Vector2i(x, z)) and d < mieux:
				mieux = d
				taniere = Vector3(x + 0.5, y_de(_antre_n), z + 0.5)
