-- lib.lua — math primitives and pipeline stage functions; no constants, no ac.* API calls
-- Note: math.clamp is a CSP extension, not available in vanilla LuaJIT.
local M = {}

local _logged = {}

function M.logOnce(key, message)
    if not _logged[key] then
        ac.log(message)
        _logged[key] = true
    end
end

-- Normalise a symmetric axis (stick) given its rest offset and physical range.
-- Output is clamped to [-1, 1]. With center=0, range=1 this is an identity.
function M.normalizeAxis(raw, center, range)
    if range == 0 then return 0.0 end
    return math.clamp((raw - center) / range, -1.0, 1.0)
end

-- Normalise a unipolar axis (trigger) given rest and max raw values.
-- Output is clamped to [0, 1]. With rest=0, maxVal=1 this is an identity.
function M.normalizeTrigger(raw, rest, maxVal)
    local span = maxVal - rest
    if span <= 0 then return 0.0 end
    return math.clamp((raw - rest) / span, 0.0, 1.0)
end

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

-- Yaw rate from car object. Returns 0.0 if unavailable (pre-v2.0 CSP).
-- car.localAngularVelocity is body-frame rad/s; .y = yaw (positive = rotating left).
function M.yawRate(car)
    if not car.localAngularVelocity then return 0.0 end
    return car.localAngularVelocity.y
end

-- Classify front vs rear slip to determine oversteer/understeer state.
-- Returns { front, rear, understeer, oversteer } all in [0, 1].
function M.stageSlipClassify(car, cfg)
    local front = (car.wheelsSlip[0] + car.wheelsSlip[1]) * 0.5
    local rear  = (car.wheelsSlip[2] + car.wheelsSlip[3]) * 0.5
    local delta = front - rear   -- positive = understeer, negative = oversteer
    local thresh = cfg.SLIP_DELTA_THRESH
    return {
        front      = front,
        rear       = rear,
        understeer = math.clamp( delta / thresh, 0.0, 1.0),
        oversteer  = math.clamp(-delta / thresh, 0.0, 1.0),
    }
end

-- Yaw damping: opposes car rotation and steer angle oscillation.
-- overFactor scales yaw correction up when oversteering; effectiveDamp handles load transfer.
function M.stageYawDamp(yaw, steerAngle, cfg, overFactor, effectiveDamp)
    local yawPart  = -yaw * cfg.YAW_GAIN * M.lerp(1.0, 1.0 + cfg.OS_BOOST, overFactor)
    local dampPart = -steerAngle * effectiveDamp
    return yawPart + dampPart
end

-- Adaptive smooth: faster at the limit, stable when settled.
-- stability in [0, 1] where 1 = fully stable.
function M.stageAdaptiveSmooth(current, target, stability, cfg, dt)
    local smooth = M.lerp(cfg.STEER_SMOOTH_MIN, cfg.STEER_SMOOTH, stability)
    return M.expSmooth(current, target, smooth, dt)
end

-- Rear wheelspin ratio. Returns value in [0, 1] where 0 = no spin, 1 = full spin.
function M.stageWheelspin(car)
    local expected = car.speedKmh / 3.6 / 0.3   -- ~0.3m typical tyre radius
    if expected < 1.0 then return 0.0 end
    local rearAvg = (car.wheelAngularSpeed[2] + car.wheelAngularSpeed[3]) * 0.5
    return math.clamp(rearAvg / expected - 1.0, 0.0, 1.0)
end

return M
