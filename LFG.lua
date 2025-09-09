BINDING_HEADER_LFG = "Looking For Group"
BINDING_NAME_LFG = "Toggle Looking For Group"

local _G, _ = _G or getfenv()

local LFG = CreateFrame("Frame")
local me = UnitName('player')
local addonVer = GetAddOnMetadata("LFG", "Version")
local LFG_ADDON_CHANNEL = 'LFG'
local groupsFormedThisSession = 0

ROLE_TANK_TOOLTIP = 'Indicates that you are willing to\nprotect allies from harm by\nensuring that enemies are\nattacking you instead of them.'
ROLE_HEALER_TOOLTIP = 'Indicates that you are willing to\nheal your allies when they take\ndamage.'
ROLE_DAMAGE_TOOLTIP = 'Indicates that you are willing to\ntake on the role of dealing\ndamage to enemies.'
ROLE_BAD_TOOLTIP = 'Your class may not perform this role.'

LFG.tab = 1
LFG.dungeonsSpam = {}
LFG.dungeonsSpamDisplay = {}
LFG.dungeonsSpamDisplayLFM = {}
LFG.browseFrames = {}
LFG.showedUpdateNotification = false
LFG.maxDungeonsInQueue = 5
LFG.groupSizeMax = 5
LFG.class = ''
LFG.channel = LFG_ADDON_CHANNEL
LFG.channelIndex = 0
LFG.level = UnitLevel('player')
LFG.findingGroup = false
LFG.findingMore = false
LFG:RegisterEvent("ADDON_LOADED")
LFG:RegisterEvent("PLAYER_ENTERING_WORLD")
LFG:RegisterEvent("PARTY_MEMBERS_CHANGED")
LFG:RegisterEvent("PARTY_LEADER_CHANGED")
LFG:RegisterEvent("PLAYER_LEVEL_UP")
LFG:RegisterEvent("PLAYER_TARGET_CHANGED")
LFG.availableDungeons = {}
LFG.group = {}
LFG.oneGroupFull = false
LFG.groupFullCode = ''
LFG.acceptNextInvite = false
LFG.onlyAcceptFrom = ''
LFG.queueStartTime = 0
LFG.averageWaitTime = 0
LFG.types = {
    [1] = 'Suggested Dungeons',
    [2] = 'Elite Encounters',
    [3] = 'All Available Dungeons',
}
LFG.maxDungeonsList = 11
LFG.minimapFrames = {}
LFG.myRandomTime = 0
LFG.random_min = 0
LFG.random_max = 5

LFG.RESET_TIME = 0
LFG.TANK_TIME = 2
LFG.HEALER_TIME = 10
LFG.DAMAGE_TIME = 18
LFG.FULLCHECK_TIME = 26 --time when checkGroupFull is called, has to wait for goingWith messages
LFG.TIME_MARGIN = 30

LFG.ROLE_CHECK_TIME = 50

LFG.foundGroup = false
LFG.inGroup = false
LFG.isLeader = false
LFG.LFMGroup = {}
LFG.LFMDungeonCode = ''
LFG.currentGroupSize = 1

LFG.objectivesFrames = {}
LFG.peopleLookingForGroups = 0
LFG.peopleLookingForGroupsDisplay = 0

LFG.currentGroupRoles = {}

LFG.supress = {}

LFG.classColors = {
    ["warrior"] = { r = 0.78, g = 0.61, b = 0.43, c = "|cffc79c6e" },
    ["mage"] = { r = 0.41, g = 0.8, b = 0.94, c = "|cff69ccf0" },
    ["rogue"] = { r = 1, g = 0.96, b = 0.41, c = "|cfffff569" },
    ["druid"] = { r = 1, g = 0.49, b = 0.04, c = "|cffff7d0a" },
    ["hunter"] = { r = 0.67, g = 0.83, b = 0.45, c = "|cffabd473" },
    ["shaman"] = { r = 0.14, g = 0.35, b = 1.0, c = "|cff0070de" },
    ["priest"] = { r = 1, g = 1, b = 1, c = "|cffffffff" },
    ["warlock"] = { r = 0.58, g = 0.51, b = 0.79, c = "|cff9482c9" },
    ["paladin"] = { r = 0.96, g = 0.55, b = 0.73, c = "|cfff58cba" }
}

-- delay leave queue, to check if im really ungrouped
local LFGDelayLeaveQueue = CreateFrame("Frame")
LFGDelayLeaveQueue:Hide()
LFGDelayLeaveQueue.reason = ''
LFGDelayLeaveQueue:SetScript("OnShow", function()
    this.startTime = GetTime()
end)
LFGDelayLeaveQueue:SetScript("OnUpdate", function()
    local plus = 2 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        LFG.inGroup = GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0
        if not LFG.inGroup then
            leaveQueue(LFGDelayLeaveQueue.reason)
            LFGDelayLeaveQueue.reason = ''
            LFG.hidePartyRoleIcons()
        end
        LFGDelayLeaveQueue:Hide()
    end
end)

local LFGMinimapAnimation = CreateFrame("Frame")
LFGMinimapAnimation:Hide()

LFGMinimapAnimation:SetScript("OnShow", function()
    this.startTime = GetTime()
    this.frameIndex = 0
end)
LFGMinimapAnimation:SetScript("OnHide", function()
    _G['LFG_MinimapEye']:SetTexture('Interface\\Addons\\LFG\\images\\eye\\battlenetworking0')
end)

LFGMinimapAnimation:SetScript("OnUpdate", function()
    local plus = 0.10 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then

        if this.frameIndex < 28 then
            this.frameIndex = this.frameIndex + 1
        else
            this.frameIndex = 0
        end

        _G['LFG_MinimapEye']:SetTexture('Interface\\Addons\\LFG\\images\\eye\\battlenetworking' .. this.frameIndex)

        this.startTime = GetTime()

    end
end)

local LFGTime = CreateFrame("Frame")
LFGTime:Hide()
LFGTime.second = -1
LFGTime.diff = 0

LFGTime:SetScript("OnShow", function()
    lfdebug('lfgtime SHOW call LFGTime.second = ' .. LFGTime.second .. ' my:' .. tonumber(date("%S", time())))
    lfdebug('diff = ' .. LFGTime.diff)
    this.startTime = GetTime()
    this.execAt = {}
    this.resetAt = {}
end)

LFGTime:SetScript("OnUpdate", function()
    local plus = 0.5 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then

        this.startTime = GetTime()

        LFGTime.second = tonumber(date("%S", time())) + LFGTime.diff
        if LFGTime.second < 0 then
            LFGTime.second = LFGTime.second + 60
        end
        if LFGTime.second >= 60 then
            LFGTime.second = LFGTime.second - 60
        end

        if LFGTime.second == LFG.RESET_TIME or LFGTime.second == LFG.TIME_MARGIN then

            if not this.resetAt[LFGTime.second] then

                this.resetAt[LFGTime.second] = true

                if LFG.peopleLookingForGroupsDisplay < LFG.peopleLookingForGroups or LFG.peopleLookingForGroups == 0 then
                    LFG.peopleLookingForGroupsDisplay = LFG.peopleLookingForGroups
                end

                LFG.peopleLookingForGroups = 0

                LFG.browseNames = {}

                lfdebug("RESET --- TIME IS 0 OR 30")

                for dungeon, data in next, LFG.dungeons do
                    --reset dungeon spam
                    LFG.dungeonsSpam[data.code] = { tank = 0, healer = 0, damage = 0 }
                    --reset myRole
                    if LFG.groupFullCode == '' and not LFG.inGroup then
                        LFG.dungeons[dungeon].myRole = ''
                    end
                end
                this.execAt = {}

            end
        end

        if (LFGTime.second > 2 and LFGTime.second < 27) or
                (LFGTime.second > 32 and LFGTime.second < 57) then

            this.resetAt = {}

            if not this.execAt[LFGTime.second] then
                BrowseDungeonListFrame_Update()
                this.execAt[LFGTime.second] = true
            end

        end

        if LFGTime.second == 28 or LFGTime.second == 58 then
            --check for 0 at 28 and 58
            for dungeon, data in next, LFG.dungeons do
                if LFG.dungeonsSpam[data.code].tank == 0 then
                    LFG.dungeonsSpamDisplay[data.code].tank = LFG.dungeonsSpam[data.code].tank
                end
                if LFG.dungeonsSpam[data.code].healer == 0 then
                    LFG.dungeonsSpamDisplay[data.code].healer = LFG.dungeonsSpam[data.code].healer
                end
                if LFG.dungeonsSpam[data.code].damage == 0 then
                    LFG.dungeonsSpamDisplay[data.code].damage = LFG.dungeonsSpam[data.code].damage
                end
                LFG.dungeonsSpamDisplayLFM[data.code] = 0
            end
        end


    end
end)

local LFGGoingWithPicker = CreateFrame("Frame")
LFGGoingWithPicker:Hide()
LFGGoingWithPicker.candidate = ''
LFGGoingWithPicker.priority = 0
LFGGoingWithPicker.dungeon = ''
LFGGoingWithPicker.myRole = ''

LFGGoingWithPicker:SetScript("OnShow", function()
    this.startTime = GetTime()
end)

LFGGoingWithPicker:SetScript("OnHide", function()
end)

LFGGoingWithPicker:SetScript("OnUpdate", function()
    local plus = 1 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then

        LFG.dungeons[LFG.dungeonNameFromCode(LFGGoingWithPicker.dungeon)].myRole = LFGGoingWithPicker.myRole

        SendChatMessage('goingWith:' .. LFGGoingWithPicker.candidate .. ':' .. LFGGoingWithPicker.dungeon .. ':' .. LFGGoingWithPicker.myRole, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))

        LFG.foundGroup = true

        LFGGoingWithPicker.candidate = ''
        LFGGoingWithPicker.myRole = ''
        LFGGoingWithPicker.priority = 0
        LFGGoingWithPicker.dungeon = ''
        LFGGoingWithPicker:Hide()
    end
end)

local COLOR_RED = '|cffff222a'
local COLOR_ORANGE = '|cffff8000'
local COLOR_GREEN = '|cff1fba1f'
local COLOR_HUNTER = '|cffabd473'
local COLOR_YELLOW = '|cffffff00'
local COLOR_WHITE = '|cffffffff'
local COLOR_DISABLED = '|cffaaaaaa'
local COLOR_DISABLED2 = '|cff666666'
local COLOR_TANK = '|cff0070de'
local COLOR_HEALER = COLOR_GREEN
local COLOR_DAMAGE = COLOR_RED

-- dungeon complete animation
local LFGDungeonComplete = CreateFrame("Frame")
LFGDungeonComplete:Hide()
LFGDungeonComplete.frameIndex = 0
LFGDungeonComplete.dungeonInProgress = false

LFGDungeonComplete:SetScript("OnShow", function()
    this.startTime = GetTime()
    LFGDungeonComplete.frameIndex = 0
    _G['LFGDungeonComplete']:SetAlpha(0)
    _G['LFGDungeonComplete']:Show()
end)

LFGDungeonComplete:SetScript("OnHide", function()
    --    this.startTime = GetTime()
end)

LFGDungeonComplete:SetScript("OnUpdate", function()
    local plus = 0.03 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        this.startTime = GetTime()
        local frame = ''
        if LFGDungeonComplete.frameIndex < 10 then
            frame = frame .. '0' .. LFGDungeonComplete.frameIndex
        else
            frame = frame .. LFGDungeonComplete.frameIndex
        end
        _G['LFGDungeonCompleteFrame']:SetTexture('Interface\\addons\\LFG\\images\\dungeon_complete\\dungeon_complete_' .. frame)
        if LFGDungeonComplete.frameIndex < 35 then
            _G['LFGDungeonComplete']:SetAlpha(_G['LFGDungeonComplete']:GetAlpha() + 0.03)
        end
        if LFGDungeonComplete.frameIndex > 119 then
            _G['LFGDungeonComplete']:SetAlpha(_G['LFGDungeonComplete']:GetAlpha() - 0.03)
        end
        if LFGDungeonComplete.frameIndex >= 150 then
            _G['LFGDungeonComplete']:Hide()
            _G['LFGDungeonStatus']:Hide()
            _G['LFGDungeonCompleteFrame']:SetTexture('Interface\\addons\\LFG\\images\\dungeon_complete\\dungeon_complete_00')
            LFGDungeonComplete:Hide()

            local index = 0
            for _, boss in next, LFG.bosses[LFG.groupFullCode] do
                index = index + 1
                LFG.objectivesFrames[index]:Hide()
                LFG.objectivesFrames[index].completed = false
                _G["LFGObjective" .. index .. 'ObjectiveComplete']:Hide()
                _G["LFGObjective" .. index .. 'ObjectivePending']:Hide()
                _G["LFGObjective" .. index .. 'Objective']:SetText('')
            end
            --LFG.objectivesFrames = {}
        end
        LFGDungeonComplete.frameIndex = LFGDungeonComplete.frameIndex + 1
    end
end)

-- objectives
local LFGObjectives = CreateFrame("Frame")
LFGObjectives:Hide()
--LFGObjectives:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
LFGObjectives.collapsed = false
LFGObjectives.closedByUser = false
LFGObjectives.lastObjective = 0
LFGObjectives.leftOffset = -80
LFGObjectives.frameIndex = 0
LFGObjectives.objectivesComplete = 0

function close_lfg_objectives()
    LFGObjectives.closedByUser = true
    _G['LFGDungeonStatus']:Hide()
end

-- swoooooooosh

LFGObjectives:SetScript("OnShow", function()
    LFGObjectives.leftOffset = -80
    LFGObjectives.frameIndex = 0
    this.startTime = GetTime()
end)

LFGObjectives:SetScript("OnHide", function()
    --    this.startTime = GetTime()
end)

LFGObjectives:SetScript("OnUpdate", function()
    local plus = 0.001 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        this.startTime = GetTime()
        LFGObjectives.frameIndex = LFGObjectives.frameIndex + 1
        LFGObjectives.leftOffset = LFGObjectives.leftOffset + 5
        _G["LFGObjective" .. LFGObjectives.lastObjective .. 'Swoosh']:SetPoint("TOPLEFT", _G["LFGObjective" .. LFGObjectives.lastObjective], "TOPLEFT", LFGObjectives.leftOffset, 5)
        if LFGObjectives.frameIndex <= 10 then
            _G["LFGObjective" .. LFGObjectives.lastObjective .. 'Swoosh']:SetAlpha(LFGObjectives.frameIndex / 10)
        end
        if LFGObjectives.frameIndex >= 30 then
            _G["LFGObjective" .. LFGObjectives.lastObjective .. 'Swoosh']:SetAlpha(1 - LFGObjectives.frameIndex / 40)
        end
        if LFGObjectives.leftOffset >= 120 then
            LFGObjectives:Hide()
            _G["LFGObjective" .. LFGObjectives.lastObjective .. 'Swoosh']:SetAlpha(0)
        end
    end
end)

LFGObjectives:SetScript("OnEvent", function()
    if event then
        if event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
            local creatureDied = arg1
            lfdebug(creatureDied)
            if LFG.bosses[LFG.groupFullCode] then
                for _, boss in next, LFG.bosses[LFG.groupFullCode] do
                    --creatureDied == 'You have slain ' .. boss .. '!'
                    if creatureDied == boss .. ' dies.' then
                        LFGObjectives.objectiveComplete(boss)
                        return true
                    end
                end
            end
        end
    end
end)

-- fill available dungeons delayer because UnitLevel(member who just joined) returns 0
local LFGFillAvailableDungeonsDelay = CreateFrame("Frame")
LFGFillAvailableDungeonsDelay.triggers = 0
LFGFillAvailableDungeonsDelay.queueAfterIfPossible = false
LFGFillAvailableDungeonsDelay:Hide()
LFGFillAvailableDungeonsDelay:SetScript("OnShow", function()
    this.startTime = GetTime()
end)

LFGFillAvailableDungeonsDelay:SetScript("OnHide", function()
    if LFGFillAvailableDungeonsDelay.triggers < 10 then
        LFG.fillAvailableDungeons(LFGFillAvailableDungeonsDelay.queueAfterIfPossible)
        LFGFillAvailableDungeonsDelay.triggers = LFGFillAvailableDungeonsDelay.triggers + 1
    else
        --lferror('Error occurred at LFGFillAvailableDungeonsDelay triggers = 10. Please report this to Bennylava.')
    end
end)
LFGFillAvailableDungeonsDelay:SetScript("OnUpdate", function()
    local plus = 0.1 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        LFGFillAvailableDungeonsDelay:Hide()
    end
end)

-- channel join delayer

local LFGChannelJoinDelay = CreateFrame("Frame")
LFGChannelJoinDelay:Hide()

LFGChannelJoinDelay:SetScript("OnShow", function()
    this.startTime = GetTime()
end)

LFGChannelJoinDelay:SetScript("OnHide", function()
    LFG.checkLFGChannel()
end)

LFGChannelJoinDelay:SetScript("OnUpdate", function()
    local plus = 15 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        LFGChannelJoinDelay:Hide()
    end
end)

local LFGQueue = CreateFrame("Frame")
LFGQueue:Hide()

-- group invite timer

local LFGInvite = CreateFrame("Frame")
LFGInvite:Hide()
LFGInvite.inviteIndex = 1
LFGInvite:SetScript("OnShow", function()
    this.startTime = GetTime()
    LFGInvite.inviteIndex = 1
    local awesomeButton = _G['LFGGroupReadyAwesome']
    awesomeButton:SetText('Waiting Players (' .. LFG.groupSizeMax - GetNumPartyMembers() - 1 .. ')')
    awesomeButton:Disable()
end)

LFGInvite:SetScript("OnUpdate", function()
    local plus = 0.5 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        this.startTime = GetTime()

        LFGInvite.inviteIndex = this.inviteIndex + 1

        if LFGInvite.inviteIndex == 2 then
            if LFG.group[LFG.groupFullCode].healer ~= '' then
                InviteUnit(LFG.group[LFG.groupFullCode].healer)
            end
        end
        if LFGInvite.inviteIndex == 3 then
            if LFG.group[LFG.groupFullCode].damage1 ~= '' then
                InviteUnit(LFG.group[LFG.groupFullCode].damage1)
            end
        end
        if LFGInvite.inviteIndex == 4 and LFGInvite.inviteIndex <= LFG.groupSizeMax then
            if LFG.group[LFG.groupFullCode].damage2 ~= '' then
                InviteUnit(LFG.group[LFG.groupFullCode].damage2)
            end
        end
        if LFGInvite.inviteIndex == 5 and LFGInvite.inviteIndex <= LFG.groupSizeMax then
            if LFG.group[LFG.groupFullCode].damage3 ~= '' then
                InviteUnit(LFG.group[LFG.groupFullCode].damage3)
                LFGInvite:Hide()
                LFGInvite.inviteIndex = 1
            end
        end
    end
end)

-- role check timer

local LFGRoleCheck = CreateFrame("Frame")
LFGRoleCheck:Hide()

LFGRoleCheck:SetScript("OnShow", function()
    this.startTime = GetTime()
end)

LFGRoleCheck:SetScript("OnHide", function()
    if LFG.isLeader then
        if LFG.findingMore then
        else
            lfprint('A member of your group has not confirmed his role.')
            PlaySoundFile("Interface\\Addons\\LFG\\sound\\lfg_denied.ogg")
            _G['findMoreButton']:Enable()
        end
    end
    _G['LFGRoleCheck']:Hide()
end)

LFGRoleCheck:SetScript("OnUpdate", function()
    local plus = LFG.ROLE_CHECK_TIME --seconds
    if LFG.isLeader then
        plus = plus + 2 --leader waits 2 more second to hide
    end
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        LFGRoleCheck:Hide()

        if LFG.isLeader then
            lfprint('A member of your group does not have the ' .. COLOR_HUNTER .. '[LFG] ' .. COLOR_WHITE ..
                    'addon. Looking for more is disabled. (Type ' .. COLOR_HUNTER .. '/lfg advertise ' .. COLOR_WHITE .. ' to send them a link)')
            _G['findMoreButton']:Disable()

        else
            declineRole()
        end
    end
end)

-- who counter timer

local LFGWhoCounter = CreateFrame("Frame")
LFGWhoCounter:Hide()
LFGWhoCounter.people = 0
LFGWhoCounter.listening = false
LFGWhoCounter:SetScript("OnShow", function()
    this.startTime = GetTime()
    LFGWhoCounter.people = 0
    LFGWhoCounter.listening = true
    lfprint('Checking people online with the addon (5secs)...')
end)

LFGWhoCounter:SetScript("OnHide", function()
    LFGWhoCounter.people = LFGWhoCounter.people + 1 -- + me
    lfprint('Found ' .. COLOR_GREEN .. LFGWhoCounter.people .. COLOR_WHITE .. ' online using LFG addon.')
    LFGWhoCounter.listening = false
end)

LFGWhoCounter:SetScript("OnUpdate", function()
    local plus = 5 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        LFGWhoCounter:Hide()
    end
end)

--closes the group ready frame when someone leaves queue from the button
local LFGGroupReadyFrameCloser = CreateFrame("Frame")
LFGGroupReadyFrameCloser:Hide()
LFGGroupReadyFrameCloser.response = ''
LFGGroupReadyFrameCloser:SetScript("OnShow", function()
    this.startTime = GetTime()
end)

LFGGroupReadyFrameCloser:SetScript("OnHide", function()
end)
LFGGroupReadyFrameCloser:SetScript("OnUpdate", function()
    local plus = LFG.ROLE_CHECK_TIME --time after i click leave queue, afk
    local plus2 = LFG.ROLE_CHECK_TIME + 5 --time after i close the window
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    local st2 = (this.startTime + plus2) * 1000
    if gt >= st then
        if LFGGroupReadyFrameCloser.response == '' then
            sayNotReady()
        end
    end
    if gt >= st2 then
        _G['LFGReadyStatus']:Hide()
        lfprint('A member of your group has not accepted the invitation. You are rejoining the queue.')
        if LFG.isLeader then
            leaveQueue('LFGGroupReadyFrameCloser isleader = true')
            LFG.fillAvailableDungeons('queueAgain' == 'queueAgain')
        end
        if LFGGroupReadyFrameCloser.response == 'notReady' then
            --doesnt trigger for leader, cause it leaves queue
            --which resets response to ''
            --LeaveParty()
            LFGGroupReadyFrameCloser.response = ''
        end
        LFGGroupReadyFrameCloser:Hide()
    end
end)

-- communication

local LFGComms = CreateFrame("Frame")
LFGComms:Hide()
LFGComms:RegisterEvent("CHAT_MSG_CHANNEL")
LFGComms:RegisterEvent("CHAT_MSG_WHISPER")
LFGComms:RegisterEvent("CHAT_MSG_CHANNEL_LEAVE")
LFGComms:RegisterEvent("PARTY_INVITE_REQUEST")
LFGComms:RegisterEvent("CHAT_MSG_ADDON")
LFGComms:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
LFGComms:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE_USER")
LFGComms:RegisterEvent("CHAT_MSG_SYSTEM")
--"CHAT_MSG_CHANNEL_NOTICE_USER"
--Category: Communication
--
--Fired when something changes in the channel like moderation enabled, user is kicked, announcements changed and so on. CHAT_*_NOTICE in GlobalStrings.lua has a full list of available types.
--
--arg1
--type ("ANNOUNCEMENTS_OFF", "ANNOUNCEMENTS_ON", "BANNED", "OWNER_CHANGED", "INVALID_NAME", "INVITE", "MODERATION_OFF", "MODERATION_ON", "MUTED", "NOT_MEMBER", "NOT_MODERATED", "SET_MODERATOR", "UNSET_MODERATOR" )
--arg2
--If arg5 has a value then this is the user affected ( eg: "Player Foo has been kicked by Bar" ), if arg5 has no value then it's the person who caused the event ( eg: "Channel Moderation has been enabled by Bar" )
--arg4
--Channel name with number
--arg5
--Player that caused the event (eg "Player Foo has been kicked by Bar" )

