-- Options panel (Esc > Options > AddOns > MeioQoL, or /qol). Built from ns.TOGGLES in help
-- order: a header where a toggle starts a section, each checkbox in the words of its chat
-- toggle; settings write straight into MeioQoLDB.
local _, ns = ...

local category, layout

local function Header(title, tip)
    if layout and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(title, tip))
    end
end

local function Button(name, label, fn, tip)
    if not CreateSettingsButtonInitializer then return end
    local b = CreateSettingsButtonInitializer(name, label, fn, tip, true)
    layout:AddInitializer(b)
    return b
end

local function Checkbox(t)
    local setting = Settings.RegisterAddOnSetting(category, "MEIOQOL_" .. t.key:upper(), t.key,
        ns.db, Settings.VarType.Boolean, t.label, ns.DEFAULTS[t.key])
    if setting.SetValueChangedCallback then
        setting:SetValueChangedCallback(function() ns.Changed(t.key) end)
    end
    local tip = t.tip .. " /qol " .. t.cmd .. " on||off"
    if ns.FLARE[t.key] then
        tip = tip .. "\n\nWaits while FlareUI's own copy is on: /qol takeover swaps them."
    end
    return Settings.CreateCheckbox(category, setting, tip)
end

local function Slider(key, name, min, max, step, format, tip, changed)
    if not (Settings.CreateSlider and Settings.CreateSliderOptions) then return end
    local setting = Settings.RegisterAddOnSetting(category, "MEIOQOL_" .. key:upper(), key,
        ns.db, Settings.VarType.Number, name, ns.DEFAULTS[key])
    if changed and setting.SetValueChangedCallback then
        setting:SetValueChangedCallback(changed)
    end
    local options = Settings.CreateSliderOptions(min, max, step)
    if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, format)
    end
    return Settings.CreateSlider(category, setting, options, tip)
end

local function Child(init, parent, key)
    if init and init.SetParentInitializer and parent then
        init:SetParentInitializer(parent, function() return ns.db[key] end)
    end
end

local function Register()
    if category or not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
    category, layout = Settings.RegisterVerticalLayoutCategory("MeioQoL")
    local made = {}
    for _, t in ipairs(ns.TOGGLES) do
        if t.section then Header(t.section, t.sectionTip) end
        made[t.key] = Checkbox(t)
        if t.key == "lowWarn" then
            Slider("reserve", "Gold to keep", 0, 200, 1, function(v) return v .. "g" end,
                "Restocking stops buying before your gold would drop below this (after "
                    .. "paying for a repair). /qol reserve <gold>")
            Button("Restock items", "List in chat", ns.RestockList, "Print the items this "
                .. "character keeps topped up and how many you have. /qol restock")
        elseif t.key == "inviteFriends" then
            Child(made.inviteFriends, made.inviteDecline, "inviteDecline")
            Child(Button("Whisper a reason", "Edit message", ns.EditInviteReason, "A short "
                .. "message whispered to whoever's invite is declined, at most once in 5 "
                .. "minutes each. Empty: no whisper. /qol invitereason <text>"),
                made.inviteDecline, "inviteDecline")
        elseif t.key == "camera" then
            local function Changed() ns.Changed("camera") end
            Child(Slider("cameraZoom", "Camera distance", 1, 2.6, 0.1,
                function(v) return ("%.1f"):format(v) end, "How far the camera can zoom "
                    .. "out: 1 is Blizzard's usual limit, 2.6 the most the game allows. "
                    .. "/qol camera <distance> <speed>", Changed), made.camera, "camera")
            Child(Slider("cameraSpeed", "Zoom speed", 5, 50, 5, tostring, "How fast the "
                .. "camera zooms as you scroll: 20 is Blizzard's. /qol camera <distance> "
                .. "<speed>", Changed), made.camera, "camera")
        end
    end
    Header("FlareUI", "Where FlareUI has its own copy of one of these, ours waits while "
        .. "FlareUI's is on.")
    Button("Use MeioQoL's", "Take over", ns.TakeOver, "Turn off FlareUI's copies of the "
        .. "ones that are on here, so ours do the job. /qol takeover")
    Button("Use FlareUI's", "Give back", ns.GiveBack, "Turn FlareUI's copies back on, as "
        .. "they were before Take over. /qol flare")
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
