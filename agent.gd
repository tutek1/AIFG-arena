extends Node2D

const ANGLE_TOLERANCE: float = 0.05
const THRUST_TOLERANCE: float = 1
const SLOWDOWN_DISTANCE: float = 900
const DIST_TOLERANCE: float = 40
const DIST_TOLER_SPEED_MAX_ADJUST: float = 20
const SHOOT_TICK_DELAY: int = 130
const ANGLE_SHOT_TOLERANCE: float = 0.05
const MIN_DIVERGENCE_SHOOT: int = 150
const MAX_DIVERGENCE_SHOOT: int = 500 
const DIST_SHIP_TO_GEM_WEIGHT: float = 1
const GEM_CLUSTERNESS_WEIGHT: float = -3
const MIN_DIST_PORTAL: float = 20

const RECALCULATE_PATH_TICKS: int = 10
const SMOOTH_PATH_ROUGHNESS: float = 5

@onready var arena : Node2D = get_parent().get_parent()
@onready var ship : CharacterBody2D = get_parent()
@onready var debug_path : Line2D = ship.get_node('../debug_path')

var _path: Array[Vector2] = []
var _path_target: Vector2 = Vector2.INF
var _was_in_polygon_idx: int = -1
var _ticks: int = 0
var _shot_at_tick: int = 0
var _last_num_walls: int = 0 	# Used to update after wall destroy

# This method is called on every tick to choose an action.  See README.md
# for a detailed description of its arguments and return value.
func action(walls: Array[PackedVector2Array], gems: Array[Vector2], 
			polygons: Array[PackedVector2Array], neighbors: Array[Array]):
	_ticks += 1
	
	# Check which polygon we are in
	var is_in_polygon_idx: int =  _get_closest_polygon_idx_to_point(ship.position, polygons)
	
	# Upon change of polygon or path end or wall destroy recalculate or X ticks
	if _path.size() < 1\
	or _was_in_polygon_idx != is_in_polygon_idx\
	or _last_num_walls != walls.size()\
	or _ticks % RECALCULATE_PATH_TICKS == 0:
		_set_path(gems, polygons, neighbors)
		if _path.size() == 0:
			_path_target = gems.pick_random()
		else:
			_path_target = _path.back()
		_was_in_polygon_idx = is_in_polygon_idx
	
	_last_num_walls = walls.size()
	
	# Check if already close enough to a target along the path
	var dist_to_target = _path_target.distance_to(ship.position)
	var speed_dist_adjust : float = lerp(0.0, DIST_TOLER_SPEED_MAX_ADJUST, float(ship.velocity.length())/ship.ACCEL)
	if dist_to_target < DIST_TOLERANCE + speed_dist_adjust and _path.size() > 1:
		_path.pop_back()
		_path_target = _path.back()
		dist_to_target = _path_target.distance_to(ship.position)
	
	# Debug
	debug_path.clear_points()
	for point in _path:
		debug_path.add_point(point)
	debug_path.add_point(ship.position)
	debug_path.add_point(_get_polygon_center(polygons[is_in_polygon_idx]))
	
	# Local pathfinding to target
	var spin : int = 0
	var thrust : int = 0
	var shoot : bool = false
	
	# Try to shoot
	var max_divergence = lerp(MIN_DIVERGENCE_SHOOT, MAX_DIVERGENCE_SHOOT, arena.time_left/arena.TIME_LIMIT)
	if _get_path_divergence() > max_divergence\
	and ship.lasers > 0\
	and _ticks - _shot_at_tick > SHOOT_TICK_DELAY:
		var target = _path.front()
		var dir_to_target: Vector2 = target - (ship.position + ship.velocity)
		var angle_to_target: float = dir_to_target.angle_to(ship.transform.x)
		if angle_to_target > ANGLE_SHOT_TOLERANCE:
			spin = -1
		elif angle_to_target < -ANGLE_SHOT_TOLERANCE:
			spin = 1
		else:
			shoot = true
			_shot_at_tick = _ticks
	
	# Navigate to target
	else:
		var velocity_mult: float = lerp(ship.velocity.length()/ship.ACCEL, 1.0, dist_to_target/SLOWDOWN_DISTANCE)
		var dir_to_target: Vector2 = _path_target - (ship.position + (ship.velocity * velocity_mult))
		var angle_to_target: float = dir_to_target.angle_to(ship.transform.x)
		if angle_to_target > ANGLE_TOLERANCE:
			spin = -1
		elif angle_to_target < -ANGLE_TOLERANCE:
			spin = 1
		
		if -THRUST_TOLERANCE < angle_to_target and angle_to_target < THRUST_TOLERANCE:
			thrust = 1
	
	return [spin, thrust, shoot]


