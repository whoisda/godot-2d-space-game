extends KinematicBody2D


signal damaged(amount)


export var health_max := 100
export var linear_speed_max := 200.0
export var acceleration_max := 15.0
export var drag_factor := 0.04
export var angular_speed_max := 270
export var angular_acceleration_max := 15
export var angular_drag_factor := 0.1
export var distance_from_target_min := 200.0
export var distance_from_obstacles_min := 200.0
export var aggro_radius := 300.0
export var distance_from_spawn_max := 600.0
export var firing_angle_to_target := 4
export(int, LAYERS_2D_PHYSICS) var projectile_mask := 0
export var PopEffect: PackedScene

var _acceleration := GSTTargetAcceleration.new()
var _velocity := Vector2.ZERO
var _angular_velocity := 0.0
var _arrive_home_blend: GSTBlend
var _pursue_face_blend : GSTBlend
var _health := health_max
var target_agent: GSTSteeringAgent

onready var gun: Gun = $Gun

onready var agent := GSTKinematicBody2DAgent.new(self)
onready var priority := GSTPriority.new(agent)
onready var target_proximity := GSTRadiusProximity.new(
		agent,
		[],
		distance_from_target_min
)
onready var world_proximity := GSTRadiusProximity.new(
		agent,
		[],
		distance_from_obstacles_min
)
onready var spawn_location := GSTAgentLocation.new()


func _ready() -> void:
	# ----- Agent config -----
	agent.linear_acceleration_max = acceleration_max
	agent.linear_speed_max = linear_speed_max
	agent.angular_acceleration_max = deg2rad(angular_acceleration_max)
	agent.angular_speed_max = deg2rad(angular_speed_max)
	agent.bounding_radius = (
		MathUtils.get_triangle_circumcircle_radius($CollisionShape.polygon)
	)
	agent.linear_drag_percentage = drag_factor
	agent.angular_drag_percentage = angular_drag_factor

	spawn_location.position.x = global_position.x
	spawn_location.position.y = global_position.y

	_setup_behaviors()

	connect("damaged", self, "_on_self_damaged")


func _physics_process(delta: float) -> void:
	_set_behaviors_on_distances()
	_set_firing_on_target()

	priority.calculate_steering(_acceleration)
	agent._apply_steering(_acceleration, delta)


func setup_world_objects(world_objects: Array) -> void:
	for wo in world_objects:
		var object_agent: GSTAgentLocation = wo.agent_location
		if object_agent and not world_proximity.agents.has(object_agent):
			world_proximity.agents.append(object_agent)


func setup_target(target: Node) -> void:
	if target:
		target.connect("died", self, "_on_Target_died")
		target_agent = target.agent
	else:
		target_agent = null
	
	var pursue: GSTPursue = _pursue_face_blend.get_behavior_at(0).behavior as GSTPursue
	var face: GSTFace = _pursue_face_blend.get_behavior_at(1).behavior as GSTFace
	target_proximity.agents.append(target_agent)
	pursue.target = target_agent
	face.target = target_agent


func _die() -> void:
	var effect: Node2D = PopEffect.instance()
	effect.global_position = global_position
	ObjectRegistry.register_effect(effect)
	queue_free()


func _set_behaviors_on_distances() -> void:
	var distance_from_spawn := agent.position.distance_to(spawn_location.position)

	if distance_from_spawn > distance_from_spawn_max or not target_agent:
		_arrive_home_blend.is_enabled = true
		_pursue_face_blend.is_enabled = false
	else:
		if target_agent:
			var distance_from_target := agent.position.distance_to(target_agent.position)
			if distance_from_target < aggro_radius:
				_pursue_face_blend.is_enabled = true
				_arrive_home_blend.is_enabled = false


func _set_firing_on_target() -> void:
	if not target_agent:
		return

	if _pursue_face_blend.is_enabled:
		var to_target := (
				Vector2(agent.position.x, agent.position.y) -
				Vector2(target_agent.position.x, target_agent.position.y)
		)

		var angle_to_target: = to_target.angle_to(GSTUtils.angle_to_vector2(rotation))
		var comfortable_angle := deg2rad(firing_angle_to_target)
		if abs(angle_to_target) <= comfortable_angle:
			gun.fire(gun.global_position, rotation, projectile_mask)


func _setup_behaviors() -> void:
	var pursue := GSTPursue.new(agent, target_agent)

	var face := GSTFace.new(agent, target_agent)
	face.alignment_tolerance = deg2rad(5)
	face.deceleration_radius = deg2rad(45)

	_pursue_face_blend = GSTBlend.new(agent)
	_pursue_face_blend.add(pursue, 1)
	_pursue_face_blend.add(face, 1)
	_pursue_face_blend.is_enabled = false

	var separation := GSTSeparation.new(agent, target_proximity)
	separation.decay_coefficient = pow(target_proximity.radius, 2)/0.15

	_pursue_face_blend.add(separation, 2)

	var avoid := GSTAvoidCollisions.new(agent, world_proximity)

	var arrive := GSTArrive.new(agent, spawn_location)
	arrive.arrival_tolerance = 200
	arrive.deceleration_radius = 300
	var look := GSTLookWhereYouGo.new(agent)
	look.alignment_tolerance = deg2rad(5)
	look.deceleration_radius = deg2rad(45)

	_arrive_home_blend = GSTBlend.new(agent)
	_arrive_home_blend.add(arrive, 1)
	_arrive_home_blend.add(look, 1)
	_arrive_home_blend.is_enabled = false

	priority.add(avoid)
	priority.add(_arrive_home_blend)
	priority.add(_pursue_face_blend)


func _on_self_damaged(amount: int) -> void:
	_health -= amount
	if _health <= 0:
		_die()

	_health -= amount
	if _health <= 0:
		_pursue_face_blend.is_enabled = false
		_arrive_home_blend.is_enabled = true


func _on_Target_died() -> void:
	setup_target(null)