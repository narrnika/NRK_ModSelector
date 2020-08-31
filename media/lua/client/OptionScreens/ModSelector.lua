require "ISUI/ISPanelJoypad"
require "ISUI/ISScrollingListBox"
require "ISUI/ISLabel"
require "ISUI/ISButton"
require "ISUI/ISTickBox"
require "ISUI/ISTextEntryBox"
require "ISUI/RichTextLayout"
require "ISUI/ISImage"
require "ISUI/ISComboBox"
require "ISUI/ISTextBox"
require "ISUI/ISModalDialog"
require "ISUI/ISPanelCompact"
require "ISUI/ISTextEntryList"
require "luautils"

local NRKModDB = require "NRK_ModDB" or {}
local NRKLOG = "NRK_ModSelector"

local FONT_HGT_TITLE = getTextManager():getFontHeight(UIFont.Title)
local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

local BUTTON_HGT = math.max(25, FONT_HGT_SMALL + 3 * 2)
local BUTTON_WDH = 100
local DX, DY = 9, 6

local DEFAULT_ICON = getTexture("media/ui/DefaultIcon.png")
local MAP_ICON = getTexture("media/ui/MapIcon.png")
local ACTIVE_ICON = getTexture("media/ui/iconInHotbar.png")
local REQUIRE_ICON = getTexture("media/ui/icon.png")
local BROKEN_ICON = getTexture("media/ui/icon_broken.png")
local FAVORITE_ICON = getTexture("media/ui/FavoriteStar.png")
local EXPANDED_ICON = getTexture("media/ui/TreeExpanded.png")
local COLLAPSED_ICON = getTexture("media/ui/TreeCollapsed.png")
local MINUS_ICON = getTexture("media/ui/Moodle_internal_minus_red.png")
local PLUS_ICON = getTexture("media/ui/Moodle_internal_plus_green.png")


ModSelector = ISPanelJoypad:derive("ModSelector")

function ModSelector:new(x, y, width, height) -- call from MainScreen.lua
	local o = ISPanelJoypad:new(x, y, width, height)
	ModSelector.instance = o -- call from NewGameScreen.lua, LoadGameScreen.lua
	setmetatable(o, self)
	self.__index = self
	o.customtagsfile = "saved_modtags.txt"
	o.customtags = {} -- {modId = {tag, tag, tag, ...}, modId = {tag, tag, tag, ...}, ...}
	o.counters = {} -- see ModSelector:populateListBox()
	-- o.isNewGame = false/true -- when call from MainScreen.lua/NewGameScreen.lua
	-- o.loadGameFolder = folder -- when call from LoadGameScreen.lua
	return o
end

function ModSelector:create() -- call from MainScreen.lua
	print(NRKLOG, "ModSelector:create")
	local halfW = (self.width - 3*DX)/2
	local halfH = (self.height - (FONT_HGT_TITLE + DY*2 + BUTTON_HGT + DY*2 + DY))/2
	
	self.titleLabel = ISLabel:new(
		0, DY, FONT_HGT_TITLE, getText("UI_mods_SelectMods"),
		1, 1, 1, 1, UIFont.Title, true
	)
	self.titleLabel:setX((self.width - self.titleLabel:getWidth())/2)
	self:addChild(self.titleLabel)
	
	self.filterPanel = ModPanelFilter:new(DX, FONT_HGT_TITLE + DY*2, halfW, BUTTON_HGT*2 + DY*3)
	self:addChild(self.filterPanel)
	
	self.listBox = ModListBox:new(DX, self.filterPanel:getBottom() + DY, halfW, halfH + halfH - self.filterPanel:getHeight())
	self:addChild(self.listBox)
	
	self.posterPanel = ModPanelPoster:new(halfW + DX*2, FONT_HGT_TITLE + DY*2, halfW, halfH)
	self:addChild(self.posterPanel)
	
	self.infoPanel = ModPanelInfo:new(halfW + DX*2, FONT_HGT_TITLE + DY*2 + halfH + DY, halfW, halfH)
	self:addChild(self.infoPanel)
	self.infoPanel:addScrollBars()
	self.infoPanel:setScrollChildren(true)
	
	self.backButton = ISButton:new(
		DX, self.height - (DY + BUTTON_HGT), BUTTON_WDH, BUTTON_HGT,
		getText("UI_btn_back"), self, ModSelector.onDone
	)
	self.backButton:setAnchorTop(false)
	self.backButton:setAnchorBottom(true)
	self.backButton:setWidthToTitle(BUTTON_WDH)
	self.backButton.borderColor = {r=1, g=1, b=1, a=0.1}
	self:addChild(self.backButton)
	
	self.acceptButton = ISButton:new(
		self.width - (DX + BUTTON_WDH), self.height - (DY + BUTTON_HGT), BUTTON_WDH, BUTTON_HGT,
		getText("UI_btn_accept"), self, ModSelector.onAccept
	)
	self.acceptButton:setAnchorLeft(false)
	self.acceptButton:setAnchorRight(true)
	self.acceptButton:setAnchorTop(false)
	self.acceptButton:setAnchorBottom(true)
	self.acceptButton:setWidthToTitle(BUTTON_WDH)
	self.acceptButton:setX(self.width - (DX + self.acceptButton:getWidth()))
	self.acceptButton.borderColor = {r=1, g=1, b=1, a=0.1}
	self:addChild(self.acceptButton)
	
	self.getModButton = ISButton:new(
		self.width - (DX + BUTTON_WDH)*2, self.height - (DY + BUTTON_HGT), BUTTON_WDH, BUTTON_HGT,
		getText("UI_mods_GetModsHere"), self, ModSelector.onGetMods
	)
	self.getModButton:setAnchorLeft(false)
	self.getModButton:setAnchorRight(true)
	self.getModButton:setAnchorTop(false)
	self.getModButton:setAnchorBottom(true)
	self.getModButton:setWidthToTitle(BUTTON_WDH)
	self.getModButton:setX(self.acceptButton:getX() - (DX + self.getModButton:getWidth()))
	self.getModButton.borderColor = {r=1, g=1, b=1, a=0.1}
	local tooltip_text = getText("UI_mods_Explanation") .. Core.getMyDocumentFolder() .. getFileSeparator() .. "mods" .. getFileSeparator()
	if not getSteamModeActive() then tooltip_text = getText("UI_mods_WorkshopRequiresSteam") .. "\n" .. tooltip_text end
	self.getModButton.tooltip = tooltip_text
	self:addChild(self.getModButton)
	
	self.savePanel = ModPanelSave:new(
		self.backButton:getRight() + DX, self.height - (DY + BUTTON_HGT),
		self.getModButton:getX() - (self.backButton:getRight() + DX*2), BUTTON_HGT
	)
	self.savePanel:setAnchorTop(false)
	self.savePanel:setAnchorBottom(true)
	self:addChild(self.savePanel)
end

function ModSelector:onDone()
	self:setVisible(false)
	
	if self.loadGameFolder then
		print(NRKLOG, "back to LoadGameScreen")
		self.loadGameFolder = nil
		LoadGameScreen.instance:setVisible(true, self.joyfocus)
		return
	end
	
	if self.isNewGame then
		print(NRKLOG, "back to NewGameScreen")
		self.isNewGame = nil
		NewGameScreen.instance:setVisible(true, self.joyfocus)
		return
	end
	
	print(NRKLOG, "back to MainScreen")
	MainScreen.instance.bottomPanel:setVisible(true)
	if self.joyfocus then
		self.joyfocus.focus = MainScreen.instance
		updateJoypadFocus(self.joyfocus)
	end
end

function ModSelector:onAccept()
	self:setVisible(false)
	print(NRKLOG, "accept pressed")
	
	local oldFavors, newFavors = {}, {}
	for _, modId in ipairs(self.savePanel.savelist["FavorList"] or {}) do
		oldFavors[modId] = true
	end
	for _, item in ipairs(self.listBox.items) do
		if item.item.isFavor then
			newFavors[item.item.modInfo:getId()] = true
		end
	end
	
	local addFavors, delFavors = {}, {}
	for modId, _ in pairs(oldFavors) do
		if not newFavors[modId] then table.insert(delFavors, modId) end
	end
	for modId, _ in pairs(newFavors) do
		if not oldFavors[modId] then table.insert(addFavors, modId) end
	end
	
	if #addFavors > 0 or #delFavors > 0 then -- favor list has been changed
		print(NRKLOG, "accept change favor-list")
		-- change mod list of saves
		for _, folder in ipairs(getFullSaveDirectoryTable()) do
			local info = getSaveInfo(folder)
			local activeMods = info.activeMods or ActiveMods.getById("default")
			ActiveMods.getById("currentGame"):copyFrom(activeMods)
			for _, modId in ipairs(addFavors) do
				ActiveMods.getById("currentGame"):setModActive(modId, true)
			end
			for _, modId in ipairs(delFavors) do
				ActiveMods.getById("currentGame"):setModActive(modId, false)
			end
			manipulateSavefile(folder, "WriteModsDotTxt")
		end
		
		-- change global mod list
		for _, modId in ipairs(addFavors) do
			ActiveMods.getById("default"):setModActive(modId, true)
		end
		for _, modId in ipairs(delFavors) do
			ActiveMods.getById("default"):setModActive(modId, false)
		end
		saveModsFile()
		
		-- save new favor list
		self.savePanel.savelist["FavorList"] = {}
		for modId, _ in pairs(newFavors) do
			table.insert(self.savePanel.savelist["FavorList"], modId)
		end
		table.sort(self.savePanel.savelist["FavorList"])
		self.savePanel:writeModList()
	end
	
	if self.loadGameFolder then
		print(NRKLOG, "accept for LoadGameScreen")
		local saveFolder = self.loadGameFolder
		self.loadGameFolder = nil
		for _, item in ipairs(self.listBox.items) do
			ActiveMods.getById("currentGame"):setModActive(item.item.modInfo:getId(), item.item.isActive)
		end
		manipulateSavefile(saveFolder, "WriteModsDotTxt")
		LoadGameScreen.instance:onSavefileModsChanged(saveFolder)
		LoadGameScreen.instance:setVisible(true, self.joyfocus)
		return
	end
	
	if self.isNewGame then
		print(NRKLOG, "accept for NewGameScreen")
		self.isNewGame = nil
		for _, item in ipairs(self.listBox.items) do
			ActiveMods.getById("currentGame"):setModActive(item.item.modInfo:getId(), item.item.isActive)
		end
		NewGameScreen.instance:setVisible(true, self.joyfocus)
		if ActiveMods.requiresResetLua(ActiveMods.getById("currentGame")) then
			getCore():ResetLua("currentGame", "NewGameMods")
		end
		return
	end
	
	print(NRKLOG, "accept for MainScreen")
	for _, item in ipairs(self.listBox.items) do
		ActiveMods.getById("default"):setModActive(item.item.modInfo:getId(), item.item.isActive)
	end
	saveModsFile()
	
	MainScreen.instance.bottomPanel:setVisible(true)
	if self.joyfocus then
		self.joyfocus.focus = MainScreen.instance
		updateJoypadFocus(self.joyfocus)
	end
	
	--if ActiveMods.requiresResetLua(ActiveMods.getById("default")) then
		getCore():ResetLua("default", "modsChanged")
	--end
end

function ModSelector:onGetMods()
	if getSteamModeActive() then
		if isSteamOverlayEnabled() then
			activateSteamOverlayToWorkshop()
		else
			openUrl("steam://url/SteamWorkshopPage/108600")
		end
	else
		openUrl("http://theindiestone.com/forums/index.php/forum/58-mods/")
	end
end

function ModSelector:onGainJoypadFocus(joypadData)
	ISPanelJoypad.onGainJoypadFocus(self, joypadData)
	self:setISButtonForA(self.acceptButton)
	self:setISButtonForB(self.backButton)
	self.hasJoypadFocus = true
	joypadData.focus = self
end

