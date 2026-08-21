extends Control
class_name OverheadItemBar

@onready var slot_icons: Array[TextureRect] = [
	$HBox/Slot1/ItemIcon,
	$HBox/Slot2/ItemIcon,
	$HBox/Slot3/ItemIcon
]

@onready var slot_texts: Array[Label] = [
	$HBox/Slot1/TextIcon,
	$HBox/Slot2/TextIcon,
	$HBox/Slot3/TextIcon
]

@onready var slot_frames: Array[Control] = [
	$HBox/Slot1,
	$HBox/Slot2,
	$HBox/Slot3
]

var inventory: PlayerInventory = null

func _ready() -> void:
	z_index = 100
	z_as_relative = false
	await get_tree().process_frame
	var player = get_parent()
	if player and player.get("inventory"):
		inventory = player.inventory
		inventory.inventory_changed.connect(update_bar)
		update_bar()

func _center_hbox() -> void:
	var hbox = get_node_or_null("HBox") as Control
	if hbox:
		hbox.reset_size()
		var min_size = hbox.get_combined_minimum_size()
		hbox.position = -min_size / 2.0

func update_bar() -> void:
	if not inventory:
		visible = false
		return
		
	var slots_data = inventory.slots
	var active_count = 0
	
	for i in range(3):
		if i >= slots_data.size():
			slot_frames[i].visible = false
			continue
			
		var quest = slots_data[i]
		var icon_node = slot_icons[i]
		var text_node = slot_texts[i]
		var frame_node = slot_frames[i]
		
		if quest == null:
			frame_node.visible = false
			icon_node.texture = null
			if text_node: text_node.text = ""
		else:
			active_count += 1
			frame_node.visible = true
			
			# Nếu đã cầm đồ (is_item_picked_up = true) -> Highlight sáng rực rỡ!
			# Nếu chưa cầm đồ -> Mờ nhẹ (35% opacity)
			if quest.is_item_picked_up:
				frame_node.modulate = Color(1.35, 1.35, 1.15, 1.0) # Highlight rực sáng rực rỡ
			else:
				frame_node.modulate = Color(1.0, 1.0, 1.0, 0.35) # Mờ nhẹ khi chưa lấy đồ
			
			match quest.quest_type:
				NPCQuestData.QuestType.SEAT_FINDER:
					icon_node.visible = false
					if text_node:
						text_node.text = "🪑"
						text_node.visible = true
				NPCQuestData.QuestType.MERCH_SELLING:
					icon_node.visible = false
					if text_node:
						text_node.text = "🛍️"
						text_node.visible = true
				NPCQuestData.QuestType.LOST_CHILD:
					icon_node.visible = false
					if text_node:
						text_node.text = "👶"
						text_node.visible = true
				_:
					if text_node: text_node.visible = false
					var icon_path = _get_quest_icon_path(quest)
					if icon_path != "" and ResourceLoader.exists(icon_path):
						icon_node.texture = load(icon_path)
						icon_node.visible = true
					else:
						icon_node.texture = null
						icon_node.visible = false

	visible = (active_count > 0)
	if visible:
		_center_hbox()

func _get_quest_icon_path(quest: NPCQuestData) -> String:
	if quest.item_icon_path != "":
		return quest.item_icon_path
	return "res://Sprites/Pixel_Mart/banana.png"
