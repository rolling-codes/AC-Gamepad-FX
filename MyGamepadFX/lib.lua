-- lib.lua — math primitives; no constants, no CSP API calls
local M = {}

function M.applyDeadzone(v, dz)   return v end  -- stub
function M.applyGamma(v, gamma)   return v end  -- stub
function M.lerp(a, b, t)          return a end  -- stub
function M.expSmooth(current, target, smooth, dt) return target end  -- stub
function M.speedScale(speedKmh, cfg) return 1.0 end  -- stub

return M
