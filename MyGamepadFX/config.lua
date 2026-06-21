-- config.lua — all tunable constants; no logic lives here
local CFG = {
    -- Deadzone & curve
    DEADZONE          = 0.08,   -- stick deadzone radius
    GAMMA             = 1.6,    -- steering curve exponent (>1 = more center precision)

    -- Smoothing
    STEER_SMOOTH      = 0.12,   -- blend weight at 60 fps (frame-rate independent)

    -- Speed scaling
    SPEED_SCALE_START = 60,     -- km/h where speed scaling begins
    SPEED_SCALE_END   = 180,    -- km/h where scaling reaches minimum
    SPEED_SCALE_MIN   = 0.35,   -- minimum steering multiplier at top speed

    -- Self-steer
    COUNTERSTEER_GAIN = 0.45,   -- correction strength
    COUNTERSTEER_DAMP = 0.30,   -- oscillation damping; must stay >= (COUNTERSTEER_GAIN * 0.6)

    -- Slip limit
    SLIP_LIMIT_START  = 0.15,   -- front slip level where reduction begins
    SLIP_LIMIT_RANGE  = 0.25,   -- slip range over which full reduction is applied
    SLIP_LIMIT_MIN    = 0.70,   -- minimum driver authority at peak slip

    -- Throttle & brake curves
    GAS_DEADZONE      = 0.01,   -- removes trigger drift at rest
    GAS_GAMMA         = 1.1,    -- slight curve for smooth power delivery
    BRAKE_DEADZONE    = 0.01,   -- avoids light brake from trigger drift
    BRAKE_GAMMA       = 1.0,    -- linear brake (no curve)

    -- Haptic feedback (trigger rumble, CSP v0.2.0+)
    HAPTICS_ENABLED    = false,  -- disabled by default; enable in config if controller supports it
    HAPTICS_SLIP_START = 0.3,   -- front slip level where rumble begins
    HAPTICS_SLIP_MAX   = 1.0,   -- slip level for maximum rumble
    HAPTICS_STRENGTH   = 0.8,   -- overall rumble intensity [0, 1]

    -- Debug / tuning mode
    DEBUG_MODE        = false,  -- set true to enable live telemetry overlay
}

return CFG
