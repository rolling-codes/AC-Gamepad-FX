# AC Gamepad FX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a CSP Gamepad FX Lua script for Assetto Corsa that delivers stable, speed-sensitive steering with self-steer correction for confident high-speed and traffic driving.

**Architecture:** Four Lua files with clear responsibilities — `config.lua` owns all tunable constants, `lib.lua` owns all math primitives, `assist.lua` assembles the pipeline and owns the CSP entry points, and `debug.lua` provides a live telemetry overlay for tuning. The pipeline processes inputs in a fixed order each frame: deadzone/gamma → speed scale → slip limit → self-steer → smooth → clamp → output.

**Tech Stack:** LuaJIT (5.2 compatibility mode), CSP Gamepad FX API (v0.2.0+), no external dependencies.

**Note on testing:** There is no Lua unit test runner available for CSP scripts. Verification for each task is done in-game via `ac.log()` on startup and `ac.debug()` at runtime. Each task's verification section specifies exactly what to look for.

**Install path (deploy after each task for in-game testing):**
```
assettocorsa/extension/lua/joypad-assist/MyGamepadFX/
```

**Dev path (source of truth):**
```
c:/Users/Tom/Videos/AC Gamepad FX project/MyGamepadFX/
```

---

## File Map

| File | Responsibility |
|------|---------------|
| `MyGamepadFX/manifest.ini` | CSP plugin declaration — name and version |
| `MyGamepadFX/config.lua` | All tunable constants in one place; no logic |
| `MyGamepadFX/lib.lua` | Math primitives: deadzone, gamma, lerp, expSmooth, speedScale |
| `MyGamepadFX/assist.lua` | CSP entry points (`script.update`, `script.reset`); pipeline assembly only — no raw constants, no math primitives |
| `MyGamepadFX/debug.lua` | Live telemetry overlay via `ac.debug()`; require'd optionally; not in release builds |

---

## Task 1: Scaffold — manifest, config, and passthrough skeleton

**Files:**
- Create: `MyGamepadFX/manifest.ini`
- Create: `MyGamepadFX/config.lua`
- Create: `MyGamepadFX/lib.lua`
- Create: `MyGamepadFX/assist.lua`

- [ ] **Step 1.1: Create manifest.ini**

```ini
[ABOUT]
NAME = MyGamepadFX
VERSION = 1.0
```

- [ ] **Step 1.2: Create config.lua**

```lua
-- config.lua — all tunable constants; no logic lives here
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

return CFG
```

- [ ] **Step 1.3: Create lib.lua with stubs only (implementations come in Task 2)**

```lua
-- lib.lua — math primitives; no constants, no CSP API calls
local M = {}

function M.applyDeadzone(v, dz)   return v end  -- stub
function M.applyGamma(v, gamma)   return v end  -- stub
function M.lerp(a, b, t)          return a end  -- stub
function M.expSmooth(current, target, smooth, dt) return target end  -- stub
function M.speedScale(speedKmh, cfg) return 1.0 end  -- stub

return M
```

- [ ] **Step 1.4: Create assist.lua as a direct passthrough**

```lua
-- assist.lua — pipeline assembly and CSP entry points
-- Pipeline (execution order):
--   raw input → deadzone/gamma → speed scale → slip limit (driver only) → + self-steer → smooth → clamp → output

local CFG = require('config')
local lib = require('lib')

local steerOut = 0.0

function script.update(dt)
    local car     = ac.getCar(0)
    local gamepad = ac.getGamepad(0)
    if not car or not gamepad then return end

    -- Raw passthrough — replaced stage by stage in later tasks
    local steer = gamepad.axes[1] or 0.0
    local gas   = gamepad.axes[3] or 0.0
    local brake = gamepad.axes[4] or 0.0

    ac.setSteer(math.clamp(steer,  -1.0, 1.0))
    ac.setGas(  math.clamp(gas,     0.0, 1.0))
    ac.setBrake(math.clamp(brake,   0.0, 1.0))
end

function script.reset()
    steerOut = 0.0
end
```

- [ ] **Step 1.5: Copy to AC install path and load a session**

