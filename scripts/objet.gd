extends RigidBody3D
# Portefaix — un meuble (scripts/objet.gd)
# Un corps qui tombe, se cogne et se casse. On le prend avec ses bras : chaque main s'accroche en un point du meuble et le tire
# vers elle, de sa force seulement (ce qui pèse trop se traîne, ou se porte à plusieurs). Un bras trop tendu s'arrache.
# Chez l'hôte, la physique est vraie, et un choc coûte au meuble de sa valeur. Chez les autres, il suit l'hôte.
# Ce qui est accroché à un mur (un tableau, un miroir) y tient tant qu'on ne l'a pas pris.

const R = preload("res://scripts/regles.gd")

signal choc(objet, force)

var id := 0
var type := ""
var nom := ""
var taille := Vector3.ONE
var valeur_neuve := 0
var valeur := 0
var fragile := 0.0
var accroche := false             # tient encore à son mur
var prises: Array = []            # les mains qui le tiennent : [joueur, côté (0 gauche, 1 droite), point d'accroche (dans le meuble)]
var porteurs: Array = []          # les numéros des joueurs qui le tiennent (tiré des prises)
var principal
var cible_pos := Vector3.ZERO     # chez les invités : où l'hôte dit qu'il est
var cible_rot := Quaternion.IDENTITY
var _v_avant := Vector3.ZERO
var _calme := 2.0                 # pas de casse pendant que la maison se pose


func preparer(p, i: int, t: String) -> void:
	principal = p
	id = i
	type = t
	name = "o%d" % i
	var d: Dictionary = R.CATALOGUE[t]
	nom = d.nom
	taille = d.taille
	mass = d.masse
	valeur_neuve = d.valeur
	valeur = valeur_neuve
	fragile = d.fragile
	collision_layer = R.COUCHE_OBJETS if mass >= R.OBJET_LEGER else R.COUCHE_LEGERS      # (le fantôme bute sur ce qui pèse, pas sur un vase)
	collision_mask = R.COUCHE_DECOR | R.COUCHE_OBJETS | R.COUCHE_LEGERS | R.COUCHE_JOUEURS
	var matiere := PhysicsMaterial.new()
	matiere.friction = 0.45
	matiere.bounce = 0.05
	physics_material_override = matiere
	angular_damp = 0.6
	var forme := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = taille
	forme.shape = b
	add_child(forme)
	for piece in _pieces(d.couleur):
		var mesh := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = taille * Vector3(piece[3], piece[4], piece[5])
		mesh.mesh = m
		mesh.position = taille * Vector3(piece[0], piece[1], piece[2])
		var mat := StandardMaterial3D.new()
		mat.albedo_color = piece[6]
		mat.roughness = 0.85
		mesh.material_override = mat
		add_child(mesh)
	if not principal.serveur:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true


# accroché à un mur : il ne tombe pas tant qu'on ne l'a pas pris
func accrocher() -> void:
	accroche = true
	if principal.serveur:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true


func decrocher() -> void:
	if accroche:
		accroche = false
		if principal.serveur:
			freeze = false
			sleeping = false


