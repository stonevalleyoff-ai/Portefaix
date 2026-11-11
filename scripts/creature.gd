extends Node3D
# Portefaix — la chose (scripts/creature.gd)
# Elle dort au fond du bureau, puis rôde. Elle entend : un bruit assez fort et assez près, elle va voir. Elle voit devant elle : un
# porteur dans son regard, elle crie, puis le chasse, plus vite qu'il ne marche, moins qu'il ne court, et pas longtemps. Son premier
# coup blesse, le suivant tue. Elle traverse les meubles et les portes claquées, pas les murs, et ne sort pas de la maison.
# L'hôte seul la fait penser ; les autres la voient où il dit qu'elle est.

const R = preload("res://scripts/regles.gd")

enum { DORT, RODE, ENQUETE, CHASSE, ALERTE }

var principal
var maison
var mode := DORT
var proie := -1
var route := PackedVector3Array()
var cible_pos := Vector3.ZERO     # chez les invités
var cible_yaw := 0.0
var _i := 0
var _vu := 0.0                    # depuis quand elle ne voit plus sa proie
var _dernier := Vector3.ZERO      # où elle l'a vue la dernière fois
var _attente := 0.0
var _pense := 0.0
var _trace := 0.0
var _interet := 0.0               # la force du bruit qu'elle suit
var _alerte := 0.0                # ce qu'il lui reste à crier avant de s'élancer
var _souffle := 0.0               # ce qu'il lui reste de chasse
var _repue := 0.0                 # tant que ça dure, elle ne regarde rien
var _son: AudioStreamPlayer3D
var _yeux: Array = []


func preparer(p) -> void:
	principal = p
	maison = p.maison
	position = maison.taniere
	cible_pos = position
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color(0.035, 0.035, 0.05)
	noir.roughness = 1.0
	_boite(Vector3(0, 1.35, 0), Vector3(0.42, 1.3, 0.26), noir)       # le tronc, trop long
	_boite(Vector3(-0.13, 0.35, 0), Vector3(0.13, 0.7, 0.13), noir)   # les jambes
	_boite(Vector3(0.13, 0.35, 0), Vector3(0.13, 0.7, 0.13), noir)
	_boite(Vector3(-0.31, 1.1, 0), Vector3(0.1, 1.6, 0.1), noir)      # les bras, jusqu'aux genoux
	_boite(Vector3(0.31, 1.1, 0), Vector3(0.1, 1.6, 0.1), noir)
	_boite(Vector3(0, 2.2, -0.03), Vector3(0.32, 0.4, 0.3), noir)     # la tête
	var pale := StandardMaterial3D.new()
	pale.albedo_color = Color(1.0, 0.92, 0.6)
	pale.emission_enabled = true
	pale.emission = Color(1.0, 0.9, 0.55)
	pale.emission_energy_multiplier = 5.0
	for x in [-0.08, 0.08]:
		var oeil := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.035
		s.height = 0.07
		oeil.mesh = s
		oeil.material_override = pale
		oeil.position = Vector3(x, 2.25, -0.19)
		add_child(oeil)
		_yeux.append(oeil)
	_son = AudioStreamPlayer3D.new()
	_son.stream = principal.sons.boucle("grogne")
	_son.position.y = 1.8
	_son.unit_size = 5.0
	_son.max_distance = 28.0
	_son.volume_db = -80.0
	add_child(_son)
	_son.play()
	visible = false


func _boite(c: Vector3, t: Vector3, m: Material) -> void:
	var mesh := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = t
	mesh.mesh = b
	mesh.position = c
	mesh.material_override = m
	add_child(mesh)


func yeux() -> Vector3:
	return global_position + Vector3(0.0, 2.2, 0.0)


func reveiller() -> void:
	if mode == DORT:
		mode = RODE
		_attente = 0.0


# un bruit, quelque part : s'il porte jusqu'à elle, et s'il vaut mieux que celui qu'elle suit, elle y va
func entendre(ou: Vector3, rayon: float) -> void:
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
	_aller(ou)


# --- chez l'hôte ---

