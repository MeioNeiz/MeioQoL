-- Options panel (Esc > Options > AddOns > MeioQoL, or /qol). A section per feature, each
-- checkbox in the words of its chat toggle; settings write straight into MeioQoLDB.
local _, ns = ...

local category

local function Header(layout, title, tip)
    if layout and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(title, tip))
    end
end

local toggles = {}
for _, t in ipairs(ns.TOGGLES) do toggles[t.key] = t end

local function Checkbox(key)
    local t = toggles[key]
    local setting = Settings.RegisterAddOnSetting(category, "MEIOQOL_" .. key:upper(), key,
        ns.db, Settings.VarType.Boolean, t.label, ns.DEFAULTS[key])
    Settings.CreateCheckbox(category, setting, t.tip .. " /qol " .. t.cmd .. " on||off")
end

local function Register()
    if category or not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory("MeioQoL")

    Header(layout, "NPC chat", "Skip the chat window when an NPC has nothing to say but one "
        .. "option. Hold Shift to talk normally.")
    Checkbox("gossip")
    Checkbox("gossipServices")

    Header(layout, "Resurrection", "Accept a resurrection without clicking.")
    Checkbox("res")

    Header(layout, "Looting", "Auto loot without waiting on the loot window.")
    Checkbox("fastLoot")

    Header(layout, "Repair", "FlareUI's auto repair pays from your own gold; this pays from "
        .. "the guild bank first.")
    Checkbox("guildRepair")

    Header(layout, "Vendor restock", "Alt-click an item at a vendor to keep a stack of it, "
        .. "Alt-click again to stop. /qol restock <item> <n> sets any amount, /qol restock "
        .. "lists them.")
    Checkbox("restock")
    if Settings.CreateSlider and Settings.CreateSliderOptions then
        local setting = Settings.RegisterAddOnSetting(category, "MEIOQOL_RESERVE", "reserve",
            ns.db, Settings.VarType.Number, "Gold to keep", ns.DEFAULTS.reserve)
        local options = Settings.CreateSliderOptions(0, 200, 1)
        if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
                function(v) return v .. "g" end)
        end
        Settings.CreateSlider(category, setting, options, "Restocking stops buying before "
            .. "your gold would drop below this (after paying for a repair). /qol reserve "
            .. "<gold>")
    end
    if CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer("Restock items", "List in chat",
            ns.RestockList, "Print the items this character keeps topped up and how many "
                .. "you have. /qol restock", true))
    end
    Settings.RegisterAddOnCategory(category)
end

ns.On("PLAYER_LOGIN", function()
    local ok, err = pcall(Register)
    if not ok then geterrorhandler()(err) end
end)

function ns.OpenSettings()
    if not category then return false end
    Settings.OpenToCategory(category:GetID())
    return true
end
