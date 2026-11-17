extends CanvasLayer
# Portefaix — ce qui s'écrit à l'écran (scripts/interface.gd)
# Le menu, le salon d'attente, la partie (l'heure, le quota, le bruit qu'on fait, le vote du chat, ce qu'on regarde), la pause et
# la fin. Leur allure : scripts/charte.gd ; derrière le menu et les pages du compte, le manoir la nuit : scripts/decor_menu.gd.
# Le menu principal : le titre, à gauche, et ses entrées (jouer seul, à plusieurs, le lieu, la boutique, les réglages, le portail,
# quitter) ; en haut à droite, qui l'on est et sa caisse ; à droite, un volet qui s'ouvre pour jouer à plusieurs ou régler.

const R = preload("res://scripts/regles.gd")
const Charte = preload("res://scripts/charte.gd")
const DecorMenu = preload("res://scripts/decor_menu.gd")

signal seul
signal heberger
signal rejoindre(adresse: String)
signal commencer
signal rejouer
signal quitter
signal connexion(email: String, mot_de_passe: String)
signal deconnexion
signal sans_compte
signal vers_connexion
signal pseudo_choisi(pseudo: String)
signal creation(email: String, mot_de_passe: String, pseudo: String)
signal oubli(email: String)
signal nouveau_mot_de_passe(nouveau: String, encore: String)
signal page_compte                 # on change de page de compte : ce qui était écrit ne vaut plus
signal salon_creer
signal salon_rejoindre(code: String)
signal vers_boutique
signal lieu_change
signal achat(nom: String)
signal pause_voulue(oui: bool)

var _menu: Control                 # les entrées du menu principal
var _menu_racine: Control
var _menu_colonne: VBoxContainer
var _logo: Label
var _devise: Label
var _editeur: Label
var _decor: Control
var _racine: Control
var _racines := {}                 # chaque page → ce qui la porte à l'écran (ce qu'on montre ou cache)
var _volet_carte: PanelContainer   # le volet de droite : jouer à plusieurs, ou les réglages
var _volet_titre: Label
var _volets := {}                  # son nom → son contenu
var _volet_ouvert := ""
var _volet_dans: VBoxContainer
var _b_plusieurs: Button
var _b_reglages: Button
var _b_portail: Button
var _b_quitter_jeu: Button
var _barre_compte: HBoxContainer
var _pause: Control
var _pause_dit: Label
var _pause_retour: Button
var _pause_quitter: Button
var _pause_aide: Label
var _pause_b_aide: Button
var _salon: Control
var _partie: Control
var _fin: Control
var _avis: Label
var _adresse: LineEdit
var _chaine: LineEdit
var _micro: CheckBox
var _salon_texte: Label
var _salon_code: Label
var _salon_bouton: Button
var _heure: Label
var _quota: Label
var _bruit: ProgressBar
var _indice: Label
var _annonce: Label
var _annonce_reste := 0.0
var _vote: PanelContainer
var _vote_texte: Label
var _mort: Label
var _fin_texte: Label
var _fin_rejouer: Button
var _aide: Label
var _trouble: ColorRect
var _fin_defile: ScrollContainer
var _b_partir: Button
var _b_lieu: Button
var _dose: Label
var _vert: ColorRect
var _screamer: Control
var _screamer_face: Control
var _screamer_gueule: Control
var _screamer_reste := 0.0
var _boutique: Control
var _boutique_lignes: VBoxContainer
var _boutique_caisse: Label
var _boutique_avis: Label
var _boutique_boutons := {}
var _b_boutique: Button
var _bourse_texte: Label
var _fin_compte: Label
var _connexion: Control
var _creation: Control
var _oubli: Control
var _nouveau: Control
var _avis_compte: Array = []      # la ligne d'avis de chaque page de compte : la même partout
var _c: Dictionary = {}           # les champs et les boutons des pages de compte, par leur nom
var _email: LineEdit
var _mdp: LineEdit
var _connexion_avis: Label
var _connexion_bouton: Button
var _compte_texte: Label
var _compte_bouton: Button
var _pseudo_ligne: HBoxContainer
var _pseudo: LineEdit
var _connecte := false
var _ligne_bloc: VBoxContainer     # jouer en ligne : ouvrir un salon, ou entrer par un code
var _ligne_creer: Button
var _ligne_rang: HBoxContainer
var _ligne_code: LineEdit
var _ligne_note: Label
var _ligne_possible := false
var _b_seul: Button
var _b_entrer: Button
var _b_sans: Button
var _en_ligne: Array = []          # ce qui demande le réseau du dehors : le compte, le chat de Twitch
var _reseau: Array = []           # ce qui sert à jouer à plusieurs, caché dans un navigateur


func _ready() -> void:
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.theme = Charte.theme()
	add_child(racine)
	_racine = racine
	_decor = DecorMenu.new()
	racine.add_child(_decor)
	_connexion = _page(racine)
	_creation = _page(racine)
	_oubli = _page(racine)
	_nouveau = _page(racine)
	_salon = _page(racine)
	_fin = _page(racine)
	_boutique = _page(racine)
	_pause = _page(racine)
	_racines[_pause].color = Color(0.01, 0.012, 0.02, 0.62)
	_racines[_fin].color = Color(0.01, 0.012, 0.02, 0.72)     # (à la fin, c'est la maison qu'on voit derrière, assombrie)
	_partie = Control.new()
	_partie.set_anchors_preset(Control.PRESET_FULL_RECT)
	_partie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(_partie)
	_faire_menu()
	_faire_connexion()
	_faire_comptes()
	_faire_salon()
	_faire_partie()
	_faire_fin()
	_faire_boutique()
	_faire_pause()
	_faire_screamer(racine)
	get_viewport().size_changed.connect(_ajuster_menu)
	_ajuster_menu()
	menu("")


# une page : un voile sur ce qui est derrière (le décor du menu, ou la maison), et au milieu, une carte de verre sombre
func _page(racine: Control) -> Control:
	var voile := ColorRect.new()
	voile.color = Color(0.01, 0.012, 0.02, 0.5)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.add_child(voile)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.add_child(centre)
	var carte := PanelContainer.new()
	carte.theme_type_variation = "Carte"
	centre.add_child(carte)
	var boite := VBoxContainer.new()
	boite.custom_minimum_size = Vector2(500, 0)
	boite.add_theme_constant_override("separation", 10)
	carte.add_child(boite)
	_racines[boite] = voile
	return boite


