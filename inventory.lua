local api = require("api")

local function Create(ctx)
    local App = ctx.App
    local trim = ctx.trim
    local lowerKey = ctx.lowerKey
    local safePcall = ctx.safePcall
    local getPlayerName = ctx.getPlayerName
    local ensureSettings = ctx.ensureSettings

    local resolveBagEntry
    local isEquippableEntry
    local ItemInfoCache = {}

local function stripLinkText(text)
    local value = tostring(text or "")
    value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
    value = value:gsub("|r", "")
    value = value:gsub("%[[^%]]+%]", function(match)
        return match
    end)
    value = value:gsub("%s+", " ")
    return trim(value)
end

local function parseItemTypeFromLinkText(text)
    local value = trim(text)
    if value == "" then
        return nil
    end
    local direct = value:match("^[%a_]+(%d+)")
    if direct ~= nil then
        return tonumber(direct)
    end
    local fallback = value:match("(%d+)")
    if fallback ~= nil then
        return tonumber(fallback)
    end
    return nil
end

local function getFirstString(tbl, keys)
    if type(tbl) ~= "table" then
        return ""
    end
    for _, key in ipairs(keys or {}) do
        local value = tbl[key]
        if value ~= nil and type(value) ~= "table" and type(value) ~= "function" and type(value) ~= "boolean" then
            local text = trim(tostring(value))
            if text ~= "" then
                return text
            end
        end
    end
    return ""
end

local function getNestedTables(tbl)
    if type(tbl) ~= "table" then
        return {}
    end
    local out = {}
    local preferredKeys = {
        "itemInfo", "item_info", "info", "tooltip", "tooltipInfo", "tooltip_info", "item", "data"
    }
    for _, key in ipairs(preferredKeys) do
        if type(tbl[key]) == "table" then
            table.insert(out, tbl[key])
        end
    end
    for _, value in pairs(tbl) do
        if type(value) == "table" then
            local seen = false
            for _, existing in ipairs(out) do
                if existing == value then
                    seen = true
                    break
                end
            end
            if not seen then
                table.insert(out, value)
            end
        end
    end
    return out
end

local function getFirstStringDeep(tbl, keys)
    local direct = getFirstString(tbl, keys)
    if direct ~= "" then
        return direct
    end
    for _, nested in ipairs(getNestedTables(tbl)) do
        local nestedValue = getFirstString(nested, keys)
        if nestedValue ~= "" then
            return nestedValue
        end
    end
    return ""
end

local function getFirstNumber(tbl, keys)
    if type(tbl) ~= "table" then
        return nil
    end
    for _, key in ipairs(keys or {}) do
        local value = tonumber(tbl[key])
        if value ~= nil then
            return value
        end
    end
    return nil
end

local function getFirstNumberDeep(tbl, keys)
    local direct = getFirstNumber(tbl, keys)
    if direct ~= nil then
        return direct
    end
    for _, nested in ipairs(getNestedTables(tbl)) do
        local nestedValue = getFirstNumber(nested, keys)
        if nestedValue ~= nil then
            return nestedValue
        end
    end
    return nil
end

local function getItemInfoByType(itemType)
    if itemType == nil or api.Item == nil or api.Item.GetItemInfoByType == nil then
        return nil
    end
    if ItemInfoCache[itemType] ~= nil then
        return ItemInfoCache[itemType] or nil
    end
    local info = safePcall(function()
        return api.Item:GetItemInfoByType(itemType)
    end)
    if type(info) ~= "table" then
        ItemInfoCache[itemType] = false
        return nil
    end
    ItemInfoCache[itemType] = info
    return info
end

local function getEquipMetadata(entry)
    if type(entry) ~= "table" then
        return "", "", "", ""
    end
    local equipSlot = trim(entry.equip_slot or entry.equipSlot or "")
    local category = trim(entry.category or entry.itemCategory or entry.item_category or "")
    local itemImpl = trim(entry.item_impl or entry.itemImpl or "")
    local cannotEquip = lowerKey(entry.item_flag_cannot_equip or entry.itemFlagCannotEquip or "")
    if (equipSlot == "" or category == "" or itemImpl == "" or cannotEquip == "") and tonumber(entry.item_type or entry.itemType) ~= nil then
        local itemInfo = getItemInfoByType(tonumber(entry.item_type or entry.itemType))
        if type(itemInfo) == "table" then
            if equipSlot == "" then
                equipSlot = trim(getFirstStringDeep(itemInfo, { "equipSlot", "equip_slot" }))
            end
            if category == "" then
                category = trim(getFirstStringDeep(itemInfo, { "category", "itemCategory", "item_category" }))
            end
            if itemImpl == "" then
                itemImpl = trim(getFirstStringDeep(itemInfo, { "item_impl", "itemImpl" }))
            end
            if cannotEquip == "" then
                cannotEquip = lowerKey(getFirstStringDeep(itemInfo, { "item_flag_cannot_equip", "itemFlagCannotEquip" }))
            end
        end
    end
    return equipSlot, category, itemImpl, cannotEquip