# Called every time the agent has bounced off a wall.
func bounce():
	_path.clear()	# Reset path

# Called every time a gem has been collected.
func gem_collected():
	_path.clear()	# Reset path

# A data class used for pathfinding
class PathNode:
	var parent_idx: int
	var dist: float

# Sets the _path variable with a valid path to a gem
func _set_path(gems: Array[Vector2], polygons: Array[PackedVector2Array], neighbors: Array[Array]):
	# Setup the queue and start polygon
	var start_poly_idx: int = _get_closest_polygon_idx_to_point(ship.position, polygons)
	var poly_queue: Array[int]
	poly_queue.append(start_poly_idx)
	
	# Setup visited with the start polygon
	var visited : Array[PathNode]
	visited.resize(polygons.size())
	var start_node: PathNode = PathNode.new()
	start_node.parent_idx = start_poly_idx
	start_node.dist = 0
	visited[start_poly_idx] = start_node
	
	# Build a tree like structure from the navmesh
	while not poly_queue.is_empty():
		var curr_node_idx : int = poly_queue.pop_front()
		var curr_poly : PackedVector2Array = polygons[curr_node_idx]
		
		# Add not visited neighbors
		var curr_center: Vector2 = _get_polygon_center(curr_poly)
		var curr_dist: float = visited[curr_node_idx].dist
		for neighbor_idx: int in neighbors[curr_node_idx]:
			var dist_to_neighbor: float = _get_polygon_center(polygons[neighbor_idx]).distance_to(curr_center)
			
			var neighbor_node: PathNode = PathNode.new()
			neighbor_node.dist = curr_dist + dist_to_neighbor
			neighbor_node.parent_idx = curr_node_idx
			
			# Already visited
			var visited_node: PathNode = visited[neighbor_idx]
			if visited_node != null:
				
				# Check if we have closer path than already present
				if neighbor_node.dist < visited_node.dist:
					visited_node.dist = neighbor_node.dist 
					visited_node.parent_idx = curr_node_idx
				continue
			
			visited[neighbor_idx] = neighbor_node
			poly_queue.append(neighbor_idx)
	
	# Find the closest gem based on tree dist and dist to ship
	var min_dist_gem: float = INF
	var goal_poly_idx: int
	var goal_target: Vector2
	for gem: Vector2 in gems:
		var avg_dist_to_gems: float
		for gem2 in gems:
			avg_dist_to_gems += gem.distance_to(gem2)
		
		avg_dist_to_gems /= gems.size()
		
		for poly_idx: int in range(0, polygons.size()):
			var poly: PackedVector2Array = polygons[poly_idx]
			var gem_dist_to_poly: float = _get_closest_point_on_polygon_FIXED(gem, poly).distance_to(gem)
			if gem_dist_to_poly > 10: continue
			
			var path_dist: float = visited[poly_idx].dist if visited[poly_idx] != null else 0.0
			path_dist += gem.distance_to(ship.position) * DIST_SHIP_TO_GEM_WEIGHT +\
						 avg_dist_to_gems * GEM_CLUSTERNESS_WEIGHT
			
			if path_dist < min_dist_gem:
				goal_target = gem
				goal_poly_idx = poly_idx
				min_dist_gem = path_dist
	
	# Clear the path and build it
	var temp_path : Array[Vector2]
	temp_path.append(goal_target)
	var last_point: Vector2 = goal_target
	
	# if we somehow didnt find a way to the gem
	if visited[goal_poly_idx] == null:
		goal_target = gems.pick_random()
		goal_poly_idx = _get_closest_polygon_idx_to_point(goal_target, polygons)
	
	# Traverse the tree from goal to start
	while goal_poly_idx != start_poly_idx and visited[goal_poly_idx] != null:
		var curr_poly: PackedVector2Array = polygons[goal_poly_idx]
		var next_poly: PackedVector2Array = polygons[visited[goal_poly_idx].parent_idx]
		
		# Find the two polygon connecting points -> portal points
		var portal_point1: Vector2 = Vector2.INF
		var portal_point2: Vector2 = Vector2.INF
		for point_curr: Vector2 in curr_poly:
			for point_next: Vector2 in next_poly:
				if point_curr.is_equal_approx(point_next):
					if portal_point1 == Vector2.INF:
						portal_point1 = point_curr
					else:
						portal_point2 = point_curr
						break
			if portal_point2 != Vector2.INF: break
		
		# Add a point on the portal line closest to the mid point of the ship and the last point
		var ship_last_point_mid: Vector2 = (ship.position + last_point) / 2
		last_point = _get_closest_point_on_line(portal_point1,
												portal_point2,
												ship_last_point_mid,
												MIN_DIST_PORTAL)
		temp_path.append(last_point)
		
		goal_poly_idx = visited[goal_poly_idx].parent_idx
	
	# Path smoothing
	if temp_path.size() >= 2:
		var curr_point : Vector2 = _get_closest_point_on_polygon_FIXED(ship.position, polygons[start_poly_idx]) 
		
		var last_tested_idx : int = temp_path.size() - 2
		for idx_next in range(last_tested_idx, -1, -1):
			var next_point : Vector2 = temp_path[idx_next]
			if not _check_if_line_is_in_polygons(curr_point, next_point, polygons):
				last_tested_idx = idx_next + 1
				break
			last_tested_idx = idx_next
		
		_path.clear()
		for i in range(0, last_tested_idx + 1):
			_path.append(temp_path[i])
	else:
		_path = temp_path

