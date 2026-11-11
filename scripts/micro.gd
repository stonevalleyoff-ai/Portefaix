extends Node
# Portefaix — le micro (scripts/micro.gd)
# Le vrai micro du joueur est une règle du jeu : parler fort, rire, crier, la chose l'entend. On n'en garde rien et on n'en envoie
# rien : seulement son niveau, lu dans un bus muet, de 0 (silence) à 1 (à pleine voix).

const R = preload("res://scripts/regles.gd")

var actif := false
var _capture: AudioEffectCapture
var _lecteur: AudioStreamPlayer
var _niveau := 0.0


func regler(oui: bool) -> void:
	if oui == actif:
		return
	actif = oui
	if oui and _capture == null:
		var bus := AudioServer.bus_count
		AudioServer.add_bus(bus)
		AudioServer.set_bus_name(bus, "Micro")
		_capture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(bus, _capture)
		var muet := AudioEffectAmplify.new()      # après la capture : on mesure la voix, on ne la rejoue pas
		muet.volume_db = -80.0
		AudioServer.add_bus_effect(bus, muet)
		_lecteur = AudioStreamPlayer.new()
		_lecteur.stream = AudioStreamMicrophone.new()
		_lecteur.bus = "Micro"
		add_child(_lecteur)
	if _lecteur != null:
		if oui:
			_lecteur.play()
		else:
			_lecteur.stop()
	_niveau = 0.0


func niveau() -> float:
	return _niveau if actif else 0.0


func _process(dt: float) -> void:
	if not actif or _capture == null:
		return
	var n := _capture.get_frames_available()
	if n <= 0:
		_niveau = maxf(_niveau - dt * 2.0, 0.0)
		return
	var cretes := 0.0
	for f in _capture.get_buffer(n):
		cretes = maxf(cretes, maxf(absf(f.x), absf(f.y)))
	var db := linear_to_db(maxf(cretes, 0.00001))
	var v := clampf(inverse_lerp(R.MICRO_SEUIL, R.MICRO_PLEIN, db), 0.0, 1.0)
	_niveau = maxf(v, _niveau - dt * 2.0)