end

local function resolveIconPath(primary, secondary)
    local iconPath = getFirstString(primary, {
        "iconPath", "icon_path", "icon", "path", "iconKey", "texture", "texturePath", "img"
    })
    if iconPath == "" then
        iconPath = getFirstString(secondary, {
            "iconPath", "icon_path", "icon", "path", "iconKey", "texture", "texturePath", "img"
        })
    end
    return iconPath
end

local function makeItemKey(name, itemType)
    local normalizedName = lowerKey(name)
    if itemType ~= nil then
        if normalizedName ~= "" then
            return "type:" .. tostring(itemType) .. ":name:" .. normalizedName
        end
        return "type:" .. tostring(itemType)
    end
    if normalizedName ~= "" then
        return "name:" .. normalizedName
    end
    return ""
end

resolveBagEntry = function(slotIndex, info, bagType, indexMode)
    if type(info) ~= "table" then
        return nil
    end

    local itemType = getFirstNumberDeep(info, {
        "itemType", "item_type", "itemId", "item_id", "itemTypeId", "item_type_id", "type", "id", "typeId", "type_id"
    })
    local itemInfo = getItemInfoByType(itemType)

    local name = getFirstStringDeep(info, {
        "name", "itemName", "item_name", "displayName", "display_name", "title", "linkText", "link_text", "itemLinkText", "item_link_text", "tooltipText", "tooltip_text"
    })
    if name == "" then
        name = getFirstStringDeep(itemInfo, {
            "name", "itemName", "item_name", "displayName", "display_name", "title", "linkText", "link_text"
        })
    end
    if name ~= "" then
        name = stripLinkText(name)
    end
    if name == "" and itemType ~= nil then
        name = "Item " .. tostring(itemType)
    end
    if name == "" then
        return nil
    end

    local count = getFirstNumberDeep(info, {
        "count", "stack", "stackCount", "stack_count", "itemCount", "item_count", "amount"
    }) or 1

    local searchBlob = table.concat({
        name,
        tostring(itemType or ""),
        getFirstStringDeep(info, { "grade", "equipSlot", "equip_slot", "category" }),
        getFirstStringDeep(itemInfo, { "grade", "equipSlot", "equip_slot", "category" })
    }, " "):lower()

    local equipSlot = trim(getFirstStringDeep(info, { "equipSlot", "equip_slot" }))
    if equipSlot == "" then
        equipSlot = trim(getFirstStringDeep(itemInfo, { "equipSlot", "equip_slot" }))
    end
    local category = trim(getFirstStringDeep(info, { "category", "itemCategory", "item_category" }))
    if category == "" then
        category = trim(getFirstStringDeep(itemInfo, { "category", "itemCategory", "item_category" }))
    end
    local itemImpl = trim(getFirstStringDeep(info, { "item_impl", "itemImpl" }))
    if itemImpl == "" then
        itemImpl = trim(getFirstStringDeep(itemInfo, { "item_impl", "itemImpl" }))
    end
    local cannotEquip = getFirstStringDeep(info, { "item_flag_cannot_equip", "itemFlagCannotEquip" })
    if cannotEquip == "" then
        cannotEquip = getFirstStringDeep(itemInfo, { "item_flag_cannot_equip", "itemFlagCannotEquip" })
    end

    local slotRaw = tonumber(slotIndex)
    local slotZeroBased = nil
    local slotOneBased = nil
    if slotRaw ~= nil then
        if indexMode == "one_based" then
            slotOneBased = slotRaw
            slotZeroBased = slotRaw - 1
        else
            slotZeroBased = slotRaw
            slotOneBased = slotRaw + 1
        end
    end

    return {
        source = "Bag",
        name = name,
        count = count,
        item_type = itemType,
        item_key = makeItemKey(name, itemType),
        icon_path = resolveIconPath(info, itemInfo),
        search = searchBlob,
        equip_slot = equipSlot,
        category = category,
        item_impl = itemImpl,
        item_flag_cannot_equip = lowerKey(cannotEquip),
        bag_type = tonumber(bagType) or 1,
        slot_index = slotRaw,
        slot_index_zero = slotZeroBased,
        slot_index_one = slotOneBased,
        index_mode = trim(indexMode ~= nil and indexMode or "zero_based")
    }
