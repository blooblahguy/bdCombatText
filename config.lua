local media = {
	flat = "Interface\\Buttons\\WHITE8x8",
	font = "fonts\\ARIALN.ttf"
}

local defaults = {}
------------------------
-- general
------------------------

------------------------
-- colors
------------------------
defaults[#defaults] = {tab = {
	type = "tab",
	value = "Colors"
}}
-- damage color
-- damage color by school
-- crit color
-- less color
-- healing color
-- healing color by school

------------------------
-- outgoing
------------------------
defaults[#defaults] = {tab = {
	type = "tab",
	value = "Outgoing"
}}
defaults[#defaults] = {outgoingupdate = {
	type = "slider",
	value = 2,
	min = 0.1,
	max = 5,
	step = 0.1,
	label = "Outgoing frame update threshold",
	callback = function bdct:callback() end
}}
defaults[#defaults] = {outgoingfontsize = {
	type = "slider",
	value = 14,
	min = 6,
	max = 30,
	step = 2,
	label = "Outoing Regular Font Size",
	callback = function bdct:callback() end
}}
defaults[#defaults] = {outgoingcritfontsize = {
	type = "slider",
	value = 18,
	min = 6,
	max = 40,
	step = 2,
	label = "Outoing Crit Font Size",
	callback = function bdct:callback() end
}}
-- threshold

------------------------
-- incoming
------------------------
defaults[#defaults] = {tab = {
	type = "tab",
	value = "Incoming"
}}
defaults[#defaults] = {incomingupdate = {
	type = "slider",
	value = 1,
	min = 0.1,
	max = 5,
	step = 0.1,
	label = "Incoming frame update threshold",
	callback = function bdct:callback() end
}}
defaults[#defaults] = {incomingfontsize = {
	type = "slider",
	value = 14,
	min = 6,
	max = 30,
	step = 2,
	label = "Incoming Regular Font Size",
	callback = function bdct:callback() end
}}
defaults[#defaults] = {incomingcritfontsize = {
	type = "slider",
	value = 18,
	min = 6,
	max = 40,
	step = 2,
	label = "Incoming Crit Font Size",
	callback = function bdct:callback() end
}}

------------------------
-- alerts
------------------------
defaults[#defaults] = {tab = {
	type = "tab",
	value = "Alerts"
}}
defaults[#defaults] = {alertsfontsize = {
	type = "slider",
	value = 14,
	min = 6,
	max = 30,
	step = 2,
	label = "Alerts Font Size",
	callback = function bdct:callback() end
}}

bdCore:addModule("Combat Text", defaults)


