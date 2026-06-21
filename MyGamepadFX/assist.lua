-- assist.lua — pipeline assembly and CSP entry points
-- Pipeline (execution order):
--   raw input → calibrate → deadzone/gamma → speed scale → slip limit (driver only) → + self-steer → smooth → clamp → output

local CFG = require('config')
local lib = require('lib')
-- local dbg = require('debug')   -- uncomment for tuning overlay; never ship enabled

local steerOut              = 0.0
local frameCount            = 0
local firstFrameDiagnostics = false

-- Live config: the MyGamepadFX Config app writes this file; we poll it every 0.5s.
-- When absent (no app open yet), CFG defaults from config.lua are used unchanged.
local LIVE_CFG_PATH = ac.getFolder(ac.FolderID.ScriptOrigin) .. '/live_cfg.ini'
local liveCfgTimer  = 0.5  -- start first check after 0.5s to avoid startup noise

local function applyLiveCfg()
    local ok, ini = pcall(ac.INIConfig.load, LIVE_CFG_PATH)
    if not ok or not ini then return end
    CFG.STEER_CENTER       = ini:get('PARAMS', 'STEER_CENTER',       CFG.STEER_CENTER)
    CFG.STEER_RANGE        = ini:get('PARAMS', 'STEER_RANGE',        CFG.STEER_RANGE)
    CFG.GAS_REST           = ini:get('PARAMS', 'GAS_REST',           CFG.GAS_REST)
    CFG.GAS_MAX            = ini:get('PARAMS', 'GAS_MAX',            CFG.GAS_MAX)
    CFG.BRAKE_REST         = ini:get('PARAMS', 'BRAKE_REST',         CFG.BRAKE_REST)
    CFG.BRAKE_MAX          = ini:get('PARAMS', 'BRAKE_MAX',          CFG.BRAKE_MAX)
    CFG.DEADZONE           = ini:get('PARAMS', 'DEADZONE',           CFG.DEADZONE)
    CFG.GAMMA              = ini:get('PARAMS', 'GAMMA',              CFG.GAMMA)
    CFG.STEER_SMOOTH       = ini:get('PARAMS', 'STEER_SMOOTH',       CFG.STEER_SMOOTH)
    CFG.SPEED_SCALE_START  = ini:get('PARAMS', 'SPEED_SCALE_START',  CFG.SPEED_SCALE_START)
    CFG.SPEED_SCALE_END    = ini:get('PARAMS', 'SPEED_SCALE_END',    CFG.SPEED_SCALE_END)
    CFG.SPEED_SCALE_MIN    = ini:get('PARAMS', 'SPEED_SCALE_MIN',    CFG.SPEED_SCALE_MIN)
    CFG.COUNTERSTEER_GAIN  = ini:get('PARAMS', 'COUNTERSTEER_GAIN',  CFG.COUNTERSTEER_GAIN)
    CFG.COUNTERSTEER_DAMP  = ini:get('PARAMS', 'COUNTERSTEER_DAMP',  CFG.COUNTERSTEER_DAMP)
    CFG.SLIP_LIMIT_START   = ini:get('PARAMS', 'SLIP_LIMIT_START',   CFG.SLIP_LIMIT_START)
    CFG.SLIP_LIMIT_RANGE   = ini:get('PARAMS', 'SLIP_LIMIT_RANGE',   CFG.SLIP_LIMIT_RANGE)
    CFG.SLIP_LIMIT_MIN     = ini:get('PARAMS', 'SLIP_LIMIT_MIN',     CFG.SLIP_LIMIT_MIN)
    CFG.GAS_DEADZONE       = ini:get('PARAMS', 'GAS_DEADZONE',       CFG.GAS_DEADZONE)
    CFG.GAS_GAMMA          = ini:get('PARAMS', 'GAS_GAMMA',          CFG.GAS_GAMMA)
    CFG.BRAKE_DEADZONE     = ini:get('PARAMS', 'BRAKE_DEADZONE',     CFG.BRAKE_DEADZONE)
    CFG.BRAKE_GAMMA        = ini:get('PARAMS', 'BRAKE_GAMMA',        CFG.BRAKE_GAMMA)
    CFG.HAPTICS_ENABLED    = ini:get('PARAMS', 'HAPTICS_ENABLED',    CFG.HAPTICS_ENABLED)
    CFG.HAPTICS_SLIP_START = ini:get('PARAMS', 'HAPTICS_SLIP_START', CFG.HAPTICS_SLIP_START)
    CFG.HAPTICS_SLIP_MAX   = ini:get('PARAMS', 'HAPTICS_SLIP_MAX',   CFG.HAPTICS_SLIP_MAX)
    CFG.HAPTICS_STRENGTH   = ini:get('PARAMS', 'HAPTICS_STRENGTH',   CFG.HAPTICS_STRENGTH)
    CFG.DEBUG_MODE         = ini:get('PARAMS', 'DEBUG_MODE',         CFG.DEBUG_MODE)