# le dessin : des boîtes, en parts de la taille (centre x y z, taille x y z, couleur) ; le devant est vers +z
func _pieces(c: Color) -> Array:
	var sombre := c.darkened(0.35)
	var clair := c.lightened(0.3)
	var noir := Color(0.07, 0.07, 0.08)
	var pieds := [[-0.42, -0.26, -0.42, 0.14, 0.48, 0.14, sombre], [0.42, -0.26, -0.42, 0.14, 0.48, 0.14, sombre],
		[-0.42, -0.26, 0.42, 0.14, 0.48, 0.14, sombre], [0.42, -0.26, 0.42, 0.14, 0.48, 0.14, sombre]]
	match type:
		"carton":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0.5, 0, 0.16, 0.02, 1.01, clair]]
		"coussin":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0.5, 0, 0.7, 0.1, 0.7, clair]]
		"panier":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0.5, 0, 0.9, 0.04, 0.9, Color(0.9, 0.9, 0.86)]]
		"chaise":
			return [[0, 0, 0, 1, 0.08, 1, c], [0, 0.28, -0.44, 1, 0.48, 0.12, c]] + pieds
		"lampe":
			return [[0, -0.48, 0, 1, 0.04, 1, sombre], [0, -0.05, 0, 0.14, 0.84, 0.14, sombre], [0, 0.38, 0, 1, 0.24, 1, c]]
		"lampe_chevet":
			return [[0, -0.42, 0, 0.6, 0.16, 0.6, sombre], [0, -0.12, 0, 0.2, 0.5, 0.2, sombre], [0, 0.25, 0, 1, 0.5, 1, c]]
		"reveil":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0, 0.5, 0.7, 0.7, 0.1, Color(0.95, 0.95, 0.9)]]
		"vase":
			return [[0, -0.1, 0, 1, 0.8, 1, c], [0, 0.4, 0, 0.5, 0.2, 0.5, clair]]
		"plante":
			return [[0, -0.38, 0, 0.7, 0.24, 0.7, Color(0.6, 0.35, 0.22)], [0, 0.1, 0, 1, 0.72, 1, c], [0, 0.34, 0, 0.6, 0.32, 0.6, clair]]
		"tableau":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0, 0.5, 0.82, 0.76, 0.1, Color(0.2, 0.42, 0.45)], [0.1, -0.1, 0.56, 0.3, 0.3, 0.05, Color(0.8, 0.5, 0.3)]]
		"miroir":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0, 0.5, 0.86, 0.9, 0.2, Color(0.7, 0.8, 0.85)]]
		"boite_bijoux":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0.5, 0, 1.03, 0.12, 1.03, Color(0.85, 0.68, 0.25)]]
		"ordinateur":
			return [[0, 0.12, -0.2, 1, 0.72, 0.2, c], [0, 0.12, -0.08, 0.92, 0.62, 0.06, Color(0.15, 0.25, 0.4)], [0, -0.38, -0.2, 0.3, 0.24, 0.5, sombre],
				[0, -0.46, 0.3, 0.8, 0.06, 0.35, sombre]]
		"tele":
			return [[0, 0.08, 0, 1, 0.84, 0.3, c], [0, 0.08, 0.16, 0.92, 0.74, 0.04, Color(0.12, 0.18, 0.28)], [0, -0.42, 0, 0.4, 0.16, 1, sombre]]
		"micro_ondes":
			return [[0, 0, 0, 1, 1, 1, c], [-0.12, 0, 0.5, 0.62, 0.7, 0.04, noir]]
		"grille_pain":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0.5, 0, 0.7, 0.06, 0.3, noir]]
		"casserole":
			return [[0, 0, 0, 1, 1, 1, c], [0.72, 0.3, 0, 0.5, 0.16, 0.16, noir]]
		"assiettes":
			return [[0, -0.33, 0, 1, 0.3, 1, c], [0, 0, 0, 0.95, 0.3, 0.95, clair], [0, 0.33, 0, 0.9, 0.3, 0.9, c]]
		"table_nuit":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0.15, 0.5, 0.8, 0.3, 0.04, sombre]]
		"table_basse":
			return [[0, 0.4, 0, 1, 0.2, 1, c]] + pieds.map(func(p): return [p[0], -0.1, p[2], 0.08, 0.8, 0.14, sombre])
		"meuble_tele":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0, 0.5, 0.9, 0.6, 0.03, sombre]]
		"table":
			return [[0, 0.45, 0, 1, 0.1, 1, c]] + pieds.map(func(p): return [p[0], -0.05, p[2], 0.08, 0.9, 0.14, sombre])
		"bureau":
			return [[0, 0.46, 0, 1, 0.08, 1, c], [-0.34, -0.04, 0, 0.3, 0.92, 0.95, sombre], [0.47, -0.04, 0, 0.05, 0.92, 0.95, sombre]]
		"fauteuil", "canape":
			return [[0, -0.2, 0.06, 1, 0.6, 0.88, c], [0, 0.2, -0.4, 1, 0.6, 0.2, sombre],
				[-0.45, 0.12, 0.06, 0.1, 0.3, 0.88, sombre], [0.45, 0.12, 0.06, 0.1, 0.3, 0.88, sombre]]
		"commode":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0.28, 0.5, 0.9, 0.02, 0.03, sombre], [0, 0, 0.5, 0.9, 0.02, 0.03, sombre], [0, -0.28, 0.5, 0.9, 0.02, 0.03, sombre]]
		"buffet":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0, 0.5, 0.02, 0.86, 0.04, sombre], [-0.25, 0.05, 0.52, 0.03, 0.06, 0.06, clair], [0.25, 0.05, 0.52, 0.03, 0.06, 0.06, clair]]
		"horloge":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0.34, 0.5, 0.62, 0.16, 0.04, Color(0.9, 0.86, 0.7)], [0, -0.1, 0.5, 0.3, 0.42, 0.04, Color(0.7, 0.55, 0.2)]]
		"cuisiniere":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0.5, 0, 1.0, 0.03, 1.0, noir], [0, -0.1, 0.5, 0.8, 0.5, 0.03, noir]]
		"bibliotheque":
			return [[0, 0, -0.1, 1, 1, 0.8, c], [0, 0.34, 0.3, 0.86, 0.14, 0.4, Color(0.55, 0.2, 0.18)], [0, 0.1, 0.3, 0.86, 0.14, 0.4, Color(0.2, 0.35, 0.5)],
				[0, -0.14, 0.3, 0.86, 0.14, 0.4, Color(0.5, 0.45, 0.25)], [0, -0.38, 0.3, 0.86, 0.14, 0.4, Color(0.25, 0.42, 0.3)]]
		"lit":
			return [[0, -0.2, 0, 1, 0.6, 1, c], [0, 0.26, 0.01, 0.96, 0.48, 0.96, Color(0.92, 0.9, 0.85)], [0, 0.4, 0.18, 0.98, 0.22, 0.62, Color(0.3, 0.4, 0.55)],
				[0, 0.6, -0.49, 1, 0.9, 0.03, sombre]]
		"machine_laver":
			return [[0, 0, 0, 1, 1, 1, c], [0, -0.05, 0.5, 0.5, 0.4, 0.03, noir], [0, 0.4, 0.5, 0.9, 0.1, 0.03, Color(0.7, 0.7, 0.72)]]
		"frigo":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0.15, 0.5, 1, 0.01, 0.02, sombre], [0.38, 0.0, 0.52, 0.04, 0.3, 0.04, sombre]]
		"armoire":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0, 0.5, 0.02, 0.92, 0.04, sombre], [-0.06, 0, 0.52, 0.03, 0.05, 0.06, clair], [0.06, 0, 0.52, 0.03, 0.05, 0.06, clair]]
		"piano":
			return [[0, 0, -0.1, 1, 1, 0.8, c], [0, 0.05, 0.38, 0.94, 0.06, 0.24, Color(0.92, 0.9, 0.85)], [0, -0.3, 0.3, 0.9, 0.4, 0.1, c]]
	return [[0, 0, 0, 1, 1, 1, c]]


