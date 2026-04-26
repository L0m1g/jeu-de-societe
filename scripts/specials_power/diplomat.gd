class_name PowerDiplomat
extends SpecialPower

var allied_peer_id: int = -1

func _setup() -> void:
	key = "POWER_DIPLOMAT"
	icon_path = "res://assets/images/powers/diplomat.png"
	bonus_tokens = 5
# En fin de tour : choisir un allié parmi les joueurs non attaqués ce tour
# L'allié ne peut pas attaquer la nation active jusqu'au prochain tour
# Les pions en déclin ignorent cet accord (Ghouls en déclin peuvent attaquer)
# Logique gérée dans GameManager