function ModSelector:onResolutionChange(oldw, oldh, neww, newh) -- call from MainScreen.lua
	-- oldw, oldh, neww, newh - window's size (no panel)
	local halfW = (self.width - 3*DX)/2
	local halfH = (self.height - (FONT_HGT_TITLE + DY*2 + BUTTON_HGT + DY*2 + DY))/2
	
	self.titleLabel:setX((self.width - self.titleLabel:getWidth())/2)
	
	self.filterPanel:setWidth(halfW)
	self.filterPanel.filter:setWidth(halfW - 2*DX)
	self.filterPanel.search:setWidth(halfW - 2*DX)
	self.filterPanel.search:recalcChildren()
	self.filterPanel.searchEntryBox:setHeight(self.filterPanel.search.height - 6)
	
	self.listBox:setWidth(halfW)
	self.listBox.btn.x1 = halfW - (self.listBox.btn.w1 + DX)
	self.listBox.btn.x2 = halfW - (self.listBox.btn.w2 + DX)
	self.listBox:setHeight(halfH + halfH - self.filterPanel:getHeight())
	
	
	self.posterPanel:setX(halfW + DX*2)
	self.posterPanel:setWidth(halfW)
	self.posterPanel:setHeight(halfH)
	self.posterPanel:update()
	
	self.infoPanel:setX(halfW + DX*2)
	self.infoPanel:setWidth(halfW)
	self.infoPanel:setY(FONT_HGT_TITLE + DY*2 + halfH + DY)
	self.infoPanel:setHeight(halfH)
	self.infoPanel.workshopEntry:setWidth(self.infoPanel:getWidth() - (BUTTON_WDH + DX*2 + self.infoPanel.scrollwidth) - (self.infoPanel.workshopLabel:getRight() + DX))
	self.infoPanel.urlEntry:setWidth(self.infoPanel:getWidth() - (BUTTON_WDH + DX*2 + self.infoPanel.scrollwidth) - (self.infoPanel.urlLabel:getRight() + DX))
	self.infoPanel.locationEntry:setWidth(self.infoPanel:getWidth() - (BUTTON_WDH + DX*2 + self.infoPanel.scrollwidth) - (self.infoPanel.locationLabel:getRight() + DX))
	self.infoPanel.customTagsButton:setWidth(self.infoPanel:getWidth() - (DX*2 + self.infoPanel.scrollwidth))
	
	self.savePanel:setWidth(self.getModButton:getX() - (self.backButton:getRight() + DX*2))
end

function ModSelector:setExistingSavefile(folder) -- call from LoadGameScreen.lua
	print(NRKLOG, "setExistingSavefile, ", folder)
	self.loadGameFolder = folder
	local info = getSaveInfo(folder)
	local activeMods = info.activeMods or ActiveMods.getById("default")
	ActiveMods.getById("currentGame"):copyFrom(activeMods)
	
	-- TODO: mapName - it's work? see original setExistingSavefile()
	--self.loadGameMapName = info.mapName or 'Muldraugh, KY'
end

function ModSelector:populateListBox(directories) -- call from MainScreen.lua, NewGameScreen.lua, LoadGameScreen.lua
	print(NRKLOG, "populateListBox")
	
	-- create items
	self.listBox:clear()
	self.listBox.indexById = {}
	for i, directory in ipairs(directories) do
		local modInfo = getModInfo(directory)
		if modInfo then -- to avoid errors if the mod has already been removed
			local modId = modInfo:getId()
			if not self.listBox.indexById[modId] then
				self.listBox:addItem(modInfo:getName(), {modInfo = modInfo})
				self.listBox.indexById[modId] = i
			end
		end
	end
	
	-- sort by name and re-index
	self.listBox:sort()
	for index, item in ipairs(self.listBox.items) do
		self.listBox.indexById[item.item.modInfo:getId()] = index
	end
	
	-- write info to items and calculate
	self.counters = {
		workshop = 0,
		map = 0,
		translate = 0,
		available = 0,
		enabled = 0,
		favor = 0,
		pzversions = {}, -- {version1 = count, version2 = count, ...}
		authors = {}, -- {author1 = count, author2 = count, ...}
		originaltags = {}, -- {tag1 = count, tag2 = count, ...}
		customtags = {}, -- {tag1 = count, tag2 = count, ...}
	}
	self.savePanel:updateOptions()
	local favorList = {}
	for _, modId in ipairs(self.savePanel.savelist["FavorList"] or {}) do
		favorList[modId] = true
	end
	local activeMods = (self.loadGameFolder or self.isNewGame) and ActiveMods.getById("currentGame") or ActiveMods.getById("default")
	for _, i in ipairs(self.listBox.items) do
		local item, modId, dir = i.item, i.item.modInfo:getId(), i.item.modInfo:getDir()
		
		if item.modInfo:getWorkshopID() then self.counters.workshop = self.counters.workshop + 1 end
		
		item.modInfoExtra = self:readInfoExtra(modId)
		if item.modInfoExtra.maps then self.counters.map = self.counters.map + 1 end
		
		item.modInfoExtra.translate = fileExists(dir .. string.gsub("/media/lua/shared/Translate", "/", getFileSeparator()))
		if item.modInfoExtra.translate then self.counters.translate = self.counters.translate + 1 end
		
		if item.isAvailable == nil then item.isAvailable = self:checkRequire(modId) end
		if item.isAvailable then self.counters.available = self.counters.available + 1 end
		
		item.isActive = activeMods:isModActive(modId)
		if item.isActive then self.counters.enabled = self.counters.enabled + 1 end
		
		item.isFavor = favorList[modId] or false
		if item.isFavor then self.counters.favor = self.counters.favor + 1 end
		
		
		local pzversion = item.modInfoExtra.pzversion
		if pzversion then
			self.counters.pzversions[pzversion] = (self.counters.pzversions[pzversion] or 0) + 1
		end
		for _, author in ipairs(item.modInfoExtra.authors or {}) do
			self.counters.authors[author] = (self.counters.authors[author] or 0) + 1
		end
		for _, tag in ipairs(item.modInfoExtra.tags or {}) do
			self.counters.originaltags[tag] = (self.counters.originaltags[tag] or 0) + 1
		end
	end
	
	-- read custom tags
	self.customtags = {}
	local file = getFileReader(self.customtagsfile, true)
	local line = file:readLine()
	while line ~= nil do
		--split modId and tags (by first ":", no luautils.split)
		local sep = string.find(line, ":")
		local modId, tags = "", ""
		if sep ~= nil then
			modId = string.sub(line, 0, sep - 1)
			tags = string.sub(line, sep + 1)
		end
		
		if modId ~= "" and tags ~= "" then
			self.customtags[modId] = luautils.split(tags, ",")
			for _, tag in ipairs(self.customtags[modId]) do
				self.counters.customtags[tag] = (self.counters.customtags[tag] or 0) + 1
			end
		end
		
		line = file:readLine()
	end
	file:close()
end

function ModSelector:checkRequire(modId)
	local requires = getModInfoByID(modId):getRequire()
	
	if requires and not requires:isEmpty() then
		for i = 0, requires:size() - 1 do
			local requireId = requires:get(i)
			local index = self.listBox.indexById[requireId]
			if index == nil then
				return false
			else
				local requireItem = self.listBox.items[index].item
				if type(requireItem.dependents) == "table" then
					table.insert(requireItem.dependents, modId)
				else
					requireItem.dependents = {modId}
				end
				if requireItem.isAvailable == nil then
					requireItem.isAvailable = self:checkRequire(requireId)
				end
				if requireItem.isAvailable == false then
					return false
				end
			end
		end
	end
	
	return true
end

function ModSelector:readInfoExtra(modId)
	local modInfo = getModInfoByID(modId)
	local modInfoExtra = NRKModDB[modId] or {}
	
	-- mod with maps?
	local mapList = getMapFoldersForMod(modId)
	if mapList ~= nil and mapList:size() > 0 then
		modInfoExtra.maps = {}
		for i = 0, mapList:size() - 1 do
			table.insert(modInfoExtra.maps, mapList:get(i))
		end
	end
	
	-- find <LANG:XX> commands in description
	local desc = modInfo:getDescription()
	local act_lang, def_lang = "<LANG:" .. Translator.getLanguage():name() .. ">", "<LANG:EN>"
	local _, start_a = string.find(desc, act_lang)
	local _, start_d = string.find(desc, def_lang)
	local start = start_a or start_d
	if start then
		desc = string.sub(desc, start + 1)
		local finish, _ = string.find(desc, "<LANG:")
		if finish ~= nil then
			modInfoExtra.description = string.sub(desc, 0, finish - 1)
		else
			modInfoExtra.description = desc
		end
	end
	
	-- extra data from mod.info
	local file = getModFileReader(modId, "mod.info", false)
	if not file then return modInfoExtra end
	local line = file:readLine()
	while line ~= nil do
		--split key and value (by first "=", no luautils.split)
		local sep = string.find(line, "=")
		local key, val = "", ""
		if sep ~= nil then
			key = string.lower(luautils.trim(string.sub(line, 0, sep - 1)))
			val = luautils.trim(string.sub(line, sep + 1))
		end
		
		-- no read default keys: name, poster, description, require, id, pack, tiledef
		-- reread url without restrictions
		if key == "modversion" then
			modInfoExtra.modversion = val
		elseif key == "url" then
			modInfoExtra.url = val
		elseif key == "icon" then
			modInfoExtra.icon = getTexture(modInfo:getDir() .. getFileSeparator() .. val)
		elseif key == "pzversion" then
			modInfoExtra.pzversion = #val > 0 and val or modInfoExtra.pzversion
		elseif key == "tags" then
			val = luautils.split(val, ",")
			for i, j in ipairs(val) do
				val[i] = luautils.trim(j)
			end
			modInfoExtra.tags = #val > 0 and val or modInfoExtra.tags
		elseif key == "authors" then
			val = luautils.split(val, ",")
			for i, j in ipairs(val) do
				val[i] = luautils.trim(j)
			end
			modInfoExtra.authors = #val > 0 and val or modInfoExtra.authors
		end
		
		line = file:readLine()
	end
	file:close()
	
	return modInfoExtra
end

function ModSelector.showNagPanel() -- call from MainScreen.lua, NewGameScreen.lua, LoadGameScreen.lua
	print(NRKLOG, "show NagPanel")
	if getCore():isModsPopupDone() then return end
	
	getCore():setModsPopupDone(true)
	ModSelector.instance:setVisible(false)
	
	local width, height = 650, 400
	local nagPanel = ISModsNagPanel:new(
		(getCore():getScreenWidth() - width)/2,
		(getCore():getScreenHeight() - height)/2,
		width, height
	)
	nagPanel:initialise()
	nagPanel:addToUIManager()
	nagPanel:setAlwaysOnTop(true)
	if JoypadState[1] then
		JoypadState[1].focus = nagPanel
		updateJoypadFocus(JoypadState[1])
	end
end


ModPanelFilter = ISPanelJoypad:derive("ModPanelFilter")

function ModPanelFilter:new(x, y, width, height)
	local o = ISPanelJoypad:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	return o
end