LFGComms:SetScript("OnEvent", function()
    if event then
        if event == 'CHAT_MSG_CHANNEL_NOTICE_USER' then

            if arg1 == 'PLAYER_ALREADY_MEMBER' then
                -- probably only used when reloadui
                LFG.checkLFGChannel()
            end
            lfdebug('CHAT_MSG_CHANNEL_NOTICE_USER')
            lfdebug(arg1) --event,
            lfdebug(arg2) -- somename
            lfdebug(arg3) -- blank
            lfdebug(arg4) -- 6.Lft
            lfdebug(arg5) -- blank
            lfdebug('channel index = ' .. LFG.channelIndex) -- blank
        end
        if event == 'CHAT_MSG_CHANNEL_NOTICE' then
            if arg9 == LFG.channel and arg1 == 'YOU_JOINED' then
                LFG.channelIndex = arg8
            end
        end

        if event == 'CHAT_MSG_ADDON' and arg1 == LFG_ADDON_CHANNEL then
            lfdebug(arg4 .. ' says : ' .. arg2)
            if string.sub(arg2, 1, 11) == 'objectives:' and arg4 ~= me then
                local objEx = StringSplit(arg2, ':')
                if LFG.groupFullCode ~= objEx[2] then
                    LFG.groupFullCode = objEx[2]
                end

                local objectivesString = StringSplit(objEx[3], '-')

                local complete = 0

                for stringIndex, s in next, objectivesString do
                    if s then
                        if s == '1' then
                            complete = complete + 1
                            local index = 0
                            for _, boss in next, LFG.bosses[LFG.groupFullCode] do
                                index = index + 1
                                if index == stringIndex then
                                    LFGObjectives.objectiveComplete(boss, true)
                                end
                            end
                        end
                    end
                end

                if not LFGObjectives.closedByUser and not _G["LFGDungeonStatus"]:IsVisible() then
                    LFG.showDungeonObjectives('code_for_debug_only', complete)
                end
            end
            if string.sub(arg2, 1, 11) == 'notReadyAs:' then

                PlaySoundFile("Interface\\Addons\\LFG\\sound\\lfg_denied.ogg")

                local readyEx = StringSplit(arg2, ':')
                local role = readyEx[2]
                if role == 'tank' then
                    _G['LFGReadyStatusReadyTank']:SetTexture('Interface\\addons\\LFG\\images\\readycheck-notready')
                end
                if role == 'healer' then
                    _G['LFGReadyStatusReadyHealer']:SetTexture('Interface\\addons\\LFG\\images\\readycheck-notready')
                end
                if role == 'damage' then
                    if _G['LFGReadyStatusReadyDamage1']:GetTexture() == 'Interface\\addons\\LFG\\images\\readycheck-waiting' then
                        _G['LFGReadyStatusReadyDamage1']:SetTexture('Interface\\addons\\LFG\\images\\readycheck-notready')
                    elseif _G['LFGReadyStatusReadyDamage2']:GetTexture() == 'Interface\\addons\\LFG\\images\\readycheck-waiting' then
                        _G['LFGReadyStatusReadyDamage2']:SetTexture('Interface\\addons\\LFG\\images\\readycheck-notready')
                    elseif _G['LFGReadyStatusReadyDamage3']:GetTexture() == 'Interface\\addons\\LFG\\images\\readycheck-waiting' then
                        _G['LFGReadyStatusReadyDamage3']:SetTexture('Interface\\addons\\LFG\\images\\readycheck-notready')
                    end
                end
            end
            if string.sub(arg2, 1, 8) == 'readyAs:' then
                local readyEx = StringSplit(arg2, ':')
                local role = readyEx[2]

                LFG.showPartyRoleIcons(role, arg4)

                if role == 'tank' then
                    _G['LFGReadyStatusReadyTank']:SetTexture('Interface\\addons\\LFG\\images\\readycheck-ready')
                end
                if role == 'healer' then
                    _G['LFGReadyStatusReadyHealer']:SetTexture('Interface\\addons\\LFG\\images\\readycheck-ready')
                end
                if role == 'damage' then
                    if _G['LFGReadyStatusReadyDamage1']:GetTexture() == 'Interface\\addons\\LFG\\images\\readycheck-waiting' then
                        _G['LFGReadyStatusReadyDamage1']:SetTexture('Interface\\addons\\LFG\\images\\readycheck-ready')
                    elseif _G['LFGReadyStatusReadyDamage2']:GetTexture() == 'Interface\\addons\\LFG\\images\\readycheck-waiting' then
                        _G['LFGReadyStatusReadyDamage2']:SetTexture('Interface\\addons\\LFG\\images\\readycheck-ready')
                    elseif _G['LFGReadyStatusReadyDamage3']:GetTexture() == 'Interface\\addons\\LFG\\images\\readycheck-waiting' then
                        _G['LFGReadyStatusReadyDamage3']:SetTexture('Interface\\addons\\LFG\\images\\readycheck-ready')
                    end
                end
                if _G['LFGReadyStatusReadyTank']:GetTexture() == 'Interface\\addons\\LFG\\images\\readycheck-ready' and
                        _G['LFGReadyStatusReadyHealer']:GetTexture() == 'Interface\\addons\\LFG\\images\\readycheck-ready' and
                        _G['LFGReadyStatusReadyDamage1']:GetTexture() == 'Interface\\addons\\LFG\\images\\readycheck-ready' and
                        _G['LFGReadyStatusReadyDamage2']:GetTexture() == 'Interface\\addons\\LFG\\images\\readycheck-ready' and
                        _G['LFGReadyStatusReadyDamage3']:GetTexture() == 'Interface\\addons\\LFG\\images\\readycheck-ready' then
                    _G['LFGReadyStatus']:Hide()
                    LFGGroupReadyFrameCloser:Hide()
                    local _, numCompletedObjectives = LFG.getDungeonCompletion()
                    LFG.showDungeonObjectives('dummy', numCompletedObjectives)
                    --promote the tank to leader
                end
                if LFG.isLeader and role == 'tank' and arg4 ~= me then
                    PromoteToLeader(arg4)
                end
            end
            if string.sub(arg2, 1, 11) == 'LFGVersion:' and arg4 ~= me then
                if not LFG.showedUpdateNotification then
                    local verEx = StringSplit(arg2, ':')
                    if LFG.ver(verEx[2]) > LFG.ver(addonVer) then
                        lfprint(COLOR_HUNTER .. 'Looking For Group ' .. COLOR_WHITE .. ' - new version available ' ..
                                COLOR_GREEN .. 'v' .. verEx[2] .. COLOR_WHITE .. ' (current version ' ..
                                COLOR_ORANGE .. 'v' .. addonVer .. COLOR_WHITE .. ')')
                        lfprint('Update yours at ' .. COLOR_HUNTER .. 'https://github.com/Bennylavaa/LFG')
                        LFG.showedUpdateNotification = true
                    end
                end
            end

            if string.sub(arg2, 1, 11) == 'leaveQueue:' and arg4 ~= me then
                leaveQueue('leaveQueue: addon party')
            end

            if string.sub(arg2, 1, 8) == 'minimap:' then
                if not LFG.isLeader then
                    local miniEx = StringSplit(arg2, ':')
                    local code = miniEx[2]
                    local tank = tonumber(miniEx[3])
                    local healer = tonumber(miniEx[4])
                    local damage = tonumber(miniEx[5])

                    LFG.LFMDungeonCode = code

                    LFG.group = {} --reset old entries
                    LFG.group[code] = {
                        tank = '',
                        healer = '',
                        damage1 = '',
                        damage2 = '',
                        damage3 = ''
                    }
                    if tank == 1 then
                        LFG.group[code].tank = 'DummyTank'
                    end
                    if healer == 1 then
                        LFG.group[code].healer = 'DummyHealer'
                    end
                    if damage > 0 then
                        LFG.group[code].damage1 = 'DummyDamage1'
                    end
                    if damage > 1 then
                        LFG.group[code].damage2 = 'DummyDamage2'
                    end
                    if damage > 2 then
                        LFG.group[code].damage3 = 'DummyDamage3'
                    end
                end
            end
            if string.sub(arg2, 1, 14) == 'LFMPartyReady:' then

                local queueEx = StringSplit(arg2, ':')
                local mCode = queueEx[2]
                local objectivesCompleted = queueEx[3]
                local objectivesTotal = queueEx[4]

                LFG.groupFullCode = mCode
                LFG.LFMDungeonCode = mCode

                --uncheck everything
                _G['Dungeon_' .. LFG.groupFullCode .. '_CheckButton']:SetChecked(false)
                LFG.findingGroup = false
                LFG.findingMore = false
                local background = ''
                local dungeonName = 'unknown'
                for d, data in next, LFG.dungeons do
                    if data.code == mCode then
                        background = data.background
                        dungeonName = d
                    end
                end

                local myRole = LFG.dungeons[LFG.dungeonNameFromCode(mCode)].myRole

                LFG.SetSingleRole(myRole)

                _G['LFGGroupReadyBackground']:SetTexture('Interface\\addons\\LFG\\images\\background\\ui-lfg-background-' .. background)
                _G['LFGGroupReadyRole']:SetTexture('Interface\\addons\\LFG\\images\\' .. myRole .. '2')
                _G['LFGGroupReadyMyRole']:SetText(LFG.ucFirst(myRole))
                _G['LFGGroupReadyDungeonName']:SetText(dungeonName)
                _G['LFGGroupReadyObjectivesCompleted']:SetText(objectivesCompleted .. '/' .. objectivesTotal .. ' Bosses Defeated')

                LFG.readyStatusReset()
                _G['LFGGroupReady']:Show()
                LFGGroupReadyFrameCloser:Show()

                LFG.fixMainButton()
                _G['LFGlfg']:Hide()

                PlaySoundFile("Interface\\Addons\\LFG\\sound\\levelup2.ogg")
                LFGQueue:Hide()

                if LFG.isLeader then
                    SendChatMessage("[LFG]:lfg_group_formed:" .. mCode .. ":" .. time() - LFG.queueStartTime, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
                end
            end
            if string.sub(arg2, 1, 10) == 'weInQueue:' then
                local queueEx = StringSplit(arg2, ':')
                LFG.weInQueue(queueEx[2])
            end
            if string.sub(arg2, 1, 10) == 'roleCheck:' then
                -- Force clean the LFMGroup before starting role check to prevent stale data
                LFG.LFMGroup = {
                    tank = '',
                    healer = '',
                    damage1 = '',
                    damage2 = '',
                    damage3 = '',
                }

                if arg4 ~= me then
                    PlaySoundFile("Interface\\AddOns\\LFG\\sound\\lfg_rolecheck.ogg")
                end
                lfprint('A role check has been initiated. Your group will be queued when all members have selected a role.')
                UIErrorsFrame:AddMessage("|cff69ccf0[LFG] |cffffff00A role check has been initiated. Your group will be queued when all members have selected a role.")

                local argEx = StringSplit(arg2, ':')
                local mCode = argEx[2]
                LFG.LFMDungeonCode = mCode
                LFG.resetGroup()

                lfdebug('my role is : ' .. LFG.dungeons[LFG.dungeonNameFromCode(LFG.LFMDungeonCode)].myRole)

                --if we dont know my prev role
                if LFG.dungeons[LFG.dungeonNameFromCode(LFG.LFMDungeonCode)].myRole == '' then

                    if _G['RoleTank']:GetChecked() then
                        LFG.dungeons[LFG.dungeonNameFromCode(LFG.LFMDungeonCode)].myRole = 'tank'
                    elseif _G['RoleHealer']:GetChecked() then
                        LFG.dungeons[LFG.dungeonNameFromCode(LFG.LFMDungeonCode)].myRole = 'healer'
                    elseif _G['RoleDamage']:GetChecked() then
                        LFG.dungeons[LFG.dungeonNameFromCode(LFG.LFMDungeonCode)].myRole = 'damage'
                    else
                        LFG.dungeons[LFG.dungeonNameFromCode(LFG.LFMDungeonCode)].myRole = LFG.GetPossibleRoles()
                    end
                end

                _G['roleCheckTank']:SetChecked(LFG.dungeons[LFG.dungeonNameFromCode(LFG.LFMDungeonCode)].myRole == 'tank')
                _G['roleCheckHealer']:SetChecked(LFG.dungeons[LFG.dungeonNameFromCode(LFG.LFMDungeonCode)].myRole == 'healer')
                _G['roleCheckDamage']:SetChecked(LFG.dungeons[LFG.dungeonNameFromCode(LFG.LFMDungeonCode)].myRole == 'damage')

                lfdebug(' my  role after checks : ' .. LFG.dungeons[LFG.dungeonNameFromCode(LFG.LFMDungeonCode)].myRole)

                _G['LFGRoleCheckAcceptRole']:Enable()

                _G['LFGRoleCheckQForText']:SetText(COLOR_WHITE .. "Queued for " .. COLOR_YELLOW .. LFG.dungeonNameFromCode(mCode))
                _G['LFGRoleCheck']:Show()
                _G['LFGGroupReady']:Hide()
                LFGRoleCheck:Show()
            end

            if string.sub(arg2, 1, 11) == 'acceptRole:' then
                local roleEx = StringSplit(arg2, ':')
                local roleColor = ''

                if arg4 == me and not LFG.isLeader then
                    LFGRoleCheck:Hide()
                end

                LFG.showPartyRoleIcons(roleEx[2], arg4)

                if roleEx[2] == 'tank' then
                    roleColor = COLOR_TANK
                end
                if roleEx[2] == 'healer' then
                    roleColor = COLOR_HEALER
                end
                if roleEx[2] == 'damage' then
                    roleColor = COLOR_DAMAGE
                end
                if arg4 == me then
                    lfprint('You have chosen: ' .. roleColor .. LFG.ucFirst(roleEx[2]))
                end

                -- Check if this is an Elite Encounter for flexible role assignment
                if LFG.isEliteEncounter(LFG.LFMDungeonCode) then
                    if roleEx[2] == 'tank' then
                        LFG.LFMGroup.tank = arg4
                    end
                    if roleEx[2] == 'healer' then
                        LFG.LFMGroup.healer = arg4
                    end
                    if roleEx[2] == 'damage' then
                        if LFG.LFMGroup.damage1 == '' then
                            LFG.LFMGroup.damage1 = arg4
                        elseif LFG.LFMGroup.damage2 == '' then
                            LFG.LFMGroup.damage2 = arg4
                        elseif LFG.LFMGroup.damage3 == '' then
                            LFG.LFMGroup.damage3 = arg4
                        end
                    end
                else
                    if roleEx[2] == 'tank' then

                        _G['roleCheckTank']:SetChecked(false)
                        _G['roleCheckTank']:Disable()
                        _G['LFGRoleCheckRoleTank']:SetDesaturated(1)

                        if _G['LFGRoleCheck']:IsVisible() and LFG_ROLE == 'tank' then
                            _G['LFGRoleCheckAcceptRole']:Disable()
                        end

                        if LFG_ROLE == 'tank' then
                            if _G['LFGRoleCheck']:IsVisible() then
                                _G['LFGRoleCheckAcceptRole']:Disable()
                                _G['roleCheckTank']:SetChecked(false)
                                _G['roleCheckTank']:Disable()
                            else
                                --not visible means confirmed by me
                                --for me
                                --should not get here i think, button will be disabled
                                if LFG.isLeader then
                                    if arg4 ~= me then
                                        lfprint(LFG.classColors[LFG.playerClass(arg4)].c .. arg4 .. COLOR_WHITE .. ' has chosen '
                                                .. COLOR_TANK .. 'Tank' .. COLOR_WHITE .. ' but you already confirmed this role.')
                                        lfprint('Queueing aborted.')
                                        leaveQueue(' two tanks')
                                        return false
                                    end
                                else
                                    --for other tank
                                    if LFG.LFMGroup.tank ~= '' and LFG.LFMGroup.tank ~= me then
                                        lfprint(COLOR_TANK .. 'Tank ' .. COLOR_WHITE .. 'role has already been filled by ' .. LFG.classColors[LFG.playerClass(LFG.LFMGroup.tank)].c .. LFG.LFMGroup.tank
                                                .. COLOR_WHITE .. '. Please select a different role to rejoin the queue.')
                                        return false
                                    end
                                end
                            end
                        end
                        LFG.LFMGroup.tank = arg4
                    end

                    if roleEx[2] == 'healer' then

                        _G['roleCheckHealer']:SetChecked(false)
                        _G['roleCheckHealer']:Disable()
                        _G['LFGRoleCheckRoleHealer']:SetDesaturated(1)

                        if _G['LFGRoleCheck']:IsVisible() and LFG_ROLE == 'healer' then
                            _G['LFGRoleCheckAcceptRole']:Disable()
                        end

                        if LFG_ROLE == 'healer' then
                            if _G['LFGRoleCheck']:IsVisible() then
                                _G['LFGRoleCheckAcceptRole']:Disable()
                                _G['roleCheckHealer']:SetChecked(false)
                                _G['roleCheckHealer']:Disable()
                            else
                                --not visible means confirmed by me
                                --for me
                                --should not get here i think, button will be disabled
                                if LFG.isLeader then
                                    if arg4 ~= me then
                                        lfprint(LFG.classColors[LFG.playerClass(arg4)].c .. arg4 .. COLOR_WHITE .. ' has chosen '
                                                .. COLOR_HEALER .. 'Healer' .. COLOR_WHITE .. ' but you already confirmed this role.')
                                        lfprint('Queueing aborted.')
                                        leaveQueue('two healers')
                                        return false
                                    end
                                else
                                    --for other healer
                                    if LFG.LFMGroup.healer ~= '' then
                                        lfprint(COLOR_HEALER .. 'Healer ' .. COLOR_WHITE .. 'role has already been filled by ' .. LFG.classColors[LFG.playerClass(LFG.LFMGroup.healer)].c .. LFG.LFMGroup.healer
                                                .. COLOR_WHITE .. '. Please select a different role to rejoin the queue.')
                                        return false
                                    end
                                end
                            end
                        end
                        LFG.LFMGroup.healer = arg4
                    end

                    if roleEx[2] == 'damage' then

                        local dpsFilled = false

                        if LFG.LFMGroup.damage1 == '' then
                            LFG.LFMGroup.damage1 = arg4
                        elseif LFG.LFMGroup.damage2 == '' then
                            LFG.LFMGroup.damage2 = arg4
                        elseif LFG.LFMGroup.damage3 == '' then
                            LFG.LFMGroup.damage3 = arg4

                            dpsFilled = true
                            _G['roleCheckDamage']:SetChecked(false)
                            _G['roleCheckDamage']:Disable()
                            _G['LFGRoleCheckRoleDamage']:SetDesaturated(1)

                            if _G['LFGRoleCheck']:IsVisible() and LFG_ROLE == 'damage' then
                                _G['LFGRoleCheckAcceptRole']:Disable()
                            end

                        end

                        if LFG_ROLE == 'damage' or dpsFilled then

                            if _G['LFGRoleCheck']:IsVisible() then

                                -- lock accept buttons if we have 3 dps already
                                if LFG.LFMGroup.damage1 ~= '' and
                                        LFG.LFMGroup.damage2 ~= '' and
                                        LFG.LFMGroup.damage3 ~= '' then
                                    --_G['LFGRoleCheckAcceptRole']:Disable()
                                    _G['roleCheckDamage']:SetChecked(false)
                                    _G['roleCheckDamage']:Disable()
                                    _G['LFGRoleCheckRoleDamage']:SetDesaturated(1)
                                end

                            else
                                if dpsFilled then
                                    if LFG.isLeader then
                                        if arg4 ~= me then
                                            if LFG.LFMGroup.damage1 ~= '' and LFG.LFMGroup.damage2 ~= '' and LFG.LFMGroup.damage3 ~= '' then
                                                lfprint(LFG.classColors[LFG.playerClass(arg4)].c .. arg4 .. COLOR_WHITE .. ' has chosen ' .. COLOR_DAMAGE .. 'Damage' .. COLOR_WHITE
                                                        .. ' but the group already has ' .. COLOR_DAMAGE .. '3' .. COLOR_WHITE .. ' confirmed ' .. COLOR_DAMAGE .. 'Damage' .. COLOR_WHITE .. ' members.')
                                                lfprint('Queueing aborted.')
                                                leaveQueue('4 dps')
                                                return false
                                            end
                                        end
                                    else
                                        if LFG.LFMGroup.damage1 ~= '' and LFG.LFMGroup.damage2 ~= '' and LFG.LFMGroup.damage3 ~= '' then
                                            lfprint(COLOR_DAMAGE .. 'Damage ' .. COLOR_WHITE .. 'role has already been filled by ' .. COLOR_DAMAGE .. '3' .. COLOR_WHITE .. ' members. Please select a different role to rejoin the queue.')
                                            return false
                                        end
                                    end
                                end
                            end
                        end

                    end
                end

                if arg4 ~= me then
                    lfprint(LFG.classColors[LFG.playerClass(arg4)].c .. arg4 .. COLOR_WHITE .. ' has chosen: ' .. roleColor .. LFG.ucFirst(roleEx[2]))
                end
                LFG.checkLFMgroup()
            end
            if string.sub(arg2, 1, 12) == 'declineRole:' then
                PlaySoundFile("Interface\\Addons\\LFG\\sound\\lfg_denied.ogg")
                LFG.checkLFMgroup(arg4)
            end
        end
        if event == 'PARTY_INVITE_REQUEST' then
            if LFG.acceptNextInvite then
                if arg1 == LFG.onlyAcceptFrom then
                    LFG.AcceptGroupInvite()
                    LFG.acceptNextInvite = false
                else
                    LFG.DeclineGroupInvite()
                end
            end
            if not LFG.foundGroup then
                leaveQueue('PARTY_INVITE_REQUEST')
            end
        end
        if event == 'CHAT_MSG_CHANNEL_LEAVE' then
            LFG.removePlayerFromVirtualParty(arg2, false) --unknown role
        end
        if event == 'CHAT_MSG_CHANNEL' and string.find(arg1, '[LFG]', 1, true) and arg8 == LFG.channelIndex and arg2 ~= me and --for lfm
                string.find(arg1, '(LFM)', 1, true) then
            --[LFG]:stratlive:(LFM):name
            local mEx = StringSplit(arg1, ':')
            if mEx[4] == me then
                LFG.onlyAcceptFrom = arg2
                LFG.acceptNextInvite = true
            end
        end
        if event == 'CHAT_MSG_CHANNEL' and arg8 == LFG.channelIndex and string.find(arg1, 'lfg_group_formed', 1, true) then
            local gfEx = StringSplit(arg1, ':')
            local code = gfEx[3]
            local time = tonumber(gfEx[4])
            groupsFormedThisSession = groupsFormedThisSession + 1
            if LFG_CONFIG['spamChat'] then
                lfnotice(LFG.dungeonNameFromCode(code) .. ' group just formed. (type "/lfg spam" to disable this message)')
            end
            if me == 'Bennylava' then
                local totalGroups = 0
                for _, number in next, LFG_FORMED_GROUPS do
                    if number ~= 0 then
                        totalGroups = totalGroups + number
                    end
                end
                lfprint(groupsFormedThisSession .. ' this session, ' .. totalGroups .. ' total recorded.')
            end
            if not time then
                return false
            end
            if LFG.averageWaitTime == 0 then
                LFG.averageWaitTime = time
            else
                LFG.averageWaitTime = math.floor((LFG.averageWaitTime + time) / 2)
            end
            if not LFG_FORMED_GROUPS[code] then
                LFG_FORMED_GROUPS[code] = 0
            end
            LFG_FORMED_GROUPS[code] = LFG_FORMED_GROUPS[code] + 1
        end
        if event == 'CHAT_MSG_CHANNEL' and string.find(arg1, '[LFG]', 1, true) and arg8 == LFG.channelIndex and arg2 ~= me and --for lfg
                string.find(arg1, 'party:ready', 1, true) then
            local mEx = StringSplit(arg1, ':')
            LFG.groupFullCode = mEx[2] --code

            local healer = mEx[5]
            local damage1 = mEx[6]
            local damage2 = mEx[7]
            local damage3 = mEx[8]

            --check if party ready message is for me
            if me ~= healer and me ~= damage1 and me ~= damage2 and me ~= damage3 then
                return
            end

            if me == healer then
                LFG.dungeons[LFG.dungeonNameFromCode(LFG.groupFullCode)].myRole = 'healer'
                LFG.SetSingleRole(LFG.dungeons[LFG.dungeonNameFromCode(LFG.groupFullCode)].myRole)
            end
            if me == damage1 or me == damage2 or me == damage3 then
                LFG.dungeons[LFG.dungeonNameFromCode(LFG.groupFullCode)].myRole = 'damage'
                LFG.SetSingleRole(LFG.dungeons[LFG.dungeonNameFromCode(LFG.groupFullCode)].myRole)
            end

            LFG.onlyAcceptFrom = arg2
            LFG.acceptNextInvite = true

            local background = ''
            local dungeonName = 'unknown'
            for d, data in next, LFG.dungeons do
                if data.code == mEx[2] then
                    background = data.background
                    dungeonName = d
                end
            end

            local myRole = LFG.dungeons[LFG.dungeonNameFromCode(LFG.groupFullCode)].myRole

            _G['LFGGroupReadyBackground']:SetTexture('Interface\\addons\\LFG\\images\\background\\ui-lfg-background-' .. background)
            _G['LFGGroupReadyRole']:SetTexture('Interface\\addons\\LFG\\images\\' .. myRole .. '2')
            _G['LFGGroupReadyMyRole']:SetText(LFG.ucFirst(myRole))
            _G['LFGGroupReadyDungeonName']:SetText(dungeonName)

            LFG.readyStatusReset()
            _G['LFGGroupReadyObjectivesCompleted']:SetText('0/' .. LFG.tableSize(LFG.bosses[LFG.groupFullCode]) .. ' Bosses Defeated')
            _G['LFGGroupReady']:Show()
            LFGGroupReadyFrameCloser:Show()
            _G['LFGRoleCheck']:Hide()

            PlaySoundFile("Interface\\Addons\\LFG\\sound\\levelup2.ogg")
            LFGQueue:Hide()

            LFG.findingGroup = false
            LFG.findingMore = false
            _G['LFGlfg']:Hide()

            LFG.fixMainButton()
        end

        if event == 'CHAT_MSG_CHANNEL' and arg8 == LFG.channelIndex and arg2 ~= me then
            if string.sub(arg1, 1, 7) == 'whoLFG:' then
                SendChatMessage('meLFG:' .. addonVer, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            if string.sub(arg1, 1, 6) == 'meLFG:' then
                lfdebug(arg1)
                if LFGWhoCounter.listening then
                    LFGWhoCounter.people = LFGWhoCounter.people + 1
                    if me == 'Bennylava' then
                        local verEx = StringSplit(arg1, ':')
                        local ver = verEx[2]
                        local color = COLOR_GREEN
                        if LFG.ver(ver) < LFG.ver(addonVer) then
                            color = COLOR_ORANGE
                        end
                        lfprint('[' .. LFGWhoCounter.people .. '] ' .. arg2 .. ' - ' .. color .. 'v' .. ver)
                    end
                end
            end
        end

        if event == 'CHAT_MSG_CHANNEL' and arg8 == LFG.channelIndex then
            if string.sub(arg1, 1, 4) == 'LFG:' then
                LFG.peopleLookingForGroups = LFG.peopleLookingForGroups + 1
                if LFG.peopleLookingForGroupsDisplay < LFG.peopleLookingForGroups then
                    LFG.peopleLookingForGroupsDisplay = LFG.peopleLookingForGroups
                end

                local lfgEx = StringSplit(arg1, ' ')

                for _, lfg in ipairs(lfgEx) do
                    local spamSplit = StringSplit(lfg, ':')
                    local mDungeonCode = spamSplit[2]
                    local mRole = spamSplit[3] --other's role

                    if mDungeonCode and mRole then

                        if not LFG.browseNames[mDungeonCode] then
                            LFG.browseNames[mDungeonCode] = {}
                        end
                        if not LFG.browseNames[mDungeonCode][mRole] then
                            LFG.browseNames[mDungeonCode][mRole] = ''
                        end

                        if LFG.browseNames[mDungeonCode][mRole] == '' then
                            LFG.browseNames[mDungeonCode][mRole] = arg2
                        else
                            LFG.browseNames[mDungeonCode][mRole] = LFG.browseNames[mDungeonCode][mRole] .. "\n" .. arg2
                        end

                        LFG.incDungeonssSpamRole(mDungeonCode, mRole)
                        LFG.updateDungeonsSpamDisplay(mDungeonCode)
                    end
                end
            end
        end
        if event == 'CHAT_MSG_CHANNEL' and arg8 == LFG.channelIndex then
            if string.sub(arg1, 1, 4) == 'LFM:' then

                local lfmEx = StringSplit(arg1, ':')
                local mDungeonCode = lfmEx[2] or false
                local lfmTank = tonumber(lfmEx[3]) or 0
                local lfmHealer = tonumber(lfmEx[4]) or 0
                local lfmDamage = tonumber(lfmEx[5]) or 0

                if mDungeonCode then

                    LFG.peopleLookingForGroups = LFG.peopleLookingForGroups + lfmTank + lfmHealer + lfmDamage
                    if LFG.peopleLookingForGroupsDisplay < LFG.peopleLookingForGroups then
                        LFG.peopleLookingForGroupsDisplay = LFG.peopleLookingForGroups
                    end

                    LFG.incDungeonssSpamRole(mDungeonCode, 'tank', lfmTank)
                    LFG.incDungeonssSpamRole(mDungeonCode, 'healer', lfmHealer)
                    LFG.incDungeonssSpamRole(mDungeonCode, 'damage', lfmDamage)
                    LFG.updateDungeonsSpamDisplay(mDungeonCode, true, lfmTank + lfmHealer + lfmDamage)
                end
            end
        end

        if event == 'CHAT_MSG_CHANNEL' and arg8 == LFG.channelIndex and not LFG.oneGroupFull and (LFG.findingGroup or LFG.findingMore) and arg2 ~= me then

            if string.sub(arg1, 1, 6) == 'found:' then
                local foundLongEx = StringSplit(arg1, ' ')

                for i, found in ipairs(foundLongEx) do
                    if string.len(found) > 0 then
                        local foundEx = StringSplit(found, ':')
                        local mRole = foundEx[2]
                        local mDungeon = foundEx[3]
                        local name = foundEx[4]
                        local prio = nil
                        if foundEx[5] then
                            if tonumber(foundEx[5]) then
                                prio = tonumber(foundEx[5])
                            end
                        end

                        if string.find(LFG_ROLE, mRole, 1, true) and not LFG.foundGroup and name == me then
                            LFG.dungeons[LFG.dungeonNameFromCode(mDungeon)].myRole = mRole
                            lfdebug('myRole for ' .. mDungeon .. ' set to ' .. mRole)

                            SendChatMessage('goingWith:' .. arg2 .. ':' .. mDungeon .. ':' .. mRole, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
                            LFG.foundGroup = true
                        end
                    end
                end
            end

            if string.sub(arg1, 1, 10) == 'leftQueue:' then
                local leftEx = StringSplit(arg1, ':')
                local mRole = leftEx[2]
                LFG.removePlayerFromVirtualParty(arg2, mRole)
            end

            if string.sub(arg1, 1, 10) == 'goingWith:' and
                    (string.find(LFG_ROLE, 'tank', 1, true) or LFG.isLeader) then

                local withEx = StringSplit(arg1, ':')
                local leader = withEx[2]
                local mDungeon = withEx[3]
                local mRole = withEx[4]

                --check if im queued for mDungeon
                for dungeon, _ in next, LFG.group do
                    if dungeon == mDungeon then
                        if leader ~= me then
                            -- only healers and damages respond with goingwith
                            LFG.remHealerOrDamage(mDungeon, arg2)
                        end
                    end
                    -- otherwise, dont care
                end

                -- lfm, leader should invite this guy now
                if LFG.isLeader then
                    lfdebug('im leader')
                else
                    lfdebug('im not leader')
                end
                if LFG.isLeader and leader == me then
                    if LFG.isNeededInLFMGroup(mRole, arg2, mDungeon) then
                        if mRole == 'tank' then
                            LFG.addTank(mDungeon, arg2, true, true)
                        end
                        if mRole == 'healer' then
                            LFG.addHealer(mDungeon, arg2, true, true)
                        end
                        if mRole == 'damage' then
                            LFG.addDamage(mDungeon, arg2, true, true)
                        end
                        LFG.inviteInLFMGroup(arg2)
                    end
                end
            end

            -- LFG
            if string.sub(arg1, 1, 4) == 'LFG:' then

                local lfgEx = StringSplit(arg1, ' ')
                local foundMessage = ''
                local prioMembers = GetNumPartyMembers() + 1
                local prioObjectives = LFG.getDungeonCompletion()

                for _, lfg in ipairs(lfgEx) do
                    local spamSplit = StringSplit(lfg, ':')
                    local mDungeonCode = spamSplit[2]
                    local mRole = spamSplit[3] --other's role

                    if mDungeonCode and mRole then

                        for _, data in next, LFG.dungeons do
                            if data.queued and data.code == mDungeonCode then

                                --LFM forming
                                if LFG.isLeader then
                                    if mRole == 'tank' then
                                        if LFG.addTank(mDungeonCode, arg2) then
                                            foundMessage = foundMessage .. 'found:tank:' .. mDungeonCode .. ':' .. arg2 .. ':' .. prioMembers .. ':' .. prioObjectives .. ' '
                                        end
                                    end
                                    if mRole == 'healer' then
                                        if LFG.addHealer(mDungeonCode, arg2) then
                                            foundMessage = foundMessage .. 'found:healer:' .. mDungeonCode .. ':' .. arg2 .. ':' .. prioMembers .. ':' .. prioObjectives .. ' '
                                        end
                                    end
                                    if mRole == 'damage' then
                                        if LFG.addDamage(mDungeonCode, arg2) then
                                            foundMessage = foundMessage .. 'found:damage:' .. mDungeonCode .. ':' .. arg2 .. ':' .. prioMembers .. ':' .. prioObjectives .. ' '
                                        end
                                    end
                                    if foundMessage ~= '' then
                                        SendChatMessage(foundMessage, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
                                    end
                                    return false
                                end

                                -- LFG forming
                                if not LFG.inGroup then
                                    if string.find(LFG_ROLE, 'tank', 1, true) then
                                        LFG.group[mDungeonCode].tank = me

                                        -- if im tank looking for x and i see a different tank looking for x first
                                        -- then supress my next lfg:x:tank
                                        if mRole == 'tank' then
                                            LFG.supress[mDungeonCode] = 'tank'
                                        end

                                        if mRole == 'healer' then
                                            if LFG.addHealer(mDungeonCode, arg2, false, true) then
                                                foundMessage = foundMessage .. 'found:healer:' .. mDungeonCode .. ':' .. arg2 .. ':0:0 '
                                            end
                                        end
                                        if mRole == 'damage' then
                                            if LFG.addDamage(mDungeonCode, arg2, false, true) then
                                                foundMessage = foundMessage .. 'found:damage:' .. mDungeonCode .. ':' .. arg2 .. ':0:0 '
                                            end
                                        end
                                        --end

                                        --pseudo fill group for tooltip display
                                    elseif string.find(LFG_ROLE, 'healer', 1, true) then
                                        LFG.addHealer(mDungeonCode, me, true, true) --faux, me

                                        if mRole == 'tank' then
                                            LFG.addTank(mDungeonCode, arg2, true, true) --faux, tank
                                        end
                                        if mRole == 'damage' then
                                            LFG.addDamage(mDungeonCode, arg2, true, true) --faux, dps
                                        end
                                        --end

                                    elseif string.find(LFG_ROLE, 'damage', 1, true) then
                                        LFG.addDamage(mDungeonCode, me, true, true) --faux

                                        if mRole == 'tank' and LFG.group[mDungeonCode].tank == '' then
                                            LFG.addTank(mDungeonCode, arg2, true, true) --faux, tank
                                        end
                                        if mRole == 'healer' and LFG.group[mDungeonCode].healer == '' then
                                            LFG.addHealer(mDungeonCode, arg2, true, true) -- fause healer
                                        end
                                        if mRole == 'damage' then
                                            LFG.addDamage(mDungeonCode, arg2, true, true) --faux, dps
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                SendChatMessage(foundMessage, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))

            end
        end
    end
end)

-- debug and print functions

function lfprint(a)
    if a == nil then
        DEFAULT_CHAT_FRAME:AddMessage(COLOR_HUNTER .. '[LFG]|cff0070de:' .. time() .. '|cffffffff attempt to print a nil value.')
        return false
    end
    DEFAULT_CHAT_FRAME:AddMessage(COLOR_HUNTER .. "[LFG] |cffffffff" .. a)
end

function lfnotice(a)
    DEFAULT_CHAT_FRAME:AddMessage(COLOR_HUNTER .. "[LFG] " .. COLOR_ORANGE .. a)
end

function lferror(a)
    DEFAULT_CHAT_FRAME:AddMessage('|cff69ccf0[LFGError]|cff0070de:' .. time() .. '|cffffffff[' .. a .. ']')
end

function lfdebug(a)
    if not LFG_CONFIG['debug'] then
        return false
    end
    if type(a) == 'boolean' then
        if a then
            lfprint('|cff0070de[LFGDEBUG:' .. time() .. ']|cffffffff[true]')
        else
            lfprint('|cff0070de[LFGDEBUG:' .. time() .. ']|cffffffff[false]')
        end
        return true
    end
    --lfprint('|cff0070de[LFGDEBUG:' .. time() .. ']|cffffffff[' .. a .. ']')
end

local hookChatFrame = function(frame)
    lfdebug('chat frame hook using GetGameTime()')

    -- Get hour and minute from server
    local hour, minute = GetGameTime()

    -- Convert hours and minutes to seconds
    local totalSeconds = (hour * 3600) + (minute * 60)

    -- Calculate just the seconds portion (0-59)
    LFGTime.second = totalSeconds % 60
    LFGTime.diff = 0

    -- Reset and start the timer
    LFGTime:Hide()
    LFGTime:Show()

    lfdebug('Using server time: ' .. hour .. ':' .. minute .. ' (second value: ' .. LFGTime.second .. ')')
end


LFG:SetScript("OnEvent", function()
    if event then
        if event == "ADDON_LOADED" and arg1 == 'LFG' then
            LFG.init()
        end
        if event == "PLAYER_TARGET_CHANGED" and LFG.inGroup then
            if _G['TargetFrame']:IsVisible() then
                if LFG.currentGroupRoles[UnitName('target')] then
                    _G['LFGPartyRoleIconsTarget']:SetTexture('Interface\\addons\\LFG\\images\\' .. LFG.currentGroupRoles[UnitName('target')] .. '_small')
                    _G['LFGPartyRoleIconsTarget']:Show()
                end
            else
                _G['LFGPartyRoleIconsTarget']:Hide()
            end
        end
        if event == "PLAYER_ENTERING_WORLD" then
            LFG.level = UnitLevel('player')
            LFG.sendMyVersion()
            lfdebug('PLAYER_ENTERING_WORLD')
            hookChatFrame(ChatFrame1);
            lfdebug(arg1)
            lfdebug(arg2)
        end
        if event == "PARTY_LEADER_CHANGED" then

            BrowseDungeonListFrame_Update()

            if LFG.isLeader and IsPartyLeader() then
                lfdebug('end PARTY_LEADER_CHANGED - missfire ?')
                return false
            end

            LFG.isLeader = IsPartyLeader()
            if GetNumPartyMembers() + 1 == LFG.groupSizeMax then
            else
                -- only leave queue if im in queue
                if LFG.isLeader and (LFG.findingGroup or LFG.findingMore) then
                    leaveQueue('party leader changed group < 5 ')
                end
            end
        end
        if event == "PARTY_MEMBERS_CHANGED" then
            lfdebug('PARTY_MEMBERS_CHANGED') --check -- triggers in raids too
            DungeonListFrame_Update()

            if not LFG.inGroup then
                LFG.currentGroupSize = 1
            end
            lfdebug('joineed' .. GetNumPartyMembers() + 1 .. ' > ' .. LFG.currentGroupSize)
            lfdebug('left' .. GetNumPartyMembers() + 1 .. ' < ' .. LFG.currentGroupSize)

            local someoneJoined = GetNumPartyMembers() + 1 > LFG.currentGroupSize
            local someoneLeft = GetNumPartyMembers() + 1 < LFG.currentGroupSize

            LFG.currentGroupSize = GetNumPartyMembers() + 1
            LFG.inGroup = GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0

            BrowseDungeonListFrame_Update()

            if not someoneLeft and not someoneJoined then
                lfdebug('end PARTY_MEMBERS_CHANGED - missfire ?')

                if not LFG.inGroup then
                    LFGDelayLeaveQueue.reason = 'i left grou --- i think'
                    LFGDelayLeaveQueue:Show()
                end

                return false
            end

            if LFG.inGroup then
                if LFG.isLeader then
                else
                    _G['LFGlfg']:Hide()
                end
            else
                -- i left the group OR everybody left
                lfdebug('LFGInvite.inviteIndex = ' .. LFGInvite.inviteIndex)
                LFG.GetPossibleRoles()
                LFG.hidePartyRoleIcons()

                _G['LFGDungeonStatus']:Hide()
                _G['LFGRoleCheck']:Hide()

                -- i left when there was a dungeon in progress
                if LFGDungeonComplete.dungeonInProgress then
                    -- todo: ban player for 5 minutes
                    LFGDungeonComplete.dungeonInProgress = false
                end

                if LFGInvite.inviteIndex == 1 then
                    return false
                end
                if LFG.findingGroup or LFG.findingMore then
                    leaveQueue('not group and finding group/more')
                end

                return false
            end

            if someoneJoined then

                if LFG.findingMore then
                    -- send him objectives
                    local objectivesString = ''
                    for index, _ in next, LFG.objectivesFrames do
                        if LFG.objectivesFrames[index].completed then
                            objectivesString = objectivesString .. '1-'
                        else
                            objectivesString = objectivesString .. '0-'
                        end
                    end
                    SendAddonMessage(LFG_ADDON_CHANNEL, "objectives:" .. LFG.LFMDungeonCode .. ":" .. objectivesString, "PARTY")
                    -- end send objectives
                    if LFG.isLeader then

                        local newName = ''
                        local joinedManually = false
                        for i = 1, GetNumPartyMembers() do
                            local name = UnitName('party' .. i)
                            local fromQueue = name == LFG.group[LFG.LFMDungeonCode].tank or
                                    name == LFG.group[LFG.LFMDungeonCode].healer or
                                    name == LFG.group[LFG.LFMDungeonCode].damage1 or
                                    name == LFG.group[LFG.LFMDungeonCode].damage2 or
                                    name == LFG.group[LFG.LFMDungeonCode].damage3

                            if not fromQueue then
                                newName = name
                                joinedManually = true
                            end
                        end
                        if joinedManually then
                            --joined manually, dont know his role

                            LFGFillAvailableDungeonsDelay.queueAfterIfPossible = GetNumPartyMembers() < (LFG.groupSizeMax - 1)

                            if not LFGFillAvailableDungeonsDelay.queueAfterIfPossible then
                                --group full
                                SendAddonMessage(LFG_ADDON_CHANNEL, "LFMPartyReady:" .. LFG.LFMDungeonCode .. ":" .. LFGObjectives.objectivesComplete .. ":" .. LFG.tableSize(LFG.bosses[LFG.LFMDungeonCode]), "PARTY")
                                return false -- so it goes into check full in timer
                            end
                            leaveQueue(' someone joined manually')
                            findMore()
                        else
                            --joined from the queue, we know his role, check if group is full
                            --  lfdebug('player ' .. newName .. ' joined from queue')
                            if LFG.checkLFMGroupReady(LFG.LFMDungeonCode) then
                                SendAddonMessage(LFG_ADDON_CHANNEL, "LFMPartyReady:" .. LFG.LFMDungeonCode .. ":" .. LFGObjectives.objectivesComplete .. ":" .. LFG.tableSize(LFG.bosses[LFG.LFMDungeonCode]), "PARTY")
                            else
                                SendAddonMessage(LFG_ADDON_CHANNEL, "weInQueue:" .. LFG.LFMDungeonCode, "PARTY")
                            end
                        end
                    end

                else
                    -- disable dungeon checks if i have more than one and i join a party
                    for _, data in next, LFG.dungeons do
                        data.queue = false
                        if _G["Dungeon_" .. data.code .. '_CheckButton'] then
                            _G["Dungeon_" .. data.code .. '_CheckButton']:SetChecked(false)
                        end
                    end
                    DungeonListFrame_Update()
                end

            end
            if someoneLeft then
                LFG.showPartyRoleIcons()
                _G['LFGReadyStatus']:Hide()
                _G['LFGGroupReady']:Hide()
                -- find who left and update virtual group
                if LFG.findingMore --then
                        and LFG.isLeader then

                    --inc some getto code
                    lfdebug('someone left')
                    local leftName = ''
                    local stillInParty = false
                    if LFG.group[LFG.LFMDungeonCode].tank ~= '' and LFG.group[LFG.LFMDungeonCode].tank ~= me then
                        leftName = LFG.group[LFG.LFMDungeonCode].tank
                        stillInParty = false
                        for i = 1, GetNumPartyMembers() do
                            local name = UnitName('party' .. i)
                            if leftName == name then
                                stillInParty = true
                                break
                            end
                        end
                        if not stillInParty then
                            LFG.group[LFG.LFMDungeonCode].tank = ''
                            LFG.LFMGroup.tank = ''
                            lfprint(leftName .. ' (' .. COLOR_TANK .. 'Tank' .. COLOR_WHITE .. ') has been removed from the queue group.')
                        end
                    end
                    --
                    if LFG.group[LFG.LFMDungeonCode].healer ~= '' and LFG.group[LFG.LFMDungeonCode].healer ~= me then
                        leftName = LFG.group[LFG.LFMDungeonCode].healer
                        stillInParty = false
                        for i = 1, GetNumPartyMembers() do
                            local name = UnitName('party' .. i)
                            if leftName == name then
                                stillInParty = true
                                break
                            end
                        end
                        if not stillInParty then
                            LFG.group[LFG.LFMDungeonCode].healer = ''
                            LFG.LFMGroup.healer = ''
                            lfprint(leftName .. ' (' .. COLOR_HEALER .. 'Healer' .. COLOR_WHITE .. ') has been removed from the queue group.')
                        end
                    end
                    --
                    if LFG.group[LFG.LFMDungeonCode].damage1 ~= '' and LFG.group[LFG.LFMDungeonCode].damage1 ~= me then
                        leftName = LFG.group[LFG.LFMDungeonCode].damage1
                        stillInParty = false
                        for i = 1, GetNumPartyMembers() do
                            local name = UnitName('party' .. i)
                            if leftName == name then
                                stillInParty = true
                                break
                            end
                        end
                        if not stillInParty then
                            LFG.group[LFG.LFMDungeonCode].damage1 = ''
                            LFG.LFMGroup.damage1 = ''
                            lfprint(leftName .. ' (' .. COLOR_DAMAGE .. 'Damage' .. COLOR_WHITE .. ') has been removed from the queue group.')
                        end
                    end
                    --
                    if LFG.group[LFG.LFMDungeonCode].damage2 ~= '' and LFG.group[LFG.LFMDungeonCode].damage2 ~= me then
                        leftName = LFG.group[LFG.LFMDungeonCode].damage2
                        stillInParty = false
                        for i = 1, GetNumPartyMembers() do
                            local name = UnitName('party' .. i)
                            if leftName == name then
                                stillInParty = true
                                break
                            end
                        end
                        if not stillInParty then
                            LFG.group[LFG.LFMDungeonCode].damage2 = ''
                            LFG.LFMGroup.damage2 = ''
                            lfprint(leftName .. ' (' .. COLOR_DAMAGE .. 'Damage' .. COLOR_WHITE .. ') has been removed from the queue group.')
                        end
                    end
                    --
                    if LFG.group[LFG.LFMDungeonCode].damage3 ~= '' and LFG.group[LFG.LFMDungeonCode].damage3 ~= me then
                        leftName = LFG.group[LFG.LFMDungeonCode].damage3
                        stillInParty = false
                        for i = 1, GetNumPartyMembers() do
                            local name = UnitName('party' .. i)
                            if leftName == name then
                                stillInParty = true
                                break
                            end
                        end
                        if not stillInParty then
                            LFG.group[LFG.LFMDungeonCode].damage3 = ''
                            LFG.LFMGroup.damage3 = ''
                            lfprint(leftName .. ' (' .. COLOR_DAMAGE .. 'Damage' .. COLOR_WHITE .. ') has been remove from the queue group.')
                        end
                    end
                end
            end
            lfdebug('ajunge aici ??')
            if LFG.isLeader then
                LFG.sendMinimapDataToParty(LFG.LFMDungeonCode)
            end
            -- update awesome button enabled if 5/5 disabled + text if not
            local awesomeButton = _G['LFGGroupReadyAwesome']
            awesomeButton:SetText('Waiting Players (' .. LFG.groupSizeMax - GetNumPartyMembers() - 1 .. ')')
            awesomeButton:Disable()

            if GetNumPartyMembers() == LFG.groupSizeMax - 1 then
                awesomeButton:SetText('Let\'s do this!')
                awesomeButton:Enable()
            end
            lfdebug(' end PARTY_MEMBERS_CHANGED')
        end
        if event == 'PLAYER_LEVEL_UP' then
            LFG.level = arg1
            LFG.fillAvailableDungeons()
        end
    end
end)

function LFG.hideButtonTextures(buttonName)
    local button = _G[buttonName]
    if button then
        lfdebug("Hiding textures for button: " .. buttonName)
        
        -- More aggressive texture hiding
        button:SetNormalTexture(nil)
        button:SetPushedTexture(nil) 
        button:SetHighlightTexture(nil)
        button:SetDisabledTexture(nil)
        
        -- Hide existing texture objects
        local normalTexture = button:GetNormalTexture()
        if normalTexture then
            normalTexture:SetTexture("")
            normalTexture:Hide()
        end
        
        local pushedTexture = button:GetPushedTexture()
        if pushedTexture then
            pushedTexture:SetTexture("")
            pushedTexture:Hide()
        end
        
        local highlightTexture = button:GetHighlightTexture()
        if highlightTexture then
            highlightTexture:SetTexture("")
            highlightTexture:Hide()
        end
        
        -- Make the button completely transparent
        button:SetAlpha(0)
    else
        lfdebug("Button not found: " .. buttonName)
    end
end

function LFG.hideAllAddonButtonTextures()
    -- Hide role tooltip buttons
    LFG.hideButtonTextures("RoleCheckRoleDamageTooltipButton")
    LFG.hideButtonTextures("RoleCheckRoleTankTooltipButton") 
    LFG.hideButtonTextures("RoleCheckRoleHealerTooltipButton")
    LFG.hideButtonTextures("RoleTankTooltipButton")
    LFG.hideButtonTextures("RoleHealerTooltipButton")
    LFG.hideButtonTextures("RoleDamageTooltipButton")
    
    -- Hide tab buttons
    LFG.hideButtonTextures("LFGBrowseButton")
    LFG.hideButtonTextures("LFGDungeonsButton")
    
    -- Hide dungeon list buttons
    for code, frame in next, LFG.availableDungeons do
        if frame then
            LFG.hideButtonTextures("Dungeon_" .. code .. "_Button")
        end
    end
    
    -- Hide browse buttons
    for code, frame in next, LFG.browseFrames do
        if frame then
            LFG.hideButtonTextures("BrowseFrame_" .. code .. "_JoinAs")
        end
    end
end

function LFG.init()

    if not LFG_CONFIG then
        LFG_CONFIG = {}
        LFG_CONFIG['debug'] = false
        LFG_CONFIG['spamChat'] = true
    end

    if LFG_CONFIG['debug'] then
        _G['LFGTitleTime']:Show()
    else
        _G['LFGTitleTime']:Hide()
    end
    local _, uClass = UnitClass('player')
    LFG.class = string.lower(uClass)

    if not LFG_TYPE then
        LFG_TYPE = 1
    end

    UIDropDownMenu_SetText(_G['LFGTypeSelect'], LFG.types[LFG_TYPE]);

        _G['LFGMainDungeonsText']:SetText('Dungeons')
        _G['LFGBrowseDungeonsText']:SetText('Dungeons')

    _G['LFGDungeonsText']:SetText(LFG.types[LFG_TYPE])
    if not LFG_ROLE then
        LFG.SetSingleRole('tank')
        LFG.SetSingleRole(LFG.GetPossibleRoles())
    else
        LFG.GetPossibleRoles()
        LFGsetRole(LFG_ROLE)
    end

    if not LFG_FORMED_GROUPS then
        LFG.resetFormedGroups()
    else
        --check if formed groups include maybe new dungeon codes
        for _, data in next, LFG.dungeons do
            if not LFG_FORMED_GROUPS[data.code] then
                LFG_FORMED_GROUPS[data.code] = 0
            end
        end
    end

    LFG.channelIndex = 0
    LFG.level = UnitLevel('player')
    LFG.findingGroup = false
    LFG.findingMore = false
    LFG.availableDungeons = {}
    LFG.group = {}
    LFG.oneGroupFull = false
    LFG.groupFullCode = ''
    LFG.acceptNextInvite = false
    LFG.currentGroupSize = GetNumPartyMembers() + 1

    LFG.isLeader = IsPartyLeader() or false

    LFG.inGroup = GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0
    LFG.fixMainButton()

    LFG.fillAvailableDungeons()

    LFGChannelJoinDelay:Show()

    LFG.objectivesFrames = {}
    LFGDungeonComplete.dungeonInProgress = false

    _G['LFGGroupReadyAwesome']:Disable()

    --lfprint(COLOR_HUNTER .. 'Looking For Group v' .. addonVer .. COLOR_WHITE .. ' - LFG Addon for Project Epoch loaded.')

    local dungeonsButton = _G['LFGBrowseButton']

    dungeonsButton:SetScript("OnEnter", function()
        _G['LFGBrowseButtonHighlight']:Show()
    end)
    dungeonsButton:SetScript("OnLeave", function()
        _G['LFGBrowseButtonHighlight']:Hide()
    end)

    local dungeonsButton = _G['LFGDungeonsButton']

    dungeonsButton:SetScript("OnEnter", function()
        _G['LFGDungeonsButtonHighlight']:Show()
    end)
    dungeonsButton:SetScript("OnLeave", function()
        _G['LFGDungeonsButtonHighlight']:Hide()
    end)

    if LFG.shouldHideButtonTextures() then
	    LFG.hideButtonTextures("RoleCheckRoleDamageTooltipButton")
	    LFG.hideButtonTextures("RoleCheckRoleTankTooltipButton")
	    LFG.hideButtonTextures("RoleCheckRoleHealerTooltipButton")
	    LFG.hideButtonTextures("RoleTankTooltipButton")
	    LFG.hideButtonTextures("RoleHealerTooltipButton")
	    LFG.hideButtonTextures("RoleDamageTooltipButton")
	end

    for dungeon, data in next, LFG.dungeons do
        if not LFG.dungeonsSpam[data.code] then
            LFG.dungeonsSpam[data.code] = {
                tank = 0,
                healer = 0,
                damage = 0
            }
        end
        if not LFG.dungeonsSpamDisplay[data.code] then
            LFG.dungeonsSpamDisplay[data.code] = {
                tank = 0,
                healer = 0,
                damage = 0
            }
            LFG.dungeonsSpamDisplayLFM[data.code] = 0
        end
    end
end

LFGQueue:SetScript("OnShow", function()
    this.startTime = GetTime()
    this.spammed = {
        tank = false,
        damage = false,
        heal = false,
        reset = false,
        lfm = false,
        checkGroupFull = false
    }
end)

LFGQueue:SetScript("OnHide", function()
    LFGMinimapAnimation:Hide()
end)

LFGQueue:SetScript("OnUpdate", function()
    local plus = 1 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st and LFG.findingGroup then
        this.startTime = GetTime()

        if LFGTime.second == -1 then
            return false
        end

        _G['LFGTitleTime']:SetText(LFGTime.second)
        _G['LFGGroupStatusTimeInQueue']:SetText('Time in Queue: ' .. SecondsToTime(time() - LFG.queueStartTime))
        if LFG.averageWaitTime == 0 then
            _G['LFGGroupStatusAverageWaitTime']:SetText('Average Wait Time: Unavailable')
        else
            _G['LFGGroupStatusAverageWaitTime']:SetText('Average Wait Time: ' .. SecondsToTimeAbbrev(LFG.averageWaitTime))
        end

        if (LFGTime.second == LFG.RESET_TIME or LFGTime.second == LFG.RESET_TIME + LFG.TIME_MARGIN) and not this.spammed.reset then
            lfdebug('reset -- call -- spam')
            this.spammed = {
                tank = false,
                damage = false,
                heal = false,
                reset = false,
                lfm = false,
                checkGroupFull = false
            }
            if not LFG.inGroup then
                LFG.resetGroup()
            end
        end

        if (LFGTime.second == LFG.RESET_TIME + 2 or LFGTime.second == LFG.RESET_TIME + 2 + LFG.TIME_MARGIN) and not this.spammed.lfm then
            if LFG.isLeader then
                LFG.sendLFMStats(LFG.LFMDungeonCode)
                this.spammed.lfm = true
            end
        end

        if (LFGTime.second == LFG.TANK_TIME + LFG.myRandomTime or LFGTime.second == LFG.TANK_TIME + LFG.TIME_MARGIN + LFG.myRandomTime) and
                string.find(LFG_ROLE, 'tank', 1, true) and not this.spammed.tank then
            this.spammed.tank = true
            if not LFG.inGroup then
                -- only start forming group if im not already grouped
                for _, data in next, LFG.dungeons do
                    if data.queued then
                        LFG.group[data.code].tank = me
                    end
                end
                --new: but do send lfg message if im a tank, to be picked up by LFM party leader
                LFG.sendLFGMessage('tank')
            end
        end

        if (LFGTime.second == LFG.HEALER_TIME + LFG.myRandomTime or LFGTime.second == LFG.HEALER_TIME + LFG.TIME_MARGIN + LFG.myRandomTime) and
                string.find(LFG_ROLE, 'healer', 1, true) and not this.spammed.heal then
            this.spammed.heal = true
            if not LFG.inGroup then
                -- dont spam lfm if im already in a group, because leader will pick up new players
                LFG.sendLFGMessage('healer')
            end
        end

        if (LFGTime.second == LFG.DAMAGE_TIME + LFG.myRandomTime or LFGTime.second == LFG.DAMAGE_TIME + LFG.TIME_MARGIN + LFG.myRandomTime) and
                string.find(LFG_ROLE, 'damage', 1, true) and not this.spammed.damage then
            this.spammed.damage = true
            if not LFG.inGroup then
                -- dont spam lfm if im already in a group, because leader will pick up new players
                LFG.sendLFGMessage('damage')
            end
        end

        if (LFGTime.second == LFG.FULLCHECK_TIME or LFGTime.second == LFG.FULLCHECK_TIME + LFG.TIME_MARGIN) and
                string.find(LFG_ROLE, 'tank', 1, true) and not this.spammed.checkGroupFull then
            this.spammed.checkGroupFull = true
            if not LFG.inGroup then

                local groupFull, code, healer, damage1, damage2, damage3 = LFG.checkGroupFull()

                if groupFull then
                    LFG.groupFullCode = code

                    LFG.dungeons[LFG.dungeonNameFromCode(LFG.groupFullCode)].myRole = 'tank'

                    LFG.SetSingleRole('tank')

                    SendChatMessage("[LFG]:" .. code .. ":party:ready:" .. healer .. ":" .. damage1 .. ":" .. damage2 .. ":" .. damage3, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))

                    SendChatMessage("[LFG]:lfg_group_formed:" .. code .. ":" .. time() - LFG.queueStartTime, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))

                    --untick everything
                    for dungeon, data in next, LFG.dungeons do
                        if _G["Dungeon_" .. data.code .. '_CheckButton'] then
                            _G["Dungeon_" .. data.code .. '_CheckButton']:SetChecked(false)
                        end
                        LFG.dungeons[dungeon].queued = false
                    end

                    LFG.findingGroup = false
                    LFG.findingMore = false

                    local background = ''
                    local dungeonName = 'unknown'
                    for d, data in next, LFG.dungeons do
                        if data.code == code then
                            background = data.background
                            dungeonName = d
                        end
                    end

                    _G['LFGGroupReadyBackground']:SetTexture('Interface\\addons\\LFG\\images\\background\\ui-lfg-background-' .. background)
                    _G['LFGGroupReadyRole']:SetTexture('Interface\\addons\\LFG\\images\\' .. LFG_ROLE .. '2')
                    _G['LFGGroupReadyMyRole']:SetText(LFG.ucFirst(LFG_ROLE))
                    _G['LFGGroupReadyDungeonName']:SetText(dungeonName)
                    LFG.readyStatusReset()
                    _G['LFGGroupReady']:Show()
                    LFGGroupReadyFrameCloser:Show()

                    _G['LFGRoleCheck']:Hide()

                    PlaySoundFile("Interface\\Addons\\LFG\\sound\\levelup2.ogg")
                    LFGQueue:Hide()

                    LFG.fixMainButton()
                    _G['LFGlfg']:Hide()
                    LFGInvite:Show()
                end
            end

        end

    end
end)

function LFG.shouldHideButtonTextures()
    return IsAddOnLoaded("pretty_patchkit")
end

function LFG.checkLFGChannel()
    lfdebug('check LFG channel call - after 15s')

    local chanList = { GetChannelList() }
    LFG.channelIndex = 0

    for i = 1, #chanList, 2 do
        local channelIndex = chanList[i]
        local channelName = chanList[i + 1]

        if channelName == LFG.channel then
            LFG.channelIndex = channelIndex
            lfdebug('Found LFG channel at index: ' .. LFG.channelIndex)

            if LFG.channelIndex == 1 then
                lfprint('WARNING: LFG channel in slot 1, leaving and rejoining...')
                LeaveChannelByName(LFG.channel)
                LFG.channelIndex = 0
                local retryFrame = CreateFrame("Frame")
                retryFrame.elapsed = 0
                retryFrame:SetScript("OnUpdate", function(self, elapsed)
                    self.elapsed = self.elapsed + elapsed
                    if self.elapsed >= 3 then
                        JoinChannelByName(LFG.channel)
                        self:SetScript("OnUpdate", nil)
                    end
                end)
                return
            end
            break
        end
    end

    if LFG.channelIndex == 0 then
        lfdebug('not in chan, joining')
        JoinChannelByName(LFG.channel)
    else
        lfdebug('in chan, chilling LFG.channelIndex = ' .. LFG.channelIndex)
    end
end

function LFG.joinLFGChannelSafely()
    local generalIndex = GetChannelName("General")
    if generalIndex ~= 1 then
        lfdebug('General channel moved, aborting LFG join')
        local retryFrame = CreateFrame("Frame")
        retryFrame.elapsed = 0
        retryFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= 3 then
                LFG.checkLFGChannel()
                self:SetScript("OnUpdate", nil)
            end
        end)
        return
    end

    JoinChannelByName(LFG.channel)

    local verifyFrame = CreateFrame("Frame")
    verifyFrame.elapsed = 0
    verifyFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 1 then
            local lfgIndex = GetChannelName(LFG.channel)
            if lfgIndex == 1 then
                lfprint('ERROR: LFG channel took channel 1! Fixing immediately...')
                LFG.fixChannelConflict()
            else
                LFG.channelIndex = lfgIndex
                lfdebug('LFG channel safely joined at index: ' .. LFG.channelIndex)
            end
            self:SetScript("OnUpdate", nil)
        end
    end)
