-- CSP (Custom Shaders Patch) LuaJIT 5.2 environment
std = "lua52"

globals = {
    "ac",         -- CSP API namespace
    "ui",         -- CSP UI rendering (app scripts only)
    "script",     -- CSP entry point table (script.update, script.reset)
    "windowMain", -- CSP app window entry point (called by runtime, not defined by us)
    "vec2", "vec3", "vec4", "rgbm",  -- CSP math/color types
}

ignore = {
    "212",  -- unused argument: dt is required by CSP entry point signatures
    "141",  -- setting undefined field: script.update/reset are CSP-defined entry points
    "143",  -- accessing undefined field: math.clamp is a CSP extension to math
}
