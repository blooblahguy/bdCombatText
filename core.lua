local media = {
	flat = "Interface\\Buttons\\WHITE8x8",
	font = "fonts\\ARIALN.ttf"
}

local config = {
	fontsize = 14,
	throttletime = 2,
	threshold = 100
}

SetCVar("floatingCombatTextCombatDamage", 1)
SetCVar("floatingCombatTextCombatHealing", 0)

local incoming =  CreateFrame('frame', "bdCT_Outgoing", UIParent)
incoming:SetPoint("CENTER", UIParent, "CENTER", -500, 0)
incoming:SetSize(200, 300)
incoming:SetFrameStrata("TOOLTIP")
bdCore:makeMovable(incoming)
local outgoing = CreateFrame('frame', "bdCT_Outgoing", UIParent)
outgoing:SetPoint("CENTER", UIParent, "CENTER", 500, 0)
outgoing:SetSize(200, 300)
outgoing:SetFrameStrata("TOOLTIP")
bdCore:makeMovable(outgoing)

local function numberize(v)
	if v <= 9999 then return v end
	if v >= 1000000000 then
		local value = string.format("%.1fb", v/1000000000)
		return value
	elseif v >= 1000000 then
		local value = string.format("%.1fm", v/1000000)
		return value
	elseif v >= 10000 then
		local value = string.format("%.1fk", v/1000)
		return value
	end
end

local player = UnitName("player")
local frameheight = 10+config.fontsize

-- we're going to create all the frames we need now so that we don't have a big memory sink
local frame_cache = {}
local data = {}
local outgoing_entries = {}
local incoming_entries = {}
function GetFrame(parent)
	local frame = table.remove(frame_cache) or CreateFrame("Frame", nil, UIParent)
	frame:SetParent(parent)
	frame:SetSize(200, frameheight)
	
	if (not frame.text) then
		frame.text = frame:CreateFontString("amount")
		frame.text:SetFont(bdCore.media.font,config.fontsize,"OUTLINE")
		frame.text:SetText("")
	end
	
	if (not frame.icon) then
		frame.icon = frame:CreateTexture(nil, "ARTWORK")
		frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		frame.icon:SetDrawLayer('ARTWORK')
		frame.icon:SetTexture("")
		frame.icon:SetSize(frameheight-8, frameheight-8)
	end
	
	if (not frame.icon.bg) then
		frame.icon.bg = frame:CreateTexture(nil, "BORDER")
		frame.icon.bg:SetTexture(media.flat)
		frame.icon.bg:Hide()
		frame.icon.bg:SetVertexColor(0,0,0,1)
		frame.icon.bg:SetPoint("TOPLEFT", frame.icon, "TOPLEFT", -2, 2)
		frame.icon.bg:SetPoint("BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", 2, -2)
	end
	
	frame:SetAlpha(1)
	frame:Show()
	frame.delay = 0
	
	return frame
end
function ReleaseFrame(frame)
	frame:Hide()
	frame.text:SetText("")
	frame.icon:SetTexture("")
	frame.icon.bg:Hide()
	frame:SetParent(nil)
	frame:ClearAllPoints()
	frame.icon:ClearAllPoints()
	frame.text:ClearAllPoints()
	frame.text:SetFont(bdCore.media.font,config.fontsize,"OUTLINE")
	frame.delay = 0
	table.insert(frame_cache, frame)
end

local function round(num)
	return math.floor((num*2)+.5)/2
end

local function countTable(t)
	local count = 0
	for k, v in pairs(t) do
		count = count + 1
	end
	
	return count
end

function format_int(number)
	local i, j, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
	int = int:reverse():gsub("(%d%d%d)", "%1,")
	return minus .. int:reverse():gsub("^,", "") .. fraction
end

local grid = {}
for i = 1, 20 do grid[i] = false; end
local function firstAvailable()
	row = nil
	for i = 1, 20 do 
		if (grid[i] == false) then
			row = i
		end
		break
	end
	
	return row
end

