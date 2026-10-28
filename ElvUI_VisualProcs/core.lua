local E, L, V, P, G = unpack(ElvUI)

local LBP = LibStub("LibBlizzardProcs-1.0", true)
local LAB = LibStub("LibActionButton-1.0-ElvUI")
local EP = LibStub("LibElvUIPlugin-1.0")
local VP = E:NewModule("VisualProcs", "AceEvent-3.0")

local AddOnName = ...

local find = string.find
local pairs, ipairs = pairs, ipairs

-- State for the Custom Procs add-form
local newProcBuffID = ""
local newProcTexFile = ""
local newProcCastIDs = ""
local selectedRemoveIdx = 1
local injectedEntries = {}

-- Returns a sorted deduplicated list of all overlay texture filenames across all classes
local function GetAllTextures()
	local seen = {}
	local list = {}
	for _, textures in pairs(LBP_Data.OverlayTextures) do
		for _, data in ipairs(textures) do
			if not seen[data[2]] then
				seen[data[2]] = true
				list[#list + 1] = data[2]
			end
		end
	end
	table.sort(list)
	return list
end

P.visualProcs = {
	overlay = {
		enable = true,
		scale = 0.8,
		disableSound = false,
	},
	buttonGlow = {
		enable = true,
	},
	customProcs = {},
}

local function GetOptions()
	E.Options.args.visualProcs = {
		order = 50,
		type = "group",
		name = "|cff0070ddVisual Procs|r",
		args = {
			overlayTest = {
				order = 1,
				type = "execute",
				name = L["Show/Hide Overlay"],
				func = function(info) VP:ToggleTestFrame() end,
				disabled = function() return not (LBP.isClassSupported and E.db.visualProcs.overlay.enable) end,
			},
			spacer = {
				order = 2,
				type = "description",
				width = "full",
				name = "",
			},
			buttonGlow = {
				order = 3,
				type = "toggle",
				name = L["Button Glow"],
				get = function(info) return E.db.visualProcs.buttonGlow.enable end,
				set = function(info, value)
					E.db.visualProcs.buttonGlow.enable = value
					VP:ToggleButtonGlow()
				end,
				disabled = function() return not LBP.isClassSupported end,
			},
			overlay = {
				order = 4,
				type = "toggle",
				name = L["Overlay Frame"],
				get = function(info) return E.db.visualProcs.overlay.enable end,
				set = function(info, value)
					E.db.visualProcs.overlay.enable = value
					VP:ToggleOverlay()
				end,
				disabled = function() return not LBP.isClassSupported end,
			},
			overlayScale = {
				order = 5,
				type = "range",
				min = 0.1, max = 2, step = 0.01,
				name = L["Overlay Frame Scale"],
				get = function(info) return E.db.visualProcs.overlay.scale end,
				set = function(info, value)
					E.db.visualProcs.overlay.scale = value
					VP:UpdateOverlay()
				end,
				disabled = function() return not (LBP.isClassSupported and E.db.visualProcs.overlay.enable) end,
			},
			disableSound = {
				order = 6,
				type = "toggle",
				name = L["Disable Sound"],
				desc = L["Disable playing sound on overlay proc."],
				get = function(info) return E.db.visualProcs.overlay.disableSound end,
				set = function(info, value)
					E.db.visualProcs.overlay.disableSound = value
					VP:UpdateSettings()
				end,
				disabled = function() return not (LBP.isClassSupported and E.db.visualProcs.overlay.enable) end,
			},
			addHeader = {
				order = 7,
				type = "header",
				name = "Add New Proc",
			},
			helpText = {
				order = 8,
				type = "description",
				fontSize = "medium",
				name = "Enter the spell ID of the buff that appears on your character when the proc triggers. Optionally assign an overlay texture and action bar spells that should glow.\n\nNote: Overlay effects apply immediately. Button glow requires a UI reload (/reload).",
			},
			buffIDInput = {
				order = 9,
				type = "input",
				width = "normal",
				name = "Proc Buff Spell ID",
				desc = "The spell ID of the buff applied to your character when the proc is active.",
				get = function() return newProcBuffID end,
				set = function(_, v) newProcBuffID = v:trim() end,
			},
			textureIdxSelect = {
				order = 10,
				type = "select",
				width = "normal",
				name = "Overlay Texture",
				desc = "The edge overlay to show on screen when the proc is active. Choose 'None' for button glow only.",
				values = function()
					local t = {[""] = "None (glow only)"}
					for _, file in ipairs(GetAllTextures()) do
						t[file] = file:gsub("%.blp$", ""):gsub("_", " ")
					end
					return t
				end,
				get = function() return newProcTexFile end,
				set = function(_, v) newProcTexFile = v end,
			},
			texturePreview = {
				order = 10.5,
				type = "description",
				name = "",
				image = function()
					if newProcTexFile and newProcTexFile ~= "" then
						return LBP.mediaPath .. "overlay\\" .. newProcTexFile
					end
					return ""
				end,
				imageWidth = 128,
				imageHeight = 64,
			},
			castIDsInput = {
				order = 11,
				type = "input",
				width = "full",
				name = "Button Glow Spell IDs (optional, comma-separated)",
				desc = "Spell IDs of spells on your action bar that should glow when this proc is active. Leave empty to skip button glow.",
				get = function() return newProcCastIDs end,
				set = function(_, v) newProcCastIDs = v end,
			},
			addButton = {
				order = 12,
				type = "execute",
				name = "Add Proc",
				desc = "Adds this proc entry. Overlay effects apply immediately; button glow requires /reload.",
				func = function()
					local buffID = tonumber(newProcBuffID)
					if not buffID then return end
					for _, e in ipairs(E.db.visualProcs.customProcs) do
						if e.buffSpellID == buffID then return end
					end
					local entry = {
						buffSpellID = buffID,
						textureFile = newProcTexFile ~= "" and newProcTexFile or nil,
						castSpellIDs = {},
					}
					for idStr in newProcCastIDs:gmatch("%d+") do
						local id = tonumber(idStr)
						if id then
							entry.castSpellIDs[#entry.castSpellIDs + 1] = id
						end
					end
					E.db.visualProcs.customProcs[#E.db.visualProcs.customProcs + 1] = entry
					VP:ApplyCustomProcs()
					newProcBuffID = ""
					newProcTexFile = ""
					newProcCastIDs = ""
				end,
				disabled = function() return not LBP.isClassSupported end,
			},
			currentHeader = {
				order = 13,
				type = "header",
				name = "Current Custom Procs",
			},
			currentList = {
				order = 14,
				type = "description",
				fontSize = "medium",
				name = function()
					local entries = E.db.visualProcs.customProcs
					if #entries == 0 then return "|cff888888No custom procs added yet.|r" end
					local lines = {}
					for i, entry in ipairs(entries) do
						local buffName = GetSpellInfo(entry.buffSpellID) or "Unknown"
						local texName = "|cff888888None|r"
						if entry.textureFile then
							texName = entry.textureFile:gsub("%.blp$", ""):gsub("_", " ")
						end
						local castStr = ""
						if entry.castSpellIDs and #entry.castSpellIDs > 0 then
							local names = {}
							for _, id in ipairs(entry.castSpellIDs) do
								names[#names + 1] = (GetSpellInfo(id) or "ID:" .. id)
							end
							castStr = "\n    |cff888888Glows: " .. table.concat(names, ", ") .. "|r"
						end
						lines[#lines + 1] = string.format("|cffffff00[%d]|r %s |cff888888(ID: %d)|r  \xE2\x86\x92  %s%s", i, buffName, entry.buffSpellID, texName, castStr)
					end
					return table.concat(lines, "\n")
				end,
			},
			removeHeader = {
				order = 15,
				type = "header",
				name = "Remove Custom Proc",
			},
			removeSelect = {
				order = 16,
				type = "select",
				name = "Select Entry to Remove",
				values = function()
					local t = {}
					for i, entry in ipairs(E.db.visualProcs.customProcs) do
						t[i] = (GetSpellInfo(entry.buffSpellID) or "Unknown") .. " (ID: " .. entry.buffSpellID .. ")"
					end
					if not next(t) then t[0] = "No entries" end
					return t
				end,
				get = function()
					if #E.db.visualProcs.customProcs == 0 then return 0 end
					if not selectedRemoveIdx or selectedRemoveIdx > #E.db.visualProcs.customProcs then
						selectedRemoveIdx = 1
					end
					return selectedRemoveIdx
				end,
				set = function(_, v) selectedRemoveIdx = v end,
				disabled = function() return #E.db.visualProcs.customProcs == 0 end,
			},
			removeButton = {
				order = 17,
				type = "execute",
				name = "Remove Selected",
				func = function()
					local entries = E.db.visualProcs.customProcs
					if #entries == 0 or not selectedRemoveIdx or not entries[selectedRemoveIdx] then return end
					table.remove(entries, selectedRemoveIdx)
					if selectedRemoveIdx > #entries then
						selectedRemoveIdx = math.max(1, #entries)
					end
					VP:ApplyCustomProcs()
				end,
				disabled = function() return #E.db.visualProcs.customProcs == 0 end,
			},
		}
	}
end

local function OverlayGlowShow(self, spellID)
	if self:GetSpellId() == spellID then
		LBP:ShowOverlayGlow(self)
	end
end

local function OverlayGlowHide(self, spellID)
	if self:GetSpellId() == spellID then
		LBP:HideOverlayGlow(self)
	end
end

local function UpdateOverlayGlow(self)
	local spellID = self:GetSpellId()

	if self:HasAction() then
		if not self.eventsRegistered then
			LBP:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", self, OverlayGlowShow)
			LBP:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", self, OverlayGlowHide)
			self.eventsRegistered = true
		end

		if spellID then
			LBP:ChangeAction(self._state_action, spellID)
		end
	else
		if self.eventsRegistered then
			LBP:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", self)
			LBP:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", self)
			self.eventsRegistered = nil
		end
	end

	if spellID and LBP:IsSpellOverlayed(spellID) then
		LBP:ShowOverlayGlow(self)
	else
		LBP:HideOverlayGlow(self)
	end
end

local function OverlayShow(self, spellID, texture, positions, scale, r, g, b)
	LBP:ShowAllOverlays(self, spellID, texture, positions, scale, r, g, b)
end

local function OverlayHide(self, spellID)
	if spellID then
		LBP:HideOverlays(self, spellID)
	else
		LBP:HideAllOverlays(self)
	end
end

function VP:ToggleTestFrame()
	self.overlayFrame.test = not self.overlayFrame.test

	if self.overlayFrame.test then
		LBP:HideAllOverlays(self.overlayFrame)

		local path = LBP.mediaPath .. "overlay\\"
		local foundTop, foundLeft

		for _, data in ipairs(LBP_Data.OverlayTextures[LBP.playerClass]) do
			if not foundTop and find(data[3], "Top") then
				foundTop = true
				LBP:ShowAllOverlays(self.overlayFrame, 100000, path .. data[2], data[3], data[4], data[5], data[6], data[7])
			elseif not foundLeft and find(data[3], "Left") then
				foundLeft = true
				LBP:ShowAllOverlays(self.overlayFrame, 100001, path .. data[2], data[3], data[4], data[5], data[6], data[7])
			end

			if foundTop and foundLeft then
				break
			end
		end

		self:RegisterEvent("PLAYER_REGEN_DISABLED", "ToggleTestFrame")
	else
		LBP:HideAllOverlays(self.overlayFrame)
		self:UnregisterEvent("PLAYER_REGEN_DISABLED")
	end
end

function VP:ToggleButtonGlow()
	if not LBP.isClassSupported then return end

	LBP.disableButtonGlow = not (E.private.actionbar.enable and E.db.visualProcs.buttonGlow.enable)

	if E.private.actionbar.enable and E.db.visualProcs.buttonGlow.enable then
		LAB.RegisterCallback(LBP, "OnButtonUpdate", function(_, button)
			UpdateOverlayGlow(button)
		end)
	else
		LAB.UnregisterCallback(LBP, "OnButtonUpdate")

		LBP:DisableButtonGlows()
	end

	self:UpdateState()
end

function VP:UpdateOverlay()
	if not LBP.isClassSupported then return end

	local scale = E.db.visualProcs.overlay.scale

	LBP.overlay.sizeScale = scale
	LBP.overlay.longSide = 256 * scale
	LBP.overlay.shortSide = 128 * scale

	self.overlayFrame:SetSize(256 * scale, 256 * scale)

	for _, overlayList in pairs(LBP.overlay.inUse) do
		if overlayList then
			for i = 1, #overlayList do
				LBP:OverlayPointSize(self.overlayFrame, overlayList[i], 1)
			end
		end
	end
end

function VP:UpdateSettings()
	if not LBP.isClassSupported then return end

	LBP.disableSound = E.db.visualProcs.overlay.disableSound
end

function VP:ToggleOverlay()
	if not LBP.isClassSupported then return end

	LBP.disableOverlay = not E.db.visualProcs.overlay.enable

	if E.db.visualProcs.overlay.enable then
		LBP:RegisterEvent("SPELL_ACTIVATION_OVERLAY_SHOW", self.overlayFrame, OverlayShow)
		LBP:RegisterEvent("SPELL_ACTIVATION_OVERLAY_HIDE", self.overlayFrame, OverlayHide)
		self.overlayFrame:Show()
	else
		LBP:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_SHOW", self.overlayFrame)
		LBP:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_HIDE", self.overlayFrame)

		LBP:DisableOverlays()
		self:UnregisterAllEvents()
		self.overlayFrame.test = false
		self.overlayFrame:Hide()
	end

	self:UpdateState()
end

function VP:UpdateState()
	if LBP.disableOverlay and LBP.disableButtonGlow then
		if LBP:isEnabled() then
			LBP:Disable()
		end
	else
		if not LBP:isEnabled() then
			LBP:Enable()
		end
	end
end

-- Remove all previously injected custom proc entries from LBP_Data
function VP:ClearCustomProcs()
	if not LBP.isClassSupported then return end
	local class = LBP.playerClass
	for _, entry in ipairs(injectedEntries) do
		LBP_Data.OverlayProcs[class][entry.buffSpellID] = nil
		if entry.procIdx then
			LBP_Data.ButtonProcs[class][entry.procIdx] = nil
			for _, castID in ipairs(entry.castSpellIDs) do
				LBP_Data.ButtonSpells[class][castID] = nil
			end
		end
	end
	injectedEntries = {}
end

-- Apply all saved custom procs into LBP_Data
function VP:ApplyCustomProcs()
	if not LBP.isClassSupported then return end
	VP:ClearCustomProcs()
	local class = LBP.playerClass
	for _, entry in ipairs(E.db.visualProcs.customProcs) do
		local injected = {buffSpellID = entry.buffSpellID, castSpellIDs = {}}
		if entry.textureFile then
			-- Find or append the texture in this class's OverlayTextures
			local classTextures = LBP_Data.OverlayTextures[class]
			local texIdx = nil
			for i, texData in ipairs(classTextures) do
				if texData[2] == entry.textureFile then
					texIdx = i
					break
				end
			end
			if not texIdx then
				texIdx = #classTextures + 1
				classTextures[texIdx] = {0, entry.textureFile, "Left + Right (Flipped)", 1, 1, 1, 1}
			end
			LBP_Data.OverlayProcs[class][entry.buffSpellID] = texIdx
		end
		if entry.castSpellIDs and #entry.castSpellIDs > 0 then
			local procIdx = #LBP_Data.ButtonProcs[class] + 1
			LBP_Data.ButtonProcs[class][procIdx] = {entry.buffSpellID}
			for _, castID in ipairs(entry.castSpellIDs) do
				LBP_Data.ButtonSpells[class][castID] = procIdx
				injected.castSpellIDs[#injected.castSpellIDs + 1] = castID
			end
			injected.procIdx = procIdx
		end
		injectedEntries[#injectedEntries + 1] = injected
	end
end

function VP:Initialize()
	LBP.mediaPath = "Interface\\AddOns\\ElvUI_VisualProcs\\LibBlizzardProcs\\textures\\"

	self.overlayFrame = CreateFrame("Frame", "ElvUI_VisualProcsOverlay", UIParent)
	self.overlayFrame:Point("CENTER")

	self:UpdateSettings()
	VP:ApplyCustomProcs()
	self:ToggleButtonGlow()
	self:UpdateOverlay()
	self:ToggleOverlay()

	EP:RegisterPlugin(AddOnName, GetOptions)
end

local function InitializeCallback()
	VP:Initialize()
end

E:RegisterModule(VP:GetName(), InitializeCallback)