end

local function scanBagEntries()
    if api.Bag == nil or api.Bag.GetBagItemInfo == nil or api.Bag.Capacity == nil then
        return {}
    end

    local capacity = tonumber(safePcall(function()
        return api.Bag:Capacity()
    end)) or 0
    if capacity <= 0 then
        return {}
    end

    local function collectBagType(bagType, rangeStart, rangeEnd, indexMode)
        local out = {}
        for slot = rangeStart, rangeEnd do
            local info = safePcall(function()
                return api.Bag:GetBagItemInfo(bagType, slot)
            end)
            local entry = resolveBagEntry(slot, info, bagType, indexMode)
            if entry ~= nil then
                table.insert(out, entry)
            end
        end
        return out
    end

    local entries = {}
    local seen = {}
    local function mergeEntries(probe)
        for _, entry in ipairs(probe or {}) do
            local dedupeKey = table.concat({
                trim(entry.item_key),
                trim(entry.name),
                tostring(entry.count or 1),
                trim(entry.icon_path)
            }, "|")
            if not seen[dedupeKey] then
                seen[dedupeKey] = entry
                table.insert(entries, entry)
            else
                local existing = seen[dedupeKey]
                if existing ~= nil then
                    if trim(existing.icon_path) == "" then
                        existing.icon_path = trim(entry.icon_path)
                    end
                    if trim(existing.equip_slot) == "" then
                        existing.equip_slot = trim(entry.equip_slot)
                    end
                    if existing.slot_index == nil and entry.slot_index ~= nil then
                        existing.slot_index = entry.slot_index
                        existing.index_mode = entry.index_mode
                    end
                    if existing.slot_index_zero == nil and entry.slot_index_zero ~= nil then
                        existing.slot_index_zero = entry.slot_index_zero
                    end
                    if existing.slot_index_one == nil and entry.slot_index_one ~= nil then
                        existing.slot_index_one = entry.slot_index_one
                    end
                    if existing.bag_type == nil and entry.bag_type ~= nil then
                        existing.bag_type = entry.bag_type
                    end
                end
            end
        end
    end

    for bagType = 1, 6 do
        mergeEntries(collectBagType(bagType, 0, capacity - 1, "zero_based"))
        mergeEntries(collectBagType(bagType, 1, capacity, "one_based"))
    end
    return entries
end

local function scanBankEntries()
    if api.Bank == nil or api.Bank.GetLinkText == nil or api.Bank.Capacity == nil then
        return {}
    end

    local capacity = tonumber(safePcall(function()
        return api.Bank:Capacity()
    end)) or 0
    if capacity <= 0 then
        return {}
    end

    local function collect(rangeStart, rangeEnd)
        local out = {}
        for slot = rangeStart, rangeEnd do
            local linkText = safePcall(function()
                return api.Bank:GetLinkText(slot)
            end)
            local cleaned = stripLinkText(linkText)
            if cleaned ~= "" then
                local itemType = parseItemTypeFromLinkText(cleaned)
                local itemInfo = getItemInfoByType(itemType)
                local itemName = getFirstString(itemInfo, {
                    "name", "itemName", "item_name", "displayName", "display_name", "title"
                })
                local equipSlot = trim(getFirstStringDeep(itemInfo, { "equipSlot", "equip_slot" }))
                local category = trim(getFirstStringDeep(itemInfo, { "category", "itemCategory", "item_category" }))
                local itemImpl = trim(getFirstStringDeep(itemInfo, { "item_impl", "itemImpl" }))
                local cannotEquip = lowerKey(getFirstStringDeep(itemInfo, { "item_flag_cannot_equip", "itemFlagCannotEquip" }))
                if itemName == "" then
                    itemName = cleaned
                end
                table.insert(out, {
                    source = "Bank",
                    name = itemName,
                    count = 1,
                    item_type = itemType,
                    item_key = makeItemKey(itemName, itemType),
                    icon_path = resolveIconPath(nil, itemInfo),
                    equip_slot = equipSlot,
                    category = category,
                    item_impl = itemImpl,
                    item_flag_cannot_equip = cannotEquip,
                    search = table.concat({
                        itemName,
                        tostring(itemType or ""),
                        "bank"
                    }, " "):lower()
                })
            end
        end
        return out
    end

    local entries = collect(0, capacity - 1)
    if #entries == 0 then
        entries = collect(1, capacity)
    end
    return entries
