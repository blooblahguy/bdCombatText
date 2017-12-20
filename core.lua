local addon, bdct = ...
local config = bdCore.config.profile['Combat Text']

SetCVar("floatingCombatTextCombatDamage", 1)
SetCVar("floatingCombatTextCombatHealing", 0)

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
out_events["SPELL_DAMAGE"] = true
out_events['SWING_DAMAGE'] = true
out_events['RANGE_DAMAGE'] = true
out_events["_MISSED"] = true
--out_events["_DRAIN"] = true
--out_events["_LEECH"] = true

local alerts_events = {}
--alerts_events["_AURA_APPLIED"] = true
--alerts_events["_AURA_REMOVED"] = true
--alerts_events["_DURABILITY_DAMAGE"] = true


function bdct:callback()
	if (config.hideautos) then
		out_events['SWING_DAMAGE'] = nil
		out_events['RANGE_DAMAGE'] = true
	end
end

bdct:callback()

LoadAddOn("Blizzard_CombatLog")
local schoolColors = COMBATLOG_DEFAULT_COLORS.schoolColoring
-- ok lets parse the combat log and sort things into incoming frame and outgoing frame
bdct.combat_parser = CreateFrame("frame", nil)
bdct.combat_parser:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
bdct.combat_parser:SetScript("OnEvent", function(self, event, ...)
	local subevent = select(2, ...)
	local sourceGUID = select(4, ...)
	local sourceFlags = select(6, ...)
	local destGUID = select(8, ...)
	local destFlags = select(10, ...)
	local allow = false
	local incoming = false
	local outgoing = false
	local isevent = false
	local source = false
	local dest = false
	-- if this isn't on or from the player then we don't care about it


	if (CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_ME) or 
	CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_MINE) or
	CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_MY_PET)) then
		source = true
	end

	if (CombatLog_Object_IsA(destFlags, COMBATLOG_FILTER_ME) or 
	CombatLog_Object_IsA(destFlags, COMBATLOG_FILTER_MINE) or
	CombatLog_Object_IsA(destFlags, COMBATLOG_FILTER_MY_PET)) then
		dest = true
	end

	if (not source and not dest) then
		--print('failing cuz not mine', ...)
		return
	end
	

	-- filter out events that don't match here
	for k, v in pairs(inc_events) do
		if (incoming) then break end
		if (string.find(subevent, k)) then
			allow = true
			incoming = true
			break
		end
	end
	for k, v in pairs(out_events) do
		if (outgoing) then break end
		--print(string.find(subevent, k), subevent, k)
		if (string.find(subevent, k)) then
			allow = true
			outgoing = true
			break
		end
	end
	for k, v in pairs(alerts_events) do
		if (isevent) then break end
		if (string.find(subevent, k)) then
			allow = true
			isevent = true
			break
		end
	end
	
	if (not allow) then return end

	-- now lets collect the vars
	local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, arg15, arg16, arg17, arg18, arg19, arg20, arg21, arg22, arg23, arg24 = ...

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
	data.timestamp = timestamp

	--if (not spellID) then return end

	-- parse out all events, then add to the correct table for animating
	if (string.find(subevent, "_DAMAGE")) then
		data.amount = arg15 or 0
		data.over = arg16 or 0
		if (arg21) then arg21 = 1 else arg21 = 0 end
		-- if (arg23) then arg23 = 1 else arg23 = 0 end crushing
		data.crit = data.crit + arg21	
		data.school = spellSchool or arg17 or false
		--data.less = data.less + (arg18 or 0)
		--data.less = data.less + (arg19 or 0)
		data.less = data.less + (arg20 or 0)
		--data.less = data.less + (arg22 or 0)

		if (subevent == "SWING_DAMAGE") then
			data.amount = spellID or 0
			data.spellID = 6603 -- auto attack spell			
		end
		data.prefix = "damage"
	elseif (string.find(subevent, "_MISSED")) then
		data.amount = 0
		data.school = arg15 or false

		data.prefix = "miss"
	elseif (string.find(subevent, "_HEAL")) then
		data.amount = arg15 or 0
		data.over = arg16 or 0
		if (arg18) then arg18 = 1 else arg18 = 0 end
		data.crit = arg18 or 0
		data.less = data.less + arg17
		data.school = spellSchool or false

		data.prefix = "heal"
	elseif (string.find(subevent, "_DRAIN") or string.find(subevent, "_LEECH")) then
		data.amount = arg15 or arg17 or 0
		data.school = arg16 or 0

		data.prefix = "heal"
	end

	if (data.amount > 0) then
		-- outgoing with player source and whitelisted event

		--print("post parse", sourceName, subevent)
		if (source and outgoing) then
			if (not data_out[data.prefix..':'..data.spellID]) then
				data_out[data.prefix..':'..data.spellID] = {}
			end
			table.insert(data_out[data.prefix..':'..data.spellID], data)
		end

		-- incoming with player destination and whitelisted event
		if (dest and incoming) then
			if (not data_inc[data.prefix..':'..data.spellID]) then
				data_inc[data.prefix..':'..data.spellID] = {}
			end
			table.insert(data_inc[data.prefix..':'..data.spellID], data)
		end
	end

	-- event with whitelisted event
	--[[if (isevent) then
		if (not data_alerts[data.prefix..':'..data.spellID]) then
			data_alerts[data.prefix..':'..data.spellID] = {}
		end
		data_alerts[data.prefix..':'..data.spellID][timestamp] = data
	end--]]
