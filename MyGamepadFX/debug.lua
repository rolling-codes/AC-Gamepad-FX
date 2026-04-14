-- debug.lua — live telemetry overlay for tuning; not for release builds
-- Enable by uncommenting: local dbg = require('debug') in assist.lua
-- Disable by commenting it out again — do not ship with this active

local D = {}

-- Call once per frame from script.update, passing the pipeline's internal values.
function D.draw(values)
    -- values = { raw, afterDZ, afterGamma, driverInput, steerLimit,
    --            avgFrontSlip, selfSteer, combined, steerOut, speedKmh }
    ac.debug("1 raw_input",      values.raw)
    ac.debug("2 after_scale",    values.afterScale)
    ac.debug("3 steer_limit",    values.steerLimit)
    ac.debug("4 driver_input",   values.driverInput)
    ac.debug("5 self_steer",     values.selfSteer)
    ac.debug("6 combined",       values.combined)
    ac.debug("7 steer_out",      values.steerOut)
    ac.debug("8 front_slip",     values.avgFrontSlip)
    ac.debug("9 speed_kmh",      values.speedKmh)
end

return D
