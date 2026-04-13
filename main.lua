local function loadModule(name)
    local ok, mod = pcall(require, "nuzi-inventory/" .. name)
    if ok then
        return mod
    end
    ok, mod = pcall(require, "nuzi-inventory." .. name)
    if ok then
        return mod
    end
    return nil
end

local Runtime = loadModule("runtime")

if Runtime == nil then
    return {
        name = "Nuzi Inventory",
        author = "Nuzi",
        version = "1.0.0",
        desc = "Search bag, bank, alt, and tracked items across your roster",
        OnLoad = function() end,
        OnUnload = function() end
    }
end

return Runtime