end

local function normalizeSavedEntry(raw)
    if type(raw) ~= "table" then
        return nil
    end
    local name = trim(raw.name)
    local source = trim(raw.source)
    local count = tonumber(raw.count) or 1
    if name == "" then
        return nil
    end
    if source == "" then
        source = "Bag"
    end
    return {
        source = source,
        name = name,
        count = math.max(1, math.floor(count)),
        item_type = tonumber(raw.item_type or raw.itemType),
        item_key = trim(raw.item_key or raw.itemKey or makeItemKey(name, tonumber(raw.item_type or raw.itemType))),
        icon_path = trim(raw.icon_path or raw.iconPath or raw.icon or raw.path or ""),
        equip_slot = trim(raw.equip_slot or raw.equipSlot or ""),
        category = trim(raw.category or raw.itemCategory or raw.item_category or ""),
        item_impl = trim(raw.item_impl or raw.itemImpl or ""),
        item_flag_cannot_equip = lowerKey(raw.item_flag_cannot_equip or raw.itemFlagCannotEquip or ""),
        bag_type = tonumber(raw.bag_type or raw.bagType),
        slot_index = tonumber(raw.slot_index or raw.slotIndex),
        slot_index_zero = tonumber(raw.slot_index_zero or raw.slotIndexZero),
        slot_index_one = tonumber(raw.slot_index_one or raw.slotIndexOne),
        index_mode = trim(raw.index_mode or raw.indexMode or ""),
        search = lowerKey(table.concat({ source, name }, " "))
    }
end

local function normalizeSavedCharacters()
    local settings = ensureSettings()
    local changed = false
    local normalized = {}
    for key, snapshot in pairs(settings.saved_characters or {}) do
        local characterName = trim((type(snapshot) == "table" and snapshot.name) or key)
        if characterName ~= "" then
            local entries = {}
            for _, rawEntry in ipairs((type(snapshot) == "table" and snapshot.entries) or {}) do
                local entry = normalizeSavedEntry(rawEntry)
                if entry ~= nil then
                    table.insert(entries, entry)
                else
                    changed = true
                end
            end
            normalized[characterName] = {
                name = characterName,
                entries = entries,
                saved_at = tonumber(type(snapshot) == "table" and snapshot.saved_at) or 0
            }
        else
            changed = true
        end
    end
    settings.saved_characters = normalized
    return changed
end

local function getSavedCharacterCount()
    local settings = ensureSettings()
    local count = 0
    for _, snapshot in pairs(settings.saved_characters or {}) do
        if type(snapshot) == "table" and trim(snapshot.name) ~= "" then
            count = count + 1
        end
    end
    return count
end

local function normalizeTrackedItems()
    local settings = ensureSettings()
    local changed = false
    local normalized = {}
    for _, raw in ipairs(settings.tracked_items or {}) do
        if type(raw) == "table" then
            local name = trim(raw.name)
            local itemType = tonumber(raw.item_type or raw.itemType)
            local itemKey = trim(raw.item_key or raw.itemKey or makeItemKey(name, itemType))
            local expectedItemKey = makeItemKey(name, itemType)
            local trackedKind = trim(raw.tracked_kind or raw.trackedKind)
            local inferredTrackedKind = isEquippableEntry(raw) and "equip" or "use"
            if expectedItemKey ~= "" and itemKey ~= expectedItemKey then
                itemKey = expectedItemKey
                changed = true
            end
            if trackedKind ~= "equip" and trackedKind ~= "use" then
                trackedKind = inferredTrackedKind
                changed = true
            elseif trackedKind ~= inferredTrackedKind and inferredTrackedKind == "equip" then
                trackedKind = "equip"
                changed = true
            end
            if itemKey ~= "" and name ~= "" then
                table.insert(normalized, {
                    item_key = itemKey,
                    name = name,
                    item_type = itemType,
                    icon_path = trim(raw.icon_path or raw.iconPath or raw.icon or raw.path or ""),
                    equip_slot = trim(raw.equip_slot or raw.equipSlot or ""),
                    category = trim(raw.category or raw.itemCategory or raw.item_category or ""),
                    item_impl = trim(raw.item_impl or raw.itemImpl or ""),
                    item_flag_cannot_equip = lowerKey(raw.item_flag_cannot_equip or raw.itemFlagCannotEquip or ""),
                    tracked_kind = trackedKind
                })
            else
                changed = true
            end
        else
            changed = true
        end
    end
    settings.tracked_items = normalized
    return changed