end)

-- now lets parse out the entires in each array and then clear the tables for more grouping
--[[local schoolColoring = {
	[SCHOOL_MASK_NONE]	= {a=1.0,r=1.00,g=1.00,b=1.00};
	[SCHOOL_MASK_PHYSICAL]	= {a=1.0,r=1.00,g=1.00,b=0.00};
	[SCHOOL_MASK_HOLY] 	= {a=1.0,r=1.00,g=0.90,b=0.50};
	[SCHOOL_MASK_FIRE] 	= {a=1.0,r=1.00,g=0.50,b=0.00};
	[SCHOOL_MASK_NATURE] 	= {a=1.0,r=0.30,g=1.00,b=0.30};
	[SCHOOL_MASK_FROST] 	= {a=1.0,r=0.50,g=1.00,b=1.00};
	[SCHOOL_MASK_SHADOW] 	= {a=1.0,r=0.50,g=0.50,b=1.00};
	[SCHOOL_MASK_ARCANE] 	= {a=1.0,r=1.00,g=0.50,b=1.00};
};--]]
bdct.data_parser = CreateFrame("frame", nil, UIParent)
bdct.data_parser.inctotal = 0
bdct.data_parser.outtotal = 0
bdct.data_parser:SetScript("OnUpdate", function(self, elapsed)
	self.inctotal = self.inctotal + elapsed
	self.outtotal = self.outtotal + elapsed

	-- outgoing
	if (self.outtotal >= config.outgoingupdate) then
		self.outtotal = 0
		local full_data = data_out -- this is what we'll loop
		data_out = {} -- clear so that addon can compile new data

		for prefixspellID, entries in pairs(full_data) do
			local amount = 0 -- highest number amount
			local crit = 0 -- true or false for critical hit
			local count = 0 --bdct:countTable(entries) -- number of hits
			local less = 0 -- blocks, absorbs, resists
			local over = 0 -- overkill, overheal
			local school = false -- school, powertype
			local timestamp = 0
			local colors = {a=1, r=1, g=1, b=1}
			local prefix, spellID = strsplit(":", prefixspellID)

			for k, data in pairs(entries) do
				amount = amount + data.amount
				crit = crit + data.crit
				less = less + data.less
				over = over + data.over
				count = count + 1
				if (not school and data.school and schoolColors[data.school]) then
					school = data.school
					print('school', data.school)
					print(schoolColors[data.school], unpack(schoolColors[data.school]))
					colors = unpack(schoolColors[data.school])
				end
			end

			

			-- colors to hex so we can color the font string a bunch
			local hex = bdct:RGBPercToHex(colors.r, colors.g, colors.b)

			-- compile display
			local name = select(1, GetSpellInfo(spellID))
			--if (name == "Leech" ) then print(spellID) end 143924
			local icon = select(3, GetSpellInfo(spellID))
			local text = ""

			-- add additional text info
			if (count > 1 or crit > 1 or less > 0) then
				text = text.." ("
				if (count > 1) then
					text = text.."x"..count..", "
				end
				if (crit > 1) then
					text = text.."!"..crit..", "
				end
				if (less > 0) then
					text = text.."<|cff777777"..less.."|r, "
				end
				text = strsub(text, 0, -3) -- trim the last comma
				text = text..") " -- close the parentheses
			end
			text = text.." |cff"..hex..bdct:numberize(amount).."|r"

			-- some threshold to determine if we show this as a crit
			local showcrit = false
			if (crit > 0) then
				showcrit = count / crit > .5 or false
			end

			bdct:animate(bdct.outgoing, timestamp, icon, text, showcrit)
			--outgoing_animate[timestamp] = {frame, icon, text, showascrit}
			-- based on options, we should animate these onto a nameplate if possible, or just always our anchor frames
		end

	end

	-- incoming
	if (self.inctotal >= config.incomingupdate) then
		self.inctotal = 0

		local full_data = data_inc -- this is what we'll loop
		data_inc = {} -- clear so that addon can compile new data

		for prefixspellID, entries in pairs(full_data) do
			local amount = 0 -- highest number amount
			local crit = 0 -- true or false for critical hit
			local count = 0 --bdct:countTable(entries) -- number of hits
			local less = 0 -- blocks, absorbs, resists
			local over = 0 -- overkill, overheal
			local school = false -- school, powertype
			local timestamp = 0
			local colors = {a=1, r=1, g=1, b=1}
			local prefix, spellID = strsplit(":", prefixspellID)

			for k, data in pairs(entries) do
				amount = amount + data.amount
				crit = crit + data.crit
				less = less + data.less
				over = over + data.over
				count = count + 1
				--[[if (not school and data.school and #schoolColoring[data.school]) then
					school = data.school
					print('school', data.school)
					print(schoolColoring[data.school]. unpack(schoolColoring[data.school]))
					colors = unpack(schoolColoring[data.school])
				end--]]
			end

			

			-- colors to hex so we can color the font string a bunch
			local hex = bdct:RGBPercToHex(colors.r, colors.g, colors.b)

			-- compile display
			local name = select(1, GetSpellInfo(spellID))
			--if (name == "Leech" ) then print(spellID) end 143924
			local icon = select(3, GetSpellInfo(spellID))
			local text = ""

			-- add additional text info
			if (count > 1 or crit > 1 or less > 0) then
				text = text.." ("
				if (count > 1) then
					text = text.."x"..count..", "
				end
				if (crit > 1) then
					text = text.."!"..crit..", "
				end
				if (less > 0) then
					text = text.."<|cff777777"..less.."|r, "
				end
				text = strsub(text, 0, -3) -- trim the last comma
				text = text..") " -- close the parentheses
			end
			text = text.." |cff"..hex..bdct:numberize(amount).."|r"

			-- some threshold to determine if we show this as a crit
			local showcrit = false
			if (crit > 0) then
				showcrit = count / crit > .5 or false
			end

			bdct:animate(bdct.incoming, timestamp, icon, text, showcrit)
		end
	end

	-- process alerts immediately

end)

local outgoing_animate = {}
local incoming_animate = {}
local alerts_animate = {}

function bdct:animate(parent, timestamp, icon, text, showcrit)
	-- pull a frame and lets do what we know needs to be done
	local frame = GetFrame(parent)

	local frameheight = 10+config.outgoingfontsize

	frame.text:SetText(text)
	frame.icon:SetTexture(icon)
	frame.icon.bg:Show()

	-- position depending on frame
	if (parent == bdct.outgoing) then
		--frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
		
		if (showcrit) then
			frame.text:SetFont(bdCore.media.font, config.outgoingcritfontsize, "THINOUTLINE")
			frame.crit = true
		else
			frame.text:SetFont(bdCore.media.font, config.outgoingfontsize, "THINOUTLINE")
			frame.crit = false
		end

		frame.text:SetPoint("RIGHT", frame, "RIGHT", -(frameheight+2), 0)
		frame.icon:SetPoint("RIGHT", frame, "RIGHT", -6, 0)

		table.insert(outgoing_animate, frame)	
	elseif (parent == bdct.incoming) then
		--frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
		frame.text:SetPoint("LEFT", frame, "LEFT", (frameheight+2), 0)
		frame.icon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 4)

		table.insert(incoming_animate, frame)	
	elseif (parent == bdct.alerts) then

	end

	bdct.animator:main()
