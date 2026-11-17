extends RefCounted
# Portefaix — la charte (scripts/charte.gd)
# L'allure de tous les écrans : deux fontes libres (SIL Open Font License 1.1, gardées avec leur licence dans polices/), les mêmes que
# le portail StoneValley et Lisière — IM Fell English, une gravure ancienne, pour les titres ; Alegreya Sans pour tout le reste —,
# des couleurs (l'ivoire, l'or d'une lampe, la nuit), et le dessin des boutons, des champs, des cadres, des barres.
# Un seul thème (theme()) : posé sur la racine de l'interface, tout ce qui est dessous le prend. Des variantes pour ce qui sort du
# commun : « Principal » (le bouton qu'on presse le plus), « Menu » (les entrées du menu, sans cadre), « Carte » (un cadre de verre
# sombre), « Lien » (un bouton qui n'est qu'un mot).

const TITRE := "res://polices/im-fell-english/IMFeENrm28P.ttf"
const TITRE_ITALIQUE := "res://polices/im-fell-english/IMFeENit28P.ttf"
const TEXTE := "res://polices/alegreya-sans/AlegreyaSans-Regular.ttf"
const TEXTE_MOYEN := "res://polices/alegreya-sans/AlegreyaSans-Medium.ttf"
const TEXTE_GRAS := "res://polices/alegreya-sans/AlegreyaSans-Bold.ttf"

const IVOIRE := Color(0.93, 0.9, 0.82)
const PALE := Color(0.62, 0.62, 0.66)
const OR := Color(1.0, 0.8, 0.45)
const OR_SOMBRE := Color(0.78, 0.55, 0.25)
const NUIT := Color(0.012, 0.015, 0.03)
const VERRE := Color(0.035, 0.035, 0.055, 0.86)
const ALERTE := Color(1.0, 0.5, 0.4)
const BIEN := Color(0.6, 0.95, 0.6)

static var _theme: Theme
static var _polices := {}


static func police(chemin: String) -> Font:
	if not _polices.has(chemin):
		var f = load(chemin) if ResourceLoader.exists(chemin) else null
		_polices[chemin] = f if f is Font else ThemeDB.fallback_font
	return _polices[chemin]


# le logo : la gravure, les lettres un peu écartées
static func police_logo() -> Font:
	if not _polices.has("logo"):
		var v := FontVariation.new()
		v.base_font = police(TITRE)
		v.spacing_glyph = 6
		_polices["logo"] = v
	return _polices["logo"]


