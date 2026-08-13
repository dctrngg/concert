class_name NPCQuestData
extends Resource

enum QuestType { FOOD_DELIVERY, SEAT_FINDER, MERCH_SELLING, INTERVENTION, LOST_CHILD }
enum QuestState { OFFERED, ACTIVE, COMPLETED, FAILED }

@export var quest_id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var quest_type: QuestType = QuestType.FOOD_DELIVERY
@export var time_limit: float = 35.0
@export var reward_points: int = 50

# Runtime states
var time_remaining: float = 0.0
var state: QuestState = QuestState.OFFERED
var is_item_picked_up: bool = false

# Dữ liệu riêng cho quest "Tìm ghế ngồi" (SEAT_FINDER)
@export var target_seat_id: String = ""

# Dữ liệu riêng cho quest "Bán Merchandise" (MERCH_SELLING)
var merch_sold_count: int = 0
@export var merch_target_count: int = 5
@export var merch_item_type: String = "Áo Concert"
var merch_buyer_indices: Array[int] = []

# Icon sản phẩm (Pixel_Mart)
@export var item_icon_path: String = ""

# Dữ liệu riêng cho quest "Cản đánh nhau" (INTERVENTION)
var intervention_progress: float = 0.0
@export var intervention_required_time: float = 2.5

# Dữ liệu riêng cho quest "Dắt trẻ lạc" (LOST_CHILD)
var parent_npc_idx: int = -1
var parent_global_pos: Vector2 = Vector2.INF



