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
    COUNTERSTEER_DAMP = 0.30,   -- oscillation damping (keep >= 60% of GAIN)

    -- Slip limit
    SLIP_LIMIT_START  = 0.15,   -- front slip level where reduction begins
    SLIP_LIMIT_RANGE  = 0.25,   -- slip range over which full reduction is applied
    SLIP_LIMIT_MIN    = 0.70,   -- minimum driver authority at peak slip
}

return CFG
