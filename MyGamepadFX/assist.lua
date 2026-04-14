-- assist.lua — pipeline assembly and CSP entry points
-- Pipeline (execution order):
--   raw input → deadzone/gamma → speed scale → slip limit (driver only) → + self-steer → smooth → clamp → output

local CFG = require('config')
local lib = require('lib')

local steerOut = 0.0

function script.update(dt)
    local car     = ac.getCar(0)
    local gamepad = ac.getGamepad(0)
    if not car or not gamepad then return end

    -- Raw passthrough — replaced stage by stage in later tasks
    local raw   = gamepad.axes[1] or 0.0
    local steer = lib.applyGamma(lib.applyDeadzone(raw, CFG.DEADZONE), CFG.GAMMA)
    steer = steer * lib.speedScale(car.speedKmh, CFG)

    -- Slip limit: clamp driver input range when front tires are sliding
    local avgFrontSlip = (car.wheelsSlip[0] + car.wheelsSlip[1]) * 0.5
    local slipFactor   = math.clamp(
        (avgFrontSlip - CFG.SLIP_LIMIT_START) / CFG.SLIP_LIMIT_RANGE,
        0.0, 1.0
    )
    local steerLimit   = lib.lerp(1.0, CFG.SLIP_LIMIT_MIN, slipFactor)
    local driverInput  = math.clamp(steer, -steerLimit, steerLimit)

    -- Self-steer: simulate caster return-to-center + oscillation damping
    -- Added AFTER slip limit — correction force is not subject to driver input restrictions
    local selfSteer = -avgFrontSlip * CFG.COUNTERSTEER_GAIN
                   -  car.steer    * CFG.COUNTERSTEER_DAMP
    local combined  = driverInput + selfSteer

    local gas   = gamepad.axes[3] or 0.0
    local brake = gamepad.axes[4] or 0.0

    ac.setSteer(math.clamp(combined, -1.0, 1.0))
    ac.setGas(  math.clamp(gas,     0.0, 1.0))
    ac.setBrake(math.clamp(brake,   0.0, 1.0))
end

function script.reset()
    steerOut = 0.0
end
