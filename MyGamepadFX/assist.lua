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
    local steer = gamepad.axes[1] or 0.0
    local gas   = gamepad.axes[3] or 0.0
    local brake = gamepad.axes[4] or 0.0

    ac.setSteer(math.clamp(steer,  -1.0, 1.0))
    ac.setGas(  math.clamp(gas,     0.0, 1.0))
    ac.setBrake(math.clamp(brake,   0.0, 1.0))
end

function script.reset()
    steerOut = 0.0
end