func _texte(parent: Control, t: String, corps: int = 18, couleur: Color = Color(0.86, 0.86, 0.82)) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", corps)
	l.add_theme_color_override("font_color", couleur)
	if corps >= 36:                        # (un titre : la gravure)
		l.add_theme_font_override("font", Charte.police(Charte.TITRE))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _bouton(parent: Control, t: String, quoi: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(quoi)
	parent.add_child(b)
	return b


# une entrée du menu principal : un mot gravé, sans cadre ; survolée, elle s'éclaire
func _entree(t: String, quoi: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.theme_type_variation = "Menu"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(quoi)
	_menu.add_child(b)
	return b


# un petit titre, dans un volet : en capitales espacées, l'or pâle
func _rubrique(parent: Control, t: String) -> Label:
	var l := Label.new()
	l.text = t.to_upper()
	l.add_theme_font_override("font", Charte.police(Charte.TEXTE_GRAS))
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(Charte.OR, 0.75))
	parent.add_child(l)
	return l

func _faire_menu() -> void:
	_menu_racine = Control.new()
	_menu_racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(_menu_racine)
	# à gauche : le titre, la devise, les entrées du menu
	_menu_colonne = VBoxContainer.new()
	_menu_colonne.add_theme_constant_override("separation", 2)
	_menu_racine.add_child(_menu_colonne)
	_editeur = Label.new()
	_editeur.text = "STONEVALLEY  PRÉSENTE"
	_editeur.add_theme_font_override("font", Charte.police(Charte.TEXTE_GRAS))
	_editeur.add_theme_font_size_override("font_size", 13)
	_editeur.add_theme_color_override("font_color", Color(Charte.OR, 0.6))
	_menu_colonne.add_child(_editeur)
	_logo = Label.new()
	_logo.text = "PORTEFAIX"
	_logo.add_theme_font_override("font", Charte.police_logo())
	_logo.add_theme_font_size_override("font_size", 104)
	_logo.add_theme_color_override("font_color", Color(1.0, 0.84, 0.52))
	_logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_logo.add_theme_constant_override("shadow_offset_x", 3)
	_logo.add_theme_constant_override("shadow_offset_y", 5)
	_menu_colonne.add_child(_logo)
	_devise = Label.new()
	_devise.text = "Videz le manoir avant l'aube.\nNe réveillez pas ce qui y dort."
	_devise.add_theme_font_override("font", Charte.police(Charte.TITRE_ITALIQUE))
	_devise.add_theme_font_size_override("font_size", 23)
	_devise.add_theme_color_override("font_color", Color(Charte.IVOIRE, 0.82))
	_menu_colonne.add_child(_devise)
	_avis = Label.new()
	_avis.add_theme_font_size_override("font_size", 17)
	_avis.add_theme_color_override("font_color", Charte.ALERTE)
	_avis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_colonne.add_child(_avis)
	var ecart := Control.new()
	ecart.custom_minimum_size = Vector2(0, 14)
	_menu_colonne.add_child(ecart)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 0)
	_menu_colonne.add_child(_menu)
	_racines[_menu] = _menu_racine
	_b_seul = _entree("Jouer seul", func(): seul.emit())
	_b_plusieurs = _entree("Jouer à plusieurs", func(): _volet("plusieurs"))
	_b_lieu = _entree("", func(): lieu_change.emit())
	_b_boutique = _entree("La boutique", func(): vers_boutique.emit())
	_b_reglages = _entree("Réglages", func(): _volet("reglages"))
	_b_portail = _entree("Retour au portail", aller_au_portail)
	_b_quitter_jeu = _entree("Quitter", func(): get_tree().quit())
	# en haut à droite : qui l'on est, et sa caisse
	_barre_compte = HBoxContainer.new()
	_barre_compte.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_barre_compte.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_barre_compte.add_theme_constant_override("separation", 10)
	_barre_compte.alignment = BoxContainer.ALIGNMENT_END
	_menu_racine.add_child(_barre_compte)
	_en_ligne.append(_barre_compte)
	_compte_texte = Label.new()
	_compte_texte.add_theme_font_size_override("font_size", 17)
	_compte_texte.add_theme_color_override("font_color", Color(Charte.IVOIRE, 0.85))
	_barre_compte.add_child(_compte_texte)
	_compte_bouton = Button.new()
	_compte_bouton.text = "Se connecter"
	_compte_bouton.theme_type_variation = "Lien"
	_compte_bouton.add_theme_font_size_override("font_size", 17)
	_compte_bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_compte_bouton.pressed.connect(func():
		if _connecte:
			deconnexion.emit()
		else:
			vers_connexion.emit())
	_barre_compte.add_child(_compte_bouton)
	var point := Label.new()
	point.text = "·"
	point.add_theme_color_override("font_color", Color(Charte.OR, 0.5))
	_barre_compte.add_child(point)
	_bourse_texte = Label.new()
	_bourse_texte.add_theme_font_override("font", Charte.police(Charte.TEXTE_GRAS))
	_bourse_texte.add_theme_font_size_override("font_size", 17)
	_barre_compte.add_child(_bourse_texte)
	# à droite : le volet (jouer à plusieurs, les réglages), fermé tant qu'on ne l'ouvre pas
	_volet_carte = PanelContainer.new()
	_volet_carte.theme_type_variation = "Carte"
	_volet_carte.add_theme_stylebox_override("panel", Charte._boite(Color(0.03, 0.03, 0.05, 0.95), Color(Charte.OR, 0.25), 1, 12, Vector2(24, 20)))
	_volet_carte.visible = false
	_menu_racine.add_child(_volet_carte)
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_volet_carte.add_child(defile)
	var dans := VBoxContainer.new()
	dans.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dans.add_theme_constant_override("separation", 10)
	defile.add_child(dans)
	_volet_dans = dans
	var tete := HBoxContainer.new()
	dans.add_child(tete)
	_volet_titre = Label.new()
	_volet_titre.add_theme_font_override("font", Charte.police(Charte.TITRE))
	_volet_titre.add_theme_font_size_override("font_size", 32)
	_volet_titre.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	_volet_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(_volet_titre)
	var fermer := Button.new()
	fermer.text = "Fermer"
	fermer.theme_type_variation = "Lien"
	fermer.pressed.connect(func(): _volet(""))
	tete.add_child(fermer)
	# — à plusieurs : en ligne (un salon et son code), en réseau local (la version de bureau)
	var plusieurs := VBoxContainer.new()
	plusieurs.add_theme_constant_override("separation", 10)
	dans.add_child(plusieurs)
	_volets["plusieurs"] = plusieurs
	_ligne_bloc = VBoxContainer.new()
	_ligne_bloc.add_theme_constant_override("separation", 10)
	plusieurs.add_child(_ligne_bloc)
	_en_ligne.append(_ligne_bloc)
	_rubrique(_ligne_bloc, "En ligne · de 2 à 6 porteurs")
	_ligne_creer = _bouton(_ligne_bloc, "Ouvrir un salon", func(): salon_creer.emit())
	_ligne_creer.theme_type_variation = "Principal"
	_ligne_rang = HBoxContainer.new()
	_ligne_rang.add_theme_constant_override("separation", 8)
	_ligne_bloc.add_child(_ligne_rang)
	_ligne_code = LineEdit.new()
	_ligne_code.placeholder_text = "le code d'un salon"
	_ligne_code.max_length = 5
	_ligne_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ligne_code.add_theme_font_size_override("font_size", 20)
	_ligne_code.text_changed.connect(func(t: String):
		if t != t.to_upper():
			var ou := _ligne_code.caret_column
			_ligne_code.text = t.to_upper()
			_ligne_code.caret_column = ou)
	_ligne_code.text_submitted.connect(func(t: String): salon_rejoindre.emit(t))
	_ligne_rang.add_child(_ligne_code)
	_b_entrer = _bouton(_ligne_rang, "Entrer", func(): salon_rejoindre.emit(_ligne_code.text))
	_ligne_note = _texte(_ligne_bloc, "", 15, Charte.PALE)
	_ligne_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var local := VBoxContainer.new()
	local.add_theme_constant_override("separation", 10)
	plusieurs.add_child(local)
	_reseau.append(local)
	_rubrique(local, "En réseau local · la version de bureau")
	_bouton(local, "Héberger une partie", func(): heberger.emit())
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 8)
	local.add_child(ligne)
	_adresse = LineEdit.new()
	_adresse.text = "127.0.0.1"
	_adresse.placeholder_text = "l'adresse de l'hôte"
	_adresse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(_adresse)
	_bouton(ligne, "Rejoindre", func(): rejoindre.emit(_adresse.text.strip_edges()))
	# — les réglages : son pseudo, le chat de Twitch, le micro, les commandes
	var reglages := VBoxContainer.new()
	reglages.add_theme_constant_override("separation", 10)
	dans.add_child(reglages)
	_volets["reglages"] = reglages
	_pseudo_ligne = HBoxContainer.new()
	_pseudo_ligne.add_theme_constant_override("separation", 8)
	var pseudo_bloc := VBoxContainer.new()
	pseudo_bloc.add_theme_constant_override("separation", 8)
	reglages.add_child(pseudo_bloc)
	_rubrique(pseudo_bloc, "Ton pseudo")
	pseudo_bloc.add_child(_pseudo_ligne)
	_pseudo = LineEdit.new()
	_pseudo.placeholder_text = "16 lettres au plus"
	_pseudo.max_length = 16
	_pseudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pseudo_ligne.add_child(_pseudo)
	_bouton(_pseudo_ligne, "Garder", func(): pseudo_choisi.emit(_pseudo.text))
	_pseudo_ligne.visibility_changed.connect(func(): pseudo_bloc.visible = _pseudo_ligne.visible)
	var twitch := VBoxContainer.new()
	twitch.add_theme_constant_override("separation", 8)
	reglages.add_child(twitch)
	_en_ligne.append(twitch)
	_rubrique(twitch, "Le chat vote les sabotages")
	_chaine = LineEdit.new()
	_chaine.placeholder_text = "ta chaîne Twitch (facultatif)"
	twitch.add_child(_chaine)
	_rubrique(reglages, "Le son")
	_micro = CheckBox.new()
	_micro.text = "La chose entend mon micro"
	_micro.button_pressed = true
	reglages.add_child(_micro)
	_rubrique(reglages, "Les commandes")
	_aide = _texte(reglages, AIDE, 15, Color(Charte.IVOIRE, 0.75))
	_aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_volet("")


