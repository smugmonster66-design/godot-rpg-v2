@tool
extends RefCounted
## Shared helpers for the Dialogue Editor serializer/deserializer.
##
## The graph UI only has widgets for a subset of DialogueEncounter / DialogueLine /
## DialogueChoice fields. To make load -> save lossless, the deserializer keeps the
## original resource on each graph node (metadata "source_line" or the choice dict key
## "_source"), and the serializer starts every new resource from a copy of that
## original, then overwrites only the fields the UI controls.

## Script variables that are exported/stored on a resource (skips built-ins such as
## resource_name/resource_path and non-storage properties).
static func stored_script_props(res: Object) -> Array[String]:
	var out: Array[String] = []
	if res == null:
		return out
	for prop in res.get_property_list():
		var usage: int = prop.usage
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) and (usage & PROPERTY_USAGE_STORAGE):
			out.append(prop.name)
	return out

## Copy every stored script variable from src to dst, except names in skip.
## Arrays and Dictionaries are deep-copied (sub-resources inside them are shared,
## which is what the saver needs to keep them as the same sub_resource).
static func copy_script_props(src: Object, dst: Object, skip: Array = []) -> void:
	if src == null or dst == null:
		return
	for pname in stored_script_props(src):
		if pname in skip:
			continue
		var v = src.get(pname)
		if v is Array or v is Dictionary:
			v = v.duplicate(true)
		dst.set(pname, v)

## Structural equality of two values (resources compared field by field; external
## resources with a file path are compared by path). Used to decide whether a
## condition can be shown in a simple widget without losing data.
static func values_equal(a, b) -> bool:
	if a is Resource or b is Resource:
		if not (a is Resource and b is Resource):
			return false
		if a == b:
			return true
		var pa: String = a.resource_path
		var pb: String = b.resource_path
		if pa != "" and not pa.contains("::"):
			return pa == pb
		if pb != "" and not pb.contains("::"):
			return false
		if a.get_script() != b.get_script():
			return false
		for pname in stored_script_props(a):
			if not values_equal(a.get(pname), b.get(pname)):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not values_equal(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not values_equal(a[k], b[k]):
				return false
		return true
	if typeof(a) != typeof(b):
		# StringName vs String compare by text
		if (a is String or a is StringName) and (b is String or b is StringName):
			return str(a) == str(b)
		return false
	return a == b

## Find a dictionary key by its text (keys may be String or StringName).
static func find_key(d: Dictionary, key_text: String):
	for k in d:
		if str(k) == key_text:
			return k
	return null

## Human-readable one-line summary of a GameCondition (for read-only display).
static func describe_condition(cond: Resource) -> String:
	if cond == null:
		return "always"
	var text := ""
	match int(cond.get("condition_type")):
		0:
			text = "always"
		1:
			text = "never"
		2:
			text = describe_check(cond.get("single_check"))
		3, 4:
			var parts: Array[String] = []
			for sub in cond.get("sub_conditions"):
				parts.append(describe_condition(sub))
			var joiner = " AND " if int(cond.get("condition_type")) == 3 else " OR "
			text = "(" + joiner.join(parts) + ")"
	if cond.get("invert") == true:
		text = "NOT " + text
	return text

static func describe_check(check: Resource) -> String:
	if check == null:
		return "(empty check)"
	var key = str(check.get("key"))
	var op = str(check.get("compare_operator"))
	var n = int(check.get("int_value"))
	match int(check.get("check_type")):
		0: return "flag %s is %s" % [key, "set" if check.get("bool_value") else "not set"]
		1: return "counter %s %s %d" % [key, op, n]
		2: return "relationship %s %s %d" % [key, op, n]
		3: return "has item %s %s %d" % [key, op, n]
		4: return "player level %s %d" % [op, n]
		5: return "class %s level %s %d" % [str(check.get("class_id")), op, n]
		6: return "quest %s is %s" % [key, str(check.get("quest_state"))]
		7: return "visited %s" % key
		8: return "approval %s %s %d" % [key, op, n]
		9: return "custom %s" % key
	return "check type %d" % int(check.get("check_type"))
