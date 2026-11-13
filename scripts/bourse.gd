extends RefCounted
# Portefaix — la caisse du porteur (scripts/bourse.gd)
# Ce qu'il lui reste des nuits passées, une fois l'agence, les frais, les cotisations et l'impôt servis : de quoi s'équiper à la
# boutique. Quand une nuit coûte plus qu'elle ne rapporte, la caisse passe sous zéro : c'est une dette, elle porte intérêt à chaque
# nuit, et passé un certain montant l'huissier vient saisir. Gardée sur l'appareil, une caisse par compte.

const R = preload("res://scripts/regles.gd")

var argent := 0                   # sous zéro : une dette
var objets := {}                  # ce qu'il a acheté : le nom → combien
var nuits := 0
var cle := "invite"
var garder := true                # (les essais ne gardent rien sur l'appareil)


func _chemin() -> String:
	return "user://bourse-%s.json" % cle.md5_text().left(12)


# la caisse de ce compte (ou celle de qui joue sans compte)
func ouvrir(c: String) -> void:
	cle = c if c != "" else "invite"
	argent = 0
	objets = {}
	nuits = 0
	if not garder or not FileAccess.file_exists(_chemin()):
		return
	var f := FileAccess.open(_chemin(), FileAccess.READ)
	if f == null:
		return
	var lu = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(lu) != TYPE_DICTIONARY:
		return
	argent = int(lu.get("argent", 0))
	nuits = int(lu.get("nuits", 0))
	var o = lu.get("objets", {})
	if typeof(o) == TYPE_DICTIONARY:
		for nom in o:
			if R.BOUTIQUE.has(nom) and int(o[nom]) > 0:
				objets[nom] = int(o[nom])


func sauver() -> void:
	if not garder:
		return
	var f := FileAccess.open(_chemin(), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"argent": argent, "objets": objets, "nuits": nuits}))
	f.close()


func a(nom: String) -> bool:
	return int(objets.get(nom, 0)) > 0


func combien(nom: String) -> int:
	return int(objets.get(nom, 0))


# ce qu'il emporte pour la nuit
func equipement() -> Array:
	var e: Array = []
	for nom in objets:
		if a(nom):
			e.append(nom)
	return e


# acheter : "" si c'est fait, sinon pourquoi non
func acheter(nom: String) -> String:
	if not R.BOUTIQUE.has(nom):
		return "La boutique n'a pas ça."
	var article: Dictionary = R.BOUTIQUE[nom]
	if argent < 0:
		return "On ne fait pas crédit à qui doit déjà %d €." % -argent
	if combien(nom) >= (R.STOCK_MAX if article.une_fois else 1):
		return "Tu en as déjà." if not article.une_fois else "Tu n'en porteras pas plus de %d." % R.STOCK_MAX
	if argent < article.prix:
		return "Il te manque %d €." % (article.prix - argent)
	argent -= article.prix
	objets[nom] = combien(nom) + 1
	sauver()
	return ""


# ce qui ne sert qu'une fois : en voilà un de moins
func consommer(nom: String) -> void:
	if a(nom):
		objets[nom] = combien(nom) - 1
		if objets[nom] <= 0:
			objets.erase(nom)
		sauver()


# la fin d'une nuit : sa part, bonne ou mauvaise. Rend ce qu'il faut lui dire (les intérêts, l'huissier).
func encaisser(part: int) -> Array:
	var dit: Array = []
	if argent < 0:
		var interets := int(ceil(-argent * R.INTERETS))
		argent -= interets
		dit.append("Les intérêts de ta dette (%d %%) : −%d €" % [int(R.INTERETS * 100), interets])
	argent += part
	nuits += 1
	while argent < -R.SAISIE:              # l'huissier : il prend ce que tu as de plus cher, et le reprend à moitié prix
		var pris := ""
		for nom in objets:
			if a(nom) and (pris == "" or R.BOUTIQUE[nom].prix > R.BOUTIQUE[pris].prix):
				pris = nom
		if pris == "":
			break
		objets[pris] = combien(pris) - 1
		if objets[pris] <= 0:
			objets.erase(pris)
		var repris := int(R.BOUTIQUE[pris].prix * 0.5)
		argent += repris
		dit.append("L'huissier est passé : il a saisi %s (repris %d €)." % [R.BOUTIQUE[pris].nom, repris])
	sauver()
	return dit


func dire() -> String:
	return "En caisse : %d €" % argent if argent >= 0 else "Dette : %d € (%d %% d'intérêts par nuit)" % [-argent, int(R.INTERETS * 100)]
