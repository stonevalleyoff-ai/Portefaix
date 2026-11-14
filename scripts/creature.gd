extends CharacterBody3D
# Portefaix — le fantôme (scripts/creature.gd)
# Il dort dans la pièce la plus loin de l'entrée, puis rôde. Il n'y voit presque pas : quelques mètres, droit devant lui, et un meuble
# haut suffit à le lui cacher. Mais il entend tout : un bruit assez fort et assez près, il va voir, en tâtonnant.
# Il marche quand il rôde, presse le pas quand il cherche, et court quand il chasse : plus vite qu'on ne marche, moins qu'on ne court,
# et pas longtemps. Il a un corps : les meubles lourds l'arrêtent. Il les contourne : il tient une carte fine de la maison (une case
# par demi-mètre), où il reporte plusieurs fois par seconde les meubles là où ils sont à cet instant, et refait son chemin autour, y
# compris de ce qu'on vient de pousser devant lui. Si rien ne passe, il va au plus près, cogne, et renonce. Un canapé en travers d'un
# couloir le tient donc dehors ; un carton, non.
# Quand il voit un porteur, il crie d'abord. Son premier coup blesse, le suivant tue. Il ne sort pas de la maison.
# L'hôte seul le fait penser et marcher ; les autres le voient où l'hôte dit qu'il est. Chacun l'anime chez soi, d'après ce qu'il fait.

const R = preload("res://scripts/regles.gd")

enum { DORT, RODE, ENQUETE, CHASSE, ALERTE }

var principal
var maison
var mode := DORT
var taniere := Vector3.ZERO      # là où elle dort, et où elle rentre
var sorte := 0                    # 0 : le fantôme du manoir ; 1 : un irradié du bunker (les yeux verts)
var proie := -1
var bute := false                 # il cogne contre un meuble qui lui barre le passage
var route := PackedVector3Array()
var cible_pos := Vector3.ZERO     # chez les invités
var cible_yaw := 0.0
var _i := 0
var _vu := 0.0                    # depuis quand il ne voit plus sa proie
var _dernier := Vector3.ZERO      # où il l'a vue la dernière fois
var _destination := Vector3.ZERO
var _attente := 0.0
var _pense := 0.0
var _trace := 0.0
var _interet := 0.0               # la force du bruit qu'il suit
var _alerte := 0.0                # ce qu'il lui reste à crier avant de s'élancer
var _souffle := 0.0               # ce qu'il lui reste de chasse
var _repue := 0.0                 # tant que ça dure, il ne regarde rien
var _allure := 0.0                # sa vitesse du moment : il n'atteint pas la sienne d'un coup
var _veut := false                # il essaie d'avancer
var _trajet := 0.0                # ce qu'il a parcouru depuis le dernier contrôle
var _t_bloc := 0.0
var _butees := 0                  # combien de fois de suite il a buté
var _t_bute := 0.0
var _evite := {}                  # les cases (fines) où il a buté → jusqu'à quand il les contourne
var _carte: AStarGrid2D            # sa carte fine du niveau où il est : les murs, ce qui tient à la maison, les portes claquées, les meubles lourds
var _cartes := {}                 # une carte par niveau
var _durs := {}                   # par niveau, ce qui ne bouge pas : les murs, les escaliers, ce qui tient à la maison
var _niv := 0                     # le niveau de la carte qu'il tient
var _i_marche := -1               # dans sa route, le point qui est au bout d'un escalier : il y va tout droit, par les marches
var _etapes := false              # sa route ne mène qu'à un escalier, ou au bout de celui où il est : arrivé, il la refait
var _t_carte := 0.0
var _atteint := true              # son chemin va-t-il jusqu'au but, ou seulement au plus près ?

const PAS := 0.5                  # le côté d'une case de sa carte
var _son: AudioStreamPlayer3D
# le corps, pour l'animer
var _os := {}                     # le nom d'une articulation → son pivot
var _pose := {}                   # le nom d'une articulation → la rotation qu'elle vise
var _lambeaux: Array = []
var _yeux_mat: StandardMaterial3D
var _lueur: OmniLight3D
var _phase := 0.0
var _temps := 0.0
var _avant_pos := Vector3.ZERO
var _vitesse_vue := 0.0
var _pas_avant := 0.0


