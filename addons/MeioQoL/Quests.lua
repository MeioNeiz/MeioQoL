-- Accepts offered quests and hands in finished ones as you talk to the NPC, one per window:
-- each pick opens the next window, which picks again. Shift does it by hand.
local _, ns = ...

-- battleground marks are kept for other rewards: a quest that takes them is handed in by hand
local MARKS = { [20558] = true, [20559] = true, [20560] = true }

local function On(key)
    return ns.Active(key) and not IsShiftKeyDown()
end

-- the offer's own flags first: the quest log may not know a quest it hasn't seen yet
local function Repeatable(questID, repeatable, frequency)
    return repeatable or (frequency and frequency > 0)
        or (questID and C_QuestLog.IsRepeatableQuest(questID)) or false
end

local function CanAccept(questID, repeatable, frequency, trivial)
    return questID and questID ~= 0 and not trivial
        and not Repeatable(questID, repeatable, frequency)
        and not C_QuestLog.IsQuestTrivial(questID)
end

local function TakesMarks()
    for i = 1, GetNumQuestItems() do
        local link = GetQuestItemLink("required", i)
        local itemID = link and C_Item.GetItemInfoInstant(link)
        if itemID and MARKS[itemID] then return true end
    end
    return false
end

local function CanHandIn()
    local money = GetQuestMoneyToGet()
    return not Repeatable(GetQuestID()) and not (money and money > 0)
end

ns.On("GOSSIP_SHOW", function()
    local G = C_GossipInfo
    if On("questTurnIn") then
        for _, q in ipairs(G.GetActiveQuests() or {}) do
            if q.isComplete and not Repeatable(q.questID, q.repeatable, q.frequency) then
                return G.SelectActiveQuest(q.questID)
            end
        end
    end
    if On("questAccept") then
        for _, q in ipairs(G.GetAvailableQuests() or {}) do
            if not q.isIgnored and CanAccept(q.questID, q.repeatable, q.frequency, q.isTrivial) then
                return G.SelectAvailableQuest(q.questID)
            end
        end
    end
end)

-- an NPC with quests and no chat options
ns.On("QUEST_GREETING", function()
    if On("questTurnIn") then
        for i = 1, GetNumActiveQuests() do
            local _, complete = GetActiveTitle(i)
            if complete and not Repeatable(GetActiveQuestID(i)) then
                return SelectActiveQuest(i)
            end
        end
    end
    if On("questAccept") then
        for i = 1, GetNumAvailableQuests() do
            local trivial, frequency, repeatable, _, questID = GetAvailableQuestInfo(i)
            if CanAccept(questID, repeatable, frequency, trivial) then
                return SelectAvailableQuest(i)
            end
        end
    end
end)

ns.On("QUEST_DETAIL", function(startItemID)
    if not On("questAccept") then return end
    -- an item's quest is offered through the tracker's pop-up instead
    if (startItemID and startItemID ~= 0) or QuestFlagsPVP() then return end
    if QuestIsFromAdventureMap and QuestIsFromAdventureMap() then return end
    if not CanAccept(GetQuestID()) then return end
    if QuestGetAutoAccept and QuestGetAutoAccept() then
        if not (QuestIsFromAreaTrigger and QuestIsFromAreaTrigger()) then
            AcknowledgeAutoAcceptQuest()
        end
    else
        AcceptQuest()
    end
end)

ns.On("QUEST_PROGRESS", function()
    if On("questTurnIn") and IsQuestCompletable() and CanHandIn() and not TakesMarks() then
        CompleteQuest()
    end
end)

ns.On("QUEST_COMPLETE", function()
    if not (On("questTurnIn") and CanHandIn()) then return end
    local choices = GetNumQuestChoices()
    if choices <= 1 then GetQuestReward(choices) end
end)
