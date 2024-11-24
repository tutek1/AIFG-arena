extends Node2D

@onready var ship = get_parent()
@onready var debug_path = ship.get_node('../debug_path')

var ticks = 0
var spin = 0
var thrust = false

# This method is called on every tick to choose an action.  See README.md
# for a detailed description of its arguments and return value.
func action(_walls: Array[PackedVector2Array], _gems: Array[Vector2], 
            _polygons: Array[PackedVector2Array], _neighbors: Array[Array]):

    # This is a dummy agent that just moves around randomly.
    # Replace this code with your actual implementation.
    ticks += 1
    if ticks % 30 == 0:
        spin = Random.randi_range(-1, 1)
        thrust = bool(Random.randi_range(0, 1))
    
    return [spin, thrust, false]

# Called every time the agent has bounced off a wall.
func bounce():
    return

# Called every time a gem has been collected.
func gem_collected():
    return

# Called every time a new level has been reached.
func new_level():
    return