end

local function getTrackedIndex(itemKey)
    local settings = ensureSettings()
    local lookupKey = trim(itemKey)
    if lookupKey == "" then
        return nil
    end
    for index, tracked in ipairs(settings.tracked_items or {}) do
        if trim(tracked.item_key) == lookupKey then
            return index
        end
    end
    return nil
end

local function isTrackedEntry(entry)
    return getTrackedIndex(entry ~= nil and entry.item_key or "") ~= nil
end

isEquippableEntry = function(entry)
    if type(entry) ~= "table" then
        return false
    end
    local equipSlot, category, itemImpl, cannotEquip = getEquipMetadata(entry)
    if cannotEquip == "true" then
        return false
    end
    if equipSlot ~= "" then
        return true
    end
    local equipText = lowerKey(table.concat({
        tostring(category or ""),
        tostring(itemImpl or ""),
        tostring(entry.name or "")
    }, " "))
    local impl = lowerKey(itemImpl)
    return impl == "weapon"
        or impl == "armor"
        or impl == "accessory"
        or impl == "glider"
        or impl == "magithopter"
        or impl == "shield"
        or impl == "instrument"
        or impl == "mate_armor"
        or impl == "slave_equipment"
        or impl == "butler_armor"
        or string.find(equipText, "glider", 1, true) ~= nil
        or string.find(equipText, "magithopter", 1, true) ~= nil
        or string.find(equipText, "shield", 1, true) ~= nil
        or string.find(equipText, "weapon", 1, true) ~= nil
        or string.find(equipText, "armor", 1, true) ~= nil
        or string.find(equipText, "accessory", 1, true) ~= nil
end

local function isCurrentCharacterBagEntry(entry)
    local currentCharacter = lowerKey(getPlayerName())
    return currentCharacter ~= ""
        and lowerKey(entry ~= nil and entry.character or "") == currentCharacter
        and lowerKey(entry ~= nil and entry.source or "") == "bag"
end

