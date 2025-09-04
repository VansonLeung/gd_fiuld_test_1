extends Node2D

@onready var ic1: Node2D = $"../Icon"
@onready var ic2: Node2D = $"../Icon2"
@onready var ic3: Node2D = $"../Icon3"

var optimum_distance: float = 0
var ENERGY_CONSTANT: float = 1
var DAMPING_RATIO: float = 0.02
var DAMPING_CONSTANT: float = 0.5
var GRAVITY_CONSTANT: float = 39.8
var FLOOR_Y_CONSTANT: float = 500

var vector_ic1 := Vector2(10, 10)
var vector_ic2 := Vector2.ZERO
var vector_ic3 := Vector2.ZERO

var pin_ic1 := Vector2.ZERO
var pin_ic2 := Vector2.ZERO

func _get_mass(node) -> float:
	if node == ic1:
		return 5
	if node == ic2:
		return 1
	return 0
	
func _get_distance(node_a: Node2D, node_b: Node2D) -> float:
	return node_a.global_position.distance_to(node_b.global_position)
	
func _get_direction_from_to(node_a: Node2D, node_b: Node2D) -> Vector2:
	return node_a.global_position.direction_to(node_b.global_position)
	
func _get_optimum_distance(node_a, node_b) -> float:
	if (node_a == ic1 and node_b == ic2) or (node_a == ic2 and node_b == ic1):
		return optimum_distance
	return 0

func _get_magnitude_by_at(by_node, at_node, force) -> float:
	var distance = _get_distance(by_node, at_node)
	var distance_optimum = _get_optimum_distance(by_node, at_node)
	var distance_diff = distance_optimum - distance
	var relative_mass = (_get_mass(by_node) / _get_mass(at_node))
	var tension = distance_diff
	var accel = force * relative_mass * tension
	return accel

func _get_magnitude_to_point(point: Vector2, at_node: Node2D, force) -> float:
	var distance = point.distance_to(at_node.global_position)
	var tension = -distance
	var accel = force * tension
	return accel
	
func _get_direction_by_at(by_node, at_node) -> Vector2:
	return _get_direction_from_to(by_node, at_node)
	
func _get_acceleration_by_at(by_node, at_node) -> Vector2:
	return (
		_get_magnitude_by_at(by_node, at_node, ENERGY_CONSTANT)
	 	* _get_direction_by_at(by_node, at_node)
	)

func _get_damping_as_ratio(velocity: Vector2) -> Vector2:
	return (-velocity * DAMPING_RATIO)

func _get_damping_as_constant(velocity: Vector2) -> Vector2:
	var dv = (-velocity.normalized() * DAMPING_CONSTANT)
	if dv.length() > velocity.length():
		return _get_damping_as_ratio(velocity)
	return dv
	

func _ready():
	optimum_distance = _get_distance(ic1, ic2) - 20

	pin_ic1 = ic3.global_position
	pin_ic2 = ic1.global_position + Vector2(100, -100)

func _physics_process(delta: float) -> void:
	# ic3 to floor gravity
	if ic3.global_position.y < FLOOR_Y_CONSTANT:
		vector_ic3.y += GRAVITY_CONSTANT * delta * 0.4

	# bounce off floor
	if ic3.global_position.y >= FLOOR_Y_CONSTANT:
		ic3.global_position.y = FLOOR_Y_CONSTANT
		if vector_ic3.y > 0:
			vector_ic3.y = -vector_ic3.y * 0.6

	ic3.global_position += vector_ic3

	pin_ic1 = ic3.global_position
	pin_ic2 = pin_ic1 + Vector2(100, -100)

	vector_ic1 += _get_acceleration_by_at(ic2, ic1) * delta
	vector_ic2 += _get_acceleration_by_at(ic1, ic2) * delta
	
	vector_ic1 += _get_magnitude_to_point(pin_ic1, ic1, 0.1) * pin_ic1.direction_to(ic1.global_position)
	vector_ic2 += _get_magnitude_to_point(pin_ic2, ic2, 0.2) * pin_ic2.direction_to(ic2.global_position)
	
	vector_ic1 += _get_damping_as_ratio(vector_ic1)
	vector_ic2 += _get_damping_as_ratio(vector_ic2)
	
	vector_ic1 += _get_damping_as_constant(vector_ic1)
	vector_ic2 += _get_damping_as_constant(vector_ic2)
	

	ic1.global_position += vector_ic1
	ic2.global_position += vector_ic2

	pass
	
func _input(event: InputEvent) -> void:
	# mouse click to induce force impulse
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = get_global_mouse_position()
		# randomize target ic
		if randf() < 0.5:
			vector_ic1 += _get_magnitude_to_point(mouse_pos, ic1, ENERGY_CONSTANT*randf() * 0.3) * -mouse_pos.direction_to(ic1.global_position)
		else:
			vector_ic2 += _get_magnitude_to_point(mouse_pos, ic2, ENERGY_CONSTANT*randf() * 0.3) * -mouse_pos.direction_to(ic2.global_position)
	pass
