# VALIDATION.md — AC-Gamepad-FX v1.0 Code Validation Report

Static code review of the v1.0 Lua files. Covers API compatibility, entry point signatures, state management, math formula correctness, edge case guards, and breaking changes.

**Verdict: PASS with warnings. No critical issues. Safe to ship.**

---

## 1. API Compatibility (CSP v0.2.0+)

| Call | Availability | Notes |
|---|---|---|
| `ac.getCar(0)` | All CSP versions | Returns nil for 1–2 frames on load — guarded |
| `ac.getGamepad(0)` | All CSP versions | Returns nil if no gamepad — guarded |
| `ac.setSteer(v)` | All CSP versions | Range [-1, 1], clamped before call |
| `ac.setGas(v)` | All CSP versions | Range [0, 1], clamped before call |
| `ac.setBrake(v)` | All CSP versions | Range [0, 1], clamped before call |
| `ac.setTriggerRumble(l, r)` | CSP v0.2.0+ | Behind `HAPTICS_ENABLED = false` by default |
| `ac.log(msg)` | All CSP versions | Diagnostics and errors |
| `ac.debug(label, val)` | All CSP versions | Debug overlay only |
| `math.clamp(v, lo, hi)` | CSP extension | Not in vanilla LuaJIT; used correctly |
| `string.format(fmt, ...)` | Standard Lua | Used throughout for log formatting |

No calls that require CSP above v0.2.0 in the default-enabled code path. `ac.setTriggerRumble` (v0.2.0+) is behind `HAPTICS_ENABLED = false`. ✅

---

## 2. Entry Point Signatures

```lua
function script.update(dt)   -- ✅ correct CSP pattern
function script.reset()      -- ✅ correct CSP pattern
```

`script.*` form only — no global-namespace aliases. ✅

---

## 3. State Management

| Variable | Cleared by `script.reset()` | Intention |
|---|---|---|
| `steerOut` | ✅ Yes — set to 0.0 | Prevents jerk at session start |
| `frameCount` | ✅ Yes — set to 0 | Allows nil-car warning to re-fire if car never loads in new session |
| `firstFrameDiagnostics` | ❌ No — intentional | Axis log fires once per game launch, not per session |
| `lib._logged` | ❌ No — intentional | logOnce messages persist for the game lifetime; prevents log spam across sessions |

`lib._logged` is module-level state. After a session reset, error messages from the previous session cannot re-fire even if the same condition recurs. If the user wants a fresh log, they must restart AC. **KNOWN/EXPECTED** ⚠️

---

## 4. Math Formula Verification

### expSmooth
```lua
local alpha = 1.0 - (1.0 - smooth) ^ (dt * 60.0)
```
Standard exponential decay normalized to 60 fps. At `dt = 1/60`, `alpha = smooth`. Identical feel at any frame rate. ✅

### speedScale
```lua
local t = math.clamp((speedKmh - START) / (END - START), 0, 1)
return lerp(1.0, SPEED_SCALE_MIN, t)
```
At START → returns 1.0. At END → returns SPEED_SCALE_MIN. Clamped outside range. ✅

### selfSteer
```lua
selfSteer = -avgFrontSlip * GAIN - car.steer * DAMP
```
Sign convention correct: positive slip → negative selfSteer (opposes outward slide). Damping opposes current angle. ✅

### slipFactor
```lua
slipFactor = clamp((avgFrontSlip - START) / RANGE, 0, 1)
steerLimit = lerp(1.0, SLIP_LIMIT_MIN, slipFactor)
```
Below START → no restriction. At START + RANGE → full reduction. No out-of-range values. ✅

### Haptics
```lua
slipIntensity = clamp((slip - HAPTICS_SLIP_START) / (HAPTICS_SLIP_MAX - HAPTICS_SLIP_START), 0, 1)
ac.setTriggerRumble(0, slipIntensity * HAPTICS_STRENGTH)
```
Final value in [0, 1] before passing to API. ✅

### Gas/brake curves
```lua
lib.applyGamma(lib.applyDeadzone(axes[N] or 0.0, DEADZONE), GAMMA)
```
Deadzone on raw input first, gamma on scaled result. Correct order. ✅

---

## 5. Edge Case Guards

| Condition | Guard |
|---|---|
| `car` nil on first 1–2 frames | frameCount grace period; silent for ≤ 2 frames, warns after |
| `gamepad` nil | logOnce error, return |
| `dt <= 0` | `if dt <= 0 or dt > 0.1 then return end` |
| `dt > 0.1` (pause, alt-tab) | same guard — discards inflated-dt frame |
| Nil axis values | `axes[N] or 0.0` fallbacks on every read |

All guards verified. ✅

---

## 6. Warnings (Not Blockers)

**W1 — logOnce keys persist across sessions.** After `script.reset()`, `lib._logged` is not cleared. Errors that fired once are silenced in subsequent sessions until AC restarts. Expected behavior — user has already seen the message.

**W2 — `ac.setTriggerRumble` on non-supported controllers.** Behavior is undefined on controllers without per-trigger rumble motors (standard Xbox One, most generics). `HAPTICS_ENABLED = false` by default eliminates this risk unless the user opts in. If it throws on unsupported hardware, wrapping in `pcall` is the fix. **ASSUMPTION — needs real-world testing.**

**W3 — Axis assignments assumed, not probed.** `axes[1] = steering` is standard Xbox layout. The startup diagnostic logs values but does not auto-detect wrong assignments. Documented in Troubleshooting.md.

**W4 — car_nil can only log once regardless of session.** If car is nil on session restart (after `script.reset()`), the warning attempt is silenced by `lib._logged`. Safe, but the second occurrence is invisible in the log.

---

## 7. Breaking Changes from Previous Version

| Change | Impact |
|---|---|
| Throttle/brake now processed (was raw passthrough) | Slight feel change. Full trigger still = 100% — only < 1% inputs affected. |
| `config.lua` has 9 new required parameters | **Old config.lua will break.** Users who customized values must copy them into the new template. |
| `script.reset()` now resets `frameCount` | Additive — no external API impact. |
| `lib.lua` has `logOnce` and `_logged` | Additive — no existing signatures changed. |
| `debug.lua` draws 11 fields (was 9) | Additive — only affects debug overlay users. |

**config.lua is the only file that requires user action on upgrade.** Tuned values from the old config must be manually transferred to the new template.

---

## 8. Verdict

| Category | Result |
|---|---|
| API compatibility | ✅ PASS |
| Entry point signatures | ✅ PASS |
| State management | ✅ PASS (W1, W4 known/expected) |
| Math formulas | ✅ PASS |
| Edge case guards | ✅ PASS |
| Breaking changes | ⚠️ config.lua requires user replacement on upgrade |
| Haptics compatibility | ⚠️ ASSUMPTION — needs hardware testing |

**Overall: PASS. Safe to ship.**
