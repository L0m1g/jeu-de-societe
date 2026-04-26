extends Node

enum RegionType {
	FOREST,
	MOUNTAIN,
	HILL,
	FIELD,
	SWAMP,
	LAKE,
	SEA,
	COAST,
	MAGIC_SOURCE,
	MINE,
	CAVE
}

enum GameState {
	WAITING,
	DRAFT,
	PLAYING,
	SCORING,
	END
}

enum TurnPhase {
	PICK_NATION,    # Phase de draft uniquement
	CHOOSE_ACTION,  # Début du tour : conquérir OU décliner
	CONQUEST,       # Conquête des régions
	REDEPLOY,       # Redéploiement des troupes
	DECLINE,        # Passage en déclin
	SCORING         # Calcul des points
}
