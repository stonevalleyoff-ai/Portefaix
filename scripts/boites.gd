extends RefCounted
# Portefaix — des boîtes fondues en un seul maillage (scripts/boites.gd)
# Tout le jeu est fait de boîtes. Une par maillage, une maison en compte plus de mille à l'écran : dans un navigateur, passé ce
# nombre, plus rien ne se dessine. On les fond donc : un meuble est un seul maillage, un pan de maison aussi. Chaque boîte garde sa
# couleur, portée par ses sommets.

# les six faces d'une boîte : leur normale, et un côté
const FACES := [[Vector3.RIGHT, Vector3.UP], [Vector3.LEFT, Vector3.UP], [Vector3.UP, Vector3.BACK], [Vector3.DOWN, Vector3.BACK], [Vector3.BACK, Vector3.RIGHT], [Vector3.FORWARD, Vector3.RIGHT]]
static var _teinte: StandardMaterial3D

var _sommets := PackedVector3Array()
var _normales := PackedVector3Array()
var _couleurs := PackedColorArray()
var _indices := PackedInt32Array()


# la matière de tous : la couleur est dans les sommets
static func teinte() -> StandardMaterial3D:
	if _teinte == null:
		_teinte = StandardMaterial3D.new()
		_teinte.vertex_color_use_as_albedo = true
		_teinte.vertex_color_is_srgb = true      # (nos couleurs sont celles qu'on voit, comme celles des autres matières)
		_teinte.roughness = 0.88
	return _teinte


func vide() -> bool:
	return _sommets.is_empty()


# une boîte de plus : son milieu, sa taille, sa couleur, et comment elle est tournée
func ajouter(centre: Vector3, taille: Vector3, couleur: Color, base: Basis = Basis.IDENTITY) -> void:
	var d := _sommets.size()
	var demi := taille * 0.5
	for face in FACES:                               # six faces, quatre sommets chacune, deux triangles (dans le sens des aiguilles, vus du dehors)
		var n: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = n.cross(u)
		for coin: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			_sommets.append(centre + base * ((n + u * coin.x + v * coin.y) * demi))
			_normales.append(base * n)
			_couleurs.append(couleur)
		for k in [0, 2, 1, 0, 3, 2]:
			_indices.append(d + k)
		d += 4


func maillage() -> ArrayMesh:
	var t := []
	t.resize(Mesh.ARRAY_MAX)
	t[Mesh.ARRAY_VERTEX] = _sommets
	t[Mesh.ARRAY_NORMAL] = _normales
	t[Mesh.ARRAY_COLOR] = _couleurs
	t[Mesh.ARRAY_INDEX] = _indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, t)
	return m


# le maillage, dans un nœud prêt à poser
func noeud() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = maillage()
	mesh.material_override = teinte()
	return mesh
