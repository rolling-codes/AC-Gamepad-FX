-- assist.lua — pipeline assembly and CSP entry points
-- Pipeline (execution order):
--   raw input → calibrate → deadzone/gamma → speed scale
--   → slip classify → understeer clamp → slip limit
--   + yaw damp (oversteer boost, load transfer)
--   → adaptive smooth → clamp → output

local CFG = require('config')
local lib = require('lib')
-- local dbg = require('debug')   -- uncomment for tuning overlay; never ship enabled

local steerOut              = 0.0
local frameCount            = 0
local firstFrameDiagnostics = false

local LIVE_CFG_PATH = ac.getFolder(ac.FolderID.ScriptOrigin) .. '/live_cfg.ini'
local liveCfgTimer  = 0.5

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
    CFG.STEER_SMOOTH_MIN   = ini:get('PARAMS', 'STEER_SMOOTH_MIN',   CFG.STEER_SMOOTH_MIN)
    CFG.SPEED_SCALE_START  = ini:get('PARAMS', 'SPEED_SCALE_START',  CFG.SPEED_SCALE_START)
    CFG.SPEED_SCALE_END    = ini:get('PARAMS', 'SPEED_SCALE_END',    CFG.SPEED_SCALE_END)
    CFG.SPEED_SCALE_MIN    = ini:get('PARAMS', 'SPEED_SCALE_MIN',    CFG.SPEED_SCALE_MIN)
    CFG.YAW_GAIN           = ini:get('PARAMS', 'YAW_GAIN',           CFG.YAW_GAIN)
    CFG.YAW_DAMP           = ini:get('PARAMS', 'YAW_DAMP',           CFG.YAW_DAMP)
    CFG.SLIP_DELTA_THRESH  = ini:get('PARAMS', 'SLIP_DELTA_THRESH',  CFG.SLIP_DELTA_THRESH)
    CFG.US_REDUCTION       = ini:get('PARAMS', 'US_REDUCTION',       CFG.US_REDUCTION)
    CFG.OS_BOOST           = ini:get('PARAMS', 'OS_BOOST',           CFG.OS_BOOST)
    CFG.SLIP_LIMIT_START   = ini:get('PARAMS', 'SLIP_LIMIT_START',   CFG.SLIP_LIMIT_START)
    CFG.SLIP_LIMIT_RANGE   = ini:get('PARAMS', 'SLIP_LIMIT_RANGE',   CFG.SLIP_LIMIT_RANGE)
    CFG.SLIP_LIMIT_MIN     = ini:get('PARAMS', 'SLIP_LIMIT_MIN',     CFG.SLIP_LIMIT_MIN)
    CFG.GAS_DEADZONE       = ini:get('PARAMS', 'GAS_DEADZONE',       CFG.GAS_DEADZONE)
    CFG.GAS_GAMMA          = ini:get('PARAMS', 'GAS_GAMMA',          CFG.GAS_GAMMA)
    CFG.BRAKE_DEADZONE     = ini:get('PARAMS', 'BRAKE_DEADZONE',     CFG.BRAKE_DEADZONE)
    CFG.BRAKE_GAMMA        = ini:get('PARAMS', 'BRAKE_GAMMA',        CFG.BRAKE_GAMMA)
    CFG.TC_ENABLED         = ini:get('PARAMS', 'TC_ENABLED',         CFG.TC_ENABLED)
    CFG.TC_SLIP_THRESHOLD  = ini:get('PARAMS', 'TC_SLIP_THRESHOLD',  CFG.TC_SLIP_THRESHOLD)
    CFG.TC_MAX_REDUCTION   = ini:get('PARAMS', 'TC_MAX_REDUCTION',   CFG.TC_MAX_REDUCTION)
    CFG.HAPTICS_ENABLED    = ini:get('PARAMS', 'HAPTICS_ENABLED',    CFG.HAPTICS_ENABLED)
    CFG.HAPTICS_SLIP_START = ini:get('PARAMS', 'HAPTICS_SLIP_START', CFG.HAPTICS_SLIP_START)
    CFG.HAPTICS_SLIP_MAX   = ini:get('PARAMS', 'HAPTICS_SLIP_MAX',   CFG.HAPTICS_SLIP_MAX)
    CFG.HAPTICS_STRENGTH   = ini:get('PARAMS', 'HAPTICS_STRENGTH',   CFG.HAPTICS_STRENGTH)
    CFG.DEBUG_MODE         = ini:get('PARAMS', 'DEBUG_MODE',         CFG.DEBUG_MODE)
end

