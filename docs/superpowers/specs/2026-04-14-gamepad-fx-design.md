# AC Gamepad FX — Design Spec

**Date:** 2026-04-14
**Version:** 1.0
**Target:** CSP Gamepad FX Lua script (LuaJIT 5.2, CSP v0.2.0+)

---

## Overview

A Custom Shaders Patch Gamepad FX script for Assetto Corsa. Intercepts raw gamepad inputs every physics frame, processes them through a layered correction pipeline, and writes the results back before they reach the physics engine. No game files modified; works in single-player and online.

Primary goal: confident, stable control at high speed and in traffic.

---

## Execution Pipeline

The following single line defines execution order. **Section numbers below reflect conceptual importance, not execution sequence.**

```
raw input → deadzone/gamma → speed scale → slip limit (driver input only) → + self-steer → smooth → clamp → output
```

This comment appears verbatim at the top of the `script.update` function in the implementation.

---

## Design Goals

Sections are numbered by conceptual priority. The pipeline comment above is the authoritative execution order.

### 1. Speed-Sensitive Steering Ratio

At low speed, full stick = full lock. At `SPEED_SCALE_END` km/h and above, the same input produces only `SPEED_SCALE_MIN` of lock. Transition is a smooth curve with no hard cutoffs.

```
t = clamp((speed - SPEED_SCALE_START) / (SPEED_SCALE_END - SPEED_SCALE_START), 0, 1)
scale = lerp(1.0, SPEED_SCALE_MIN, t)
```

### 2. Deadzone & Gamma Curve

Deadzone removes stick drift and gives the center a clean null zone. The remaining range is rescaled to `[0, 1]` with no discontinuity at the deadzone edge. Gamma is applied after rescaling.

```
-- Deadzone with rescale:
abs = math.abs(v)
if abs < dz then return 0.0 end
normalized = (abs - dz) / (1.0 - dz)

-- Gamma:
result = sign * normalized ^ gamma
```

### 3. Steering Smoothing

Frame-rate independent exponential decay. `STEER_SMOOTH` is the blend weight at 60 fps — its meaning is intuitive at that reference rate and scales correctly at any other frame rate.

```
alpha = 1 - (1 - STEER_SMOOTH) ^ (dt * 60)
steerOut = lerp(steerOut, combined, alpha)
```

Smoothing is applied to the **combined** signal (driver input + self-steer) so corrections feel progressive. Smoothing driver input and self-steer separately would introduce correction lag during slides.

### 4. Self-Steer / Countersteer Force

Simulates caster-angle return-to-center. Applied after the slip limit clamp, before smoothing, so the correction is never artificially restricted by the driver input limit.

```
avgFrontSlip = (wheelsSlip[0] + wheelsSlip[1]) * 0.5
selfSteer = -avgFrontSlip * COUNTERSTEER_GAIN
          -  car.steer   * COUNTERSTEER_DAMP
combined = clampedDriverInput + selfSteer
```

`COUNTERSTEER_DAMP` must be kept at ≥ 60% of `COUNTERSTEER_GAIN` to prevent oscillation.

### 5. Dynamic Steering Limit Reduction

When front slip exceeds the optimal grip angle, the available driver input range shrinks proportionally. Prevents the driver from pushing past the point where tires can respond.

Applied to driver input only — self-steer is added afterward and is not subject to this limit.

```
slipFactor = clamp((avgFrontSlip - SLIP_LIMIT_START) / SLIP_LIMIT_RANGE, 0, 1)
steerLimit = lerp(1.0, SLIP_LIMIT_MIN, slipFactor)
clampedDriverInput = clamp(driverInput, -steerLimit, steerLimit)
```

### 6. Throttle & Brake Passthrough

Trigger axes passed directly to `ac.setGas` and `ac.setBrake` with a `[0, 1]` clamp. No processing in v1.

### 7. Future: Haptic Feedback

Not implemented in v1. CSP API is available (`ac.setControllerRumble`, `ac.setTriggerRumble` — CSP 0.2.0+). Candidate triggers: wheel slip onset, steering limit reduction active, kerb contact.

---

## Config Parameters

```lua
local CFG = {
    -- Deadzone & curve
    DEADZONE          = 0.08,   -- stick deadzone radius
    GAMMA             = 1.6,    -- steering curve exponent (>1 = more center precision)

    -- Smoothing
    STEER_SMOOTH      = 0.12,   -- blend weight at 60 fps (frame-rate independent)

    -- Speed scaling
    SPEED_SCALE_START = 60,     -- km/h where speed scaling begins
    SPEED_SCALE_END   = 180,    -- km/h where scaling reaches minimum
    SPEED_SCALE_MIN   = 0.35,   -- minimum steering multiplier at top speed

    -- Self-steer
    COUNTERSTEER_GAIN = 0.45,   -- correction strength
    COUNTERSTEER_DAMP = 0.30,   -- oscillation damping (keep >= 60% of GAIN)

    -- Slip limit
    SLIP_LIMIT_START  = 0.15,   -- front slip level where reduction begins
    SLIP_LIMIT_RANGE  = 0.25,   -- slip range over which full reduction is applied
    SLIP_LIMIT_MIN    = 0.70,   -- minimum driver authority at peak slip
}
```

---

## File Structure

```
assettocorsa/extension/lua/joypad-assist/
└── MyGamepadFX/
    ├── manifest.ini    ← declares name and version
    ├── assist.lua      ← entry point; update/reset hooks, pipeline assembly
    ├── lib.lua         ← math utilities: lerp, clamp, deadzone, gamma, exponential smoother
    ├── config.lua      ← CFG table; all tunable constants in one place
    └── debug.lua       ← live telemetry overlay via ac.debug(); tuning aid, not shipped
```

**Module responsibilities:**

`assist.lua` owns the pipeline and calls into the other modules. It should contain no math primitives and no raw constants — those live in `lib.lua` and `config.lua` respectively.

`lib.lua` contains every reusable helper: `applyDeadzone`, `applyGamma`, `speedScale`, `lerp`, and the exponential smoother. Any future smoothed value (e.g. slip-limit smoothing) uses the same smoother from this file, not a new inline implementation.

`config.lua` exports the `CFG` table. Keeping constants here means tuning sessions only ever touch one file, and Claude only needs to modify it when adjusting feel rather than logic.

`debug.lua` batches key pipeline values — raw input, clamped input, self-steer contribution, steer limit, final output — and prints them via `ac.debug(label, value)` each frame. Disable by not requiring the module. Not intended for release builds.

---

## Error Handling & Guard Conditions

- `ac.getCar(0)` can return nil for one or two frames on session load — guard before any property access
- `ac.getGamepad(0)` similarly guarded
- All axis reads use `or 0.0` fallback
- Final steer output clamped to `[-1, 1]` regardless of pipeline intermediate values
- `script.reset()` clears `steerOut = 0.0` to prevent jerk on session restart

---

## Known Pitfalls

- **Frame-rate dependent smoothing:** Fixed by exponential decay — `STEER_SMOOTH / dt` is NOT used
- **Axis index drift:** On first load, log all axes to confirm mapping before coding around them
- **Self-steer oscillation:** Raise `COUNTERSTEER_DAMP` before lowering `COUNTERSTEER_GAIN`
- **Nil guard on first frame:** Covered under Error Handling above
- **Inline math drift:** All helpers must come from `lib.lua` — never reimplement lerp or deadzone inline, as subtle differences accumulate across the pipeline