func preparer(p) -> void:
	principal = p
	maison = p.maison
	if taniere == Vector3.ZERO:
		taniere = maison.taniere
	position = taniere
	cible_pos = position
	_avant_pos = position
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 0
	collision_mask = (R.COUCHE_DECOR | R.COUCHE_OBJETS) if principal.serveur else 0
	var forme := CollisionShape3D.new()
	var c := CapsuleShape3D.new()
	c.radius = 0.28
	c.height = 1.7                       # (de 0,3 m à 2 m : au-dessus du sol, où il ne s'accroche pas, et sous les linteaux des
	forme.shape = c                      # portes, à 2,2 m ; plus haut, il restait coincé dans leur encadrement)
	forme.position.y = 1.15
	add_child(forme)
	if principal.serveur:
		_dresser_carte()
	_faire_corps()
	_son = AudioStreamPlayer3D.new()
	_son.stream = principal.sons.boucle("grogne")
	_son.position.y = 1.8
	_son.unit_size = 5.0
	_son.max_distance = 28.0
	_son.volume_db = -80.0
	add_child(_son)
	_son.play()
	visible = false


# --- le corps : un grand spectre décharné, tout en articulations, drapé de lambeaux ---

func _mat(c: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = 1.0
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _pivot(parent: Node3D, nom: String, ou: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = ou
	parent.add_child(n)
	_os[nom] = n
	_pose[nom] = Vector3.ZERO
	return n


func _boite(parent: Node3D, c: Vector3, t: Vector3, m: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = t
	mesh.mesh = b
	mesh.position = c
	mesh.material_override = m
	parent.add_child(mesh)
	return mesh


func _faire_corps() -> void:
	var chair := _mat(Color(0.05, 0.055, 0.075))
	var os := _mat(Color(0.16, 0.17, 0.2))
	var drap := _mat(Color(0.03, 0.035, 0.05), 0.72)
	var bassin := _pivot(self, "bassin", Vector3(0, 1.15, 0))
	_boite(bassin, Vector3(0, 0, 0), Vector3(0.3, 0.16, 0.18), chair)
	# les jambes : une cuisse, un tibia, un pied, de chaque côté
	for cote: int in [-1, 1]:
		var s := "g" if cote < 0 else "d"
		var hanche := _pivot(bassin, "hanche_" + s, Vector3(0.11 * cote, -0.05, 0))
		_boite(hanche, Vector3(0, -0.29, 0), Vector3(0.1, 0.58, 0.1), chair)
		var genou := _pivot(hanche, "genou_" + s, Vector3(0, -0.58, 0))
		_boite(genou, Vector3(0, -0.26, 0), Vector3(0.075, 0.52, 0.075), os)
		_boite(genou, Vector3(0, -0.51, -0.07), Vector3(0.09, 0.05, 0.24), chair)
	# le tronc : une taille trop mince, une cage de côtes, des épaules trop larges
	var torse := _pivot(bassin, "torse", Vector3(0, 0.06, 0))
	_boite(torse, Vector3(0, 0.2, 0), Vector3(0.16, 0.36, 0.13), chair)
	_boite(torse, Vector3(0, 0.56, 0), Vector3(0.36, 0.42, 0.2), chair)
	for k in 4:                         # les côtes, qui percent
		_boite(torse, Vector3(0, 0.4 + 0.1 * k, -0.105), Vector3(0.3 - 0.02 * k, 0.025, 0.02), os)
	_boite(torse, Vector3(0, 0.8, 0), Vector3(0.58, 0.09, 0.16), chair)
	for k in 5:                         # l'échine
		_boite(torse, Vector3(0, 0.15 + 0.14 * k, 0.11), Vector3(0.05, 0.06, 0.06), os)
	# la tête : un crâne long, penché en avant, une mâchoire qui se décroche, deux yeux pâles
	var cou := _pivot(torse, "cou", Vector3(0, 0.84, -0.02))
	_boite(cou, Vector3(0, 0.07, 0), Vector3(0.08, 0.16, 0.08), chair)
	var tete := _pivot(cou, "tete", Vector3(0, 0.16, 0))
	_boite(tete, Vector3(0, 0.17, -0.03), Vector3(0.24, 0.3, 0.27), chair)
	_boite(tete, Vector3(0, 0.32, 0.02), Vector3(0.2, 0.08, 0.22), chair)
	var machoire := _pivot(tete, "machoire", Vector3(0, 0.04, 0.05))
	_boite(machoire, Vector3(0, -0.05, -0.1), Vector3(0.18, 0.08, 0.2), chair)
	for k in 4:                         # les dents
		_boite(machoire, Vector3(-0.06 + 0.04 * k, 0.0, -0.195), Vector3(0.018, 0.05, 0.015), os)
	_yeux_mat = _mat(Color(1.0, 0.92, 0.6) if sorte == 0 else Color(0.6, 1.0, 0.5))
	_yeux_mat.emission_enabled = true
	_yeux_mat.emission = Color(1.0, 0.9, 0.55) if sorte == 0 else Color(0.4, 1.0, 0.3)
	_yeux_mat.emission_energy_multiplier = 5.0
	for x in [-0.065, 0.065]:
		var oeil := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.028
		sph.height = 0.056
		oeil.mesh = sph
		oeil.material_override = _yeux_mat
		oeil.position = Vector3(x, 0.2, -0.17)
		tete.add_child(oeil)
		_boite(tete, Vector3(x, 0.2, -0.155), Vector3(0.075, 0.07, 0.03), _mat(Color(0.0, 0.0, 0.0)))     # les orbites
	_lueur = OmniLight3D.new()
	_lueur.position = Vector3(0, 0.2, -0.3)
	_lueur.light_color = Color(1.0, 0.3, 0.15)
	_lueur.light_energy = 0.0
	_lueur.omni_range = 3.5
	tete.add_child(_lueur)
	# les bras : trop longs, jusqu'aux tibias, et des doigts comme des brindilles
	for cote: int in [-1, 1]:
		var s := "g" if cote < 0 else "d"
		var epaule := _pivot(torse, "epaule_" + s, Vector3(0.31 * cote, 0.78, 0))
		_boite(epaule, Vector3(0, -0.34, 0), Vector3(0.075, 0.68, 0.075), chair)
		var coude := _pivot(epaule, "coude_" + s, Vector3(0, -0.68, 0))
		_boite(coude, Vector3(0, -0.36, 0), Vector3(0.06, 0.72, 0.06), os)
		var main := _pivot(coude, "main_" + s, Vector3(0, -0.72, 0))
		_boite(main, Vector3(0, -0.05, 0), Vector3(0.09, 0.1, 0.04), chair)
		for k in 4:
			var doigt := _boite(main, Vector3(-0.036 + 0.024 * k, -0.22, 0), Vector3(0.016, 0.26 - 0.03 * absi(k - 1), 0.016), os)
			doigt.rotation.z = (k - 1.5) * 0.12
	# les lambeaux : ce qu'il reste d'un drap, pendu aux épaules et à la taille, qui traîne derrière lui
	var ou := [Vector3(-0.22, 0.82, 0.08), Vector3(0.0, 0.84, 0.1), Vector3(0.22, 0.82, 0.08), Vector3(-0.3, 0.8, 0.0), Vector3(0.3, 0.8, 0.0),
		Vector3(-0.14, 0.05, 0.09), Vector3(0.14, 0.05, 0.09), Vector3(-0.12, 0.05, -0.09), Vector3(0.12, 0.05, -0.09)]
	var longs := [1.25, 1.5, 1.2, 0.85, 0.9, 0.95, 0.8, 0.6, 0.7]
	for k in ou.size():
		var l := Node3D.new()
		l.position = ou[k]
		torse.add_child(l)
		_boite(l, Vector3(0, -longs[k] * 0.5, 0), Vector3(0.16 if k < 5 else 0.13, longs[k], 0.012), drap)
		_boite(l, Vector3(0.03, -longs[k] - 0.08, 0), Vector3(0.06, 0.16, 0.012), drap)      # une frange, au bout
		_lambeaux.append(l)


func yeux() -> Vector3:
	return global_position + Vector3(0.0, 2.2, 0.0)


func reveiller() -> void:
	if mode == DORT:
		mode = RODE
		_attente = 0.0


# un bruit, quelque part : s'il porte jusqu'à lui, et s'il vaut mieux que celui qu'il suit, il y va
func entendre(ou: Vector3, rayon: float) -> void:
	rayon *= R.CHOSE_OUIE
	if mode == CHASSE or mode == ALERTE or _repue > 0.0:
		return
	var d := global_position.distance_to(ou)
	if d > rayon:
		return
	if mode == DORT:
		if rayon < 15.0:
			return
		reveiller()
	var interet := rayon - d
	if interet + 1.0 < _interet:
		return
	_interet = interet
	mode = ENQUETE
	_butees = 0
	_aller(ou)


# --- chez l'hôte ---

func avancer(dt: float) -> void:
	if mode == DORT:
		return
	_interet = maxf(_interet - dt * 1.5, 0.0)
	_repue = maxf(_repue - dt, 0.0)
	_t_bute = maxf(_t_bute - dt, 0.0)
	bute = _t_bute > 0.0
	_pense -= dt
	if _pense <= 0.0:
		_pense = 0.2
		_chercher()
	var vitesse: float = R.CHOSE_RODE
	_veut = false
	match mode:
		ALERTE:
			# il a vu un porteur : il se tourne vers lui et crie, sans avancer. C'est le moment de fuir.
			_allure = 0.0
			var j = principal.joueurs.get(proie)
			if j == null or not j.vivant:
				_roder(1.0)
				return
			var d: Vector3 = j.global_position - global_position
			rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(1.0, dt * 8.0))
			_alerte -= dt
			if _alerte <= 0.0:
				mode = CHASSE
				_souffle = R.CHOSE_SOUFFLE
				_trace = 0.0
				_vu = 0.0
				_butees = 0
			return
		CHASSE:
			vitesse = R.CHOSE_CHASSE
			_souffle -= dt
			var j = principal.joueurs.get(proie)
			if j == null or not j.vivant:
				_roder(1.0)
			elif _a_plat(j.global_position) < R.CHOSE_ALLONGE and absf(j.global_position.y - global_position.y) < 1.5 and _vu <= 0.0:
				principal.frapper(proie)       # (le premier coup blesse, le suivant tue)
				rentrer()
			elif _vu > R.CHOSE_PERTE:
				mode = ENQUETE
				_aller(_dernier)
			elif _souffle <= 0.0:              # essoufflé : il s'arrête, et ne regarde plus un moment
				_repue = 4.0
				_roder(4.0)
			else:
				_trace -= dt
				if _trace <= 0.0:
					_trace = 0.3
					_aller(j.global_position)
				if _i >= route.size() and maison.dedans(j.global_position) and absf(j.global_position.y - global_position.y) < 1.0:      # dans la même case : droit sur lui
					_veut = true
					_vers(j.global_position, vitesse, dt)
		ENQUETE:
			vitesse = R.CHOSE_ENQUETE
			if _i >= route.size() and _t_bute <= 0.0:
				_roder(2.5)
		RODE:
			if _repue > 0.0:                   # (il rentre d'un bon pas)
				vitesse = R.CHOSE_ENQUETE
			if _i >= route.size():
				_attente -= dt
				if _attente <= 0.0:
					_attente = principal.hasard.randf_range(1.0, 3.0)
					_butees = 0
					_aller(maison.case_au_hasard(principal.hasard))
	if _i < route.size():
		_veut = true
		# les meubles ont pu bouger : il regarde, et refait son chemin autour
		_t_carte -= dt
		if _t_carte <= 0.0:
			_aller(_destination)
		# il coupe au plus court tant que la voie est libre : il ne marche pas de case en case
		for k in 3:
			if _i + 1 < route.size() and _i != _i_marche and _i + 1 != _i_marche and _degage(global_position, route[_i + 1]):
				_i += 1
		if _i < route.size() and _vers(route[_i], vitesse, dt):
			_i += 1
			if _i >= route.size() and _etapes:      # au bout de l'escalier : la suite du chemin, à ce niveau-ci
				_aller(_destination)
			elif _i >= route.size() and not _atteint and mode != CHASSE:
				_t_bute = 1.3                  # au bout d'un chemin qui ne passe pas : il cogne contre ce qui le barre
				principal.son_a.rpc("choc", global_position + Vector3.UP, -2.0)
	if not _veut:
		_allure = 0.0
		_t_bloc = 0.0
		_trajet = 0.0
		return
	# avance-t-il ? S'il piétine, c'est qu'un meuble lui barre le passage
	_t_bloc += dt
	if _t_bloc >= R.CHOSE_BLOCAGE:
		if _trajet < 0.12:
			_buter()
		elif _trajet > 0.5:
			_butees = 0
		_t_bloc = 0.0
		_trajet = 0.0


# il bute : il cogne, puis cherche un passage qui évite cette case ; à force, il renonce
func _buter() -> void:
	_butees += 1
	_t_bute = 0.9
	_allure = 0.0
	principal.son_a.rpc("choc", global_position + Vector3.UP, -2.0)
	if _i < route.size():
		_evite[_case(route[_i])] = Time.get_ticks_msec() + 6000
	if _butees >= R.CHOSE_BUTEES:
		_butees = 0
		_repue = 3.0
		_roder(2.0)
		return
	_aller(_destination)


func _a_plat(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _roder(attente: float) -> void:
	mode = RODE
	proie = -1
	_interet = 0.0
	_attente = attente
	route = PackedVector3Array()
	_i = 0


# après un coup : il rentre à sa tanière, sans rien regarder en chemin
func rentrer() -> void:
	_roder(3.0)
	_repue = R.CHOSE_REPUE
	_butees = 0
	_aller(taniere)


# --- sa carte, et ses chemins ---

func _case(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int(floor(p.x / PAS)), 0, maison.largeur * 2 - 1), clampi(int(floor(p.z / PAS)), 0, maison.profondeur * 2 - 1))


func _milieu(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * PAS, maison.y_de(_niv), (c.y + 0.5) * PAS)


# les cases dont le milieu est dans ce rectangle
func _cases_de(r: Rect2) -> Array:
	var cases: Array = []
	for z in range(int(floor(r.position.y / PAS)), int(floor(r.end.y / PAS)) + 1):
		for x in range(int(floor(r.position.x / PAS)), int(floor(r.end.x / PAS)) + 1):
			var c := Vector2i(x, z)
			if x >= 0 and z >= 0 and x < maison.largeur * 2 and z < maison.profondeur * 2 and r.has_point(Vector2((x + 0.5) * PAS, (z + 0.5) * PAS)):
				cases.append(c)
	return cases


# une fois : ce qui ne bougera pas, à chaque niveau
func _dresser_carte() -> void:
	for n in maison.niveaux:
		var carte := AStarGrid2D.new()
		carte.region = Rect2i(0, 0, maison.largeur * 2, maison.profondeur * 2)
		carte.cell_size = Vector2(PAS, PAS)
		carte.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		carte.update()
		_cartes[n] = carte
		_durs[n] = {}
		for z in maison.profondeur:
			for x in maison.largeur:
				if not maison.plans[n][z][x] in [".", "D", "P"]:
					for c in _cases_de(Rect2(x, z, 1.0, 1.0)):
						_durs[n][c] = true
	for i in maison.fixes.size():
		for c in _cases_de(maison.fixes[i].grow(0.2)):
			_durs[maison.fixes_n[i]][c] = true
	_reporter()


# plusieurs fois par seconde : au niveau où il est, où sont les meubles lourds, là, maintenant ; les portes claquées ; les cases où il vient de buter
func _reporter() -> void:
	_t_carte = R.CHOSE_CARTE
	_niv = maison.niveau_de(global_position.y)
	_carte = _cartes[_niv]
	var sol: float = maison.y_de(_niv)
	_carte.fill_solid_region(_carte.region, false)
	for c in _durs[_niv]:
		_carte.set_point_solid(c, true)
	for porte in maison.portes:
		if porte.verrou and porte.niveau == _niv:
			var boite: Vector3 = porte.forme.shape.size
			for c in _cases_de(Rect2(porte.centre.x - boite.x * 0.5, porte.centre.z - boite.z * 0.5, boite.x, boite.z).grow(0.2)):
				_carte.set_point_solid(c, true)
	for o in principal.objets.values():
		if o.collision_layer != R.COUCHE_OBJETS:
			continue                       # (trop léger : il passe au travers)
		var base: Basis = o.global_transform.basis
		var demi: Vector3 = o.taille * 0.5
		var etendue := base.x.abs() * demi.x + base.y.abs() * demi.y + base.z.abs() * demi.z       # la boîte qui l'entoure, dans le monde
		var p: Vector3 = o.global_position
		if p.y - etendue.y > sol + 2.0 or p.y + etendue.y < sol + 0.3:
			continue                       # (au-dessus de sa tête, ou sous ses pieds : un autre niveau, aussi)
		var debout := absf(base.y.y) > 0.9
		var envers: Transform3D = o.global_transform.affine_inverse()
		for c in _cases_de(Rect2(p.x - etendue.x, p.z - etendue.z, etendue.x * 2.0, etendue.z * 2.0).grow(0.22)):
			if debout:                     # posé droit : sa vraie place au sol, tourné comme il l'est
				var dans: Vector3 = envers * Vector3((c.x + 0.5) * PAS, p.y, (c.y + 0.5) * PAS)
				if absf(dans.x) > demi.x + 0.22 or absf(dans.z) > demi.z + 0.22:
					continue
			_carte.set_point_solid(c, true)
	var maintenant := Time.get_ticks_msec()
	for c in _evite.keys():
		if _evite[c] < maintenant:
			_evite.erase(c)
		else:
			_carte.set_point_solid(c, true)


# une case libre, la plus près de celle-ci
func _libre_pres(c: Vector2i) -> Vector2i:
	if not _carte.is_point_solid(c):
		return c
	for r in range(1, 5):
		var mieux := c
		var pres := 1e9
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var v := Vector2i(c.x + dx, c.y + dz)
				if _carte.is_in_boundsv(v) and not _carte.is_point_solid(v) and Vector2(dx, dz).length() < pres:
					pres = Vector2(dx, dz).length()
					mieux = v
		if pres < 1e8:
			return mieux
	return c


# il ne sort pas de la maison : ce qui l'appelle dehors l'amène au seuil, pas plus loin. Son chemin contourne les meubles ; si rien ne
# passe, il va au plus près.
# D'un niveau à l'autre, il prend l'escalier : son chemin le mène au pied (ou en haut) des marches, puis tout droit à l'autre bout ;
# là, il le refait.
func _aller(ou: Vector3) -> void:
	_destination = ou
	var but: Vector3 = ou if maison.dedans(ou) else maison.seuil
	var vers: int = maison.niveau_de(but.y)
	_i_marche = -1
	_etapes = false
	var marches = maison.escalier_sous(global_position)
	if marches != null:                   # dans l'escalier : il le finit, du côté où il va
		route = PackedVector3Array([marches.haut if vers > marches.de else marches.bas])
		_i = 0
		_i_marche = 0
		_etapes = true
		_atteint = true
		_t_carte = R.CHOSE_CARTE
		return
	_reporter()
	var sortie = null
	if vers != _niv:
		var e: Dictionary = maison.escalier_entre(_niv, vers)
		if not e.is_empty():
			but = e.entree
			sortie = e.sortie
			if _a_plat(but) < 0.7:        # il y est : droit sur les marches, jusqu'à l'autre bout
				route = PackedVector3Array([sortie])
				_i = 0
				_i_marche = 0
				_etapes = true
				_atteint = true
				return
	var a := _libre_pres(_case(global_position))
	var b := _libre_pres(_case(but))
	var cases := _carte.get_id_path(a, b, true)
	route = PackedVector3Array()
	for c in cases:
		route.append(_milieu(c))
	_atteint = not cases.is_empty() and cases[cases.size() - 1] == b
	_i = 1 if route.size() > 1 else 0     # la première case est celle où il est
	if sortie != null and _atteint:
		route[route.size() - 1] = but     # (au pied des marches, bien dans l'axe)
		route.append(sortie)
		_i_marche = route.size() - 1
		_etapes = true


# de là à là, tout droit, la voie est-elle libre ? (de quoi couper les angles de son chemin, sans frôler un meuble)
func _degage(de: Vector3, vers: Vector3) -> bool:
	var d := Vector3(vers.x - de.x, 0.0, vers.z - de.z)
	var l := d.length()
	if l < 0.05:
		return true
	var cote := Vector3(-d.z, 0.0, d.x) / l * 0.24
	var n := int(ceil(l / 0.2))
	for k in range(1, n + 1):
		var p := de + d * (float(k) / n)
		if _carte.is_point_solid(_case(p + cote)) or _carte.is_point_solid(_case(p - cote)):
			return false
	return true


# un pas vers un point ; vrai quand il y est. Il prend de la vitesse peu à peu, et glisse le long de ce qui le gêne.
func _vers(p: Vector3, vitesse: float, dt: float) -> bool:
	var d := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
	if d.length() < 0.2:
		return true
	_allure = move_toward(_allure, vitesse, R.CHOSE_ELAN * dt)
	velocity = d.normalized() * minf(_allure, d.length() / dt)
	var avant := global_position
	move_and_slide()
	global_position.y = maison.sol(global_position)
	_trajet += global_position.distance_to(avant)
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(1.0, dt * 7.0))
	return false


# voit-il ce porteur ? À cette distance au plus, dans la maison, sans rien entre eux : un mur, ou un meuble haut (sauf s'il le chasse déjà)
func _voit(j, portee: float, meubles: bool) -> bool:
	return j.vivant and maison.dedans(j.global_position) and global_position.distance_to(j.global_position) < portee \
		and maison.voit(yeux(), j.global_position + Vector3(0.0, 1.0, 0.0), (R.COUCHE_DECOR | R.COUCHE_OBJETS) if meubles else R.COUCHE_DECOR)


# qui voit-il ? En chasse, il ne suit que sa proie. Sinon : le plus proche des vivants, dans la maison, droit devant lui (ou tout
# contre lui), à quelques mètres, sans rien entre eux. Alors il crie avant de s'élancer.
func _chercher() -> void:
	if mode == ALERTE or _repue > 0.0:
		return
	if mode == CHASSE:
		var p = principal.joueurs.get(proie)
		if p != null and _voit(p, R.CHOSE_VUE * 2.0, false):
			_vu = 0.0
			_dernier = p.global_position
		else:
			_vu += 0.2
		return
	var avant := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	var mieux := -1
	var pres := 1e9
	var par_la_torche := false
	for j in principal.joueurs.values():
		var d: float = global_position.distance_to(j.global_position)
		if d >= pres:
			continue
		var allumee: bool = j.vivant and j.torche_voulue and j.torche_ok
		# le faisceau lui tombe dessus : il le sent, même de dos
		if allumee and d < R.TORCHE_FAISCEAU and j.vise().dot((yeux() - Vector3(0.0, 0.8, 0.0) - j.tete.global_position).normalized()) > R.TORCHE_ANGLE and _voit(j, R.TORCHE_FAISCEAU, true):
			mieux = j.id
			pres = d
			par_la_torche = true
			continue
		var vers: Vector3 = (j.global_position - global_position) * Vector3(1.0, 0.0, 1.0)
		if d > R.CHOSE_PRES and avant.dot(vers.normalized()) < R.CHOSE_CONE:
			continue
		# devant lui : à quelques mètres ; de bien plus loin si la torche est allumée (accroupi, on se cache à moitié dans les deux cas)
		var portee: float = R.CHOSE_VUE * (R.CHOSE_VUE_ACCROUPI if j.accroupi else 1.0)
		if _voit(j, portee, true):
			mieux = j.id
			pres = d
			par_la_torche = false
		elif allumee and _voit(j, portee * R.CHOSE_TORCHE, true):
			mieux = j.id
			pres = d
			par_la_torche = true
	if mieux >= 0:
		mode = ALERTE
		proie = mieux
		_alerte = R.CHOSE_ALERTE
		_dernier = principal.joueurs[mieux].global_position
		route = PackedVector3Array()
		_i = 0
		principal.reperer(mieux, par_la_torche, global_position)


# --- chez tout le monde : le voir bouger ---

func _process(dt: float) -> void:
	if not principal.serveur:
		global_position = global_position.lerp(cible_pos, minf(1.0, dt * 12.0))
		rotation.y = lerp_angle(rotation.y, cible_yaw, minf(1.0, dt * 10.0))
	visible = mode != DORT
	var volume: float = [-80.0, -14.0, -7.0, 0.0, 3.0][mode]
	_son.volume_db = lerpf(_son.volume_db, volume, minf(1.0, dt * 3.0))
	_son.pitch_scale = lerpf(_son.pitch_scale, 1.35 if mode == CHASSE or mode == ALERTE else 1.0, minf(1.0, dt * 3.0))
	if not visible or dt <= 0.0:
		_avant_pos = global_position
		return
	# sa vitesse, lue dans ce qu'il a parcouru : la même chez l'hôte et chez les autres
	var v := Vector2(global_position.x - _avant_pos.x, global_position.z - _avant_pos.z).length() / dt
	_avant_pos = global_position
	_vitesse_vue = lerpf(_vitesse_vue, minf(v, 8.0), minf(1.0, dt * 8.0))
	_temps += dt
	_phase += _vitesse_vue * dt * 2.3
	_poser(dt)
	# ses pas s'entendent : deux par foulée, plus lourds quand il court
	if _vitesse_vue > 0.3 and floor(_phase / PI) != floor(_pas_avant / PI):
		principal.sons.jouer_a("pas", global_position, -6.0 if _vitesse_vue > 3.0 else -14.0)
	_pas_avant = _phase


# la pose du moment : chaque articulation vise un angle, et y va sans à-coup
func _poser(dt: float) -> void:
	var v := _vitesse_vue
	var court := clampf(inverse_lerp(2.6, 3.8, v), 0.0, 1.0)             # de la marche à la course
	var marche := clampf(v / 1.2, 0.0, 1.0)
	var s := sin(_phase)
	var ampleur := lerpf(0.42, 0.95, court) * marche
	var t := _temps
	# les jambes : l'une avance quand l'autre recule ; le genou plie quand la jambe revient
	_pose["hanche_g"] = Vector3(s * ampleur, 0, 0)
	_pose["hanche_d"] = Vector3(-s * ampleur, 0, 0)
	_pose["genou_g"] = Vector3(-maxf(0.0, cos(_phase)) * ampleur * 1.5 - 0.05, 0, 0)
	_pose["genou_d"] = Vector3(-maxf(0.0, -cos(_phase)) * ampleur * 1.5 - 0.05, 0, 0)
	# le tronc : voûté ; il se penche pour courir, et se balance quand il ne bouge pas
	var porte := 0.0                    # sous un linteau, il se baisse
	if maison.lettre(int(floor(global_position.x)), int(floor(global_position.z))) in ["D", "P"]:
		porte = 1.0
	var penche := lerpf(0.16, 0.5, court) + (0.14 if mode == ENQUETE else 0.0) + 0.35 * porte
	_pose["torse"] = Vector3(-penche, sin(t * 0.7) * 0.06 * (1.0 - marche), sin(_phase) * 0.05 * marche + sin(t * 0.9) * 0.03)
	_pose["cou"] = Vector3(penche * 0.5, 0, 0)
	# la tête : il ne voit presque rien, alors il la tourne, il écoute
	var ecoute := sin(t * 0.6) * 0.7 * (1.0 - court) if mode == RODE or mode == ENQUETE else 0.0
	_pose["tete"] = Vector3(0.1 + sin(t * 1.3) * 0.05, ecoute, sin(t * 0.4) * 0.12 * (1.0 - court))
	_pose["machoire"] = Vector3(-0.12 - 0.06 * sin(t * 2.0), 0, 0)
	# les bras : ils pendent et balancent ; en cherchant, ils tâtonnent devant lui ; en courant, ils se tendent vers sa proie
	var tend := 0.0
	if mode == ENQUETE:
		tend = 0.75
	if mode == CHASSE:
		tend = 1.3
	for cote: float in [-1.0, 1.0]:
		var nom := "g" if cote < 0.0 else "d"
		var balance := -s * cote * 0.35 * marche * (1.0 - court)
		var tatonne := sin(t * 2.2 + cote) * 0.18 if mode == ENQUETE else sin(t * 9.0 + cote) * 0.05 * court
		_pose["epaule_" + nom] = Vector3(tend + balance + tatonne, 0, cote * (0.08 + 0.1 * tend))
		_pose["coude_" + nom] = Vector3(0.15 + 0.5 * tend * (0.6 if mode == CHASSE else 1.0) + absf(balance) * 0.5, 0, 0)
		_pose["main_" + nom] = Vector3(0.2 * tend + sin(t * 3.0 + cote * 2.0) * 0.12, 0, 0)
	var yeux := Color(1.0, 0.9, 0.55)
	var lueur := 0.0
	if mode == ALERTE:
		# il crie : le dos cambré, la tête en arrière, la mâchoire décrochée, les bras écartés, tout qui tremble
		var tremble := sin(t * 38.0) * 0.04
		_pose["torse"] = Vector3(0.28 + tremble, 0, tremble)
		_pose["cou"] = Vector3(0.25, 0, 0)
		_pose["tete"] = Vector3(0.5 + tremble, 0, tremble * 2.0)
		_pose["machoire"] = Vector3(-0.95, 0, 0)
		for cote: float in [-1.0, 1.0]:
			var nom := "g" if cote < 0.0 else "d"
			_pose["epaule_" + nom] = Vector3(0.35 + tremble * 3.0, 0, cote * 1.05)
			_pose["coude_" + nom] = Vector3(0.7, 0, 0)
			_pose["main_" + nom] = Vector3(-0.5, 0, 0)
		yeux = Color(1.0, 0.25, 0.12)
		lueur = 0.9
	elif mode == CHASSE:
		_pose["machoire"] = Vector3(-0.6, 0, 0)
		yeux = Color(1.0, 0.3, 0.15)
		lueur = 0.55
	if bute:
		# il cogne contre ce qui lui barre le passage : les deux bras, à tour de rôle
		for cote: float in [-1.0, 1.0]:
			var nom := "g" if cote < 0.0 else "d"
			_pose["epaule_" + nom] = Vector3(1.5 + sin(t * 14.0 + cote * 1.5) * 0.55, 0, cote * 0.1)
			_pose["coude_" + nom] = Vector3(0.5 + sin(t * 14.0 + cote * 1.5) * 0.4, 0, 0)
		_pose["torse"] = Vector3(-0.3, 0, sin(t * 14.0) * 0.06)
	var k := minf(1.0, dt * 9.0)
	for nom in _os:
		var n: Node3D = _os[nom]
		if nom == "bassin":
			continue
		n.rotation = n.rotation.lerp(_pose[nom], k)
	# le bassin monte et descend à chaque pas, et s'abaisse quand il court
	_os["bassin"].position.y = lerpf(_os["bassin"].position.y, 1.15 - 0.05 * absf(s) * marche - 0.1 * court - 0.22 * porte, k)
	# les lambeaux traînent derrière lui, et flottent
	for i in _lambeaux.size():
		var l: Node3D = _lambeaux[i]
		var flotte := sin(t * 1.7 + i * 1.3) * 0.1
		l.rotation = l.rotation.lerp(Vector3(penche - minf(v * 0.16, 0.75) + flotte, 0, cos(t * 1.1 + i) * 0.07), k)      # (d'aplomb malgré le dos voûté, puis vers l'arrière)
	_yeux_mat.emission = _yeux_mat.emission.lerp(yeux, k)
	_yeux_mat.albedo_color = _yeux_mat.emission
	_lueur.light_energy = lerpf(_lueur.light_energy, lueur, k)
