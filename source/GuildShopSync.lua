-- GuildShopSync v2.5

local scanning = false
local scanIndex = 0
local scanPrices = {}

local ITEMS = {
    -- Protection & Utility
    {id = "GFPP", name = "Greater Fire Protection Potion"},
    {id = "GAPP", name = "Greater Arcane Protection Potion"},
    {id = "GNPP", name = "Greater Nature Protection Potion"},
    {id = "GFROP", name = "Greater Frost Protection Potion"},
    {id = "GSPP", name = "Greater Shadow Protection Potion"},
    {id = "SPP", name = "Shadow Protection Potion"},
    {id = "LIP", name = "Limited Invulnerability Potion"},
    {id = "FAP", name = "Free Action Potion"},
    {id = "LAP", name = "Living Action Potion"},
    {id = "Restorative", name = "Restorative Potion"},
    {id = "Invisibility", name = "Invisibility Potion"},
    {id = "Swiftness", name = "Swiftness Potion"},
    {id = "Purification", name = "Purification Potion"},
    {id = "Quickness", name = "Potion of Quickness"},
    {id = "MagicResistance", name = "Magic Resistance Potion"},
    {id = "MajorHealing", name = "Major Healing Potion"},
    -- Tank & Melee
    {id = "Mongoose", name = "Elixir of the Mongoose"},
    {id = "GreaterAgility", name = "Elixir of Greater Agility"},
    {id = "Giants", name = "Elixir of Giants"},
    {id = "MightyRage", name = "Mighty Rage Potion"},
    {id = "GreaterStoneshield", name = "Greater Stoneshield Potion"},
    {id = "Fortitude", name = "Elixir of Fortitude"},
    {id = "SuperiorDefense", name = "Elixir of Superior Defense"},
    {id = "TrollsBlood", name = "Major Troll's Blood Potion"},
    {id = "GiftOfArthas", name = "Gift of Arthas"},
    {id = "OilOfImmolation", name = "Oil of Immolation"},
    {id = "ThistleTea", name = "Thistle Tea"},
    {id = "GoblinSapper", name = "Goblin Sapper Charge"},
    {id = "WinterfallFirewater", name = "Winterfall Firewater"},
    -- Caster
    {id = "Mageblood", name = "Mageblood Potion"},
    {id = "GAE", name = "Greater Arcane Elixir"},
    {id = "ArcaneElixir", name = "Arcane Elixir"},
    {id = "MajorMana", name = "Major Mana Potion"},
    {id = "GFW", name = "Elixir of Greater Firepower"},
    {id = "GSP", name = "Elixir of Shadow Power"},
    {id = "GFrostP", name = "Elixir of Frost Power"},
    {id = "GNP", name = "Elixir of Greater Nature Power"},
    {id = "Dreamshard", name = "Dreamshard Elixir"},
    {id = "DarkRune", name = "Dark Rune"},
    -- Weapon Buffs
    {id = "BrilliantManaOil", name = "Brilliant Mana Oil"},
    {id = "BlessedWizardOil", name = "Blessed Wizard Oil"},
    {id = "FrostOil", name = "Frost Oil"},
    {id = "ElementalStone", name = "Elemental Sharpening Stone"},
    {id = "BrilliantWizardOil", name = "Brilliant Wizard Oil"},
    {id = "DenseSharpeningStone", name = "Dense Sharpening Stone"},
    -- Food & Drink
    {id = "GrilledSquid", name = "Grilled Squid"},
    {id = "HerbalSalad", name = "Empowering Herbal Salad"},
    {id = "NightfinSoup", name = "Nightfin Soup"},
    {id = "HardenedMushroom", name = "Hardened Mushroom"},
    {id = "LeFishe", name = "Le Fishe Au Chocolat"},
    {id = "MedivhMerlot", name = "Medivh's Merlot"},
    {id = "MedivhMerlotBlue", name = "Medivh's Merlot Blue"},
    {id = "DragonbreathChili", name = "Dragonbreath Chili"},
    {id = "DanozoDelight", name = "Danonzo's Tel'Abim Delight"},
    {id = "DanozoSurprise", name = "Danonzo's Tel'Abim Surprise"},
    {id = "DanozoMedley", name = "Danonzo's Tel'Abim Medley"},
    {id = "PowerMushroom", name = "Power Mushroom"},
    {id = "SmokedDesertDumplings", name = "Smoked Desert Dumplings"},
    {id = "GilneasHotStew", name = "Gilneas Hot Stew"},
    {id = "RumseyRumBlackLabel", name = "Rumsey Rum Black Label"},
    -- Concoctions (Turtle WoW custom)
    {id = "EmeraldMongoose", name = "Concoction of the Emerald Mongoose"},
    {id = "ArcaneGiant", name = "Concoction of the Arcane Giant"},
    {id = "Dreamwater", name = "Concoction of the Dreamwater"},
    {id = "ElixirOfDemonslaying", name = "Elixir of Demonslaying"},
    {id = "ElixirOfBruteForce", name = "Elixir of Brute Force"},
    {id = "Dreamtonic", name = "Dreamtonic"},
}