function ModPanelFilter:createChildren()
	self.filter = ISPanelCompact:new(DX, DY, self.width - 2*DX, BUTTON_HGT)
	self:addChild(self.filter)
	self.filter.createText = function(S)
		local options, P = {}, S.parent
		
		if P.locationTickBox.selected[1] and not P.locationTickBox.selected[2] then
			table.insert(options, getText("UI_NRK_ModSelector_Filter_Workshop"))
		elseif not P.locationTickBox.selected[1] and P.locationTickBox.selected[2] then
			table.insert(options, getText("UI_NRK_ModSelector_Filter_Local"))
		end 
		
		if P.mapTickBox.selected[1] and not P.mapTickBox.selected[2] then
			table.insert(options, getText("UI_NRK_ModSelector_Filter_Withmap"))
		elseif not P.mapTickBox.selected[1] and P.mapTickBox.selected[2] then
			table.insert(options, getText("UI_NRK_ModSelector_Filter_Withoutmap"))
		end 
		
		if P.translateTickBox.selected[1] and not P.translateTickBox.selected[2] then
			table.insert(options, getText("UI_NRK_ModSelector_Filter_Withtranslate"))
		elseif not P.translateTickBox.selected[1] and P.translateTickBox.selected[2] then
			table.insert(options, getText("UI_NRK_ModSelector_Filter_Withouttranslate"))
		end 
		
		if P.availabilityTickBox.selected[1] and not P.availabilityTickBox.selected[2] then
			table.insert(options, getText("UI_NRK_ModSelector_Filter_Available"))
		elseif not P.availabilityTickBox.selected[1] and P.availabilityTickBox.selected[2] then
			table.insert(options, getText("UI_NRK_ModSelector_Filter_Broken"))
		end 
		
		if P.statusTickBox.selected[1] and not P.statusTickBox.selected[2] then
			table.insert(options, getText("UI_NRK_ModSelector_Filter_Enabled"))
		elseif not P.statusTickBox.selected[1] and P.statusTickBox.selected[2] then
			table.insert(options, getText("UI_NRK_ModSelector_Filter_Disabled"))
		end 
		
		if P.favorTickBox.selected[1] and not P.favorTickBox.selected[2] then
			table.insert(options, getText("UI_NRK_ModSelector_Filter_Favor"))
		elseif not P.favorTickBox.selected[1] and P.favorTickBox.selected[2] then
			table.insert(options, getText("UI_NRK_ModSelector_Filter_Nofavor"))
		end 
		
		if #options == 0 then
			S.text = getText("UI_NRK_ModSelector_Filter_Off")
		else
			S.text = getText("UI_NRK_ModSelector_Filter_On", table.concat(options, ", "))
		end
	end
	self.filter.popup.resize = function(S)
		local P = S.parentPanel.parent
		
		-- update labels, counts and Width
		local all = P.parent.listBox.count
		local counters = P.parent.counters
		
		P.allButton:setTitle(string.format("%s [%d]", getText("UI_NRK_ModSelector_Filter_AllButton"), all))
		
		P.locationTickBox.options[1] = string.format("%s [%d]", getText("UI_NRK_ModSelector_Filter_Workshop"), counters.workshop)
		P.locationTickBox.optionsIndex[1] = P.locationTickBox.options[1]
		P.locationTickBox.options[2] = string.format("%s [%d]", getText("UI_NRK_ModSelector_Filter_Local"), all - counters.workshop)
		P.locationTickBox.optionsIndex[2] = P.locationTickBox.options[2]
		P.locationTickBox:setWidthToFit()
		
		P.mapTickBox.options[1] = string.format("%s [%d]", getText("UI_NRK_ModSelector_Filter_Withmap"), counters.map)
		P.mapTickBox.optionsIndex[1] = P.mapTickBox.options[1]
		P.mapTickBox.options[2] = string.format("%s [%d]", getText("UI_NRK_ModSelector_Filter_Withoutmap"), all - counters.map)
		P.mapTickBox.optionsIndex[2] = P.mapTickBox.options[2]
		P.mapTickBox:setWidthToFit()
		
		P.translateTickBox.options[1] = string.format("%s [%d]", getText("UI_NRK_ModSelector_Filter_Withtranslate"), counters.translate)
		P.translateTickBox.optionsIndex[1] = P.translateTickBox.options[1]
		P.translateTickBox.options[2] = string.format("%s [%d]", getText("UI_NRK_ModSelector_Filter_Withouttranslate"), all - counters.translate)
		P.translateTickBox.optionsIndex[2] = P.translateTickBox.options[2]
		P.translateTickBox:setWidthToFit()
		
		P.availabilityTickBox.options[1] = string.format("%s [%d]", getText("UI_NRK_ModSelector_Filter_Available"), counters.available)
		P.availabilityTickBox.optionsIndex[1] = P.availabilityTickBox.options[1]
		P.availabilityTickBox.options[2] = string.format("%s [%d]", getText("UI_NRK_ModSelector_Filter_Broken"), all - counters.available)
		P.availabilityTickBox.optionsIndex[2] = P.availabilityTickBox.options[2]
		P.availabilityTickBox:setWidthToFit()
		
		P.statusTickBox.options[1] = string.format("%s [%d]", getText("UI_NRK_ModSelector_Filter_Enabled"), counters.enabled)
		P.statusTickBox.optionsIndex[1] = P.statusTickBox.options[1]
		P.statusTickBox.options[2] = string.format("%s [%d]", getText("UI_NRK_ModSelector_Filter_Disabled"), all - counters.enabled)
		P.statusTickBox.optionsIndex[2] = P.statusTickBox.options[2]
		P.statusTickBox:setWidthToFit()
		
		P.favorTickBox.options[1] = string.format("%s [%d]", getText("UI_NRK_ModSelector_Filter_Favor"), counters.favor)
		P.favorTickBox.optionsIndex[1] = P.favorTickBox.options[1]
		P.favorTickBox.options[2] = string.format("%s [%d]", getText("UI_NRK_ModSelector_Filter_Nofavor"), all - counters.favor)
		P.favorTickBox.optionsIndex[2] = P.favorTickBox.options[2]
		P.favorTickBox:setWidthToFit()
		
		-- update coordinates
		P.allButton:setWidth(S.width - 2*DX)
		
		local w = {
			P.locationTickBox.width,
			P.mapTickBox.width,
			P.translateTickBox.width,
			P.availabilityTickBox.width,
			P.statusTickBox.width,
			P.favorTickBox.width,
		}
		local w32 = math.max(w[1], w[4]) + math.max(w[2], w[5]) + math.max(w[3], w[6])
		local w23 = math.max(w[1], w[2], w[3]) + math.max(w[4], w[5], w[6])
		
		if w32 + 4*DX <= S.width then -- 3 columns, 2 rows
			local x1 = (S.width - w32)/4
			local x2 = x1 + math.max(w[1], w[4]) + x1
			local x3 = x2 + math.max(w[2], w[5]) + x1
			local y1 = P.allButton:getBottom() + DY
			P.locationTickBox:setX(x1)
			P.locationTickBox:setY(y1)
			P.mapTickBox:setX(x2)
			P.mapTickBox:setY(y1)
			P.translateTickBox:setX(x3)
			P.translateTickBox:setY(y1)
			local y2 = P.translateTickBox:getBottom() + DY
			P.availabilityTickBox:setX(x1)
			P.availabilityTickBox:setY(y2)
			P.statusTickBox:setX(x2)
			P.statusTickBox:setY(y2)
			P.favorTickBox:setX(x3)
			P.favorTickBox:setY(y2)
		elseif w23 + 3*DX <= S.width then -- 2 columns, 3 rows
			local dx = (S.width - w23)/3
			local x1 = (S.width - w23)/3
			local x2 = x1 + math.max(w[1], w[2], w[3]) + x1
			local y1 = P.allButton:getBottom() + DY
			P.locationTickBox:setX(x1)
			P.locationTickBox:setY(y1)
			P.availabilityTickBox:setX(x2)
			P.availabilityTickBox:setY(y1)
			local y2 = P.availabilityTickBox:getBottom() + DY
			P.mapTickBox:setX(x1)
			P.mapTickBox:setY(y2)
			P.statusTickBox:setX(x2)
			P.statusTickBox:setY(y2)
			local y3 = P.statusTickBox:getBottom() + DY
			P.translateTickBox:setX(x1)
			P.translateTickBox:setY(y3)
			P.favorTickBox:setX(x2)
			P.favorTickBox:setY(y3)
		else -- 1 column, 6 rows
			local dx = (S.width - math.max(w[1], w[2], w[3], w[4], w[5], w[6]))/2
			P.locationTickBox:setX(dx)
			P.locationTickBox:setY(P.allButton:getBottom() + DY)
			P.mapTickBox:setX(dx)
			P.mapTickBox:setY(P.locationTickBox:getBottom() + DY)
			P.translateTickBox:setX(dx)
			P.translateTickBox:setY(P.mapTickBox:getBottom() + DY)
			P.availabilityTickBox:setX(dx)
			P.availabilityTickBox:setY(P.translateTickBox:getBottom() + DY)
			P.statusTickBox:setX(dx)
			P.statusTickBox:setY(P.availabilityTickBox:getBottom() + DY)
			P.favorTickBox:setX(dx)
			P.favorTickBox:setY(P.statusTickBox:getBottom() + DY)
		end
		
		S:setHeight(P.favorTickBox:getBottom() + DY)
	end
	
	local allButton = ISButton:new(
		DX, DY, 0, BUTTON_HGT, "", self,
		function(target)
			target.locationTickBox.selected = {true, true}
			target.mapTickBox.selected = {true, true}
			target.translateTickBox.selected = {true, true}
			target.availabilityTickBox.selected = {true, true}
			target.statusTickBox.selected = {true, true}
			target.favorTickBox.selected = {true, true}
			target.filter.text = getText("UI_NRK_ModSelector_Filter_Off")
		end
	)
	allButton.borderColor = {r=1, g=1, b=1, a=0.1}
	self.filter.popup:addChild(allButton)
	self.allButton = allButton
	
	local locationTickBox = ISTickBox:new(
		0, 0, 0, 0, nil, self.filter,
		function(target, optionindex, optionvalue, arg1, arg2, tickbox)
			if not optionvalue then tickbox.selected[3 - optionindex] = true end
			target:createText()
		end
	)
	locationTickBox.choicesColor = {r=1, g=1, b=1, a=1}
	locationTickBox:addOption("", "Workshop")
	locationTickBox:addOption("", "Local")
	locationTickBox.selected = {true, true}
	self.filter.popup:addChild(locationTickBox)
	self.locationTickBox = locationTickBox
	
	local mapTickBox = ISTickBox:new(
		0, 0, 0, 0, nil, self.filter,
		function(target, optionindex, optionvalue, arg1, arg2, tickbox)
			if not optionvalue then tickbox.selected[3 - optionindex] = true end
			target:createText()
		end
	)
	mapTickBox.choicesColor = {r=1, g=1, b=1, a=1}
	mapTickBox:addOption("", "Withmap")
	mapTickBox:addOption("", "Withoutmap")
	mapTickBox.selected = {true, true}
	self.filter.popup:addChild(mapTickBox)
	self.mapTickBox = mapTickBox
	
	local translateTickBox = ISTickBox:new(
		0, 0, 0, 0, nil, self.filter,
		function(target, optionindex, optionvalue, arg1, arg2, tickbox)
			if not optionvalue then tickbox.selected[3 - optionindex] = true end
			target:createText()
		end
	)
	translateTickBox.choicesColor = {r=1, g=1, b=1, a=1}
	translateTickBox:addOption("", "Withtranslate")
	translateTickBox:addOption("", "Withouttranslate")
	translateTickBox.selected = {true, true}
	self.filter.popup:addChild(translateTickBox)
	self.translateTickBox = translateTickBox
	
	local availabilityTickBox = ISTickBox:new(
		0, 0, 0, 0, nil, self.filter,
		function(target, optionindex, optionvalue, arg1, arg2, tickbox)
			if not optionvalue then tickbox.selected[3 - optionindex] = true end
			target:createText()
		end
	)
	availabilityTickBox.choicesColor = {r=1, g=1, b=1, a=1}
	availabilityTickBox:addOption("", "Available")
	availabilityTickBox:addOption("", "Broken")
	availabilityTickBox.selected = {true, false}
	self.filter.popup:addChild(availabilityTickBox)
	self.availabilityTickBox = availabilityTickBox
	
	local statusTickBox = ISTickBox:new(
		0, 0, 0, 0, nil, self.filter,
		function(target, optionindex, optionvalue, arg1, arg2, tickbox)
			if not optionvalue then tickbox.selected[3 - optionindex] = true end
			target:createText()
		end
	)
	statusTickBox.choicesColor = {r=1, g=1, b=1, a=1}
	statusTickBox:addOption("", "Enabled")
	statusTickBox:addOption("", "Disabled")
	statusTickBox.selected = {true, true}
	self.filter.popup:addChild(statusTickBox)
	self.statusTickBox = statusTickBox
	
	local favorTickBox = ISTickBox:new(
		0, 0, 0, 0, nil, self.filter,
		function(target, optionindex, optionvalue, arg1, arg2, tickbox)
			if not optionvalue then tickbox.selected[3 - optionindex] = true end
			target:createText()
		end
	)
	favorTickBox.choicesColor = {r=1, g=1, b=1, a=1}
	favorTickBox:addOption("", "Favor")
	favorTickBox:addOption("", "Nofavor")
	favorTickBox.selected = {false, true}
	self.filter.popup:addChild(favorTickBox)
	self.favorTickBox = favorTickBox
	
	self.filter:createText()
	
	
	self.search = ISPanelCompact:new(DX, self.filter:getBottom() + DY, self.width - 2*DX, BUTTON_HGT)
	self:addChild(self.search)
	self.search.recalcChildren = function(S)
		local w = math.max(S.width - (10 + getTextManager():MeasureStringX(S.font, S.text) + 5 + 18), BUTTON_WDH)
		S.parent.searchEntryBox:setX(S.width - (w + 18))
		S.parent.searchEntryBox:setWidth(w)
	end
	self.search.createText = function(S)
		local options, P = {}, S.parent
		local operator1, operator2 = "", ""
		
		for i, name in ipairs(P.searchby1.options) do
			if P.searchby1.selected[i] then table.insert(options, name) end
		end
		for i, name in ipairs(P.searchby2.options) do
			if P.searchby2.selected[i] then table.insert(options, name) end
		end
		for i, name in ipairs(P.searchas1.options) do
			if P.searchas1.selected[i] then
				operator1 = getText("UI_NRK_ModSelector_Search_OR")
				operator2 = name
			end
		end
		for i, name in ipairs(P.searchas2.options) do
			if P.searchas2.selected[i] then
				operator1 = getText("UI_NRK_ModSelector_Search_AND")
				operator2 = name
			end
		end
		
		S.text = getText("UI_NRK_ModSelector_Search_By", table.concat(options, operator1), operator2)
		S:recalcChildren()
	end
	self.search.popup.resize = function(S)
		local P = S.parentPanel.parent
		
		local w = {
			P.searchby1.width,
			P.searchby2.width,
			P.searchas1.width,
			P.searchas2.width,
		}
		local w12 = math.max(w[1], w[2])
		local w34 = math.max(w[3], w[4])
		
		if w[1] + w[2] + w[3] + w[4] + 5*DX <= S.width then
			local dx = (S.width - (w[1] + w[2] + w[3] + w[4] + 5*DX))/3
			P.searchby1:setX(DX + dx)
			P.searchby1:setY(DY)
			P.searchby2:setX(P.searchby1:getRight() + DX)
			P.searchby2:setY(DY)
			P.searchas1:setX(P.searchby2:getRight() + DX + dx)
			P.searchas1:setY(DY)
			P.searchas2:setX(P.searchas1:getRight() + DX)
			P.searchas2:setY(DY)
		elseif w12 + w34 + 3*DX <= S.width then
			local x1 = (S.width - (w12 + w34))/3
			local x2 = x1 + w12 + x1
			P.searchby1:setX(x1)
			P.searchby1:setY(DY)
			P.searchby2:setX(x1)
			P.searchby2:setY(P.searchby1:getBottom() + DY)
			P.searchas1:setX(x2)
			P.searchas1:setY(DY)
			P.searchas2:setX(x2)
			P.searchas2:setY(P.searchas1:getBottom() + DY)
		else
			local x = (S.width - math.max(w12, w34))/2
			P.searchby1:setX(x)
			P.searchby1:setY(DY)
			P.searchby2:setX(x)
			P.searchby2:setY(P.searchby1:getBottom() + DY)
			P.searchas1:setX(x)
			P.searchas1:setY(P.searchby2:getBottom() + DY)
			P.searchas2:setX(x)
			P.searchas2:setY(P.searchas1:getBottom() + DY)
		end
		
		S:setHeight(math.max(P.searchby2:getBottom(), P.searchas2:getBottom()) + DY)
	end
	
	local searchby1 = ISTickBox:new(
		0, 0, 0, 0, nil, self.search,
		function(target, optionindex, optionvalue, arg1, arg2, tickbox)
			if optionvalue then
				target.parent.searchby2.selected = {}
				target.parent.searchEntryBox.options = {}
			elseif not(tickbox.selected[1] or tickbox.selected[2] or tickbox.selected[3]) then
				tickbox.selected[optionindex] = true
			end
			target:createText()
		end
	)
	searchby1.choicesColor = {r=1, g=1, b=1, a=1}
	searchby1:addOption(getText("UI_NRK_ModSelector_Search_Name"))
	searchby1:addOption(getText("UI_NRK_ModSelector_Search_Desc"))
	searchby1:addOption(getText("UI_NRK_ModSelector_Search_ModID"))
	searchby1:setWidthToFit()
	searchby1.selected = {true, true, true}
	self.search.popup:addChild(searchby1)
	self.searchby1 = searchby1
	
	local searchby2 = ISTickBox:new(
		0, 0, 0, 0, nil, self.search,
		function(target, optionindex, optionvalue, arg1, arg2, tickbox)
			if optionvalue then
				target.parent.searchby1.selected = {}
				tickbox.selected = {}
				tickbox.selected[optionindex] = true
				
				target.parent.searchEntryBox.options = {}
				if optionindex == 3 then
					for i, j in pairs(target.parent.parent.counters.pzversions) do
						target.parent.searchEntryBox:addOption(i, j)
					end
				elseif optionindex == 4 then
					local tags = {}
					for i, j in pairs(target.parent.parent.counters.originaltags) do
						tags[i] = j
					end
					for i, j in pairs(target.parent.parent.counters.customtags) do
						tags[i] = (tags[i] or 0) + j
					end
					for i, j in pairs(tags) do
						target.parent.searchEntryBox:addOption(i, j)
					end
				elseif optionindex == 5 then
					for i, j in pairs(target.parent.parent.counters.authors) do
						target.parent.searchEntryBox:addOption(i, j)
					end
				end
			else
				tickbox.selected[optionindex] = true
			end
			target:createText()
		end
	)
	searchby2.choicesColor = {r=1, g=1, b=1, a=1}
	searchby2:addOption(getText("UI_NRK_ModSelector_Search_WorkshopID"))
	searchby2:addOption(getText("UI_NRK_ModSelector_Search_MapID"))
	searchby2:addOption(getText("UI_NRK_ModSelector_Search_PZVersion"))
	searchby2:addOption(getText("UI_NRK_ModSelector_Search_Tags"))
	searchby2:addOption(getText("UI_NRK_ModSelector_Search_Author"))
	searchby2:setWidthToFit()
	searchby2.selected = {}
	self.search.popup:addChild(searchby2)
	self.searchby2 = searchby2
	
	local searchas1 = ISTickBox:new(
		0, 0, 0, 0, nil, self.search,
		function(target, optionindex, optionvalue, arg1, arg2, tickbox)
			if optionvalue then
				target.parent.searchEntryBox:setVisible(not(optionindex == 3))
				target.parent.searchas2.selected = {}
				tickbox.selected = {}
				tickbox.selected[optionindex] = true
			else
				tickbox.selected[optionindex] = true
			end
			target:createText()
		end
	)
	searchas1.choicesColor = {r=1, g=1, b=1, a=1}
	searchas1:addOption(getText("UI_NRK_ModSelector_Search_Equal"))
	searchas1:addOption(getText("UI_NRK_ModSelector_Search_Contain"))
	searchas1:addOption(getText("UI_NRK_ModSelector_Search_Empty"))
	searchas1:setWidthToFit()
	searchas1.selected = {false, true, false}
	self.search.popup:addChild(searchas1)
	self.searchas1 = searchas1
	
	local searchas2 = ISTickBox:new(
		0, 0, 0, 0, nil, self.search,
		function(target, optionindex, optionvalue, arg1, arg2, tickbox)
			if optionvalue then
				target.parent.searchEntryBox:setVisible(not(optionindex == 3))
				target.parent.searchas1.selected = {}
				tickbox.selected = {}
				tickbox.selected[optionindex] = true
			else
				tickbox.selected[optionindex] = true
			end
			target:createText()
		end
	)
	searchas2.choicesColor = {r=1, g=1, b=1, a=1}
	searchas2:addOption(getText("UI_NRK_ModSelector_Search_noEqual"))
	searchas2:addOption(getText("UI_NRK_ModSelector_Search_noContain"))
	searchas2:addOption(getText("UI_NRK_ModSelector_Search_noEmpty"))
	searchas2:setWidthToFit()
	searchas2.selected = {}
	self.search.popup:addChild(searchas2)
	self.searchas2 = searchas2
	
	local searchEntryBox = ISTextEntryList:new("", 0, 3, 0, self.search.height - 6)
	self.search:addChild(searchEntryBox)
	self.searchEntryBox = searchEntryBox
	searchEntryBox:setClearButton(true)
	
	self.search:createText()