local last_outgoing_frame = nil;
local function sendOutgoing(num,info,parent)
	local frame = GetFrame(parent)
	local first = unpack(info)
	local timeStamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21 = unpack(first)
	
	local extra = {}
	extra.icon = nil
	extra.dmg = 0
	local dmgarg
		
	if (string.find(event, "ABSORBED")) then
		extra.dmg = arg19 or 0
		extra.crit = arg18 or false
		dmgarg = 19
	end
	if (string.find(event, "SWING")) then
		extra.dmg = arg12 or 0
		extra.blocked = arg16 or 0
		extra.absorb = arg17 or 0
		extra.crit = arg18 or false
		dmgarg = 12
	elseif (string.find(event, "DAMAGE")) then
		extra.spellid = arg12 or 0
		extra.dmg = arg15 or 0
		extra.absorb = arg20 or 0
		extra.resisted = arg18 or 0
		extra.crit = arg21 or false
		extra.school = arg17 or false
		dmgarg = 15
	elseif (string.find(event, "HEAL")) then
		extra.spellid = arg12 or 0
		extra.dmg = arg15 or 0
		extra.absorb = arg17 or 0
		extra.crit = arg18 or false
		dmgarg = 15
	end
	
	if (extra.school) then
		local r = COMBATLOG_DEFAULT_COLORS.schoolColoring[extra.school].r
		local g = COMBATLOG_DEFAULT_COLORS.schoolColoring[extra.school].g
		local b = COMBATLOG_DEFAULT_COLORS.schoolColoring[extra.school].b
		frame.text:SetTextColor(r, g, b)
	elseif (string.find(event,"HEAL")) then
		frame.text:SetTextColor(0,1,0)
	else
		frame.text:SetTextColor(1,1,1)
	end
	--[[
	if (info) then
		for k, v in pairs(info) do
			--local timeStamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21 = unpack(v)
			if (dmgarg) then
				extra.dmg = extra.dmg + select(dmgarg, v)
			end
			--print(arg12)
		end
	end
	--]]
	
	if (tonumber(extra.dmg) and tonumber(extra.dmg) > 0) then
		if (info) then
			for k, v in pairs(info) do
				--local timeStamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21 = unpack(v)
				if (dmgarg) then
					extra.dmg = extra.dmg + select(dmgarg, unpack(v))
				end
				--print(arg12)
			end
		end
	
	
		if (parent == outgoing) then
			frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
			frame.text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(frameheight+2), 4)
			frame.icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 4)
		else
			frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
			frame.text:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (frameheight+2), 4)
			frame.icon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 4)
		end
		
		extra.dmg = numberize(extra.dmg)
		local text = extra.dmg
			
		if (num > 1) then
			text = text.." (x"..num..")"
		end
		frame.text:SetText(text)
		
		if (extra.spellid) then
			local name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange = GetSpellInfo(extra.spellid)
			frame.icon.bg:Show()
			frame.icon:SetTexture(icon)
		end
		if (extra.crit) then
			frame.text:SetFont(bdCore.media.font,config.fontsize+2,"OUTLINE")
		end
		if (parent == outgoing) then
			table.insert(outgoing_entries, frame)		
		else
			table.insert(incoming_entries, frame)		
		end
		last_outgoing_frame = frame
	end
	
end

local addon = CreateFrame("frame",nil,UIParent)
local animator = CreateFrame("frame",nil,UIParent)
addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
addon:SetScript("OnEvent", function(self, event, ...)
	local spellId = select(12, ...) or 0
	local event = select(2, ...) or 0
	local sourceName = select(5, ...) or 0
	local destName = select(9, ...) or 0
		
	local group = spellId..":"..event
	
	if (sourceName == player or destName == player) then
		data[group] = data[group] or {}
		table.insert(data[group], {...})
	end
end)

local a_total = 0
animator:SetScript("OnUpdate", function(self, elapsed)
	a_total = a_total + elapsed
	if (a_total > 0.01) then
		a_total = 0
		
		for k, frame in pairs(outgoing_entries) do
			frame.delay = frame.delay + elapsed
			if (frame.delay > 1.5) then
				frame:SetAlpha(frame:GetAlpha()-0.02)
			end
			if (frame:GetAlpha() == 0) then
				outgoing_entries[k] = nil
				ReleaseFrame(frame)
			end
		end
		
		for k, frame in pairs(incoming_entries) do
			frame.delay = frame.delay + elapsed
			if (frame.delay > 1.5) then
				frame:SetAlpha(frame:GetAlpha()-0.02)
			end
			if (frame:GetAlpha() == 0) then
				incoming_entries[k] = nil
				ReleaseFrame(frame)
			end
		end
	end
	
	local lastframe = nil
	local level = 1
	for k, v in pairs(outgoing_entries) do
		v:SetFrameLevel(level)
		local alpha = v:GetAlpha() > .33 and 1 or v:GetAlpha() * 3.3
		v:SetHeight(v:GetHeight()*alpha)
		if (lastframe) then
			v:SetPoint("BOTTOMRIGHT", lastframe, "TOPRIGHT", 0, 0)
		else
			v:SetPoint("BOTTOMRIGHT", outgoing, "BOTTOMRIGHT", 0, 0)
		end
		lastframe = v
		level = level + 1
	end
	
	local lastframe = nil
	local level = 1
	for k, v in pairs(incoming_entries) do
		v:SetFrameLevel(level)
		local alpha = v:GetAlpha() > .33 and 1 or v:GetAlpha() * 3.3
		v:SetHeight(v:GetHeight()*alpha)
		if (lastframe) then
			v:SetPoint("BOTTOMLEFT", lastframe, "TOPLEFT", 0, 0)
		else
			v:SetPoint("BOTTOMLEFT", incoming, "BOTTOMLEFT", 0, 0)
		end
		lastframe = v
		level = level + 1
	end
	
end)
local total = 0
addon:SetScript("OnUpdate", function(self, elapsed)
	total = total + elapsed
	if total >= .75 then	
		total = 0;
		
		if (countTable(data) > 0) then			
			for group, info in pairs(data) do
				local num = countTable(info)
				local first = info[1]
				local timeStamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21 = unpack(first)
				
				if (destName == player) then
					-- incoming
					sendOutgoing(num,info,incoming)
				end				
				if (sourceName == player) then
					-- outgoing
					sendOutgoing(num,info,outgoing)
				end				
				data[group] = nil

			end
		end

	end
end)
	
	