local api = require("api")
local Core = api._NuziCore or require("nuzi-core/core")
local Constants = require("nuzi-inventory/constants")
local Shared = require("nuzi-inventory/shared")
local UiHelpers = require("nuzi-inventory/ui_helpers")

local Events = Core.Events
local Log = Core.Log

local addon = Constants.ADDON
local logger = Log.Create(Constants.ADDON ~= nil and Constants.ADDON.name or "Nuzi Inventory")
local events = Events.Create({
    logger = logger
})

local WINDOW_ID = Constants.WINDOW_ID
local BUTTON_ID = Constants.BUTTON_ID
local ICON_PATH = Constants.ICON_PATH
local ROWS_PER_PAGE = Constants.ROWS_PER_PAGE
local HOTBAR_DEFAULT_X = Constants.HOTBAR_DEFAULT_X
local HOTBAR_DEFAULT_Y = Constants.HOTBAR_DEFAULT_Y
local HOTBAR_USE_OFFSET_Y = Constants.HOTBAR_USE_OFFSET_Y
local TRACKED_POLL_INTERVAL_MS = Constants.TRACKED_POLL_INTERVAL_MS
local DEFAULT_SETTINGS = Constants.DEFAULT_SETTINGS

local App = {
    results = {},
    inventory_entries = {},
    tracked_poll_accum_ms = 0,
    tracked_bag_signature = "",
    ui = {
        button = nil,
        tracked_bars = {},
        window = nil,
        rows = {},
        controls = {}
    }
}

local trim = Shared.Trim
local lowerKey = Shared.LowerKey
local safePcall = Shared.SafePcall
local isShiftDown = Shared.IsShiftDown
local getPlayerName = Shared.GetPlayerName
local ensureSettings = Shared.EnsureSettings
local saveSettings = Shared.SaveSettings
local safeShow = Shared.SafeShow
local safeFree = Shared.SafeFree
local safeSetText = Shared.SafeSetText
local safeSetColor = Shared.SafeSetColor
local safeSetTexture = Shared.SafeSetTexture

local attachImage = UiHelpers.AttachImage
local createPanel = UiHelpers.CreatePanel
local createLabel = UiHelpers.CreateLabel
local createButton = UiHelpers.CreateButton
local createItemSlot = UiHelpers.CreateItemSlot
local safeSetItemIcon = UiHelpers.SafeSetItemIcon
local createVisualItemIcon = UiHelpers.CreateVisualItemIcon
local safeSetVisualIcon = UiHelpers.SafeSetVisualIcon
local createIconLauncherWindow = UiHelpers.CreateIconLauncherWindow
local createEdit = UiHelpers.CreateEdit
local getEditText = UiHelpers.GetEditText
local setEditText = UiHelpers.SetEditText


local Inventory = require("nuzi-inventory/inventory")
local inventory = Inventory.Create({
    App = App,
    trim = trim,
    lowerKey = lowerKey,
    safePcall = safePcall,
    getPlayerName = getPlayerName,
    ensureSettings = ensureSettings
})

local scanBagEntries = inventory.scanBagEntries
local scanBankEntries = inventory.scanBankEntries
local buildCurrentCharacterSnapshot = inventory.buildCurrentCharacterSnapshot
local getTrackedBagCountSignature = inventory.getTrackedBagCountSignature
local normalizeSavedCharacters = inventory.normalizeSavedCharacters
local getSavedCharacterCount = inventory.getSavedCharacterCount
local normalizeTrackedItems = inventory.normalizeTrackedItems
local getTrackedIndex = inventory.getTrackedIndex
local isTrackedEntry = inventory.isTrackedEntry
local isEquippableEntry = inventory.isEquippableEntry
local aggregateTrackedItems = inventory.aggregateTrackedItems
local buildResults = inventory.buildResults