# trop lourd pour qu'un seul le soulève ?
func lourd() -> bool:
	return mass * 9.8 > R.FORCE_PORTEUR


# où chaque main s'accroche : sur la face tournée vers le porteur, la gauche à sa gauche, la droite à sa droite
func accroches(j, cotes: Array) -> Array:
	var vers: Vector3 = global_transform.basis.inverse() * (j.tete.global_position - global_position)
	vers.y = 0.0
	if vers.length() < 0.01:
		vers = Vector3(0, 0, 1)
	vers = vers.normalized()
	var demi := taille * 0.5
	# jusqu'à la face : la plus petite des distances au bord, le long de cette direction
	var k := minf(demi.x / maxf(absf(vers.x), 0.001), demi.z / maxf(absf(vers.z), 0.001))
	var face := vers * k
	var travers := Vector3(-vers.z, 0.0, vers.x)        # le long de la face
	var ecart: float = minf(R.BRAS_ECART, maxf(absf(travers.x) * demi.x + absf(travers.z) * demi.z - 0.03, 0.02))
	var liste: Array = []
	for cote in cotes:
		var signe := -1.0 if cote == 0 else 1.0
		# (la main gauche du porteur est du côté de sa gauche : vu du meuble, c'est l'autre sens)
		var point := face - travers * signe * ecart
		point.x = clampf(point.x, -demi.x, demi.x)
		point.z = clampf(point.z, -demi.z, demi.z)
		liste.append([j.id, cote, point])
	return liste


