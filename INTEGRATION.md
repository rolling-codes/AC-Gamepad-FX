# INTEGRATION.md — AC-Gamepad-FX v1.0 Integration Guide

Step-by-step guide for applying the v1.0 changes. Written for a solo developer working alone, no CI pipeline, no automated build step — changes go straight from editor to the game folder.

---

## Files Modified in v1.0

| File | What Changed |
|---|---|
| `MyGamepadFX/config.lua` | 9 new parameters added: GAS_DEADZONE, GAS_GAMMA, BRAKE_DEADZONE, BRAKE_GAMMA, HAPTICS_ENABLED, HAPTICS_SLIP_START, HAPTICS_SLIP_MAX, HAPTICS_STRENGTH, DEBUG_MODE |
| `MyGamepadFX/lib.lua` | Added `logOnce(key, message)` function and module-level `_logged` table |
| `MyGamepadFX/debug.lua` | Expanded telemetry with `carSteer` and `dt_ms` fields |
| `MyGamepadFX/assist.lua` | Full pipeline rewrite: first-frame diagnostics, error logging, frame drop warning, throttle/brake curves, haptic trigger rumble, corrected pipeline order |

---

## Suggested Commit Order

Apply and commit files in this order. The goal is to keep the working tree in a functional state for as long as possible — each commit is usable on its own until assist.lua lands.

**1. config.lua**

Add the 9 new parameters to the config table. This is a pure data change. Until assist.lua is updated, the new keys are never read, so there is no behavior change and no risk of breakage.

```
feat: add v1.0 config parameters (throttle/brake curves, haptics, debug mode)
```

**2. lib.lua**

Add `logOnce`. This is purely additive — no existing function is modified. The new function is not called by anything until assist.lua is updated.

```
feat: add logOnce helper to lib.lua
```

**3. debug.lua**

Expand the telemetry overlay with `carSteer` and `dt_ms`. The debug overlay is opt-in (requires uncommenting in assist.lua and setting DEBUG_MODE = true), so this change has no runtime effect until explicitly enabled.

```
feat: expand debug overlay with carSteer and dt_ms fields
```

**4. assist.lua**

This is the behavior-changing commit. The pipeline now processes throttle/brake through deadzone/gamma, adds self-steer, slip limit, smoothing, haptics, error logging, and diagnostics. Commit this last to minimize the window between "old config" and "new pipeline."

```
feat: v1.0 pipeline rewrite (diagnostics, throttle/brake curves, haptics, error logging)
```

**5. Docs (one commit)**

README.md, INSTALLATION.md, Troubleshooting.md, TESTING.md, VALIDATION.md, INTEGRATION.md — documentation only, no code. Can be one commit or split by file type.

```
docs: v1.0 documentation (testing, validation, integration, troubleshooting)
```

---

## How to Apply

### Step 1 — Back Up

Before touching any files, copy the current `MyGamepadFX/` folder to a safe location.

```
MyGamepadFX-backup-v0x\
```

If anything goes wrong after the update, restore from this backup to return to the last known working state.

### Step 2 — Locate the Target Folder

The script folder lives inside the AC installation:

```
[AC install]\extension\lua\joypad-assist\MyGamepadFX\
```