end


ModListBox = ISScrollingListBox:derive("ModListBox")

function ModListBox:new(x, y, width, height)
	local o = ISScrollingListBox:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.drawBorder = true
	o.indexById = {}
	o.itemheight = math.max(FONT_HGT_MEDIUM + DY*2, BUTTON_HGT)
	
	o.btn = {}
	o.btn.text1 = getText("UI_NRK_ModSelector_List_Favorite")
	o.btn.text2 = getText("UI_NRK_ModSelector_List_Unfavorite")
	o.btn.text3 = getText("UI_NRK_ModSelector_List_On")
	o.btn.text4 = getText("UI_NRK_ModSelector_List_Off")
	local w1 = getTextManager():MeasureStringX(UIFont.Small, o.btn.text1)
	local w2 = getTextManager():MeasureStringX(UIFont.Small, o.btn.text2)
	local w3 = getTextManager():MeasureStringX(UIFont.Small, o.btn.text3)
	local w4 = getTextManager():MeasureStringX(UIFont.Small, o.btn.text4)
	o.btn.w1 = math.max(w2, (math.max(w1, math.max(w3, w4)) + DX)*2) + DX
	o.btn.w2 = (o.btn.w1 - DX)/2
	o.btn.x1 = o.width - (o.btn.w1 + DX)
	o.btn.x2 = o.width - (o.btn.w2 + DX)
	o.btn.dy = (o.itemheight - BUTTON_HGT)/2
	--[[
	o.item.item.modInfo
	o.item.item.modInfoExtra = {}
	o.item.item.isAvailable = true/false
	o.item.item.isActive = true/false
	o.item.item.isFavor = true/false
	o.item.item.dependents = {}
	]]
	return o
end