end

function LFG.fixChannelConflict()
    lfdebug('Attempting to fix channel 1 conflict')

    LeaveChannelByName(LFG.channel)
    LFG.channelIndex = 0

    local fixFrame = CreateFrame("Frame")
    fixFrame.elapsed = 0
    fixFrame.attempts = 0
    fixFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 3 then
            self.elapsed = 0
            self.attempts = self.attempts + 1

            local generalIndex = GetChannelName("General")
            if generalIndex == 1 then
                lfdebug('General restored to channel 1, rejoining LFG')
                LFG.joinLFGChannelSafely()
                self:SetScript("OnUpdate", nil)
            elseif self.attempts >= 10 then
                lfprint('Unable to restore proper channel order. Please /reload if issues persist.')
                self:SetScript("OnUpdate", nil)
            else
                lfdebug('General still not in channel 1, attempt: ' .. self.attempts)
            end
        end
    end)
end

function LFG.GetPossibleRoles()

    local tankCheck = _G['RoleTank']
    local healerCheck = _G['RoleHealer']
    local damageCheck = _G['RoleDamage']

    --ready check window
    local readyCheckTank = _G['roleCheckTank']
    local readyCheckHealer = _G['roleCheckHealer']
    local readyCheckDamage = _G['roleCheckDamage']

    tankCheck:Disable()
    tankCheck:Hide()
    tankCheck:SetChecked(false)
    healerCheck:Disable()
    healerCheck:Hide()
    healerCheck:SetChecked(false)
    damageCheck:Disable()
    damageCheck:Hide()
    damageCheck:SetChecked(false)

    readyCheckTank:Disable()
    readyCheckTank:Hide()
    readyCheckTank:SetChecked(false)
    readyCheckHealer:Disable()
    readyCheckHealer:Hide()
    readyCheckHealer:SetChecked(false)
    readyCheckDamage:Disable()
    readyCheckDamage:Hide()
    readyCheckDamage:SetChecked(false)

    _G['LFGTankBackground2']:SetDesaturated(1)
    _G['LFGHealerBackground2']:SetDesaturated(1)
    _G['LFGDamageBackground2']:SetDesaturated(1)

    _G['LFGRoleCheckRoleTank']:SetDesaturated(1)
    _G['LFGRoleCheckRoleHealer']:SetDesaturated(1)
    _G['LFGRoleCheckRoleDamage']:SetDesaturated(1)

    if LFG.class == 'warrior' then

        tankCheck:Enable()
        tankCheck:Show()

        readyCheckTank:Enable()
        readyCheckTank:Show()
        readyCheckTank:SetChecked(true)

        damageCheck:Enable()
        damageCheck:Show()

        readyCheckDamage:Enable()
        readyCheckDamage:Show()
        readyCheckDamage:SetChecked(false)

        tankCheck:SetChecked(string.find(LFG_ROLE, 'tank', 1, true))
        healerCheck:SetChecked(false)
        damageCheck:SetChecked(string.find(LFG_ROLE, 'damage', 1, true))

        _G['LFGTankBackground2']:SetDesaturated(0)
        _G['LFGDamageBackground2']:SetDesaturated(0)

        _G['LFGRoleCheckRoleTank']:SetDesaturated(0)
        _G['LFGRoleCheckRoleDamage']:SetDesaturated(0)

        return 'tank'
    end
    if LFG.class == 'paladin' or LFG.class == 'druid' or LFG.class == 'shaman' then

        tankCheck:Enable()
        tankCheck:Show()

        readyCheckTank:Enable()
        readyCheckTank:Show()
        readyCheckTank:SetChecked(false)

        healerCheck:Enable()
        healerCheck:Show()

        readyCheckHealer:Enable()
        readyCheckHealer:Show()
        readyCheckHealer:SetChecked(true)

        damageCheck:Enable()
        damageCheck:Show()

        readyCheckDamage:Enable()
        readyCheckDamage:Show()
        readyCheckDamage:SetChecked(false)

        tankCheck:SetChecked(string.find(LFG_ROLE, 'tank', 1, true))
        healerCheck:SetChecked(string.find(LFG_ROLE, 'healer', 1, true))
        damageCheck:SetChecked(string.find(LFG_ROLE, 'damage', 1, true))

        _G['LFGTankBackground2']:SetDesaturated(0)
        _G['LFGHealerBackground2']:SetDesaturated(0)
        _G['LFGDamageBackground2']:SetDesaturated(0)

        _G['LFGRoleCheckRoleTank']:SetDesaturated(0)
        _G['LFGRoleCheckRoleHealer']:SetDesaturated(0)
        _G['LFGRoleCheckRoleDamage']:SetDesaturated(0)

        return 'healer'
    end
    if LFG.class == 'priest' then

        healerCheck:Enable()
        healerCheck:Show()
        readyCheckHealer:Enable()
        readyCheckHealer:Show()
        readyCheckHealer:SetChecked(true)

        damageCheck:Enable()
        damageCheck:Show()
        readyCheckDamage:Enable()
        readyCheckDamage:Show()
        readyCheckDamage:SetChecked(false)

        tankCheck:SetChecked(false)
        healerCheck:SetChecked(string.find(LFG_ROLE, 'healer', 1, true))
        damageCheck:SetChecked(string.find(LFG_ROLE, 'damage', 1, true))

        _G['LFGHealerBackground2']:SetDesaturated(0)
        _G['LFGDamageBackground2']:SetDesaturated(0)

        _G['LFGRoleCheckRoleHealer']:SetDesaturated(0)
        _G['LFGRoleCheckRoleDamage']:SetDesaturated(0)

        return 'healer'
    end
    if LFG.class == 'warlock' or LFG.class == 'hunter' or LFG.class == 'mage' or LFG.class == 'rogue' then

        damageCheck:Enable()
        damageCheck:Show()

        readyCheckDamage:Enable()
        readyCheckDamage:Show()
        readyCheckDamage:SetChecked(true)

        tankCheck:SetChecked(false)
        healerCheck:SetChecked(false)
        damageCheck:SetChecked(string.find(LFG_ROLE, 'damage', 1, true))

        _G['LFGDamageBackground2']:SetDesaturated(0)
        _G['LFGRoleCheckRoleDamage']:SetDesaturated(0)

        return 'damage'
    end

    tankCheck:SetChecked(string.find(LFG_ROLE, 'tank', 1, true))
    healerCheck:SetChecked(string.find(LFG_ROLE, 'healer', 1, true))
    damageCheck:SetChecked(string.find(LFG_ROLE, 'damage', 1, true))

    return 'damage'
