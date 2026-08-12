extends Control
class_name OverheadItemBar

@onready var slot_icons: Array[TextureRect] = [
	$HBox/Slot1/ItemIcon,
	$HBox/Slot2/ItemIcon,
	$HBox/Slot3/ItemIcon
]

@onready var slot_frames: Array[Control] = [
	$HBox/Slot1,
	$HBox/Slot2,
	$HBox/Slot3
]

var inventory: PlayerInventory = null

func _ready() -> void:
	await get_tree().process_frame
	var player = get_parent()
	if player and player.get("inventory"):
		inventory = player.inventory
		inventory.inventory_changed.connect(update_bar)
		update_bar()

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
		var frame_node = slot_frames[i]
		
		if quest == null:
			# Ẩn slot trống khi chưa nhận quest ở slot đó
			frame_node.visible = false
			icon_node.texture = null
		else:
			active_count += 1
			frame_node.visible = true
			
			if quest.is_item_picked_up:
				# Đã lấy đồ -> icon rõ nét 100%
				icon_node.modulate = Color(1, 1, 1, 1.0)
				var icon_path = _get_quest_icon_path(quest)
				if icon_path != "" and ResourceLoader.exists(icon_path):
					icon_node.texture = load(icon_path)
					icon_node.visible = true
				else:
					icon_node.texture = null
					icon_node.visible = false
			else:
				# Nhận quest nhưng chưa lấy đồ -> icon mờ mờ
				icon_node.modulate = Color(1, 1, 1, 0.35)
				var icon_path = _get_quest_icon_path(quest)
				if icon_path != "" and ResourceLoader.exists(icon_path):
					icon_node.texture = load(icon_path)
					icon_node.visible = true
				else:
					icon_node.texture = null
					icon_node.visible = false

	# Ẩn toàn bộ thanh nếu không giữ bất kỳ quest/vật phẩm nào
	visible = (active_count > 0)

func _get_quest_icon_path(quest: NPCQuestData) -> String:
	if quest.item_icon_path != "":
		return quest.item_icon_path
		
	match quest.quest_type:
		NPCQuestData.QuestType.SEAT_FINDER:
			return "res://Sprites/Pixel_Mart/paper_bag.png"
		NPCQuestData.QuestType.MERCH_SELLING:
			return "res://Sprites/Pixel_Mart/paper_bag.png"
		_:
			return "res://Sprites/Pixel_Mart/banana.png"