const AIDE := "ZQSD : marcher · Maj : courir (bruyant)\nCtrl : s'accroupir · Espace : sauter\nE ou clic : prendre, poser · clic droit : lancer\nF : la torche (le fantôme la voit de loin)\nV : crier · G : lancer un réveil · Échap : la pause"
const AIDE_DOIGT := "Le pouce gauche marche, le droit regarde en glissant.\nAgir : prendre, poser, klaxonner\nCourir (bruyant) et Bas restent enfoncés\n❚❚ en haut à droite : la pause"


# le volet de droite : l'ouvrir sur ce contenu ; le même, ou "" : le fermer
func _volet(nom: String) -> void:
	if nom == _volet_ouvert:
		nom = ""
	_volet_ouvert = nom
	_volet_carte.visible = nom != ""
	for k in _volets:
		_volets[k].visible = k == nom
	_volet_titre.text = {"plusieurs": "Jouer à plusieurs", "reglages": "Réglages"}.get(nom, "")
	_ajuster_menu.call_deferred()
	for b in [_b_plusieurs, _b_reglages]:
		b.add_theme_color_override("font_color", Charte.OR if (b == _b_plusieurs and nom == "plusieurs") or (b == _b_reglages and nom == "reglages") else Charte.IVOIRE)


# où va chaque morceau du menu, selon la taille de l'écran : un téléphone couché a peu de hauteur
func _ajuster_menu() -> void:
	if _menu_colonne == null:
		return
	var ecran := get_viewport().get_visible_rect().size
	var bas := ecran.y < 600.0
	var etroit := ecran.x < 1000.0
	var marge := 32.0 if bas else 72.0
	_logo.add_theme_font_size_override("font_size", 64 if bas else 104)
	_devise.add_theme_font_size_override("font_size", 17 if bas else 23)
	for b in _menu.get_children():
		b.add_theme_font_size_override("font_size", 23 if bas else 31)
	_menu_colonne.position = Vector2(marge, 18.0 if bas else 52.0)
	_menu_colonne.size = Vector2(minf(470.0, ecran.x * 0.45), 0.0)
	_barre_compte.offset_top = 10.0 if bas else 22.0
	_barre_compte.offset_bottom = _barre_compte.offset_top
	_barre_compte.offset_right = -(16.0 if bas else 40.0)
	_barre_compte.offset_left = _barre_compte.offset_right
	# (le volet prend la hauteur de ce qu'il montre, sans dépasser l'écran : au-delà, il défile)
	var large := 380.0 if etroit else 440.0
	_volet_carte.position = Vector2(ecran.x - large - (16.0 if bas else 48.0), 46.0 if bas else 84.0)
	var place := ecran.y - _volet_carte.position.y - (12.0 if bas else 48.0)
	var contenu := _volet_dans.get_combined_minimum_size().y + 44.0
	_volet_carte.custom_minimum_size = Vector2(large, minf(place, contenu))
	_volet_carte.size = _volet_carte.custom_minimum_size