func definir_prises(liste: Array) -> void:
	var nouveaux: Array = []
	for p in liste:
		if not nouveaux.has(p[0]):
			nouveaux.append(p[0])
	for pid in porteurs:
		if not nouveaux.has(pid) and principal.joueurs.has(pid):
			remove_collision_exception_with(principal.joueurs[pid])
	for pid in nouveaux:
		if not porteurs.has(pid) and principal.joueurs.has(pid):
			add_collision_exception_with(principal.joueurs[pid])
	prises = liste.duplicate(true)
	porteurs = nouveaux
	angular_damp = 4.0 if not prises.is_empty() else 0.6
	if not prises.is_empty():
		decrocher()
	sleeping = false


# un bras arraché reste un moment pendu là où il tenait
func laisser_bras(point: Vector3, couleur: Color) -> void:
	var n := Node3D.new()
	n.position = point
	add_child(n)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = couleur
	mat.roughness = 0.9
	for i in 4:
		var mesh := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.11, 0.11, 0.13) if i == 3 else Vector3(0.07, 0.26, 0.07)
		mesh.mesh = b
		mesh.material_override = mat
		mesh.position = Vector3(0.0, -0.13 - 0.26 * i if i < 3 else -0.84, 0.03 * i)
		n.add_child(mesh)
	get_tree().create_timer(6.0).timeout.connect(n.queue_free)


func ancre(prise: Array) -> Vector3:
	return global_transform * (prise[2] as Vector3)


func _physics_process(dt: float) -> void:
	if not principal.serveur:
		return
	_calme = maxf(_calme - dt, 0.0)
	var dv := (linear_velocity - _v_avant).length()
	_v_avant = linear_velocity
	if dv > R.CHOC_SEUIL and _calme <= 0.0:
		_calme = 0.25
		choc.emit(self, dv)
	if prises.is_empty():
		return
	sleeping = false
	var n := float(prises.size())
	var mains := {}                  # par porteur : où sont sa main gauche et sa main droite
	for prise in prises:
		var j = principal.joueurs.get(prise[0])
		if j == null or not j.vivant:
			principal.lacher(prise[0], id, false)
			return
		var a := ancre(prise)
		if j.epaule(prise[1]).distance_to(a) > R.BRAS_MAX:      # trop tendu : le bras s'arrache
			principal.arracher(prise[0], prise[1], id)
			return
		# chaque bras tire le meuble vers le point de prise de son porteur, de la moitié de la force de celui-ci
		var vers: Vector3 = j.point_de_prise(taille) - global_position
		var v := vers * R.PORT_RAIDEUR
		if v.length() > R.PORT_VITESSE:
			v = v.normalized() * R.PORT_VITESSE
		var f := (v - linear_velocity) * mass * R.PORT_GAIN / n
		if f.length() > R.FORCE_PORTEUR * 0.5:
			f = f.normalized() * R.FORCE_PORTEUR * 0.5
		apply_central_force(f)
		if not mains.has(prise[0]):
			mains[prise[0]] = [null, null]
		mains[prise[0]][prise[1]] = a
	# qui le tient à deux mains le garde face à lui : le meuble tourne avec son porteur
	var inertie := mass * (taille.x * taille.x + taille.z * taille.z) / 12.0
	for pid in mains:
		if mains[pid][0] == null or mains[pid][1] == null:
			continue
		var axe: Vector3 = (mains[pid][1] - mains[pid][0]) * Vector3(1, 0, 1)
		var droite: Vector3 = principal.joueurs[pid].tete.global_transform.basis.x * Vector3(1, 0, 1)
		if axe.length() > 0.05 and droite.length() > 0.05:
			var ecart := axe.normalized().signed_angle_to(droite.normalized(), Vector3.UP)
			apply_torque(Vector3.UP * (ecart * 40.0 - angular_velocity.y * 8.0) * inertie / float(mains.size()))


func _process(dt: float) -> void:
	if principal.serveur:
		return
	var k := minf(1.0, dt * 15.0)
	global_position = global_position.lerp(cible_pos, k)
	quaternion = quaternion.slerp(cible_rot, k)
