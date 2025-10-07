# Physics System Refactoring - TODO List

## Overview
Refactor the monolithic `glue_1.gd` physics implementation into a modular, reusable system with custom node types and a centralized physics engine.

---

## Node Type Design

### ☐ 1. Design PhysicsBody2D custom node class
**File:** `physics_body_2d.gd`

Create a base class for physics-enabled nodes with properties:
- `mass: float` - Object mass for force calculations
- `velocity: Vector2` - Current velocity vector
- `acceleration: Vector2` - Accumulated acceleration this frame
- `damping_ratio: float` - Proportional velocity damping
- `damping_constant: float` - Fixed velocity damping
- `enabled: bool` - Enable/disable physics processing

**Methods:**
- `apply_force(force: Vector2)` - Accumulate forces
- `apply_damping(delta: float)` - Apply both damping types
- `integrate(delta: float)` - Update velocity and position
- `reset_forces()` - Clear accumulated forces

**Purpose:** Replace current `vector_ic1/vector_ic2` approach with unified interface

---

### ☐ 2. Create SpringConnection node type
**File:** `spring_connection.gd`

Design a node that represents a spring connection between two PhysicsBody2D nodes.

**Properties:**
- `body_a: PhysicsBody2D` - First connected body
- `body_b: PhysicsBody2D` - Second connected body
- `optimum_distance: float` - Equilibrium spring length
- `spring_constant: float` - Spring stiffness (k value)
- `auto_calculate_distance: bool` - Set optimum from initial positions
- `enabled: bool` - Enable/disable this connection

**Methods:**
- `calculate_spring_force() -> void` - Compute and apply forces to both bodies
- `get_current_distance() -> float` - Distance between bodies
- `get_tension() -> float` - Spring displacement from equilibrium

**Purpose:** Handles bidirectional spring force calculations

---

### ☐ 3. Create PinConstraint node type
**File:** `pin_constraint.gd`

Design a constraint node that pins a PhysicsBody2D to a target position.

**Properties:**
- `target_body: PhysicsBody2D` - Body to constrain
- `pin_position: Vector2` - Target position (world space)
- `pin_to_node: Node2D` - Alternative: pin to another node's position
- `position_offset: Vector2` - Offset from pin_to_node
- `pin_strength: float` - Force multiplier
- `enabled: bool` - Enable/disable constraint

**Methods:**
- `apply_constraint() -> void` - Calculate and apply pin force
- `get_effective_pin_position() -> Vector2` - Resolve actual pin location
- `get_distance_to_pin() -> float` - Current displacement

**Purpose:** Pins bodies to fixed or dynamic positions with configurable strength

---

### ☐ 4. Create GravityBody2D node type
**File:** `gravity_body_2d.gd`

Extend PhysicsBody2D to add gravity and floor collision.

**Properties:**
- Inherits all PhysicsBody2D properties
- `gravity_scale: float` - Multiplier for global gravity
- `use_gravity: bool` - Enable gravity for this body
- `floor_enabled: bool` - Enable floor collision
- `floor_y: float` - Floor position
- `restitution: float` - Bounce coefficient (0-1)

**Methods:**
- `apply_gravity(delta: float)` - Add gravitational acceleration
- `check_floor_collision()` - Detect and resolve floor collision
- `_physics_process(delta: float)` - Override to add gravity logic

**Purpose:** Handles vertical physics and bouncing (for anchor nodes)

---

## Engine Architecture

### ☐ 5. Design CustomPhysicsEngine class
**File:** `custom_physics_engine.gd`

Create centralized physics orchestrator.

**Properties:**
- `physics_bodies: Array[PhysicsBody2D]` - Registered bodies
- `constraints: Array[Node]` - Pin constraints, springs, etc.
- `global_gravity: float` - Default gravity value
- `physics_enabled: bool` - Master physics toggle
- `debug_draw: bool` - Enable debug visualization

**Methods:**
- `register_body(body: PhysicsBody2D)` - Add body to simulation
- `unregister_body(body: PhysicsBody2D)` - Remove body
- `register_constraint(constraint: Node)` - Add constraint
- `discover_physics_nodes()` - Auto-find all physics components
- `_physics_process(delta: float)` - Main physics loop

**Physics Loop Order:**
1. Reset all forces on bodies
2. Apply gravity to GravityBody2D nodes
3. Process all constraints (springs, pins)
4. Apply damping to all bodies
5. Integrate positions (update all body positions)
6. Handle collisions (floor checks)
7. Debug draw (if enabled)

**Purpose:** Orchestrates all physics in correct order

---

## Implementation Tasks

### ☐ 6. Implement force calculation methods
Move physics calculations from `glue_1.gd` into appropriate node classes:

**SpringConnection:**
- Migrate `_get_magnitude_by_at()` logic
- Implement proper Hooke's Law: `F = -k * (distance - optimum)`
- Consider mass ratios or use mass-independent forces
- Ensure proper delta scaling

**PinConstraint:**
- Migrate `_get_magnitude_to_point()` logic
- Implement: `F = -strength * distance_vector`
- Apply to single body only

**PhysicsBody2D:**
- Migrate `_get_damping_as_ratio()` and `_get_damping_as_constant()`
- Unify or make configurable
- Apply to self.velocity

**Purpose:** Distribute physics logic into appropriate classes

---

### ☐ 7. Add PhysicsEngine registration system
Implement auto-discovery or manual registration of physics bodies and constraints.

**Auto-discovery approach:**
```gdscript
func discover_physics_nodes():
    # Find all children recursively
    physics_bodies = find_children("*", "PhysicsBody2D", true, false)
    constraints = find_children("*", "SpringConnection", true, false)
    constraints += find_children("*", "PinConstraint", true, false)
```

