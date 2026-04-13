local api = require("api")
local Shared = require("nuzi-inventory/shared")

local Helpers = {}

function Helpers.AttachImage(widget, path, layer, width, height, anchorTo, x, y)
    if widget == nil or path == nil then
        return nil
    end
    local drawable = Shared.SafePcall(function()
        if widget.CreateImageDrawable ~= nil then
            return widget:CreateImageDrawable(path, layer or "artwork")
        end
        if widget.CreateDrawable ~= nil then
            return widget:CreateDrawable(path, layer or "artwork")
        end
        return nil
    end)
    if drawable == nil then
        return nil
    end
    Shared.SafeSetTexture(drawable, path)
    if drawable.AddAnchor ~= nil then
        pcall(function()
            drawable:AddAnchor(anchorTo or "CENTER", widget, x or 0, y or 0)
        end)
    end
    if drawable.SetExtent ~= nil then
        pcall(function()
            drawable:SetExtent(width or 24, height or 24)
        end)
    end
    return drawable
end

function Helpers.CreatePanel(parent, id, x, y, width, height, color)
    local panel = api.Interface:CreateWidget("emptywidget", id, parent)
    if panel == nil then
        return nil
    end
    panel:AddAnchor("TOPLEFT", x, y)
    panel:SetExtent(width or 100, height or 100)
    if panel.CreateNinePartDrawable ~= nil and TEXTURE_PATH ~= nil and TEXTURE_PATH.HUD ~= nil then
        local background = Shared.SafePcall(function()
            return panel:CreateNinePartDrawable(TEXTURE_PATH.HUD, "background")
        end)
        if background ~= nil then
            if background.SetTextureInfo ~= nil then
                pcall(function()
                    background:SetTextureInfo("bg_quest")
                end)
            end
            local tint = color or { 0.05, 0.04, 0.03, 0.82 }
            Shared.SafeSetColor(background, tint[1], tint[2], tint[3], tint[4])
            pcall(function()
                background:AddAnchor("TOPLEFT", panel, 0, 0)
                background:AddAnchor("BOTTOMRIGHT", panel, 0, 0)
            end)
            panel.bg = background
        end
    end
    return panel
end

function Helpers.CreateLabel(parent, id, text, x, y, width, fontSize)
    local label = api.Interface:CreateWidget("label", id, parent)
    if label == nil then
        return nil
    end
    label:AddAnchor("TOPLEFT", x, y)
    label:SetExtent(width or 180, 18)
    Shared.SafeSetText(label, text or "")
    if label.style ~= nil then
        if label.style.SetFontSize ~= nil then
            label.style:SetFontSize(fontSize or 13)
        end
        if label.style.SetAlign ~= nil then
            label.style:SetAlign(ALIGN.LEFT)
        end
    end
    return label
end

function Helpers.CreateButton(parent, id, text, x, y, width, height)
    local button = api.Interface:CreateWidget("button", id, parent)
    if button == nil then
        return nil
    end
    button:AddAnchor("TOPLEFT", x, y)
    button:SetExtent(width or 100, height or 28)
    Shared.SafeSetText(button, text or "")
    if api.Interface ~= nil and api.Interface.ApplyButtonSkin ~= nil then
        pcall(function()
            api.Interface:ApplyButtonSkin(button, BUTTON_BASIC.DEFAULT)
        end)
    end
    return button
end

function Helpers.CreateItemSlot(id, parent)
    if type(CreateItemIconButton) ~= "function" or parent == nil then
        return nil
    end
    local icon = Shared.SafePcall(function()
        return CreateItemIconButton(id, parent)
    end)
    if icon == nil then
        return nil
    end
    if F_SLOT ~= nil and F_SLOT.ApplySlotSkin ~= nil and SLOT_STYLE ~= nil and icon.back ~= nil then
        local style = SLOT_STYLE.DEFAULT or SLOT_STYLE.ITEM or SLOT_STYLE.BUFF
        if style ~= nil then
            pcall(function()
                F_SLOT.ApplySlotSkin(icon, icon.back, style)
            end)
        end
    end
    Shared.SafeShow(icon, true)
    return icon
end

function Helpers.SafeSetItemIcon(icon, path)
    if icon == nil then
        return
    end
    local texturePath = Shared.Trim(path)
    if texturePath == "" then
        return
    end
    if icon.__nuzi_item_icon_path ~= texturePath then
        icon.__nuzi_item_icon_path = texturePath
        if F_SLOT ~= nil and F_SLOT.SetIconBackGround ~= nil then
            pcall(function()
                F_SLOT.SetIconBackGround(icon, texturePath)
            end)
        end
    end
end

