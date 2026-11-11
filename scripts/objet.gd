extends RigidBody3D
# Portefaix — un meuble (scripts/objet.gd)
# Un corps qui tombe, se cogne et se casse. Chez l'hôte, la physique est vraie : chaque porteur le tire vers sa main, de sa force
# seulement (ce qui pèse trop se traîne, ou se porte à plusieurs), et un choc lui coûte de sa valeur. Chez les autres, il suit l'hôte.

const R = preload("res://scripts/regles.gd")

signal choc(objet, force)

var id := 0
var type := ""
var nom := ""
var taille := Vector3.ONE
var valeur_neuve := 0
var valeur := 0
var fragile := 0.0
var porteurs: Array = []          # les numéros des joueurs qui le tiennent
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
	collision_layer = 2
	collision_mask = 1 | 2 | 4
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


# le dessin : des boîtes, en parts de la taille (centre x y z, taille x y z, couleur)
func _pieces(c: Color) -> Array:
	var sombre := c.darkened(0.35)
	var clair := c.lightened(0.3)
	match type:
		"carton":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0.5, 0, 0.16, 0.02, 1.01, clair]]
		"chaise":
			return [[0, 0, 0, 1, 0.08, 1, c], [0, 0.28, -0.44, 1, 0.48, 0.12, c],
				[-0.42, -0.26, -0.42, 0.14, 0.48, 0.14, sombre], [0.42, -0.26, -0.42, 0.14, 0.48, 0.14, sombre],
				[-0.42, -0.26, 0.42, 0.14, 0.48, 0.14, sombre], [0.42, -0.26, 0.42, 0.14, 0.48, 0.14, sombre]]
		"lampe":
			return [[0, -0.48, 0, 1, 0.04, 1, sombre], [0, -0.05, 0, 0.14, 0.84, 0.14, sombre], [0, 0.38, 0, 1, 0.24, 1, c]]
		"vase":
			return [[0, -0.1, 0, 1, 0.8, 1, c], [0, 0.4, 0, 0.5, 0.2, 0.5, clair]]
		"tableau":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0, 0.5, 0.82, 0.76, 0.1, Color(0.2, 0.42, 0.45)], [0.1, -0.1, 0.56, 0.3, 0.3, 0.05, Color(0.8, 0.5, 0.3)]]
		"table":
			return [[0, 0.45, 0, 1, 0.1, 1, c], [-0.44, -0.05, -0.4, 0.08, 0.9, 0.14, sombre], [0.44, -0.05, -0.4, 0.08, 0.9, 0.14, sombre],
				[-0.44, -0.05, 0.4, 0.08, 0.9, 0.14, sombre], [0.44, -0.05, 0.4, 0.08, 0.9, 0.14, sombre]]
		"fauteuil", "canape":
			return [[0, -0.2, 0.06, 1, 0.6, 0.88, c], [0, 0.2, -0.4, 1, 0.6, 0.2, sombre],
				[-0.45, 0.12, 0.06, 0.1, 0.3, 0.88, sombre], [0.45, 0.12, 0.06, 0.1, 0.3, 0.88, sombre]]
		"tele":
			return [[0, 0.08, 0, 1, 0.84, 0.3, c], [0, 0.08, 0.16, 0.92, 0.74, 0.04, Color(0.12, 0.18, 0.28)], [0, -0.42, 0, 0.4, 0.16, 1, sombre]]
		"horloge":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0.34, 0.5, 0.62, 0.16, 0.04, Color(0.9, 0.86, 0.7)], [0, -0.1, 0.5, 0.3, 0.42, 0.04, Color(0.7, 0.55, 0.2)]]
		"armoire":
			return [[0, 0, 0, 1, 1, 1, c], [0, 0, 0.5, 0.02, 0.92, 0.04, sombre], [-0.06, 0, 0.52, 0.03, 0.05, 0.06, clair], [0.06, 0, 0.52, 0.03, 0.05, 0.06, clair]]
		"piano":
			return [[0, 0, -0.1, 1, 1, 0.8, c], [0, 0.05, 0.38, 0.94, 0.06, 0.24, Color(0.92, 0.9, 0.85)], [0, -0.3, 0.3, 0.9, 0.4, 0.1, c]]
	return [[0, 0, 0, 1, 1, 1, c]]


# trop lourd pour qu'un seul le soulève ?
func lourd() -> bool:
	return mass * 9.8 > R.FORCE_PORTEUR


func definir_porteurs(liste: Array) -> void:
	for pid in porteurs:
		if not liste.has(pid) and principal.joueurs.has(pid):
			remove_collision_exception_with(principal.joueurs[pid])
	for pid in liste:
		if not porteurs.has(pid) and principal.joueurs.has(pid):
			add_collision_exception_with(principal.joueurs[pid])
	porteurs = liste.duplicate()
	angular_damp = 5.0 if not porteurs.is_empty() else 0.6
	sleeping = false


func _physics_process(dt: float) -> void:
	if not principal.serveur:
		return
	_calme = maxf(_calme - dt, 0.0)
	var dv := (linear_velocity - _v_avant).length()
	_v_avant = linear_velocity
	if dv > R.CHOC_SEUIL and _calme <= 0.0:
		_calme = 0.25
		choc.emit(self, dv)
	if porteurs.is_empty():
		return
	sleeping = false
	var n := float(porteurs.size())
	for pid in porteurs.duplicate():
		var j = principal.joueurs.get(pid)
		if j == null or not j.vivant:
			principal.lacher(pid, id, false)
			continue
		var vers: Vector3 = j.point_de_prise(taille) - global_position
		if vers.length() > R.PORT_RUPTURE:
			principal.lacher(pid, id, false)
			continue
		var v := vers * R.PORT_RAIDEUR
		if v.length() > R.PORT_VITESSE:
			v = v.normalized() * R.PORT_VITESSE
		var f := (v - linear_velocity) * mass * R.PORT_GAIN / n
		if f.length() > R.FORCE_PORTEUR:
			f = f.normalized() * R.FORCE_PORTEUR
		apply_central_force(f)


func _process(dt: float) -> void:
	if principal.serveur:
		return
	var k := minf(1.0, dt * 15.0)
	global_position = global_position.lerp(cible_pos, k)
	quaternion = quaternion.slerp(cible_rot, k)
