# AC Gamepad FX — Development Instructions

## What This Is

This is a **Custom Shaders Patch (CSP) Gamepad FX Lua script** for Assetto Corsa. Its job is to intercept raw gamepad inputs every physics frame, process them, and write corrected values back to the game before they reach the physics engine — no game files modified, works in single-player and online.

The primary goal is confident, stable control at **high speed and in traffic**: reducing stick twitchiness, scaling steering authority with speed, and applying a self-steer force that catches overcorrections before they become spins.

Minimum CSP version: **v0.2.0**. Target latest stable.

---

## File Structure

```
assettocorsa/extension/lua/joypad-assist/
└── MyGamepadFX/
    ├── manifest.ini        ← required; declares name and version
    └── assist.lua          ← main script (entry point)
```

**manifest.ini:**
```ini
[ABOUT]
NAME = MyGamepadFX
VERSION = 1.0
```

The script is activated in **Content Manager → Settings → Custom Shaders Patch → Gamepad FX**.

---

## AC Controls Settings

These must be set in **Content Manager → Controls** before testing. The script takes over all of these responsibilities itself.

| Setting | Value |
|---|---|
| Speed Sensitivity | 0% |
| Steering Speed | 100% (or 1% if relying on script smoothing) |
| Steering Gamma | 100% |
| Steering Filter | 0% |
| Steering Deadzone | 0% |

---

## Runtime & Entry Points

Scripts run in **LuaJIT** (5.2 compatibility mode). CSP calls two functions each session:

```lua
function script.update(dt)  -- called every physics frame; dt = delta time in seconds
function script.reset()     -- called on session reset or car change; clear all state here
```

Global-namespace versions (`function update(dt)`) also work for backwards compatibility, but `script.*` is preferred and looked up first.

---

## CSP API Reference

### Reading Gamepad Input
```lua
local gamepad = ac.getGamepad(0)   -- 0 = primary gamepad
gamepad.axes[1]   -- left stick X: steering    [-1, 1]
gamepad.axes[2]   -- left stick Y              [-1, 1]  (usually unused)
gamepad.axes[3]   -- right trigger: throttle   [0, 1]
gamepad.axes[4]   -- left trigger: brake       [0, 1]
-- Note: axis indices can vary by controller — validate at startup with ac.log()
```

### Writing Outputs to Physics
```lua
ac.setSteer(value)        -- [-1, 1]   final steering
ac.setGas(value)          -- [0, 1]    throttle
ac.setBrake(value)        -- [0, 1]    brake pressure
ac.setClutch(value)       -- [0, 1]    clutch (0 = fully engaged)
ac.setGearRequest(delta)  -- int: +1 upshift, -1 downshift, 0 = hold
```

### Car Physics & Telemetry
```lua
local car = ac.getCar(0)              -- 0 = player car (may be nil on first frame — guard this)

car.speedKmh                          -- speed in km/h
car.localVelocity                     -- vec3: velocity in car-local space
car.steer                             -- current steering angle, normalized
car.gas / car.brake / car.clutch      -- current applied input values
car.gear                              -- 0=R, 1=N, 2=1st gear, ...
car.rpm / car.rpmLimiter              -- engine RPM
car.wheelsSlip[0..3]                  -- lateral slip per wheel (FL, FR, RL, RR)
car.tyreSlip[0..3]                    -- combined slip per wheel
car.wheelAngularSpeed[0..3]           -- wheel angular velocity
car.isGrounded[0..3]                  -- bool: wheel contact per corner

-- Common derived value:
local avgFrontSlip = (car.wheelsSlip[0] + car.wheelsSlip[1]) * 0.5
```

### Haptics (Xbox controllers)
```lua
ac.setControllerRumble(leftMotor, rightMotor, duration)  -- motors [0,1], duration in seconds
ac.setTriggerRumble(leftTrigger, rightTrigger)           -- trigger motors [0,1], CSP 0.2.0+
```

### Utilities
```lua
ac.log("message")               -- write to CSP log
ac.setMessage("Title", "Body")  -- in-game toast notification
```

---

## Design Goals

These are the core systems to build, in implementation order. Each one builds on the last.

### 1. Speed-Sensitive Steering Ratio
The most important feature for traffic driving. At low speed, full stick should equal full lock. At 150+ km/h, that same input should only produce ~35–40% of lock. The transition must be a smooth curve over a configurable speed range — never a hard cutoff, which feels like the car suddenly goes numb.

### 2. Deadzone & Gamma Curve
Deadzone (7–12%) removes stick drift and gives the center a clean null zone. A gamma exponent above 1.0 compresses the center portion of the stick travel, allowing fine, precise adjustments at speed while the outer range still builds to full authority for emergency moves. These two work together to define how the stick *feels* at rest and in motion.

### 3. Steering Smoothing
A per-frame lerp on the final steering output kills single-frame spikes that cause snap-oversteer. The lerp factor must be `dt`-normalized so the smoothing behavior is identical at 60fps and 165fps. This is the difference between a stable car and one that twitches at the limit.

### 4. Self-Steer / Countersteer Force
This simulates the natural caster-angle return-to-center behavior of a real steering wheel. Read the average front wheel slip and apply a corrective force opposing it, plus a damping term proportional to the current steer angle to kill oscillation. **This is the most critical system for traffic driving** — without it, any overcorrection compounds and spins the car. With it, the car wants to track straight and small corrections feel effortless.

### 5. Dynamic Steering Limit Reduction
When front slip exceeds the optimal grip angle, reduce the available steering range proportionally. This prevents the driver from instinctively jabbing the stick past the point where the tires can respond — a common mistake when threading through traffic at speed.

