local api = require("api")
local Constants = require("nuzi-inventory/constants")

local Shared = {
    settings = nil
}

local function deepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] ~= nil then
        return seen[value]
    end
    local out = {}
    seen[value] = out
    for key, entry in pairs(value) do
        out[deepCopy(key, seen)] = deepCopy(entry, seen)
    end
    return out
end

local function copyDefaults(into, defaults)
    local changed = false
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(into[key]) ~= "table" then
                into[key] = deepCopy(value)
                changed = true
            else
                if copyDefaults(into[key], value) then
                    changed = true
                end
            end
        elseif into[key] == nil then
            into[key] = value
            changed = true
        end
    end
    return changed
end

local function readTableFile(path)
    if api.File == nil or api.File.Read == nil then
        return nil
    end
    local ok, value = pcall(function()
        return api.File:Read(path)
    end)
    if ok and type(value) == "table" then
        return value
    end
    return nil
end

local function writeTableFile(path, value)
    if api.File == nil or api.File.Write == nil or type(value) ~= "table" then
        return false
    end
    local ok = pcall(function()
        api.File:Write(path, value)
    end)
    return ok
end

function Shared.Trim(value)
    return (tostring(value or ""):gsub("^%s*(.-)%s*$", "%1"))
end

function Shared.LowerKey(value)
    return Shared.Trim(value):lower()
end

function Shared.SafePcall(fn)
    local ok, result = pcall(fn)
    if not ok then
        return nil
    end
    return result
end

function Shared.IsShiftDown()
    if api ~= nil and api.Input ~= nil and api.Input.IsShiftKeyDown ~= nil then
        local down = Shared.SafePcall(function()
            return api.Input:IsShiftKeyDown()
        end)
        return down and true or false
    end
    return false
end

function Shared.GetPlayerName()
    if api == nil or api.Unit == nil or api.Unit.GetUnitId == nil or api.Unit.GetUnitNameById == nil then
        return ""
    end
    local playerId = Shared.SafePcall(function()
        return api.Unit:GetUnitId("player")
    end)
    if playerId == nil then
        return ""
    end
    local playerName = Shared.SafePcall(function()
        return api.Unit:GetUnitNameById(playerId)
    end)
    return Shared.Trim(playerName or "")
end

function Shared.LoadSettings()
    local settings = readTableFile(Constants.SETTINGS_FILE_PATH)
    local migrated = false
    if type(settings) ~= "table" then
        for _, path in ipairs(Constants.LEGACY_SETTINGS_FILE_PATHS or {}) do
            settings = readTableFile(path)
            if type(settings) == "table" then
                migrated = true
                break
            end
        end
    end
    if type(settings) ~= "table" and api.GetSettings ~= nil then
        settings = api.GetSettings(Constants.ADDON_ID) or {}
    end
    if type(settings) ~= "table" then
        settings = {}
    end
    local changed = copyDefaults(settings, Constants.DEFAULT_SETTINGS)
    settings.query = Shared.Trim(settings.query)
    settings.include_bank = settings.include_bank and true or false
    settings.page = math.max(1, tonumber(settings.page) or 1)
    if type(settings.tracked_bar_positions) ~= "table" then
        settings.tracked_bar_positions = {}
        changed = true
    end
    local trackedGroupMode = Shared.Trim(settings.tracked_group_mode)
    if trackedGroupMode ~= "categories" and trackedGroupMode ~= "two_bars" then
        settings.tracked_group_mode = Constants.DEFAULT_SETTINGS.tracked_group_mode
        changed = true
    end
    local iconsPerRow = math.floor(tonumber(settings.tracked_icons_per_row) or Constants.DEFAULT_SETTINGS.tracked_icons_per_row)
    iconsPerRow = math.max(1, math.min(12, iconsPerRow))
    if settings.tracked_icons_per_row ~= iconsPerRow then
        settings.tracked_icons_per_row = iconsPerRow
        changed = true
    end
    if type(settings.saved_characters) ~= "table" then
        settings.saved_characters = {}
        changed = true
    end
    Shared.settings = settings
    if changed or migrated then
        writeTableFile(Constants.SETTINGS_FILE_PATH, settings)
    end
    return settings
end

function Shared.EnsureSettings()
    if type(Shared.settings) ~= "table" then
        return Shared.LoadSettings()
    end
    return Shared.settings
end

function Shared.SaveSettings()
    local settings = Shared.EnsureSettings()
    writeTableFile(Constants.SETTINGS_FILE_PATH, settings)
    if api.SaveSettings ~= nil then
        pcall(function()
            api.SaveSettings()
        end)
    end
end

function Shared.SafeShow(widget, show)
    if widget ~= nil and widget.Show ~= nil then
        pcall(function()
            widget:Show(show and true or false)
        end)
    end
end

function Shared.SafeFree(widget)
    if widget ~= nil and api.Interface ~= nil and api.Interface.Free ~= nil then
        pcall(function()
            api.Interface:Free(widget)
        end)
    end
end

function Shared.SafeSetText(widget, text)
    if widget ~= nil and widget.SetText ~= nil then
        pcall(function()
            widget:SetText(tostring(text or ""))
        end)
    end
end

function Shared.SafeSetColor(target, r, g, b, a)
    if target ~= nil and target.SetColor ~= nil then
        pcall(function()
            target:SetColor(r, g, b, a)
        end)
    end
end

function Shared.SafeSetTexture(drawable, path)
    if drawable ~= nil and drawable.SetTexture ~= nil then
        pcall(function()
            drawable:SetTexture(path)
        end)
    end
end

return Shared

