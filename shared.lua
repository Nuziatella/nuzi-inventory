local api = require("api")
local Core = api._NuziCore or require("nuzi-core/core")
local Constants = require("nuzi-inventory/constants")

local Log = Core.Log
local Runtime = Core.Runtime
local Settings = Core.Settings

local logger = Log.Create(Constants.ADDON ~= nil and Constants.ADDON.name or "Nuzi Inventory")

local Shared = {
    settings = nil
}

local function normalizeSettings(settings)
    local changed = false

    local query = Runtime.Trim(settings.query)
    if settings.query ~= query then
        settings.query = query
        changed = true
    end

    local includeBank = settings.include_bank and true or false
    if settings.include_bank ~= includeBank then
        settings.include_bank = includeBank
        changed = true
    end

    local page = math.max(1, tonumber(settings.page) or 1)
    if settings.page ~= page then
        settings.page = page
        changed = true
    end

    if type(settings.tracked_bar_positions) ~= "table" then
        settings.tracked_bar_positions = {}
        changed = true
    end

    local trackedGroupMode = Runtime.Trim(settings.tracked_group_mode)
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

    if type(settings.tracked_items) ~= "table" then
        settings.tracked_items = {}
        changed = true
    end

    return changed
end

local store = Settings.CreateAddonStore(Constants, {
    read_mode = "serialized_then_flat",
    write_mode = "serialized",
    fallback_paths = Constants.LEGACY_SETTINGS_FILE_PATHS,
    skip_empty_default_tables = true,
    normalize = function(settings)
        return normalizeSettings(settings)
    end,
    log_name = Constants.ADDON ~= nil and Constants.ADDON.name or "Nuzi Inventory"
})

Shared.store = store

function Shared.GetStore()
    return store
end

function Shared.LoadSettings()
    local settings = store:Load()
    Shared.settings = settings
    return settings
end

function Shared.EnsureSettings()
    local settings = store:Ensure()
    Shared.settings = settings
    return settings
end

function Shared.SaveSettings()
    local settings = Shared.EnsureSettings()
    local ok = store:Save()
    Shared.settings = settings
    if not ok then
        logger:Err("Failed to save settings.")
    end
    return ok
end

function Shared.Trim(value)
    return Runtime.Trim(value)
end

function Shared.LowerKey(value)
    return Runtime.Trim(value):lower()
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
