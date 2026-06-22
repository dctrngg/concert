class_name NPCQuestData
extends Resource

enum QuestType { FOOD_DELIVERY, CHAIR_CARRY, SELL_MECH, INTERVENTION }
enum QuestState { OFFERED, ACTIVE, COMPLETED, FAILED }

@export var quest_id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var quest_type: QuestType = QuestType.FOOD_DELIVERY
@export var time_limit: float = 35.0

# Runtime states
var time_remaining: float = 0.0
var state: QuestState = QuestState.OFFERED
var is_item_picked_up: bool = false
