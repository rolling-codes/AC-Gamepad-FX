# Installation Guide — AC Gamepad FX

---

## Prerequisites

- **Assetto Corsa** (any version)
- **Custom Shaders Patch (CSP)** v0.2.0 or later — [download at acstuff.ru/patch](https://acstuff.ru/patch/)
- **Content Manager** (recommended) — [download at assettocorsa.club/content-manager.html](https://assettocorsa.club/content-manager.html)

---

## Step 1: Install the Script

Copy the `MyGamepadFX/` folder into your Assetto Corsa installation:

```
assettocorsa/extension/lua/joypad-assist/MyGamepadFX/
```

The folder must contain these four files:

```
MyGamepadFX/
├── manifest.ini
├── config.lua
├── lib.lua
├── assist.lua
└── debug.lua
```

If the `joypad-assist/` folder doesn't exist, create it.

---

## Step 2: Configure AC Controls (REQUIRED)

**This step must be completed before driving. Skipping it causes broken steering feel that the script cannot detect or correct.**

Navigate to: **Content Manager → Settings (gear icon, top right) → Assetto Corsa → Controls tab**

Set each value exactly as listed:

| Setting | Required Value | Notes |
|---|---|---|
| Input Method | Gamepad | Must be Gamepad, not Keyboard/Wheel |
| Speed Sensitivity | 0% | Script handles this |
| Steering Speed | 100% | Set to maximum |
| Steering Gamma | 100% | Critical — script applies its own gamma |
| Steering Filter | 0% | Script applies its own smoothing |
| Steering Deadzone | 0% | Script applies its own deadzone |

[Screenshot: CM Controls tab — Input Method dropdown set to "Gamepad"]

[Screenshot: CM Controls tab — Speed Sensitivity slider at 0%]

[Screenshot: CM Controls tab — Steering Gamma slider at 100%]

[Screenshot: CM Controls tab — Steering Filter and Deadzone both at 0%]

**Why these values?** The script takes over all steering correction. If AC applies gamma or deadzone and the script applies them again, they stack — the result is unusable double-processing that cannot be fixed from inside the script.

---

## Step 3: Activate in CSP

In Content Manager: **Settings → Custom Shaders Patch → Gamepad FX**

1. Check that **"Active"** is enabled
2. Select **"MyGamepadFX"** from the plugin dropdown

[Screenshot: CM CSP settings showing Gamepad FX section with MyGamepadFX selected]

---

## Step 4: First Drive

1. Launch a session (Monaco pitlane is ideal — open space, low traffic)
2. Open the CM log: **View → Show Log** (or press `Ctrl+L`)
3. Confirm you see this line at startup:
   ```
   [MyGamepadFX] Axis map — axes[0]=... axes[1]=... axes[3]=... axes[4]=...
   ```
4. Check the axis values: with the controller at rest, all four should be near `0.0` or `0.00`
5. Move the left stick — `axes[1]` should change
6. Press the right trigger — `axes[3]` should change
7. Drive around and confirm steering, throttle, and brake respond correctly

If you see `[MyGamepadFX] ERROR:` in the log, see [Troubleshooting.md](Troubleshooting.md).

---

## Troubleshooting

| Symptom | First check |
|---|---|
| Steering twitchy or spikey | Steering Gamma not at 100% — redo Step 2 |
| Unresponsive center / large dead zone | Steering Deadzone not at 0% — redo Step 2 |
| Steering feels delayed/laggy | Steering Filter not at 0% — redo Step 2 |
| No `[MyGamepadFX]` lines in log | CSP not active or wrong plugin — redo Step 3 |
| Car drifts without input | Raise `DEADZONE` in config.lua |
| Car oscillates (tank-slapper) | Raise `COUNTERSTEER_DAMP` in config.lua |

Full troubleshooting guide: [Troubleshooting.md](Troubleshooting.md)
