-- app.lua — MyGamepadFX Config UI
-- Writes live_cfg.ini into the joypad-assist script folder.
-- assist.lua polls and applies it within 0.5 seconds while driving.
--
-- Path used by this app:
--   ac.getFolder(ac.FolderID.ExtLua) .. '/joypad-assist/MyGamepadFX/live_cfg.ini'
-- Path used by assist.lua:
--   ac.getFolder(ac.FolderID.ScriptOrigin) .. '/live_cfg.ini'
-- Both resolve to the same file on disk.

local LIVE_CFG_PATH = ac.getFolder(ac.FolderID.ExtLua) .. '/joypad-assist/MyGamepadFX/live_cfg.ini'

-- Defaults mirror config.lua — used when no saved file exists yet
local cfg = {
    DEADZONE           = 0.08,
    GAMMA              = 1.6,
    STEER_SMOOTH       = 0.12,
    SPEED_SCALE_START  = 60,
    SPEED_SCALE_END    = 180,
    SPEED_SCALE_MIN    = 0.35,
    COUNTERSTEER_GAIN  = 0.45,
    COUNTERSTEER_DAMP  = 0.30,
    SLIP_LIMIT_START   = 0.15,
    SLIP_LIMIT_RANGE   = 0.25,
    SLIP_LIMIT_MIN     = 0.70,
    GAS_DEADZONE       = 0.01,
    GAS_GAMMA          = 1.1,
    BRAKE_DEADZONE     = 0.01,
    BRAKE_GAMMA        = 1.0,
    HAPTICS_ENABLED    = false,
    HAPTICS_SLIP_START = 0.3,
    HAPTICS_SLIP_MAX   = 1.0,
    HAPTICS_STRENGTH   = 0.8,
    DEBUG_MODE         = false,
}

local dirty     = false
local saveTimer = 0

local function saveLiveCfg()
    local ok, err = pcall(function()
        local ini = ac.INIConfig.load(LIVE_CFG_PATH)
        ini:set('PARAMS', 'DEADZONE',           cfg.DEADZONE)
        ini:set('PARAMS', 'GAMMA',              cfg.GAMMA)
        ini:set('PARAMS', 'STEER_SMOOTH',       cfg.STEER_SMOOTH)
        ini:set('PARAMS', 'SPEED_SCALE_START',  cfg.SPEED_SCALE_START)
        ini:set('PARAMS', 'SPEED_SCALE_END',    cfg.SPEED_SCALE_END)
        ini:set('PARAMS', 'SPEED_SCALE_MIN',    cfg.SPEED_SCALE_MIN)
        ini:set('PARAMS', 'COUNTERSTEER_GAIN',  cfg.COUNTERSTEER_GAIN)
        ini:set('PARAMS', 'COUNTERSTEER_DAMP',  cfg.COUNTERSTEER_DAMP)
        ini:set('PARAMS', 'SLIP_LIMIT_START',   cfg.SLIP_LIMIT_START)
        ini:set('PARAMS', 'SLIP_LIMIT_RANGE',   cfg.SLIP_LIMIT_RANGE)
        ini:set('PARAMS', 'SLIP_LIMIT_MIN',     cfg.SLIP_LIMIT_MIN)
        ini:set('PARAMS', 'GAS_DEADZONE',       cfg.GAS_DEADZONE)
        ini:set('PARAMS', 'GAS_GAMMA',          cfg.GAS_GAMMA)
        ini:set('PARAMS', 'BRAKE_DEADZONE',     cfg.BRAKE_DEADZONE)
        ini:set('PARAMS', 'BRAKE_GAMMA',        cfg.BRAKE_GAMMA)
        ini:set('PARAMS', 'HAPTICS_ENABLED',    cfg.HAPTICS_ENABLED)
        ini:set('PARAMS', 'HAPTICS_SLIP_START', cfg.HAPTICS_SLIP_START)
        ini:set('PARAMS', 'HAPTICS_SLIP_MAX',   cfg.HAPTICS_SLIP_MAX)
        ini:set('PARAMS', 'HAPTICS_STRENGTH',   cfg.HAPTICS_STRENGTH)
        ini:set('PARAMS', 'DEBUG_MODE',         cfg.DEBUG_MODE)
        ini:save(LIVE_CFG_PATH)
    end)
    if not ok then
        ac.log('[MyGamepadFXConfig] ERROR saving live_cfg.ini: ' .. tostring(err))
    end
end