**Manual registration approach:**
```gdscript
func _ready():
    var engine = get_node("/root/PhysicsEngine")
    engine.register_body(self)
```

**Features:**
- Enable/disable individual bodies and constraints
- Add/remove at runtime
- Query system state

**Purpose:** Engine maintains lists of all active physics components

---

### ☐ 8. Create configuration and constants
**File:** `physics_config.gd`

Centralize physics constants in a resource or autoload singleton.

**Global Settings:**
```gdscript
extends Node

# Spring Physics
var default_spring_constant: float = 1.0
var default_optimum_distance: float = 100.0

# Damping
var default_damping_ratio: float = 0.02
var default_damping_constant: float = 0.5

# Gravity
var default_gravity: float = 39.8
var default_gravity_scale: float = 0.4

# Collision
var default_floor_y: float = 500.0
var default_restitution: float = 0.6

# Interaction
var default_impulse_strength: float = 1.0
var default_impulse_randomness: float = 0.3
```

**Allow per-body overrides** via exported properties.

**Purpose:** Single source of truth for physics parameters

---

## Scene Refactoring

### ☐ 9. Refactor existing scene to use new system
Update `node_2d.tscn` to use new node architecture.

**Old Structure:**
```
Node2D
├── Icon (Sprite2D)
├── Icon2 (Sprite2D)
├── Icon3 (Sprite2D)
└── Glue1 (Node2D with glue_1.gd)
```

**New Structure:**
```
Node2D
├── CustomPhysicsEngine
├── Icon (Sprite2D)
│   └── PhysicsBody2D [mass=5, damping_ratio=0.02]
├── Icon2 (Sprite2D)
│   └── PhysicsBody2D [mass=1, damping_ratio=0.02]
├── Icon3 (Sprite2D)
│   └── GravityBody2D [gravity_scale=0.4, floor_y=500, restitution=0.6]
├── SpringConnection [body_a=Icon, body_b=Icon2, spring_constant=1.0]
├── PinConstraint [target_body=Icon, pin_to_node=Icon3, strength=0.1]
└── PinConstraint [target_body=Icon2, pin_to_node=Icon3, offset=(100,-100), strength=0.2]
```

**Configure properties via inspector** instead of hardcoding in scripts.

**Purpose:** Demonstrate new system recreating original behavior

---

## Enhancement Tasks

### ☐ 10. Add debug visualization to PhysicsEngine
Implement optional debug drawing in CustomPhysicsEngine.

**Visualizations:**
- **Spring connections:** Lines with color based on tension
  - Green: compressed
  - Red: stretched
  - Width: proportional to force magnitude
- **Pin constraints:** Arrows from body to pin position
- **Velocity vectors:** Blue arrows showing movement direction
- **Force vectors:** Yellow arrows showing net force
- **Mass indicators:** Circle size or text label

**Configuration:**
```gdscript
@export var debug_draw: bool = false
@export var draw_springs: bool = true
@export var draw_pins: bool = true
@export var draw_velocities: bool = false
@export var draw_forces: bool = false
```

**Implementation:**
```gdscript
func _draw():
    if not debug_draw:
        return
    
    for spring in springs:
        if draw_springs:
            _draw_spring(spring)
    
    for constraint in constraints:
        if draw_pins:
            _draw_pin(constraint)
    
    # ... etc
```

**Purpose:** Visual debugging and parameter tuning

---

### ☐ 11. Implement mouse interaction system
**File:** `mouse_impulse_controller.gd`

Create reusable component for mouse-based force application.

**Properties:**
- `target_bodies: Array[PhysicsBody2D]` - Bodies that can be affected
- `impulse_strength: float` - Base impulse magnitude
- `impulse_randomness: float` - Random variation (0-1)
- `random_target: bool` - Pick random body from array
- `repulsive: bool` - Push away vs pull toward click

**Methods:**
- `_input(event: InputEvent)` - Handle mouse clicks
- `apply_impulse_at(position: Vector2, target: PhysicsBody2D)` - Apply force

**Usage:**
```gdscript
# In scene
MouseImpulseController
├── target_bodies = [Icon/PhysicsBody2D, Icon2/PhysicsBody2D]
├── impulse_strength = 1.0
├── impulse_randomness = 0.3
└── random_target = true
```

**Purpose:** Replicate current mouse behavior in reusable way

---

## Testing & Validation

### ☐ 12. Test and validate physics behavior
Ensure refactored system produces same or better behavior as original.

**Test Cases:**

1. **Spring Oscillations**
   - Set bodies at various distances
   - Verify they converge to optimum_distance
   - Check oscillation frequency matches expectations

2. **Damping Convergence**
   - Apply impulse
   - Verify system settles to rest state
   - Measure settling time

3. **Gravity & Floor Collision**
   - Drop GravityBody from various heights
   - Verify floor collision at correct Y
   - Check bounce heights match restitution coefficient

4. **Pin Constraints**
   - Move pin_to_node
   - Verify pinned bodies follow correctly
   - Check force strength proportional to distance

5. **Mouse Impulses**
   - Click at various positions
   - Verify impulse direction and magnitude
   - Check random target selection

6. **Mass Effects**
   - Verify heavier bodies move less
   - Check spring forces respect mass ratios (if implemented)

**Compare with original:** Run side-by-side with `glue_1.gd` implementation

**Reference:** Use `PHYSICS_DOCUMENTATION.md` as specification

**Success Criteria:**
- [ ] Visual behavior matches original
- [ ] No physics explosions or instabilities
- [ ] Performance is acceptable (monitor FPS)
- [ ] Code is cleaner and more maintainable

---

## Progress Tracking

**Not Started:** 12 tasks  
**In Progress:** 0 tasks  
**Completed:** 0 tasks

**Last Updated:** 2025-10-07
