class_name DialogueTree
extends Resource
## nodes: Array of dictionaries:
## {"id","speaker","text","set_flag","quest","next","end","choices":[
##   {"text","next","set_flag","give","take","quest","rep","requires_flag","requires_item"}]}

@export var id: String = ""
@export var npc_id: String = ""
@export var start_node: String = "start"
@export var nodes: Array = []


func node_by_id(node_id: String) -> Dictionary:
	for n in nodes:
		if String(n.get("id", "")) == node_id:
			return n
	return {}
