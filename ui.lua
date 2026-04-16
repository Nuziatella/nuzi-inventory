local api = require("api")

local function Create(ctx)
    local App = ctx.App
    local trim = ctx.trim
    local lowerKey = ctx.lowerKey
    local safePcall = ctx.safePcall
    local isShiftDown = ctx.isShiftDown
    local getPlayerName = ctx.getPlayerName
    local ensureSettings = ctx.ensureSettings
    local saveSettings = ctx.saveSettings
    local safeShow = ctx.safeShow
    local safeFree = ctx.safeFree
    local safeSetText = ctx.safeSetText
    local safeSetColor = ctx.safeSetColor
    local createPanel = ctx.createPanel
    local createLabel = ctx.createLabel
    local createButton = ctx.createButton
    local createItemSlot = ctx.createItemSlot
    local safeSetItemIcon = ctx.safeSetItemIcon
    local createVisualItemIcon = ctx.createVisualItemIcon
    local safeSetVisualIcon = ctx.safeSetVisualIcon
    local createIconLauncherWindow = ctx.createIconLauncherWindow
    local createEdit = ctx.createEdit
    local getEditText = ctx.getEditText
    local setEditText = ctx.setEditText
    local ROWS_PER_PAGE = ctx.ROWS_PER_PAGE
    local HOTBAR_DEFAULT_X = ctx.HOTBAR_DEFAULT_X
    local HOTBAR_DEFAULT_Y = ctx.HOTBAR_DEFAULT_Y
    local HOTBAR_USE_OFFSET_Y = ctx.HOTBAR_USE_OFFSET_Y
    local TRACKED_POLL_INTERVAL_MS = ctx.TRACKED_POLL_INTERVAL_MS
    local DEFAULT_SETTINGS = ctx.DEFAULT_SETTINGS
    local WINDOW_ID = ctx.WINDOW_ID
    local BUTTON_ID = ctx.BUTTON_ID
    local ICON_PATH = ctx.ICON_PATH
    local buildResults = ctx.buildResults
    local getSavedCharacterCount = ctx.getSavedCharacterCount
    local getTrackedIndex = ctx.getTrackedIndex
    local isTrackedEntry = ctx.isTrackedEntry
    local isEquippableEntry = ctx.isEquippableEntry
    local aggregateTrackedItems = ctx.aggregateTrackedItems
    local scanBagEntries = ctx.scanBagEntries
    local buildCurrentCharacterSnapshot = ctx.buildCurrentCharacterSnapshot
    local getTrackedBagCountSignature = ctx.getTrackedBagCountSignature
local function toTitleWords(text)
    local input = trim(text):gsub("[_%-%s]+", " ")
    if input == "" then
        return ""
    end
    return (input:gsub("(%S+)", function(word)
        local lower = word:lower()
        return lower:sub(1, 1):upper() .. lower:sub(2)
    end))
end

local function getTrackedTypeGroup(summary)
    if type(summary) ~= "table" then
        return "other", "Other"
    end
    local equipSlot = trim(summary.equip_slot)
    local category = trim(summary.category)
    local itemImpl = trim(summary.item_impl)
    local combined = lowerKey(table.concat({
        equipSlot,
        category,
        itemImpl,
        trim(summary.name)
    }, " "))
    if summary.is_equippable then
        if string.find(combined, "glider", 1, true) ~= nil or string.find(combined, "magithopter", 1, true) ~= nil then
            return "gliders", "Gliders"
        end
        if string.find(combined, "shield", 1, true) ~= nil then
            return "shields", "Shields"
        end
        if string.find(combined, "accessory", 1, true) ~= nil
            or string.find(combined, "ring", 1, true) ~= nil
            or string.find(combined, "neck", 1, true) ~= nil
            or string.find(combined, "ear", 1, true) ~= nil
            or string.find(combined, "wrist", 1, true) ~= nil
        then
            return "accessories", "Accessories"
        end
        if string.find(combined, "weapon", 1, true) ~= nil
            or string.find(combined, "mainhand", 1, true) ~= nil
            or string.find(combined, "offhand", 1, true) ~= nil
            or string.find(combined, "bow", 1, true) ~= nil
            or string.find(combined, "instrument", 1, true) ~= nil
        then
            return "weapons", "Weapons"
        end
        if string.find(combined, "armor", 1, true) ~= nil
            or string.find(combined, "head", 1, true) ~= nil
            or string.find(combined, "chest", 1, true) ~= nil
            or string.find(combined, "waist", 1, true) ~= nil
            or string.find(combined, "legs", 1, true) ~= nil
            or string.find(combined, "hands", 1, true) ~= nil
            or string.find(combined, "feet", 1, true) ~= nil
        then
            return "armor", "Armor"
        end
    end
    local raw = category ~= "" and category or itemImpl
    if raw == "" then
        return "other", "Other"
    end
    local key = lowerKey(raw):gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if key == "" then
        key = "other"
    end
    return key, toTitleWords(raw)
end

local function getTrackedBarPosition(groupKey, useIndex)
    local settings = ensureSettings()
    if groupKey == "equip" then
        return tonumber(settings.hotbar_x) or HOTBAR_DEFAULT_X, tonumber(settings.hotbar_y) or HOTBAR_DEFAULT_Y
    end
    local saved = type(settings.tracked_bar_positions) == "table" and settings.tracked_bar_positions[groupKey] or nil
    if type(saved) == "table" then
        return tonumber(saved.x) or HOTBAR_DEFAULT_X, tonumber(saved.y) or (HOTBAR_DEFAULT_Y + HOTBAR_USE_OFFSET_Y)
    end
    local baseX = tonumber(settings.use_hotbar_x) or HOTBAR_DEFAULT_X
    local baseY = tonumber(settings.use_hotbar_y) or (HOTBAR_DEFAULT_Y + HOTBAR_USE_OFFSET_Y)
    return baseX, baseY + math.max(0, (tonumber(useIndex) or 1) - 1) * HOTBAR_USE_OFFSET_Y
