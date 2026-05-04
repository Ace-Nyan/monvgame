# CharacterManager.gd
extends Node

# 单例模式
static var instance: Node  

# 存储所有角色数据
var characters: Dictionary = {}  # character_id: CharacterData

# ==== 初始化 ====
func _enter_tree():
	# 设置单例实例
	instance = self
	print("角色管理器初始化完成")
	
# ==== 角色管理 ====
func add_character(character_data: CharacterData) -> void:
	characters[character_data.character_id] = character_data
	print("添加角色: %s" % character_data.character_name)

func get_character(character_id: String) -> CharacterData:
	return characters.get(character_id)

func remove_character(character_id: String) -> void:
	if characters.has(character_id):
		characters.erase(character_id)

# ==== 批量操作 ====
func heal_all(amount: float) -> void:
	for character in characters.values():
		character.add_hp(amount)

func restore_all_mp(amount: float) -> void:
	for character in characters.values():
		character.add_mp(amount)

# ==== 查找 ====
func find_characters_by_type(magic_type: MagicType.Type) -> Array:
	var result = []
	for character in characters.values():
		if character.has_magic_type(magic_type):
			result.append(character)
	return result

# ==== 保存/加载 ====
func save_all_characters() -> Dictionary:
	var save_data = {}
	for char_id in characters:
		save_data[char_id] = characters[char_id].save_to_dict()
	return save_data

func load_characters(data: Dictionary) -> void:
	for char_id in data:
		var char_data = data[char_id]
		if characters.has(char_id):
			characters[char_id].load_from_dict(char_data)
		else:
			var new_char = CharacterData.new()
			new_char.load_from_dict(char_data)
			characters[char_id] = new_char