Common paths:
- Steam: `C:\Program Files (x86)\Steam\steamapps\common\assettocorsa\extension\lua\joypad-assist\MyGamepadFX\`
- Non-Steam: wherever AC is installed, same subfolder structure.

### Step 3 — Copy New Files

Copy the updated files from the repository to the target folder. If prompted to overwrite, confirm for all four files:

- `config.lua`
- `lib.lua`
- `debug.lua`
- `assist.lua`

Do not copy `TESTING.md`, `VALIDATION.md`, or `INTEGRATION.md` to the AC folder — they are dev docs only.

### Step 4 — Launch AC via Content Manager

Do not launch AC directly. Always launch through Content Manager so that CSP hooks load correctly.

### Step 5 — Open the CM Log

Before loading a race, open the log pane: **View → Show Log** (bottom toolbar in Content Manager). This streams log output in real time. You can also view `Documents\Assetto Corsa\logs\log.txt` after the session if you miss live output.

### Step 6 — Load a Race

Load any session — practice, quickrace, or hotlap. A simple venue with open space makes observation easier. Monaco pitlane recommended for low-speed steering feel testing.

### Step 7 — Check for Startup Diagnostic

Within the first second of the session loading, the log should contain:

```
[MyGamepadFX] === Startup Diagnostic ===
[MyGamepadFX] Axes: [0]=0.00 [1]=0.00 [3]=0.00 [4]=0.00
[MyGamepadFX] Expected: axes[1]=steer, axes[3]=throttle, axes[4]=brake
```

If this does not appear, CSP is not running the script. Check: **Settings → Custom Shaders Patch → Gamepad FX → Active = enabled, Script = MyGamepadFX**.

### Step 8 — Drive for 2–3 Minutes

Drive in a clear area. Test steering, throttle, brake responsiveness. Induce a little oversteer to verify self-steer is active. No specific lap required — this is a feel check, not a timed test.

### Step 9 — Check Log for Errors

After driving, scan the log for any lines containing `ERROR` or `Warning`:

- `[MyGamepadFX] ERROR:` — something is wrong (nil car, nil gamepad). Follow the in-message instructions.
- `[MyGamepadFX] Warning: frame time` — frame drop logged. Occasional is fine; consistent means CPU or physics load issue (not a script bug).

No error or warning lines = clean integration.

---

## First-Drive Validation Checklist

Run through these after completing Steps 4–9 above. Each item confirms a specific v1.0 feature is working.

- [ ] Startup Diagnostic appears in CM log within first second of session load
- [ ] Axis values at rest are near 0.00 for all four axes (±0.05 acceptable for analog drift)
- [ ] Moving left stick changes steering angle proportionally — no dead gaps beyond the deadzone
- [ ] Deadzone feels clean: stick at center produces zero output, no drift
- [ ] Speed scaling is noticeable: full stick lock at rest is visibly more than full stick lock at 100+ km/h
- [ ] Throttle responds to right trigger; no response to trigger touches lighter than ~2% travel
- [ ] Brake responds to left trigger; same sub-2% deadzone behavior
- [ ] No `[MyGamepadFX] ERROR` lines in log
- [ ] No `[MyGamepadFX] Warning` lines in log (or only one frame-drop warning at most during load)

---

## Troubleshooting

### Startup Diagnostic does not appear

1. Confirm CSP is installed and Gamepad FX is set to Active + MyGamepadFX in CM settings.
2. Confirm `MyGamepadFX/manifest.ini` is present in the script folder.
3. Check the log for a Lua error (CSP will log script parse errors). A common cause is a syntax error introduced during file copy.

### Script stops working after update but worked before

Most likely cause: config.lua was not updated. If assist.lua references `CFG.GAS_DEADZONE` but the old config.lua does not have that key, Lua will error and the script will stop. Verify that all 9 new parameters are present in config.lua.

### Steering feels over-smooth or under-smooth compared to before

assist.lua now applies smoothing to the combined signal (driver input + self-steer), whereas the previous version may have applied it differently. Adjust `STEER_SMOOTH` in config.lua. Start from the default and move in 0.05 steps.

### Throttle/brake feel different

v1.0 now runs throttle and brake through deadzone and gamma curves. With default values this is a very small change, but if you had a custom prior version that passed them raw, the feel difference may be noticeable. Adjust `GAS_GAMMA`, `GAS_DEADZONE`, `BRAKE_GAMMA`, `BRAKE_DEADZONE` in config.lua to match your preference. Setting GAS_GAMMA = 1.0 and GAS_DEADZONE = 0.0 reproduces the old raw behavior.

### Axis assignments wrong (wrong axis controlling wrong input)

Check the startup diagnostic log to see actual axis values. Move each input one at a time and identify which axis index changes. Update the axis read lines in assist.lua (`gamepad.axes[N]`) to match your controller's actual mapping.

---

*Integration guide for AC-Gamepad-FX v1.0. Apply changes in the order listed, verify the first-drive checklist, then run the full manual test plan in TESTING.md.*