static func _boite(fond: Color, bord: Color, epaisseur: int = 1, rayon: int = 7, marge := Vector2(18, 9)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.border_color = bord
	s.set_border_width_all(epaisseur)
	s.set_corner_radius_all(rayon)
	s.content_margin_left = marge.x
	s.content_margin_right = marge.x
	s.content_margin_top = marge.y
	s.content_margin_bottom = marge.y
	s.anti_aliasing = true
	return s


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = police(TEXTE)
	t.default_font_size = 18
	# les textes
	t.set_color("font_color", "Label", IVOIRE)
	# les boutons : un verre sombre cerné d'or pâle ; survolé, l'or s'allume ; pressé, il s'enfonce
	t.set_font("font", "Button", police(TEXTE_GRAS))
	t.set_font_size("font_size", "Button", 18)
	for k in ["font_color", "font_focus_color"]:
		t.set_color(k, "Button", IVOIRE)
	t.set_color("font_hover_color", "Button", OR)
	t.set_color("font_pressed_color", "Button", NUIT)
	t.set_color("font_hover_pressed_color", "Button", NUIT)
	t.set_color("font_disabled_color", "Button", Color(IVOIRE, 0.35))
	t.set_stylebox("normal", "Button", _boite(Color(0.06, 0.055, 0.075, 0.9), Color(OR, 0.32)))
	t.set_stylebox("hover", "Button", _boite(Color(0.1, 0.085, 0.07, 0.95), Color(OR, 0.85)))
	t.set_stylebox("pressed", "Button", _boite(OR_SOMBRE, OR))
	t.set_stylebox("hover_pressed", "Button", _boite(OR, OR))
	t.set_stylebox("disabled", "Button", _boite(Color(0.05, 0.05, 0.06, 0.6), Color(1, 1, 1, 0.08)))
	t.set_stylebox("focus", "Button", _boite(Color(0, 0, 0, 0), Color(OR, 0.9), 2))
	# « Principal » : l'or plein, l'encre sombre dessus
	t.set_type_variation("Principal", "Button")
	t.set_stylebox("normal", "Principal", _boite(Color(0.88, 0.66, 0.32), Color(1.0, 0.86, 0.55), 1, 7, Vector2(26, 12)))
	t.set_stylebox("hover", "Principal", _boite(Color(1.0, 0.78, 0.42), Color(1.0, 0.92, 0.7), 1, 7, Vector2(26, 12)))
	t.set_stylebox("pressed", "Principal", _boite(Color(0.7, 0.5, 0.22), OR, 1, 7, Vector2(26, 12)))
	t.set_color("font_color", "Principal", Color(0.08, 0.06, 0.04))
	t.set_color("font_hover_color", "Principal", Color(0.05, 0.03, 0.02))
	t.set_color("font_focus_color", "Principal", Color(0.08, 0.06, 0.04))
	t.set_font_size("font_size", "Principal", 20)
	t.set_font("font", "Principal", police(TEXTE_GRAS))
	# « Menu » : une entrée du menu principal, sans cadre ; survolée, elle s'éclaire et un filet d’or la souligne à gauche
	t.set_type_variation("Menu", "Button")
	var vide := StyleBoxEmpty.new()
	vide.content_margin_left = 22
	vide.content_margin_top = 4
	vide.content_margin_bottom = 4
	var souligne := StyleBoxFlat.new()
	souligne.bg_color = Color(OR, 0.07)
	souligne.border_color = OR
	souligne.border_width_left = 3
	souligne.content_margin_left = 22
	souligne.content_margin_top = 4
	souligne.content_margin_bottom = 4
	for k in ["normal", "disabled"]:
		t.set_stylebox(k, "Menu", vide)
	for k in ["hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(k, "Menu", souligne)
	t.set_font("font", "Menu", police(TITRE))
	t.set_font_size("font_size", "Menu", 31)
	t.set_color("font_color", "Menu", IVOIRE)
	t.set_color("font_focus_color", "Menu", OR)
	t.set_color("font_hover_color", "Menu", OR)
	t.set_color("font_pressed_color", "Menu", OR)
	t.set_color("font_hover_pressed_color", "Menu", OR)
	t.set_constant("h_separation", "Menu", 14)
	# « Lien » : un mot, souligné au survol
	t.set_type_variation("Lien", "Button")
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(k, "Lien", StyleBoxEmpty.new())
	t.set_stylebox("focus", "Lien", _boite(Color(0, 0, 0, 0), Color(OR, 0.7), 1, 4, Vector2(4, 2)))
	t.set_font("font", "Lien", police(TEXTE_MOYEN))
	t.set_color("font_color", "Lien", PALE)
	t.set_color("font_hover_color", "Lien", OR)
	t.set_color("font_pressed_color", "Lien", OR)
	t.set_color("font_focus_color", "Lien", OR)
	# les champs
	t.set_stylebox("normal", "LineEdit", _boite(Color(0.02, 0.02, 0.035, 0.9), Color(1, 1, 1, 0.14), 1, 7, Vector2(14, 9)))
	t.set_stylebox("focus", "LineEdit", _boite(Color(0, 0, 0, 0), Color(OR, 0.9), 2, 7, Vector2(14, 9)))
	t.set_stylebox("read_only", "LineEdit", _boite(Color(0.02, 0.02, 0.03, 0.6), Color(1, 1, 1, 0.06), 1, 7, Vector2(14, 9)))
	t.set_color("font_color", "LineEdit", IVOIRE)
	t.set_color("font_placeholder_color", "LineEdit", Color(PALE, 0.75))
	t.set_color("caret_color", "LineEdit", OR)
	t.set_color("selection_color", "LineEdit", Color(OR, 0.3))
	t.set_font_size("font_size", "LineEdit", 18)
	# les cases
	t.set_color("font_color", "CheckBox", IVOIRE)
	t.set_color("font_hover_color", "CheckBox", OR)
	t.set_color("font_pressed_color", "CheckBox", IVOIRE)
	t.set_color("font_focus_color", "CheckBox", IVOIRE)
	for k in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(k, "CheckBox", StyleBoxEmpty.new())
	# « Carte » : un cadre de verre sombre, un fil d'or
	t.set_type_variation("Carte", "PanelContainer")
	t.set_stylebox("panel", "Carte", _boite(VERRE, Color(OR, 0.22), 1, 12, Vector2(24, 20)))
	t.set_stylebox("panel", "PanelContainer", _boite(Color(0.03, 0.03, 0.045, 0.82), Color(OR, 0.25), 1, 10, Vector2(16, 12)))
	# les barres, les défilements
	t.set_stylebox("background", "ProgressBar", _boite(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.12), 1, 5, Vector2(0, 0)))
	t.set_stylebox("fill", "ProgressBar", _boite(Color(0.95, 0.72, 0.38, 0.9), Color(0, 0, 0, 0), 0, 5, Vector2(0, 0)))
	var rail := _boite(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 0, 4, Vector2(4, 4))
	var poignee := _boite(Color(OR, 0.35), Color(0, 0, 0, 0), 0, 4, Vector2(4, 4))
	t.set_stylebox("scroll", "VScrollBar", rail)
	t.set_stylebox("grabber", "VScrollBar", poignee)
	t.set_stylebox("grabber_highlight", "VScrollBar", _boite(Color(OR, 0.6), Color(0, 0, 0, 0), 0, 4, Vector2(4, 4)))
	t.set_stylebox("grabber_pressed", "VScrollBar", _boite(OR, Color(0, 0, 0, 0), 0, 4, Vector2(4, 4)))
	_theme = t
	return t
