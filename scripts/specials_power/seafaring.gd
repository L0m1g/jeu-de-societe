class_name PowerSeafaring
extends SpecialPower

func _setup() -> void:
	key = "POWER_SEAFARING"
	icon_path = "res://assets/images/powers/seafaring.png"
	bonus_tokens = 5
# Peut conquérir mers et lac comme 3 régions vides
# Garde ces régions même en déclin et continue de scorer
# Seule race pouvant occuper mers et lac
# Logique gérée dans GameManager
