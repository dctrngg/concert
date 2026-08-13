extends Node2D
class_name TargetPointer

@export var orbit_radius: float = 24.0

@onready var arrow_sprite: Sprite2D = $ArrowSprite

var player: CharacterBody2D = null
var crowd_manager: Node = null
var food_source: Node2D = null
var chair_source: Node2D = null
var merch_stall: Node2D = null

func _ready() -> void:
	player = get_parent() as CharacterBody2D
	visible = false

func _process(_delta: float) -> void:
	if not player or not player.get("inventory"):
		visible = false
		return
		
	var target_pos = _get_active_target_position()
	if target_pos == Vector2.INF:
		visible = false
	else:
		visible = true
		var player_pos = player.global_position
		var dir = (target_pos - player_pos).normalized()
		
		# Đặt vị trí mũi tên xoay quanh player với bán kính orbit_radius
		position = dir * orbit_radius
		rotation = dir.angle()

func _get_active_target_position() -> Vector2:
	if not player or not player.inventory:
		return Vector2.INF
		
	var active_quests = player.inventory.get_active_quests()
	if active_quests.is_empty():
		return Vector2.INF
		
	# Lấy nhiệm vụ đầu tiên đang kích hoạt trong túi đồ
	var quest: NPCQuestData = active_quests[0]
	if quest == null:
		return Vector2.INF

	match quest.quest_type:
		NPCQuestData.QuestType.LOST_CHILD:
			if quest.parent_global_pos != Vector2.INF:
				return quest.parent_global_pos
			return _get_npc_quest_giver_position(quest)

		NPCQuestData.QuestType.MERCH_SELLING:
			if quest.is_item_picked_up:
				return _get_nearest_merch_buyer_position()
			else:
				var merch_stalls = get_tree().get_nodes_in_group("merch_stall")
				if merch_stalls.size() > 0:
					return merch_stalls[0].global_position
				return Vector2.INF

		NPCQuestData.QuestType.FOOD_DELIVERY:
			if not quest.is_item_picked_up:
				return _get_target_food_source_position(quest)
			else:
				return _get_npc_quest_giver_position(quest)

		NPCQuestData.QuestType.SEAT_FINDER:
			if not quest.is_item_picked_up:
				return _get_nearest_chair_source_position()
			else:
				return _get_npc_quest_giver_position(quest)

		NPCQuestData.QuestType.INTERVENTION:
			var fight_events = get_tree().get_nodes_in_group("fight_event")
			for fight in fight_events:
				if fight.get("quest_data") == quest or not fight.get("is_resolved"):
					return fight.global_position
			return Vector2.INF

	return Vector2.INF

func _get_npc_quest_giver_position(quest: NPCQuestData) -> Vector2:
	# 1. Kiểm tra xem NPC giao quest có đang ở trạng thái Promoted (Node thật) hay không
	var interactive_npcs = get_tree().get_nodes_in_group("npc_interactive")
	for npc in interactive_npcs:
		if npc.get("quest_data") == quest:
			return npc.global_position
			
	# 2. Nếu NPC đang ở dạng nền (CrowdManager multi-mesh array)
	if not crowd_manager:
		crowd_manager = get_node_or_null("/root/World/CrowdManager")
		
	if crowd_manager and "quest_data_map" in crowd_manager:
		var q_map: Dictionary = crowd_manager.quest_data_map
		for npc_idx in q_map.keys():
			if q_map[npc_idx] == quest:
				if "positions" in crowd_manager and npc_idx < crowd_manager.positions.size():
					var local_pos = crowd_manager.positions[npc_idx]
					return crowd_manager.to_global(local_pos)
					
	return Vector2.INF

func _get_nearest_merch_buyer_position() -> Vector2:
	if not player:
		return Vector2.INF
		
	var player_pos = player.global_position
	var nearest_pos = Vector2.INF
	var min_dist = INF
	
	# 1. Kiểm tra các promoted interactive NPCs đang là Merch Buyer
	var interactive_npcs = get_tree().get_nodes_in_group("npc_interactive")
	for npc in interactive_npcs:
		if npc.get("is_merch_buyer") == true:
			var d = player_pos.distance_to(npc.global_position)
			if d < min_dist:
				min_dist = d
				nearest_pos = npc.global_position
				
	if nearest_pos != Vector2.INF:
		return nearest_pos
		
	# 2. Kiểm tra các background crowd manager buyers
	if not crowd_manager:
		crowd_manager = get_node_or_null("/root/World/CrowdManager")
		
	if crowd_manager and "merch_buyers_map" in crowd_manager:
		var b_map: Dictionary = crowd_manager.merch_buyers_map
		for npc_idx in b_map.keys():
			if b_map[npc_idx] == true and npc_idx < crowd_manager.positions.size():
				var global_pos = crowd_manager.to_global(crowd_manager.positions[npc_idx])
				var d = player_pos.distance_to(global_pos)
				if d < min_dist:
					min_dist = d
					nearest_pos = global_pos
					
	return nearest_pos

const FOOD_STALL_MAP := {
	"Nước cam ép": 0, "Nước ngọt lon": 0, "Nước suối": 0, "Ca cao nóng": 0,
	"Bim bim khoai tây": 1, "Bánh Snack": 1, "Thanh năng lượng": 1, "Kẹo cao su": 1,
	"Bánh Cookies": 2, "Kem dâu tây": 2, "Socola sữa": 2, "Kẹo gôm": 2,
	"Chuối tươi": 3, "Sữa chua": 3, "Mứt dâu": 3, "Hộp sữa tươi": 3
}

func _get_target_food_source_position(quest: NPCQuestData) -> Vector2:
	var target_stall_id = 0
	for food_name in FOOD_STALL_MAP.keys():
		if food_name in quest.title or food_name in quest.description:
			target_stall_id = FOOD_STALL_MAP[food_name]
			break
			
	var food_sources = get_tree().get_nodes_in_group("food_source")
	for stall in food_sources:
		if stall.get("stall_id") == target_stall_id:
			return stall.global_position
			
	if food_sources.size() > 0:
		return food_sources[0].global_position
	return Vector2.INF

func _get_nearest_chair_source_position() -> Vector2:
	var chair_sources = get_tree().get_nodes_in_group("chair_source")
	if chair_sources.is_empty():
		return Vector2.INF
		
	if not player:
		return chair_sources[0].global_position
		
	var player_pos = player.global_position
	var nearest_pos = chair_sources[0].global_position
	var min_dist = INF
	
	for cs in chair_sources:
		var d = player_pos.distance_to(cs.global_position)
		if d < min_dist:
			min_dist = d
			nearest_pos = cs.global_position
			
	return nearest_pos
