# RESEARCH_FINDINGS.md — CSP Live Config App Research

**Date:** June 2026
**Decision:** Build v1.0 app — config UI only. AC pass-through settings cannot be automated.

---

## Question: Can CSP Lua apps write to CONTROLS.INI?

**Answer: NO.**

Three independent lines of evidence from the CSP SDK (`acc-lua-sdk`):

1. **Explicit SDK annotation.** `ac.INIConfig.controlsConfig()` in `ac_extras_ini.d.lua` carries the comment *"Returned file can't be saved."* The same read-only annotation applies to carData, carConfig, trackData, trackConfig, onlineExtras, raceConfig, and videoConfig — all protected system configs.

2. **No public write API.** The `io` module only documents `io.scanDir`. There is no `io.save`, `io.write`, or `io.open` in the public Lua API. `ac.INIConfig:save()` internally calls `io.save` (a C++ function) — but only for configs loaded via `ac.INIConfig.load(filename)`, not for the protected config accessors.

3. **`ac.storage` sandboxed.** The only reliable per-script persistence API saves to `Documents\Assetto Corsa\cfg\extension\state\lua\` — scoped per script type, inaccessible cross-script.

## What the App CAN Do

- Show all 20 MyGamepadFX parameters as live sliders and checkboxes
- Write `live_cfg.ini` to the joypad-assist script's own folder via `ac.INIConfig:save()`
- The joypad-assist script polls that file every 0.5s and overrides CFG values in memory
- Persist the last-used slider values across sessions (same file)

## What the App CANNOT Do

- Read or write `CONTROLS.INI`
- Auto-configure Speed Sensitivity, Steering Gamma, Steering Filter, Steering Deadzone
- Replace the manual pre-flight checklist in README.md and INSTALLATION.md

## Communication Architecture

```
App (extension/apps/lua/MyGamepadFX_Config/)
  → writes live_cfg.ini to extension/lua/joypad-assist/MyGamepadFX/
    via ac.getFolder(ac.FolderID.ExtLua) .. '/joypad-assist/MyGamepadFX/live_cfg.ini'

Script (extension/lua/joypad-assist/MyGamepadFX/)
  → polls live_cfg.ini every 0.5s
    via ac.getFolder(ac.FolderID.ScriptOrigin) .. '/live_cfg.ini'
  → overrides CFG values with live values when file present and parseable
  → uses static config.lua defaults when file absent (first run, no app open)
```

Both paths resolve to the same file on disk. The script's folder is the canonical location — the app reaches into it via the known extension/lua/ root.

## Build Decision

**v1.0: Build the app.** All 20 CFG parameters exposed as live sliders. Changes apply within 0.5s while driving. No AC settings automation — that requires a CM plugin (v1.1 or later, different technology stack).

The manual pre-flight checklist in README/INSTALLATION.md remains mandatory and unchanged.
