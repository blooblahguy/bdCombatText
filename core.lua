local addon, bdct = ...
local config = bdCore.config.profile['Combat Text']

function bdct:callback()

end

SetCVar("floatingCombatTextCombatDamage", 1)
SetCVar("floatingCombatTextCombatHealing", 0)
local schoolColors = COMBATLOG_DEFAULT_COLORS.schoolColoring

-- here are our arrays
local data_out = {}
--[[ ex
	data_out[spellID]
		.crit
		.less
		.amount
		.data[]
			...
--]]
local data_inc = {}
local data_alerts = {}

-- whitelist some events for each frame
local inc_events = {}
inc_events["_HEAL"] = true
inc_events["_DAMAGE"] = true

local out_events = {}
out_events["_HEAL"] = true
out_events["_DAMAGE"] = true
out_events["_MISSED"] = true
out_events["_DRAIN"] = true
out_events["_LEECH"] = true

local alerts_events = {}
alerts_events["_AURA_APPLIED"] = true
alerts_events["_AURA_REMOVED"] = true
alerts_events["_DURABILITY_DAMAGE"] = true


-- ok lets parse the combat log and sort things into incoming frame and outgoing frame
bdct.combat_parser = CreateFrame("frame", nil)
bdct.combat_parser:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
bdct.combat_parser:SetScript("OnEvent", function(self, event, ...)
	local subevent = select(2, ...)
	local sourceName = select(5, ...)
	local destName = select(9, ...)
	local allow = false
	local incoming = false
	local outgoing = false
	local isevent = false

	-- if this isn't on or from the player then we don't care about it
	if (not (UnitExists(sourceName) and UnitIsUnit(sourceName, "player")) and not (UnitExists(destName) and UnitIsUnit(destName, "player"))) then return end

	-- filter out events that don't match here
	for k, v in pairs(inc_events) do
		if (allow) then break end
		if (string.find(subevent, k)) then
			allow = true
			incoming = true
			break
		end
	end
	for k, v in pairs(inc_events) do
		if (allow) then break end
		if (string.find(subevent, k)) then
			allow = true
			outgoing = true
			break
		end
	end
	for k, v in pairs(alerts_events) do
		if (allow) then break end
		if (string.find(subevent, k)) then
			allow = true
			isevent = true
			break
		end
	end
	
	if (not allow) then return end

	-- now lets collect the vars
	local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, arg15, arg16, arg17, arg18, arg19, arg20, arg21, arg22, arg23, arg24 = ...

	print(...)

	-- we'll consistently pass the same data for ease
	local data = {}
	data.amount = 0 -- highest number amount
	data.crit = 0 -- #s of crits
	data.less = 0 -- blocks, absorbs, resists
	data.over = 0 -- overkill, overheal
	data.school = false -- school, powertype
	data.prefix = '' -- prefix so we don't group dmg with misses etc
	data.spellID = spellID -- to reference if needed
	data.subevent = subevent -- to reference if needed

	-- parse out all events, then add to the correct table for animating
	if (string.find(subevent, "_DAMAGE")) then
		data.amount = arg15 or 0
		data.over = arg16 or 0
		data.crit = data.crit + (arg21 or 0)
		data.crit = data.crit + (arg23 or 0)
		data.school = spellSchool or arg17 or false
		data.less = data.less + arg18
		data.less = data.less + arg19
		data.less = data.less + arg20
		data.less = data.less + arg22

		data.prefix = "damage"
	elseif (string.find(subevent, "_MISSED"))
		data.amount = 0
		data.school = arg15 or false

		data.prefix = "miss"
	elseif (string.find(subevent, "_HEAL"))
		data.amount = arg15 or 0
		data.over = arg16 or 0
		data.crit = arg18 or 0
		data.less = data.less + arg17
		data.school = spellSchool or false

		data.prefix = "heal"
	elseif (string.find(subevent, "_DRAIN") or string.find(subevent, "_LEECH"))
		data.amount = arg15 or arg17 or 0
		data.school = arg16 or 0

		data.prefix = "heal"
	end

	-- outgoing with player source and whitelisted event
	if (UnitIsUnit(sourceName, "player") and outgoing) then
		if (not data_out[data.prefix..':'..data.spellID]) then
			data_out[data.prefix..':'..data.spellID] = {}
			data_out[data.prefix..':'..data.spellID][timestamp] = data
		end
	end

	-- incoming with player destination and whitelisted event
	if (UnitIsUnit(destName, "player") and incoming) then
		if (not data_inc[data.prefix..':'..data.spellID]) then
			data_inc[data.prefix..':'..data.spellID] = {}
			data_inc[data.prefix..':'..data.spellID][timestamp] = data
		end
	end

	-- event with whitelisted event
	if (isevent) then
		if (not data_alerts[data.prefix..':'..data.spellID]) then
			data_alerts[data.prefix..':'..data.spellID] = {}
		end
		data_alerts[data.prefix..':'..data.spellID][timestamp] = data
	end
end)