# le portail StoneValley : dans un navigateur, on y va (la même fenêtre) ; sur un ordinateur, le navigateur l'ouvre
func aller_au_portail() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.href = %s" % JSON.stringify(R.PORTAIL), true)
	else:
		OS.shell_open(R.PORTAIL)


func _faire_connexion() -> void:
	_texte(_connexion, "PORTEFAIX", 52, Color(1.0, 0.86, 0.5))
	_texte(_connexion, "Connecte-toi avec ton compte Stone Valley.", 20)
	_email = LineEdit.new()
	_email.placeholder_text = "ton e-mail"
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_email.add_theme_font_size_override("font_size", 20)
	_connexion.add_child(_email)
	_mdp = LineEdit.new()
	_mdp.placeholder_text = "ton mot de passe"
	_mdp.secret = true
	_mdp.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	_mdp.add_theme_font_size_override("font_size", 20)
	_mdp.text_submitted.connect(func(_t): connexion.emit(_email.text, _mdp.text))
	_connexion.add_child(_mdp)
	_connexion_avis = _texte(_connexion, "", 18, Color(1.0, 0.5, 0.4))
	_avis_compte.append(_connexion_avis)
	_connexion_bouton = _bouton(_connexion, "Se connecter", func(): connexion.emit(_email.text, _mdp.text))
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 10)
	_connexion.add_child(ligne)
	_c["vers_creer"] = _bouton(ligne, "Créer un compte", func(): _vers(_creation))
	_c["vers_oubli"] = _bouton(ligne, "Mot de passe oublié ?", func(): _vers(_oubli))
	for b in ligne.get_children():
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_b_sans = _bouton(_connexion, "Jouer sans compte", func(): sans_compte.emit())
	_texte(_connexion, "C'est le même compte que dans Stone Valley. Ton mot de passe n'est pas gardé sur cet appareil.", 15, Color(0.6, 0.62, 0.66))


func _champ(parent: Control, nom: String, invite: String, secret: bool = false, clavier: int = LineEdit.KEYBOARD_TYPE_DEFAULT) -> LineEdit:
	var c := LineEdit.new()
	c.placeholder_text = invite
	c.secret = secret
	c.virtual_keyboard_type = clavier
	c.add_theme_font_size_override("font_size", 20)
	parent.add_child(c)
	_c[nom] = c
	return c


