-- lib.lua — math primitives; no constants, no CSP API calls
local M = {}

-- Deadzone with rescale: removes drift and maps the remaining range to [0,1]
-- with no discontinuity at the deadzone edge.
function M.applyDeadzone(v, dz)
    local sign = v >= 0 and 1 or -1
    local abs  = math.abs(v)
    if abs < dz then return 0.0 end
    return sign * (abs - dz) / (1.0 - dz)
end

-- Gamma curve: compresses center travel for precision, preserves sign.
function M.applyGamma(v, gamma)
    local sign = v >= 0 and 1 or -1
    return sign * math.abs(v) ^ gamma
end

-- Linear interpolation, t clamped to [0,1].
function M.lerp(a, b, t)
    t = math.clamp(t, 0.0, 1.0)
    return a + (b - a) * t
end

-- Frame-rate independent exponential smoother.
-- smooth = blend weight at 60 fps. Identical feel at any frame rate.
function M.expSmooth(current, target, smooth, dt)
    local alpha = 1.0 - (1.0 - smooth) ^ (dt * 60.0)
    return M.lerp(current, target, alpha)
end

-- Speed-sensitive steering ratio.
-- Returns a multiplier in [SPEED_SCALE_MIN, 1.0].
function M.speedScale(speedKmh, cfg)
    local t = math.clamp(
        (speedKmh - cfg.SPEED_SCALE_START) / (cfg.SPEED_SCALE_END - cfg.SPEED_SCALE_START),
        0.0, 1.0
    )
    return M.lerp(1.0, cfg.SPEED_SCALE_MIN, t)
end

return M
