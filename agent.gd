extends Node2D

@onready var ship : CharacterBody2D = get_parent()
@onready var debug_path = ship.get_node('../debug_path')

var _path : Array[Vector2] = []
var _target : Vector2 = Vector2.INF
var _target_idx : int = -1

# This method is called on every tick to choose an action.  See README.md
# for a detailed description of its arguments and return value.
func action(_walls: Array[PackedVector2Array], _gems: Array[Vector2], 
			_polygons: Array[PackedVector2Array], _neighbors: Array[Array]):
	
	if _target == Vector2.INF:
		pass
	
	
	# Local pathfinding
	var spin : int = 0
	var thrust : int = 0
	
	# Check target validity
	var dist_to_target = _target.distance_to(ship.position + ship.velocity)
	if dist_to_target < 10 or _target_idx == -1:
		_target_idx += 1
		if _path.size() == 0 or _target_idx >= _path.size():
			#_set_path(_get_closest_gem(gems))
			_path = _gems
			_target_idx = 0
			_target = _path[_target_idx]
			return [0, 0, false]
		
		_target = _path[_target_idx]
	
	# Navigate to target
	var dir_to_target = _target - (ship.position + ship.velocity)
	var angle_to_target = dir_to_target.angle_to(ship.transform.x)
	if angle_to_target > 0.05:
		spin = -1
	elif angle_to_target < -0.05:
		spin = 1
	else:
		thrust = 1
	
	return [spin, thrust, false]


# Called every time the agent has bounced off a wall.
func bounce():
	return

# Called every time a gem has been collected.
func gem_collected():
	print("collected")

func _set_path(path_target : Vector2):
	pass 

func _get_closest_gem(gems : Array[Vector2]) -> Vector2:
	var min_dist = ship.position.distance_to(gems[0])
	var closest_gem = gems[0]
	
	for gem in gems:
		var dist = ship.position.distance_to(gem)
		if dist < min_dist:
			min_dist = dist
			closest_gem = gem
	
	return closest_gem
