-- config.lua — all tunable constants; no logic lives here
local CFG = {
    -- Axis calibration (Hall Effect controllers)
    -- Defaults produce no change from pre-calibration behaviour.
    STEER_CENTER  = 0.0,   -- raw stick value at rest; subtracted before deadzone
    STEER_RANGE   = 1.0,   -- max raw deflection from center (scale to ±1.0)
    GAS_REST      = 0.0,   -- raw trigger value when fully released
    GAS_MAX       = 1.0,   -- raw trigger value when fully pressed
    BRAKE_REST    = 0.0,   -- raw trigger value when fully released
    BRAKE_MAX     = 1.0,   -- raw trigger value when fully pressed

    -- Deadzone & curve
    DEADZONE          = 0.08,   -- stick deadzone radius
    GAMMA             = 1.6,    -- steering curve exponent (>1 = more center precision)

    -- Smoothing
    STEER_SMOOTH      = 0.12,   -- stable-state blend weight at 60 fps
    STEER_SMOOTH_MIN  = 0.04,   -- minimum blend weight at high instability (v2.0)

    -- Speed scaling
    SPEED_SCALE_START = 60,     -- km/h where speed scaling begins
    SPEED_SCALE_END   = 180,    -- km/h where scaling reaches minimum
    SPEED_SCALE_MIN   = 0.35,   -- minimum steering multiplier at top speed

    -- Yaw damping (v2.0 — replaces COUNTERSTEER_GAIN/DAMP)
    YAW_GAIN          = 0.5,    -- countersteer force per rad/s of yaw
    YAW_DAMP          = 0.3,    -- steer angle damping when yawing

    -- Slip discrimination (v2.0)
    SLIP_DELTA_THRESH = 0.08,   -- front-rear slip difference that fully classifies under/oversteer
    US_REDUCTION      = 0.25,   -- max authority reduction when understeering (0 = disabled)
    OS_BOOST          = 0.3,    -- max countersteer boost when oversteering (0 = disabled)

    -- Slip limit
    SLIP_LIMIT_START  = 0.15,   -- front slip level where reduction begins
    SLIP_LIMIT_RANGE  = 0.25,   -- slip range over which full reduction is applied
    SLIP_LIMIT_MIN    = 0.70,   -- minimum driver authority at peak slip

    -- Throttle & brake curves
    GAS_DEADZONE      = 0.01,   -- removes trigger drift at rest
    GAS_GAMMA         = 1.1,    -- slight curve for smooth power delivery
    BRAKE_DEADZONE    = 0.01,   -- avoids light brake from trigger drift
    BRAKE_GAMMA       = 1.0,    -- linear brake (no curve)

    -- Traction control (v2.0, off by default)
    TC_ENABLED        = false,  -- enable to reduce wheelspin automatically
    TC_SLIP_THRESHOLD = 0.15,   -- rear wheelspin ratio where TC activates
    TC_MAX_REDUCTION  = 0.5,    -- maximum throttle reduction fraction

    -- Haptic feedback (trigger rumble, CSP v0.2.0+)
    HAPTICS_ENABLED    = false,
    HAPTICS_SLIP_START = 0.3,
    HAPTICS_SLIP_MAX   = 1.0,
    HAPTICS_STRENGTH   = 0.8,

    -- Debug / tuning mode
    DEBUG_MODE        = false,
}

return CFG