# créer un compte ; mot de passe oublié ; choisir un nouveau mot de passe (quand on arrive par le lien de l'e-mail)
func _faire_comptes() -> void:
	_texte(_creation, "Créer un compte", 40, Color(1.0, 0.86, 0.5))
	_texte(_creation, "Il te servira aussi dans Stone Valley.", 18)
	var pseudo := _champ(_creation, "c_pseudo", "ton pseudo (16 lettres au plus)")
	pseudo.max_length = 16
	var email := _champ(_creation, "c_email", "ton e-mail", false, LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
	var mdp := _champ(_creation, "c_mdp", "un mot de passe (6 caractères au moins)", true, LineEdit.KEYBOARD_TYPE_PASSWORD)
	mdp.text_submitted.connect(func(_t): creation.emit(email.text, mdp.text, pseudo.text))
	_avis_compte.append(_texte(_creation, "", 18))
	_c["c_creer"] = _bouton(_creation, "Créer mon compte", func(): creation.emit(email.text, mdp.text, pseudo.text))
	_c["c_retour"] = _bouton(_creation, "Retour", func(): _vers(_connexion))

	_texte(_oubli, "Mot de passe oublié", 40, Color(1.0, 0.86, 0.5))
	_texte(_oubli, "Donne l'e-mail de ton compte : tu y recevras un lien pour en choisir un nouveau.", 18)
	var o_email := _champ(_oubli, "o_email", "ton e-mail", false, LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
	o_email.text_submitted.connect(func(t): oubli.emit(t))
	_avis_compte.append(_texte(_oubli, "", 18))
	_c["o_envoyer"] = _bouton(_oubli, "Envoyer le lien", func(): oubli.emit(o_email.text))
	_c["o_retour"] = _bouton(_oubli, "Retour", func(): _vers(_connexion))

	_texte(_nouveau, "Nouveau mot de passe", 40, Color(1.0, 0.86, 0.5))
	var n1 := _champ(_nouveau, "n_mdp", "ton nouveau mot de passe (6 caractères au moins)", true, LineEdit.KEYBOARD_TYPE_PASSWORD)
	var n2 := _champ(_nouveau, "n_encore", "encore une fois", true, LineEdit.KEYBOARD_TYPE_PASSWORD)
	n2.text_submitted.connect(func(_t): nouveau_mot_de_passe.emit(n1.text, n2.text))
	_avis_compte.append(_texte(_nouveau, "", 18))
	_c["n_valider"] = _bouton(_nouveau, "Enregistrer", func(): nouveau_mot_de_passe.emit(n1.text, n2.text))


# d'une page de compte à l'autre : l'e-mail déjà tapé suit, les avis s'effacent
func _vers(page: Control) -> void:
	if page == _creation and _c["c_email"].text == "":
		_c["c_email"].text = _email.text
	if page == _oubli and _c["o_email"].text == "":
		_c["o_email"].text = _email.text
	page_compte.emit()
	_montrer(page)


func _faire_salon() -> void:
	_texte(_salon, "Le salon", 40, Color(1.0, 0.86, 0.5))
	_salon_code = _texte(_salon, "", 54, Color(1.0, 0.95, 0.8))     # le code d'un salon en ligne, en grand : c'est lui qu'on dicte
	_salon_texte = _texte(_salon, "", 20)
	_salon_bouton = _bouton(_salon, "Commencer la nuit", func(): commencer.emit())
	_bouton(_salon, "Retour", func(): quitter.emit())


func _faire_boutique() -> void:
	_texte(_boutique, "La boutique", 40, Color(1.0, 0.86, 0.5))
	_boutique_caisse = _texte(_boutique, "", 22)
	_boutique_avis = _texte(_boutique, "", 17, Color(1.0, 0.5, 0.4))
	_boutique_lignes = VBoxContainer.new()
	_boutique_lignes.add_theme_constant_override("separation", 8)
	_boutique.add_child(_boutique_lignes)
	_boutique_boutons["retour_boutique"] = _bouton(_boutique, "Retour", func(): quitter.emit())


# la boutique, pour cette caisse : chaque article, son prix, ce qu'il fait, et s'il l'a déjà
func boutique(bourse, avis: String = "") -> void:
	_boutique_caisse.text = bourse.dire()
	_boutique_caisse.add_theme_color_override("font_color", Color(0.86, 0.86, 0.82) if bourse.argent >= 0 else Color(1.0, 0.45, 0.35))
	_boutique_avis.text = avis
	_boutique_avis.visible = avis != ""
	for c in _boutique_lignes.get_children():
		_boutique_lignes.remove_child(c)
		c.queue_free()
	var retour: Button = _boutique_boutons["retour_boutique"]
	_boutique_boutons = {"retour_boutique": retour}
	for nom in R.BOUTIQUE:
		var article: Dictionary = R.BOUTIQUE[nom]
		var ligne := HBoxContainer.new()
		_boutique_lignes.add_child(ligne)
		var l := Label.new()
		var a := ""
		if bourse.a(nom):
			a = "  (tu en as %d)" % bourse.combien(nom) if article.une_fois else "  (acquis)"
		l.text = "%s — %d €%s\n%s" % [article.nom, article.prix, a, article.dit]
		l.add_theme_font_size_override("font_size", 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ligne.add_child(l)
		var b := _bouton(ligne, "Acheter", func(): achat.emit(nom))
		b.disabled = bourse.argent < article.prix or (bourse.a(nom) and not article.une_fois) or bourse.combien(nom) >= R.STOCK_MAX
		_boutique_boutons["achat_" + nom] = b
	_montrer(_boutique)


# au menu : ce qu'il a en caisse, ou ce qu'il doit
func bourse(t: String, dette: bool) -> void:
	_bourse_texte.text = t
	_bourse_texte.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35) if dette else Color(0.86, 0.86, 0.82))


# la pause : reprendre, les commandes, quitter la nuit
func _faire_pause() -> void:
	_texte(_pause, "Pause", 54, Color(1.0, 0.86, 0.55))
	_pause_dit = _texte(_pause, "", 18, Color(Charte.IVOIRE, 0.8))
	_pause_retour = _bouton(_pause, "Reprendre", func(): pause_voulue.emit(false))
	_pause_retour.theme_type_variation = "Principal"
	_pause_b_aide = _bouton(_pause, "Les commandes", func():
		_pause_aide.visible = not _pause_aide.visible
		_pause_b_aide.text = "Cacher les commandes" if _pause_aide.visible else "Les commandes")
	_pause_aide = _texte(_pause, AIDE, 15, Color(Charte.IVOIRE, 0.75))
	_pause_aide.visible = false
	_pause_quitter = _bouton(_pause, "Quitter la nuit", func(): quitter.emit())
	_texte(_pause, "Échap : reprendre", 14, Charte.PALE)


# la pause, montrée ou rangée : seul, le monde attend ; à plusieurs, la nuit continue (et l'hôte qui part la finit pour tous)
func pause(oui: bool, seul: bool, hote: bool, vivant: bool) -> void:
	if not oui:
		_pause_aide.visible = false
		_pause_b_aide.text = "Les commandes"
		_montrer(_partie)
		return
	_pause_dit.text = "La nuit attend que tu reviennes." if seul else "La nuit continue : les autres portent, et la chose rôde.\nTu ne bouges plus tant que tu es ici."
	if not vivant and not seul:
		_pause_dit.text = "Tu es mort. Les autres finissent la nuit."
	_pause_quitter.text = "Quitter la nuit" if seul or not hote else "Quitter la nuit (elle s'arrête pour tous)"
	_montrer(_pause)


# Échap : à la pause, on revient ; en pleine nuit, la pause ; au menu, le volet se ferme
func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE):
		return
	var jeu = get_parent()
	if _pause.is_visible_in_tree():
		pause_voulue.emit(false)
	elif _partie.is_visible_in_tree() and jeu != null and "etat" in jeu and jeu.etat == jeu.PARTIE:
		pause_voulue.emit(true)
	elif _menu.is_visible_in_tree() and _volet_ouvert != "":
		_volet("")
	else:
		return
	get_viewport().set_input_as_handled()


