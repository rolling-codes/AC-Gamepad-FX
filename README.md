# AC Gamepad FX

A [Custom Shaders Patch](https://acstuff.ru/patch/) Gamepad FX Lua script for Assetto Corsa. Intercepts raw gamepad inputs every physics frame, runs them through a layered correction pipeline, and writes the results back before they reach the physics engine. No game files modified — works in single-player and online.

**Primary goal:** confident, stable control at high speed and in traffic.

---

## ⚠️ MANDATORY: AC Controls Pre-Flight Checklist

**This script will not work correctly unless AC's built-in controls are set to pass-through mode. Do this before driving.**

In Content Manager: **Settings** (gear icon) → **Assetto Corsa** → **Controls** tab

1. **Input Method** → `Gamepad`
2. **Speed Sensitivity** → `0%`
3. **Steering Speed** → `100%`
4. **Steering Gamma** → `100%`
5. **Steering Filter** → `0%`
6. **Steering Deadzone** → `0%`

> **Why this matters:** This script owns all steering correction. If AC also applies gamma, deadzone, or filter, the effects stack — your gamma curve gets applied twice, your deadzone gets applied twice, and the result is unusable. There is no way for the script to detect or fix this automatically; you must set these manually.

For step-by-step screenshots showing each setting in Content Manager, see [INSTALLATION.md](INSTALLATION.md).

If steering feels broken after installing, the AC settings are the first thing to check. See [Troubleshooting.md](Troubleshooting.md).

---

## What it does

Five corrections applied in order every frame:

**1. Deadzone & gamma curve**
Removes stick drift with a clean rescaled deadzone (no discontinuity at the edge). A configurable gamma exponent compresses center travel for precision at speed while preserving full authority at full deflection.

**2. Speed-sensitive steering ratio**
At low speed, full stick = full lock. Above a configurable speed threshold, the same input produces progressively less lock — down to 35% at highway speed. Transition is a smooth curve, never a hard cutoff.

**3. Dynamic steering limit reduction**
When front tires slide past the optimal grip angle, the available steering range shrinks proportionally. Prevents the instinct to jab the stick past the point where the tires can respond.

**4. Self-steer / countersteer force**
Simulates caster-angle return-to-center. Reads average front wheel slip and applies a corrective force opposing it, plus a damping term proportional to the current steer angle to kill oscillation. Applied after the slip limit — so the correction is never artificially restricted by the driver input clamp.

**5. Frame-rate independent smoothing**
A per-frame exponential lerp on the final output kills single-frame spikes. Blend weight is defined at 60 fps and auto-scales at any frame rate — identical feel at 60 fps or 165 fps.

---

## Installation

Copy the `MyGamepadFX/` folder to:

```
assettocorsa/extension/lua/joypad-assist/MyGamepadFX/
```

Activate in **Content Manager → Settings → Custom Shaders Patch → Gamepad FX → MyGamepadFX**.

Complete step-by-step installation with screenshots: [INSTALLATION.md](INSTALLATION.md).

---

## File structure

```
MyGamepadFX/
├── manifest.ini   — CSP plugin declaration
├── config.lua     — all tunable constants (edit this to tune feel)
├── lib.lua        — math helpers: deadzone, gamma, lerp, expSmooth, speedScale, logOnce
├── assist.lua     — pipeline assembly and CSP entry points
└── debug.lua      — live telemetry overlay (disabled by default)
```

All tuning is in `config.lua`. `assist.lua` contains no raw constants.

---

## Tuning

Edit `MyGamepadFX/config.lua`:

```lua
DEADZONE          = 0.08   -- stick deadzone radius; find minimum that kills drift
GAMMA             = 1.6    -- >1 compresses center, raises for more precision at speed
STEER_SMOOTH      = 0.12   -- blend weight at 60 fps; raise for more lag, lower for sharper
SPEED_SCALE_START = 60     -- km/h where scaling begins
SPEED_SCALE_END   = 180    -- km/h where scaling reaches minimum
SPEED_SCALE_MIN   = 0.35   -- authority at top speed (0.35 = 35% of full lock)
COUNTERSTEER_GAIN = 0.45   -- self-steer strength; raise until slides self-correct
COUNTERSTEER_DAMP = 0.30   -- must stay >= COUNTERSTEER_GAIN * 0.6 to prevent oscillation
SLIP_LIMIT_START  = 0.15   -- front slip level where limit kicks in
SLIP_LIMIT_RANGE  = 0.25   -- slip range for full reduction
SLIP_LIMIT_MIN    = 0.70   -- minimum authority at peak slip

GAS_DEADZONE      = 0.01   -- removes trigger drift at rest
GAS_GAMMA         = 1.1    -- slight curve for smooth power delivery
BRAKE_DEADZONE    = 0.01   -- avoids unintended light brake from trigger drift
BRAKE_GAMMA       = 1.0    -- linear brake (no curve)

HAPTICS_ENABLED   = false  -- set true if your controller supports trigger rumble
```

**Tuning order:** deadzone → gamma → speed scale → countersteer gain → damp → slip limit → smoothing last.

If the car oscillates (tank-slapper), raise `COUNTERSTEER_DAMP` before touching `COUNTERSTEER_GAIN`.

---

## Debug overlay

Enable the live telemetry overlay during tuning by uncommenting two lines in `assist.lua`:

```lua
local dbg = require('debug')   -- line 1: uncomment this
```

And inside `script.update`, uncomment the `dbg.draw({...})` block. Also set in `config.lua`:

```lua
DEBUG_MODE = true
```

Shows raw input, post-scale value, steer limit, driver input, self-steer contribution, combined signal, smoothed output, front slip, speed, actual steer angle, and frame time — updated every frame via `ac.debug()`.

**Never ship with this enabled.**

---

## Requirements

- Assetto Corsa with [Custom Shaders Patch](https://acstuff.ru/patch/) v0.2.0 or later
- A gamepad (tested layout: left stick X = steering, right trigger = throttle, left trigger = brake)

---

## Troubleshooting

See [Troubleshooting.md](Troubleshooting.md) for a full Q&A covering common symptoms.

**Quick reference:**
- Steering twitchy/spikey → AC Steering Gamma not at 100%
- Dead zone at center → AC Steering Deadzone not at 0%
- Laggy feel → AC Steering Filter not at 0%
- Car drifts at center → raise `DEADZONE` in config.lua
- Car oscillates → raise `COUNTERSTEER_DAMP` in config.lua