function ModListBox:checkFilter(item)
	local filter = self.parent.filterPanel
	
	-- tickbox filter
	if not filter.locationTickBox.selected[1] and item.modInfo:getWorkshopID() then return false end
	if not filter.locationTickBox.selected[2] and not item.modInfo:getWorkshopID() then return false end
	if not filter.mapTickBox.selected[1] and item.modInfoExtra.maps then return false end
	if not filter.mapTickBox.selected[2] and not item.modInfoExtra.maps then return false end
	if not filter.translateTickBox.selected[1] and item.modInfoExtra.translate then return false end
	if not filter.translateTickBox.selected[2] and not item.modInfoExtra.translate then return false end
	if not filter.availabilityTickBox.selected[1] and item.isAvailable then return false end
	if not filter.availabilityTickBox.selected[2] and not item.isAvailable then return false end
	if not filter.statusTickBox.selected[1] and item.isActive then return false end
	if not filter.statusTickBox.selected[2] and not item.isActive then return false end
	if not filter.favorTickBox.selected[1] and item.isFavor then return false end
	if not filter.favorTickBox.selected[2] and not item.isFavor then return false end
	
	-- search filter
	local keyWord = filter.searchEntryBox:getText() or ""
	
	local tableForFind = {}
	if filter.searchby2.selected[1] then
		table.insert(tableForFind, item.modInfo:getWorkshopID())
	elseif filter.searchby2.selected[2] then
		for _, map in ipairs(item.modInfoExtra.maps or {}) do
			table.insert(tableForFind, map)
		end
	elseif filter.searchby2.selected[3] then
		table.insert(tableForFind, item.modInfoExtra.pzversion)
	elseif filter.searchby2.selected[4] then
		for _, t in ipairs(item.modInfoExtra.tags or {}) do
			table.insert(tableForFind, t)
		end
		for _, t in ipairs(self.parent.customtags[item.modInfo:getId()] or {}) do
			table.insert(tableForFind, t)
		end
	elseif filter.searchby2.selected[5] then
		for _, author in ipairs(item.modInfoExtra.authors or {}) do
			table.insert(tableForFind, author)
		end
	else
		if filter.searchby1.selected[1] then
			table.insert(tableForFind, item.modInfo:getName())
		end
		if filter.searchby1.selected[2] then
			table.insert(tableForFind, item.modInfo:getDescription())
			table.insert(tableForFind, item.modInfoExtra.description)
		end
		if filter.searchby1.selected[3] then
			table.insert(tableForFind, item.modInfo:getId())
		end
	end
	
	if filter.searchas1.selected[1] then -- Equal
		if keyWord == "" then return true end
		for _, s in ipairs(tableForFind) do
			if s == keyWord then return true end
		end
	elseif filter.searchas1.selected[2] then -- Contain
		if keyWord == "" then return true end
		for _, s in ipairs(tableForFind) do
			if string.find(string.lower(s), string.lower(keyWord), 1, true) ~= nil then return true end
		end
	elseif filter.searchas1.selected[3] then -- Empty
		if #tableForFind == 0 then return true end
	elseif filter.searchas2.selected[1] then -- noEqual
		if keyWord == "" then return true end
		local noequal = true
		for _, s in ipairs(tableForFind) do 
			if s == keyWord then noequal = false end
		end
		return noequal
	elseif filter.searchas2.selected[2] then -- noContain
		if keyWord == "" then return true end
		local nocontain = true
		for _, s in ipairs(tableForFind) do
			if string.find(string.lower(s), string.lower(keyWord), 1, true) ~= nil then nocontain = false end
		end
		return nocontain
	elseif filter.searchas2.selected[3] then -- noEmpty
		if #tableForFind > 0 then return true end
	end
	
	return false
end

function ModListBox:doDrawButton(text, internal, x, y, w, h)
	local selected = self.mouseoverselected
	local color = {a = 1.0, r = 0.0, g = 0.0, b = 0.0}
	
	if self:getMouseX() > x and self:getMouseX() < x + w and self:getMouseY() > y and self:getMouseY() < y + h then
		if self.pressedbutton and self.pressedbutton.internal == internal and self.pressedbutton.selected == selected then
			color = {a = 1.0, r = 0.15, g = 0.15, b = 0.15}
		else
			color = {a = 1.0, r = 0.3, g = 0.3, b = 0.3}
		end
		self.mouseoverbutton = {internal = internal, selected = selected}
	elseif self.mouseoverbutton and self.mouseoverbutton.internal == internal and self.mouseoverbutton.selected == selected then
		self.mouseoverbutton = nil
	end
	
	self:drawRect(x, y, w, h, color.a, color.r, color.g, color.b)
	self:drawRectBorder(x, y, w, h, 0.1, 1.0, 1.0, 1.0)
	self:drawTextCentre(
		text, x + w/2, y + (BUTTON_HGT - FONT_HGT_SMALL)/2,
		1.0, 1.0, 1.0, 1.0, UIFont.Small
	)
end

function ModListBox:doDrawItem(y, i, alt)
	local index, item = i.index, i.item
	if not self:checkFilter(item) then return y end
	
	local h, s = self.itemheight, self:isVScrollBarVisible() and 13 or 0
	
	-- item bar
	if self.selected == index then
		self:drawRect(0, y, self:getWidth(), h, 0.3, 0.7, 0.35, 0.15)
	elseif self.mouseoverselected == index and not self:isMouseOverScrollBar() then
		self:drawRect(0, y, self:getWidth(), h, 0.95, 0.05, 0.05, 0.05)
	end
	self:drawRectBorder(0, y, self:getWidth(), h, 0.5, self.borderColor.r, self.borderColor.g, self.borderColor.b)
	
	-- icon
	local icon = item.modInfoExtra.icon or item.modInfoExtra.maps and MAP_ICON or DEFAULT_ICON
	self:drawTextureScaled(icon, DX, y + DY, FONT_HGT_MEDIUM, FONT_HGT_MEDIUM, 1)
	if not item.isAvailable then
		self:drawTexture(BROKEN_ICON, DX + FONT_HGT_MEDIUM - 5, y + DY + FONT_HGT_MEDIUM - 7, 1)
	elseif item.isActive then
		local dependents = {}
		for _, dependentId in ipairs(item.dependents or {}) do
			if self.items[self.indexById[dependentId]].item.isActive then
				table.insert(dependents, dependentId)
			end
		end
		if #dependents > 0 then
			self:drawTexture(REQUIRE_ICON, DX + FONT_HGT_MEDIUM - 5, y + DY + FONT_HGT_MEDIUM - 7, 1)
		else
			self:drawTexture(ACTIVE_ICON, DX + FONT_HGT_MEDIUM - 5, y + DY + FONT_HGT_MEDIUM - 7, 1)
		end
		if item.isFavor then
			self:drawTexture(FAVORITE_ICON, DX + FONT_HGT_MEDIUM - 6, y + DY, 1)
		end
	end
	
	-- title
	local text, r, g, b = item.modInfo:getName(), 1, 1, 1
	if not item.isAvailable then
		text = text .. getText("UI_NRK_ModSelector_Status_Broken")
		g, b = 0.5, 0.5
	elseif item.isActive then
		local dependents = {}
		for _, dependentId in ipairs(item.dependents or {}) do
			if self.items[self.indexById[dependentId]].item.isActive then
				table.insert(dependents, dependentId)
			end
		end
		if #dependents > 0 then
			text = text .. getText("UI_NRK_ModSelector_Status_EnabledBy", table.concat(dependents, ", "))
			g, b = 0.7, 0.2
		else
			text = text .. getText("UI_NRK_ModSelector_Status_Enabled")
			r, b = 0.5, 0.5
		end
	end
	self:drawText(text, DX + FONT_HGT_MEDIUM + DX, y + DY, r, g, b, 1, UIFont.Medium)
	
	-- buttons
	if self.mouseoverselected == index and not self:isMouseOverScrollBar() and item.isAvailable then
		if item.isFavor then
			self:doDrawButton(self.btn.text2, "UNFAVOR", self.btn.x1 - s, y + self.btn.dy, self.btn.w1, BUTTON_HGT)
		else
			self:doDrawButton(self.btn.text1, "FAVOR", self.btn.x1 - s, y + self.btn.dy, self.btn.w2, BUTTON_HGT)
			if item.isActive then
				self:doDrawButton(self.btn.text4, "OFF", self.btn.x2 - s, y + self.btn.dy, self.btn.w2, BUTTON_HGT)
			else
				self:doDrawButton(self.btn.text3, "ON", self.btn.x2 - s, y + self.btn.dy, self.btn.w2, BUTTON_HGT)
			end
		end
	end
	
	y = y + h + 1
	return y
end

function ModListBox:doActiveRequest(item, doFavor)
	local pzversion = tonumber(item.modInfoExtra.pzversion)
	if pzversion and pzversion < 41 then -- TODO: get current version
		local modal = ISModalDialog:new(
			(getCore():getScreenWidth() - 230)/2,
			(getCore():getScreenHeight() - 120)/2,
			230, 120,
			getText("UI_NRK_ModSelector_List_Warning_OldMod", item.modInfo:getId(), pzversion),
			true, self,
			function (target, button, param1, param2)
				if button.internal == "YES" then
					target:doActive(param1, param2)
				end
			end,
			nil, item, doFavor
		)
		modal:initialise()
		modal:setCapture(true)
		modal:setAlwaysOnTop(true)
		modal:addToUIManager()
	else
		self:doActive(item, doFavor)
	end
end

function ModListBox:doActive(item, doFavor)
	local modId = item.modInfo:getId()
	print(NRKLOG, "do Active", modId, doFavor)
	
	if item.isActive == false then
		item.isActive = true
		self.parent.counters.enabled = self.parent.counters.enabled + 1
	end
	
	if doFavor then
		item.isFavor = true
		self.parent.counters.favor = self.parent.counters.favor + 1
	end
	
	local requires = item.modInfo:getRequire()
	if requires and not requires:isEmpty() then
		for i = 0, requires:size() - 1 do
			self:doActive(self.items[self.indexById[requires:get(i)]].item, doFavor)
		end
	end
	
end

function ModListBox:doInactive(item)
	if item.isActive == false then return end
	
	local modId = item.modInfo:getId()
	print(NRKLOG, "do Inactive", modId)
	
	self.parent.counters.enabled = self.parent.counters.enabled - 1
	if item.isFavor then self.parent.counters.favor = self.parent.counters.favor - 1 end
	item.isActive = false
	item.isFavor = false
	
	for _, dependentId in ipairs(item.dependents or {}) do
		self:doInactive(self.items[self.indexById[dependentId]].item)
	end
end

function ModListBox:onMouseMove(dx, dy)
	if self:isMouseOverScrollBar() then
		self.mouseoverbutton = nil
		return
	end
	self.mouseoverselected = self:rowAt(self:getMouseX(), self:getMouseY())
	if self.mouseoverbutton and self.mouseoverbutton.selected ~= self.mouseoverselected then
		self.mouseoverbutton = nil
	end
end

function ModListBox:onMouseMoveOutside(x, y)
	self.mouseoverselected = -1
	self.mouseoverbutton = nil
end

function ModListBox:onMouseDown(x, y)
	if self.mouseoverbutton then
		self.pressedbutton = self.mouseoverbutton
	else
		ISScrollingListBox.onMouseDown(self, x, y)
	end
end

function ModListBox:onMouseUp(x, y)
	if self.mouseoverbutton and self.pressedbutton and self.mouseoverbutton.internal == self.pressedbutton.internal and self.mouseoverbutton.selected == self.pressedbutton.selected then
		local item = self.items[self.pressedbutton.selected].item
		if self.pressedbutton.internal == "ON" then
			self:doActiveRequest(item)
		elseif self.pressedbutton.internal == "OFF" then
			self:doInactive(item)
		elseif self.pressedbutton.internal == "FAVOR" then
			self:doActiveRequest(item, true)
		elseif self.pressedbutton.internal == "UNFAVOR" then
			self:doInactive(item)
		end
		self.mouseoverbutton = nil
		self.pressedbutton = nil
	else
		self.pressedbutton = nil
		ISScrollingListBox.onMouseUp(self, x, y)
	end
end

function ModListBox:onMouseUpOutside(x, y)
	self.pressedbutton = nil
--	ISScrollingListBox.onMouseUpOutside(self, x, y) -- call error "attempted index: onMouseUpOutside of non-table" when "reload lua" and mouse cursor outside the panel
	if self.vscroll then self.vscroll.scrolling = false end
end

function ModListBox:onMouseDoubleClick(x, y)
	if self:isMouseOverScrollBar() then
		return
	end
	
	if self.mouseoverbutton then
		self.pressedbutton = self.mouseoverbutton
		return
	end
	
	local item = self.items[self.selected].item
	if not item.isAvailable then return end
	
	if not item.isActive then
		self:doActiveRequest(item)
	else
		self:doInactive(item)
	end
end


ModPanelInfo = ISPanelJoypad:derive("ModPanelInfo")

function ModPanelInfo:new(x, y, width, height)
	local o = ISPanelJoypad:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.scrollwidth = 13
	o.extrainfo = true
	o.selected = 0
	return o
end