local function loadSaved()
    local ok, ini = pcall(ac.INIConfig.load, LIVE_CFG_PATH)
    if not ok or not ini then return end
    cfg.DEADZONE           = ini:get('PARAMS', 'DEADZONE',           cfg.DEADZONE)
    cfg.GAMMA              = ini:get('PARAMS', 'GAMMA',              cfg.GAMMA)
    cfg.STEER_SMOOTH       = ini:get('PARAMS', 'STEER_SMOOTH',       cfg.STEER_SMOOTH)
    cfg.SPEED_SCALE_START  = ini:get('PARAMS', 'SPEED_SCALE_START',  cfg.SPEED_SCALE_START)
    cfg.SPEED_SCALE_END    = ini:get('PARAMS', 'SPEED_SCALE_END',    cfg.SPEED_SCALE_END)
    cfg.SPEED_SCALE_MIN    = ini:get('PARAMS', 'SPEED_SCALE_MIN',    cfg.SPEED_SCALE_MIN)
    cfg.COUNTERSTEER_GAIN  = ini:get('PARAMS', 'COUNTERSTEER_GAIN',  cfg.COUNTERSTEER_GAIN)
    cfg.COUNTERSTEER_DAMP  = ini:get('PARAMS', 'COUNTERSTEER_DAMP',  cfg.COUNTERSTEER_DAMP)
    cfg.SLIP_LIMIT_START   = ini:get('PARAMS', 'SLIP_LIMIT_START',   cfg.SLIP_LIMIT_START)
    cfg.SLIP_LIMIT_RANGE   = ini:get('PARAMS', 'SLIP_LIMIT_RANGE',   cfg.SLIP_LIMIT_RANGE)
    cfg.SLIP_LIMIT_MIN     = ini:get('PARAMS', 'SLIP_LIMIT_MIN',     cfg.SLIP_LIMIT_MIN)
    cfg.GAS_DEADZONE       = ini:get('PARAMS', 'GAS_DEADZONE',       cfg.GAS_DEADZONE)
    cfg.GAS_GAMMA          = ini:get('PARAMS', 'GAS_GAMMA',          cfg.GAS_GAMMA)
    cfg.BRAKE_DEADZONE     = ini:get('PARAMS', 'BRAKE_DEADZONE',     cfg.BRAKE_DEADZONE)
    cfg.BRAKE_GAMMA        = ini:get('PARAMS', 'BRAKE_GAMMA',        cfg.BRAKE_GAMMA)
    cfg.HAPTICS_ENABLED    = ini:get('PARAMS', 'HAPTICS_ENABLED',    cfg.HAPTICS_ENABLED)
    cfg.HAPTICS_SLIP_START = ini:get('PARAMS', 'HAPTICS_SLIP_START', cfg.HAPTICS_SLIP_START)
    cfg.HAPTICS_SLIP_MAX   = ini:get('PARAMS', 'HAPTICS_SLIP_MAX',   cfg.HAPTICS_SLIP_MAX)
    cfg.HAPTICS_STRENGTH   = ini:get('PARAMS', 'HAPTICS_STRENGTH',   cfg.HAPTICS_STRENGTH)
    cfg.DEBUG_MODE         = ini:get('PARAMS', 'DEBUG_MODE',         cfg.DEBUG_MODE)
end

-- Restore last-saved values on app open
loadSaved()

local function sliderRow(label, key, min, max, fmt)
    local v = ui.slider('##' .. key, cfg[key], min, max, label .. ': ' .. fmt)
    if v ~= cfg[key] then
        cfg[key] = v
        dirty = true
    end
end

function windowMain(dt)
    -- Throttle disk writes — save at most 10 Hz regardless of how fast sliders move
    if dirty and saveTimer <= 0 then
        saveLiveCfg()
        dirty = false
        saveTimer = 0.1
    end
    saveTimer = saveTimer - dt

    ui.text('Steering')
    ui.separator()
    sliderRow('Deadzone',    'DEADZONE',     0.0,  0.30, '%.2f')
    sliderRow('Gamma',       'GAMMA',        1.0,  3.0,  '%.2f')
    sliderRow('Smooth',      'STEER_SMOOTH', 0.01, 0.50, '%.2f')

    ui.offsetCursorY(8)
    ui.text('Speed Scaling')
    ui.separator()
    sliderRow('Start km/h',  'SPEED_SCALE_START', 0,   200, '%.0f')
    sliderRow('End km/h',    'SPEED_SCALE_END',   0,   300, '%.0f')
    sliderRow('Min scale',   'SPEED_SCALE_MIN',   0.1, 1.0, '%.2f')

    ui.offsetCursorY(8)
    ui.text('Self-Steer')
    ui.separator()
    sliderRow('Gain',        'COUNTERSTEER_GAIN', 0.0, 1.0, '%.2f')
    sliderRow('Damp',        'COUNTERSTEER_DAMP', 0.0, 1.0, '%.2f')

    ui.offsetCursorY(8)
    ui.text('Slip Limit')
    ui.separator()
    sliderRow('Start slip',  'SLIP_LIMIT_START', 0.0,  0.5,  '%.2f')
    sliderRow('Range',       'SLIP_LIMIT_RANGE', 0.05, 0.5,  '%.2f')
    sliderRow('Min auth.',   'SLIP_LIMIT_MIN',   0.3,  1.0,  '%.2f')

    ui.offsetCursorY(8)
    ui.text('Throttle & Brake')
    ui.separator()
    sliderRow('Gas dz',      'GAS_DEADZONE',   0.0, 0.10, '%.3f')
    sliderRow('Gas gamma',   'GAS_GAMMA',      0.5, 2.0,  '%.2f')
    sliderRow('Brake dz',    'BRAKE_DEADZONE', 0.0, 0.10, '%.3f')
    sliderRow('Brake gamma', 'BRAKE_GAMMA',    0.5, 2.0,  '%.2f')

    ui.offsetCursorY(8)
    ui.text('Haptics')
    ui.separator()
    if ui.checkbox('Enabled##haptics', cfg.HAPTICS_ENABLED) then
        cfg.HAPTICS_ENABLED = not cfg.HAPTICS_ENABLED
        dirty = true
    end
    if cfg.HAPTICS_ENABLED then
        sliderRow('Slip start',  'HAPTICS_SLIP_START', 0.0, 1.0, '%.2f')
        sliderRow('Slip max',    'HAPTICS_SLIP_MAX',   0.0, 2.0, '%.2f')
        sliderRow('Strength',    'HAPTICS_STRENGTH',   0.0, 1.0, '%.2f')
    end

    ui.offsetCursorY(8)
    if ui.checkbox('Debug overlay', cfg.DEBUG_MODE) then
        cfg.DEBUG_MODE = not cfg.DEBUG_MODE
        dirty = true
    end

    ui.offsetCursorY(6)
    ui.text('Changes apply within ~0.5s')
end