# Returns the mid-point of the polygon
func _get_polygon_center(poly : PackedVector2Array) -> Vector2:
	var point: Vector2 = Vector2.ZERO
	
	for vertex: Vector2 in poly:
		point += vertex
	
	return point/poly.size()

# Returns the max divergence of the positions in the _path variable
# Divergence - max distance of points from the line (from ship to goal)
func _get_path_divergence() -> float:
	var max_length: float = 0
	
	for pos: Vector2 in _path:
		var length = (_get_closest_point_on_line(ship.position, _path.front(), pos) - pos).length()
		max_length = max(length, max_length)
	
	return max_length

# Returns the idx of the polygon that is the closest to the ship
func _get_closest_polygon_idx_to_point(point : Vector2, polygons: Array[PackedVector2Array]) -> int:
	var min_dist : float = INF
	var closest_idx : int
	for poly_idx in range(0, polygons.size()):
		var poly: PackedVector2Array = polygons[poly_idx]
		
		var point_on_poly: Vector2 = _get_closest_point_on_polygon_FIXED(point, poly)
		var dist_to_poly: float = point_on_poly.distance_to(point)
		if dist_to_poly < 10:
			return poly_idx
		
		if dist_to_poly < min_dist:
			min_dist = dist_to_poly
			closest_idx = poly_idx
	
	return closest_idx

# Returns the position of the closest gem to the ship
func _get_closest_gem(gems : Array[Vector2]) -> Vector2:
	var min_dist = ship.position.distance_to(gems[0])
	var closest_gem = gems[0]
	
	for gem in gems:
		var dist = ship.position.distance_to(gem)
		if dist < min_dist:
			min_dist = dist
			closest_gem = gem
	
	return closest_gem

# Returns the closest point on a line to a given point
func _get_closest_point_on_line(line_a : Vector2, line_b : Vector2, point : Vector2,
								min_dist : float = 0.0) -> Vector2:
	var line: Vector2 = line_b - line_a
	var t = ((point - line_a).dot(line)) / line.length_squared()
	var min_t : float = max(0, min(min_dist/line.length(), 1.0))
	t = clamp(t, min_t, 1 - min_t)
	
	return line_a + line * t

func _get_closest_point_on_polygon_FIXED(point : Vector2, poly : PackedVector2Array):
	if Geometry2D.is_point_in_polygon(point, poly): return point
	
	return Util.get_closest_point_on_polygon(point, poly)

func _check_if_line_is_in_polygons(point1 : Vector2, point2 : Vector2, polygons : Array[PackedVector2Array]):
	var dir_to_next : Vector2 = (point2 - point1).normalized()
	
	var temp_point : Vector2 = point1
	while temp_point.distance_to(point2) > SMOOTH_PATH_ROUGHNESS:
		temp_point += dir_to_next * SMOOTH_PATH_ROUGHNESS
		
		var is_on_polygon : bool = false
		for poly in polygons:
			if Geometry2D.is_point_in_polygon(temp_point, poly):
				is_on_polygon = true
				break
		
		if not is_on_polygon:
			return false
	
	return true