function ModPanelInfo:createChildren()
	-- workshop Label, Entry, Button
	self.workshopLabel = ISLabel:new(
		DX, 4, FONT_HGT_SMALL, getText("UI_NRK_ModSelector_Info_WorkshopLable"),
		1, 1, 1, 1, UIFont.Small, true
	)
	self.workshopLabel:setVisible(false)
	self:addChild(self.workshopLabel)
	
	self.workshopEntry = ISTextEntryBox:new("",
		self.workshopLabel:getRight() + DX, 2,
		self.width - (BUTTON_WDH + DX*2 + self.scrollwidth) - (self.workshopLabel:getRight() + DX), FONT_HGT_SMALL + 2*2
	)
	self.workshopEntry:setVisible(false)
	self:addChild(self.workshopEntry)
	self.workshopEntry:setEditable(false)
	self.workshopEntry:setSelectable(true)
	
	self.workshopButton = ISButton:new(
		self.width - (BUTTON_WDH + DX + self.scrollwidth), 0, BUTTON_WDH, BUTTON_HGT,
		getText("UI_NRK_ModSelector_Info_FollowButton"), self, self.onGoButton
	)
	self.workshopButton.tooltip = getText("UI_NRK_ModSelector_Info_WorkshopTooltip")
	self.workshopButton.internal = "WORKSHOP"
	self.workshopButton.borderColor = {r=1, g=1, b=1, a=0.1}
	self.workshopButton:setAnchorLeft(false)
	self.workshopButton:setAnchorRight(true)
	self.workshopButton:setVisible(false)
	self.workshopButton:setWidth(BUTTON_WDH) -- suppress auto setWidthToTitle
	self:addChild(self.workshopButton)
	
	-- url Label, Entry, Button
	self.urlLabel = ISLabel:new(
		DX, 4, FONT_HGT_SMALL, getText("UI_NRK_ModSelector_Info_URLLabel"),
		1, 1, 1, 1, UIFont.Small, true
	)
	self.urlLabel:setVisible(false)
	self:addChild(self.urlLabel)
	
	self.urlEntry = ISTextEntryBox:new("",
		self.urlLabel:getRight() + DX, 2,
		self.width - (BUTTON_WDH + DX*2 + self.scrollwidth) - (self.urlLabel:getRight() + DX), FONT_HGT_SMALL + 2*2
	)
	self.urlEntry:setVisible(false)
	self:addChild(self.urlEntry)
	self.urlEntry:setEditable(false)
	self.urlEntry:setSelectable(true)
	
	self.urlButton = ISButton:new(
		self.width - (BUTTON_WDH + DX + self.scrollwidth), 0, BUTTON_WDH, BUTTON_HGT,
		getText("UI_NRK_ModSelector_Info_FollowButton"), self, self.onGoButton
	)
	self.urlButton.tooltip = getText("UI_NRK_ModSelector_Info_URLTooltip")
	self.urlButton.internal = "URL"
	self.urlButton.borderColor = {r=1, g=1, b=1, a=0.1}
	self.urlButton:setAnchorLeft(false)
	self.urlButton:setAnchorRight(true)
	self.urlButton:setVisible(false)
	self.urlButton:setWidth(BUTTON_WDH) -- suppress auto setWidthToTitle
	self:addChild(self.urlButton)
	
	-- location Label, Entry, Button
	self.locationLabel = ISLabel:new(
		DX, 4, FONT_HGT_SMALL, getText("UI_NRK_ModSelector_Info_LocationLabel"),
		1, 1, 1, 1, UIFont.Small, true
	)
	self:addChild(self.locationLabel)
	
	self.locationEntry = ISTextEntryBox:new("",
		self.locationLabel:getRight() + DX, 2,
		self.width - (BUTTON_WDH + DX*2 + self.scrollwidth) - (self.locationLabel:getRight() + DX), FONT_HGT_SMALL + 2*2
	)
	self:addChild(self.locationEntry)
	self.locationEntry:setEditable(false)
	self.locationEntry:setSelectable(true)
	
	self.locationButton = ISButton:new(
		self.width - (BUTTON_WDH + DX + self.scrollwidth), 0, BUTTON_WDH, BUTTON_HGT,
		getText("UI_NRK_ModSelector_Info_FollowButton"), self, self.onGoButton
	)
	self.locationButton.tooltip = getText("UI_NRK_ModSelector_Info_LocationTooltip")
	self.locationButton.internal = "LOCATION"
	self.locationButton.borderColor = {r=1, g=1, b=1, a=0.1}
	self.locationButton:setAnchorLeft(false)
	self.locationButton:setAnchorRight(true)
	self.locationButton:setWidth(BUTTON_WDH) -- suppress auto setWidthToTitle
	self:addChild(self.locationButton)
	
	-- richText
	self.extraButton = ISButton:new(
		DX, 0, DX, BUTTON_HGT,
		"", self,
		function()
			self.extrainfo = not self.extrainfo
			self.extraButton:setImage(self.extrainfo and EXPANDED_ICON or COLLAPSED_ICON)
		end
	)
	self.extraButton:setDisplayBackground(false)
	self.extraButton:setImage(self.extrainfo and EXPANDED_ICON or COLLAPSED_ICON)
	self:addChild(self.extraButton)
	
	self.extraButton2 = ISButton:new(
		self.extraButton:getRight(), 0, BUTTON_WDH, BUTTON_HGT,
		getText("UI_NRK_ModSelector_Info_ExtraInfo"), self,
		function()
			self.extrainfo = not self.extrainfo
			self.extraButton:setImage(self.extrainfo and EXPANDED_ICON or COLLAPSED_ICON)
		end
	)
	self.extraButton2:setWidthToTitle()
	self.extraButton2:setDisplayBackground(false)
	self:addChild(self.extraButton2)
	
	self.descRichText = ISRichTextLayout:new(self.width - self.scrollwidth)
	self.descRichText:setMargins(DX, DY, DX, DY)
	self.extraRichText = ISRichTextLayout:new(self.width - self.scrollwidth)
	self.extraRichText:setMargins(DX, DY, DX, DY)

	self.customTagsButton = ISButton:new(
		DX, 0, self.width - (DX*2 + self.scrollwidth), BUTTON_HGT,
		getText("UI_NRK_ModSelector_Info_TagsButton"), self, self.onCustomTagsDialog
	)
	self.customTagsButton.borderColor = {r=1, g=1, b=1, a=0.1}
	self:addChild(self.customTagsButton)
end

function ModPanelInfo:prerender()
	local i = self.parent.listBox.selected
	if self.selected ~= i then
		local item = self.parent.listBox.items[i].item
		local color_d, color_l = " <RGB:0.7,0.7,0.7> ", " <RGB:0.9,0.9,0.9> "
		
		-- formation name & description
		local name = item.modInfo:getName()
		local desc = item.modInfoExtra.description or item.modInfo:getDescription() or ""
		local full_desc = " <H1> " .. name .. " <LINE> <TEXT> " .. desc .. " <LINE> "
		self.descRichText:setText(full_desc)
		self.descRichText:paginate()
		
		-- formation extra info
		local extra_desc = " <TEXT> " .. color_l .. getText("UI_NRK_ModSelector_Info_ModId") ..
		  " " .. color_d .. item.modInfo:getId() .. " <LINE> "
		
		if item.modInfoExtra.modversion ~= nil then
			extra_desc = extra_desc .. color_l .. getText("UI_NRK_ModSelector_Info_ModVersion") ..
			  " " .. color_d .. item.modInfoExtra.modversion .. " <LINE> "
		end
		
		if item.modInfoExtra.pzversion ~= nil then
			extra_desc = extra_desc .. color_l.. getText("UI_NRK_ModSelector_Info_PZVersion") ..
			  " " .. color_d .. item.modInfoExtra.pzversion .. " <LINE> "
		end
		
		local tags, customtags = item.modInfoExtra.tags or {}, self.parent.customtags[item.modInfo:getId()] or {}
		if #tags + #customtags > 1 then
			extra_desc = extra_desc .. color_l .. getText("UI_NRK_ModSelector_Info_Tags") ..
			  color_d .. " <LINE> <INDENT:" .. tostring(DX) .. "> "
			for _ , tag in ipairs(tags) do
				extra_desc = extra_desc .. "- " .. tag .. " <LINE> "
			end
			for _ , tag in ipairs(customtags) do
				extra_desc = extra_desc .. " <GREEN> - " .. tag .. " <LINE> "
			end
			extra_desc = extra_desc .. color_d .. " <INDENT:0> "
		elseif #tags == 1 then
			extra_desc = extra_desc .. color_l ..
			  (getTextOrNull("UI_NRK_ModSelector_Info_Tag") or getText("UI_NRK_ModSelector_Info_Tags")) ..
			  " " .. color_d .. tags[1] .. " <LINE> "
		elseif #customtags == 1 then
			extra_desc = extra_desc .. color_l ..
			  (getTextOrNull("UI_NRK_ModSelector_Info_Tag") or getText("UI_NRK_ModSelector_Info_Tags")) ..
			  " " .. " <GREEN> " .. customtags[1] .. color_d .. " <LINE> "
		end
		
		local maps = item.modInfoExtra.maps
		if maps ~= nil and #maps > 1 then
			extra_desc = extra_desc .. color_l .. getText("UI_NRK_ModSelector_Info_Maps") ..
			  color_d .. " <LINE> <INDENT:" .. tostring(DX) .. "> "
			for _ , map in ipairs(maps) do
				extra_desc = extra_desc .. "- " .. map .. " <LINE> "
			end
			extra_desc = extra_desc .. " <INDENT:0> "
		elseif maps ~= nil and #maps > 0 then
			extra_desc = extra_desc .. color_l ..
			  (getTextOrNull("UI_NRK_ModSelector_Info_Map") or getText("UI_NRK_ModSelector_Info_Maps")) ..
			  " " .. color_d .. maps[1] .. " <LINE> "
		end
		
		local requires = item.modInfo:getRequire()
		if requires and requires:size() > 1 then
			extra_desc = extra_desc .. color_l .. getText("UI_NRK_ModSelector_Info_Requires") ..
			  color_d .. " <LINE> <INDENT:" .. tostring(DX) .. "> "
			for i = 0, requires:size() - 1 do
				local requireId = requires:get(i)
				local requireItem = self.parent.listBox.items[self.parent.listBox.indexById[requireId]]
				if requireItem ~= nil and requireItem.item.isAvailable then
					extra_desc = extra_desc .. "- " .. requireId .. " <LINE> "
				else
					extra_desc = extra_desc .. " <RED> - " .. requireId .. color_d .. " <LINE> "
				end
			end
			extra_desc = extra_desc .. " <INDENT:0> "
		elseif requires and not requires:isEmpty() then
			extra_desc = extra_desc .. color_l ..
			  (getTextOrNull("UI_NRK_ModSelector_Info_Require") or getText("UI_NRK_ModSelector_Info_Requires")) ..
			  " " .. color_d
			local requireId = requires:get(0)
			local requireItem = self.parent.listBox.items[self.parent.listBox.indexById[requireId]]
			if requireItem ~= nil and requireItem.item.isAvailable then
				extra_desc = extra_desc .. " " .. requireId .. " <LINE> "
			else
				extra_desc = extra_desc .. "  <RED> " .. requireId .. color_d .. " <LINE> "
			end
		end
		
		local authors = item.modInfoExtra.authors
		if authors ~= nil and #authors > 1 then
			extra_desc = extra_desc .. color_l .. getText("UI_NRK_ModSelector_Info_Authors") ..
			  color_d .. " <LINE> <INDENT:" .. tostring(DX) .. "> "
			for _, author in ipairs(authors) do
				extra_desc = extra_desc .. "- " .. author .. " <LINE> "
			end
			extra_desc = extra_desc .. " <INDENT:0> "
		elseif authors ~= nil and #authors > 0 then
			extra_desc = extra_desc .. color_l .. 
			  (getTextOrNull("UI_NRK_ModSelector_Info_Author") or getText("UI_NRK_ModSelector_Info_Authors")) ..
			  " " .. color_d .. authors[1] .. " <LINE> "
		end
		
		self.extraRichText:setText(extra_desc)
		self.extraRichText:paginate()
		
		-- formation links
		if getSteamModeActive() and item.modInfo:getWorkshopID() then
			self.workshopLabel:setVisible(true)
			self.workshopEntry:setVisible(true)
			self.workshopButton:setVisible(true)
			self.workshopEntry:setText(item.modInfo:getWorkshopID())
		else
			self.workshopLabel:setVisible(false)
			self.workshopEntry:setVisible(false)
			self.workshopButton:setVisible(false)
			self.workshopEntry:setText("")
		end
		
		if item.modInfo:getUrl() ~= nil and item.modInfo:getUrl() ~= "" then
			self.urlLabel:setVisible(true)
			self.urlEntry:setVisible(true)
			self.urlButton:setVisible(true)
			self.urlButton.tooltip = getText("UI_NRK_ModSelector_Info_URLTooltip")
			self.urlEntry:setText(item.modInfo:getUrl())
		elseif item.modInfoExtra.url ~= nil and item.modInfoExtra.url ~= "" then
			self.urlLabel:setVisible(true)
			self.urlEntry:setVisible(true)
			self.urlButton:setVisible(true)
			self.urlButton.tooltip = getText("UI_NRK_ModSelector_Info_URLTooltip") .. " " .. getText("UI_NRK_ModSelector_Info_URLWarning")
			self.urlEntry:setText(item.modInfoExtra.url)
		else
			self.urlLabel:setVisible(false)
			self.urlEntry:setVisible(false)
			self.urlButton:setVisible(false)
			self.urlEntry:setText("")
		end
		
		self.locationEntry:setText(item.modInfo:getDir())
		
		self.selected = i
	end
	
	if self.width - self.scrollwidth ~= self.descRichText.width then
		self.descRichText:setWidth(self.width - self.scrollwidth)
		self.descRichText:paginate()
	end
	if self.width - self.scrollwidth ~= self.extraRichText.width then
		self.extraRichText:setWidth(self.width - self.scrollwidth)
		self.extraRichText:paginate()
	end
	
	local bottom = self.descRichText:getHeight() + DY
	
	self.extraButton:setY(bottom)
	self.extraButton2:setY(bottom)
	bottom = self.extraButton:getBottom() + DY
	
	if self.extrainfo then
		bottom = bottom + self.extraRichText:getHeight() + DY
	else
		bottom = bottom + DY
	end
	
	if self.workshopButton:isVisible() then
		self.workshopLabel:setY(bottom + 4)
		self.workshopEntry:setY(bottom + 2)
		self.workshopButton:setY(bottom)
		bottom = self.workshopButton:getBottom() + DY
	end
	
	if self.urlButton:isVisible() then
		self.urlLabel:setY(bottom + 4)
		self.urlEntry:setY(bottom + 2)
		self.urlButton:setY(bottom)
		bottom = self.urlButton:getBottom() + DY
	end
	
	self.locationLabel:setY(bottom + 4)
	self.locationEntry:setY(bottom + 2)
	self.locationButton:setY(bottom)
	bottom = self.locationButton:getBottom() + DY
	
	self.customTagsButton:setY(bottom)
	bottom = self.customTagsButton:getBottom() + DY
	
	self:setScrollHeight(bottom)
	self:setStencilRect(0, 0, self:getWidth(), self:getHeight())
	
	ISPanelJoypad.prerender(self)