-- now lets parse out the entires in each array and then clear the tables for more grouping
bdct.data_parser = CreateFrame("frame", nil, UIParent)
bdct.data_parser.inctotal = 0
bdct.data_parser.outtotal = 0
bdct.data_parser:SetScript("OnUpdate", function(self, elapsed)
	self.inctotal = self.inctotal + elapsed
	self.outtotal = self.outtotal + elapsed
	self.eventtotal = self.eventtotal + elapsed

	-- outgoing
	if (self.outtotal >= config.outgoingupdate) then
		self.outtotal = 0
		local full_data = data_out -- this is what we'll loop
		data_out = {} -- clear so that addon can compile new data

		for spellID, entries in pairs(full_data) do
			local amount = 0 -- highest number amount
			local crit = 0 -- true or false for critical hit
			local number = #entries -- number of hits
			local less = 0 -- blocks, absorbs, resists
			local over = 0 -- overkill, overheal
			local school = false -- school, powertype
			local timestamp = 0
			local colors = {a=1, r=1, g=1, b=1}

			for timestamp, data in pairs(entries) do
				amount = amount + data.amount
				crit = crit + data.crit
				less = less + data.less
				over = over + data.over
				if (not school) then
					school = data.school
					colors = unpack(schoolColors[data.school])
				end
			end

			-- colors to hex so we can color the font string a bunch
			local hex = bdct:RGBPercToHex(colors.r, colors.g, colors.b)

			-- compile display
			local icon = select(3, GetSpellInfo(spellID))
			local text = "|cff"..hex..bdct:numberize(amount).."|r"

			-- add additional text info
			if (number > 1 or crit > 0 or less > 0) then
				text = text.." ("
				if (num > 0) then
					text = text.."x"..num..", "
				end
				if (crit > 0) then
					text = text.."!"..crit..", "
				end
				if (less > 0) then
					text = text.."<|cff777777"..less.."|r, "
				end
				text = substr(text, 0, -2) -- trim the last comma
				text = text..")" -- close the parentheses
			end

			-- some threshold to determine if we show this as a crit
			local showcrit = false
			if (crit > 0) then
				showcrit = number / crit > .5 or false
			end

			bdct:animate(bdct.outgoing, timestamp, icon, text, showascrit)
			--outgoing_animate[timestamp] = {frame, icon, text, showascrit}
			-- based on options, we should animate these onto a nameplate if possible, or just always our anchor frames
		end

	end

	-- incoming
	if (self.inctotal >= config.incomingupdate) then
		self.inctotal = 0

		local full_data = data_inc -- this is what we'll loop
		data_inc = {} -- clear so that addon can compile new data

		--[[for spellID, entries in pairs(full_data) do
			local amount = 0 -- highest number amount
			local crit = 0 -- true or false for critical hit
			local number = #entries -- number of hits
			local less = 0 -- blocks, absorbs, resists
			local over = 0 -- overkill, overheal
			local school = false -- school, powertype

			for timestamp, data in pairs(entries) do
				amount = amount + data.amount
				crit = crit + data.crit
				less = less + data.less
				over = over + data.over
				if (not school) then
					school = data.school
				end
			end

			-- compile display
			local icon = select(3, GetSpellInfo(spellID))
			local text = amount

			if (number > 1 or crit > 0 or less > 0) then
				text = text.." ("
				if (num > 0) then
					text = text.."x"..num.." , "
				end
				if (crit > 0) then
					text = text.."!"..crit.." , "
				end
				if (less > 0) then
					text = text.."<"..crit.." , "
				end
				text = substr(text, 0, -3)
				text = text..")"
			end

			local showascrit = number / crit > .50 or false
			-- outgoing_animate(frame, icon, text, showascrit)
			-- based on options, we should animate these onto a nameplate if possible, or just always our anchor frames
		end--]]
	end

	-- process alerts immediately

end)

