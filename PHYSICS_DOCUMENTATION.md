# Custom Physics System Documentation

## Overview
This Godot project implements a custom 2D physics simulation featuring spring-damped connections between objects, gravity, floor collision, and interactive impulse forces. The system models three nodes with interconnected physics behaviors.

---

## System Architecture

### Node Configuration
| Node | Mass | Role | Physics Behavior |
|------|------|------|------------------|
| `ic1` (Icon) | 5.0 | Primary particle | Spring-connected to ic2, pinned to dynamic anchor |
| `ic2` (Icon2) | 1.0 | Secondary particle | Spring-connected to ic1, pinned to offset anchor |
| `ic3` (Icon3) | N/A | Anchor controller | Gravity-affected, provides dynamic pin points |

### Physics Constants
```gdscript
ENERGY_CONSTANT: 1.0        # Spring force multiplier
DAMPING_RATIO: 0.02         # Proportional velocity damping
DAMPING_CONSTANT: 0.5       # Fixed velocity damping threshold
GRAVITY_CONSTANT: 39.8      # Downward acceleration (scaled from ~9.8 m/s²)
FLOOR_Y_CONSTANT: 500       # Ground level position
optimum_distance: dynamic   # Target spring length (calculated as initial distance - 20)
```

---

## Physics Components

### 1. Spring Force System

#### Concept
The system uses Hooke's Law variant to create spring-like connections between nodes. The force is proportional to displacement from an optimum distance.

#### Implementation
```gdscript
func _get_magnitude_by_at(by_node, at_node, force) -> float
```

**Formula Breakdown:**
```
distance = current distance between nodes
distance_optimum = desired equilibrium distance
distance_diff = distance_optimum - distance
relative_mass = mass(by_node) / mass(at_node)
tension = distance_diff
acceleration = force * relative_mass * tension
```

**Physical Interpretation:**
- **Positive tension** (distance < optimum): Spring is compressed → push apart
- **Negative tension** (distance > optimum): Spring is stretched → pull together
- **Mass ratio**: Heavier objects influence lighter objects more strongly
- **Force multiplier**: ENERGY_CONSTANT scales the spring stiffness

#### Connection Rules
- **ic1 ↔ ic2**: Spring connection with `optimum_distance = initial_distance - 20`
- **Other pairs**: No spring force (optimum_distance = 0)

---

### 2. Pin Point Attraction

#### Concept
Each node is attracted to a "pin point" anchor position, simulating tethered behavior.

#### Implementation
```gdscript
func _get_magnitude_to_point(point: Vector2, at_node: Node2D, force) -> float
```

**Formula:**
```
distance = |point - node_position|
tension = -distance
acceleration = force * tension
```

**Behavior:**
- Always creates attraction toward the pin point
- Negative tension ensures force always points toward target
- Force magnitude scales linearly with distance

#### Pin Point Configuration
```gdscript
pin_ic1 = ic3.global_position          # ic1 follows ic3 directly
pin_ic2 = pin_ic1 + Vector2(100, -100) # ic2 offset from ic3 (100 right, 100 up)
```

**Applied Forces:**
- `ic1`: 0.1× force toward `pin_ic1`
- `ic2`: 0.2× force toward `pin_ic2` (stronger attraction)

---

### 3. Damping System

The simulation uses **dual damping** to prevent oscillations and stabilize motion.

#### A. Proportional Damping (Ratio-based)
```gdscript
func _get_damping_as_ratio(velocity: Vector2) -> Vector2:
    return (-velocity * DAMPING_RATIO)
```

**Characteristics:**
- Linear with velocity (2% reduction per frame)
- Works at all speeds
- Ensures smooth asymptotic decay to rest

#### B. Constant Damping (Fixed force)
```gdscript
func _get_damping_as_constant(velocity: Vector2) -> Vector2:
    dv = (-velocity.normalized() * DAMPING_CONSTANT)
    if dv.length() > velocity.length():
        return _get_damping_as_ratio(velocity)
    return dv
```

**Characteristics:**
- Applies fixed 0.5 unit deceleration
- Direction opposite to velocity
- Falls back to ratio damping if force would overshoot (prevents velocity reversal)
- More effective at high speeds

**Application Order:**
1. Ratio damping applied first
2. Constant damping applied second
3. Both damping forces accumulate

---

### 4. Gravity and Floor Collision

#### Gravity Implementation
```gdscript
if ic3.global_position.y < FLOOR_Y_CONSTANT:
    vector_ic3.y += GRAVITY_CONSTANT * delta * 0.4
```

**Details:**
- Only affects `ic3` (anchor node)
- Scaled by 0.4 (15.92 m/s² effective acceleration)
- Applied only when above floor
- Unidirectional (downward only)

#### Floor Collision
```gdscript
if ic3.global_position.y >= FLOOR_Y_CONSTANT:
    ic3.global_position.y = FLOOR_Y_CONSTANT
    if vector_ic3.y > 0:
        vector_ic3.y = -vector_ic3.y * 0.6
```

**Collision Response:**
- Hard constraint: Position clamped to floor level
- Velocity reversal with 60% restitution coefficient
- Energy loss: 40% per bounce (coefficient = 0.6)
- Prevents penetration by position correction

---

## Physics Loop Execution Order

### Per-Frame Update (`_physics_process`)

