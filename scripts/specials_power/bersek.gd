class_name PowerBerserk
extends SpecialPower

func _setup() -> void:
	key = "POWER_BERSERK"
	icon_path = "res://assets/images/powers/bersek.png"
	bonus_tokens = 4
# Peut lancer le dé avant CHAQUE conquête, pas seulement la dernière
# Logique gérée dans GameManager : is_berserk_active()