local Ui = require("nuzi-inventory/ui")
local ui = Ui.Create({
    App = App,
    trim = trim,
    lowerKey = lowerKey,
    safePcall = safePcall,
    isShiftDown = isShiftDown,
    getPlayerName = getPlayerName,
    ensureSettings = ensureSettings,
    saveSettings = saveSettings,
    safeShow = safeShow,
    safeFree = safeFree,
    safeSetText = safeSetText,
    safeSetColor = safeSetColor,
    createPanel = createPanel,
    createLabel = createLabel,
    createButton = createButton,
    createItemSlot = createItemSlot,
    safeSetItemIcon = safeSetItemIcon,
    createVisualItemIcon = createVisualItemIcon,
    safeSetVisualIcon = safeSetVisualIcon,
    createIconLauncherWindow = createIconLauncherWindow,
    createEdit = createEdit,
    getEditText = getEditText,
    setEditText = setEditText,
    ROWS_PER_PAGE = ROWS_PER_PAGE,
    HOTBAR_DEFAULT_X = HOTBAR_DEFAULT_X,
    HOTBAR_DEFAULT_Y = HOTBAR_DEFAULT_Y,
    HOTBAR_USE_OFFSET_Y = HOTBAR_USE_OFFSET_Y,
    TRACKED_POLL_INTERVAL_MS = TRACKED_POLL_INTERVAL_MS,
    DEFAULT_SETTINGS = DEFAULT_SETTINGS,
    WINDOW_ID = WINDOW_ID,
    BUTTON_ID = BUTTON_ID,
    ICON_PATH = ICON_PATH,
    buildResults = buildResults,
    getSavedCharacterCount = getSavedCharacterCount,
    getTrackedIndex = getTrackedIndex,
    isTrackedEntry = isTrackedEntry,
    isEquippableEntry = isEquippableEntry,
    aggregateTrackedItems = aggregateTrackedItems,
    scanBagEntries = scanBagEntries,
    buildCurrentCharacterSnapshot = buildCurrentCharacterSnapshot,
    getTrackedBagCountSignature = getTrackedBagCountSignature
})

local ensureButton = ui.ensureButton
local unloadUi = ui.unloadUi
local onUiReloaded = ui.onUiReloaded
local onChatMessage = ui.onChatMessage
local onTrackedInventoryEvent = ui.onTrackedInventoryEvent
local onUpdate = ui.onUpdate
local refreshTrackedHotbar = ui.refreshTrackedHotbar

local function onLoad()
    ensureSettings()
    if normalizeSavedCharacters() then
        saveSettings()
    end
    if normalizeTrackedItems() then
        saveSettings()
    end
    buildResults()
    ensureButton()
    if refreshTrackedHotbar ~= nil then
        refreshTrackedHotbar()
    end
    App.tracked_bag_signature = getTrackedBagCountSignature()
    App.tracked_poll_accum_ms = 0
    events:OnSafe("UI_RELOADED", "UI_RELOADED", onUiReloaded)
    events:OnSafe("CHAT_MESSAGE", "CHAT_MESSAGE", onChatMessage)
    events:OnSafe("UPDATE", "UPDATE", onUpdate)
    events:OnSafe("BAG_UPDATE", "BAG_UPDATE", onTrackedInventoryEvent)
    events:OnSafe("BANK_UPDATE", "BANK_UPDATE", onTrackedInventoryEvent)
    events:OnSafe("UNIT_EQUIPMENT_CHANGED", "UNIT_EQUIPMENT_CHANGED", onTrackedInventoryEvent)
    events:OnSafe("ITEM_EQUIP_RESULT", "ITEM_EQUIP_RESULT", onTrackedInventoryEvent)
    logger:Info("Loaded v" .. tostring(addon ~= nil and addon.version or "1.0.0"))
end

local function onUnload()
    events:ClearAll()
    unloadUi()
end

addon.OnLoad = onLoad
addon.OnUnload = onUnload

return addon