func _faire_fin() -> void:
	_fin_texte = _texte(_fin, "", 22)
	# les boutons d'abord, toujours à l'écran ; la facture dessous, dans un cadre qui défile si elle est longue
	var boutons := HBoxContainer.new()
	boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	boutons.add_theme_constant_override("separation", 12)
	_fin.add_child(boutons)
	_fin_rejouer = _bouton(boutons, "Une autre maison", func(): rejouer.emit())
	_bouton(boutons, "Retour au menu", func(): quitter.emit())
	_fin_defile = ScrollContainer.new()
	_fin_defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_fin.add_child(_fin_defile)
	_fin_compte = _texte(_fin_defile, "", 15, Color(0.8, 0.8, 0.76))
	_fin_compte.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# la peur bleue : tout l'écran se dédouble, ondule, bleuit, et se referme sur les bords
const TROUBLE := """
shader_type canvas_item;
uniform sampler2D ecran : hint_screen_texture, filter_linear;
void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	vec2 d = vec2(sin(t * 9.0 + uv.y * 30.0), cos(t * 7.0 + uv.x * 26.0)) * 0.004;
	vec3 c = texture(ecran, uv + d).rgb * 0.34;
	c += texture(ecran, uv - d * 2.0 + vec2(0.007, 0.0)).rgb * 0.22;
	c += texture(ecran, uv + d * 2.0 - vec2(0.007, 0.0)).rgb * 0.22;
	c += texture(ecran, uv + vec2(0.0, 0.008)).rgb * 0.11;
	c += texture(ecran, uv - vec2(0.0, 0.008)).rgb * 0.11;
	float gris = dot(c, vec3(0.3, 0.6, 0.1));
	c = mix(c, vec3(gris * 0.7, gris * 0.88, gris * 1.3), 0.5);
	float bord = smoothstep(0.3, 0.8, distance(uv, vec2(0.5)));
	c *= 1.0 - bord * 0.75 * (0.8 + 0.2 * sin(t * 5.0));
	COLOR = vec4(c, 1.0);
}
"""


# le screamer : quand le fantôme vous attrape, sa face vous saute au visage, d'un coup, et hurle
const SCREAMER := 0.85            # sa durée, en secondes

func _faire_screamer(racine: Control) -> void:
	_screamer = Control.new()
	_screamer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screamer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screamer.visible = false
	racine.add_child(_screamer)            # (en dernier : par-dessus tout)
	var noir := ColorRect.new()
	noir.color = Color(0.0, 0.0, 0.0, 0.93)
	noir.set_anchors_preset(Control.PRESET_FULL_RECT)
	noir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screamer.add_child(noir)
	_screamer_face = Control.new()         # une face de 400 sur 560, dessinée autour de son milieu
	_screamer_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screamer.add_child(_screamer_face)
	var os := Color(0.8, 0.79, 0.72)
	var creux := Color(0.03, 0.02, 0.02)
	var sang := Color(1.0, 0.1, 0.05)
	var morceaux := [
		[Rect2(-170, -280, 340, 300), os], [Rect2(-200, -220, 400, 200), os], [Rect2(-130, 0, 260, 120), os.darkened(0.12)],      # le crâne, les pommettes
		[Rect2(-150, -150, 110, 120), creux], [Rect2(40, -150, 110, 120), creux],                                                    # les orbites
		[Rect2(-118, -112, 44, 44), sang], [Rect2(74, -112, 44, 44), sang], [Rect2(-104, -98, 16, 16), Color(1, 0.9, 0.6)], [Rect2(88, -98, 16, 16), Color(1, 0.9, 0.6)],
		[Rect2(-22, -20, 18, 50), creux], [Rect2(4, -20, 18, 50), creux],                                                            # le nez
		[Rect2(-200, -60, 30, 220), os.darkened(0.3)], [Rect2(170, -60, 30, 220), os.darkened(0.3)],                                  # des mèches
	]
	for m in morceaux:
		_morceau(_screamer_face, m[0], m[1])
	_screamer_gueule = Control.new()       # la gueule : elle s'ouvre
	_screamer_gueule.position = Vector2(0, 60)
	_screamer_gueule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screamer_face.add_child(_screamer_gueule)
	_morceau(_screamer_gueule, Rect2(-110, 0, 220, 200), creux)
	_morceau(_screamer_gueule, Rect2(-60, 60, 120, 120), Color(0.35, 0.02, 0.03))
	for k in 7:                            # les dents, en haut et en bas
		_morceau(_screamer_gueule, Rect2(-104 + k * 30, 0, 22, 34 + (k % 2) * 14), os)
		_morceau(_screamer_gueule, Rect2(-104 + k * 30, 200 - 30 - (k % 3) * 8, 22, 30 + (k % 3) * 8), os.darkened(0.1))


func _morceau(parent: Control, r: Rect2, c: Color) -> void:
	var m := ColorRect.new()
	m.color = c
	m.position = r.position
	m.size = r.size
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(m)


func screamer() -> void:
	_screamer_reste = SCREAMER
	_screamer.visible = true
	_animer_screamer()


func _animer_screamer() -> void:
	var a := 1.0 - _screamer_reste / SCREAMER          # de 0 à 1
	var ecran := get_viewport().get_visible_rect().size
	var grandeur := ecran.y / 560.0 * lerpf(0.7, 2.4, 1.0 - pow(1.0 - a, 3.0))      # elle arrive très vite, puis vous colle
	_screamer_face.scale = Vector2(grandeur, grandeur)
	_screamer_face.position = ecran * 0.5 + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 16.0 * (1.0 - a) + Vector2(0, 40.0 * grandeur)
	_screamer_face.rotation = randf_range(-0.05, 0.05)
	_screamer_gueule.scale = Vector2(1.0, lerpf(0.5, 1.25, minf(1.0, a * 4.0)))
	_screamer.modulate.a = 1.0 if a < 0.75 else (1.0 - a) / 0.25


# où l'on joue : le bouton du menu passe de l'un à l'autre
func lieu(nom: String) -> void:
	_b_lieu.text = "Lieu : le bunker" if nom == "bunker" else "Lieu : le manoir hanté"
	var c: Dictionary = R.CONTRAT.get(nom, R.CONTRAT["manoir"])
	_b_lieu.tooltip_text = "%s. Contrat, seul : %d € (prime %d %%). Changer de lieu." % [c.dit, c.base, int(c.prime * 100)]


