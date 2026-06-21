# TESTING.md — AC-Gamepad-FX v1.0 Manual Testing Plan

Manual test plan for a single tester with one Xbox controller. All tests require launching Assetto Corsa via Content Manager. No automated test runner exists — this script runs inside the game engine every physics frame.

---

## 1. Pre-Test Setup

Complete all five settings before starting any test below. Wrong values here will produce false failures.

**In Content Manager → Settings → Assetto Corsa → Controls:**
- [ ] Input Method = **Gamepad**
- [ ] Steering Gamma = **1.0** (pass-through; MyGamepadFX applies its own gamma)
- [ ] Steering Deadzone = **0** (pass-through; MyGamepadFX applies its own deadzone)
- [ ] Steering Filter = **0** (pass-through; MyGamepadFX applies its own smoothing)
- [ ] Speed Sensitivity = **0** (pass-through; MyGamepadFX applies its own speed scale)

**In Content Manager → Settings → Custom Shaders Patch → Gamepad FX:**
- [ ] Active = **enabled**
- [ ] Selected script = **MyGamepadFX**

**In MyGamepadFX/config.lua:**
- [ ] `DEBUG_MODE = false` (overlay off for functional tests; enable only in Section 6)
- [ ] `HAPTICS_ENABLED = false` (off for all tests except Section 5)

**Recommended test venue:** Monaco pitlane or any open flat area. The pitlane at low speed lets you isolate steering feel without traction limit interference. For slip/self-steer tests, exit the pitlane onto the track.

---

## 2. Functional Tests — Core Pipeline

### 2.1 Steering Response

**What to do:** Load a race. At rest in the pitlane, move the left stick slowly from center to full left, then full right.

**Expected result:** The front wheels visually track the stick. Movement is smooth and proportional — no dead gap larger than the configured DEADZONE, no snap or jerk.

- [ ] PASS / FAIL

---

### 2.2 Deadzone at Center

**What to do:** Hold the stick as close to dead center as you can. Watch the steering wheel in the cockpit view for 10 seconds.

**Expected result:** Steering wheel does not drift or twitch. Output is exactly zero when stick is within the deadzone band.

- [ ] PASS / FAIL

---

### 2.3 Full Lock Left and Right

**What to do:** Push left stick to full left, hold for 2 seconds. Then full right, hold for 2 seconds.

