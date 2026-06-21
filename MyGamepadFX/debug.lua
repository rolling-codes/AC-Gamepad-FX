-- debug.lua — live telemetry overlay for tuning; not for release builds
-- Enable by uncommenting: local dbg = require('debug') in assist.lua
-- Disable by commenting it out again — do not ship with this active

local D = {}

-- Call once per frame from script.update, passing the pipeline's internal values.
function D.draw(values)
    -- values = { raw, afterScale, driverInput, steerLimit,
    --            avgFrontSlip, selfSteer, combined, steerOut, speedKmh,
    --            carSteer, dt }
    ac.debug("1 raw_input",      string.format("%.3f", values.raw))
    ac.debug("2 after_scale",    string.format("%.3f", values.afterScale))
    ac.debug("3 steer_limit",    string.format("%.3f", values.steerLimit))
    ac.debug("4 driver_input",   string.format("%.3f", values.driverInput))
    ac.debug("5 self_steer",     string.format("%.3f", values.selfSteer))
    ac.debug("6 combined",       string.format("%.3f", values.combined))
    ac.debug("7 steer_out",      string.format("%.3f", values.steerOut))
    ac.debug("8 front_slip",     string.format("%.3f", values.avgFrontSlip))
    ac.debug("9 speed_kmh",      string.format("%.1f", values.speedKmh))
    ac.debug("A_car_steer",      string.format("%.3f", values.carSteer))
    ac.debug("B_dt_ms",          string.format("%.2f", values.dt * 1000))
end

return D