```
1. GRAVITY PHASE
   └─ Apply gravity to ic3

2. COLLISION PHASE
   └─ Floor collision detection and response for ic3
   └─ Update ic3 position

3. ANCHOR UPDATE
   └─ pin_ic1 = ic3.position
   └─ pin_ic2 = pin_ic1 + offset

4. SPRING FORCES (mutual)
   └─ ic1 receives force from ic2
   └─ ic2 receives force from ic1

5. PIN ATTRACTION FORCES
   └─ ic1 attracted to pin_ic1 (force: 0.1)
   └─ ic2 attracted to pin_ic2 (force: 0.2)

6. DAMPING FORCES (dual application)
   └─ Ratio damping for ic1 and ic2
   └─ Constant damping for ic1 and ic2

7. POSITION INTEGRATION
   └─ ic1.position += vector_ic1
   └─ ic2.position += vector_ic2
```

---

## Force Analysis

### Force Diagram for ic1
```
Total Acceleration = Spring_force(ic2→ic1) 
                   + Pin_attraction(pin_ic1→ic1) 
                   + Damping_ratio(velocity_ic1)
                   + Damping_constant(velocity_ic1)
```

**Per-frame calculation:**
```gdscript
vector_ic1 += _get_acceleration_by_at(ic2, ic1) * delta                    // Spring
vector_ic1 += _get_magnitude_to_point(pin_ic1, ic1, 0.1) * direction       // Pin
vector_ic1 += _get_damping_as_ratio(vector_ic1)                            // Damping 1
vector_ic1 += _get_damping_as_constant(vector_ic1)                         // Damping 2
```

### Force Diagram for ic2
```
Total Acceleration = Spring_force(ic1→ic2) 
                   + Pin_attraction(pin_ic2→ic2) 
                   + Damping_ratio(velocity_ic2)
                   + Damping_constant(velocity_ic2)
```

---

## Mass and Acceleration Relationships

### Spring Force Asymmetry
Due to mass ratios, forces are **not equal and opposite**:

**Force on ic1 from ic2:**
```
F_ic1 = ENERGY_CONSTANT * (mass_ic2 / mass_ic1) * tension
      = 1.0 * (1/5) * tension
      = 0.2 * tension
```

**Force on ic2 from ic1:**
```
F_ic2 = ENERGY_CONSTANT * (mass_ic1 / mass_ic2) * tension
      = 1.0 * (5/1) * tension
      = 5.0 * tension
```

**Result:** ic2 (lighter) experiences 25× stronger acceleration than ic1 (heavier) for the same spring displacement.

---

## Interactive Forces

### Mouse Click Impulse
```gdscript
func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        mouse_pos = get_global_mouse_position()
        target = random_choice([ic1, ic2])
        
        impulse_force = ENERGY_CONSTANT * rand(0, 0.3)
        distance = |mouse_pos - target_position|
        direction = target_position → mouse_pos
        
        target_velocity += impulse_force * distance * direction
```

**Behavior:**
- 50% chance to affect ic1, 50% for ic2
- Impulse magnitude: 0% to 30% of ENERGY_CONSTANT
- Repulsive force (pushes away from click)
- Force scales with distance from click

---

## System Characteristics

### Stability Analysis
**Stabilizing Forces:**
- Pin attractions keep system bounded
- Dual damping prevents runaway oscillations
- Floor collision prevents infinite fall

**Destabilizing Factors:**
- Low damping ratios allow sustained oscillation
- Mass asymmetry creates unequal responses
- Pin force difference (0.1 vs 0.2) creates preferential motion

### Energy Dissipation
1. **Ratio damping**: 2% velocity loss per frame
2. **Constant damping**: 0.5 units/frame at high speeds
3. **Floor bounces**: 40% energy loss per collision
4. **Net effect**: System converges to equilibrium at pin positions

### Coupling Effects
- **ic3 motion → cascade**: Gravity pulls ic3, which drags ic1 and ic2 via pins
- **ic1-ic2 spring**: Coupling creates coupled oscillator behavior
- **Damping feedback**: Faster motion → stronger ratio damping

---

## Potential Issues and Improvements

### Current Issues
1. **Damping redundancy**: Applying both ratio and constant damping may be overkill
2. **No time-step independence**: Physics scales with frame rate (missing proper delta scaling on some forces)
3. **Mass-based forces**: Unusual spring force implementation (typically mass-independent)
4. **Magic numbers**: Pin forces (0.1, 0.2) lack physical meaning

### Suggested Improvements
```gdscript
# More realistic spring force (mass-independent)
func improved_spring_force(k: float, displacement: Vector2) -> Vector2:
    return -k * displacement  # F = -kx

# Semi-implicit Euler integration (more stable)
func improved_integration(pos: Vector2, vel: Vector2, accel: Vector2, delta: float):
    vel += accel * delta
    pos += vel * delta
    return [pos, vel]

# Single unified damping
func unified_damping(velocity: Vector2, damping_coeff: float) -> Vector2:
    return -damping_coeff * velocity
```

---

## Conclusion

This custom physics system creates an emergent behavior where:
1. **ic3** acts as a gravitational pendulum
2. **ic1** and **ic2** form a coupled spring-damped oscillator
3. **Pin forces** tether the oscillator to ic3
4. **User interaction** adds external impulses

The result is a fluid-like, organic motion with realistic damping and interactive behavior suitable for game demonstrations or particle effects.

---

**Last Updated:** 2025-10-07  
**Godot Version:** 4.4  
**Script:** `glue_1.gd`