function script.update(dt)
    frameCount = frameCount + 1

    liveCfgTimer = liveCfgTimer - dt
    if liveCfgTimer <= 0 then
        liveCfgTimer = 0.5
        applyLiveCfg()
    end

    local car = ac.getCar(0)
    if not car then
        if frameCount > 2 then
            lib.logOnce("car_nil", "[MyGamepadFX] ERROR: ac.getCar(0) returned nil after startup. Check CM \xE2\x86\x92 Settings \xE2\x86\x92 Custom Shaders Patch \xE2\x86\x92 Gamepad FX \xE2\x86\x92 confirm Active and MyGamepadFX selected.")
        end
        steerOut = 0.0
        return
    end

    local gamepad = ac.getGamepad(0)
    if not gamepad then
        lib.logOnce("gamepad_nil", "[MyGamepadFX] ERROR: No gamepad detected. Check CM \xE2\x86\x92 Settings \xE2\x86\x92 Assetto Corsa \xE2\x86\x92 Controls \xE2\x86\x92 Input Method = Gamepad.")
        steerOut = 0.0
        return
    end

    if dt <= 0 or dt > 0.1 then return end

    if dt > 0.05 then
        lib.logOnce("frame_drop", "[MyGamepadFX] Warning: frame time " .. string.format("%.0f", dt * 1000) .. "ms exceeds 50ms threshold. Smoothing may be affected.")
    end

    if not firstFrameDiagnostics then
        ac.log("[MyGamepadFX] === Startup Diagnostic ===")
        ac.log("[MyGamepadFX] Axes: [0]=" .. string.format("%.2f", gamepad.axes[0] or 0)
            .. " [1]=" .. string.format("%.2f", gamepad.axes[1] or 0)
            .. " [3]=" .. string.format("%.2f", gamepad.axes[3] or 0)
            .. " [4]=" .. string.format("%.2f", gamepad.axes[4] or 0))
        ac.log("[MyGamepadFX] Expected: axes[1]=steer, axes[3]=throttle, axes[4]=brake")
        ac.log("[MyGamepadFX] yawRate available: " .. tostring(car.localAngularVelocity ~= nil))
        firstFrameDiagnostics = true
    end

    -- 1. Raw input -> calibrate -> deadzone -> gamma -> speed scale
    local raw        = gamepad.axes[1] or 0.0
    local calibrated = lib.normalizeAxis(raw, CFG.STEER_CENTER, CFG.STEER_RANGE)
    local steer      = lib.applyGamma(lib.applyDeadzone(calibrated, CFG.DEADZONE), CFG.GAMMA)
    steer = steer * lib.speedScale(car.speedKmh, CFG)

    -- 2. Slip classify: front vs rear
    local slip = lib.stageSlipClassify(car, CFG)

    -- 3. Slip limit — clamps driver input; tightened by understeer factor
    local slipFactor  = math.clamp((slip.front - CFG.SLIP_LIMIT_START) / CFG.SLIP_LIMIT_RANGE, 0.0, 1.0)
    local steerLimit  = lib.lerp(1.0, CFG.SLIP_LIMIT_MIN, slipFactor)
    steerLimit = steerLimit * lib.lerp(1.0, 1.0 - CFG.US_REDUCTION, slip.understeer)
    local driverInput = math.clamp(steer, -steerLimit, steerLimit)

    -- 4. Yaw damping + oversteer boost (replaces self-steer)
    local yaw           = lib.yawRate(car)
    local heavyBraking  = (car.brake or 0) > 0.4 and car.speedKmh > 30
    local effectiveDamp = heavyBraking and CFG.YAW_DAMP * 0.6 or CFG.YAW_DAMP
    local yawCorrection = lib.stageYawDamp(yaw, car.steer, CFG, slip.oversteer, effectiveDamp)
    local combined      = driverInput + yawCorrection

    -- 5. Adaptive smooth: faster at the limit, smooth when settled
    local avgSlip   = (slip.front + slip.rear) * 0.5
    local stability = 1.0 - math.clamp((math.abs(yaw) * 0.5 + avgSlip) / 0.4, 0.0, 1.0)
    steerOut = lib.stageAdaptiveSmooth(steerOut, combined, stability, CFG, dt)

    -- 5.5. Haptic feedback
    if CFG.HAPTICS_ENABLED then
        local slipIntensity = math.clamp(
            (avgSlip - CFG.HAPTICS_SLIP_START) / (CFG.HAPTICS_SLIP_MAX - CFG.HAPTICS_SLIP_START),
            0.0, 1.0
        )
        ac.setTriggerRumble(0, slipIntensity * CFG.HAPTICS_STRENGTH)
    end

    -- 6. Write to physics
    local rawGas   = lib.normalizeTrigger(gamepad.axes[3] or 0.0, CFG.GAS_REST,   CFG.GAS_MAX)
    local rawBrake = lib.normalizeTrigger(gamepad.axes[4] or 0.0, CFG.BRAKE_REST, CFG.BRAKE_MAX)
    local gasOut   = math.clamp(lib.applyGamma(lib.applyDeadzone(rawGas, CFG.GAS_DEADZONE), CFG.GAS_GAMMA), 0.0, 1.0)
    if CFG.TC_ENABLED then
        local spin      = lib.stageWheelspin(car)
        local reduction = math.clamp((spin - CFG.TC_SLIP_THRESHOLD) / 0.2, 0.0, 1.0)
        gasOut = gasOut * (1.0 - reduction * CFG.TC_MAX_REDUCTION)
    end
    ac.setSteer(math.clamp(steerOut, -1.0, 1.0))
    ac.setGas(gasOut)
    ac.setBrake(math.clamp(lib.applyGamma(lib.applyDeadzone(rawBrake, CFG.BRAKE_DEADZONE), CFG.BRAKE_GAMMA), 0.0, 1.0))
end

function script.reset()
    steerOut      = 0.0
    frameCount    = 0
    liveCfgTimer  = 0.5
    -- firstFrameDiagnostics intentionally not reset — log axes once per game start, not per session
end
