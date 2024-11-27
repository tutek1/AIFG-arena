extends CharacterBody2D

const ROTATE_SPEED = 4
const ACCEL = 150

@onready var Laser = preload('res://laser.tscn')
@onready var agent = get_node('agent')
@onready var RADIUS = get_node('CollisionShape2D').shape.radius

var lasers = 0

func _physics_process(delta):
	var arena = get_parent()
	var use_agent = arena.use_agent

	var action
	if use_agent:
		if arena.building or arena.gems == []:
			action = [0, false, false]
		else:
			var gems: Array[Vector2]
			gems.assign(arena.gems.map(func(g): return g.position))
			action = agent.action(arena.wall_polygons, gems, arena.polygons, arena.neighbors)

	var turn = action[0] if use_agent else Input.get_axis('ui_left', 'ui_right')
	turn = clampi(turn, -1, 1)
	rotation += turn * ROTATE_SPEED * delta

	var thrust = action[1] if use_agent else Input.is_action_pressed('thrust')
	if thrust:
		velocity += Vector2.from_angle(rotation) * ACCEL * delta
		$particles.emitting = true
	else:
		$particles.emitting = false

	var collision = move_and_collide(velocity * delta)
	if collision:
		%bounce_sound.play()
		velocity = velocity.bounce(collision.get_normal()) * 0.7
		if use_agent:
			agent.bounce()

	var fire = action[2] if use_agent else Input.is_action_just_pressed('fire')
	if lasers > 0 and fire:
		get_parent().add_laser(-1)
		%fire_sound.play()
		var laser = Laser.instantiate()
		var point = Vector2.from_angle(rotation)
		laser.position = position + point * 20
		laser.rotation = rotation
		laser.velocity = velocity + point * laser.SPEED
		%lasers.add_child(laser)