end

function script.update(dt)
    frameCount = frameCount + 1

    -- Poll live_cfg.ini written by the MyGamepadFX Config app (if open)
    liveCfgTimer = liveCfgTimer - dt
    if liveCfgTimer <= 0 then
        liveCfgTimer = 0.5
        applyLiveCfg()
    end

    local car = ac.getCar(0)
    if not car then
        if frameCount > 2 then
            lib.logOnce("car_nil", "[MyGamepadFX] ERROR: ac.getCar(0) returned nil after startup. Check CM → Settings → Custom Shaders Patch → Gamepad FX → confirm Active and MyGamepadFX selected.")
        end
        steerOut = 0.0
        return
    end

    local gamepad = ac.getGamepad(0)
    if not gamepad then
        lib.logOnce("gamepad_nil", "[MyGamepadFX] ERROR: No gamepad detected. Check CM → Settings → Assetto Corsa → Controls → Input Method = Gamepad.")
        steerOut = 0.0
        return
    end

    if dt <= 0 or dt > 0.1 then return end

    if dt > 0.05 then
        lib.logOnce("frame_drop", "[MyGamepadFX] Warning: frame time " .. string.format("%.0f", dt * 1000) .. "ms exceeds 50ms threshold. Smoothing may be affected.")
    end

    -- First-frame axis diagnostics (once per game start, not per session reset)
    if not firstFrameDiagnostics then
        ac.log("[MyGamepadFX] === Startup Diagnostic ===")
        ac.log("[MyGamepadFX] Axes: [0]=" .. string.format("%.2f", gamepad.axes[0] or 0)
            .. " [1]=" .. string.format("%.2f", gamepad.axes[1] or 0)
            .. " [3]=" .. string.format("%.2f", gamepad.axes[3] or 0)
            .. " [4]=" .. string.format("%.2f", gamepad.axes[4] or 0))
        ac.log("[MyGamepadFX] Expected: axes[1]=steer, axes[3]=throttle, axes[4]=brake")
        firstFrameDiagnostics = true
    end

    -- 1. Raw input → calibrate → deadzone → gamma → speed scale
    local raw        = gamepad.axes[1] or 0.0  -- left stick X (steering)
    local calibrated = lib.normalizeAxis(raw, CFG.STEER_CENTER, CFG.STEER_RANGE)
    local steer      = lib.applyGamma(lib.applyDeadzone(calibrated, CFG.DEADZONE), CFG.GAMMA)
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

    -- if dbg and CFG.DEBUG_MODE then dbg.draw({
    --     raw          = raw,
    --     afterScale   = steer,
    --     steerLimit   = steerLimit,
    --     driverInput  = driverInput,
    --     selfSteer    = selfSteer,
    --     combined     = combined,
    --     steerOut     = steerOut,
    --     avgFrontSlip = avgFrontSlip,
    --     speedKmh     = car.speedKmh,
    --     carSteer     = car.steer,
    --     dt           = dt,
    -- }) end

    -- 4.5. Haptic feedback (trigger rumble on front slip)
    if CFG.HAPTICS_ENABLED then
        local slipIntensity = math.clamp(
            (avgFrontSlip - CFG.HAPTICS_SLIP_START) / (CFG.HAPTICS_SLIP_MAX - CFG.HAPTICS_SLIP_START),
            0.0, 1.0
        )
        ac.setTriggerRumble(0, slipIntensity * CFG.HAPTICS_STRENGTH)
    end

    -- 5. Write to physics
    local rawGas   = lib.normalizeTrigger(gamepad.axes[3] or 0.0, CFG.GAS_REST,   CFG.GAS_MAX)
    local rawBrake = lib.normalizeTrigger(gamepad.axes[4] or 0.0, CFG.BRAKE_REST, CFG.BRAKE_MAX)
    ac.setSteer(math.clamp(steerOut, -1.0, 1.0))
    ac.setGas(  math.clamp(lib.applyGamma(lib.applyDeadzone(rawGas,   CFG.GAS_DEADZONE),   CFG.GAS_GAMMA),   0.0, 1.0))
    ac.setBrake(math.clamp(lib.applyGamma(lib.applyDeadzone(rawBrake, CFG.BRAKE_DEADZONE), CFG.BRAKE_GAMMA), 0.0, 1.0))
end

function script.reset()
    steerOut      = 0.0
    frameCount    = 0
    liveCfgTimer  = 0.5
    -- firstFrameDiagnostics intentionally not reset — log axes once per game start, not per session
end
