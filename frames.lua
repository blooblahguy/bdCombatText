local addon, bdct = ...
local config = bdCore.config.profile['Combat Text']

bdct.incoming =  CreateFrame('frame', "bdCT_Incoming", UIParent)
bdct.incoming:SetPoint("CENTER", UIParent, "CENTER", -500, 0)
bdct.incoming:SetSize(200, 300)
bdct.incoming:SetFrameStrata("TOOLTIP")
bdCore:makeMovable(bdct.incoming)

bdct.outgoing = CreateFrame('frame', "bdCT_Outgoing", UIParent)
bdct.outgoing:SetPoint("CENTER", UIParent, "CENTER", 500, 0)
bdct.outgoing:SetSize(200, 300)
bdct.outgoing:SetFrameStrata("TOOLTIP")
bdCore:makeMovable(bdct.outgoing)

bdct.alerts = CreateFrame('frame', "bdCT_Alerts", UIParent)
bdct.alerts:SetPoint("CENTER", UIParent, "CENTER", 0, -500)
bdct.alerts:SetSize(200, 300)
bdct.alerts:SetFrameStrata("TOOLTIP")
bdCore:makeMovable(bdct.alerts)

-- we're going to do dynamic frame creating/releasing so that we don't have a big memory sink
local frame_cache = {}
local data = {}
local outgoing_entries = {}
local incoming_entries = {}
function GetFrame(parent)
	local frame = table.remove(frame_cache) or CreateFrame("Frame", nil, UIParent)
	frame:SetParent(parent)

	local frameheight = 10+config.outgoingfontsize
	
	frame:SetSize(200, frameheight)
	
	if (not frame.text) then
		frame.text = frame:CreateFontString("amount")
	end

	if (parent == bdct.outgoing) then
		frame.text:SetFont(bdCore.media.font, config.outgoingfontsize, "OUTLINE")
	elseif (parent == bdct.incoming) then
		frame.text:SetFont(bdCore.media.font, config.incomingfontsize, "OUTLINE")
	elseif (parent == bdct.alerts) then
		frame.text:SetFont(bdCore.media.font, config.alertsfontsize, "OUTLINE")
	end
	frame.text:SetText("")
	
	if (not frame.icon) then
		frame.icon = frame:CreateTexture(nil, "ARTWORK")
		frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		frame.icon:SetDrawLayer('ARTWORK')
		frame.icon:SetTexture("")
		frame.icon:SetSize(frameheight-8, frameheight-8)
	end
	
	if (not frame.icon.bg) then
		frame.icon.bg = frame:CreateTexture(nil, "BORDER")
		frame.icon.bg:SetTexture(bdCore.media.flat)
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
	frame.delay = 0
	
	table.insert(frame_cache, frame)
end