end

bdct.animator = CreateFrame("frame", nil, UIParent)
bdct.animator.total = 0
function bdct.animator:main(elapsed)
	if (not elapsed) then elapsed = 0 end
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

	-- incoming
	for k, frame in pairs(incoming_animate) do
		-- start fading alpha after given delay
		frame.delay = frame.delay + elapsed
		if (frame.delay > 1.5) then
			frame:SetAlpha(frame:GetAlpha()-0.02)
		end
		-- once alpha hits 0 we're done, return the frame
		if (frame:GetAlpha() == 0) then
			incoming_animate[k] = nil
			ReleaseFrame(frame)
		end
	end

	-- alerts
	--[[for k, frame in pairs(alerts_animate) do
		-- start fading alpha after given delay
		frame.delay = frame.delay + elapsed
		if (frame.delay > 1.5) then
			frame:SetAlpha(frame:GetAlpha()-0.02)
		end
		-- once alpha hits 0 we're done, return the frame
		if (frame:GetAlpha() == 0) then
			alerts_animate[k] = nil
			ReleaseFrame(frame)
		end
	end--]]

	-----------------------------------------
	-- animate position of frames and height
	-----------------------------------------
	-- outgoing
	local lastframe = nil
	local level = 1

	for k, v in pairs(outgoing_animate) do
		v:SetFrameLevel(level)
		v:ClearAllPoints()

		-- this is the animation
		local alpha = v:GetAlpha() > .5 and 1 or v:GetAlpha() * 2
		v:SetHeight(v:GetHeight()*alpha)

		if (lastframe) then
			v:SetPoint("BOTTOMRIGHT", lastframe, "TOPRIGHT", 0, 0)
		else
			v:SetPoint("BOTTOMRIGHT", bdct.outgoing, "BOTTOMRIGHT", 0, 0)
		end
		lastframe = v
		level = level + 1
	end

	-- incoming
	local lastframe = nil
	local level = 1
	for k, v in pairs(incoming_animate) do
		v:SetFrameLevel(level)
		local alpha = v:GetAlpha() > .33 and 1 or v:GetAlpha() * 3.3
		v:SetHeight(v:GetHeight()*alpha)
		if (lastframe) then
			v:SetPoint("BOTTOMLEFT", lastframe, "TOPLEFT", 0, 0)
		else
			v:SetPoint("BOTTOMLEFT", bdct.incoming, "BOTTOMLEFT", 0, 0)
		end
		lastframe = v
		level = level + 1
	end
end
bdct.animator:SetScript("OnUpdate", function(self, elapsed)
	self.total = self.total + elapsed

	-------------------------
	-- animate alpha (30fps)
	-------------------------
	-- outgoing
	if (self.total > 0.033) then
		self.total = 0
		bdct.animator:main(elapsed)
	end
end)

	