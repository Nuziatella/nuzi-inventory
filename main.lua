local api = require("api")
local Core = api._NuziCore or require("nuzi-core/core")

local Log = Core.Log
local Require = Core.Require

local logger = Log.Create("Nuzi Inventory")
local Runtime, _, errors = Require.Addon("nuzi-inventory", "runtime")

if Runtime == nil then
    logger:Err("Module load error: " .. tostring(Require.DescribeErrors(errors)))
    return {
        name = "Nuzi Inventory",
        author = "Nuzi",
        version = "2.0.1",
        desc = "Search bag, bank, alt, and tracked items across your roster",
        OnLoad = function() end,
        OnUnload = function() end
    }
end

return Runtime
