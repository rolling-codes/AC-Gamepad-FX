# Troubleshooting — AC Gamepad FX

---

**Q: Steering feels twitchy or spikey — small inputs cause large jerky responses**

AC's Steering Gamma is not at 100%. When AC applies its gamma curve and the script applies its own, you get gamma applied twice. The result is an overly aggressive exponential curve that makes center inputs feel violent.

Fix: Content Manager → Settings → Assetto Corsa → Controls → **Steering Gamma = 100%**

---

**Q: There's a large dead zone at center — the car barely responds to small stick inputs**

AC's Steering Deadzone is not at 0%. Double deadzone means the stick has to travel further before anything happens, killing precision.

Fix: Content Manager → Settings → Assetto Corsa → Controls → **Steering Deadzone = 0%**

---

**Q: Steering feels delayed or laggy**

AC's Steering Filter is not at 0%. The script applies its own frame-rate-independent smoothing (`STEER_SMOOTH`). Adding AC's filter on top creates compounded lag.

Fix: Content Manager → Settings → Assetto Corsa → Controls → **Steering Filter = 0%**

---

**Q: Steering authority changes erratically with speed in a way that feels wrong**

AC's Speed Sensitivity is not at 0%. Double speed scaling produces non-linear, unexpected behavior through the speed range.

Fix: Content Manager → Settings → Assetto Corsa → Controls → **Speed Sensitivity = 0%**

---

**Q: Can the script auto-fix these AC settings for me?**

No. CSP's Lua sandbox runs without filesystem access — the script cannot read or write `Documents\Assetto Corsa\cfg\controls.ini`. There is no API to query or modify AC's control settings from inside a Gamepad FX script. This is a deliberate CSP design decision, not a missing feature that will be added later. The settings must be configured manually.

---

**Q: The script doesn't seem to be running at all — steering is completely unaffected**

Check these in order:

1. **CSP active?** Content Manager → Settings → Custom Shaders Patch — confirm "Custom Shaders Patch" is enabled and on v0.2.0 or later.
2. **Gamepad FX active?** Content Manager → Settings → Custom Shaders Patch → Gamepad FX — confirm "Active" is checked and "MyGamepadFX" is selected in the dropdown.
3. **Script loaded?** Open the CM log (View → Show Log). After loading a race, you should see `[MyGamepadFX] Axis map —` within the first few lines. If you see `[MyGamepadFX] ERROR:`, read what it says — the message includes where to look.
4. **Files in place?** Confirm the `MyGamepadFX/` folder is at `assettocorsa/extension/lua/joypad-assist/MyGamepadFX/` and contains `manifest.ini`, `config.lua`, `lib.lua`, `assist.lua`, `debug.lua`.

---

**Q: Car drifts at center without touching the stick**

Controller stick drift — the physical axis isn't returning to a true zero. Raise `DEADZONE` in `config.lua` until drift stops. Start at `0.10`, go to `0.12` if needed. Don't go above `0.15` or small corrections become imprecise.

---

**Q: Car oscillates back and forth (tank-slapper effect)**

`COUNTERSTEER_DAMP` is too low relative to `COUNTERSTEER_GAIN`. The self-steer system overcorrects and then overcorrects the overcorrection.

Fix: raise `COUNTERSTEER_DAMP` in `config.lua`. Rule: DAMP must stay at or above `COUNTERSTEER_GAIN × 0.6`. If GAIN is `0.45`, DAMP must be at least `0.27`. Raise DAMP before lowering GAIN.

---

**Q: Works fine on Xbox controller but feels wrong on PlayStation / generic USB gamepad**

Axis assignments are not guaranteed across controller types. This script assumes:
- `axes[1]` = left stick X (steering)
- `axes[3]` = right trigger (throttle)
- `axes[4]` = left trigger (brake)

On some controllers or with Steam Input enabled, these assignments may differ. Check the CM log after loading a race — look for the `[MyGamepadFX] Axis map —` line. It shows values for axes 0, 1, 3, and 4 at rest. Move each input and reload to see which axis changes. If `axes[1]` doesn't change when you move the left stick, the axis mapping on your controller is different from the default assumption.

There is currently no in-config way to remap axes — you would need to change the axis index in `assist.lua` directly.

---

**Q: I enabled haptics (`HAPTICS_ENABLED = true`) but the controller doesn't vibrate**

Trigger rumble (`ac.setTriggerRumble`) requires CSP v0.2.0 or later and a controller that supports trigger motors. Standard Xbox One controllers do not have trigger motors; Xbox Series X|S controllers do. Generic USB controllers typically do not. If your controller doesn't support it, the call is a no-op — no error, no vibration.

Also confirm the car is actually generating front wheel slip. Haptics only fire above `HAPTICS_SLIP_START` (default 0.3). In normal driving on a dry track, you may not reach this threshold. Push harder through corners or induce oversteer deliberately to test it.
