extends Node
# Portefaix — le chat (scripts/chat.gd)
# Le public joue la maison. Toutes les 40 secondes, trois sabotages sont proposés ; il a 15 secondes pour voter en écrivant 1, 2 ou 3
# (ou !1, !2, !3), une voix par personne. Le plus voté tombe sur les porteurs.
# Avec le nom d'une chaîne Twitch, l'hôte lit son vrai chat (en lecture seule, sans compte : la connexion anonyme de Twitch).
# Sans chaîne, des spectateurs de paille votent au hasard, pour que le jeu se joue pareil hors antenne.

const R = preload("res://scripts/regles.gd")
const TWITCH := "wss://irc-ws.chat.twitch.tv:443"

signal vote_clos(gagnant: String)

var chaine := ""
var ouvert := false
var options: Array = []           # trois noms de sabotages
var voix: Array = [0, 0, 0]
var reste := 0.0                  # avant la clôture, ou avant le prochain vote
var change := false               # vrai tant que personne n'a redit l'état aux joueurs
var en_ligne := false
var _votants := {}
var _socket: WebSocketPeer
var _salue := false
var _paille := 0.0
var _penchant := 0
var _hasard := RandomNumberGenerator.new()


func recommencer() -> void:
	_hasard.randomize()
	ouvert = false
	options = []
	voix = [0, 0, 0]
	reste = R.VOTE_PAUSE
	change = true
	_brancher()


func arreter() -> void:
	if _socket != null:
		_socket.close()
	_socket = null
	en_ligne = false


func _brancher() -> void:
	arreter()
	chaine = chaine.strip_edges().to_lower().trim_prefix("#")
	if chaine == "":
		return
	_socket = WebSocketPeer.new()
	_salue = false
	if _socket.connect_to_url(TWITCH) != OK:
		_socket = null


# chez l'hôte, à chaque image de la partie
func avancer(dt: float) -> void:
	_lire()
	reste -= dt
	if not ouvert:
		if reste <= 0.0:
			ouvrir()
		return
	if not en_ligne:
		# les spectateurs de paille : une voix de temps en temps, avec un penchant
		_paille -= dt
		if _paille <= 0.0:
			_paille = _hasard.randf_range(0.3, 1.6)
			voter("paille%d" % _votants.size(), _penchant if _hasard.randf() < 0.5 else _hasard.randi_range(0, 2))
	if reste <= 0.0:
		clore()


func ouvrir() -> void:
	var noms: Array = R.SABOTAGES.keys()
	options = []
	while options.size() < 3:
		var n: String = noms[_hasard.randi_range(0, noms.size() - 1)]
		if not options.has(n):
			options.append(n)
	voix = [0, 0, 0]
	_votants.clear()
	_penchant = _hasard.randi_range(0, 2)
	ouvert = true
	reste = R.VOTE_DUREE
	change = true


func voter(qui: String, choix: int) -> void:
	if not ouvert or choix < 0 or choix > 2 or _votants.has(qui):
		return
	_votants[qui] = true
	voix[choix] += 1
	change = true


func clore() -> void:
	if not ouvert:
		return
	ouvert = false
	reste = R.VOTE_PAUSE
	change = true
	var g := 0
	for i in 3:
		if voix[i] > voix[g]:
			g = i
	if voix[g] == 0:
		g = _hasard.randi_range(0, 2)
	vote_clos.emit(options[g])


# --- le chat de Twitch ---

func _lire() -> void:
	if _socket == null:
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _salue:
				_salue = true
				_socket.send_text("NICK justinfan%d" % _hasard.randi_range(10000, 99999))
				_socket.send_text("JOIN #" + chaine)
			while _socket.get_available_packet_count() > 0:
				for ligne in _socket.get_packet().get_string_from_utf8().split("\r\n", false):
					var reponse := lire_ligne(ligne)
					if reponse != "":
						_socket.send_text(reponse)
		WebSocketPeer.STATE_CLOSED:
			_socket = null
			en_ligne = false


# une ligne du chat ; rend ce qu'il faut répondre au serveur, s'il y a lieu
func lire_ligne(ligne: String) -> String:
	if ligne.begins_with("PING"):
		return "PONG" + ligne.substr(4)
	var mots := ligne.split(" ", false, 3)
	if mots.size() >= 3 and mots[1] == "JOIN":
		en_ligne = true
	if mots.size() < 4 or mots[1] != "PRIVMSG" or not mots[0].begins_with(":"):
		return ""
	var qui := mots[0].substr(1).get_slice("!", 0)
	var dit := mots[3].trim_prefix(":").strip_edges().trim_prefix("!")
	if dit.length() == 1 and dit in ["1", "2", "3"]:
		voter(qui, int(dit) - 1)
	return ""