local function Msg(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[GuildShop]|r " .. text)
end

-- Reload popup frame
local reloadPopup = CreateFrame("Frame", "GuildShopSyncReloadPopup", UIParent)
reloadPopup:SetWidth(300)
reloadPopup:SetHeight(100)
reloadPopup:SetPoint("CENTER", 0, 100)
reloadPopup:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
reloadPopup:SetBackdropColor(0, 0, 0, 1)
reloadPopup:SetFrameStrata("DIALOG")
reloadPopup:EnableMouse(true)
reloadPopup:SetMovable(true)
reloadPopup:RegisterForDrag("LeftButton")
reloadPopup:SetScript("OnDragStart", function() this:StartMoving() end)
reloadPopup:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
reloadPopup:Hide()

local popupTitle = reloadPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
popupTitle:SetPoint("TOP", 0, -15)
popupTitle:SetText("|cFF00FF00Scan Complete!|r")

local popupText = reloadPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
popupText:SetPoint("TOP", 0, -35)
popupText:SetText("Click below to save & sync prices")

local reloadBtn = CreateFrame("Button", nil, reloadPopup, "UIPanelButtonTemplate")
reloadBtn:SetWidth(140)
reloadBtn:SetHeight(25)
reloadBtn:SetPoint("BOTTOM", 0, 15)
reloadBtn:SetText("Reload UI & Sync")
reloadBtn:SetScript("OnClick", function()
    reloadPopup:Hide()
    ReloadUI()
end)

local function ShowReloadPopup(count)
    popupTitle:SetText("|cFF00FF00Scan Complete!|r " .. count .. " prices")
    reloadPopup:Show()
end

local function FinishScan()
    scanning = false
    if not GuildShopSyncDB then
        GuildShopSyncDB = {}
    end
    if not GuildShopSyncDB.prices then
        GuildShopSyncDB.prices = {}
    end
    local count = 0
    for k, v in pairs(scanPrices) do
        GuildShopSyncDB.prices[k] = v
        count = count + 1
    end
    GuildShopSyncDB.triggerUpload = true
    GuildShopSyncDB.lastSync = date("%Y-%m-%d %H:%M:%S")
    Msg("|cFF00FF00Done!|r " .. count .. " prices saved.")
    Msg("|cFFFFFF00Click the popup to reload & sync to website!|r")
    ShowReloadPopup(count)
end

local function ProcessResults()
    local item = ITEMS[scanIndex]
    if not item then return end

    local lowest = nil
    local n = GetNumAuctionItems("list")
    for i = 1, n do
        local name, _, cnt, _, _, _, _, _, bo = GetAuctionItemInfo("list", i)
        if name and bo and bo > 0 and strlower(name) == strlower(item.name) then
            local per = math.floor(bo / cnt)
            if not lowest or per < lowest then
                lowest = per
            end
        end
    end

    if lowest then
        scanPrices[item.id] = lowest
        local g = math.floor(lowest / 10000)
        local s = math.floor(math.mod(lowest, 10000) / 100)
        Msg("|cFF00FF00" .. item.id .. "|r: " .. g .. "g " .. s .. "s")
    else
        Msg("|cFFAAAAAA" .. item.id .. "|r: not on AH")
    end
end

local scanState = "idle"

local scanFrame = CreateFrame("Frame")
scanFrame:Hide()
scanFrame:SetScript("OnUpdate", function()
    if not scanning then
        this:Hide()
        return
    end

    if scanState == "waiting_for_query" then
        if CanSendAuctionQuery() then
            local item = ITEMS[scanIndex]
            Msg("Scanning: " .. item.name .. " (" .. scanIndex .. "/" .. table.getn(ITEMS) .. ")")
            QueryAuctionItems(item.name, nil, nil, nil, nil, nil, 0, 0, 0)
            scanState = "waiting_for_results"
        end
    end
end)

local function NextItem()
    scanIndex = scanIndex + 1
    if scanIndex > table.getn(ITEMS) then
        FinishScan()
        scanFrame:Hide()
    else
        scanState = "waiting_for_query"
        scanFrame:Show()
    end
end

local function StartScan()
    if scanning then
        Msg("Already scanning...")
        return
    end
    if not aux_frame or not aux_frame:IsVisible() then
        Msg("|cFFFF0000Open Auction House first!|r")
        return
    end
    scanning = true
    scanIndex = 0
    scanPrices = {}
    scanState = "idle"
    reloadPopup:Hide()
    Msg("Scanning " .. table.getn(ITEMS) .. " items...")
    NextItem()
end

local function MakeButton()
    if GuildShopSyncBtn then return end
    if not aux_frame then return end

    local b = CreateFrame("Button", "GuildShopSyncBtn", aux_frame, "UIPanelButtonTemplate")
    b:SetWidth(90)
    b:SetHeight(24)
    b:SetText("Sync Prices")
    b:SetPoint("BOTTOMRIGHT", aux_frame, "BOTTOMRIGHT", -160, 5)
    b:SetFrameStrata("DIALOG")
    b:SetScript("OnClick", StartScan)
    b:Show()
    Msg("|cFF00FF00Button ready!|r")
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
f:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "GuildShopSync" then
        if not GuildShopSyncDB then
            GuildShopSyncDB = {}
        end
        if not GuildShopSyncDB.prices then
            GuildShopSyncDB.prices = {}
        end
        Msg("v2.5 loaded - /gss help")
    end
    if event == "AUCTION_HOUSE_SHOW" then
        MakeButton()
    end
    if event == "AUCTION_ITEM_LIST_UPDATE" then
        if scanning and scanState == "waiting_for_results" then
            ProcessResults()
            NextItem()
        end
    end
end)

SLASH_GSS1 = "/gss"
SlashCmdList["GSS"] = function(m)
    if m == "scan" then
        StartScan()
    elseif m == "debug" then
        Msg("aux_frame: " .. tostring(aux_frame ~= nil))
        Msg("scanning: " .. tostring(scanning))
        Msg("scanState: " .. scanState)
        Msg("scanIndex: " .. scanIndex)
        Msg("Total items: " .. table.getn(ITEMS))
    elseif m == "stop" then
        scanning = false
        scanState = "idle"
        reloadPopup:Hide()
        Msg("Scan stopped.")
    else
        Msg("/gss scan - Start scanning")
        Msg("/gss stop - Stop scanning")
        Msg("/gss debug - Debug info")
    end
end