func avancer(dt: float) -> void:
	if mode == DORT:
		return
	_interet = maxf(_interet - dt * 1.5, 0.0)
	_repue = maxf(_repue - dt, 0.0)
	_pense -= dt
	if _pense <= 0.0:
		_pense = 0.2
		_chercher()
	var vitesse: float = R.CHOSE_RODE
	match mode:
		ALERTE:
			# elle a vu un porteur : elle se tourne vers lui et crie, sans avancer. C'est le moment de fuir.
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
			return
		CHASSE:
			vitesse = R.CHOSE_CHASSE
			_souffle -= dt
			var j = principal.joueurs.get(proie)
			if j == null or not j.vivant:
				_roder(1.0)
			elif _a_plat(j.global_position) < R.CHOSE_ALLONGE and _vu <= 0.0:
				principal.frapper(proie)       # (le premier coup blesse, le suivant tue)
				rentrer()
			elif _vu > R.CHOSE_PERTE:
				mode = ENQUETE
				_aller(_dernier)
			elif _souffle <= 0.0:              # essoufflée : elle s'arrête, et ne regarde plus un moment
				_repue = 4.0
				_roder(4.0)
			else:
				_trace -= dt
				if _trace <= 0.0:
					_trace = 0.3
					_aller(j.global_position)
				if _i >= route.size() and maison.dedans(j.global_position):      # dans la même case : droit sur lui
					_vers(j.global_position, vitesse, dt)
		ENQUETE:
			vitesse = R.CHOSE_ENQUETE
			if _i >= route.size():
				_roder(2.5)
		RODE:
			if _repue > 0.0:                   # (elle rentre d'un bon pas)
				vitesse = R.CHOSE_ENQUETE
			if _i >= route.size():
				_attente -= dt
				if _attente <= 0.0:
					_attente = principal.hasard.randf_range(1.0, 3.0)
					_aller(maison.case_au_hasard(principal.hasard))
	if _i < route.size():
		if _vers(route[_i], vitesse, dt):
			_i += 1


func _a_plat(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _roder(attente: float) -> void:
	mode = RODE
	proie = -1
	_interet = 0.0
	_attente = attente
	route = PackedVector3Array()
	_i = 0


# après un coup : elle rentre à sa tanière, sans rien regarder en chemin
func rentrer() -> void:
	_roder(3.0)
	_repue = R.CHOSE_REPUE
	_aller(maison.taniere)


# elle ne sort pas de la maison : ce qui l'appelle dehors l'amène au seuil, pas plus loin
func _aller(ou: Vector3) -> void:
	route = maison.chemin(global_position, ou if maison.dedans(ou) else maison.seuil)
	_i = 1 if route.size() > 1 else 0     # la première case est celle où elle est


# un pas vers un point ; vrai quand elle y est
func _vers(p: Vector3, vitesse: float, dt: float) -> bool:
	var d := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
	if d.length() < 0.12:
		return true
	global_position += d.normalized() * minf(vitesse * dt, d.length())
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(1.0, dt * 8.0))
	return false


func _voit(j, portee: float) -> bool:
	return j.vivant and maison.dedans(j.global_position) and global_position.distance_to(j.global_position) < portee \
		and maison.voit(yeux(), j.global_position + Vector3(0.0, 1.0, 0.0))


# qui voit-elle ? En chasse, elle ne suit que sa proie. Sinon : le plus proche des vivants, dans la maison, devant elle (ou tout
# près), à portée, sans mur entre eux. Alors elle crie avant de s'élancer.
func _chercher() -> void:
	if mode == ALERTE or _repue > 0.0:
		return
	if mode == CHASSE:
		var p = principal.joueurs.get(proie)
		if p != null and _voit(p, R.CHOSE_VUE * 1.3):
			_vu = 0.0
			_dernier = p.global_position
		else:
			_vu += 0.2
		return
	var avant := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	var mieux := -1
	var pres := 1e9
	for j in principal.joueurs.values():
		var d: float = global_position.distance_to(j.global_position)
		var vers: Vector3 = (j.global_position - global_position) * Vector3(1.0, 0.0, 1.0)
		if d >= pres or (d > R.CHOSE_PRES and avant.dot(vers.normalized()) < R.CHOSE_CONE):
			continue
		if _voit(j, R.CHOSE_VUE * (R.CHOSE_VUE_ACCROUPI if j.accroupi else 1.0)):
			mieux = j.id
			pres = d
	if mieux >= 0:
		mode = ALERTE
		proie = mieux
		_alerte = R.CHOSE_ALERTE
		_dernier = principal.joueurs[mieux].global_position
		route = PackedVector3Array()
		_i = 0
		principal.reperer(mieux)


# --- chez tout le monde ---

func _process(dt: float) -> void:
	if not principal.serveur:
		global_position = global_position.lerp(cible_pos, minf(1.0, dt * 12.0))
		rotation.y = lerp_angle(rotation.y, cible_yaw, minf(1.0, dt * 10.0))
	visible = mode != DORT
	var volume: float = [-80.0, -14.0, -7.0, 0.0, 3.0][mode]
	_son.volume_db = lerpf(_son.volume_db, volume, minf(1.0, dt * 3.0))
	_son.pitch_scale = lerpf(_son.pitch_scale, 1.35 if mode == CHASSE or mode == ALERTE else 1.0, minf(1.0, dt * 3.0))
