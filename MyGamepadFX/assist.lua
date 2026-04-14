-- assist.lua — pipeline assembly and CSP entry points
-- Pipeline (execution order):
--   raw input → deadzone/gamma → speed scale → slip limit (driver only) → + self-steer → smooth → clamp → output

local CFG = require('config')
local lib = require('lib')
-- local dbg = require('debug')   -- uncomment for tuning overlay; never ship enabled

local steerOut = 0.0

function script.update(dt)
    local car     = ac.getCar(0)
    local gamepad = ac.getGamepad(0)
    if not car or not gamepad then return end

    -- 1. Raw input → deadzone → gamma → speed scale
    local raw   = gamepad.axes[1] or 0.0
    local steer = lib.applyGamma(lib.applyDeadzone(raw, CFG.DEADZONE), CFG.GAMMA)
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
    -- if dbg then dbg.draw({
    --     raw          = raw,
    --     afterScale   = steer,         -- value after deadzone + gamma + speed scale, before slip clamp
    --     steerLimit   = steerLimit,
    --     driverInput  = driverInput,
    --     selfSteer    = selfSteer,
    --     combined     = combined,
    --     steerOut     = steerOut,
    --     avgFrontSlip = avgFrontSlip,
    --     speedKmh     = car.speedKmh,
    -- }) end
    steerOut = lib.expSmooth(steerOut, combined, CFG.STEER_SMOOTH, dt)

    -- 5. Write to physics
    ac.setSteer(math.clamp(steerOut,               -1.0, 1.0))
    ac.setGas(  math.clamp(gamepad.axes[3] or 0.0,  0.0, 1.0))
    ac.setBrake(math.clamp(gamepad.axes[4] or 0.0,  0.0, 1.0))
end

function script.reset()
    steerOut = 0.0
end
