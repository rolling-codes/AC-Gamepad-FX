# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Hard Rule — Skill Execution Policy

Skills are lazy-loaded. Nothing runs, reads, or costs tokens unless its trigger condition is explicitly matched by the current task.

- Never pre-load a skill speculatively
- Never keep a skill active between tasks
- Read a SKILL.md once per invocation, then release it
- If no trigger matches, no skill loads
- Routing is stateless and costs nothing — only the matched skill's read costs tokens

This applies to every skill, every subagent, every session. No exceptions.

## Hard Rule — Response Behavior

No AI patterns. Ever.

No formulaic transitions. No symmetrical structure. No generic phrasing. No predictable rhythm. Vary sentence length naturally.

If multiple choice → output only the correct letter.
If short answer → output only the direct answer.
No explanation unless explicitly asked.
No conclusions. No summaries. No filler.

---

## What This Is

A [Custom Shaders Patch](https://acstuff.ru/patch/) Gamepad FX Lua script for Assetto Corsa. Runs in **LuaJIT** (5.2 compatibility mode) via CSP — no standard Lua toolchain, no package manager, no build step.

## Deployment & Testing

There is no build system. "Deploying" means copying the folder:

```
MyGamepadFX/ → assettocorsa/extension/lua/joypad-assist/MyGamepadFX/
```

Testing requires launching Assetto Corsa with the script active. Activate in **Content Manager → Settings → Custom Shaders Patch → Gamepad FX → MyGamepadFX**.

AC Controls must have Speed Sensitivity, Steering Gamma, Steering Filter, and Steering Deadzone all at 0%, Steering Speed at 100% — the script owns all of these.

## Architecture

Four files, strict separation of concerns:

| File | Role |
|---|---|
| `manifest.ini` | CSP plugin declaration (name, version) |
| `config.lua` | All tunable constants, nothing else — returns a `CFG` table |
| `lib.lua` | Pure math helpers (`applyDeadzone`, `applyGamma`, `lerp`, `expSmooth`, `speedScale`) — no `ac.*` calls, no constants |
| `assist.lua` | Pipeline assembly and the two CSP entry points |
| `debug.lua` | Optional live telemetry overlay via `ac.debug()` — disabled by default |

**Pipeline in `assist.lua` (execution order):**

```
raw input → applyDeadzone → applyGamma → speedScale
         → slip limit clamp (driver input only)
         → + selfSteer (not subject to slip clamp)
         → expSmooth (combined signal)
         → clamp → ac.setSteer / ac.setGas / ac.setBrake
```

## CSP Entry Points

```lua
function script.update(dt)   -- called every physics frame; dt = seconds
function script.reset()      -- called on session reset; must clear all persistent state
```

`ac.getCar(0)` returns nil on the first frame — always nil-guard before reading car properties. `dt <= 0` guard also required.

## Debug Overlay

Uncomment in `assist.lua` to enable:

```lua
local dbg = require('debug')
```

And uncomment the `dbg.draw({...})` call block. Shows all pipeline intermediate values via `ac.debug()`. Never ship with this enabled.

## Key CSP API

```lua
ac.getGamepad(0)           -- gamepad.axes[1] = left stick X (steering)
ac.getCar(0)               -- car.speedKmh, car.wheelsSlip[0..3], car.steer
ac.setSteer(v)             -- [-1, 1]
ac.setGas(v)               -- [0, 1]
ac.setBrake(v)             -- [0, 1]
math.clamp(v, min, max)    -- CSP extension, not vanilla LuaJIT
```

## Tuning

Edit `config.lua` only — `assist.lua` contains no raw constants. Tuning order: deadzone → gamma → speed scale → countersteer gain → damp → slip limit → smoothing last.

`COUNTERSTEER_DAMP` must stay ≥ `COUNTERSTEER_GAIN × 0.6` or the car develops tank-slappers.

Frame-rate independence: smoothing uses `expSmooth` with `(1 - smooth)^(dt * 60)` — never use a bare lerp constant directly against `dt`.