end

function LFG.getAvailableDungeons(level, type, mine, partyIndex)
    if level == 0 then
        return {}
    end
    local dungeons = {}

    local sourceData
    if type == 2 then
        sourceData = LFG.eliteEncounters
    else
        sourceData = LFG.allDungeons
    end

    for _, data in next, sourceData do
        if level >= data.minLevel and (level <= data.maxLevel or (not mine)) and type ~= 3 then
            dungeons[data.code] = true
        end
        if level >= data.minLevel and type == 3 then
            --all available
            dungeons[data.code] = true
        end
    end
    return dungeons
end

function LFG.fillAvailableDungeons(queueAfter, dont_scroll)

    if LFG_TYPE == 2 then
        -- Elite Encounters
        LFG.dungeons = LFG.eliteEncounters
    else
        -- Regular dungeons
        LFG.dungeons = LFG.allDungeons
    end

    --unqueue queued
    for dungeon, data in next, LFG.dungeons do
        LFG.dungeons[dungeon].canQueue = true
        if data.queued and LFG.level < data.minLevel then
            LFG.dungeons[dungeon].queued = false
        end
    end

    --hide all
    for _, frame in next, LFG.availableDungeons do
        _G["Dungeon_" .. frame.code]:Hide()
    end

    -- if grouped fill only dungeons that can be joined by EVERYONE
    if LFG.inGroup then

        local party = {
            [0] = {
                level = LFG.level,
                name = UnitName('player'),
                dungeons = LFG.getAvailableDungeons(LFG.level, LFG_TYPE, true)
            }
        }
        for i = 1, GetNumPartyMembers() do
            party[i] = {
                level = UnitLevel('party' .. i),
                name = UnitName('party' .. i),
                dungeons = LFG.getAvailableDungeons(UnitLevel('party' .. i), LFG_TYPE, false, i)
            }

            if party[i].level == 0 and UnitIsConnected('party' .. i) then
                LFGFillAvailableDungeonsDelay:Show()
                return false
            end
        end

        LFGFillAvailableDungeonsDelay.triggers = 0

        for dungeonCode in next, LFG.getAvailableDungeons(LFG.level, LFG_TYPE, true) do
            local canAdd = {
                [1] = UnitLevel('party1') == 0,
                [2] = UnitLevel('party2') == 0,
                [3] = UnitLevel('party3') == 0,
                [4] = UnitLevel('party4') == 0
            }

            for i = 1, GetNumPartyMembers() do
                for code in next, party[i].dungeons do
                    if dungeonCode == code then
                        canAdd[i] = true
                    end
                end
            end
            if canAdd[1] and canAdd[2] and canAdd[3] and canAdd[4] then
            else
                LFG.dungeons[LFG.dungeonNameFromCode(dungeonCode)].canQueue = false
            end
        end
    end

    local dungeonIndex = 0
    for dungeon, data in LFG.fuckingSortAlready(LFG.dungeons) do
        --    for dungeon, data in next, LFG.dungeons do
        if LFG.level >= data.minLevel and LFG.level <= data.maxLevel and LFG_TYPE ~= 3 then

            dungeonIndex = dungeonIndex + 1

            if not LFG.availableDungeons[data.code] then
                LFG.availableDungeons[data.code] = CreateFrame("Frame", "Dungeon_" .. data.code, _G["DungeonListScrollFrameChildren"], "LFG_DungeonItemTemplate")
            end

            if LFG.shouldHideButtonTextures() then
	            -- Hide button textures for the newly created dungeon item
			    LFG.hideButtonTextures("Dungeon_" .. data.code .. "_Button")
			end

            LFG.availableDungeons[data.code]:Show()

            local color = COLOR_GREEN
            if LFG.level == data.minLevel or LFG.level == data.minLevel + 1 then
                color = COLOR_RED
            end
            if LFG.level == data.minLevel + 2 or LFG.level == data.minLevel + 3 then
                color = COLOR_ORANGE
            end
            if LFG.level == data.minLevel + 4 or LFG.level == data.maxLevel + 5 then
                color = COLOR_GREEN
            end

            if LFG.level > data.maxLevel then
                color = COLOR_GREEN
            end

            _G['Dungeon_' .. data.code .. '_CheckButton']:Enable()

            if data.canQueue then
                LFG.removeOnEnterTooltip(_G['Dungeon_' .. data.code .. '_Button'])
            else
                color = COLOR_DISABLED
                data.queued = false
                LFG.addOnEnterTooltip(_G['Dungeon_' .. data.code .. '_Button'], dungeon .. ' is unavailable',
                        'A member of your group does not meet', 'the suggested minimum level requirement (' .. data.minLevel .. ').')
                _G['Dungeon_' .. data.code .. '_CheckButton']:Disable()
            end

            _G['Dungeon_' .. data.code .. 'Text']:SetText(color .. dungeon)

            _G['Dungeon_' .. data.code .. 'Levels']:SetText(color .. '(' .. data.minLevel .. ' - ' .. data.maxLevel .. ')')

            _G['Dungeon_' .. data.code .. '_Button']:SetID(dungeonIndex)

            LFG.availableDungeons[data.code]:SetPoint("TOPLEFT", _G["DungeonListScrollFrameChildren"], "TOPLEFT", 5, 20 - 20 * (dungeonIndex))
            LFG.availableDungeons[data.code].code = data.code
            LFG.availableDungeons[data.code].background = data.background
            LFG.availableDungeons[data.code].minLevel = data.minLevel
            LFG.availableDungeons[data.code].maxLevel = data.maxLevel

            LFG.dungeons[dungeon].queued = data.queued
            _G['Dungeon_' .. data.code .. '_CheckButton']:SetChecked(data.queued)

        end

        if LFG.level >= data.minLevel and LFG_TYPE == 3 then
            --all available

            dungeonIndex = dungeonIndex + 1

            if not LFG.availableDungeons[data.code] then
                LFG.availableDungeons[data.code] = CreateFrame("Frame", "Dungeon_" .. data.code, _G["DungeonListScrollFrameChildren"], "LFG_DungeonItemTemplate")
            end

            LFG.availableDungeons[data.code]:Show()

            local color = COLOR_GREEN
            if LFG.level == data.minLevel or LFG.level == data.minLevel + 1 then
                color = COLOR_RED
            end
            if LFG.level == data.minLevel + 2 or LFG.level == data.minLevel + 3 then
                color = COLOR_ORANGE
            end
            if LFG.level == data.minLevel + 4 or LFG.level == data.maxLevel + 5 then
                color = COLOR_GREEN
            end

            if LFG.level > data.maxLevel then
                color = COLOR_GREEN
            end

            _G['Dungeon_' .. data.code .. '_CheckButton']:Enable()

            if data.canQueue then
                LFG.removeOnEnterTooltip(_G['Dungeon_' .. data.code .. '_Button'])
            else
                color = COLOR_DISABLED
                data.queued = false
                LFG.addOnEnterTooltip(_G['Dungeon_' .. data.code .. '_Button'], dungeon .. ' is unavailable',
                        'A member of your group does not meet', 'the suggested minimum level requirement (' .. data.minLevel .. ').')
                _G['Dungeon_' .. data.code .. '_CheckButton']:Disable()
            end

            _G['Dungeon_' .. data.code .. 'Text']:SetText(color .. dungeon)
            _G['Dungeon_' .. data.code .. 'Levels']:SetText(color .. '(' .. data.minLevel .. ' - ' .. data.maxLevel .. ')')
            _G['Dungeon_' .. data.code .. '_Button']:SetID(dungeonIndex)

            LFG.availableDungeons[data.code]:SetPoint("TOPLEFT", _G["DungeonListScrollFrameChildren"], "TOPLEFT", 5, 20 - 20 * (dungeonIndex))
            LFG.availableDungeons[data.code].code = data.code
            LFG.availableDungeons[data.code].background = data.background
            LFG.availableDungeons[data.code].minLevel = data.minLevel
            LFG.availableDungeons[data.code].maxLevel = data.maxLevel

        end

        if LFG.findingGroup then
            if _G['Dungeon_' .. data.code .. '_CheckButton'] then
                _G['Dungeon_' .. data.code .. '_CheckButton']:Disable()
            end
        end

        if LFG.findingMore then
            if _G['Dungeon_' .. data.code .. '_CheckButton'] then
                _G['Dungeon_' .. data.code .. '_CheckButton']:Disable()
                _G['Dungeon_' .. data.code .. '_CheckButton']:SetChecked(false)
            end
            if data.code == LFG.LFMDungeonCode then
                if _G['Dungeon_' .. data.code .. '_CheckButton'] then
                    _G['Dungeon_' .. data.code .. '_CheckButton']:SetChecked(true)
                end
                LFG.dungeons[dungeon].queued = true
            end
        end
        if _G['Dungeon_' .. data.code .. '_CheckButton'] then
            if _G['Dungeon_' .. data.code .. '_CheckButton']:GetChecked() then
                LFG.dungeons[dungeon].queued = true
            end
        end
    end

    -- gray out the rest if there are 5 already checked
    local queues = 0
    for _, d in next, LFG.dungeons do
        if d.queued then
            queues = queues + 1
        end
    end
    if queues >= LFG.maxDungeonsInQueue then

        for _, frame in next, LFG.availableDungeons do
            local dungeonName = LFG.dungeonNameFromCode(frame.code)
            if not LFG.dungeons[dungeonName].queued then
                _G["Dungeon_" .. frame.code .. '_CheckButton']:Disable()
                _G['Dungeon_' .. frame.code .. 'Text']:SetText(COLOR_DISABLED .. dungeonName)
                _G['Dungeon_' .. frame.code .. 'Levels']:SetText(COLOR_DISABLED .. '(' .. frame.minLevel .. ' - ' .. frame.maxLevel .. ')')

                local q = 'dungeons'
                LFG.addOnEnterTooltip(_G['Dungeon_' .. frame.code .. '_Button'], 'Queueing for ' .. dungeonName .. ' is unavailable', 'Maximum allowed queued ' .. q .. ' at a time is ' .. LFG.maxDungeonsInQueue .. '.')
            end
        end
    end
    -- end gray

    LFG.fixMainButton()

    if queueAfter then
        LFGFillAvailableDungeonsDelay.queueAfterIfPossible = false

        --find checked dungeon
        local qDungeon = ''
        local dungeonName = ''
        for _, frame in next, LFG.availableDungeons do
            if _G["Dungeon_" .. frame.code .. '_CheckButton']:GetChecked() then
                qDungeon = frame.code
            end
        end
        if qDungeon == '' then
            return false --do nothing
        end

        dungeonName = LFG.dungeonNameFromCode(qDungeon)

        if LFG.dungeons[dungeonName].canQueue then
            findMore()
        else
            lfprint('A member of your group does not meet the suggested minimum level requirement for |cff69ccf0' .. dungeonName)
        end
    end

    if dont_scroll then
        return
    end
    _G['DungeonListScrollFrame']:SetVerticalScroll(0)
    _G['DungeonListScrollFrame']:UpdateScrollChildRect()

    if LFG.shouldHideButtonTextures() then
	    for code, frame in next, LFG.availableDungeons do
	        if frame then
	            LFG.hideButtonTextures("Dungeon_" .. code .. "_Button")
	        end
	    end

	    LFG.hideButtonTextures("LFGBrowseButton")
	    LFG.hideButtonTextures("LFGDungeonsButton")
	end