local function aggregateTrackedItems()
    local settings = ensureSettings()
    local totalsByKey = {}
    for _, entry in ipairs(App.inventory_entries or {}) do
        local itemKey = trim(entry.item_key)
        if itemKey ~= "" then
            local bucket = totalsByKey[itemKey]
            if bucket == nil then
                bucket = {
                    item_key = itemKey,
                    name = trim(entry.name),
                    item_type = tonumber(entry.item_type),
                    icon_path = trim(entry.icon_path),
                    tracked_kind = "",
                    count = 0,
                    equip_slot = "",
                    category = "",
                    item_impl = "",
                    item_flag_cannot_equip = "",
                    current_bag_count = 0,
                    live_slot_index = nil,
                    live_slot_index_zero = nil,
                    live_slot_index_one = nil,
                    live_index_mode = "",
                    live_bag_type = nil
                }
                totalsByKey[itemKey] = bucket
            end
            bucket.count = bucket.count + math.max(1, math.floor(tonumber(entry.count) or 1))
            if bucket.icon_path == "" then
                bucket.icon_path = trim(entry.icon_path)
            end
            if bucket.tracked_kind == "" then
                bucket.tracked_kind = isEquippableEntry(entry) and "equip" or "use"
            end
            if bucket.equip_slot == "" then
                bucket.equip_slot = trim(entry.equip_slot)
            end
            if bucket.category == "" then
                bucket.category = trim(entry.category)
            end
            if bucket.item_impl == "" then
                bucket.item_impl = trim(entry.item_impl)
            end
            if bucket.item_flag_cannot_equip == "" then
                bucket.item_flag_cannot_equip = lowerKey(entry.item_flag_cannot_equip)
            end
            if isCurrentCharacterBagEntry(entry) then
                bucket.current_bag_count = bucket.current_bag_count + math.max(1, math.floor(tonumber(entry.count) or 1))
                if trim(entry.name) ~= "" then
                    bucket.name = trim(entry.name)
                end
                if tonumber(entry.item_type) ~= nil then
                    bucket.item_type = tonumber(entry.item_type)
                end
                if trim(entry.icon_path) ~= "" then
                    bucket.icon_path = trim(entry.icon_path)
                end
                if bucket.live_slot_index == nil and tonumber(entry.slot_index) ~= nil then
                    bucket.live_slot_index = tonumber(entry.slot_index)
                    bucket.live_index_mode = trim(entry.index_mode)
                end
                if bucket.live_slot_index_zero == nil and tonumber(entry.slot_index_zero) ~= nil then
                    bucket.live_slot_index_zero = tonumber(entry.slot_index_zero)
                end
                if bucket.live_slot_index_one == nil and tonumber(entry.slot_index_one) ~= nil then
                    bucket.live_slot_index_one = tonumber(entry.slot_index_one)
                end
                if bucket.live_bag_type == nil and tonumber(entry.bag_type) ~= nil then
                    bucket.live_bag_type = tonumber(entry.bag_type)
                end
                if bucket.equip_slot == "" then
                    bucket.equip_slot = trim(entry.equip_slot)
                end
                if bucket.category == "" then
                    bucket.category = trim(entry.category)
                end
                if bucket.item_impl == "" then
                    bucket.item_impl = trim(entry.item_impl)
                end
                if bucket.item_flag_cannot_equip == "" then
                    bucket.item_flag_cannot_equip = lowerKey(entry.item_flag_cannot_equip)
                end
            end
        end
    end

    local out = {}
    for _, tracked in ipairs(settings.tracked_items or {}) do
        local itemKey = trim(tracked.item_key)
        if itemKey ~= "" then
            local aggregate = totalsByKey[itemKey] or {
                item_key = itemKey,
                name = trim(tracked.name),
                item_type = tonumber(tracked.item_type),
                icon_path = trim(tracked.icon_path),
                tracked_kind = "",
                count = 0,
                equip_slot = "",
                category = "",
                item_impl = "",
                item_flag_cannot_equip = "",
                current_bag_count = 0,
                live_slot_index = nil,
                live_slot_index_zero = nil,
                live_slot_index_one = nil,
                live_index_mode = "",
                live_bag_type = nil
            }
            if aggregate.name == "" then
                aggregate.name = trim(tracked.name)
            end
            if aggregate.icon_path == "" then
                aggregate.icon_path = trim(tracked.icon_path)
            end
            if aggregate.tracked_kind == "" then
                local trackedKind = trim(tracked.tracked_kind or tracked.trackedKind)
                if trackedKind ~= "equip" and trackedKind ~= "use" then
                    trackedKind = isEquippableEntry(tracked) and "equip" or "use"
                end
                aggregate.tracked_kind = trackedKind
            end
            if aggregate.equip_slot == "" then
                aggregate.equip_slot = trim(tracked.equip_slot or tracked.equipSlot)
            end
            if aggregate.category == "" then
                aggregate.category = trim(tracked.category or tracked.itemCategory or tracked.item_category)
            end
            if aggregate.item_impl == "" then
                aggregate.item_impl = trim(tracked.item_impl or tracked.itemImpl)
            end
            if aggregate.item_flag_cannot_equip == "" then
                aggregate.item_flag_cannot_equip = lowerKey(tracked.item_flag_cannot_equip or tracked.itemFlagCannotEquip)
            end
            aggregate.is_equippable = trim(aggregate.tracked_kind) == "equip"
            aggregate.has_live_bag_entry = aggregate.current_bag_count > 0
            table.insert(out, aggregate)
        end
    end
    return out
end

local function makeSearchEntry(character, entry)
    local source = trim(entry.source or "")
    local name = trim(entry.name or "")
    local count = tonumber(entry.count) or 1
    if name == "" then
        return nil
    end
    return {
        character = trim(character or ""),
        source = source ~= "" and source or "Bag",
        name = name,
        count = math.max(1, math.floor(count)),
        item_type = tonumber(entry.item_type or entry.itemType),
        item_key = trim(entry.item_key or entry.itemKey or makeItemKey(name, tonumber(entry.item_type or entry.itemType))),
        icon_path = trim(entry.icon_path or entry.iconPath or entry.icon or entry.path or ""),
        equip_slot = trim(entry.equip_slot or entry.equipSlot or ""),
        category = trim(entry.category or entry.itemCategory or entry.item_category or ""),
        item_impl = trim(entry.item_impl or entry.itemImpl or ""),
        item_flag_cannot_equip = lowerKey(entry.item_flag_cannot_equip or entry.itemFlagCannotEquip or ""),
        bag_type = tonumber(entry.bag_type or entry.bagType),
        slot_index = tonumber(entry.slot_index or entry.slotIndex),
        slot_index_zero = tonumber(entry.slot_index_zero or entry.slotIndexZero),
        slot_index_one = tonumber(entry.slot_index_one or entry.slotIndexOne),
        index_mode = trim(entry.index_mode or entry.indexMode or ""),
        search = lowerKey(table.concat({
            trim(character or ""),
            source,
            name,
            tostring(count)
        }, " "))
    }