# la dose de radiations : un compteur, et l'écran qui verdit
func dose(d: float, rayonne: float, au_bunker: bool) -> void:
	_dose.visible = au_bunker
	_dose.text = "Dose : %d %%%s" % [int(d * 100.0), "   ☢ zone radioactive" if rayonne > 0.0 else ""]
	_dose.add_theme_color_override("font_color", Color(0.9, 0.9, 0.86).lerp(Color(0.4, 1.0, 0.3), clampf(d * 1.5 + rayonne * 0.4, 0.0, 1.0)))
	_vert.visible = d > 0.02 or rayonne > 0.0
	_vert.color = Color(0.25, 1.0, 0.2, clampf(d * 0.3 + rayonne * 0.06, 0.0, 0.36))


func trouble(oui: bool) -> void:
	_trouble.visible = oui


func _faire_partie() -> void:
	_trouble = ColorRect.new()             # (avant tout le reste : l'heure et le quota restent nets par-dessus)
	_trouble.set_anchors_preset(Control.PRESET_FULL_RECT)
	_trouble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ombre := Shader.new()
	ombre.code = TROUBLE
	var voile := ShaderMaterial.new()
	voile.shader = ombre
	_trouble.material = voile
	_trouble.visible = false
	_partie.add_child(_trouble)
	_vert = ColorRect.new()
	_vert.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vert.visible = false
	_partie.add_child(_vert)
	_dose = _coin(Control.PRESET_TOP_LEFT, Vector2(18, 44), Vector2(420, 30), 18)
	_dose.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dose.visible = false
	_heure = _coin(Control.PRESET_CENTER_TOP, Vector2(-100, 12), Vector2(200, 40), 30)
	_quota = _coin(Control.PRESET_TOP_LEFT, Vector2(18, 12), Vector2(420, 60), 22)
	_quota.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_annonce = _coin(Control.PRESET_CENTER_TOP, Vector2(-400, 70), Vector2(800, 70), 24)
	_annonce.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45))
	var viseur := _coin(Control.PRESET_CENTER, Vector2(-10, -14), Vector2(20, 28), 20)
	viseur.text = "+"
	_indice = _coin(Control.PRESET_CENTER, Vector2(-400, 30), Vector2(800, 60), 18)
	_b_partir = Button.new()
	_b_partir.text = "Quitter la partie"
	_b_partir.add_theme_font_size_override("font_size", 18)
	_b_partir.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_b_partir.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_b_partir.position += Vector2(-16, 14)
	_b_partir.visible = false
	_b_partir.pressed.connect(func(): quitter.emit())
	_partie.add_child(_b_partir)
	_mort = _coin(Control.PRESET_CENTER_BOTTOM, Vector2(-400, -120), Vector2(800, 60), 20)
	_mort.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	var etiquette := _coin(Control.PRESET_BOTTOM_LEFT, Vector2(18, -64), Vector2(260, 24), 16)
	etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	etiquette.text = "le bruit que tu fais"
	_bruit = ProgressBar.new()
	_bruit.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bruit.position += Vector2(18, -38)
	_bruit.custom_minimum_size = Vector2(260, 18)
	_bruit.size = Vector2(260, 18)
	_bruit.max_value = R.BRUIT_MICRO
	_bruit.show_percentage = false
	_partie.add_child(_bruit)
	_vote = PanelContainer.new()
	_vote.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_vote.position += Vector2(-378, 150)
	_vote.custom_minimum_size = Vector2(360, 0)
	_partie.add_child(_vote)
	_vote_texte = Label.new()
	_vote_texte.add_theme_font_size_override("font_size", 18)
	_vote.add_child(_vote_texte)


func _coin(ancre: int, ou: Vector2, t: Vector2, corps: int) -> Label:
	var l := Label.new()
	l.set_anchors_preset(ancre)
	l.position += ou
	l.custom_minimum_size = t
	l.size = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", corps)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_partie.add_child(l)
	return l


func _montrer(page: Control) -> void:
	for p in _racines:
		_racines[p].visible = p == page
	_partie.visible = page == _partie
	# (le manoir la nuit, derrière le menu et les pages qui ne sont pas de la partie ; l'ombre à gauche, au menu seulement)
	_decor.visible = page in [_menu, _connexion, _creation, _oubli, _nouveau, _salon, _boutique]
	_decor.gauche = 0.62 if page == _menu else 0.0
	if page == _menu:
		_ajuster_menu.call_deferred()


# dans un navigateur, on joue seul : pas de port à ouvrir, et le micro attend qu'on le demande
func passer_au_navigateur() -> void:
	for c in _reseau:
		c.visible = false
	_b_quitter_jeu.visible = false          # (une page ne se ferme pas d'elle-même : on va au portail)
	_micro.button_pressed = false


# sur une page qui ne laisse rien sortir vers le réseau : ni compte, ni chat de Twitch
func passer_hors_ligne() -> void:
	for c in _en_ligne:
		c.visible = false
	_aide.text += "\nSur cette page, on joue sans compte et sans chat : elle ne laisse pas le jeu joindre le réseau."


func passer_au_tactile() -> void:
	_micro.button_pressed = false
	_aide.text = AIDE_DOIGT
	_pause_aide.text = AIDE_DOIGT


# où sont les boutons et les champs qu'on voit, en pixels de la fenêtre : pour qu'un essai dans un navigateur clique au bon endroit
func reperes() -> Dictionary:
	var vers := get_viewport().get_screen_transform()
	var r := {}
	var choses := {"email": _email, "mdp": _mdp, "connecter": _connexion_bouton, "sans_compte": _b_sans, "seul": _b_seul, "ouvrir": _ligne_creer, "code": _ligne_code,
		"entrer": _b_entrer, "commencer": _salon_bouton, "boutique": _b_boutique, "lieu": _b_lieu, "partir": _b_partir, "compte": _compte_bouton,
		"plusieurs": _b_plusieurs, "reglages": _b_reglages, "portail": _b_portail, "quitter_jeu": _b_quitter_jeu,
		"pause_retour": _pause_retour, "pause_quitter": _pause_quitter, "pause_aide": _pause_b_aide}
	for nom in _boutique_boutons:
		choses[nom] = _boutique_boutons[nom]
	for nom in _c:
		choses[nom] = _c[nom]
	for nom in choses:
		var c: Control = choses[nom]
		if c.is_visible_in_tree():
			var p: Vector2 = vers * c.get_global_rect().get_center()
			r[nom] = [int(p.x), int(p.y)]
	return r