end

function LFG.enableDungeonCheckButtons()
    for _, frame in next, LFG.availableDungeons do
        _G["Dungeon_" .. frame.code .. '_CheckButton']:Enable()
    end
    DungeonListFrame_Update()
end

function LFG.disableDungeonCheckButtons(except)
    for _, frame in next, LFG.availableDungeons do
        if except and except == frame.code then
            --dont disable
        else
            _G["Dungeon_" .. frame.code .. '_CheckButton']:Disable()
        end
    end
end

function LFG.resetGroup()
    LFG.group = {};
    if not LFG.oneGroupFull then
        LFG.groupFullCode = ''
    end
    LFG.acceptNextInvite = false
    LFG.onlyAcceptFrom = ''
    LFG.foundGroup = false

    LFG.currentGroupRoles = {}

    LFG.isLeader = IsPartyLeader()
    LFG.inGroup = GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0

    LFGGroupReadyFrameCloser.response = ''

    for dungeon, data in next, LFG.dungeons do

        LFG.dungeons[dungeon].myRole = ''

        if data.queued then
            local tank = ''
            if string.find(LFG_ROLE, 'tank', 1, true) then
                tank = me
            end
            LFG.group[data.code] = {
                tank = tank,
                healer = '',
                damage1 = '',
                damage2 = '',
                damage3 = '',
            }
        end
    end
    LFG.myRandomTime = math.random(LFG.random_min, LFG.random_max)
    LFG.LFMGroup = {
        tank = '',
        healer = '',
        damage1 = '',
        damage2 = '',
        damage3 = '',
    }
end