end

local function saveTrackedBarPosition(groupKey, x, y)
    local settings = ensureSettings()
    if groupKey == "equip" then
        settings.hotbar_x = tonumber(x) or settings.hotbar_x
        settings.hotbar_y = tonumber(y) or settings.hotbar_y
    else
        settings.tracked_bar_positions[groupKey] = {
            x = tonumber(x) or HOTBAR_DEFAULT_X,
            y = tonumber(y) or (HOTBAR_DEFAULT_Y + HOTBAR_USE_OFFSET_Y)
        }
    end
    saveSettings()
end

local function getTrackedGroupMode()
    local settings = ensureSettings()
    local mode = trim(settings.tracked_group_mode)
    if mode == "categories" then
        return "categories"
    end
    return "two_bars"
end

local function getTrackedIconsPerRow()
    local settings = ensureSettings()
    return math.max(1, math.min(12, math.floor(tonumber(settings.tracked_icons_per_row) or DEFAULT_SETTINGS.tracked_icons_per_row)))
end

local function setStatus(text)
    safeSetText(App.ui.controls.status_label, text)
end

local function reportStatus(text, isError)
    setStatus(text)
    if api ~= nil and api.Log ~= nil then
        if isError and api.Log.Err ~= nil then
            pcall(function()
                api.Log:Err("[Nuzi Inventory] " .. tostring(text))
            end)
            return
        end
        if api.Log.Info ~= nil then
            pcall(function()
                api.Log:Info("[Nuzi Inventory] " .. tostring(text))
            end)
        end
    end
end


local function formatRowText(entry)
    local count = tonumber(entry.count) or 1
    local character = trim(entry.character or "")
    local source = trim(entry.source or "")
    if character ~= "" and source ~= "" then
        return string.format("%s - %s: %s x%d", character, source, tostring(entry.name or ""), math.max(1, math.floor(count)))
    end
    if character ~= "" then
        return string.format("%s: %s x%d", character, tostring(entry.name or ""), math.max(1, math.floor(count)))
    end
    if source ~= "" then
        return string.format("%s: %s x%d", source, tostring(entry.name or ""), math.max(1, math.floor(count)))
    end
    return string.format("%s x%d", tostring(entry.name or ""), math.max(1, math.floor(count)))
end

local function formatCardMeta(entry)
    local meta = {}
    local character = trim(entry.character or "")
    local source = trim(entry.source or "")
    if character ~= "" then
        table.insert(meta, character)
    end
    if source ~= "" then
        table.insert(meta, source)
    end
    return table.concat(meta, " - ")
end

local function formatRowMeta(entry)
    local meta = {}
    local character = trim(entry.character or "")
    local source = trim(entry.source or "")
    if character ~= "" then
        table.insert(meta, character)
    end
    if source ~= "" then
        table.insert(meta, source)
    end
    return table.concat(meta, "  •  ")
end

local refreshRows