### 6. Throttle & Brake Passthrough
For initial implementation, pass trigger inputs directly. A future improvement is a gentle gamma curve on the throttle for smoother power delivery out of slow corners, but this is low priority compared to steering feel.

---

## Script Skeleton

```lua
-- ============================================================
-- Config
-- ============================================================
local CFG = {
    DEADZONE          = 0.08,   -- stick deadzone radius
    GAMMA             = 1.6,    -- steering curve exponent (>1 = more center precision)
    STEER_SMOOTH      = 0.12,   -- smoothing strength (lower = smoother, more lag)
    SPEED_SCALE_START = 60,     -- km/h where speed scaling begins
    SPEED_SCALE_END   = 180,    -- km/h where scaling reaches minimum
    SPEED_SCALE_MIN   = 0.35,   -- minimum steering multiplier at top speed
    COUNTERSTEER_GAIN = 0.45,   -- self-steer correction strength
    COUNTERSTEER_DAMP = 0.30,   -- oscillation damping (keep at ~60%+ of GAIN)
}

-- ============================================================
-- State
-- ============================================================
local steerOut = 0.0

-- ============================================================
-- Helpers
-- ============================================================

local function applyDeadzone(v, dz)
    local sign = v >= 0 and 1 or -1
    local abs  = math.abs(v)
    if abs < dz then return 0.0 end
    return sign * (abs - dz) / (1.0 - dz)
end

local function applyGamma(v, gamma)
    local sign = v >= 0 and 1 or -1
    return sign * math.pow(math.abs(v), gamma)
end

local function speedScale(speedKmh)
    local t = math.clamp(
        (speedKmh - CFG.SPEED_SCALE_START) / (CFG.SPEED_SCALE_END - CFG.SPEED_SCALE_START),
        0.0, 1.0
    )
    return 1.0 - t * (1.0 - CFG.SPEED_SCALE_MIN)
end

local function lerp(a, b, t)
    return a + (b - a) * math.clamp(t, 0.0, 1.0)
end

-- ============================================================
-- Main loop
-- ============================================================
function script.update(dt)
    local car     = ac.getCar(0)
    local gamepad = ac.getGamepad(0)
    if not car or not gamepad then return end

    -- 1. Raw input → deadzone → gamma → speed scale
    local input = applyDeadzone(gamepad.axes[1] or 0.0, CFG.DEADZONE)
    input = applyGamma(input, CFG.GAMMA)
    input = input * speedScale(car.speedKmh)

    -- 2. Self-steer correction + damping
    local avgFrontSlip = (car.wheelsSlip[0] + car.wheelsSlip[1]) * 0.5
    local selfSteer    = -avgFrontSlip * CFG.COUNTERSTEER_GAIN
                       -  car.steer   * CFG.COUNTERSTEER_DAMP
    input = input + selfSteer

    -- 3. Smooth output (dt-normalized)
    steerOut = lerp(steerOut, input, CFG.STEER_SMOOTH / dt)

    -- 4. Write to physics
    ac.setSteer(math.clamp(steerOut,                      -1.0, 1.0))
    ac.setGas(  math.clamp(gamepad.axes[3] or 0.0,         0.0, 1.0))
    ac.setBrake(math.clamp(gamepad.axes[4] or 0.0,         0.0, 1.0))
end

function script.reset()
    steerOut = 0.0
end
```

---

## Tuning Reference

| Parameter | Too Low | Too High | Start Here |
|---|---|---|---|
| `DEADZONE` | Drifts, oversensitive center | Dead, unresponsive center | 0.08 |
| `GAMMA` | Linear, twitchy at speed | Heavy center, slow to build | 1.6 |
| `STEER_SMOOTH` | Immediate, sharp | Laggy, disconnected feel | 0.10–0.15 |
| `SPEED_SCALE_MIN` | Nearly undriveable at speed | Too much lock available fast | 0.35 |
| `COUNTERSTEER_GAIN` | Car wants to spin | Overpowers driver input | 0.40–0.55 |
| `COUNTERSTEER_DAMP` | Pendulum oscillation | Wooden, dead steering feel | 0.25–0.40 |

`COUNTERSTEER_DAMP` should always be at least 60% of `COUNTERSTEER_GAIN` to prevent oscillation.

---

## Known Pitfalls

**Frame-rate dependent smoothing** — always normalize lerp `t` against `dt`. A fixed constant will feel totally different at 60fps vs 165fps. The form `CFG.STEER_SMOOTH / dt` works, or use `1 - (1 - base)^dt` for a more mathematically correct exponential decay.

**Axis index drift** — gamepad axis assignments are not guaranteed. On first load, log all axes with `ac.log()` to confirm the mapping matches expectations before coding around it.

**Self-steer oscillation** — if the car develops a tank-slapper effect, `COUNTERSTEER_DAMP` is too low relative to `COUNTERSTEER_GAIN`. Raise damp first before lowering gain.

**Nil guard on first frame** — `ac.getCar(0)` can return nil for a frame or two on session load. Always check before reading car properties or the script will throw and stop running.

**`script.reset()` must clear all state** — any smoothed or accumulated value left over from the previous session will cause a jerk at the start of the next one.

---

## References

- CSP Lua SDK: https://github.com/ac-custom-shaders-patch/acc-lua-sdk
- CSP internal gamepad scripts: https://github.com/ac-custom-shaders-patch/acc-lua-internal
- Advanced Gamepad Assist (full reference implementation): https://github.com/adam10603/AC-Advanced-Gamepad-Assist
- ConsoleFX (simpler reference): https://www.overtake.gg/downloads/consolefx-a-console-like-script-for-gamepads.53561/
- Full API docs ship with CSP at: `assettocorsa/extension/internal/lua-sdk/`