function Helpers.CreateVisualItemIcon(id, parent)
    if api.Interface == nil or api.Interface.CreateWidget == nil or parent == nil then
        return nil
    end
    local widget = Shared.SafePcall(function()
        return api.Interface:CreateWidget("emptywidget", id, parent)
    end)
    if widget == nil then
        return nil
    end
    widget:SetExtent(34, 34)
    if widget.EnablePick ~= nil then
        pcall(function()
            widget:EnablePick(false)
        end)
    end
    widget.bg = nil
    if widget.CreateNinePartDrawable ~= nil and TEXTURE_PATH ~= nil and TEXTURE_PATH.HUD ~= nil then
        widget.bg = Shared.SafePcall(function()
            return widget:CreateNinePartDrawable(TEXTURE_PATH.HUD, "background")
        end)
        if widget.bg ~= nil then
            if widget.bg.SetTextureInfo ~= nil then
                pcall(function()
                    widget.bg:SetTextureInfo("bg_quest")
                end)
            end
            Shared.SafeSetColor(widget.bg, 0.08, 0.06, 0.04, 0.82)
            pcall(function()
                widget.bg:AddAnchor("TOPLEFT", widget, 0, 0)
                widget.bg:AddAnchor("BOTTOMRIGHT", widget, 0, 0)
            end)
        end
    end
    widget.icon = nil
    return widget
end

function Helpers.SafeSetVisualIcon(widget, path)
    if widget == nil then
        return
    end
    local texturePath = Shared.Trim(path)
    if widget.icon == nil and texturePath ~= "" then
        widget.icon = Helpers.AttachImage(widget, texturePath, "artwork", 28, 28, "CENTER", 0, 0)
    end
    if widget.icon ~= nil and widget.icon.SetTexture ~= nil then
        pcall(function()
            widget.icon:SetTexture(texturePath)
        end)
    end
end

function Helpers.CreateIconLauncherWindow(id, path, width, height, offsetX, offsetY)
    if api.Interface == nil or api.Interface.CreateEmptyWindow == nil then
        return nil
    end
    local window = Shared.SafePcall(function()
        return api.Interface:CreateEmptyWindow(id, "UIParent")
    end)
    if window == nil then
        return nil
    end
    window:SetExtent(width or 42, height or 42)
    window:AddAnchor("TOPLEFT", "UIParent", offsetX or 0, offsetY or 0)
    if window.SetUILayer ~= nil then
        pcall(function()
            window:SetUILayer("game")
        end)
    end

    local background = nil
    if window.CreateImageDrawable ~= nil and api.baseDir ~= nil then
        background = Shared.SafePcall(function()
            return window:CreateImageDrawable(id .. ".bg", "background")
        end)
        if background ~= nil then
            pcall(function()
                background:SetTexture(api.baseDir .. "/" .. path)
                background:AddAnchor("TOPLEFT", window, 0, 0)
                background:SetExtent(width or 42, height or 42)
                background:Show(true)
            end)
        end
    end

    local clickButton = nil
    if window.CreateChildWidget ~= nil then
        clickButton = Shared.SafePcall(function()
            return window:CreateChildWidget("button", id .. ".click", 0, true)
        end)
        if clickButton ~= nil then
            pcall(function()
                clickButton:AddAnchor("TOPLEFT", window, 0, 0)
                clickButton:AddAnchor("BOTTOMRIGHT", window, 0, 0)
                clickButton:Show(true)
                clickButton:Enable(true)
            end)
        end
    end

    window.bg = background
    window.clickButton = clickButton
    return window
end

function Helpers.CreateEdit(parent, id, guideText, x, y, width, height, maxLen)
    local edit = nil
    if W_CTRL ~= nil and W_CTRL.CreateEdit ~= nil then
        edit = W_CTRL.CreateEdit(id, parent)
    end
    if edit == nil then
        return nil
    end
    edit:AddAnchor("TOPLEFT", x, y)
    if edit.SetExtent ~= nil then
        edit:SetExtent(width or 220, height or 28)
    end
    if edit.SetMaxTextLength ~= nil then
        edit:SetMaxTextLength(maxLen or 64)
    end
    if guideText ~= nil and edit.CreateGuideText ~= nil then
        edit:CreateGuideText(guideText)
    end
    return edit
end

function Helpers.GetEditText(edit)
    if edit == nil or edit.GetText == nil then
        return ""
    end
    local value = Shared.SafePcall(function()
        return edit:GetText()
    end)
    return Shared.Trim(value or "")
end

function Helpers.SetEditText(edit, text)
    if edit ~= nil and edit.SetText ~= nil then
        pcall(function()
            edit:SetText(tostring(text or ""))
        end)
    end
end

return Helpers