end

function ModPanelInfo:render()
	ISPanelJoypad.render(self)
	
	self.descRichText:render(0, 0, self)
	if self.extrainfo then
		self.extraRichText:render(0, self.extraButton:getBottom(), self)
	end
	self:clearStencilRect()
	self:drawRectBorderStatic(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
end

function ModPanelInfo:onMouseWheel(del)
	self:setYScroll(self:getYScroll() - (del * 40))
	return true
end

function ModPanelInfo:onGoButton(button)
	if button.internal == "URL" then
		if isSteamOverlayEnabled() then
			activateSteamOverlayToWebPage(self.urlEntry.title)
		else
			openUrl(self.urlEntry.title)
		end
	elseif button.internal == "WORKSHOP" then
		if isSteamOverlayEnabled() then
			activateSteamOverlayToWorkshopItem(self.workshopEntry.title)
		else
			openUrl(string.format("https://steamcommunity.com/sharedfiles/filedetails/?id=%s", self.workshopEntry.title))
		end
	elseif button.internal == "LOCATION" then
		showFolderInDesktop(self.locationEntry.title)
	end
end

function ModPanelInfo:onValidateCustomTags(text)
	return not text:contains(":")
end

function ModPanelInfo:onCustomTagsDialog()
	local modId = self.parent.listBox.items[self.selected].item.modInfo:getId()
	local text = table.concat(self.parent.customtags[modId] or {}, ",") 
	local modal = ISTextBox:new(
		(getCore():getScreenWidth() / 2) - 140,
		(getCore():getScreenHeight() / 2) - 90,
		280, 180,
		getText("UI_NRK_ModSelector_Info_TagsButton_Request", modId),
		text, self, self.onCustomTagsConfirm
	)
	modal.validateTooltipText = getText("UI_NRK_ModSelector_Info_TagsButton_Warning")
	modal:initialise()
	modal:setCapture(true)
	modal:setAlwaysOnTop(true)
	modal:setValidateFunction(self, self.onValidateCustomTags)
	modal:addToUIManager()
	
	modal.addComboBox = ISComboBox:new(
		modal.entry:getX(), modal.entry:getBottom() + DY, (modal.entry:getWidth() - DX)/2, BUTTON_HGT, modal,
		function (modal)
			local tags = luautils.split(modal.entry:getText(), ",")
			local addtag = modal.addComboBox:getOptionData(modal.addComboBox.selected)
			table.insert(tags, addtag)
			modal.entry:setText(table.concat(tags, ","))
			modal.entry:onTextChange()
		end
	)
	modal.addComboBox.noSelectionText = getText("UI_NRK_ModSelector_Info_TagsCombo_Add")
	modal.addComboBox.image = PLUS_ICON
	modal:addChild(modal.addComboBox)
	
	modal.delComboBox = ISComboBox:new(
		modal.addComboBox:getRight() + DX, modal.entry:getBottom() + DY, (modal.entry:getWidth() - DX)/2, BUTTON_HGT, modal,
		function (modal)
			local index = modal.delComboBox.selected
			if modal.delComboBox:getOptionData(index) == "all" then
				modal.entry:setText("")
			else
				local tags, deltag = {}, modal.delComboBox:getOptionText(index)
				for _, tag in ipairs(luautils.split(modal.entry:getText(), ",")) do
					if tag ~= deltag then
						table.insert(tags, tag)
					end
				end
				modal.entry:setText(table.concat(tags, ","))
			end
			modal.entry:onTextChange()
		end
	)
	modal.delComboBox.noSelectionText = getText("UI_NRK_ModSelector_Info_TagsCombo_Del")
	modal.delComboBox.image = MINUS_ICON
	modal:addChild(modal.delComboBox)
	
	modal.entry.onTextChange = function(entry)
		local current_tags_d = luautils.split(entry:getInternalText(), ",") -- no entry:getText() - it's return previous text
		local current_tags_a = {}
		for _, tag in ipairs(current_tags_d) do
			current_tags_a[tag] = true
		end
		local all_tags = {}
		for tag, _ in pairs(self.parent.counters.customtags) do
			if not current_tags_a[tag] then
				table.insert(all_tags, tag)
			end
		end
		table.sort(all_tags)
		
		if #all_tags == 0 then
			entry.parent.addComboBox.disabled = true
		else
			entry.parent.addComboBox:clear()
			for _, tag in ipairs(all_tags) do
				local count = self.parent.counters.customtags[tag]
				entry.parent.addComboBox:addOptionWithData(tag .. " [" .. tostring(count) .. "]", tag)
			end
			entry.parent.addComboBox.disabled = false
		end
		entry.parent.addComboBox.selected = 0
		
		if #current_tags_d == 0 then
			entry.parent.delComboBox.disabled = true
		else
			entry.parent.delComboBox:clear()
			entry.parent.delComboBox:addOptionWithData(getText("UI_NRK_ModSelector_Info_TagsCombo_All"), "all")
			for _, tag in ipairs(current_tags_d) do
				entry.parent.delComboBox:addOption(tag)
			end
			entry.parent.delComboBox.disabled = false
		end
		entry.parent.delComboBox.selected = 0
	end
	
	modal.entry:onTextChange()
end

function ModPanelInfo:onCustomTagsConfirm(button)
	if button.internal == "OK" then
		local modId = self.parent.listBox.items[self.selected].item.modInfo:getId()
		local text = button.parent.entry:getText()
		local old_tags, new_tags = {}, {}
		for _, tag in ipairs(self.parent.customtags[modId] or {}) do
			old_tags[tag] = true
		end
		for _, tag in ipairs(luautils.split(text, ",")) do
			new_tags[tag] = true
		end
		
		-- update tags and counts
		for tag, _ in pairs(old_tags) do
			if not new_tags[tag] then
				self.parent.counters.customtags[tag] = self.parent.counters.customtags[tag] - 1
			end
		end
		self.parent.customtags[modId] = {}
		for tag, _ in pairs(new_tags) do
			self.parent.counters.customtags[tag] = (self.parent.counters.customtags[tag] or 0) + 1
			table.insert(self.parent.customtags[modId], tag)
		end
		table.sort(self.parent.customtags[modId])
		
		-- write to file
		local file = getFileWriter(self.parent.customtagsfile, true, false)
		for id, tags in pairs(self.parent.customtags) do
			if #tags > 0 then
				file:write(id..":"..table.concat(tags, ",").."\n")
			end
		end
		file:close()
		
		-- for force update info-panel
		self.selected = self.selected + 1
		
		-- update dropdown list for searchstring
		if self.parent.filterPanel.searchby2.selected[4] then
			self.parent.filterPanel.searchEntryBox.options = {}
			local tags = {}
			for i, j in pairs(self.parent.counters.originaltags) do
				tags[i] = j
			end
			for i, j in pairs(self.parent.counters.customtags) do
				tags[i] = (tags[i] or 0) + j
			end
			for i, j in pairs(tags) do
				self.parent.filterPanel.searchEntryBox:addOption(i, j)
			end
		end
	end
end


ModPanelPoster = ISPanelJoypad:derive("ModPanelPoster")

function ModPanelPoster:new(x, y, width, height)
	local o = ISPanelJoypad:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.selectedmod = 0
	o.selectedposter = 0
	o.expanded = false
	o.textures = {}
	return o
end

function ModPanelPoster:createChildren()
	local w, h = 2*self.width/3, 2*self.height/3
	local x, y = (self.width - w)/2, (self.height - h)/2
	
	self.leftImage = ISImage:new(DX, y + h/4, w/2, h/2, nil)
	self.leftImage.target = self
	self.leftImage.onclick = self.prevPoster
	self:addChild(self.leftImage)
	
	self.rightImage = ISImage:new(self.width - (DX + w/2), y + h/4, w/2, h/2, nil)
	self.rightImage.target = self
	self.rightImage.onclick = self.nextPoster
	self:addChild(self.rightImage)
	
	self.centerImage = ISImage:new(x, y, w, h, nil)
	self.centerImage.font = UIFont.Medium
	self.centerImage.target = self
	self.centerImage.onclick = self.expandPoster
	self:addChild(self.centerImage)
end

function ModPanelPoster:prerender()
	local index = self.parent.listBox.selected
	if self.selectedmod ~= index then
		local modInfo = self.parent.listBox.items[index].item.modInfo
		self.textures = {}
		self.postercount = modInfo:getPosterCount()
		for id = 0, modInfo:getPosterCount() - 1 do
			table.insert(self.textures, getTexture(modInfo:getPoster(id)))
		end
		
		self.selectedmod = index
		self.selectedposter = math.min(#self.textures, 1)
		self.expanded = false
		self:update()
	end
	
	ISPanelJoypad.prerender(self)
end

function ModPanelPoster:update()
	if #self.textures == 0 then
		self.centerImage.name = getText("UI_NRK_ModSelector_NoPoster")
		self.centerImage:setWidth(getTextManager():MeasureStringX(self.centerImage.font, self.centerImage.name))
		self.centerImage:setHeight(getTextManager():getFontHeight(self.centerImage.font))
		self.centerImage:setX((self.width - self.centerImage.width)/2)
		self.centerImage:setY((self.height - self.centerImage.height)/2)
		self.centerImage.texture = nil
		self.leftImage.texture = nil
		self.rightImage.texture = nil
	elseif #self.textures == 1 or self.expanded then
		self.centerImage.name = ""
		local texture = self.textures[self.selectedposter]
		local k = math.min((self.width - 4)/texture:getWidth(), (self.height - 4)/texture:getHeight())
		local w, h = texture:getWidth()*k, texture:getHeight()*k
		self.centerImage.scaledWidth = w
		self.centerImage.scaledHeight = h
		self.centerImage:setWidth(w)
		self.centerImage:setHeight(h)
		self.centerImage:setX((self.width - w)/2)
		self.centerImage:setY((self.height - h)/2)
		self.centerImage.texture = texture
		self.leftImage.texture = nil
		self.rightImage.texture = nil
	else
		self.centerImage.name = ""
		local w, h = 2*self.width/3, 2*self.height/3
		local x, y = (self.width - w)/2, (self.height - h)/2
		local textures = {
			leftImage = {
				texture = self.textures[self.selectedposter - 1],
				w_def = w/2, h_def = h/2,
				x_def = x - (w/2)/3, y_def = y + (h/2)/2
			},
			centerImage = {
				texture = self.textures[self.selectedposter],
				w_def = w, h_def = h,
				x_def = x, y_def = y
			},
			rightImage = {
				texture = self.textures[self.selectedposter + 1],
				w_def = w/2, h_def = h/2,
				x_def = x + w - 2*(w/2)/3, y_def = y + (h/2)/2
			}
		}
		for i, t in pairs(textures) do
			if t.texture then
				local k = math.min(t.w_def/t.texture:getWidth(), t.h_def/t.texture:getHeight())
				local w_new, h_new = t.texture:getWidth()*k, t.texture:getHeight()*k
				self[i].scaledWidth = w_new
				self[i].scaledHeight = h_new
				self[i]:setWidth(w_new)
				self[i]:setHeight(h_new)
				self[i]:setX(t.x_def + (t.w_def - w_new)/2)
				self[i]:setY(t.y_def + (t.h_def - h_new)/2)
			end
			self[i].texture = t.texture
		end
	end
end

function ModPanelPoster:render()
	local l = {r = 0.4, g = 0.4, b = 0.4, a = 1}
	local r = {r = 0.4, g = 0.4, b = 0.4, a = 1}
	local c = {r = 0.4, g = 0.4, b = 0.4, a = 1}
	
	if self.leftImage:getTexture() then
		if self.leftImage:isMouseOver() and #self.textures > 1 then l = {r = 1, g = 1, b = 1, a = 1} end
		local x, y = 0, 0
		local w, h = self.centerImage:getX() - self.leftImage:getX(), self.leftImage:getHeight()
		self.leftImage.javaObject:DrawTextureScaledColor(nil, x, y, 1, h, l.r, l.g, l.b, l.a)
		self.leftImage.javaObject:DrawTextureScaledColor(nil, x+1, y, w-1, 1, l.r, l.g, l.b, l.a)
		self.leftImage.javaObject:DrawTextureScaledColor(nil, x+1, y+h-1, w-1, 1, l.r, l.g, l.b, l.a)
	end
	if self.rightImage:getTexture() then
		if self.rightImage:isMouseOver() and #self.textures > 1 then r = {r = 1, g = 1, b = 1, a = 1} end
		local x, y = self.centerImage:getRight() - self.rightImage:getX(), 0
		local w, h = self.rightImage:getRight() - self.centerImage:getRight(), self.rightImage:getHeight()
		self.rightImage.javaObject:DrawTextureScaledColor(nil, x, y, w-1, 1, r.r, r.g, r.b, r.a)
		self.rightImage.javaObject:DrawTextureScaledColor(nil, x+w-1, y, 1, h, r.r, r.g, r.b, r.a)
		self.rightImage.javaObject:DrawTextureScaledColor(nil, x, y+h-1, w-1, 1, r.r, r.g, r.b, r.a)
	end
	if self.centerImage:getTexture() then
		if self.centerImage:isMouseOver() and #self.textures > 1 then c = {r = 1, g = 1, b = 1, a = 1} end
		self.centerImage:drawRectBorder(0, 0, self.centerImage:getWidth(), self.centerImage:getHeight(), c.a, c.r, c.g, c.b)
	end
end

function ModPanelPoster:expandPoster()
	if #self.textures > 1 then
		self.expanded = not self.expanded
		self:update()
	end
end

function ModPanelPoster:prevPoster()
	if self.selectedposter > 1 then
		self.selectedposter = self.selectedposter - 1
		self:update()
	end
end

function ModPanelPoster:nextPoster()
	if self.selectedposter < self.postercount then
		self.selectedposter = self.selectedposter + 1
		self:update()
	end
end

function ModPanelPoster:onMouseWheel(step)
	self.selectedposter = self.selectedposter + step
	if self.selectedposter > self.postercount then self.selectedposter = self.postercount end
	if self.selectedposter < 1 then self.selectedposter = 1 end
	self:update()
--	return true
end


ModPanelSave = ISPanelJoypad:derive("ModPanelSave")

function ModPanelSave:new(x, y, width, height)
	local o = ISPanelJoypad:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.background = false
	o.savefile = "saved_modlist.txt"
	o.savelist = {}
	return o
end

function ModPanelSave:createChildren()
	self.saveLabel = ISLabel:new(
		DX, 0, BUTTON_HGT, getText("UI_NRK_ModSelector_Save_Label"),
		1, 1, 1, 1, UIFont.Small, true
	)
	self:addChild(self.saveLabel)
	
	self.saveComboBox = ISComboBox:new(self.saveLabel:getRight() + DX, 0, BUTTON_WDH*2, BUTTON_HGT, self, self.onSelected)
	self.saveComboBox.openUpwards = true
	self.saveComboBox.noSelectionText = getText("UI_NRK_ModSelector_Save_NoSelection")
	self:addChild(self.saveComboBox)
	
	self.saveButton = ISButton:new(
		self.saveComboBox:getRight() + DX, 0, BUTTON_WDH, BUTTON_HGT,
		getText("UI_NRK_ModSelector_Save_SaveButton"), self, self.onSaveListRequest
	)
	self.saveButton.borderColor = {r=1, g=1, b=1, a=0.1}
	self.saveButton:setWidthToTitle(BUTTON_WDH)
	self:addChild(self.saveButton)
	
	self.delButton = ISButton:new(
		self.saveButton:getRight() + DX, 0, BUTTON_WDH, BUTTON_HGT,
		getText("UI_NRK_ModSelector_Save_DelButton"), self, self.onDelListRequest
	)
	self.delButton.borderColor = {r=1, g=1, b=1, a=0.1}
	self.delButton:setWidthToTitle(BUTTON_WDH)
	self.delButton:setEnable(false)
	self:addChild(self.delButton)
end

function ModPanelSave:readModList()
	self.savelist = {}
	local file = getFileReader(self.savefile, true)
	local line = file:readLine()
	while line ~= nil do
		--split name and list (by first ":", no luautils.split)
		local sep = string.find(line, ":")
		local save_name, save_list = "", ""
		if sep ~= nil then
			save_name = string.sub(line, 0, sep - 1)
			save_list = string.sub(line, sep + 1)
		end
		
		if save_name ~= "" and save_list ~= "" then
			self.savelist[save_name] = luautils.split(save_list, ";")
		end
		
		line = file:readLine()
	end
	file:close()
end

function ModPanelSave:writeModList()
	local file = getFileWriter(self.savefile, true, false)
	for save_name, save_list in pairs(self.savelist) do
		if #save_list > 0 then
			file:write(save_name..":"..table.concat(save_list, ";").."\n")
		end
	end
	file:close()
end

function ModPanelSave:updateOptions()
	self.saveComboBox:clear()
	self.saveComboBox:addOptionWithData(getText("UI_NRK_ModSelector_Save_AllDisabled"), "clear")
	self.saveComboBox:addOptionWithData(getText("UI_NRK_ModSelector_Save_List_Global"), "currentlist_global")
	self.saveComboBox:addOptionWithData(getText("UI_NRK_ModSelector_Save_List_LastSave"), "currentlist_lastsave")
	if self.parent.loadGameFolder or self.parent.isNewGame then
		self.saveComboBox:addOptionWithData(getText("UI_NRK_ModSelector_Save_List_CurrentSave"), "currentlist_currentsave")
	end
	self:readModList()
	for save_name, _ in pairs(self.savelist) do
		if save_name ~= "FavorList" then self.saveComboBox:addOptionWithData(save_name, "user") end
	end
	self.saveComboBox.selected = 0
	self.delButton:setEnable(false)
end

function ModPanelSave:onSelected()
	local selectedItem = self.saveComboBox.options[self.saveComboBox.selected]
	local name, data = selectedItem.text, selectedItem.data
	
	self.delButton:setEnable(data == "user")
	
	local activeMods = {}
	if data == "currentlist_global" then
		local mods = ActiveMods.getById("default"):getMods()
		for i = 0, mods:size() - 1 do
			activeMods[mods:get(i)] = true
		end
	elseif data == "currentlist_lastsave" then
		local latestSave = MainScreen.latestSaveGameMode .. getFileSeparator() .. MainScreen.latestSaveWorld
		local mods = getSaveInfo(latestSave).activeMods:getMods()
		for i = 0, mods:size() - 1 do
			activeMods[mods:get(i)] = true
		end
	elseif data == "currentlist_currentsave" then
		local mods = ActiveMods.getById("currentGame"):getMods()
		for i = 0, mods:size() - 1 do
			activeMods[mods:get(i)] = true
		end
	elseif data == "user" then
		for _, m in ipairs(self.savelist[name]) do
			activeMods[m] = true
		end
	end
	
	self.parent.counters.enabled = self.parent.counters.favor
	for _, item in ipairs(self.parent.listBox.items) do
		if item.item.isFavor then
			-- do nothing
		elseif activeMods[item.item.modInfo:getId()] then
			item.item.isActive = true
			self.parent.counters.enabled = self.parent.counters.enabled + 1
		else
			item.item.isActive = false
		end
	end
end

function ModPanelSave:onValidateSaveName(text)
	return not text:contains(":") and not text:contains(";") and text ~= "FavorList"
end

function ModPanelSave:onSaveListRequest()
	local name = "NewModList"
	local modal = ISTextBox:new(
		(getCore():getScreenWidth() / 2) - 140,
		(getCore():getScreenHeight() / 2) - 90,
		280, 180,
		getText("UI_NRK_ModSelector_Save_SaveButton_Request"),
		name, self, self.onSaveListConfirm
	)
	modal.maxChars = 50
	modal.noEmpty = true
	modal.validateTooltipText = getText("UI_NRK_ModSelector_Save_SaveButton_Warning")
	modal:initialise()
	modal:setCapture(true)
	modal:setAlwaysOnTop(true)
	modal:setValidateFunction(self, self.onValidateSaveName)
	modal:addToUIManager()
end

function ModPanelSave:onSaveListConfirm(button)
	if button.internal == "OK" then
		local name = button.parent.entry:getText()
		self.savelist[name] = {}
		for _, item in ipairs(self.parent.listBox.items) do
			if item.item.isActive then
				table.insert(self.savelist[name], item.item.modInfo:getId())
			end
		end
		self:writeModList()
		self:updateOptions()
		--self.saveComboBox:select(name)
		--self.delButton:setEnable(true)
	end
end

function ModPanelSave:onDelListRequest()
	local name = self.saveComboBox.options[self.saveComboBox.selected].text
	local modal = ISModalDialog:new(
		(getCore():getScreenWidth() - 230)/2,
		(getCore():getScreenHeight() - 120)/2,
		230, 120,
		getText("UI_NRK_ModSelector_Save_DelButton_Request", name),
		true, self, self.onDelListConfirm
	)
	modal:initialise()
	modal:setCapture(true)
	modal:setAlwaysOnTop(true)
	modal:addToUIManager()
end

function ModPanelSave:onDelListConfirm(button)
	if button.internal == "YES" then
		local name = self.saveComboBox.options[self.saveComboBox.selected].text
		self.savelist[name] = nil
		self:writeModList()
		self:updateOptions()
	end
end