function LFG.addTank(dungeon, name, faux, add)
    -- Prevent adding same person twice, for both elite and regular dungeons
    if LFG.group[dungeon].tank == name or
            LFG.group[dungeon].healer == name or
            LFG.group[dungeon].damage1 == name or
            LFG.group[dungeon].damage2 == name or
            LFG.group[dungeon].damage3 == name then
        return false
    end

    if LFG.isEliteEncounter(dungeon) then
        -- For Elite Encounters, allow any role to fill any slot
        if LFG.group[dungeon].tank == '' then
            if add then LFG.group[dungeon].tank = name end
            if not faux then
                --SendChatMessage('found:tank:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        elseif LFG.group[dungeon].healer == '' then
            if add then LFG.group[dungeon].healer = name end
            if not faux then
                --SendChatMessage('found:tank:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        elseif LFG.group[dungeon].damage1 == '' then
            if add then LFG.group[dungeon].damage1 = name end
            if not faux then
                --SendChatMessage('found:tank:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        elseif LFG.group[dungeon].damage2 == '' then
            if add then LFG.group[dungeon].damage2 = name end
            if not faux then
                --SendChatMessage('found:tank:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        elseif LFG.group[dungeon].damage3 == '' then
            if add then LFG.group[dungeon].damage3 = name end
            if not faux then
                --SendChatMessage('found:tank:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        end
        return false -- Group is full
    else
        -- Regular dungeons: strict tank role validation
        if LFG.group[dungeon].tank == '' then
            if add then
                LFG.group[dungeon].tank = name
            end
            if not faux then
                --SendChatMessage('found:tank:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        end
        return false
    end
end

function LFG.addHealer(dungeon, name, faux, add)
    -- Prevent adding same person twice, for both elite and regular dungeons
    if LFG.group[dungeon].healer == name or
            LFG.group[dungeon].damage1 == name or
            LFG.group[dungeon].damage2 == name or
            LFG.group[dungeon].damage3 == name or
            LFG.group[dungeon].tank == name then
        return false
    end

    if LFG.isEliteEncounter(dungeon) then
        -- For Elite Encounters, allow any role to fill any slot
        if LFG.group[dungeon].tank == '' then
            if add then LFG.group[dungeon].tank = name end
            if not faux then
                --SendChatMessage('found:healer:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        elseif LFG.group[dungeon].healer == '' then
            if add then LFG.group[dungeon].healer = name end
            if not faux then
                --SendChatMessage('found:healer:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        elseif LFG.group[dungeon].damage1 == '' then
            if add then LFG.group[dungeon].damage1 = name end
            if not faux then
                --SendChatMessage('found:healer:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        elseif LFG.group[dungeon].damage2 == '' then
            if add then LFG.group[dungeon].damage2 = name end
            if not faux then
                --SendChatMessage('found:healer:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        elseif LFG.group[dungeon].damage3 == '' then
            if add then LFG.group[dungeon].damage3 = name end
            if not faux then
                --SendChatMessage('found:healer:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        end
        return false -- Group is full
    else
        -- Regular dungeons: strict healer role validation
        if LFG.group[dungeon].healer == '' then
            if add then
                LFG.group[dungeon].healer = name
            end
            if not faux then
                --SendChatMessage('found:healer:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        end
        return false
    end
end

function LFG.remHealerOrDamage(dungeon, name)
    if LFG.isEliteEncounter(dungeon) then
        -- For Elite Encounters, check all slots since any role can be in any slot
        if LFG.group[dungeon].tank == name then
            LFG.group[dungeon].tank = ''
        end
    end

    if LFG.group[dungeon].healer == name then
        LFG.group[dungeon].healer = ''
    end
    if LFG.group[dungeon].damage1 == name then
        LFG.group[dungeon].damage1 = ''
    end
    if LFG.group[dungeon].damage2 == name then
        LFG.group[dungeon].damage2 = ''
    end
    if LFG.group[dungeon].damage3 == name then
        LFG.group[dungeon].damage3 = ''
    end
end

function LFG.addDamage(dungeon, name, faux, add)
    if not LFG.group[dungeon] then
        LFG.group[dungeon] = {
            tank = '',
            healer = '',
            damage1 = '',
            damage2 = '',
            damage3 = ''
        }
    end

    -- Prevent adding same person twice, for both elite and regular dungeons
    if LFG.group[dungeon].tank == name or
            LFG.group[dungeon].healer == name or
            LFG.group[dungeon].damage1 == name or
            LFG.group[dungeon].damage2 == name or
            LFG.group[dungeon].damage3 == name then
        return false
    end

    if LFG.isEliteEncounter(dungeon) then
        -- For Elite Encounters, allow any role to fill any slot
        if LFG.group[dungeon].tank == '' then
            if add then LFG.group[dungeon].tank = name end
            if not faux then
                --SendChatMessage('found:damage:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        elseif LFG.group[dungeon].healer == '' then
            if add then LFG.group[dungeon].healer = name end
            if not faux then
                --SendChatMessage('found:damage:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        elseif LFG.group[dungeon].damage1 == '' then
            if add then LFG.group[dungeon].damage1 = name end
            if not faux then
                --SendChatMessage('found:damage:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        elseif LFG.group[dungeon].damage2 == '' then
            if add then LFG.group[dungeon].damage2 = name end
            if not faux then
                --SendChatMessage('found:damage:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        elseif LFG.group[dungeon].damage3 == '' then
            if add then LFG.group[dungeon].damage3 = name end
            if not faux then
                --SendChatMessage('found:damage:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        end
        return false -- Group is full
    else
        -- Regular dungeons: strict damage role validation (up to 3 damage slots)
        if LFG.group[dungeon].damage1 == '' then
            if add then LFG.group[dungeon].damage1 = name end
            if not faux then
                --SendChatMessage('found:damage:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        elseif LFG.group[dungeon].damage2 == '' then
            if add then LFG.group[dungeon].damage2 = name end
            if not faux then
                --SendChatMessage('found:damage:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        elseif LFG.group[dungeon].damage3 == '' then
            if add then LFG.group[dungeon].damage3 = name end
            if not faux then
                --SendChatMessage('found:damage:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
            end
            return true
        end
        return false -- Group full on damage
    end
end

function LFG.checkGroupFull()

    for _, data in next, LFG.dungeons do
        if data.queued then
            local members = 0
            if LFG.group[data.code].tank ~= '' then
                members = members + 1
            end
            if LFG.group[data.code].healer ~= '' then
                members = members + 1
            end
            if LFG.group[data.code].damage1 ~= '' then
                members = members + 1
            end
            if LFG.group[data.code].damage2 ~= '' then
                members = members + 1
            end
            if LFG.group[data.code].damage3 ~= '' then
                members = members + 1
            end
            lfdebug('members = ' .. members .. ' (' .. LFG.group[data.code].tank ..
                    ',' .. LFG.group[data.code].healer .. ',' .. LFG.group[data.code].damage1 ..
                    ',' .. LFG.group[data.code].damage2 .. ',' .. LFG.group[data.code].damage3 .. ')')
            if members == LFG.groupSizeMax then
                LFG.oneGroupFull = true
                LFG.group[data.code].full = true

                return true, data.code, LFG.group[data.code].healer, LFG.group[data.code].damage1, LFG.group[data.code].damage2, LFG.group[data.code].damage3
            else
                LFG.group[data.code].full = false
                LFG.oneGroupFull = false
            end
        end
    end

    return false, false, nil, nil, nil, nil
end

function LFG.showMyRoleIcon(myRole)
    if _G['PlayerPortrait']:IsVisible() then
        _G['LFGPartyRoleIconsPlayer']:SetTexture('Interface\\addons\\LFG\\images\\' .. myRole .. '_small')
        _G['LFGPartyRoleIconsPlayer']:Show()
    else
        _G['LFGPartyRoleIconsPlayer']:Hide()
    end
end

function LFG.showPartyRoleIcons(role, name)
    if not role and not name then
        for i = 1, 4 do
            if _G['PartyMemberFrame' .. i .. 'Portrait']:IsVisible() then
                if LFG.currentGroupRoles[UnitName('party' .. i)] then
                    _G['LFGPartyRoleIconsParty' .. i]:SetTexture('Interface\\addons\\LFG\\images\\' .. LFG.currentGroupRoles[UnitName('party' .. i)] .. '_small')
                    _G['LFGPartyRoleIconsParty' .. i]:Show()
                end
            else
                _G['LFGPartyRoleIconsParty' .. i]:Hide()
            end
        end
        return true
    end
    LFG.currentGroupRoles[name] = role
    for i = 1, GetNumPartyMembers() do
        if UnitName('party' .. i) == name then
            if _G['PartyMemberFrame' .. i .. 'Portrait']:IsVisible() then
                _G['LFGPartyRoleIconsParty' .. i]:SetTexture('Interface\\addons\\LFG\\images\\' .. role .. '_small')
                _G['LFGPartyRoleIconsParty' .. i]:Show()
            else
                _G['LFGPartyRoleIconsParty' .. i]:Hide()
            end
        end
    end
end

function LFG.hideMyRoleIcon()
    _G['LFGPartyRoleIconsPlayer']:Hide()
end

function LFG.hidePartyRoleIcons()
    LFG.hideMyRoleIcon()
    _G['LFGPartyRoleIconsParty1']:Hide()
    _G['LFGPartyRoleIconsParty2']:Hide()
    _G['LFGPartyRoleIconsParty3']:Hide()
    _G['LFGPartyRoleIconsParty4']:Hide()
end

function LFG.dungeonNameFromCode(code)
    for name, data in next, LFG.dungeons do
        if data.code == code then
            return name, data.background
        end
    end

    for name, data in next, LFG.allDungeons do
        if data.code == code then
            return name, data.background
        end
    end

    for name, data in next, LFG.eliteEncounters do
        if data.code == code then
            return name, data.background
        end
    end

    return 'Unknown', 'UnknownBackground'
end

function LFG.dungeonFromCode(code)
    for _, data in next, LFG.dungeons do
        if data.code == code then
            return data
        end
    end
    return false
end

function LFG.AcceptGroupInvite()
    AcceptGroup()
    StaticPopup_Hide("PARTY_INVITE")
    PlaySoundFile("Sound\\Doodad\\BellTollNightElf.wav")
    UIErrorsFrame:AddMessage("[LFG] Group Auto Accept")
end

function LFG.DeclineGroupInvite()
    DeclineGroup()
    StaticPopup_Hide("PARTY_INVITE")
end

function LFG.fuckingSortAlready(t, reverse)
    local a = {}
    for n, l in pairs(t) do
        table.insert(a, { ['code'] = l.code, ['minLevel'] = l.minLevel, ['name'] = n })
    end
    if reverse then
        table.sort(a, function(a, b)
            return a['minLevel'] > b['minLevel']
        end)
    else
        table.sort(a, function(a, b)
            return a['minLevel'] < b['minLevel']
        end)
    end

    local i = 0 -- iterator variable
    local iter = function()
        -- iterator function
        i = i + 1
        if a[i] == nil then
            return nil
            --        else return a[i]['code'], t[a[i]['name']]
        else
            return a[i]['name'], t[a[i]['name']]
        end
    end
    return iter
end

function LFG.tableSize(t)
    local size = 0
    for _, _ in next, t do
        size = size + 1
    end
    return size
end

function LFG.checkLFMgroup(someoneDeclined)

    if someoneDeclined then
        if someoneDeclined ~= me then
            lfprint(LFG.classColors[LFG.playerClass(someoneDeclined)].c .. someoneDeclined .. COLOR_WHITE .. ' declined role check.')
            lfdebug('LFGRoleCheck:Hide() in checkLFMgroup someone declined')
            LFGRoleCheck:Hide()
        end
        return false
    end

    if not LFG.isLeader then
        return
    end

    local currentGroupSize = GetNumPartyMembers() + 1
    local readyNumber = 0
    if LFG.LFMGroup.tank ~= '' then
        readyNumber = readyNumber + 1
    end
    if LFG.LFMGroup.healer ~= '' then
        readyNumber = readyNumber + 1
    end
    if LFG.LFMGroup.damage1 ~= '' then
        readyNumber = readyNumber + 1
    end
    if LFG.LFMGroup.damage2 ~= '' then
        readyNumber = readyNumber + 1
    end
    if LFG.LFMGroup.damage3 ~= '' then
        readyNumber = readyNumber + 1
    end

    if currentGroupSize == readyNumber then
        LFG.findingMore = true
        lfdebug('group ready ? ' .. currentGroupSize .. ' = ' .. readyNumber)
        lfdebug(LFG.LFMGroup.tank)
        lfdebug(LFG.LFMGroup.healer)
        lfdebug(LFG.LFMGroup.damage1)
        lfdebug(LFG.LFMGroup.damage2)
        lfdebug(LFG.LFMGroup.damage3)
        --everyone is ready / confirmed roles

        LFG.group[LFG.LFMDungeonCode] = {
            tank = LFG.LFMGroup.tank,
            healer = LFG.LFMGroup.healer,
            damage1 = LFG.LFMGroup.damage1,
            damage2 = LFG.LFMGroup.damage2,
            damage3 = LFG.LFMGroup.damage3,
        }
        SendAddonMessage(LFG_ADDON_CHANNEL, "weInQueue:" .. LFG.LFMDungeonCode, "PARTY")
        lfdebug('LFGRoleCheck:Hide() in checkLFMGROUP we ready')
        LFGRoleCheck:Hide()
    end
end

function LFG.weInQueue(code)

    local dungeonName = LFG.dungeonNameFromCode(code)
    LFG.dungeons[dungeonName].queued = true

    lfprint('Your group is in the queue for |cff69ccf0' .. dungeonName)

    LFG.findingGroup = true
    LFG.findingMore = true
    LFG.disableDungeonCheckButtons()

    _G['RoleTank']:Disable()
    _G['RoleHealer']:Disable()
    _G['RoleDamage']:Disable()

    PlaySound('PvpEnterQueue')

    if LFG.isLeader then
        LFG.sendMinimapDataToParty(code)
    else
        LFG.group[code] = {
            tank = '',
            healer = '',
            damage1 = '',
            damage2 = '',
            damage3 = ''
        }
    end

    LFG.oneGroupFull = false
    LFG.queueStartTime = time()
    LFGQueue:Show()
    LFGMinimapAnimation:Show()
    _G['LFGlfg']:Hide()
    LFG.fixMainButton()
end

function LFG.fixMainButton()

    local lfgButton = _G['findGroupButton']
    local lfmButton = _G['findMoreButton']
    local leaveQueueButton = _G['leaveQueueButton']

    lfgButton:Hide()
    lfmButton:Hide()
    leaveQueueButton:Hide()

    lfgButton:Disable()
    lfmButton:Disable()
    leaveQueueButton:Disable()

    LFG.inGroup = GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0

    local queues = 0
    for _, data in next, LFG.dungeons do
        if data.queued then
            queues = queues + 1
        end
    end

    if queues > 0 then
        lfgButton:Enable()
    end

    if LFG.inGroup then
        lfmButton:Show()
        --GetNumPartyMembers() returns party size-1, doesnt count myself
        if GetNumPartyMembers() < (LFG.groupSizeMax - 1) and LFG.isLeader and queues > 0 then
            lfmButton:Enable()
            if LFG.LFMDungeonCode ~= '' then
                LFG.disableDungeonCheckButtons(LFG.LFMDungeonCode)
            end
        end
        if GetNumPartyMembers() == (LFG.groupSizeMax - 1) and LFG.isLeader then
            --group full
            lfmButton:Disable()
            LFG.disableDungeonCheckButtons()
        end
        if not LFG.isLeader then
            lfmButton:Disable()
            LFG.disableDungeonCheckButtons()
        end
    else
        lfgButton:Show()
    end

    if LFG.findingGroup then
        leaveQueueButton:Show()
        leaveQueueButton:Enable()
        if LFG.inGroup then
            if not LFG.isLeader then
                leaveQueueButton:Disable()
            end
        end
        lfgButton:Hide()
        lfmButton:Hide()
    end

    if GetNumRaidMembers() > 0 then
        lfgButton:Disable()
        lfmButton:Disable()
        leaveQueueButton:Disable()
    end

    -- todo replace this with LFG_ROLE == ''
    local tankCheck = _G['RoleTank']
    local healerCheck = _G['RoleHealer']
    local damageCheck = _G['RoleDamage']
    local newRole = ''
    if tankCheck:GetChecked() then
        newRole = newRole .. 'tank'
    end
    if healerCheck:GetChecked() then
        newRole = newRole .. 'healer'
    end
    if damageCheck:GetChecked() then
        newRole = newRole .. 'damage'
    end

    if newRole == '' then
        lfgButton:Disable()
        lfmButton:Disable()
    end
end

function LFG.sendCancelMeMessage()
    if string.find(LFG_ROLE, 'tank', 1, true) then
        SendChatMessage('leftQueue:tank', "CHANNEL",DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))

    end
    if string.find(LFG_ROLE, 'healer', 1, true) then
        SendChatMessage('leftQueue:healer', "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))

    end
    if string.find(LFG_ROLE, 'damage', 1, true) then
        SendChatMessage('leftQueue:damage', "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))

    end
end

function LFG.sendLFGMessage(role)

    local lfg_text = ''
    for code, _ in pairs(LFG.group) do
        if LFG.supress[code] == role then
            LFG.supress[code] = ''
        else
            lfg_text = 'LFG:' .. code .. ':' .. role .. ' ' .. lfg_text
        end
    end
    lfg_text = string.sub(lfg_text, 1, string.len(lfg_text) - 1)

    SendChatMessage(lfg_text, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
end

function LFG.sendLFMStats(code)

    if code == '' then
        lfdebug('cant send lfm stats, code = blank')
        return false
    end
    if not LFG.group[code] then
        return false
    end
    local tank, healer, damage = 0, 0, 0
    if LFG.group[code].tank ~= '' then
        tank = tank + 1
    end
    if LFG.group[code].healer ~= '' then
        healer = healer + 1
    end
    if LFG.group[code].damage1 ~= '' then
        damage = damage + 1
    end
    if LFG.group[code].damage2 ~= '' then
        damage = damage + 1
    end
    if LFG.group[code].damage3 ~= '' then
        damage = damage + 1
    end

    SendChatMessage("LFM:" .. code .. ":" .. tank .. ":" .. healer .. ":" .. damage, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
end

function LFG.isNeededInLFMGroup(role, name, code)

    if role == 'tank' and LFG.group[code].tank == '' then
        --        LFG.group[code].tank = name
        return true
    end
    if role == 'healer' and LFG.group[code].healer == '' then
        --        LFG.group[code].healer = name
        return true
    end
    if role == 'damage' then
        if LFG.group[code].damage1 == '' then
            --            LFG.group[code].damage1 = name
            return true
        end
        if LFG.group[code].damage2 == '' then
            --            LFG.group[code].damage2 = name
            return true
        end
        if LFG.group[code].damage3 == '' then
            --            LFG.group[code].damage3 = name
            return true
        end
    end
    return false
end

function LFG.inviteInLFMGroup(name)
    SendChatMessage("[LFG]:" .. LFG.LFMDungeonCode .. ":(LFM):" .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
    InviteUnit(name)
end

function LFG.checkLFMGroupReady(code)
    if not LFG.isLeader then
        return
    end

    local members = 0

    if LFG.group[code].tank ~= '' then
        members = members + 1
    end
    if LFG.group[code].healer ~= '' then
        members = members + 1
    end
    if LFG.group[code].damage1 ~= '' then
        members = members + 1
    end
    if LFG.group[code].damage2 ~= '' then
        members = members + 1
    end
    if LFG.group[code].damage3 ~= '' then
        members = members + 1
    end

    return members == LFG.groupSizeMax
end

function LFG.sendMinimapDataToParty(code)
    lfdebug('send minimap data to party code = ' .. code)
    if code == '' then
        return false
    end
    if not LFG.group[code] then
        return false
    end
    local tank, healer, damage = 0, 0, 0
    if LFG.group[code].tank ~= '' then
        tank = tank + 1
    end
    if LFG.group[code].healer ~= '' then
        healer = healer + 1
    end
    if LFG.group[code].damage1 ~= '' then
        damage = damage + 1
    end
    if LFG.group[code].damage2 ~= '' then
        damage = damage + 1
    end
    if LFG.group[code].damage3 ~= '' then
        damage = damage + 1
    end
    SendAddonMessage(LFG_ADDON_CHANNEL, "minimap:" .. code .. ":" .. tank .. ":" .. healer .. ":" .. damage, "PARTY")
end

function LFG.addOnEnterTooltip(frame, title, text1, text2, x, y)
    frame:SetScript("OnEnter", function()
        if x and y then
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT", x, y)
        else
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT", -200, -5)
        end
        GameTooltip:AddLine(title)
        if text1 then
            GameTooltip:AddLine(text1, 1, 1, 1)
        end
        if text2 then
            GameTooltip:AddLine(text2, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function LFG.removeOnEnterTooltip(frame)
    frame:SetScript("OnEnter", function()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function LFG.sendMyVersion()
    SendAddonMessage(LFG_ADDON_CHANNEL, "LFGVersion:" .. addonVer, "PARTY")
    SendAddonMessage(LFG_ADDON_CHANNEL, "LFGVersion:" .. addonVer, "GUILD")
    SendAddonMessage(LFG_ADDON_CHANNEL, "LFGVersion:" .. addonVer, "RAID")
    SendAddonMessage(LFG_ADDON_CHANNEL, "LFGVersion:" .. addonVer, "BATTLEGROUND")
end

function LFG.removePlayerFromVirtualParty(name, mRole)
    if not mRole then
        mRole = 'unknown'
    end
    for dungeonCode, data in next, LFG.group do
        if data.tank == name and (mRole == 'tank' or mRole == 'unknown') then
            LFG.group[dungeonCode].tank = ''
        end
        if data.healer == name and (mRole == 'healer' or mRole == 'unknown') then
            LFG.group[dungeonCode].healer = ''
        end
        if data.damage1 == name and (mRole == 'damage' or mRole == 'unknown') then
            LFG.group[dungeonCode].damage1 = ''
        end
        if data.damage2 == name and (mRole == 'damage' or mRole == 'unknown') then
            LFG.group[dungeonCode].damage2 = ''
        end
        if data.damage3 == name and (mRole == 'damage' or mRole == 'unknown') then
            LFG.group[dungeonCode].damage3 = ''
        end
    end
end

function LFG.deQueueAll()
    for _, data in next, LFG.dungeons do
        if data.queued then
            LFG.dungeons[data.code].queued = false
        end
    end
end

function LFG.resetFormedGroups()
    LFG_FORMED_GROUPS = {}
    for _, data in next, LFG.dungeons do
        LFG_FORMED_GROUPS[data.code] = 0
    end
end

function LFG.readyStatusReset()
    _G['LFGReadyStatusReadyTank']:SetTexture('Interface\\addons\\LFG\\images\\readycheck-waiting')
    _G['LFGReadyStatusReadyHealer']:SetTexture('Interface\\addons\\LFG\\images\\readycheck-waiting')
    _G['LFGReadyStatusReadyDamage1']:SetTexture('Interface\\addons\\LFG\\images\\readycheck-waiting')
    _G['LFGReadyStatusReadyDamage2']:SetTexture('Interface\\addons\\LFG\\images\\readycheck-waiting')
    _G['LFGReadyStatusReadyDamage3']:SetTexture('Interface\\addons\\LFG\\images\\readycheck-waiting')
end

function test_dung_ob(code)
    LFG.showDungeonObjectives(code)
end

function LFG.showDungeonObjectives(code, numObjectivesComplete)

    local dungeonName = LFG.dungeonNameFromCode(LFG.groupFullCode)
    if numObjectivesComplete then
        lfdebug('showdungeons obj call with numObjectivesComplete = ' .. numObjectivesComplete)
        LFGObjectives.objectivesComplete = numObjectivesComplete
    else
        lfdebug('showdungeons obj call without numObjectivesComplete')
        LFGObjectives.objectivesComplete = 0
    end

    lfdebug('LFGObjectives.objectivesComplete = ' .. LFGObjectives.objectivesComplete)

    --hideall
    for index, _ in next, LFG.objectivesFrames do
        if _G["LFGObjective" .. index] then
            _G["LFGObjective" .. index]:Hide()
        end
    end

    if LFG.dungeons[dungeonName] then
        if LFG.bosses[LFG.groupFullCode] then
            _G['LFGDungeonStatusDungeonName']:SetText(dungeonName)

            local index = 0
            for _, boss in next, LFG.bosses[LFG.groupFullCode] do
                index = index + 1
                if not LFG.objectivesFrames[index] then
                    LFG.objectivesFrames[index] = CreateFrame("Frame", "LFGObjective" .. index, _G['LFGDungeonStatus'], "LFGObjectiveBossTemplate")
                end
                LFG.objectivesFrames[index]:Show()
                LFG.objectivesFrames[index].name = boss
                LFG.objectivesFrames[index].code = LFG.groupFullCode

                if LFG.objectivesFrames[index].completed == nil then
                    LFG.objectivesFrames[index].completed = false
                end

                _G["LFGObjective" .. index .. 'Swoosh']:SetAlpha(0)
                _G["LFGObjective" .. index .. 'ObjectiveComplete']:Hide()
                _G["LFGObjective" .. index .. 'ObjectivePending']:Show()

                if LFG.objectivesFrames[index].completed then
                    _G["LFGObjective" .. index .. 'ObjectiveComplete']:Show()
                    _G["LFGObjective" .. index .. 'ObjectivePending']:Hide()
                else
                    -- _G["LFGObjective" .. index .. 'Objective']:SetText(COLOR_DISABLED .. '0/1 ' .. boss .. ' defeated')
                    _G["LFGObjective" .. index .. 'Objective']:SetText(COLOR_DISABLED .. '' .. boss .. '')
                end

                LFG.objectivesFrames[index]:SetPoint("TOPLEFT", _G["LFGDungeonStatus"], "TOPLEFT", 10, -110 - 20 * (index))
            end

            _G["LFGDungeonStatusCollapseButton"]:Show()
            _G["LFGDungeonStatusExpandButton"]:Hide()
            _G["LFGDungeonStatus"]:Show()
        else
            _G["LFGDungeonStatus"]:Hide()
        end
    else
        _G["LFGDungeonStatus"]:Hide()
    end
end

function LFG.getDungeonCompletion()
    local completed = 0
    local total = 0
    for index, _ in next, LFG.objectivesFrames do
        if LFG.objectivesFrames[index].completed then
            completed = completed + 1
        end
        total = total + 1
    end
    if completed == 0 then
        return 0, 0
    end
    return math.floor((completed * 100) / total), completed
end

LFG.browseNames = {}

function LFG.LFGBrowse_Update()
    lfdebug('LFGBrowse_Update time is ' .. LFGTime.second)

    --hide all
    for _, frame in next, LFG.browseFrames do
        _G["BrowseFrame_" .. frame.code]:Hide()
    end

    local dungeonIndex = 0

    -- Fix: Use a regular for loop instead of relying on fuckingSortAlready
    local sortedDungeons = {}
    for dungeon, data in next, LFG.dungeons do
        table.insert(sortedDungeons, {name = dungeon, data = data})
    end

    -- Sort dungeons by minLevel in descending order
    table.sort(sortedDungeons, function(a, b)
        return a.data.minLevel > b.data.minLevel
    end)

    -- Now iterate through the sorted table
    for _, dungeonData in ipairs(sortedDungeons) do
        local dungeon = dungeonData.name
        local data = dungeonData.data

        if LFG.dungeonsSpam[data.code] and LFG.level >= data.minLevel then

            if LFG.dungeonsSpamDisplay[data.code].tank > 0 or LFG.dungeonsSpamDisplay[data.code].healer > 0 or LFG.dungeonsSpamDisplay[data.code].damage > 0 then

                dungeonIndex = dungeonIndex + 1

                if not LFG.browseFrames[data.code] then
                    LFG.browseFrames[data.code] = CreateFrame("Frame", "BrowseFrame_" .. data.code, _G["BrowseScrollFrameChildren"], "LFGBrowseDungeonTemplate")
                end

                _G['BrowseFrame_' .. data.code .. 'Background']:SetTexture('Interface\\addons\\LFG\\images\\background\\ui-lfg-background-' .. data.background)
                _G['BrowseFrame_' .. data.code .. 'Background']:SetAlpha(0.7)

                LFG.browseFrames[data.code]:Show()

                local color = COLOR_GREEN
                if LFG.level == data.minLevel or LFG.level == data.minLevel + 1 then
                    color = COLOR_RED
                end
                if LFG.level == data.minLevel + 2 or LFG.level == data.minLevel + 3 then
                    color = COLOR_ORANGE
                end
                if LFG.level == data.minLevel + 4 or LFG.level == data.maxLevel + 5 then
                    color = COLOR_GREEN
                end

                if LFG.level > data.maxLevel then
                    color = COLOR_GREEN
                end

                _G["BrowseFrame_" .. data.code .. "DungeonName"]:SetText(color .. dungeon)
                _G["BrowseFrame_" .. data.code .. "IconLeader"]:Hide()

                if LFG.dungeonsSpamDisplayLFM[data.code] > 0 then
                    _G["BrowseFrame_" .. data.code .. "DungeonName"]:SetText(color .. dungeon .. " (" .. LFG.dungeonsSpamDisplayLFM[data.code] .. "/5)")
                    _G["BrowseFrame_" .. data.code .. "IconLeader"]:Show()
                end

                local tank_color = ''
                local healer_color = ''
                local damage_color = ''

                _G["BrowseFrame_" .. data.code .. "TankButtonTexture"]:SetDesaturated(0)
                if LFG.dungeonsSpamDisplay[data.code].tank == 0 then
                    tank_color = COLOR_DISABLED2
                    _G["BrowseFrame_" .. data.code .. "TankButtonTexture"]:SetDesaturated(1)
                    LFG.removeOnEnterTooltip(_G["BrowseFrame_" .. data.code .. "TankButton"])
                else
                    if LFG.browseNames[data.code] and LFG.browseNames[data.code]['tank'] then
                        LFG.addOnEnterTooltip(_G["BrowseFrame_" .. data.code .. "TankButton"], COLOR_TANK .. "Tank\n" .. COLOR_WHITE .. LFG.browseNames[data.code]['tank'], nil, nil, 15, 0)
                    end
                end

                _G["BrowseFrame_" .. data.code .. "HealerButtonTexture"]:SetDesaturated(0)
                if LFG.dungeonsSpamDisplay[data.code].healer == 0 then
                    healer_color = COLOR_DISABLED2
                    _G["BrowseFrame_" .. data.code .. "HealerButtonTexture"]:SetDesaturated(1)
                    LFG.removeOnEnterTooltip(_G["BrowseFrame_" .. data.code .. "HealerButton"])
                else
                    if LFG.browseNames[data.code] and LFG.browseNames[data.code]['healer'] then
                        LFG.addOnEnterTooltip(_G["BrowseFrame_" .. data.code .. "HealerButton"], COLOR_HEALER .. "Healer\n" .. COLOR_WHITE .. LFG.browseNames[data.code]['healer'], nil, nil, 15, 0)
                    end
                end

                _G["BrowseFrame_" .. data.code .. "DamageButtonTexture"]:SetDesaturated(0)
                if LFG.dungeonsSpamDisplay[data.code].damage == 0 then
                    damage_color = COLOR_DISABLED2
                    _G["BrowseFrame_" .. data.code .. "DamageButtonTexture"]:SetDesaturated(1)
                    LFG.removeOnEnterTooltip(_G["BrowseFrame_" .. data.code .. "DamageButton"])
                else
                    if LFG.browseNames[data.code] and LFG.browseNames[data.code]['damage'] then
                        LFG.addOnEnterTooltip(_G["BrowseFrame_" .. data.code .. "DamageButton"], COLOR_DAMAGE .. "Damage\n" .. COLOR_WHITE .. LFG.browseNames[data.code]['damage'], nil, nil, 15, 0)
                    end
                end

                _G["BrowseFrame_" .. data.code .. "NrTank"]:SetText(tank_color .. LFG.dungeonsSpamDisplay[data.code].tank)
                _G["BrowseFrame_" .. data.code .. "NrHealer"]:SetText(healer_color .. LFG.dungeonsSpamDisplay[data.code].healer)
                _G["BrowseFrame_" .. data.code .. "NrDamage"]:SetText(damage_color .. LFG.dungeonsSpamDisplay[data.code].damage)

                _G["BrowseFrame_" .. data.code .. "_JoinAs"]:Hide()

                if data.queued and (LFG.findingMore or LFG.findingGroup) then
                    _G["BrowseFrame_" .. data.code .. "InQueue"]:Show()
                else
                    _G["BrowseFrame_" .. data.code .. "InQueue"]:Hide()

                    local queues = 0
                    for dungeon, data in next, LFG.dungeons do
                        if data.queued then
                            queues = queues + 1
                        end
                    end

                    if not LFG.inGroup and queues < 5 then

                        if LFG.dungeonsSpamDisplay[data.code].tank == 0 and string.find(LFG_ROLE, 'tank', 1, true) then
                            _G["BrowseFrame_" .. data.code .. "_JoinAs"]:SetID(1)
                            _G["BrowseFrame_" .. data.code .. "_JoinAs"]:SetText('Join as Tank')
                            _G["BrowseFrame_" .. data.code .. "_JoinAs"]:Show()
                        elseif LFG.dungeonsSpamDisplay[data.code].healer == 0 and string.find(LFG_ROLE, 'healer', 1, true) then
                            _G["BrowseFrame_" .. data.code .. "_JoinAs"]:SetID(2)
                            _G["BrowseFrame_" .. data.code .. "_JoinAs"]:SetText('Join as Healer')
                            _G["BrowseFrame_" .. data.code .. "_JoinAs"]:Show()
                        elseif LFG.dungeonsSpamDisplay[data.code].damage < 3 and string.find(LFG_ROLE, 'damage', 1, true) then
                            _G["BrowseFrame_" .. data.code .. "_JoinAs"]:SetID(3)
                            _G["BrowseFrame_" .. data.code .. "_JoinAs"]:SetText('Join as Damage')
                            _G["BrowseFrame_" .. data.code .. "_JoinAs"]:Show()
                        end
                    end
                end

                LFG.browseFrames[data.code]:SetPoint("TOPLEFT", _G["BrowseScrollFrameChildren"], "TOPLEFT", 0, 41 - 41 * (dungeonIndex))
                LFG.browseFrames[data.code].code = data.code
            end
        end
    end

    if dungeonIndex > 0 then
        _G['LFGBrowseNoPeople']:Hide()
        _G['LFGBrowseBrowseText']:SetText('Browse (' .. dungeonIndex .. ')')
        _G['LFGMainBrowseText']:SetText('Browse (' .. dungeonIndex .. ')')
    else
        _G['LFGBrowseNoPeople']:Show()
        _G['LFGBrowseBrowseText']:SetText('Browse')
        _G['LFGMainBrowseText']:SetText('Browse')
    end

    _G['BrowseDungeonListScrollFrame']:UpdateScrollChildRect()
end

-- XML called methods and public functions

function checkRoleCompatibility(role)
    if role == 'tank' and (LFG.class == 'priest' or LFG.class == 'mage' or LFG.class == 'warlock' or LFG.class == 'hunter' or LFG.class == 'rogue') then
        GameTooltip:AddLine(ROLE_BAD_TOOLTIP, 1, 0, 0);
    end
    if role == 'healer' and (LFG.class == 'warrior' or LFG.class == 'mage' or LFG.class == 'warlock' or LFG.class == 'hunter' or LFG.class == 'rogue') then
        GameTooltip:AddLine(ROLE_BAD_TOOLTIP, 1, 0, 0);
    end
end

function lfg_replace(s, c, cc)
    return (string.gsub(s, c, cc))
end

function acceptRole()

    local myRole = ''
    if _G['roleCheckTank']:GetChecked() then
        myRole = 'tank'
    end
    if _G['roleCheckHealer']:GetChecked() then
        myRole = 'healer'
    end
    if _G['roleCheckDamage']:GetChecked() then
        myRole = 'damage'
    end
    LFG.dungeons[LFG.dungeonNameFromCode(LFG.LFMDungeonCode)].myRole = myRole

    LFG.SetSingleRole(myRole)

    SendAddonMessage(LFG_ADDON_CHANNEL, "acceptRole:" .. myRole, "PARTY")
    LFG.showMyRoleIcon(myRole)
    --LFGRoleCheck:Hide()
    _G['LFGRoleCheck']:Hide()
end

function declineRole()
    local myRole = ''
    if _G['roleCheckTank']:GetChecked() then
        myRole = 'tank'
    end
    if _G['roleCheckHealer']:GetChecked() then
        myRole = 'healer'
    end
    if _G['roleCheckDamage']:GetChecked() then
        myRole = 'damage'
    end
    LFG.dungeons[LFG.dungeonNameFromCode(LFG.LFMDungeonCode)].myRole = myRole
    local myRole = LFG.dungeons[LFG.dungeonNameFromCode(LFG.LFMDungeonCode)].myRole
    SendAddonMessage(LFG_ADDON_CHANNEL, "declineRole:" .. myRole, "PARTY")

    --LFGRoleCheck:Hide()
    _G['LFGRoleCheck']:Hide()
end

function LFG_Toggle()

    -- remove channel from every chat frame
    LFG.removeChannelFromWindows()

    if LFG.level == 0 then
        LFG.level = UnitLevel('player')
    end

    for dungeon, data in next, LFG.dungeons do
        if not LFG.dungeonsSpam[data.code] then
            LFG.dungeonsSpam[data.code] = { tank = 0, healer = 0, damage = 0 }
        end
        if not LFG.dungeonsSpamDisplay[data.code] then
            LFG.dungeonsSpamDisplay[data.code] = { tank = 0, healer = 0, damage = 0 }
        end
        if not LFG.dungeonsSpamDisplayLFM[data.code] then
            LFG.dungeonsSpamDisplayLFM[data.code] = 0
        end
        if not LFG.supress[data.code] then
            LFG.supress[data.code] = ''
        end
    end

    if _G['LFGlfg']:IsVisible() then
        PlaySound("igCharacterInfoClose")
        _G['LFGlfg']:Hide()
    else
        PlaySound("igCharacterInfoOpen")
        _G['LFGlfg']:Show()

        if LFG.tab == 1 then

            LFG.checkLFGChannel()
            if not LFG.findingGroup then
                LFG.fillAvailableDungeons()
            end

            DungeonListFrame_Update()

        elseif LFG.tab == 2 then
            BrowseDungeonListFrame_Update()
        end
    end

end

function sayReady()
    if LFG.inGroup and GetNumPartyMembers() + 1 == LFG.groupSizeMax then
        _G['LFGGroupReady']:Hide()
        local myRole = LFG.dungeons[LFG.dungeonNameFromCode(LFG.groupFullCode)].myRole
        SendAddonMessage(LFG_ADDON_CHANNEL, "readyAs:" .. myRole, "PARTY")
        LFG.SetSingleRole(myRole)
        LFG.GetPossibleRoles()
        LFG.showMyRoleIcon(myRole)
        LFGMinimapAnimation:Hide()
        _G['LFGReadyStatus']:Show()
        LFGGroupReadyFrameCloser.response = 'ready'
        _G['LFGGroupReadyAwesome']:Disable()
    end
end

function sayNotReady()
    if LFG.inGroup and GetNumPartyMembers() + 1 == LFG.groupSizeMax then
        _G['LFGGroupReady']:Hide()
        local myRole = LFG.dungeons[LFG.dungeonNameFromCode(LFG.groupFullCode)].myRole
        SendAddonMessage(LFG_ADDON_CHANNEL, "notReadyAs:" .. myRole, "PARTY")
        LFG.SetSingleRole(myRole)
        LFG.GetPossibleRoles()
        LFGMinimapAnimation:Hide()
        _G['LFGReadyStatus']:Show()
        LFGGroupReadyFrameCloser.response = 'notReady'
        _G['LFGGroupReadyAwesome']:Disable()
    end
end

function LFG.SetSingleRole(role)

    _G['RoleTank']:SetChecked(role == 'tank')
    _G['roleCheckTank']:SetChecked(role == 'tank')

    _G['RoleHealer']:SetChecked(role == 'healer')
    _G['roleCheckHealer']:SetChecked(role == 'healer')

    _G['RoleDamage']:SetChecked(role == 'danage')
    _G['roleCheckDamage']:SetChecked(role == 'damage')

    LFG_ROLE = role

end

function LFGsetRole(role, status, readyCheck)

    local tankCheck = _G['RoleTank']
    local healerCheck = _G['RoleHealer']
    local damageCheck = _G['RoleDamage']

    --ready check window
    local readyCheckTank = _G['roleCheckTank']
    local readyCheckHealer = _G['roleCheckHealer']
    local readyCheckDamage = _G['roleCheckDamage']

    if readyCheck then
        _G['LFGRoleCheckAcceptRole']:Enable()

        if not readyCheckTank:GetChecked() and
                not readyCheckHealer:GetChecked() and
                not readyCheckDamage:GetChecked() then
            _G['LFGRoleCheckAcceptRole']:Disable()
        end

        readyCheckHealer:SetChecked(role == 'healer')
        readyCheckDamage:SetChecked(role == 'damage')
        readyCheckTank:SetChecked(role == 'tank')

        LFG_ROLE = role
        return true
    end

    local newRole = ''

    if LFG.inGroup then
        tankCheck:SetChecked(role == 'tank')
        healerCheck:SetChecked(role == 'healer')
        damageCheck:SetChecked(role == 'damage')
        newRole = role
    else
        if tankCheck:GetChecked() then
            newRole = newRole .. 'tank'
        end
        if healerCheck:GetChecked() then
            newRole = newRole .. 'healer'
        end
        if damageCheck:GetChecked() then
            newRole = newRole .. 'damage'
        end
    end

    LFG_ROLE = newRole

    LFG.fixMainButton()
    lfdebug('newRole = ' .. newRole)
    BrowseDungeonListFrame_Update()
end

function DungeonListFrame_Update(dont_scroll)
    LFG.fillAvailableDungeons(false, dont_scroll)
end

function BrowseDungeonListFrame_Update()
    LFG.LFGBrowse_Update()
end

function DungeonType_OnLoad()
    UIDropDownMenu_Initialize(this, DungeonType_Initialize);
    UIDropDownMenu_SetWidth(LFGTypeSelect, 160);
end

function DungeonType_OnClick(self, arg1)
    LFG_TYPE = arg1
    UIDropDownMenu_SetText(_G['LFGTypeSelect'], LFG.types[LFG_TYPE])

    _G['LFGMainDungeonsText']:SetText('Dungeons')
    _G['LFGBrowseDungeonsText']:SetText('Dungeons')

    _G['LFGDungeonsText']:SetText(LFG.types[LFG_TYPE])

    -- dequeue everything from before
    for dungeon, data in next, LFG.dungeons do
        if _G["Dungeon_" .. data.code .. '_CheckButton'] then
            _G["Dungeon_" .. data.code .. '_CheckButton']:SetChecked(false)
        end
        LFG.dungeons[dungeon].queued = false
    end

    -- dequeue everything after too
    for dungeon, data in next, LFG.dungeons do
        if data.queued then
            if _G["Dungeon_" .. data.code .. '_CheckButton'] then
                _G["Dungeon_" .. data.code .. '_CheckButton']:SetChecked(false)
            end
            LFG.dungeons[dungeon].queued = false
        end
    end

    if LFG_TYPE == 2 then
        LFG.dungeons = LFG.eliteEncounters
    else
        LFG.dungeons = LFG.allDungeons
    end

    for dungeon, data in next, LFG.dungeons do
        if not LFG.dungeonsSpam[data.code] then
            LFG.dungeonsSpam[data.code] = {
                tank = 0,
                healer = 0,
                damage = 0
            }
        end
        if not LFG.dungeonsSpamDisplay[data.code] then
            LFG.dungeonsSpamDisplay[data.code] = {
                tank = 0,
                healer = 0,
                damage = 0
            }
            LFG.dungeonsSpamDisplayLFM[data.code] = 0
        end
        if not LFG.supress[data.code] then
            LFG.supress[data.code] = ''
        end
    end

    LFG.fillAvailableDungeons()

    -- ADD THIS LINE - Hide button textures for newly created dungeon buttons
    if LFG.shouldHideButtonTextures() then
    	LFG.hideAllAddonButtonTextures()
    end
end

function DungeonType_Initialize()
    for id, type in pairs(LFG.types) do
        local info = {}
        info.text = type
        info.value = id
        info.arg1 = id
        info.checked = LFG_TYPE == id
        info.func = DungeonType_OnClick
        if not LFG.findingGroup then
            UIDropDownMenu_AddButton(info)
        end
    end
end

function LFG_HideMinimap()
    for i, frame in pairs(LFG.minimapFrames) do
        if frame and type(frame) == "table" and frame.Hide then
            frame:Hide()
        end
    end
    _G['LFGGroupStatus']:Hide()
end

function LFG_ShowMinimap()

    if LFG.findingGroup or LFG.findingMore then
        local dungeonIndex = 0
        for dungeonCode, _ in next, LFG.group do
            local tank = 0
            local healer = 0
            local damage = 0

            if LFG.group[dungeonCode].tank ~= '' or (not LFG.inGroup and string.find(LFG_ROLE, 'tank', 1, true)) then
                tank = tank + 1
            end
            if LFG.group[dungeonCode].healer ~= '' or (not LFG.inGroup and string.find(LFG_ROLE, 'healer', 1, true)) then
                healer = healer + 1
            end
            if LFG.group[dungeonCode].damage1 ~= '' or (not LFG.inGroup and string.find(LFG_ROLE, 'damage', 1, true)) then
                damage = damage + 1
            end
            if LFG.group[dungeonCode].damage2 ~= '' then
                damage = damage + 1
            end
            if LFG.group[dungeonCode].damage3 ~= '' then
                damage = damage + 1
            end

            if not LFG.minimapFrames[dungeonCode] then
                LFG.minimapFrames[dungeonCode] = CreateFrame('Frame', "LFGMinimap_" .. dungeonCode, UIParent, "LFGMinimapDungeonTemplate")
            end

            local background = ''
            local dungeonName = 'unknown'
            for d, data2 in next, LFG.dungeons do
                if data2.code == dungeonCode then
                    background = data2.background
                    dungeonName = d
                end
            end

            LFG.minimapFrames[dungeonCode]:Show()
            LFG.minimapFrames[dungeonCode]:SetPoint("TOP", _G["LFGGroupStatus"], "TOP", 0, -25 - 46 * (dungeonIndex))
            _G['LFGMinimap_' .. dungeonCode .. 'Background']:SetTexture('Interface\\addons\\LFG\\images\\background\\ui-lfg-background-' .. background)
            _G['LFGMinimap_' .. dungeonCode .. 'DungeonName']:SetText(dungeonName)

            --_G['LFGMinimap_' .. dungeonCode .. 'MyRole']:SetTexture('Interface\\addons\\LFG\\images\\ready_' .. LFG_ROLE)
            _G['LFGMinimap_' .. dungeonCode .. 'MyRole']:Hide() -- hide for now  - dev

            if tank == 0 then
                _G['LFGMinimap_' .. dungeonCode .. 'ReadyIconTank']:SetDesaturated(1)
            end
            if healer == 0 then
                _G['LFGMinimap_' .. dungeonCode .. 'ReadyIconHealer']:SetDesaturated(1)
            end
            if damage == 0 then
                _G['LFGMinimap_' .. dungeonCode .. 'ReadyIconDamage']:SetDesaturated(1)
            end
            _G['LFGMinimap_' .. dungeonCode .. 'NrTank']:SetText(tank .. '/1')
            _G['LFGMinimap_' .. dungeonCode .. 'NrHealer']:SetText(healer .. '/1')
            _G['LFGMinimap_' .. dungeonCode .. 'NrDamage']:SetText(damage .. '/3')

            dungeonIndex = dungeonIndex + 1
        end

        _G['LFGGroupStatus']:SetHeight(dungeonIndex * 46 + 95)
        _G['LFGGroupStatusTimeInQueue']:SetText('Time in Queue: ' .. SecondsToTime(time() - LFG.queueStartTime))
        if LFG.averageWaitTime == 0 then
            _G['LFGGroupStatusAverageWaitTime']:SetText('Average Wait Time: Unavailable')
        else
            _G['LFGGroupStatusAverageWaitTime']:SetText('Average Wait Time: ' .. SecondsToTimeAbbrev(LFG.averageWaitTime))
        end

        local x, y = GetCursorPosition()

        if x < 800 and y > 300 then
            _G['LFGGroupStatus']:SetPoint("TOPLEFT", _G["LFG_Minimap"], "BOTTOMRIGHT", 0, 0)
        elseif x < 800 and y < 300 then
            _G['LFGGroupStatus']:SetPoint("TOPLEFT", _G["LFG_Minimap"], "TOPRIGHT", 0, _G['LFGGroupStatus']:GetHeight())
        elseif x > 800 and y > 300 then
            _G['LFGGroupStatus']:SetPoint("TOPLEFT", _G["LFG_Minimap"], "TOPRIGHT", -_G['LFGGroupStatus']:GetWidth() - 40, -20)
        else
            _G['LFGGroupStatus']:SetPoint("TOPLEFT", _G["LFG_Minimap"], "TOPRIGHT", -_G['LFGGroupStatus']:GetWidth() - 40, _G['LFGGroupStatus']:GetHeight())
        end

        _G['LFGGroupStatus']:Show()
    else
        GameTooltip:SetOwner(this, "ANCHOR_LEFT", 0, -110)
        GameTooltip:AddLine('Looking For Group', 1, 1, 1)
        GameTooltip:AddLine('Left-click to open LFG.')
        GameTooltip:AddLine('Drag to move.')
        GameTooltip:AddLine('You are not queued for any dungeons.')
        if LFG.peopleLookingForGroupsDisplay == 0 then
            GameTooltip:AddLine('No players are looking for groups at the moment.')
        elseif LFG.peopleLookingForGroupsDisplay == 1 then
            GameTooltip:AddLine(LFG.peopleLookingForGroupsDisplay .. ' player is looking for groups at the moment.')
        else
            GameTooltip:AddLine(LFG.peopleLookingForGroupsDisplay .. ' players are looking for groups at the moment.')
        end
        GameTooltip:Show()
    end
end

function queueForFromButton(bCode)

    local codeEx = StringSplit(bCode, '_')
    local qCode = codeEx[2]

    if _G['Dungeon_' .. qCode .. '_CheckButton']:IsEnabled() == 0 then
        return false
    end

    for code, data in next, LFG.availableDungeons do
        if code == qCode and not LFG.findingGroup then
            _G['Dungeon_' .. data.code .. '_CheckButton']:SetChecked(not _G['Dungeon_' .. data.code .. '_CheckButton']:GetChecked())
            queueFor(bCode, _G['Dungeon_' .. data.code .. '_CheckButton']:GetChecked())
        end
    end
end

function queueFor(name, status)

    lfdebug('queue for call ' .. name)

    local dungeonCode = ''
    local dung = StringSplit(name, '_')
    dungeonCode = dung[2]
    for dungeon, data in next, LFG.dungeons do
        if tonumber(dungeonCode) then
            dungeonCode = tonumber(dungeonCode)
        end
        if dungeonCode == data.code then
            if status then
                LFG.dungeons[dungeon].queued = true
            else
                LFG.dungeons[dungeon].queued = false
            end
        end
    end

    local queues = 0
    for _, data in next, LFG.dungeons do
        if data.queued then
            queues = queues + 1
        end
    end

    lfdebug(queues .. ' queues in queuefor')

    LFG.inGroup = GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0

    lfdebug('queues: ' .. queues)
    lfdebug(LFG.inGroup)

    if LFG.inGroup then
        if queues == 1 then
            LFG.LFMDungeonCode = dungeonCode
            LFG.disableDungeonCheckButtons(dungeonCode)
        end
    else
        if queues < LFG.maxDungeonsInQueue then
            --LFG.enableDungeonCheckButtons()
        else
            for _, frame in next, LFG.availableDungeons do
                local dungeonName = LFG.dungeonNameFromCode(frame.code)
                lfdebug('dungeonName in queuefor = ' .. dungeonName)
                lfdebug('frame.code in queuefor = ' .. frame.code)
                lfdebug('frame.background in queuefor = ' .. frame.background)
                if not LFG.dungeons[dungeonName].queued then
                    _G["Dungeon_" .. frame.code .. '_CheckButton']:Disable()
                    _G['Dungeon_' .. frame.code .. 'Text']:SetText(COLOR_DISABLED .. dungeonName)
                    _G['Dungeon_' .. frame.code .. 'Levels']:SetText(COLOR_DISABLED .. '(' .. frame.minLevel .. ' - ' .. frame.maxLevel .. ')')

                    local q = 'dungeons'

                    LFG.addOnEnterTooltip(_G['Dungeon_' .. frame.code .. '_Button'], 'Queueing for ' .. dungeonName .. ' is unavailable', 'Maximum allowed queued ' .. q .. ' at a time is ' .. LFG.maxDungeonsInQueue .. '.')
                end
            end
        end
    end
    DungeonListFrame_Update(true)
    LFG.fixMainButton()
end

function findMore()

    --LFGsetRole('tank', true, true)

    -- find queueing dungeon
    local qDungeon = ''
    for _, frame in next, LFG.availableDungeons do
        if _G["Dungeon_" .. frame.code .. '_CheckButton']:GetChecked() then
            qDungeon = frame.code
        end
    end

    LFG.LFMDungeonCode = qDungeon

    local tankCheck = _G['RoleTank']
    local healerCheck = _G['RoleHealer']
    local damageCheck = _G['RoleDamage']

    if tankCheck:GetChecked() then
        LFGsetRole('tank', true, true)
    elseif healerCheck:GetChecked() then
        LFGsetRole('healer', true, true)
    elseif damageCheck:GetChecked() then
        LFGsetRole('damage', true, true)
    end

    SendAddonMessage(LFG_ADDON_CHANNEL, "roleCheck:" .. qDungeon, "PARTY")

    LFG.fixMainButton()

    -- disable the button disable spam clicking it
    _G['findMoreButton']:Disable()

    BrowseDungeonListFrame_Update()
end

function joinQueue(roleID, name)

    lfdebug('join queue call ' .. name)
    lfdebug('join queue call role ' .. roleID)

    local nameEx = StringSplit(name, '_')
    local mCode = nameEx[2]

    --leaveQueue('from join queue')

    if _G['Dungeon_' .. mCode .. '_CheckButton'] ~= nil then
        _G['Dungeon_' .. mCode .. '_CheckButton']:SetChecked(true)
    end

    queueFor(name, true)

    findGroup()
end

function findGroup()

    LFG.resetGroup()

    _G['RoleTank']:Disable()
    _G['RoleHealer']:Disable()
    _G['RoleDamage']:Disable()

    PlaySound('PvpEnterQueue')

    local roleText = ''
    if string.find(LFG_ROLE, 'tank', 1, true) then
        roleText = roleText .. COLOR_TANK .. 'Tank'
    end
    if string.find(LFG_ROLE, 'healer', 1, true) then
        local orText = ''
        if roleText ~= '' then
            orText = COLOR_WHITE .. ', '
        end
        roleText = roleText .. orText .. COLOR_HEALER .. 'Healer'
    end
    if string.find(LFG_ROLE, 'damage', 1, true) then
        local orText = ''
        if roleText ~= '' then
            orText = COLOR_WHITE .. ', '
        end
        roleText = roleText .. orText .. COLOR_DAMAGE .. 'Damage'
    end

    local dungeonsText = ''
    for dungeon, data in next, LFG.dungeons do
        if data.queued then
            lfdebug('in find group queued for : ' .. dungeon)
            dungeonsText = dungeonsText .. dungeon .. ', '
            --lfg_text = 'LFG:' .. data.code .. ':' .. LFG_ROLE .. ' ' .. lfg_text
        end
    end

    dungeonsText = string.sub(dungeonsText, 1, string.len(dungeonsText) - 2)
    lfprint('You are in the queue for |cff69ccf0' .. dungeonsText .. COLOR_WHITE .. ' as: ' .. roleText)

    LFG.findingGroup = true
    LFGQueue:Show()
    LFGMinimapAnimation:Show()

    LFG.disableDungeonCheckButtons()
    LFG.oneGroupFull = false
    LFG.queueStartTime = time()

    LFG.fixMainButton()

    BrowseDungeonListFrame_Update()
end

function leaveQueue(callData)

    if callData then
        lfdebug('-------- leaveQueue(' .. callData .. ')')
    else
        lfdebug('-------- leaveQueue(no-callData)')
    end
    lfdebug('_G[LFGGroupReady]:Hide()')
    _G['LFGGroupReady']:Hide()
    _G["LFGDungeonStatus"]:Hide()
    _G['LFGRoleCheck']:Hide()

    LFGGroupReadyFrameCloser:Hide()
    LFGGroupReadyFrameCloser.response = ''

    LFGQueue:Hide()
    LFGRoleCheck:Hide()
    lfdebug('LFGRoleCheck:Hide() in leaveQueue')

    LFG.hidePartyRoleIcons()
    LFG.hideMyRoleIcon()

    local dungeonsText = ''

    for dungeon, data in next, LFG.dungeons do
        if data.queued then
            if callData ~= 'from join queue' then
                if _G["Dungeon_" .. data.code .. '_CheckButton'] then
                    _G["Dungeon_" .. data.code .. '_CheckButton']:SetChecked(false)
                end
                LFG.dungeons[dungeon].queued = false
            end
            dungeonsText = dungeonsText .. dungeon .. ', '
        end
    end

    dungeonsText = string.sub(dungeonsText, 1, string.len(dungeonsText) - 2)
    if dungeonsText == '' then
        dungeonsText = LFG.dungeonNameFromCode(LFG.LFMDungeonCode)
    end
    if LFG.findingGroup or LFG.findingMore then
        if LFG.inGroup then
            if LFG.isLeader then
                SendAddonMessage(LFG_ADDON_CHANNEL, "leaveQueue:now", "PARTY")
            end
            lfprint('Your group has left the queue for |cff69ccf0' .. dungeonsText .. COLOR_WHITE .. '.')
        else
            if callData ~= 'from join queue' then
                lfprint('You have left the queue for |cff69ccf0' .. dungeonsText .. COLOR_WHITE .. '.')
            end
        end

        LFG.sendCancelMeMessage()
        LFG.findingGroup = false
        LFG.findingMore = false
    end

    LFG.enableDungeonCheckButtons()

    LFG.GetPossibleRoles()
    --LFGsetRole(LFG_ROLE)

    if LFG.LFMDungeonCode ~= '' then
        if _G["Dungeon_" .. LFG.LFMDungeonCode .. '_CheckButton'] then
            _G["Dungeon_" .. LFG.LFMDungeonCode .. '_CheckButton']:SetChecked(true)
            LFG.dungeons[LFG.dungeonNameFromCode(LFG.LFMDungeonCode)].queued = true
        end
    end

    local tankCheck = _G['RoleTank']
    local healerCheck = _G['RoleHealer']
    local damageCheck = _G['RoleDamage']

    DungeonListFrame_Update()
    BrowseDungeonListFrame_Update()
end

function LFGObjectives.objectiveComplete(bossName, dontSendToAll)
    local code = ''
    local objectivesString = ''
    for index, _ in next, LFG.objectivesFrames do
        if LFG.objectivesFrames[index].name == bossName then
            if not LFG.objectivesFrames[index].completed then
                LFG.objectivesFrames[index].completed = true

                LFGObjectives.objectivesComplete = LFGObjectives.objectivesComplete + 1

                _G["LFGObjective" .. index .. 'ObjectiveComplete']:Show()
                _G["LFGObjective" .. index .. 'ObjectivePending']:Hide()
                -- _G["LFGObjective" .. index .. 'Objective']:SetText(COLOR_WHITE .. '1/1 ' .. bossName .. ' defeated')
                _G["LFGObjective" .. index .. 'Objective']:SetText(COLOR_WHITE .. '' .. bossName .. '')

                LFGObjectives.lastObjective = index
                LFGObjectives:Show()
                code = LFG.objectivesFrames[index].code

            else
            end
        end
        if LFG.objectivesFrames[index].completed then
            objectivesString = objectivesString .. '1-'
        else
            objectivesString = objectivesString .. '0-'
        end
    end

    if code ~= '' then
        if not dontSendToAll then
            lfdebug("send " .. "objectives:" .. code .. ":" .. objectivesString)
            SendAddonMessage(LFG_ADDON_CHANNEL, "objectives:" .. code .. ":" .. objectivesString, "PARTY")
        end

        --dungeon complete ?
        local dungeonName, iconCode = LFG.dungeonNameFromCode(code)
        if LFGObjectives.objectivesComplete == LFG.tableSize(LFG.objectivesFrames) or
                (code == 'brdarena' and LFGObjectives.objectivesComplete == 1) then
            _G['LFGDungeonCompleteIcon']:SetTexture('Interface\\addons\\LFG\\images\\icon\\lfgicon-' .. iconCode)
            _G['LFGDungeonCompleteDungeonName']:SetText(dungeonName)
            LFGDungeonComplete.dungeonInProgress = false
            LFGDungeonComplete:Show()
            LFGObjectives.closedByUser = false
        else
            LFGDungeonComplete.dungeonInProgress = true
        end
    end
end

function toggleDungeonStatus_OnClick()
    LFGObjectives.collapsed = not LFGObjectives.collapsed
    if LFGObjectives.collapsed then
        _G["LFGDungeonStatusCollapseButton"]:Hide()
        _G["LFGDungeonStatusExpandButton"]:Show()
    else
        _G["LFGDungeonStatusCollapseButton"]:Show()
        _G["LFGDungeonStatusExpandButton"]:Hide()
    end
    for index, _ in next, LFG.objectivesFrames do
        if LFGObjectives.collapsed then
            _G["LFGObjective" .. index]:Hide()
        else
            _G["LFGObjective" .. index]:Show()
        end
    end
end

function lfg_switch_tab(t)
    LFG.tab = t
    PlaySound("igCharacterInfoTab");
    if t == 1 then
        _G['LFGBrowse']:Hide()
        _G['LFGMain']:Show()
    elseif t == 2 then
        _G['LFGMain']:Hide()
        _G['LFGBrowse']:Show()
    end
end

-- slash commands
SLASH_LFG1 = "/lfgaddon"
SLASH_LFG2 = "/lfg"
SlashCmdList["LFG"] = function(cmd)
    if cmd then
        if string.sub(cmd, 1, 4) == 'spam' then
            LFG_CONFIG['spamChat'] = not LFG_CONFIG['spamChat']
            if LFG_CONFIG['spamChat'] then
                lfnotice('Groups formed spam is on')
            else
                lfnotice('Groups formed spam is off')
            end
        end
        if string.sub(cmd, 1, 3) == 'who' then
            if me ~= 'Bennylava' then
                return false
            end
            if LFG.channelIndex == 0 then
                lfprint('LFG.channelIndex = 0, please try again in 10 seconds')
                return false
            end
            LFGWhoCounter:Show()
            SendChatMessage('whoLFG:' .. addonVer, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFG.channel))
        end
        if string.sub(cmd, 1, 17) == 'resetformedgroups' then
            LFG.resetFormedGroups()
            lfprint('Formed groups history reset.')
        end
        if string.sub(cmd, 1, 12) == 'formedgroups' then
            lfprint('Listing formed groups history')
            local totalGroups = 0
            for code, number in next, LFG_FORMED_GROUPS do
                if number ~= 0 then
                    totalGroups = totalGroups + number
                    lfprint(number .. ' - ' .. LFG.dungeonNameFromCode(code))
                end
            end
            if totalGroups == 0 then
                lfprint('There are no recorded formed groups.')
            else
                lfprint('There are ' .. totalGroups .. ' recorded formed groups.')
            end
        end
        if string.sub(cmd, 1, 5) == 'debug' then
            LFG_CONFIG['debug'] = not LFG_CONFIG['debug']
            if LFG_CONFIG['debug'] then
                lfprint('debug enabled')
                _G['LFGTitleTime']:Show()
            else
                lfprint('debug disabled')
                _G['LFGTitleTime']:Hide()
            end
        end
        if string.sub(cmd, 1, 9) == 'advertise' then
            LFG.sendAdvertisement("PARTY")
        end
        if string.sub(cmd, 1, 8) == 'sayguild' then
            LFG.sendAdvertisement("GUILD")
        end
    end
end

function LFG.sendAdvertisement(chan)
    SendChatMessage('I am using Looking For Group - LFG Addon for Project Epoch v' .. addonVer, chan, DEFAULT_CHAT_FRAME.editBox.languageID)
    SendChatMessage('Get it at: https://github.com/Bennylavaa/LFG', chan, DEFAULT_CHAT_FRAME.editBox.languageID)
end

function LFG.removeChannelFromWindows()
    if LFG_CONFIG and LFG_CONFIG['debug'] then
        return false
    end
    if me == 'Bennylava' then
        return false
    end

    if LFG.channelIndex == 1 then
        lfdebug('Not removing LFG from windows - channel conflict detected')
        return false
    end

    for windowIndex = 1, 9 do
        local channels = { GetChatWindowChannels(windowIndex) }
        for i = 1, #channels, 2 do
            local channelName = channels[i]
            local channelIndex = channels[i + 1]

            if channelName == LFG.channel and channelIndex == LFG.channelIndex then
                local chatFrame = _G["ChatFrame" .. windowIndex]
                if chatFrame then
                    ChatFrame_RemoveChannel(chatFrame, LFG.channel)
                    lfdebug('LFG channel removed from window ' .. windowIndex)
                end
            end
        end
    end
end

function LFG.incDungeonssSpamRole(dungeon, role, nrInc)

    if not nrInc then
        nrInc = 1
    end

    if not role then
        role = LFG_ROLE
    end

    if not LFG.dungeonsSpam[dungeon] then
        lfdebug('error in incDugeon, ' .. dungeon .. ' not init')
        return false
    end

    if role == 'tank' then
        LFG.dungeonsSpam[dungeon].tank = LFG.dungeonsSpam[dungeon].tank + nrInc
    end
    if role == 'healer' then
        LFG.dungeonsSpam[dungeon].healer = LFG.dungeonsSpam[dungeon].healer + nrInc
    end
    if role == 'damage' then
        LFG.dungeonsSpam[dungeon].damage = LFG.dungeonsSpam[dungeon].damage + nrInc
    end
end

function LFG.updateDungeonsSpamDisplay(code, lfm, numLFM)

    if not LFG.dungeonsSpam[code] then
        lfdebug('error in updateDungeons, ' .. code .. ' not init')
        return false
    end

    if not LFG.dungeonsSpamDisplay[code] then
        lfdebug('error in updateDungeons, ' .. code .. ' not init, display')
        return false
    end

    if LFG.dungeonsSpam[code].tank ~= 0 then
        LFG.dungeonsSpamDisplay[code].tank = LFG.dungeonsSpam[code].tank
    end

    if LFG.dungeonsSpam[code].healer ~= 0 then
        LFG.dungeonsSpamDisplay[code].healer = LFG.dungeonsSpam[code].healer
    end

    if LFG.dungeonsSpam[code].damage ~= 0 then
        LFG.dungeonsSpamDisplay[code].damage = LFG.dungeonsSpam[code].damage
    end

    if lfm then
        if LFG.dungeonsSpamDisplayLFM[code] == 0 then
            LFG.dungeonsSpamDisplayLFM[code] = numLFM
        else
            if numLFM > LFG.dungeonsSpamDisplayLFM[code] then
                LFG.dungeonsSpamDisplayLFM[code] = numLFM
            end
        end
    end

end

-- dungeons

LFG.dungeons = {}

LFG.allDungeons = {
    ['Ragefire Chasm'] = { minLevel = 13, maxLevel = 18, code = 'rfc', queued = false, canQueue = true, background = 'ragefirechasm', myRole = '' },
    ['Wailing Caverns'] = { minLevel = 17, maxLevel = 24, code = 'wc', queued = false, canQueue = true, background = 'wailingcaverns', myRole = '' },
    ['The Deadmines'] = { minLevel = 17, maxLevel = 24, code = 'dm', queued = false, canQueue = true, background = 'deadmines', myRole = '' },
    ['Shadowfang Keep'] = { minLevel = 22, maxLevel = 30, code = 'sfk', queued = false, canQueue = true, background = 'shadowfangkeep', myRole = '' },
    ['The Stockade'] = { minLevel = 22, maxLevel = 30, code = 'stocks', queued = false, canQueue = true, background = 'stormwindstockades', myRole = '' },
    ['Blackfathom Deeps'] = { minLevel = 23, maxLevel = 32, code = 'bfd', queued = false, canQueue = true, background = 'blackfathomdeeps', myRole = '' },
    ['Scarlet Monastery Graveyard'] = { minLevel = 28, maxLevel = 36, code = 'smgy', queued = false, canQueue = true, background = 'scarletmonastery', myRole = '' },
    ['Scarlet Monastery Library'] = { minLevel = 32, maxLevel = 39, code = 'smlib', queued = false, canQueue = true, background = 'scarletmonastery', myRole = '' },
    ['Gnomeregan'] = { minLevel = 29, maxLevel = 38, code = 'gnome', queued = false, canQueue = true, background = 'gnomeregan', myRole = '' },
    ['Razorfen Kraul'] = { minLevel = 29, maxLevel = 38, code = 'rfk', queued = false, canQueue = true, background = 'razorfenkraul', myRole = '' },
    ['Scarlet Monastery Armory'] = { minLevel = 34, maxLevel = 41, code = 'smarm', queued = false, canQueue = true, background = 'scarletmonastery', myRole = '' },
    ['Scarlet Monastery Cathedral'] = { minLevel = 37, maxLevel = 45, code = 'smcath', queued = false, canQueue = true, background = 'scarletmonastery', myRole = '' },
    ['Razorfen Downs'] = { minLevel = 36, maxLevel = 46, code = 'rfd', queued = false, canQueue = true, background = 'razorfendowns', myRole = '' },
    ['Glittermurk Mines'] = { minLevel = 39, maxLevel = 44, code = 'gmm', queued = false, canQueue = true, background = 'tcg', myRole = '' }, -- Glittermurk
    ['Uldaman'] = { minLevel = 40, maxLevel = 51, code = 'ulda', queued = false, canQueue = true, background = 'uldaman', myRole = '' },
    ['Zul\'Farrak'] = { minLevel = 44, maxLevel = 54, code = 'zf', queued = false, canQueue = true, background = 'zulfarak', myRole = '' },
    ['Maraudon Orange'] = { minLevel = 47, maxLevel = 55, code = 'orange', queued = false, canQueue = true, background = 'maraudon', myRole = '' },
    ['Maraudon Purple'] = { minLevel = 45, maxLevel = 55, code = 'purple', queued = false, canQueue = true, background = 'maraudon', myRole = '' },
    ['Maraudon Princess'] = { minLevel = 47, maxLevel = 55, code = 'princess', queued = false, canQueue = true, background = 'maraudon', myRole = '' },
    ['Temple of Atal\'Hakkar'] = { minLevel = 50, maxLevel = 60, code = 'st', queued = false, canQueue = true, background = 'sunkentemple', myRole = '' },
    ['Blackrock Depths'] = { minLevel = 52, maxLevel = 60, code = 'brd', queued = false, canQueue = true, background = 'blackrockdepths', myRole = '' },
    ['Blackrock Depths Arena'] = { minLevel = 52, maxLevel = 60, code = 'arena', queued = false, canQueue = true, background = 'blackrockdepths', myRole = '' },
    ['Blackrock Depths Emperor'] = { minLevel = 54, maxLevel = 60, code = 'emp', queued = false, canQueue = true, background = 'blackrockdepths', myRole = '' },
    ['Lower Blackrock Spire'] = { minLevel = 55, maxLevel = 60, code = 'lbrs', queued = false, canQueue = true, background = 'blackrockspire', myRole = '' },
    ['Baradin Hold'] = { minLevel = 57, maxLevel = 60, code = 'bh', queued = false, canQueue = true, background = 'kc', myRole = '' }, --Baradin Hold
    -- ['Stonetalon Peaks'] = { minLevel = 57, maxLevel = 60, code = 'stp', queued = false, canQueue = true, background = 'hfq', myRole = '' }, --Stonetalon Peaks
    ['Scholomance'] = { minLevel = 58, maxLevel = 60, code = 'scholo', queued = false, canQueue = true, background = 'scholomance', myRole = '' },
    ['Stratholme: Undead District'] = { minLevel = 58, maxLevel = 60, code = 'ud', queued = false, canQueue = true, background = 'stratholme', myRole = '' },
    ['Stratholme: Scarlet Bastion'] = { minLevel = 58, maxLevel = 60, code = 'live', queued = false, canQueue = true, background = 'stratholme', myRole = '' },
    ['Upper Blackrock Spire'] = { minLevel = 58, maxLevel = 60, code = 'ubrs', queued = false, canQueue = true, background = 'blackrockspire', myRole = '' },

}

LFG.eliteEncounters = {
    ['Jintha\'Alor'] = { minLevel = 45, maxLevel = 60, code = 'ja', queued = false, canQueue = true, background = 'jinthaalor', myRole = '' },
    ['Felstone Fortress'] = { minLevel = 50, maxLevel = 60, code = 'ff', queued = false, canQueue = true, background = 'felstonefort', myRole = '' },
    ['Silithus Dailies'] = { minLevel = 60, maxLevel = 60, code = 'silithusd', queued = false, canQueue = true, background = 'silithusdailies', myRole = '' },
}

LFG.bosses = {
    ['rfc'] = {
        'Oggleflint',
        'Taragaman the Hungerer',
        'Jergosh the Invoker',
        'Bazzalan'
    },
    ['wc'] = {
        'Lord Cobrahn',
        'Lady Anacondra',
        'Kresh',
        'Lord Pythas',
        'Skum',
        'Nyx',
        'Lord Serpentis',
        'Verdan the Everliving',
        'Mutanus the Devourer'
    },
    ['dm'] = {
        'Rhahk\'zor',
        'Sneed',
        'Gilnid',
        'Mr. Smite',
        'Cookie',
        'Captain Greenskin',
        'Edwin VanCleef'
    },
    ['sfk'] = {
        'Rethilgore',
        'Razorclaw the Butcher',
        'Baron Silverlaine',
        'Commander Springvale',
        'Odo the Blindwatcher',
        'Steward Graves',
        'Fenrus the Devourer',
        'Wolf Master Nandos',
        'Archmage Arugal'
    },
    ['bfd'] = {
        'Ghamoo-ra',
        'Lady Sarevess',
        'Gelihast',
        'Lorgus Jett',
        'Baron Aquanis',
        'Twilight Lord Kelris',
        'Old Serra\'kis',
        'Aku\'mai'
    },
    ['stocks'] = {
        'Targorr the Dread',
        'Kam Deepfury',
        'Hamhock',
        'Bazil Thredd',
        'Dextren Ward'
    },
    ['gnome'] = {
        'Grubbis',
        'Viscous Fallout',
        'Electrocutioner 6000',
        'Crowd Pummeler 9-60',
        'Mekgineer Thermaplugg'
    },
    ['rfk'] = {
        'Roogug',
        'Aggem Thorncurse',
        'Death Speaker Jargba',
        'Overlord Ramtusk',
        'Agathelos the Raging',
        'Charlga Razorflank'
    },
    ['smgy'] = {
        'Interrogator Vishas',
        'Bloodmage Thalnos'
    },
    ['smarm'] = {
        'Herod'
    },
    ['smcath'] = {
        'High Inquisitor Fairbanks',
        'Scarlet Commander Mograine',
        'High Inquisitor Whitemane'
    },
    ['smlib'] = {
        'Houndmaster Loksey',
        'Arcanist Doan'
    },
    ['rfd'] = {
        'Tuten\'kash',
        'Mordresh Fire Eye',
        'Glutton',
        'Plaguemaw the Rotting',
        'Amnennar the Coldbringer'
    },
    ['gmm'] = { -- Glittermurk
        'Supervisor Grimgash',
        'Foreman Sprocket',
        'Krakken',
        'Primscale',
        'Murklurk',
        'Gnash'
    },
    ['ulda'] = {
        'Revelosh',
        'The Lost Dwarves',
        'Ironaya',
        'Obsidian Sentinel',
        'Ancient Stone Keeper',
        'Galgann Firehammer',
        'Grimlok',
        'Sentinel of Archaedas'
    },
    ['zf'] = {
        'Antu\'sul',
        'Theka the Martyr',
        'Witch Doctor Zum\'rah',
        'Sandfury Executioner',
        'Nekrum Gutchewer',
        'Shadowpriest Sezz\'ziz',
        'Sergeant Bly',
        'Hydromancer Velratha',
        'Ruuzlu',
        'Chief Ukorz Sandscalp'
    },
    ['orange'] = {
        'Noxxion',
        'Razorlash'
    },
    ['purple'] = {
        'Lord Vyletongue',
        'Celebras the Cursed'
    },
    ['princess'] = {
        'Tinkerer Gizlock',
        'Landslide',
        'Rotgrip',
        'Princess Theradras'
    },
    ['st'] = {
        'Gasher',
        'Atal\'alarion',
        'Dreamscythe',
        'Weaver',
        'Jammal\'an the Prophet',
        'Ogom the Wretched',
        'Morphaz',
        'Hazzas',
        '???',
        'Shade of Eranikus'
    },
    ['brd'] = {
        'Lord Roccor',
        'Bael\'Gar',
        'Houndmaster Grebmar',
        'High Interrogator Gerstahn',
        'High Justice Grimstone',
        'Pyromancer Loregrain',
        'General Angerforge',
        'Verek',
        'Golem Lord Argelmach',
        'Ribbly Screwspigot',
        'Hurley Blackbreath',
        'Plugger Spazzring',
        'Phalanx',
        'Lord Incendius',
        'Fineous Darkvire',
        'Warder Stilgiss',
        'Watchman Doomgrip',
        'Ambassador Flamelash',
        'Magmus',
        'Emperor Dagran Thaurissan'
    },
    ['emp'] = {
        'General Angerforge',
        'Golem Lord Argelmach',
        'Emperor Dagran Thaurissan',
        'Magmus',
        'Ambassador Flamelash'
    },
    ['arena'] = {
        'Anub\'shiah-s', --summoned
        'Eviscerator-s', --summoned
        'Gorosh the Dervish-s', --summoned
        'Grizzle-s', --summoned
        'Hedrum the Creeper-s', --summoned
        'Ok\'thor the Breaker-s' --summoned
    },
    ['lbrs'] = {
        'Highlord Omokk',
        'Shadow Hunter Vosh\'gajin',
        'War Master Voone',
        'Mother Smolderweb',
        '???',
        'Quartermaster Zigris',
        'Halycon',
        'Gizrul the Slavener',
        'Overlord Wyrmthalak'
    },
    ['bh'] = { --Baradin Hold
        'Morrumus',
        'Millhouse Manastorm',
        'Astilos the Hollow',
        'Calypso',
        'Dak\'mal',
        'Glagut',
        'Nazrasash',
        'Pirate Lord Blackstone'
    },
    -- ['stp'] = { --Stonetalon Peaks
        -- '',
        -- '',
        -- '',
        -- '',
        -- ''
    -- },
    ['scholo'] = {
        'Kirtonos the Herald',
        'Jandice Barov',
        'Rattlegore',
        'Marduk Blackpool',
        'Vectus',
        'Ras Frostwhisper',
        'Instructor Malicia',
        '???',
        'Doctor Theolen Krastinov',
        'Lorekeeper Polkelt',
        'The Ravenian',
        'Lord Alexei Barov',
        'Lady Illucia Barov',
        'Darkmaster Gandling'
    },
    ['live'] = {
        'Fras Siabi',
        'Hearthsinger Forresten',
        'The Unforgiven',
        'Postmaster Malown',
        'Timmy the Cruel',
        'Malor the Zealous',
        'Cannon Master Willey',
        'Crimson Hammersmith',
        'Archivist Galford',
        'Balnazzar'
    },
    ['ud'] = {
        'Magistrate Barthilas',
        'Stonespine',
        'Nerub\'enkan',
        'Black Guard Swordsmith',
        'Maleki the Pallid',
        'Baroness Anastari',
        'Ramstein the Gorger',
        'Baron Rivendare'
    },
    ['ubrs'] = {
        'Pyroguard Emberseer',
        'Solakar Flamewreath',
        'Warchief Rend Blackhand',
        'Gyth',
        'The Beast',
        'General Drakkisath'
    },
    ['ja'] = {
        'Vile Priestess Hexx',
    },
    ['ff'] = {
        --'Vile Priestess Hexx',
    },
    ['silithusd'] = {
        --'Vile Priestess Hexx',
    },
};

-- utils

function LFG.isEliteEncounter(dungeonCode)
    for _, data in next, LFG.eliteEncounters do
        if data.code == dungeonCode then
            return true
        end
    end
    return false
end

function LFG.playerClass(name)
    if name == me then
        local _, unitClass = UnitClass('player')
        return string.lower(unitClass)
    end
    for i = 1, GetNumPartyMembers() do
        if UnitName('party' .. i) then
            if name == UnitName('party' .. i) then
                local _, unitClass = UnitClass('party' .. i)
                return string.lower(unitClass)
            end
        end
    end
    return 'priest'
end

function LFG.ver(ver)
    return tonumber(string.sub(ver, 1, 1)) * 1000 +
            tonumber(string.sub(ver, 3, 3)) * 100 +
            tonumber(string.sub(ver, 5, 5)) * 10 +
            tonumber(string.sub(ver, 7, 7)) * 1
end

function LFG.ucFirst(a)
    return string.upper(string.sub(a, 1, 1)) .. string.lower(string.sub(a, 2, string.len(a)))
end

function StringSplit(str, delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(str, delimiter, from)
    while delim_from do
        table.insert(result, string.sub(str, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = string.find(str, delimiter, from)
    end
    table.insert(result, string.sub(str, from))
    return result
end

local channelMonitorFrame = CreateFrame("Frame")
channelMonitorFrame:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
channelMonitorFrame:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE_USER")
channelMonitorFrame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_CHANNEL_NOTICE" then
        if arg1 == "YOU_JOINED" and arg9 == LFG.channel then
            local channelIndex = arg8
            if channelIndex == 1 then
                lfprint('LFG joined in channel 1! Auto-fixing...')
                LFG.fixChannelConflict()
            else
                LFG.channelIndex = channelIndex
                lfdebug('LFG properly joined in channel: ' .. channelIndex)
            end
        end
    elseif event == "CHAT_MSG_CHANNEL_NOTICE_USER" then
        if LFG.channelIndex > 0 then
            local checkFrame = CreateFrame("Frame")
            checkFrame.elapsed = 0
            checkFrame:SetScript("OnUpdate", function(self, elapsed)
                self.elapsed = self.elapsed + elapsed
                if self.elapsed >= 0.5 then
                    local currentIndex = GetChannelName(LFG.channel)
                    if currentIndex == 1 and LFG.channelIndex ~= 1 then
                        lfprint('Channel conflict detected! Fixing...')
                        LFG.fixChannelConflict()
                    end
                    self:SetScript("OnUpdate", nil)
                end
            end)
        end
    end
end)