local outgoing_animate = {}
local incoming_animate = {}
local alerts_animate = {}

function bdct:animate(parent, timestamp, icon, text, showcrit)
	-- pull a frame and lets do what we know needs to be done
	local frame = GetFrame(parent)

	frame.text:SetText(text)
	frame.icon:SetTexture(icon)
	frame.icon.bg:Show()

	-- position depending on frame
	if (parent == bdct.outgoing) then
		frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
		frame.text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(frameheight+2), 4)
		frame.icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 4)

		table.insert(outgoing_animate, frame)	
	elseif (parent == bdct.incoming) then
		frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
		frame.text:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (frameheight+2), 4)
		frame.icon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 4)

		table.insert(incoming_animate, frame)	
	elseif (parent == bdct.alerts) then

	end
end

bdct.animator = CreateFrame("frame", nil, UIParent)
bdct.animator.total = 0
bdct.animator:SetScript("OnUpdate", function(self, elasped)
	self.total = self.total + elapsed

	-------------------------
	-- animate alpha (20fps)
	-------------------------
	-- outgoing
	if (self.total > 0.05) then
		self.total = 0
		for k, frame in pairs(outgoing_animate) do
			-- start fading alpha after given delay
			frame.delay = frame.delay + elapsed
			if (frame.delay > 1.5) then
				frame:SetAlpha(frame:GetAlpha()-0.02)
			end
			-- once alpha hits 0 we're done, return the frame
			if (frame:GetAlpha() == 0) then
				outgoing_animate[k] = nil
				ReleaseFrame(frame)
			end
		end

		-- inomcing
		for k, frame in pairs(incoming_animate) do
			-- start fading alpha after given delay
			frame.delay = frame.delay + elapsed
			if (frame.delay > 1.5) then
				frame:SetAlpha(frame:GetAlpha()-0.02)
			end
			-- once alpha hits 0 we're done, return the frame
			if (frame:GetAlpha() == 0) then
				outgoing_animate[k] = nil
				ReleaseFrame(frame)
			end
		end

		-- alerts
		for k, frame in pairs(alerts_animate) do
			-- start fading alpha after given delay
			frame.delay = frame.delay + elapsed
			if (frame.delay > 1.5) then
				frame:SetAlpha(frame:GetAlpha()-0.02)
			end
			-- once alpha hits 0 we're done, return the frame
			if (frame:GetAlpha() == 0) then
				outgoing_animate[k] = nil
				ReleaseFrame(frame)
			end
		end
	end

	-----------------------------------------
	-- animate position of frames and height
	-----------------------------------------
	-- outgoing
	local lastframe = nil
	local level = 1
	for k, v in pairs(outgoing_animate) do
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

	-- inomcing
	local lastframe = nil
	local level = 1
	for k, v in pairs(incoming_animate) do
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

	