# --- les écrans ---

# la version du jeu, en petit, en bas à droite de tous les écrans : on sait laquelle on a sous les yeux
func version(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.position += Vector2(-10, -6)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)


func menu(avis: String) -> void:
	_avis.text = avis
	_avis.visible = avis != ""
	_montrer(_menu)          # (le volet reste comme on l'a laissé : un code refusé se retape sans le rouvrir)


func page_connexion() -> void:
	_montrer(_connexion)


func page_nouveau_mot_de_passe() -> void:
	_montrer(_nouveau)


# une page de compte est-elle à l'écran ?
func sur_un_compte() -> bool:
	return _connexion.is_visible_in_tree() or _creation.is_visible_in_tree() or _oubli.is_visible_in_tree() or _nouveau.is_visible_in_tree()


# l'état du compte, redit aux deux écrans qui en parlent
func compte(connecte: bool, nom: String, occupe: bool, erreur: String, avis: String = "") -> void:
	_connecte = connecte
	for l in _avis_compte:         # la même ligne sur chaque page de compte : on attend, ça a marché, ou ce qui n'a pas marché
		l.text = "On frappe à la porte…" if occupe else (erreur if erreur != "" else avis)
		l.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82) if occupe else (Color(1.0, 0.5, 0.4) if erreur != "" else Color(0.6, 0.95, 0.6)))
	for nom_bouton in ["c_creer", "o_envoyer", "n_valider"]:
		_c[nom_bouton].disabled = occupe
	_connexion_bouton.disabled = occupe
	_compte_texte.text = ("Connecté : %s" % nom) if connecte else "Sans compte"
	_compte_bouton.text = "Se déconnecter" if connecte else "Se connecter"
	_compte_bouton.disabled = occupe
	_pseudo_ligne.visible = connecte
	_en_ligne_maj()
	if connecte:
		_mdp.text = ""
		for champ in ["c_mdp", "n_mdp", "n_encore"]:
			_c[champ].text = ""
		if not _pseudo.has_focus():
			_pseudo.text = nom if nom != "Porteur" else ""


# jouer en ligne demande un compte, et de quoi relier les joueurs (tous les navigateurs l'ont)
func en_ligne(possible: bool) -> void:
	_ligne_possible = possible
	_en_ligne_maj()


func _en_ligne_maj() -> void:
	var ouvert := _ligne_possible and _connecte
	_ligne_creer.visible = ouvert
	_ligne_rang.visible = ouvert
	_ligne_note.visible = not ouvert
	_ligne_note.text = "Pour jouer en ligne : connecte-toi." if _ligne_possible else "Le jeu en ligne (salon et code) se joue dans un navigateur."


func salon(t: String, hote: bool, code: String = "") -> void:
	_salon_code.text = "  ".join(code.split(""))
	_salon_code.visible = code != ""
	_salon_texte.text = t
	_salon_bouton.visible = hote
	_montrer(_salon)


func partie() -> void:
	_trouble.visible = false
	_b_partir.visible = false
	_annonce.text = ""
	_mort.text = ""
	_vote.visible = false
	_montrer(_partie)


func fin(t: String, hote: bool, compte_: String = "") -> void:
	_fin_texte.text = t
	_fin_compte.text = compte_
	_fin_defile.visible = compte_ != ""
	# la facture prend ce qu'il reste de l'écran, pas plus : au-delà, elle défile
	var ecran := get_viewport().get_visible_rect().size
	_fin_compte.custom_minimum_size.x = minf(520.0, ecran.x - 40.0)
	_fin_defile.custom_minimum_size = Vector2(minf(540.0, ecran.x - 24.0), clampf(ecran.y - 300.0, 90.0, 360.0))
	_fin_defile.scroll_vertical = 0
	_fin_rejouer.visible = hote
	_montrer(_fin)


func chaine() -> String:
	return _chaine.text


func micro() -> bool:
	return _micro.button_pressed


# --- pendant la partie ---

func annoncer(t: String, duree: float = 4.0) -> void:
	_annonce.text = t
	_annonce_reste = duree


func mort(t: String) -> void:
	_mort.text = t


# mort, on peut partir : un bouton, en haut à droite (la partie continue pour les autres)
func peut_partir(oui: bool) -> void:
	_b_partir.visible = oui


func dire(temps: float, charge: int, quota: int, bruit: float, indice: String) -> void:
	# la nuit va de 22 h à 6 h
	var minutes := int((1.0 - clampf(temps / R.DUREE_NUIT, 0.0, 1.0)) * 480.0)
	_heure.text = "%02d:%02d" % [(22 + minutes / 60) % 24, minutes % 60]
	_heure.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35) if temps < 60.0 else Color(0.9, 0.9, 0.86))
	_quota.text = "Chargé : %d € / %d €" % [charge, quota]
	_quota.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55) if charge >= quota else Color(0.9, 0.9, 0.86))
	_bruit.value = bruit
	_indice.text = indice


func vote(ouvert: bool, options: Array, voix: Array, reste: float) -> void:
	_vote.visible = ouvert
	if not ouvert:
		return
	var t := "LE CHAT VOTE — %d s\n" % int(ceil(maxf(reste, 0.0)))
	for i in options.size():
		t += "%d. %s  (%d)\n" % [i + 1, R.SABOTAGES[options[i]].nom, voix[i]]
	_vote_texte.text = t.strip_edges()


func _process(dt: float) -> void:
	if _screamer_reste > 0.0:
		_screamer_reste -= dt
		if _screamer_reste <= 0.0:
			_screamer.visible = false
		else:
			_animer_screamer()
	if _annonce_reste > 0.0:
		_annonce_reste -= dt
		if _annonce_reste <= 0.0:
			_annonce.text = ""
