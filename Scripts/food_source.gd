extends Area2D
class_name FoodSource

@export var stall_id: int = 0
@export var stall_name: String = "Quầy Đồ Ăn"

const STALL_CONFIGS := {
	0: {
		"name": "🥤 Pixel Oasis (Nước Giải Khát)",
		"icon1": "res://Sprites/Pixel_Mart/orange_juice.png",
		"icon2": "res://Sprites/Pixel_Mart/soft_drink_red.png"
	},
	1: {
		"name": "🍿 Crunchy Corner (Bim Bim & Snack)",
		"icon1": "res://Sprites/Pixel_Mart/potatochip_yellow.png",
		"icon2": "res://Sprites/Pixel_Mart/snack1.png"
	},
	2: {
		"name": "🍰 Sweet Paradise (Bánh Ngọt & Kem)",
		"icon1": "res://Sprites/Pixel_Mart/strawberry_ice_cream.png",
		"icon2": "res://Sprites/Pixel_Mart/cookies.png"
	},
	3: {
		"name": "🍌 Fresh & Healthy (Trái Cây & Sữa)",
		"icon1": "res://Sprites/Pixel_Mart/banana.png",
		"icon2": "res://Sprites/Pixel_Mart/plain_yogurt.png"
	}
}

const STALL_FOOD_ITEMS := {
	0: ["Nước cam ép", "Nước ngọt lon", "Nước suối", "Ca cao nóng"],
	1: ["Bim bim khoai tây", "Bánh Snack", "Thanh năng lượng", "Kẹo cao su"],
	2: ["Bánh Cookies", "Kem dâu tây", "Socola sữa", "Kẹo gôm"],
	3: ["Chuối tươi", "Sữa chua", "Mứt dâu", "Hộp sữa tươi"]
}

const FOOD_STALL_MAP := {
	"Nước cam ép": 0, "Nước ngọt lon": 0, "Nước suối": 0, "Ca cao nóng": 0,
	"Bim bim khoai tây": 1, "Bánh Snack": 1, "Thanh năng lượng": 1, "Kẹo cao su": 1,
	"Bánh Cookies": 2, "Kem dâu tây": 2, "Socola sữa": 2, "Kẹo gôm": 2,
	"Chuối tươi": 3, "Sữa chua": 3, "Mứt dâu": 3, "Hộp sữa tươi": 3
}

var is_player_nearby: bool = false

func _ready() -> void:
	add_to_group("food_source")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_update_stall_visuals()

func _update_stall_visuals() -> void:
	var cfg = STALL_CONFIGS.get(stall_id, STALL_CONFIGS[0])
	stall_name = cfg["name"]
	
	var label = get_node_or_null("Label") as Label
	if label:
		label.visible = false
		
	var d1 = get_node_or_null("FoodDisplay1") as Sprite2D
	if d1 and ResourceLoader.exists(cfg["icon1"]):
		d1.texture = load(cfg["icon1"])
		d1.scale = Vector2(1.2, 1.2)
		
	var d2 = get_node_or_null("FoodDisplay2") as Sprite2D
	if d2 and ResourceLoader.exists(cfg["icon2"]):
		d2.texture = load(cfg["icon2"])
		d2.scale = Vector2(1.2, 1.2)

func interact() -> void:
	_try_pickup_food()

func _try_pickup_food() -> void:
	var quest_manager = get_node_or_null("/root/QuestManager")
	if not quest_manager:
		return
	var player = quest_manager.get_player()
	if not player or not player.get("inventory"):
		return
		
	var inventory = player.inventory
	var active_quests = inventory.get_active_quests()
	var allowed_list: Array = STALL_FOOD_ITEMS.get(stall_id, [])
	
	var picked_up_any = false
	var wrong_stall_food_needed = ""
	
	for quest in active_quests:
		if quest.quest_type == NPCQuestData.QuestType.FOOD_DELIVERY and not quest.is_item_picked_up:
			var item_matched = false
			for food_name in allowed_list:
				if food_name in quest.title or food_name in quest.description:
					item_matched = true
					break
					
			if item_matched:
				quest.is_item_picked_up = true
				picked_up_any = true
				print("[FoodSource] Đã lấy thành công đồ ăn từ %s cho: %s" % [stall_name, quest.title])
			else:
				for f_key in FOOD_STALL_MAP.keys():
					if f_key in quest.title or f_key in quest.description:
						wrong_stall_food_needed = f_key
						break

	if picked_up_any:
		inventory.inventory_changed.emit()
		var tree = get_tree()
		if tree:
			tree.call_group("npc_interactive", "update_quest_indicator")
		var sound_mgr = get_node_or_null("/root/SoundManager")
		if not sound_mgr and tree:
			sound_mgr = tree.get_first_node_in_group("sound_manager")
		if sound_mgr and sound_mgr.has_method("play_food_pickup_sfx"):
			sound_mgr.play_food_pickup_sfx()
	elif not wrong_stall_food_needed.is_empty():
		var correct_stall_id = FOOD_STALL_MAP.get(wrong_stall_food_needed, 0)
		var correct_cfg = STALL_CONFIGS.get(correct_stall_id, {})
		var correct_stall_name = correct_cfg.get("name", "quầy khác")
		print("[FoodSource] %s không bán %s! Bạn cần sang đúng %s!" % [stall_name, wrong_stall_food_needed, correct_stall_name])
	else:
		print("[FoodSource] %s: Không có nhiệm vụ mua đồ ăn nào cần lấy hàng tại đây." % stall_name)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true
		print("[%s] Ấn [E] hoặc Click chuột trái để lấy hàng." % stall_name)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