**Expected result:** Steering reaches maximum lock in both directions. No clipping artifacts (wheel doesn't oscillate at limit). Returns cleanly to center when stick released.

- [ ] PASS / FAIL

---

### 2.4 Throttle Response

**What to do:** In neutral or with clutch held, slowly press the right trigger from 0% to 100%.

**Expected result:** Engine revs rise proportionally. No rev spike at the first mm of trigger travel (GAS_DEADZONE working). Full trigger produces full throttle.

- [ ] PASS / FAIL

---

### 2.5 Brake Response

**What to do:** At low speed (30 km/h), slowly apply the left trigger.

**Expected result:** Car decelerates smoothly. No brake jab at initial trigger contact (BRAKE_DEADZONE working). Full trigger produces full brake pressure.

- [ ] PASS / FAIL

---

### 2.6 Throttle/Brake Deadzone (< 2% trigger press)

**What to do:** Very lightly brush the right trigger — just barely press it, less than what you'd estimate is 2% of full travel. Do the same with the left trigger.

**Expected result:** No throttle or brake response. The car remains stationary (throttle) or decelerates at the same rate (brake). This confirms GAS_DEADZONE and BRAKE_DEADZONE are filtering micro-inputs.

- [ ] PASS / FAIL

---

### 2.7 Speed Scaling

**What to do:** Come to a complete stop. Apply full left stick and note approximate steering angle. Accelerate to 150 km/h on a straight. Apply full left stick again and note steering angle.

**Expected result:** At standstill, full stick produces near-full lock. At 150+ km/h, full stick produces noticeably less lock. The reduction should feel gradual, not a sudden cut.

- [ ] PASS / FAIL
- Note approximate lock reduction at 150 km/h: ____________

---

### 2.8 Self-Steer / Countersteer Resistance

**What to do:** At 80–100 km/h, enter a corner and deliberately over-rotate the car (e.g., lift mid-corner to induce oversteer). Do not countersteer manually — let the script work.

**Expected result:** The car resists spinning further. Self-steer pulls the wheel toward recovery. It should NOT fully self-correct back to straight (CFG.COUNTERSTEER_GAIN is intentionally moderate) — the driver still needs to assist, but the snap is damped.

- [ ] PASS / FAIL
- Note: this is subjective feel. Fail = car spins regardless, or wheel snaps violently in recovery direction.

---

### 2.9 Slip Limit (Hard Cornering)

**What to do:** Push hard into a medium-speed corner at the limit of front grip. Try to add more steering mid-corner.

**Expected result:** Additional steering input beyond the slip limit feels progressively blocked — the wheel moves less than the stick commands. This is distinct from understeer (the physical car understeering vs. the script clamping input).

- [ ] PASS / FAIL
- Note: to distinguish script clamp from car physics, enable DEBUG overlay (Section 6) and watch `steerLimit` value during the corner.

---

### 2.10 Smoothing (No Single-Frame Spike)

**What to do:** While driving at 80 km/h, rapidly flick the left stick from full left to full right and back. Do this 5–6 times quickly.

**Expected result:** Steering follows the input without a single-frame snap. The transition should feel damped — it takes a fraction of a second to reach the new position. No jerk or oscillation.

- [ ] PASS / FAIL

---

## 3. Diagnostic Logging Tests

**How to open the log:** In Content Manager, go to **View → Show Log** (bottom of the CM window). The log updates live. You can also check the AC log file at `Documents\Assetto Corsa\logs\log.txt` after the session.

### 3.1 Startup Diagnostic Header

**What to do:** Load any race session fresh (not resume).

**Expected result:** Log contains:
```
[MyGamepadFX] === Startup Diagnostic ===
```

- [ ] PASS / FAIL

---

### 3.2 Axis Values Logged

**What to do:** Check the log immediately after the diagnostic header.

**Expected result:** Log contains a line like:
```
[MyGamepadFX] Axes: [0]=0.00 [1]=0.00 [3]=0.00 [4]=0.00
```
Values at rest should all be near `0.00` (may vary slightly by controller — small drift up to ±0.05 is normal for analog sticks).

- [ ] PASS / FAIL
- Recorded axis values at rest: [0]=_____ [1]=_____ [3]=_____ [4]=_____

---

### 3.3 Expected Axis Assignment Line

**What to do:** Check log for axis assignment hint.

**Expected result:** Log contains:
```
[MyGamepadFX] Expected: axes[1]=steer, axes[3]=throttle, axes[4]=brake
```

- [ ] PASS / FAIL

---

### 3.4 Steering Axis Change Visible in Log

**What to do:** Exit to menu. Edit config.lua to temporarily set `DEBUG_MODE = true`. Load the race again. Move left stick to full left before and after the diagnostic fires (on next game restart, not session reset).

**Alternative (without restart):** Enable debug overlay (Section 6) and watch the `raw` field change as you move the stick.

**Expected result:** axes[1] value changes from ~0.00 to ~-1.00 (left) when stick is moved. This confirms the steer axis assignment is correct.

- [ ] PASS / FAIL

---

### 3.5 Throttle/Brake Axes Change

**What to do:** Same as 3.4 but press right trigger (axes[3]) and left trigger (axes[4]) while watching the debug overlay or restarting with diagnostic.

**Expected result:** axes[3] rises from 0.00 toward 1.00 on throttle. axes[4] rises from 0.00 toward 1.00 on brake.

- [ ] PASS / FAIL

---

### 3.6 Diagnostic Does Not Repeat on Session Reset

**What to do:** Without restarting the game, exit to menu and reload the session (Session Reset → Restart).

**Expected result:** `[MyGamepadFX] === Startup Diagnostic ===` does NOT appear again in the log. The diagnostic fires once per game launch only. `script.reset()` clears frameCount and steerOut but intentionally does not reset `firstFrameDiagnostics`.

- [ ] PASS / FAIL

---

## 4. Error Condition Tests

### 4.1 Gamepad Disconnected

**What to do:** Unplug the Xbox controller USB before launching a race, then load a session.

**Expected result:** Log contains exactly one line:
```
[MyGamepadFX] ERROR: No gamepad detected. Check CM → Settings → Assetto Corsa → Controls → Input Method = Gamepad.
```
The message appears once, not once per frame.

- [ ] PASS / FAIL

---

### 4.2 logOnce Prevents Spam

**What to do:** Leave the controller unplugged and wait 10 seconds (many frames will have passed).

**Expected result:** The error message above appears only once in the log, regardless of how many frames have elapsed. Searching the log for `[MyGamepadFX] ERROR: No gamepad` should return exactly one match.

- [ ] PASS / FAIL

---

### 4.3 Script Recovers After Reconnect

**What to do:** While AC is running in a session with the gamepad unplugged (error message logged), plug the controller back in.

**Expected result:** On the next frame after reconnect, `ac.getGamepad(0)` returns non-nil and the script resumes normal operation. Steering, throttle, and brake all respond correctly. No crash or freeze.

- [ ] PASS / FAIL
- Note: AC may require you to re-enter the session or re-assign axes depending on OS controller detection timing. This is OS/AC behavior, not a script bug.

---

## 5. Haptic Feedback Tests

**Prerequisites:** A controller with trigger rumble motors (Xbox Elite Series 2 or similar). Standard Xbox One controllers have motor rumble but not per-trigger rumble — `ac.setTriggerRumble` behavior on non-trigger-rumble controllers is **undefined** (may be a no-op). Test results here are ASSUMPTION-flagged.

**Before testing:** Set `HAPTICS_ENABLED = true` in config.lua, then restart AC.

### 5.1 Trigger Rumble on Slip

**What to do:** Drive at the limit of front traction (aggressive corner entry or deliberate lockup under braking).

**Expected result:** Controller vibrates or trigger resists slightly when front tire slip is above HAPTICS_SLIP_START (0.3 by default). Intensity increases as slip increases.

- [ ] PASS / FAIL / NOT TESTABLE (controller lacks trigger motors)

---

### 5.2 Vibration Increases with Slip

**What to do:** Gradually increase cornering speed from moderate to at-limit to beyond-limit.

**Expected result:** Vibration/rumble intensity increases proportionally. At very high slip, intensity is near maximum (clamped to 1.0 * HAPTICS_STRENGTH = 0.8).

- [ ] PASS / FAIL / NOT TESTABLE

---

### 5.3 No Vibration on Straight

**What to do:** Drive a straight at any speed with no wheelspin.

**Expected result:** No haptic feedback. avgFrontSlip below HAPTICS_SLIP_START = 0.3 means slipIntensity clamps to 0.0.

- [ ] PASS / FAIL / NOT TESTABLE

---

### 5.4 Disable Haptics

**What to do:** Set `HAPTICS_ENABLED = false` in config.lua. Restart AC. Repeat the slip scenario from 5.1.

**Expected result:** No vibration at all, even at high slip.

- [ ] PASS / FAIL

---

## 6. Debug Mode Tests

**Before testing:** In assist.lua, uncomment these two lines:
```lua
local dbg = require('debug')
```
and (inside `script.update`, after `steerOut` is written):
```lua
-- dbg.draw({...})
```
Also set `DEBUG_MODE = true` in config.lua. Restart AC.

### 6.1 Overlay Appears

**What to do:** Load a race.

**Expected result:** A telemetry overlay is visible in-game (top-left or configured corner). Numbers are updating each frame — not frozen.

- [ ] PASS / FAIL

---

### 6.2 All 11 Fields Present and Updating

**What to do:** Drive around and observe the overlay. Move the stick, apply throttle/brake, generate slip.

**Expected result:** All 11 fields update each frame:

| Field | Changes When |
|---|---|
| `raw` | Stick moves |
| `afterScale` | Stick moves + speed changes |
| `steerLimit` | Front slip increases/decreases |
| `driverInput` | Stick moves |
| `selfSteer` | Slip or car.steer changes |
| `combined` | Any of the above |
| `steerOut` | Smoothed version of combined |
| `avgFrontSlip` | Cornering or braking |
| `speedKmh` | Acceleration/braking |
| `carSteer` | Actual wheel position |
| `dt_ms` | Every frame (should hover around 8–16ms at 60–120fps) |

- [ ] PASS / FAIL
- Note any fields that appear frozen or missing: ____________

---

### 6.3 Overlay Disappears with DEBUG_MODE = false

**What to do:** Set `DEBUG_MODE = false` in config.lua (or re-comment the dbg lines in assist.lua). Restart AC.

**Expected result:** No overlay visible during the race.

- [ ] PASS / FAIL

---

## 7. Session Reset Tests

### 7.1 No Jerk on Session Reload

**What to do:** Drive normally at 80+ km/h. Exit to main menu (triggers `script.reset()`). Immediately reload the same session.

**Expected result:** At session start, steering output is zero (steerOut was cleared to 0.0 by reset). No jerk or snap in the first second of the new session.

- [ ] PASS / FAIL

---

### 7.2 Diagnostics Do Not Re-Log on Reset

**What to do:** Check the CM log after reloading the session (same game process, not a restart).

**Expected result:** `[MyGamepadFX] === Startup Diagnostic ===` does not appear a second time. `firstFrameDiagnostics` is intentionally preserved across session resets.

- [ ] PASS / FAIL

---

### 7.3 No State Leak Across Sessions (Qualifying → Race)

**What to do:** Start in qualifying. Drive for 2–3 minutes. Transition to race session without restarting AC.

**Expected result:** Race session starts cleanly. steerOut is 0.0 at the start line. No persistent leftover steering bias. frameCount restarts at 0 (confirming reset ran).

- [ ] PASS / FAIL

---

## 8. Edge Cases

### 8.1 Gamepad Briefly Unavailable at Load

**What to do:** Launch AC with the controller plugged in. Just as the race loads (the loading screen is transitioning), briefly unplug and replug the controller.

**Expected result:** Script does not crash. The nil-gamepad path runs for those frames, logging at most one error. Normal operation resumes once `ac.getGamepad(0)` returns non-nil again.

- [ ] PASS / FAIL
- Note: outcome depends on OS timing of USB reconnect. A crash here would show as AC hanging — if that occurs, report it.

---

### 8.2 Pause/Unpause Does Not Produce Jerk

**What to do:** Drive at 100 km/h. Pause the game (ESC). Wait 5 seconds. Unpause.

**Expected result:** No steering jerk on unpause. The `dt > 0.1` guard in assist.lua discards the first frame (which has an inflated dt from pause). Steering resumes smoothly from its pre-pause position.

- [ ] PASS / FAIL

---

### 8.3 Alt-Tab and Return

**What to do:** While in a session, Alt-Tab to desktop. Wait 10 seconds. Return to the game.

**Expected result:** No crash, freeze, or unexpected steering output on return. Similar to 8.2 — the dt spike on return is discarded.

- [ ] PASS / FAIL

---

### 8.4 Online Multiplayer (If Available)

**What to do:** If a test server is accessible, join an online session.

**Expected result:** Script behaves identically to single-player. Multiplayer physics loop runs the same CSP pipeline.

- [ ] PASS / FAIL / SKIPPED (no server access)

---

## 9. AC Settings Validation Table

If behavior seems wrong, check these AC settings before attributing the issue to the script.

| Setting | Wrong Value | Symptom | Correct Value |
|---|---|---|---|
| Steering Gamma | > 1.0 | Steering feels exponential on top of script gamma (double-curved) | 1.0 |
| Steering Deadzone | > 0 | Dead center zone feels larger than configured CFG.DEADZONE | 0 |
| Steering Filter | > 0 | Steering feels over-smoothed or laggy; smooth added twice | 0 |
| Speed Sensitivity | > 0 | Speed scaling effect is stronger than expected (AC and script both reduce at speed) | 0 |

---

*Testing plan for AC-Gamepad-FX v1.0. All tests executable by one person with one Xbox controller. Tests marked NOT TESTABLE require hardware with per-trigger rumble motors.*