end

local function buildCurrentCharacterSnapshot()
    local entries = {}
    for _, entry in ipairs(scanBagEntries()) do
        table.insert(entries, entry)
    end
    for _, entry in ipairs(scanBankEntries()) do
        table.insert(entries, entry)
    end
    return entries
end

local function getTrackedBagCountSignature()
    local settings = ensureSettings()
    if api.Bag == nil or api.Bag.CountBagItemByItemType == nil then
        return ""
    end
    local parts = {}
    for _, tracked in ipairs(settings.tracked_items or {}) do
        local itemType = tonumber(tracked.item_type or tracked.itemType)
        if itemType ~= nil then
            local count = tonumber(safePcall(function()
                return api.Bag:CountBagItemByItemType(itemType)
            end)) or 0
            table.insert(parts, tostring(itemType) .. ":" .. tostring(count))
        end
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

local function matchesQuery(entry, query)
    if query == "" then
        return true
    end
    return string.find(entry.search or "", query, 1, true) ~= nil
end

local function sortResults(results)
    table.sort(results, function(a, b)
        local aName = lowerKey(a.name)
        local bName = lowerKey(b.name)
        if aName ~= bName then
            return aName < bName
        end
        local aCharacter = lowerKey(a.character)
        local bCharacter = lowerKey(b.character)
        if aCharacter ~= bCharacter then
            return aCharacter < bCharacter
        end
        local aSource = lowerKey(a.source)
        local bSource = lowerKey(b.source)
        if aSource ~= bSource then
            return aSource < bSource
        end
        return (tonumber(a.count) or 0) > (tonumber(b.count) or 0)
    end)
end

local function buildResults()
    local settings = ensureSettings()
    local currentCharacter = getPlayerName()
    local query = lowerKey(settings.query)
    local allEntries = {}
    local out = {}

    for _, entry in ipairs(scanBagEntries()) do
        local result = makeSearchEntry(currentCharacter, entry)
        if result ~= nil then
            table.insert(allEntries, result)
        end
    end

    if settings.include_bank then
        for _, entry in ipairs(scanBankEntries()) do
            local result = makeSearchEntry(currentCharacter, entry)
            if result ~= nil then
                table.insert(allEntries, result)
            end
        end
    end

    for characterName, snapshot in pairs(settings.saved_characters or {}) do
        if trim(characterName) ~= "" and lowerKey(characterName) ~= lowerKey(currentCharacter) then
            for _, entry in ipairs((type(snapshot) == "table" and snapshot.entries) or {}) do
                if settings.include_bank or lowerKey(entry.source) ~= "bank" then
                    local result = makeSearchEntry(characterName, entry)
                    if result ~= nil then
                        table.insert(allEntries, result)
                    end
                end
            end
        end
    end

    App.inventory_entries = allEntries
    for _, result in ipairs(allEntries) do
        if matchesQuery(result, query) then
            table.insert(out, result)
        end
    end
    sortResults(out)
    App.results = out
end

    return {
        scanBagEntries = scanBagEntries,
        scanBankEntries = scanBankEntries,
        buildCurrentCharacterSnapshot = buildCurrentCharacterSnapshot,
        getTrackedBagCountSignature = getTrackedBagCountSignature,
        normalizeSavedCharacters = normalizeSavedCharacters,
        getSavedCharacterCount = getSavedCharacterCount,
        normalizeTrackedItems = normalizeTrackedItems,
        getTrackedIndex = getTrackedIndex,
        isTrackedEntry = isTrackedEntry,
        isEquippableEntry = isEquippableEntry,
        aggregateTrackedItems = aggregateTrackedItems,
        buildResults = buildResults
    }
end

return {
    Create = Create
}