Verify: script loads without errors. Check the CSP log (`assettocorsa/logs/csp.log`) — no Lua errors. Steering responds (it's raw passthrough at this point, same as no script).

- [ ] **Step 1.6: Commit**

```bash
git add MyGamepadFX/
git commit -m "feat: scaffold manifest, config, lib stubs, and passthrough assist"
```

---

## Task 2: Implement math helpers in lib.lua

**Files:**
- Modify: `MyGamepadFX/lib.lua`

- [ ] **Step 2.1: Implement all helpers**

Replace the entire contents of `lib.lua`:

```lua
-- lib.lua — math primitives; no constants, no CSP API calls
local M = {}

-- Deadzone with rescale: removes drift and maps the remaining range to [0,1]
-- with no discontinuity at the deadzone edge.
function M.applyDeadzone(v, dz)
    local sign = v >= 0 and 1 or -1
    local abs  = math.abs(v)
    if abs < dz then return 0.0 end
    return sign * (abs - dz) / (1.0 - dz)
end

-- Gamma curve: compresses center travel for precision, preserves sign.
function M.applyGamma(v, gamma)
    local sign = v >= 0 and 1 or -1
    return sign * math.abs(v) ^ gamma
end

-- Linear interpolation, t clamped to [0,1].
function M.lerp(a, b, t)
    t = math.clamp(t, 0.0, 1.0)
    return a + (b - a) * t
end

-- Frame-rate independent exponential smoother.
-- smooth = blend weight at 60 fps. Identical feel at any frame rate.
function M.expSmooth(current, target, smooth, dt)
    local alpha = 1.0 - (1.0 - smooth) ^ (dt * 60.0)
    return M.lerp(current, target, alpha)
end

-- Speed-sensitive steering ratio.
-- Returns a multiplier in [SPEED_SCALE_MIN, 1.0].
function M.speedScale(speedKmh, cfg)
    local t = math.clamp(
        (speedKmh - cfg.SPEED_SCALE_START) / (cfg.SPEED_SCALE_END - cfg.SPEED_SCALE_START),
        0.0, 1.0
    )
    return M.lerp(1.0, cfg.SPEED_SCALE_MIN, t)
end

return M
```

- [ ] **Step 2.2: Add a startup log to verify helpers load**

At the bottom of `assist.lua`, inside `script.reset()` (it fires on session start), add:

```lua
function script.reset()
    steerOut = 0.0
    ac.log("[GamepadFX] lib loaded — expSmooth(0,1,0.12,1/60)=" ..
        tostring(lib.expSmooth(0, 1, 0.12, 1/60)))
    -- Expected output: ~0.12 (blend weight at exactly 60 fps)
end
```

- [ ] **Step 2.3: Deploy and verify**

Load a session. In `csp.log` look for the `[GamepadFX]` line.

Expected value: `expSmooth(0,1,0.12,1/60)=0.12` (or very close — floating point).

If you see a Lua error instead, check that `require('lib')` resolves correctly (file must be in the same folder as `assist.lua`).

- [ ] **Step 2.4: Remove the startup log**

Delete the `ac.log` line added in Step 2.2 — it was verification only.

- [ ] **Step 2.5: Commit**

```bash
git add MyGamepadFX/lib.lua MyGamepadFX/assist.lua
git commit -m "feat: implement math helpers in lib.lua (deadzone, gamma, lerp, expSmooth, speedScale)"
```

---

## Task 3: Deadzone and gamma curve (Design Goal 2)

**Files:**
- Modify: `MyGamepadFX/assist.lua`

- [ ] **Step 3.1: Replace raw steer read with deadzone + gamma**

In `script.update`, replace:
```lua
local steer = gamepad.axes[1] or 0.0
```
With:
```lua
local raw   = gamepad.axes[1] or 0.0
local steer = lib.applyGamma(lib.applyDeadzone(raw, CFG.DEADZONE), CFG.GAMMA)
```

- [ ] **Step 3.2: Deploy and verify**

Load a session. With the stick at rest (center), `steer` should produce exactly 0.0 — no drift. Slowly move the stick: the first ~8% of travel should feel dead, then the response should build smoothly. Near full deflection the stick should reach full authority.

To make this visible without debug.lua, temporarily add to `script.update` after the steer calculation:
```lua
ac.setMessage("Steer", tostring(math.floor(steer * 100) / 100))
```
Remove after verifying. (The in-game toast fires every frame so it will flash — that's fine for a quick check.)

- [ ] **Step 3.3: Commit**

```bash
git add MyGamepadFX/assist.lua
git commit -m "feat: apply deadzone and gamma curve to steering input"
```

---

## Task 4: Speed-sensitive steering ratio (Design Goal 1)

**Files:**
- Modify: `MyGamepadFX/assist.lua`

- [ ] **Step 4.1: Apply speed scale after gamma**

In `script.update`, after the gamma line, add:
```lua
steer = steer * lib.speedScale(car.speedKmh, CFG)
```

The full steer derivation now reads:
```lua
local raw   = gamepad.axes[1] or 0.0
local steer = lib.applyGamma(lib.applyDeadzone(raw, CFG.DEADZONE), CFG.GAMMA)
steer = steer * lib.speedScale(car.speedKmh, CFG)
```

- [ ] **Step 4.2: Deploy and verify**

Test in two conditions:
1. **Parked / slow (< 60 km/h):** Full stick deflection should produce full lock.
2. **Highway speed (150+ km/h):** Same full stick should produce noticeably less lock (~35% of full). The transition between these should be gradual — no sudden stiffening.

- [ ] **Step 4.3: Commit**

```bash
git add MyGamepadFX/assist.lua
git commit -m "feat: add speed-sensitive steering ratio"
```

---

## Task 5: Dynamic steering limit reduction (Design Goal 5)

**Files:**
- Modify: `MyGamepadFX/assist.lua`

- [ ] **Step 5.1: Compute front slip and apply slip limit clamp**

This clamp applies to the driver input only — self-steer (added next task) is not subject to it.

In `script.update`, after the speed scale line, add:

```lua
-- Slip limit: clamp driver input range when front tires are sliding
local avgFrontSlip = (car.wheelsSlip[0] + car.wheelsSlip[1]) * 0.5
local slipFactor   = math.clamp(
    (avgFrontSlip - CFG.SLIP_LIMIT_START) / CFG.SLIP_LIMIT_RANGE,
    0.0, 1.0
)
local steerLimit   = lib.lerp(1.0, CFG.SLIP_LIMIT_MIN, slipFactor)
local driverInput  = math.clamp(steer, -steerLimit, steerLimit)
```

Replace the local variable name going forward: `steer` → `driverInput` is now the clamped driver contribution. `avgFrontSlip` and `steerLimit` are kept as locals — they're reused in Task 6 and debug.lua respectively.

- [ ] **Step 5.2: Update the setSteer call to use driverInput**

```lua
ac.setSteer(math.clamp(driverInput, -1.0, 1.0))
```

(Self-steer isn't added yet — `driverInput` is still the full signal for now.)

- [ ] **Step 5.3: Deploy and verify**

Drive onto a straight, build speed to ~120 km/h, then brake hard while turning. When the front slides, the steering should feel like it hits a soft wall — the stick can't push further into the slide. No effect during normal cornering within grip limits.

- [ ] **Step 5.4: Commit**

```bash
git add MyGamepadFX/assist.lua
git commit -m "feat: add dynamic steering limit reduction on front slip"
```

---

## Task 6: Self-steer / countersteer force (Design Goal 4)

**Files:**
- Modify: `MyGamepadFX/assist.lua`

- [ ] **Step 6.1: Add self-steer correction after slip limit clamp**

After the `driverInput` computation, add:

```lua
-- Self-steer: simulate caster return-to-center + oscillation damping
-- Added AFTER slip limit — correction force is not subject to driver input restrictions
local selfSteer = -avgFrontSlip * CFG.COUNTERSTEER_GAIN
               -  car.steer    * CFG.COUNTERSTEER_DAMP
local combined  = driverInput + selfSteer
```

- [ ] **Step 6.2: Update setSteer to use combined**

```lua
ac.setSteer(math.clamp(combined, -1.0, 1.0))
```

- [ ] **Step 6.3: Deploy and verify**

Two checks:
1. **Straight-line stability:** At speed on a straight with no input, the car should track without wandering. The self-steer term should produce near-zero output when there is no slip and the steering angle is near zero.
2. **Slide recovery:** Induce a rear slide (power oversteer). The car should naturally steer into the correction. Release the stick — the car should recover without spinning.

If the car develops a tank-slapper (oscillates left-right rapidly), `COUNTERSTEER_DAMP` in `config.lua` is too low. Raise it before lowering `COUNTERSTEER_GAIN`.

- [ ] **Step 6.4: Commit**

```bash
git add MyGamepadFX/assist.lua
git commit -m "feat: add self-steer countersteer force with oscillation damping"
```

---

## Task 7: Steering smoothing (Design Goal 3)

**Files:**
- Modify: `MyGamepadFX/assist.lua`

- [ ] **Step 7.1: Replace direct setSteer with smoothed output**

The smoothing wraps the combined signal. `steerOut` persists across frames (it's the module-level local declared at the top of `assist.lua`).

Replace:
```lua
ac.setSteer(math.clamp(combined, -1.0, 1.0))
```

With:
```lua
steerOut = lib.expSmooth(steerOut, combined, CFG.STEER_SMOOTH, dt)
ac.setSteer(math.clamp(steerOut, -1.0, 1.0))
```

- [ ] **Step 7.2: Verify reset clears steerOut**

`script.reset()` already sets `steerOut = 0.0`. Confirm it's still there — a leftover value from the previous session would cause a jerk on the first frame.

- [ ] **Step 7.3: Deploy and verify**

Two checks:
1. **No jerk on session load:** Load a session. At the start line, the steering should not kick to one side. (If it does, `steerOut` was not reset.)
2. **Smoothing feel:** Make a sharp stick flick at speed. The steering output should follow the input with a slight rounding — it should not feel laggy or disconnected, but sharp spikes should be absorbed. At 60 fps the blend weight is 12% per frame; at 165 fps it auto-adjusts to ~4.7% per frame for the same effective feel.

- [ ] **Step 7.4: Commit**

```bash
git add MyGamepadFX/assist.lua
git commit -m "feat: add frame-rate independent exponential steering smoothing"
```

---

## Task 8: debug.lua telemetry overlay

**Files:**
- Create: `MyGamepadFX/debug.lua`
- Modify: `MyGamepadFX/assist.lua`

The debug module is enabled by uncommenting one `require` line in `assist.lua`. It is never committed in an enabled state.

- [ ] **Step 8.1: Create debug.lua**

```lua
-- debug.lua — live telemetry overlay for tuning; not for release builds
-- Enable by uncommenting: local dbg = require('debug') in assist.lua
-- Disable by commenting it out again — do not ship with this active

local D = {}

-- Call once per frame from script.update, passing the pipeline's internal values.
function D.draw(values)
    -- values = { raw, afterDZ, afterGamma, driverInput, steerLimit,
    --            avgFrontSlip, selfSteer, combined, steerOut, speedKmh }
    ac.debug("1 raw_input",      values.raw)
    ac.debug("2 after_dz_gamma", values.afterGamma)
    ac.debug("3 steer_limit",    values.steerLimit)
    ac.debug("4 driver_input",   values.driverInput)
    ac.debug("5 self_steer",     values.selfSteer)
    ac.debug("6 combined",       values.combined)
    ac.debug("7 steer_out",      values.steerOut)
    ac.debug("8 front_slip",     values.avgFrontSlip)
    ac.debug("9 speed_kmh",      values.speedKmh)
end

return D
```

- [ ] **Step 8.2: Add optional debug hook to assist.lua**

At the top of `assist.lua`, after the existing `require` lines, add (commented out):

```lua
-- local dbg = require('debug')   -- uncomment for tuning overlay; never ship enabled
```

At the end of `script.update`, just before the `ac.setSteer` call, add (also commented out):

```lua
-- if dbg then dbg.draw({
--     raw          = raw,
--     afterGamma   = steer,         -- value after deadzone + gamma + speed scale, before slip clamp
--     steerLimit   = steerLimit,
--     driverInput  = driverInput,
--     selfSteer    = selfSteer,
--     combined     = combined,
--     steerOut     = steerOut,
--     avgFrontSlip = avgFrontSlip,
--     speedKmh     = car.speedKmh,
-- }) end
```

- [ ] **Step 8.3: Deploy and verify the overlay**

Temporarily uncomment both lines (`local dbg` and the `dbg.draw` block). Load a session. The CSP debug overlay (visible in-game if the debug overlay is enabled in CSP settings) should show all 9 labeled values updating live each frame.

Confirm that at rest with no input: `raw_input ≈ 0`, `steer_limit = 1.0`, `self_steer ≈ 0`, `steer_out` converging to 0.

Re-comment both lines after verifying.

- [ ] **Step 8.4: Commit (with debug disabled)**

```bash
git add MyGamepadFX/debug.lua MyGamepadFX/assist.lua
git commit -m "feat: add debug telemetry overlay (disabled by default)"
```

---

## Task 9: Final state — complete assist.lua

**Files:**
- Modify: `MyGamepadFX/assist.lua`

After all tasks, `assist.lua` should look exactly like this. This step is a clean-up pass to confirm nothing leaked in during development.

- [ ] **Step 9.1: Verify assist.lua matches this final form**

```lua
-- assist.lua — pipeline assembly and CSP entry points
-- Pipeline (execution order):
--   raw input → deadzone/gamma → speed scale → slip limit (driver only) → + self-steer → smooth → clamp → output

local CFG = require('config')
local lib = require('lib')
-- local dbg = require('debug')   -- uncomment for tuning overlay; never ship enabled

local steerOut = 0.0

function script.update(dt)
    local car     = ac.getCar(0)
    local gamepad = ac.getGamepad(0)
    if not car or not gamepad then return end

    -- 1. Raw input → deadzone → gamma → speed scale
    local raw   = gamepad.axes[1] or 0.0
    local steer = lib.applyGamma(lib.applyDeadzone(raw, CFG.DEADZONE), CFG.GAMMA)
    steer = steer * lib.speedScale(car.speedKmh, CFG)

    -- 2. Slip limit — clamps driver input only; self-steer is added after
    local avgFrontSlip = (car.wheelsSlip[0] + car.wheelsSlip[1]) * 0.5
    local slipFactor   = math.clamp(
        (avgFrontSlip - CFG.SLIP_LIMIT_START) / CFG.SLIP_LIMIT_RANGE,
        0.0, 1.0
    )
    local steerLimit  = lib.lerp(1.0, CFG.SLIP_LIMIT_MIN, slipFactor)
    local driverInput = math.clamp(steer, -steerLimit, steerLimit)

    -- 3. Self-steer: caster return-to-center + damping (not subject to slip limit)
    local selfSteer = -avgFrontSlip * CFG.COUNTERSTEER_GAIN
                   -  car.steer    * CFG.COUNTERSTEER_DAMP
    local combined  = driverInput + selfSteer

    -- 4. Smooth combined signal (driver + self-steer together — avoids correction lag)
    steerOut = lib.expSmooth(steerOut, combined, CFG.STEER_SMOOTH, dt)

    -- if dbg then dbg.draw({
    --     raw          = raw,
    --     afterGamma   = steer,
    --     steerLimit   = steerLimit,
    --     driverInput  = driverInput,
    --     selfSteer    = selfSteer,
    --     combined     = combined,
    --     steerOut     = steerOut,
    --     avgFrontSlip = avgFrontSlip,
    --     speedKmh     = car.speedKmh,
    -- }) end

    -- 5. Write to physics
    ac.setSteer(math.clamp(steerOut,               -1.0, 1.0))
    ac.setGas(  math.clamp(gamepad.axes[3] or 0.0,  0.0, 1.0))
    ac.setBrake(math.clamp(gamepad.axes[4] or 0.0,  0.0, 1.0))
end

function script.reset()
    steerOut = 0.0
end
```

- [ ] **Step 9.2: Confirm no raw constants appear in assist.lua**

Search `assist.lua` for any numeric literals. Acceptable: `0.0`, `1.0`, `-1.0` (range clamp bounds — these are API contracts, not tuning values). Not acceptable: any deadzone, gamma, gain, or scale value inline. All tuning values must come from `CFG`.

- [ ] **Step 9.3: Final deploy and end-to-end verification**

Run through this checklist in-game:

| Check | Pass condition |
|-------|---------------|
| Script loads clean | No errors in `csp.log` |
| Center deadzone | Stick at rest → no steering drift |
| Gamma feel | First ~8% of travel dead; builds smoothly after |
| Speed scaling | Full stick at 150 km/h gives ~35% lock vs full lock at rest |
| Slip limit | Hard front-lock braking → stick hits soft resistance, not full lock |
| Self-steer | Releasing stick mid-slide → car self-corrects without spinning |
| No oscillation | `COUNTERSTEER_DAMP / COUNTERSTEER_GAIN` ≥ 0.60 (0.30/0.45 = 0.67 ✓) |
| Session reset | Load new session → no jerk at start |
| Frame rate | Behavior consistent whether AC runs at 60 fps or 165 fps |

- [ ] **Step 9.4: Commit**

```bash
git add MyGamepadFX/
git commit -m "feat: complete v1 pipeline — all 6 design goals implemented"
```

---

## Tuning Reference (from spec)

After the implementation is stable, tune in this order:

1. **`DEADZONE`** — find the minimum that eliminates stick drift at rest
2. **`GAMMA`** — adjust center feel; raise if too twitchy at speed
3. **`SPEED_SCALE_MIN`** — how much authority at top speed
4. **`COUNTERSTEER_GAIN`** — raise until slides self-correct; back off if it fights the driver
5. **`COUNTERSTEER_DAMP`** — raise if oscillation appears; keep ≥ 60% of GAIN
6. **`SLIP_LIMIT_MIN`** — how aggressively to reduce authority at peak slip
7. **`STEER_SMOOTH`** — last; only adjust if the output feels laggy or too sharp