local function runSearch()
    local settings = ensureSettings()
    settings.query = getEditText(App.ui.controls.query_edit)
    settings.page = 1
    saveSettings()
    buildResults()
    refreshRows()
    if refreshTrackedHotbar ~= nil then
        refreshTrackedHotbar()
    end
    setStatus(string.format("Found %d result(s)", #App.results))
end

local function clearSearch()
    local settings = ensureSettings()
    settings.query = ""
    settings.page = 1
    setEditText(App.ui.controls.query_edit, "")
    saveSettings()
    buildResults()
    refreshRows()
    if refreshTrackedHotbar ~= nil then
        refreshTrackedHotbar()
    end
    setStatus("Cleared search")
end

local function toggleBank()
    local settings = ensureSettings()
    settings.include_bank = not settings.include_bank
    settings.page = 1
    saveSettings()
    buildResults()
    refreshRows()
    if refreshTrackedHotbar ~= nil then
        refreshTrackedHotbar()
    end
    setStatus(settings.include_bank and "Bank results enabled" or "Bank results disabled")
end

local function cycleTrackedGroupMode()
    local settings = ensureSettings()
    if getTrackedGroupMode() == "two_bars" then
        settings.tracked_group_mode = "categories"
        setStatus("Tracked bars switched to Categories")
    else
        settings.tracked_group_mode = "two_bars"
        setStatus("Tracked bars switched to 2 Bars")
    end
    saveSettings()
    if refreshTrackedHotbar ~= nil then
        refreshTrackedHotbar()
    end
    refreshRows()
end

local function adjustTrackedIconsPerRow(delta)
    local settings = ensureSettings()
    local nextValue = math.max(1, math.min(12, getTrackedIconsPerRow() + (tonumber(delta) or 0)))
    if nextValue == getTrackedIconsPerRow() then
        return
    end
    settings.tracked_icons_per_row = nextValue
    saveSettings()
    if refreshTrackedHotbar ~= nil then
        refreshTrackedHotbar()
    end
    refreshRows()
    setStatus("Tracked icons per row set to " .. tostring(nextValue))
end

local function saveCurrentCharacterSnapshot()
    local settings = ensureSettings()
    local characterName = getPlayerName()
    if characterName == "" then
        setStatus("Could not resolve the current character name")
        return
    end
    settings.saved_characters[characterName] = {
        name = characterName,
        entries = buildCurrentCharacterSnapshot(),
        saved_at = os ~= nil and os.time ~= nil and safePcall(function() return os.time() end) or 0
    }
    saveSettings()
    buildResults()
    refreshRows()
    if refreshTrackedHotbar ~= nil then
        refreshTrackedHotbar()
    end
    setStatus("Saved inventory snapshot for " .. characterName)
end

local function removeCurrentCharacterSnapshot()
    local settings = ensureSettings()
    local characterName = getPlayerName()
    if characterName == "" then
        setStatus("Could not resolve the current character name")
        return
    end
    if settings.saved_characters[characterName] == nil then
        setStatus("No saved snapshot exists for " .. characterName)
        return
    end
    settings.saved_characters[characterName] = nil
    saveSettings()
    buildResults()
    refreshRows()
    if refreshTrackedHotbar ~= nil then
        refreshTrackedHotbar()
    end
    setStatus("Removed saved snapshot for " .. characterName)
end

local refreshTrackedHotbar

local function toggleTrackedItem(entry)
    if type(entry) ~= "table" then
        return
    end
    local settings = ensureSettings()
    local itemKey = trim(entry.item_key)
    local itemName = trim(entry.name)
    if itemKey == "" or itemName == "" then
        setStatus("Could not resolve item tracking data")
        return
    end
    local existingIndex = getTrackedIndex(itemKey)
    if existingIndex ~= nil then
        table.remove(settings.tracked_items, existingIndex)
        saveSettings()
        refreshRows()
        if refreshTrackedHotbar ~= nil then
            refreshTrackedHotbar()
        end
        setStatus("Stopped tracking " .. itemName)
        return
    end

    table.insert(settings.tracked_items, {
        item_key = itemKey,
        name = itemName,
        item_type = tonumber(entry.item_type),
        icon_path = trim(entry.icon_path),
        equip_slot = trim(entry.equip_slot),
        category = trim(entry.category),
        item_impl = trim(entry.item_impl),
        item_flag_cannot_equip = lowerKey(entry.item_flag_cannot_equip),
        tracked_kind = isEquippableEntry(entry) and "equip" or "use"
    })
    saveSettings()
    refreshRows()
    if refreshTrackedHotbar ~= nil then
        refreshTrackedHotbar()
    end
    setStatus("Tracking " .. itemName)
end

refreshRows = function()
    local settings = ensureSettings()
    local results = App.results or {}
    local total = #results
    local maxPage = math.max(1, math.ceil(math.max(total, 1) / ROWS_PER_PAGE))
    if settings.page > maxPage then
        settings.page = maxPage
    elseif settings.page < 1 then
        settings.page = 1
    end

    safeSetText(
        App.ui.controls.bank_toggle_button,
        settings.include_bank and "Bank: On" or "Bank: Off"
    )
    safeSetText(
        App.ui.controls.page_label,
        string.format("Page %d / %d", settings.page, maxPage)
    )
    safeSetText(
        App.ui.controls.summary_label,
        string.format("%d result(s) | Saved characters: %d", total, getSavedCharacterCount())
    )
    if App.ui.controls.tracked_mode_button ~= nil then
        safeSetText(
            App.ui.controls.tracked_mode_button,
            getTrackedGroupMode() == "categories" and "Bars: Categories" or "Bars: 2 Bars"
        )
    end
    if App.ui.controls.tracked_wrap_header ~= nil then
        safeSetText(
            App.ui.controls.tracked_wrap_header,
            string.format("Icons / Row: %d", getTrackedIconsPerRow())
        )
    end

    local startIndex = ((settings.page - 1) * ROWS_PER_PAGE) + 1
    for rowIndex = 1, ROWS_PER_PAGE do
        local absoluteIndex = startIndex + rowIndex - 1
        local row = App.ui.rows[rowIndex]
        local entry = results[absoluteIndex]
        if row ~= nil then
            safeShow(row.panel, entry ~= nil)
            safeShow(row.icon, entry ~= nil)
            safeShow(row.name_label, entry ~= nil)
            safeShow(row.meta_label, entry ~= nil)
            safeShow(row.count_label, entry ~= nil)
            safeShow(row.track_button, entry ~= nil)
            if entry ~= nil then
                row.entry = entry
                safeSetItemIcon(row.icon, entry.icon_path)
                safeSetText(row.name_label, tostring(entry.name or ""))
                safeSetText(row.meta_label, formatCardMeta(entry))
                safeSetText(row.count_label, "x" .. tostring(math.max(1, math.floor(tonumber(entry.count) or 1))))
                safeSetText(row.track_button, isTrackedEntry(entry) and "Untrack" or "Track")
            else
                row.entry = nil
            end
        end
    end
end

local function ensureWindow()
    if App.ui.window ~= nil then
        return
    end

    local settings = ensureSettings()
    local WINDOW_WIDTH = 820
    local WINDOW_HEIGHT = 620
    local PANEL_X = 12
    local PANEL_WIDTH = 784
    local SEARCH_PANEL_Y = 38
    local SEARCH_PANEL_HEIGHT = 148
    local RESULTS_PANEL_Y = 192
    local RESULTS_PANEL_HEIGHT = 360
    local FOOTER_PANEL_Y = 558
    local FOOTER_PANEL_HEIGHT = 42
    local SEARCH_HEADER_Y = 74
    local SEARCH_ROW_Y = 98
    local ALT_HEADER_Y = 136
    local ALT_ROW_Y = 160
    local LIST_HEADER_Y = 196
    local ROWS_START_Y = 220
    local ROW_PANEL_X = 24
    local ROW_PANEL_WIDTH = 760
    local ROW_NAME_X = 52
    local ROW_NAME_WIDTH = 560
    local ROW_META_X = 52
    local ROW_META_WIDTH = 520
    local ROW_COUNT_X = 640
    local ROW_COUNT_WIDTH = 44
    local ROW_TRACK_X = 692
    local ROW_TRACK_WIDTH = 72
    local TRACKED_WRAP_GROUP_X = 620
    local TRACKED_WRAP_BUTTON_WIDTH = 36
    local TRACKED_WRAP_MINUS_X = 628
    local TRACKED_WRAP_PLUS_X = 716
    local PAGER_PREV_X = 36
    local PAGER_BUTTON_WIDTH = 58
    local PAGER_LABEL_X = 134
    local PAGER_LABEL_WIDTH = 140
    local PAGER_NEXT_X = 292
    local STATUS_LABEL_X = 382
    local STATUS_LABEL_WIDTH = 330

    local window = safePcall(function()
        return api.Interface:CreateWindow(WINDOW_ID, "Nuzi Inventory", WINDOW_WIDTH, WINDOW_HEIGHT)
    end)
    if window == nil then
        return
    end
    App.ui.window = window
    window:AddAnchor("TOPLEFT", "UIParent", tonumber(settings.window_x) or 210, tonumber(settings.window_y) or 160)
    if window.SetHandler ~= nil then
        window:SetHandler("OnCloseByEsc", function()
            safeShow(window, false)
        end)
    end

    App.ui.controls.search_panel = createPanel(window, "nuziInventorySearchPanel", PANEL_X, SEARCH_PANEL_Y, PANEL_WIDTH, SEARCH_PANEL_HEIGHT, { 0.09, 0.07, 0.04, 0.86 })
    App.ui.controls.results_panel = createPanel(window, "nuziInventoryResultsPanel", PANEL_X, RESULTS_PANEL_Y, PANEL_WIDTH, RESULTS_PANEL_HEIGHT, { 0.05, 0.04, 0.03, 0.88 })
    App.ui.controls.footer_panel = createPanel(window, "nuziInventoryFooterPanel", PANEL_X, FOOTER_PANEL_Y, PANEL_WIDTH, FOOTER_PANEL_HEIGHT, { 0.08, 0.06, 0.04, 0.86 })

    createLabel(window, "nuziInventoryTitle", "Inventory Ledger", 20, 18, 220, 18)
    App.ui.controls.summary_label = createLabel(window, "nuziInventorySummary", "0 result(s)", 28, 52, 330, 13)
    App.ui.controls.character_label = createLabel(window, "nuziInventoryCharacter", "", 470, 52, 300, 13)
    safeSetText(App.ui.controls.character_label, "Current: " .. (getPlayerName() ~= "" and getPlayerName() or "Unknown"))

    createLabel(window, "nuziInventorySearchHeader", "Search Inventory", 28, SEARCH_HEADER_Y, 180, 14)
    App.ui.controls.query_edit = createEdit(window, "nuziInventoryQuery", "Search items", 28, SEARCH_ROW_Y, 294, 28, 80)
    setEditText(App.ui.controls.query_edit, settings.query or "")

    App.ui.controls.search_button = createButton(window, "nuziInventorySearch", "Search", 332, SEARCH_ROW_Y, 96, 28)
    App.ui.controls.search_button:SetHandler("OnClick", runSearch)

    App.ui.controls.clear_button = createButton(window, "nuziInventoryClear", "Clear", 436, SEARCH_ROW_Y, 88, 28)
    App.ui.controls.clear_button:SetHandler("OnClick", clearSearch)

    App.ui.controls.refresh_button = createButton(window, "nuziInventoryRefresh", "Refresh", 532, SEARCH_ROW_Y, 92, 28)
    App.ui.controls.refresh_button:SetHandler("OnClick", function()
        buildResults()
        refreshRows()
        if refreshTrackedHotbar ~= nil then
            refreshTrackedHotbar()
        end
        setStatus("Inventory refreshed")
    end)

    App.ui.controls.bank_toggle_button = createButton(window, "nuziInventoryBankToggle", "", 632, SEARCH_ROW_Y, 120, 28)
    App.ui.controls.bank_toggle_button:SetHandler("OnClick", toggleBank)

    createLabel(window, "nuziInventoryAltHeader", "Alt Snapshots", 28, ALT_HEADER_Y, 180, 14)
    App.ui.controls.save_character_button = createButton(window, "nuziInventorySaveCharacter", "Save This Character", 28, ALT_ROW_Y, 180, 28)
    App.ui.controls.save_character_button:SetHandler("OnClick", saveCurrentCharacterSnapshot)

    App.ui.controls.remove_character_button = createButton(window, "nuziInventoryRemoveCharacter", "Remove Saved Character", 216, ALT_ROW_Y, 204, 28)
    App.ui.controls.remove_character_button:SetHandler("OnClick", removeCurrentCharacterSnapshot)

    createLabel(window, "nuziInventoryTrackedHeader", "Tracked Bars", 456, ALT_HEADER_Y, 170, 14)
    App.ui.controls.tracked_mode_button = createButton(window, "nuziInventoryTrackedMode", "", 456, ALT_ROW_Y, 144, 28)
    App.ui.controls.tracked_mode_button:SetHandler("OnClick", cycleTrackedGroupMode)
    App.ui.controls.tracked_wrap_header = createLabel(
        window,
        "nuziInventoryWrapHeader",
        "Icons / Row: " .. tostring(getTrackedIconsPerRow()),
        TRACKED_WRAP_GROUP_X,
        ALT_HEADER_Y,
        156,
        14
    )
    App.ui.controls.tracked_wrap_minus = createButton(window, "nuziInventoryWrapMinus", "-", TRACKED_WRAP_MINUS_X, ALT_ROW_Y, TRACKED_WRAP_BUTTON_WIDTH, 28)
    App.ui.controls.tracked_wrap_minus:SetHandler("OnClick", function()
        adjustTrackedIconsPerRow(-1)
    end)
    App.ui.controls.tracked_wrap_plus = createButton(window, "nuziInventoryWrapPlus", "+", TRACKED_WRAP_PLUS_X, ALT_ROW_Y, TRACKED_WRAP_BUTTON_WIDTH, 28)
    App.ui.controls.tracked_wrap_plus:SetHandler("OnClick", function()
        adjustTrackedIconsPerRow(1)
    end)

    createLabel(window, "nuziInventoryListHeader", "Items", 28, LIST_HEADER_Y, 120, 14)
    createLabel(window, "nuziInventoryCountHeader", "Qty", 720, LIST_HEADER_Y, 40, 14)

    for index = 1, ROWS_PER_PAGE do
        local y = ROWS_START_Y + ((index - 1) * 28)
        local rowPanel = createPanel(window, "nuziInventoryRowPanel" .. tostring(index), ROW_PANEL_X, y, ROW_PANEL_WIDTH, 24, index % 2 == 0 and { 0.12, 0.09, 0.05, 0.38 } or { 0.09, 0.07, 0.04, 0.28 })
        local rowIcon = createItemSlot("nuziInventoryRowIcon" .. tostring(index), rowPanel)
        if rowIcon ~= nil then
            rowIcon:AddAnchor("TOPLEFT", rowPanel, 2, 2)
            rowIcon:SetExtent(20, 20)
        end
        App.ui.rows[index] = {
            panel = rowPanel,
            icon = rowIcon,
            name_label = createLabel(window, "nuziInventoryRowName" .. tostring(index), "", ROW_NAME_X, y + 1, ROW_NAME_WIDTH, 12, 8),
            meta_label = createLabel(window, "nuziInventoryRowMeta" .. tostring(index), "", ROW_META_X, y + 11, ROW_META_WIDTH, 10, 7),
            count_label = createLabel(window, "nuziInventoryRowCount" .. tostring(index), "", ROW_COUNT_X, y + 4, ROW_COUNT_WIDTH, 12, 8),
            track_button = createButton(window, "nuziInventoryRowTrack" .. tostring(index), "Track", ROW_TRACK_X, y + 1, ROW_TRACK_WIDTH, 22)
        }
        if App.ui.rows[index].track_button ~= nil and App.ui.rows[index].track_button.SetHandler ~= nil then
            App.ui.rows[index].track_button:SetHandler("OnClick", function()
                toggleTrackedItem(App.ui.rows[index].entry)
            end)
        end
        if App.ui.rows[index].name_label ~= nil and App.ui.rows[index].name_label.style ~= nil then
            if App.ui.rows[index].name_label.style.SetAlign ~= nil then
                App.ui.rows[index].name_label.style:SetAlign(ALIGN.LEFT)
            end
            if App.ui.rows[index].name_label.style.SetEllipsis ~= nil then
                App.ui.rows[index].name_label.style:SetEllipsis(true)
            end
        end
        if App.ui.rows[index].meta_label ~= nil and App.ui.rows[index].meta_label.style ~= nil then
            if App.ui.rows[index].meta_label.style.SetAlign ~= nil then
                App.ui.rows[index].meta_label.style:SetAlign(ALIGN.LEFT)
            end
            if App.ui.rows[index].meta_label.style.SetEllipsis ~= nil then
                App.ui.rows[index].meta_label.style:SetEllipsis(true)
            end
        end
        if App.ui.rows[index].count_label ~= nil and App.ui.rows[index].count_label.style ~= nil and App.ui.rows[index].count_label.style.SetAlign ~= nil then
            App.ui.rows[index].count_label.style:SetAlign(ALIGN.RIGHT)
        end
    end

    App.ui.controls.prev_button = createButton(window, "nuziInventoryPrev", "<", PAGER_PREV_X, 565, PAGER_BUTTON_WIDTH, 28)
    App.ui.controls.prev_button:SetHandler("OnClick", function()
        local state = ensureSettings()
        state.page = math.max(1, state.page - 1)
        refreshRows()
    end)

    App.ui.controls.page_label = createLabel(window, "nuziInventoryPage", "Page 1 / 1", PAGER_LABEL_X, 571, PAGER_LABEL_WIDTH, 13)
    if App.ui.controls.page_label ~= nil and App.ui.controls.page_label.style ~= nil and App.ui.controls.page_label.style.SetAlign ~= nil then
        App.ui.controls.page_label.style:SetAlign(ALIGN.CENTER)
    end

    App.ui.controls.next_button = createButton(window, "nuziInventoryNext", ">", PAGER_NEXT_X, 565, PAGER_BUTTON_WIDTH, 28)
    App.ui.controls.next_button:SetHandler("OnClick", function()
        local state = ensureSettings()
        state.page = state.page + 1
        refreshRows()
    end)

    App.ui.controls.status_label = createLabel(window, "nuziInventoryStatus", "", STATUS_LABEL_X, 571, STATUS_LABEL_WIDTH, 13)

    safeShow(window, false)
    buildResults()
    refreshRows()
    if refreshTrackedHotbar ~= nil then
        refreshTrackedHotbar()
    end
end

local function getTrackedBarGroups()
    local mode = getTrackedGroupMode()
    local groups = {}
    local order = {}

    local function ensureGroup(key, title, visualOnly)
        local bucket = groups[key]
        if bucket == nil then
            bucket = {
                key = key,
                title = title,
                visual_only = visualOnly and true or false,
                items = {}
            }
            groups[key] = bucket
            table.insert(order, bucket)
        end
        return bucket
    end

    for _, summary in ipairs(aggregateTrackedItems()) do
        if mode == "categories" then
            local baseKey, title = getTrackedTypeGroup(summary)
            local keyPrefix = summary.is_equippable and "equip_" or "use_"
            local bucket = ensureGroup(keyPrefix .. baseKey, title, not summary.is_equippable)
            table.insert(bucket.items, summary)
        elseif summary.is_equippable then
            table.insert(ensureGroup("equip", "Equipables", false).items, summary)
        else
            table.insert(ensureGroup("tracked", "Tracked", true).items, summary)
        end
    end

    table.sort(order, function(a, b)
        if a.key == "equip" then
            return true
        end
        if b.key == "equip" then
            return false
        end
        if a.key == "tracked" then
            return true
        end
        if b.key == "tracked" then
            return false
        end
        return lowerKey(a.title) < lowerKey(b.title)
    end)
    return order
end

local function getActionableBagSlots(summary)
    local slots = {}
    local seen = {}
    local function addCandidate(value)
        local numeric = tonumber(value)
        if numeric == nil then
            return
        end
        local key = tostring(numeric)
        if not seen[key] then
            seen[key] = true
            table.insert(slots, numeric)
        end
    end
    addCandidate(summary.live_slot_index)
    if trim(summary.live_index_mode) == "zero_based" then
        addCandidate(summary.live_slot_index_zero)
        addCandidate(summary.live_slot_index_one)
    else
        addCandidate(summary.live_slot_index_one)
        addCandidate(summary.live_slot_index_zero)
    end
    return slots
end

local function getActionableBagSlotsFromEntry(entry)
    local slots = {}
    local seen = {}
    local function addCandidate(value)
        local numeric = tonumber(value)
        if numeric == nil then
            return
        end
        local key = tostring(numeric)
        if not seen[key] then
            seen[key] = true
            table.insert(slots, numeric)
        end
    end
    addCandidate(entry.slot_index)
    if trim(entry.index_mode) == "zero_based" then
        addCandidate(entry.slot_index_zero)
        addCandidate(entry.slot_index_one)
    else
        addCandidate(entry.slot_index_one)
        addCandidate(entry.slot_index_zero)
    end
    return slots
end

local function findLiveBagEntryForSummary(summary)
    if type(summary) ~= "table" then
        return nil
    end
    local targetKey = trim(summary.item_key)
    local targetName = lowerKey(summary.name)
    local candidates = scanBagEntries()
    for _, entry in ipairs(candidates) do
        if trim(entry.item_key) ~= "" and trim(entry.item_key) == targetKey then
            return entry
        end
    end
    for _, entry in ipairs(candidates) do
        if lowerKey(entry.name) == targetName and targetName ~= "" then
            return entry
        end
    end
    return nil
end

local function equipTrackedItem(summary)
    if type(summary) ~= "table" then
        return
    end
    local liveEntry = findLiveBagEntryForSummary(summary)
    if liveEntry == nil then
        setStatus("Equipables bar only works with the current character's bag items")
        return
    end
    if api.Bag == nil or api.Bag.EquipBagItem == nil then
        setStatus("EquipBagItem is unavailable on this client")
        return
    end
    local attempted = false
    for _, slotIndex in ipairs(getActionableBagSlotsFromEntry(liveEntry)) do
        attempted = true
        local ok = pcall(function()
            api.Bag:EquipBagItem(slotIndex, false)
        end)
        if ok then
            setStatus("Tried equipping " .. trim(summary.name))
            return
        end
    end
    if not attempted then
        setStatus("No live bag slot is available for " .. trim(summary.name))
        return
    end
    setStatus("Could not equip " .. trim(summary.name))
end

local function bindTrackedConsumableSlot(widget, summary)
    if widget == nil then
        return false
    end
    if widget.ReleaseSlot ~= nil then
        pcall(function()
            widget:ReleaseSlot()
        end)
    end
    safeSetVisualIcon(widget, type(summary) == "table" and summary.icon_path or "")
    if widget.EnablePick ~= nil then
        pcall(function()
            widget:EnablePick(false)
        end)
    end
    return true
end

local function ensureTrackedBar(groupKey, title, useIndex, visualOnly)
    local existing = App.ui.tracked_bars[groupKey]
    if type(existing) == "table" and existing.window ~= nil then
        existing.title = title
        existing.visual_only = visualOnly and true or false
        if existing.window.title_label ~= nil then
            safeSetText(existing.window.title_label, title)
        end
        return existing
    end
    if api.Interface == nil or api.Interface.CreateEmptyWindow == nil then
        return nil
    end
    local id = "nuziInventoryTrackedBar_" .. tostring(groupKey)
    local startX, startY = getTrackedBarPosition(groupKey, useIndex)

    local hotbar = safePcall(function()
        return api.Interface:CreateEmptyWindow(id, "UIParent")
    end)
    if hotbar == nil then
        return nil
    end
    hotbar:SetExtent(240, 68)
    hotbar:AddAnchor("TOPLEFT", "UIParent", startX, startY)
    if hotbar.EnablePick ~= nil then
        pcall(function()
            hotbar:EnablePick(true)
        end)
    end
    hotbar.bg = nil
    if hotbar.CreateNinePartDrawable ~= nil and TEXTURE_PATH ~= nil and TEXTURE_PATH.HUD ~= nil then
        hotbar.bg = safePcall(function()
            return hotbar:CreateNinePartDrawable(TEXTURE_PATH.HUD, "background")
        end)
        if hotbar.bg ~= nil then
            if hotbar.bg.SetTextureInfo ~= nil then
                pcall(function()
                    hotbar.bg:SetTextureInfo("bg_quest")
                end)
            end
            safeSetColor(hotbar.bg, 0.05, 0.04, 0.03, 0.76)
            pcall(function()
                hotbar.bg:AddAnchor("TOPLEFT", hotbar, 0, 0)
                hotbar.bg:AddAnchor("BOTTOMRIGHT", hotbar, 0, 0)
            end)
        end
    end

    hotbar.title_label = createLabel(hotbar, id .. "Title", title, 8, 4, 120, 12, 8)
    if hotbar.title_label ~= nil and hotbar.title_label.EnablePick ~= nil then
        pcall(function()
            hotbar.title_label:EnablePick(false)
        end)
    end
    local barState = {
        key = groupKey,
        title = title,
        visual_only = visualOnly and true or false,
        window = hotbar,
        slots = {},
        drag_handle = nil
    }
    App.ui.tracked_bars[groupKey] = barState

    if hotbar.CreateChildWidget ~= nil then
        local dragHandle = safePcall(function()
            return hotbar:CreateChildWidget("button", id .. "Drag", 0, true)
        end)
        if dragHandle ~= nil then
            pcall(function()
                dragHandle:AddAnchor("TOPLEFT", hotbar, 0, 0)
                dragHandle:SetExtent(240, 18)
                dragHandle:Show(true)
                dragHandle:Enable(true)
                dragHandle:Raise()
            end)
            if dragHandle.SetText ~= nil then
                pcall(function()
                    dragHandle:SetText("")
                end)
            end
            if dragHandle.RegisterForDrag ~= nil then
                dragHandle:RegisterForDrag("LeftButton")
            end
            if dragHandle.EnableDrag ~= nil then
                dragHandle:EnableDrag(true)
            end
            if dragHandle.SetHandler ~= nil then
                dragHandle:SetHandler("OnDragStart", function()
                    if not isShiftDown() then
                        hotbar.__nuzi_dragging = false
                        return
                    end
                    hotbar.__nuzi_dragging = true
                    if hotbar.StartMoving ~= nil then
                        hotbar:StartMoving()
                    end
                end)
                dragHandle:SetHandler("OnDragStop", function()
                    if not hotbar.__nuzi_dragging then
                        return
                    end
                    hotbar.__nuzi_dragging = false
                    if hotbar.StopMovingOrSizing ~= nil then
                        hotbar:StopMovingOrSizing()
                    end
                    local ok, x, y = false, nil, nil
                    if hotbar.GetEffectiveOffset ~= nil then
                        ok, x, y = pcall(function()
                            return hotbar:GetEffectiveOffset()
                        end)
                    end
                    if (not ok or x == nil or y == nil) and hotbar.GetOffset ~= nil then
                        ok, x, y = pcall(function()
                            return hotbar:GetOffset()
                        end)
                    end
                    if ok then
                        saveTrackedBarPosition(groupKey, x, y)
                    end
                end)
            end
            barState.drag_handle = dragHandle
        end
    end
    safeShow(hotbar, false)
    return barState
end

local function refreshTrackedBar(groupKey, title, tracked, useIndex, visualOnly)
    local barState = ensureTrackedBar(groupKey, title, useIndex, visualOnly)
    if barState == nil or barState.window == nil then
        return
    end
    local hotbar = barState.window
    local slots = barState.slots
    safeShow(hotbar, #tracked > 0)
    if #tracked == 0 then
        return
    end

    local slotSize = 34
    local spacing = 6
    local padding = 8
    local top = 22
    local iconsPerRow = math.max(1, getTrackedIconsPerRow())
    local columns = math.min(#tracked, iconsPerRow)
    local rows = math.max(1, math.ceil(#tracked / iconsPerRow))
    local rowSpacing = 8
    local rowPitch = slotSize + rowSpacing
    local hotbarWidth = math.max(120, (padding * 2) + (columns * slotSize) + math.max(0, (columns - 1) * spacing))
    local hotbarHeight = 24 + (rows * rowPitch)
    if hotbar.SetExtent ~= nil then
        hotbar:SetExtent(hotbarWidth, hotbarHeight)
    end
    if barState.drag_handle ~= nil and barState.drag_handle.SetExtent ~= nil then
        barState.drag_handle:SetExtent(hotbarWidth, 18)
    end

    for index, summary in ipairs(tracked) do
        local slot = slots[index]
        if slot == nil then
            local slotIndex = index
            local iconIdPrefix = visualOnly and "nuziInventoryTypeSlot" or "nuziInventoryTrackedSlot"
            local countIdPrefix = visualOnly and "nuziInventoryTypeCount" or "nuziInventoryTrackedCount"
            local icon = visualOnly
                and createVisualItemIcon(iconIdPrefix .. tostring(groupKey) .. "_" .. tostring(index), hotbar)
                or createItemSlot(iconIdPrefix .. tostring(groupKey) .. "_" .. tostring(index), hotbar)
            local countLabel = createLabel(hotbar, countIdPrefix .. tostring(groupKey) .. "_" .. tostring(index), "", 0, 0, 30, 12, 8)
            slot = { icon = icon, count_label = countLabel }
            slots[index] = slot
            if countLabel ~= nil and countLabel.style ~= nil and countLabel.style.SetAlign ~= nil then
                countLabel.style:SetAlign(ALIGN.RIGHT)
            end
            if countLabel ~= nil and countLabel.EnablePick ~= nil then
                pcall(function()
                    countLabel:EnablePick(false)
                end)
            end
            if not visualOnly and icon ~= nil and icon.SetHandler ~= nil then
                icon:SetHandler("OnClick", function(_, mouseButton)
                    local current = slots[slotIndex]
                    if current == nil or type(current.summary) ~= "table" then
                        return
                    end
                    if mouseButton == "LeftButton" then
                        equipTrackedItem(current.summary)
                    end
                end)
            end
        end
        slot.summary = summary
        local column = (index - 1) % iconsPerRow
        local row = math.floor((index - 1) / iconsPerRow)
        local x = padding + (column * (slotSize + spacing))
        local y = top + (row * rowPitch)
        if slot.icon ~= nil then
            if slot.icon.RemoveAllAnchors ~= nil then
                slot.icon:RemoveAllAnchors()
            end
            slot.icon:AddAnchor("TOPLEFT", hotbar, x, y)
            slot.icon:SetExtent(slotSize, slotSize)
            if slot.icon.ReleaseSlot ~= nil then
                pcall(function()
                    slot.icon:ReleaseSlot()
                end)
            end
            if visualOnly then
                bindTrackedConsumableSlot(slot.icon, summary)
            else
                safeSetItemIcon(slot.icon, summary.icon_path)
                if slot.icon.EnablePick ~= nil then
                    pcall(function()
                        slot.icon:EnablePick(true)
                    end)
                end
            end
            safeShow(slot.icon, true)
        end
        if slot.count_label ~= nil then
            if slot.count_label.RemoveAllAnchors ~= nil then
                slot.count_label:RemoveAllAnchors()
            end
            slot.count_label:AddAnchor("TOPLEFT", hotbar, x + 2, y + 26)
            slot.count_label:SetExtent(30, 12)
            safeSetText(slot.count_label, tostring(summary.count))
            safeShow(slot.count_label, true)
        end
    end

    for index = #tracked + 1, #slots do
        local slot = slots[index]
        if slot ~= nil then
            safeShow(slot.icon, false)
            safeShow(slot.count_label, false)
            slot.summary = nil
        end
    end
end

refreshTrackedHotbar = function()
    local groups = getTrackedBarGroups()
    local active = {}
    for index, group in ipairs(groups) do
        active[group.key] = true
        refreshTrackedBar(group.key, group.title, group.items, index, group.visual_only)
    end
    for key, barState in pairs(App.ui.tracked_bars or {}) do
        if not active[key] and type(barState) == "table" and barState.window ~= nil then
            safeShow(barState.window, false)
        end
    end
end

local function hasTrackedItems()
    local settings = ensureSettings()
    return type(settings.tracked_items) == "table" and #settings.tracked_items > 0
end

local function isWindowVisible()
    if App.ui.window == nil or App.ui.window.IsVisible == nil then
        return false
    end
    local visible = safePcall(function()
        return App.ui.window:IsVisible()
    end)
    return visible and true or false
end

local function refreshInventoryUi()
    buildResults()
    if refreshTrackedHotbar ~= nil then
        refreshTrackedHotbar()
    end
    if isWindowVisible() then
        safeSetText(App.ui.controls.character_label, "Current: " .. (getPlayerName() ~= "" and getPlayerName() or "Unknown"))
        refreshRows()
    end
end

local function onTrackedInventoryEvent()
    if not hasTrackedItems() and not isWindowVisible() then
        return
    end
    refreshInventoryUi()
    App.tracked_bag_signature = getTrackedBagCountSignature()
    App.tracked_poll_accum_ms = 0
end

local function onUpdate(dt)
    if not hasTrackedItems() then
        App.tracked_poll_accum_ms = 0
        App.tracked_bag_signature = ""
        return
    end
    App.tracked_poll_accum_ms = (tonumber(App.tracked_poll_accum_ms) or 0) + (tonumber(dt) or 0)
    if App.tracked_poll_accum_ms < TRACKED_POLL_INTERVAL_MS then
        return
    end
    App.tracked_poll_accum_ms = 0
    local currentSignature = getTrackedBagCountSignature()
    if currentSignature == App.tracked_bag_signature then
        return
    end
    App.tracked_bag_signature = currentSignature
    refreshInventoryUi()
end

local function ensureButton()
    if App.ui.button ~= nil then
        return
    end
    local settings = ensureSettings()
    local button = createIconLauncherWindow(BUTTON_ID, ICON_PATH, 96, 96, tonumber(settings.button_x) or 156, tonumber(settings.button_y) or 140)
    if button == nil then
        return
    end
    App.ui.button = button
    if button.Lower ~= nil then
        button:Lower()
    end
    safeShow(button, true)

    local dragSurface = button.clickButton or button
    if dragSurface.RegisterForDrag ~= nil then
        dragSurface:RegisterForDrag("LeftButton")
    end
    if dragSurface.EnableDrag ~= nil then
        dragSurface:EnableDrag(true)
    end
    if dragSurface.SetHandler ~= nil then
        dragSurface:SetHandler("OnDragStart", function()
            if button ~= nil and button.StartMoving ~= nil then
                button:StartMoving()
            end
        end)
        dragSurface:SetHandler("OnClick", function()
            if button.__nuzi_just_dragged then
                button.__nuzi_just_dragged = false
                return
            end
            ensureWindow()
            if App.ui.window == nil then
                return
            end
            local visible = false
            if App.ui.window.IsVisible ~= nil then
                local current = safePcall(function()
                    return App.ui.window:IsVisible()
                end)
                visible = current and true or false
            end
            safeShow(App.ui.window, not visible)
            if not visible then
                safeSetText(App.ui.controls.character_label, "Current: " .. (getPlayerName() ~= "" and getPlayerName() or "Unknown"))
                setEditText(App.ui.controls.query_edit, ensureSettings().query or "")
                buildResults()
                refreshRows()
                if refreshTrackedHotbar ~= nil then
                    refreshTrackedHotbar()
                end
            end
        end)
        dragSurface:SetHandler("OnDragStop", function()
            if button ~= nil and button.StopMovingOrSizing ~= nil then
                button:StopMovingOrSizing()
            end
            if button ~= nil and button.GetEffectiveOffset ~= nil then
                local ok, x, y = pcall(function()
                    return button:GetEffectiveOffset()
                end)
                if ok then
                    button.__nuzi_just_dragged = true
                    settings.button_x = tonumber(x) or settings.button_x
                    settings.button_y = tonumber(y) or settings.button_y
                    saveSettings()
                end
            end
        end)
    end

    if button.EnableDrag ~= nil then
        button:EnableDrag(true)
    end
end

local function unloadUi()
    safeFree(App.ui.window)
    for _, barState in pairs(App.ui.tracked_bars or {}) do
        if type(barState) == "table" then
            safeFree(barState.window)
        end
    end
    safeFree(App.ui.button)
    App.ui.window = nil
    App.ui.button = nil
    App.ui.tracked_bars = {}
    App.ui.rows = {}
    App.ui.controls = {}
end

local function onUiReloaded()
    unloadUi()
    ensureButton()
end

local function onChatMessage(channel, unit, isHostile, name, message)
    local raw = trim(message)
    if raw == "!ib" or raw == "!inventory" or raw == "!nuziinventory" or raw == "!bagsearch" or raw == "!nuzibagsearch" then
        ensureWindow()
        if App.ui.window ~= nil then
            safeShow(App.ui.window, true)
            setEditText(App.ui.controls.query_edit, ensureSettings().query or "")
            buildResults()
            refreshRows()
            if refreshTrackedHotbar ~= nil then
                refreshTrackedHotbar()
            end
        end
    end
end

    return {
        setStatus = setStatus,
        reportStatus = reportStatus,
        refreshRows = refreshRows,
        refreshTrackedHotbar = refreshTrackedHotbar,
        ensureWindow = ensureWindow,
        ensureButton = ensureButton,
        unloadUi = unloadUi,
        onUiReloaded = onUiReloaded,
        onChatMessage = onChatMessage,
        onTrackedInventoryEvent = onTrackedInventoryEvent,
        onUpdate = onUpdate
    }
end

return {
    Create = Create
}

