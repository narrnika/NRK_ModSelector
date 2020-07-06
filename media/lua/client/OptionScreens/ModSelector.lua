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

require "luautils"

local NRKLOG = "NRK_ModSelector"

local FONT_HGT_TITLE = getTextManager():getFontHeight(UIFont.Title)
local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

local BUTTON_HGT = math.max(25, FONT_HGT_SMALL + 3 * 2)
local BUTTON_WDH = 100
local DX, DY = 10, 5

local DEFAULT_ICON = getTexture("media/ui/DefaultIcon.png")
local ACTIVE_ICON = getTexture("media/ui/iconInHotbar.png")
local REQUIRE_ICON = getTexture("media/ui/icon.png")
local BROKEN_ICON = getTexture("media/ui/icon_broken.png")
local FAVORITE_ICON = getTexture("media/ui/FavoriteStar.png")
local EXPANDED_ICON = getTexture("media/ui/TreeExpanded.png")
local COLLAPSED_ICON = getTexture("media/ui/TreeCollapsed.png")


ModSelector = ISPanelJoypad:derive("ModSelector")

function ModSelector:new(x, y, width, height) -- call from MainScreen.lua
	local o = ISPanelJoypad:new(x, y, width, height)
	ModSelector.instance = o
	setmetatable(o, self)
	self.__index = self
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
	
	self.filterPanel = ModPanelFilter:new(DX, FONT_HGT_TITLE + DY*2, halfW, BUTTON_HGT*2 + DY)
	self:addChild(self.filterPanel)
	
	self.listBox = ModListBox:new(DX, self.filterPanel:getBottom(), halfW, self.height - (self.filterPanel:getBottom() + BUTTON_HGT + DY*2))
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
	
	if self.loadGameFolder then
		print(NRKLOG, "accept for LoadGameScreen")
		local saveFolder = self.loadGameFolder
		self.loadGameFolder = nil
		for _, item in ipairs(self.listBox.items) do
			local active = item.item.isActive == true or (type(item.item.isActive) == "table" and #item.item.isActive > 0)
			ActiveMods.getById("currentGame"):setModActive(item.item.modInfo:getId(), active)
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
			local active = item.item.isActive == true or (type(item.item.isActive) == "table" and #item.item.isActive > 0)
			ActiveMods.getById("currentGame"):setModActive(item.item.modInfo:getId(), active)
		end
		NewGameScreen.instance:setVisible(true, self.joyfocus)
		if ActiveMods.requiresResetLua(ActiveMods.getById("currentGame")) then
			getCore():ResetLua("currentGame", "NewGameMods")
		end
		return
	end
	
	print(NRKLOG, "accept for MainScreen")
	for _, item in ipairs(self.listBox.items) do
		local active = item.item.isActive == true or (type(item.item.isActive) == "table" and #item.item.isActive > 0)
		ActiveMods.getById("default"):setModActive(item.item.modInfo:getId(), active)
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
			-- TODO: need testing, steem or browser
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
	self.filterPanel.textFilterText:setWidth(self.filterPanel:getWidth() - self.filterPanel.textFilterText:getX())
	
	self.listBox:setWidth(halfW)
	self.listBox:setHeight(self.height - (self.filterPanel:getBottom() + BUTTON_HGT + DY*2))
	
	self.posterPanel:setX(halfW + DX*2)
	self.posterPanel:setWidth(halfW)
	self.posterPanel:setHeight(halfH)
	
	self.infoPanel:setX(halfW + DX*2)
	self.infoPanel:setWidth(halfW)
	self.infoPanel:setY(FONT_HGT_TITLE + DY*2 + halfH + DY)
	self.infoPanel:setHeight(halfH)
	self.infoPanel.workshopEntry:setWidth(self.infoPanel:getWidth() - (BUTTON_WDH + DX*2 + self.infoPanel.scrollwidth) - (self.infoPanel.workshopLabel:getRight() + DX))
	self.infoPanel.urlEntry:setWidth(self.infoPanel:getWidth() - (BUTTON_WDH + DX*2 + self.infoPanel.scrollwidth) - (self.infoPanel.urlLabel:getRight() + DX))
	self.infoPanel.locationEntry:setWidth(self.infoPanel:getWidth() - (BUTTON_WDH + DX*2 + self.infoPanel.scrollwidth) - (self.infoPanel.locationLabel:getRight() + DX))
	
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
	print(NRKLOG, "populateListBox, ", directories)
	self.listBox:clear()
	local modIDs = {}
	
	local activeMods = (self.loadGameFolder or self.isNewGame) and ActiveMods.getById("currentGame") or ActiveMods.getById("default")
	
	for _, directory in ipairs(directories) do
		local item = {modInfo = getModInfo(directory)}
		local modID = item.modInfo:getId()
		if not modIDs[modID] then
			item.modInfoExtra = self:readInfoExtra(modID)
			item.isActive = activeMods:isModActive(modID)
			
			self.listBox:addItem(item.modInfo:getName(), item)
			modIDs[modID] = true
		end
	end
	
	-- check in a separate cycle, because the list should already be formed
	for _, item in ipairs(self.listBox.items) do
		if item.item.isAvailable == nil then
			item.item.isAvailable = self:checkRequire(item.item.modInfo:getId())
		end
	end
	
	-- mark mods activated by require
	-- TODO: make as function
	for _, item in ipairs(self.listBox.items) do
		local modID = item.item.modInfo:getId()
		local requires = item.item.modInfo:getRequire()
		if item.item.isActive and requires and not requires:isEmpty() then
			for i = 0, requires:size() - 1 do
				local requireItem = self.listBox:getItemById(requires:get(i))
				if type(requireItem.item.isActive) == "table" then
					table.insert(requireItem.item.isActive, modID)
				else
					requireItem.item.isActive = {modID}
				end
			end
		end
	end
	--[[
	table.sort(
		self.listBox.items,
		function(a,b)
			return not string.sort(a.item.modInfo:getName(), b.item.modInfo:getName())
		end
	)]]
	self.listBox:sort()
end

function ModSelector:checkRequire(modID)
	local requires = getModInfoByID(modID):getRequire()
	
	if requires and not requires:isEmpty() then
		for i = 0, requires:size() - 1 do
			local requireID = requires:get(i)
			if getModInfoByID(requireID) == nil or self:checkRequire(requireID) == false then
				return false
			end
		end
	end
	
	return true
end

function ModSelector:readInfoExtra(modID)
	local modInfoExtra = {}
	
	-- mod with maps?
	local mapList = getMapFoldersForMod(modID)
	if mapList ~= nil then
		modInfoExtra.withMap = true
		modInfoExtra.maps = {}
		for i = 0, mapList:size() - 1 do
			table.insert(modInfoExtra.maps, mapList:get(i))
		end
	end
	
	-- extra data from mod.info
	local file = getModFileReader(modID, "mod.info", false)
	if not file then return modInfoExtra end
	local line = file:readLine()
	while line ~= nil do
		--split key and value (no luautils.split)
		local sep = string.find(line, "=")
		local key, val = "", ""
		if sep ~= nil then
			key = string.lower(luautils.trim(string.sub(line, 0, sep - 1)))
			val = luautils.trim(string.sub(line, sep + 1))
		end
		-- split lists
		if key == "authors" then -- tags? pzversion?
			val = luautils.split(val, ",")
			for i, j in ipairs(val) do
				val[i] = luautils.trim(j)
			end
		end
		
		-- no read default keys: name, poster, description, require, id, pack, tiledef
		-- reread url without restrictions
		if key == "name_extra" then modInfoExtra.name = getTextOrNull(val) end
		if key == "description_extra" then modInfoExtra.description = getTextOrNull(val) end
		if key == "modversion" then modInfoExtra.modversion = val end
		if key == "pzversion" then modInfoExtra.pzversion = val end
		if key == "tags" then modInfoExtra.tags = val end
		if key == "authors" then modInfoExtra.authors = val end
		if key == "icon" then modInfoExtra.icon = val end
		if key == "url" then modInfoExtra.url = val end
		line = file:readLine()
	end
	file:close()
	
	return modInfoExtra
end

function ModSelector.showNagPanel() -- call from MainScreen.lua, NewGameScreen.lua, LoadGameScreen.lua
	print(NRKLOG, "show NagPanel")
	-- TODO: return here what was in the original
end


ModPanelFilter = ISPanelJoypad:derive("ModPanelFilter")

function ModPanelFilter:new(x, y, width, height)
	local o = ISPanelJoypad:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.background = false
	o.byname = true
	o.bydesc = false
	o.bytag = false
	o.bymap = false
	o.fromlocal = true
	o.fromworkshop = true
	o.withmap = true
	o.withoutmap = true
	return o
end

function ModPanelFilter:createChildren()
	-- line 1
	-- TODO: "Filter" [keyword] "in" [*] name, [*] description, [*] tags, [*] maps
	self.textFilterLabel = ISLabel:new(
		0, 0, BUTTON_HGT, getText("UI_NRK_ModSelector_FilterBy"),
		1, 1, 1, 1, UIFont.Small, true
	)
	self:addChild(self.textFilterLabel)
	
	self.textFilterByName = ISTickBox:new(
		self.textFilterLabel:getRight() + DX, 2, BUTTON_WDH, BUTTON_HGT,
		"textFilterByName", self,
		function()
			self.byname = not self.byname
		end
	)
	self.textFilterByName.choicesColor = {r=1, g=1, b=1, a=1}
	self.textFilterByName:addOption(getText("UI_NRK_ModSelector_ByName"), nil)
	self.textFilterByName:setWidthToFit()
	self.textFilterByName.selected[1] = self.byname
	self:addChild(self.textFilterByName)
	
	self.textFilterByDesc = ISTickBox:new(
		self.textFilterByName:getRight() + DX, 2, BUTTON_WDH, BUTTON_HGT,
		"textFilterByDesc", self,
		function()
			self.bydesc = not self.bydesc
		end
	)
	self.textFilterByDesc.choicesColor = {r=1, g=1, b=1, a=1}
	self.textFilterByDesc:addOption(getText("UI_NRK_ModSelector_ByDesc"), nil)
	self.textFilterByDesc:setWidthToFit()
	self.textFilterByDesc.selected[1] = self.bydesc
	self:addChild(self.textFilterByDesc)
	
	self.textFilterByTag = ISTickBox:new(
		self.textFilterByDesc:getRight() + DX, 2, BUTTON_WDH, BUTTON_HGT,
		"textFilterByTag", self,
		function()
			self.bytag = not self.bytag
		end
	)
	self.textFilterByTag.choicesColor = {r=1, g=1, b=1, a=1}
	self.textFilterByTag:addOption(getText("UI_NRK_ModSelector_ByTags"), nil)
	self.textFilterByTag:setWidthToFit()
	self.textFilterByTag.selected[1] = self.bytag
	self:addChild(self.textFilterByTag)
	
	self.textFilterByMap = ISTickBox:new(
		self.textFilterByTag:getRight() + DX, 2, BUTTON_WDH, BUTTON_HGT,
		"textFilterByMap", self,
		function()
			self.bymap = not self.bymap
		end
	)
	self.textFilterByMap.choicesColor = {r=1, g=1, b=1, a=1}
	self.textFilterByMap:addOption(getText("UI_NRK_ModSelector_ByMaps"), nil)
	self.textFilterByMap:setWidthToFit()
	self.textFilterByMap.selected[1] = self.bymap
	self:addChild(self.textFilterByMap)
	
	self.textFilterText = ISTextEntryBox:new("",
		self.textFilterByMap:getRight() + DX, 3,
		self.width - (self.textFilterByMap:getRight() + DX), FONT_HGT_SMALL + 3
	)
	self:addChild(self.textFilterText)
	
	-- line 2
	-- TODO: add [*]enable, [*]disabled, [*]available, [*]not available
	self.flagFilterLabel = ISLabel:new(
		0, BUTTON_HGT + DY, BUTTON_HGT, getText("UI_NRK_ModSelector_ShowMods"),
		1, 1, 1, 1, UIFont.Small, true
	)
	self:addChild(self.flagFilterLabel)
	
	self.flagFilterLocal = ISTickBox:new(
		self.flagFilterLabel:getRight() + DX, BUTTON_HGT + DY + 2, BUTTON_WDH, BUTTON_HGT,
		"flagFilterLocal", self,
		function()
			self.fromlocal = not self.fromlocal
		end
	)
	self.flagFilterLocal.choicesColor = {r=1, g=1, b=1, a=1}
	self.flagFilterLocal:addOption(getText("UI_NRK_ModSelector_FromLocal"), nil)
	self.flagFilterLocal:setWidthToFit()
	self.flagFilterLocal.selected[1] = self.fromlocal
	self:addChild(self.flagFilterLocal)
	
	self.flagFilterWorkshop = ISTickBox:new(
		self.flagFilterLocal:getRight() + DX, BUTTON_HGT + DY + 2, BUTTON_WDH, BUTTON_HGT,
		"flagFilterLocal", self,
		function()
			self.fromworkshop = not self.fromworkshop
		end
	)
	self.flagFilterWorkshop.choicesColor = {r=1, g=1, b=1, a=1}
	self.flagFilterWorkshop:addOption(getText("UI_NRK_ModSelector_FromWorkshop"), nil)
	self.flagFilterWorkshop:setWidthToFit()
	self.flagFilterWorkshop.selected[1] = self.fromworkshop
	self:addChild(self.flagFilterWorkshop)
	
	self.flagFilterWithMap = ISTickBox:new(
		self.flagFilterWorkshop:getRight() + DX, BUTTON_HGT + DY + 2, BUTTON_WDH, BUTTON_HGT,
		"flagFilterLocal", self,
		function()
			self.withmap = not self.withmap
		end
	)
	self.flagFilterWithMap.choicesColor = {r=1, g=1, b=1, a=1}
	self.flagFilterWithMap:addOption(getText("UI_NRK_ModSelector_WithMap"), nil)
	self.flagFilterWithMap:setWidthToFit()
	self.flagFilterWithMap.selected[1] = self.withmap
	self:addChild(self.flagFilterWithMap)
	
	self.flagFilterWithoutMap = ISTickBox:new(
		self.flagFilterWithMap:getRight() + DX, BUTTON_HGT + DY + 2, BUTTON_WDH, BUTTON_HGT,
		"flagFilterLocal", self,
		function()
			self.withoutmap = not self.withoutmap
		end
	)
	self.flagFilterWithoutMap.choicesColor = {r=1, g=1, b=1, a=1}
	self.flagFilterWithoutMap:addOption(getText("UI_NRK_ModSelector_WithoutMap"), nil)
	self.flagFilterWithoutMap:setWidthToFit()
	self.flagFilterWithoutMap.selected[1] = self.withoutmap
	self:addChild(self.flagFilterWithoutMap)
end


ModListBox = ISScrollingListBox:derive("ModListBox")

function ModListBox:new(x, y, width, height)
	local o = ISScrollingListBox:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.drawBorder = true
	o.itemheight = FONT_HGT_MEDIUM + 2*DY
	--[[
	o.item.item.modInfo
	o.item.item.modInfoExtra = {}
	o.item.item.isAvailable = true/false
	o.item.item.isActive = true/false/{modID1, modID2, ...}
	]]
	return o
end

function ModListBox:doDrawItem(y, item, alt)
	local modInfo = item.item.modInfo
	local modInfoExtra = item.item.modInfoExtra
	local filter = self.parent.filterPanel
	if not filter.fromlocal and not modInfo:getWorkshopID() then return y end
	if not filter.fromworkshop and modInfo:getWorkshopID() then return y end
	if not filter.withmap and modInfoExtra.withMap then return y end
	if not filter.withoutmap and not modInfoExtra.withMap then return y end
	
	local keyWord = filter.textFilterText:getText()
	if keyWord ~= nil and keyWord ~= "" then
		local show, tableForFind = false, {}
		
		if filter.byname then
			table.insert(tableForFind, modInfo:getName())
			table.insert(tableForFind, modInfoExtra.name or "")
		end
		if filter.bydesc then
			table.insert(tableForFind, modInfo:getDescription() or "")
			table.insert(tableForFind, modInfoExtra.description or "")
		end
		if filter.bytag then
			table.insert(tableForFind, modInfoExtra.tags or "")
		end
		if filter.bymap then
			for _, map in ipairs(modInfoExtra.maps or {}) do
				table.insert(tableForFind, map or "")
			end
		end
		
		for _, s in ipairs(tableForFind) do
			if string.find(s, keyWord) ~= nil then
				show = true
				break
			end
		end
		
		if not show then return y end
	end
	
	local h = self.itemheight
	
	if self.selected == item.index then
		self:drawRect(0, y, self:getWidth(), h - 1, 0.3, 0.7, 0.35, 0.15)
	elseif self.mouseoverselected == item.index and not self:isMouseOverScrollBar() then
		self:drawRect(1, y + 1, self:getWidth() - 2, h - 2, 0.95, 0.05, 0.05, 0.05)
	end
	self:drawRectBorder(0, y, self:getWidth(), h - 1, 0.5, self.borderColor.r, self.borderColor.g, self.borderColor.b)
	
	local icon = modInfoExtra.icon and getTexture(modInfoExtra.icon) or DEFAULT_ICON
	self:drawTextureScaled(icon, DX, y + DY, FONT_HGT_MEDIUM, FONT_HGT_MEDIUM, 1)
	if item.item.isActive == true then
		self:drawTexture(ACTIVE_ICON, DX + FONT_HGT_MEDIUM - 5, y + DY + FONT_HGT_MEDIUM - 7, 1)
	elseif type(item.item.isActive) == "table" then
		self:drawTexture(REQUIRE_ICON, DX + FONT_HGT_MEDIUM - 5, y + DY + FONT_HGT_MEDIUM - 7, 1)
	end
	if not item.item.isAvailable then
		self:drawTexture(BROKEN_ICON, DX + FONT_HGT_MEDIUM - 5, y + DY + FONT_HGT_MEDIUM - 7, 1)
	end
	
	local text = modInfo:getName()
	if not item.item.isAvailable then
		text = text .. getText("UI_NRK_ModSelector_Broken")
	elseif item.item.isActive == true then
		text = text .. getText("UI_NRK_ModSelector_Enabled")
	elseif type(item.item.isActive) == "table" then
		text = text .. getText("UI_NRK_ModSelector_EnabledBy", table.concat(item.item.isActive, ", "))
	end
	self:drawText(text, DX + FONT_HGT_MEDIUM + DX, y + DY, 1, 1, 1, 1, UIFont.Medium)
	
	y = y + h
	return y
end

function ModListBox:doActive(item, byRequire)
	local modID = item.modInfo:getId()
	print(NRKLOG, "do Active", modID, byRequire)
	if not byRequire then
		item.isActive = true
	else
		if type(item.isActive) == "table" then
			table.insert(item.isActive, byRequire)
		else
			item.isActive = {byRequire}
		end
	end
	
	local requires = item.modInfo:getRequire()
	if requires and not requires:isEmpty() then
		for i = 0, requires:size() - 1 do
			local requiresID = requires:get(i)
			self:doActive(self:getItemById(requiresID).item, modID)
		end
	end
end

function ModListBox:doInactive(item, byRequire)
	if item.isActive == false then return end
	
	local modID = item.modInfo:getId()
	print(NRKLOG, "do Inactive", modID, byRequire)
	local requiresUp = (type(item.isActive) == "table" and item.isActive) or {}
	local requiresDown = item.modInfo:getRequire()
	
	if byRequire then
		local new_active = {}
		for _, id in ipairs(item.isActive) do
			if id ~= byRequire then table.insert(new_active, id) end
		end
		if #new_active == 0 then
			item.isActive = false
			if requiresDown and not requiresDown:isEmpty() then
				for i = 0, requiresDown:size() - 1 do
					self:doInactive(self:getItemById(requiresDown:get(i)).item, modID)
				end
			end
		else
			item.isActive = new_active
		end
	else
		item.isActive = false
		if requiresDown and not requiresDown:isEmpty() then
			for i = 0, requiresDown:size() - 1 do
				self:doInactive(self:getItemById(requiresDown:get(i)).item, modID)
			end
		end
		for _, id in ipairs(requiresUp) do
			self:doInactive(self:getItemById(id).item)
		end
	end
end

function ModListBox:getItemById(modID)
	for _, item in ipairs(self.items) do
		if item.item.modInfo:getId() == modID then
			return item
		end
	end
	return nil
end

function ModListBox:onMouseDoubleClick(x, y)
	local item = self.items[self.selected].item
	print(NRKLOG, "onMouseDoubleClick", item.modInfo:getId())
	
	if not item.isAvailable then return end
	
	if not item.isActive then
		self:doActive(item)
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
		DX, 4, FONT_HGT_SMALL, getText("UI_NRK_ModSelector_ToWorkshop"), 
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
		getText("UI_NRK_ModSelector_Go"), self, self.onGoButton
	)
	self.workshopButton.tooltip = getText("UI_NRK_ModSelector_ToWorkshop_tt")
	self.workshopButton.internal = "workshop"
	self.workshopButton.borderColor = {r=1, g=1, b=1, a=0.1}
	self.workshopButton:setAnchorLeft(false)
	self.workshopButton:setAnchorRight(true)
	self.workshopButton:setVisible(false)
	self.workshopButton:setWidth(BUTTON_WDH) -- suppress auto setWidthToTitle
	self:addChild(self.workshopButton)
	
	-- url Label, Entry, Button
	self.urlLabel = ISLabel:new(
		DX, 4, FONT_HGT_SMALL, getText("UI_NRK_ModSelector_ToURL"), 
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
		getText("UI_NRK_ModSelector_Go"), self, self.onGoButton
	)
	self.urlButton.tooltip = getText("UI_NRK_ModSelector_ToURL_tt")
	self.urlButton.link = "url"
	self.urlButton.borderColor = {r=1, g=1, b=1, a=0.1}
	self.urlButton:setAnchorLeft(false)
	self.urlButton:setAnchorRight(true)
	self.urlButton:setVisible(false)
	self.urlButton:setWidth(BUTTON_WDH) -- suppress auto setWidthToTitle
	self:addChild(self.urlButton)
	
	-- location Label, Entry, Button
	self.locationLabel = ISLabel:new(
		DX, 4, FONT_HGT_SMALL, getText("UI_NRK_ModSelector_ToLocation"), 
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
		getText("UI_NRK_ModSelector_Go"), self, self.onGoButton
	)
	self.locationButton.tooltip = getText("UI_NRK_ModSelector_ToLocation_tt")
	self.locationButton.link = "location"
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
		getText("UI_NRK_ModSelector_ExtraInfo"), self,
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
end

function ModPanelInfo:prerender()
	local i = self.parent.listBox.selected
	if self.selected ~= i then
		local item = self.parent.listBox.items[i].item
		
		local name = item.modInfoExtra.name or item.modInfo:getName()
		local desc = item.modInfoExtra.description or item.modInfo:getDescription() or ""
		local full_desc = " <H1> " .. name .. " <LINE> <TEXT> " .. desc .. " <LINE> " --<LINE> <TEXT> "
		self.descRichText:setText(full_desc)
		self.descRichText:paginate()
		
		local extra_desc = " <TEXT> " .. getText("UI_mods_ID", item.modInfo:getId()) .. " <LINE> "
		if item.modInfoExtra.modversion ~= nil then
			extra_desc = extra_desc .. getText("UI_NRK_ModSelector_ModVersion") .. " " .. item.modInfoExtra.modversion .. " <LINE> "
		end
		if item.modInfoExtra.pzversion ~= nil then
			extra_desc = extra_desc .. getText("UI_NRK_ModSelector_PZVersion") .. " " .. item.modInfoExtra.pzversion .. " <LINE> "
		end
		if item.modInfoExtra.tags ~= nil then
			extra_desc = extra_desc .. getText("UI_NRK_ModSelector_Tags") .. " " .. item.modInfoExtra.tags .. " <LINE> "
		end
		local maps = item.modInfoExtra.maps
		if maps ~= nil and #maps > 0 then
			extra_desc = extra_desc .. getText("UI_NRK_ModSelector_Maps") .. " <LINE> <INDENT:" .. tostring(DX) .. "> "
			for _ , map in ipairs(maps) do
				extra_desc = extra_desc .. "- " .. map .. " <LINE> "
			end
			extra_desc = extra_desc .. " <INDENT:0> "
		end
		local requires = item.modInfo:getRequire()
		if requires and not requires:isEmpty() then
			extra_desc = extra_desc .. getText("UI_NRK_ModSelector_Require") .. " <LINE> <INDENT:" .. tostring(DX) .. "> "
			for i = 0, requires:size() - 1 do
				if item.isAvailable then
					extra_desc = extra_desc .. "- " .. requires:get(i) .. " <LINE> "
				else
					extra_desc = extra_desc .. " <RED> - " .. requires:get(i) .. " <LINE> <TEXT> "
				end
			end
			extra_desc = extra_desc .. " <INDENT:0> "
		end
		local authors = item.modInfoExtra.authors
		if authors ~= nil and #authors > 0 then
			extra_desc = extra_desc .. getText("UI_NRK_ModSelector_Authors") .. " <LINE> <INDENT:" .. tostring(DX) .. "> "
			for _, author in ipairs(authors) do
				extra_desc = extra_desc .. "- " .. author .. " <LINE> "
			end
			extra_desc = extra_desc .. " <INDENT:0> "
		end
		self.extraRichText:setText(extra_desc)
		self.extraRichText:paginate()
		
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
			self.urlButton.tooltip = getText("UI_NRK_ModSelector_ToURL_tt")
			self.urlEntry:setText(item.modInfo:getUrl())
		elseif item.modInfoExtra.url ~= nil and item.modInfoExtra.url ~= "" then
			self.urlLabel:setVisible(true)
			self.urlEntry:setVisible(true)
			self.urlButton:setVisible(true)
			self.urlButton.tooltip = getText("UI_NRK_ModSelector_ToURL_tt") .. " " .. getText("UI_NRK_ModSelector_ToURL_warning")
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
	
	self:setScrollHeight(self.locationButton:getBottom() + DY)
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
	if button.internal == "url" then
		if isSteamOverlayEnabled() then
			activateSteamOverlayToWebPage(self.urlEntry.title)
		else
			openUrl(self.urlEntry.title)
		end
	elseif button.internal == "workshop" then
		activateSteamOverlayToWorkshopItem(self.workshopEntry.title)
	elseif button.internal == "location" then
		showFolderInDesktop(self.locationEntry.title)
	end
end


ModPanelPoster = ISPanelJoypad:derive("ModPanelPoster")

function ModPanelPoster:new(x, y, width, height)
	local o = ISPanelJoypad:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.selectedmod = 0
	o.sourceposter = 0
	o.nextposter = 0
	return o
end

function ModPanelPoster:createChildren()
	local w, h = 3*self.width/4, 3*self.height/4
	local x, y = (self.width - w)/2, (self.height - h)/2
	
	self.leftImage = ISImage:new(DX, y + h/4, w/2, h/2, nil)
	self.leftImage.scaledWidth = w/2
	self.leftImage.scaledHeight = h/2
	self.leftImage.target = self
	self.leftImage.onclick = self.prevPoster
	self:addChild(self.leftImage)
	
	self.rightImage = ISImage:new(self.width - (DX + w/2), y + h/4, w/2, h/2, nil)
	self.rightImage.scaledWidth = w/2
	self.rightImage.scaledHeight = h/2
	self.rightImage.target = self
	self.rightImage.onclick = self.nextPoster
	self:addChild(self.rightImage)
	
	self.centerImage = ISImage:new(x, y, w, h, nil)
	self.centerImage.scaledWidth = w
	self.centerImage.scaledHeight = h
	self.centerImage.font = UIFont.Medium
	self:addChild(self.centerImage)
end

function ModPanelPoster:prerender()
	-- TODO: add to onResolutionChange
	-- TODO: scale with save ratio
	local i = self.parent.listBox.selected
	if self.selectedmod ~= i then
		local modInfo = self.parent.listBox.items[i].item.modInfo
		self.textures = {}
		self.postercount = modInfo:getPosterCount()
		if self.postercount == 0 then
			self.centerImage.name = getText("UI_NRK_ModSelector_NoPoster")
			self.centerImage:setX((self.width - (getTextManager():MeasureStringX(self.centerImage.font, self.centerImage.name)))/2)
		else
			self.centerImage.name = ""
			self.centerImage:setX((self.width - self.centerImage.width)/2)
			for id = 0, modInfo:getPosterCount() - 1 do
				table.insert(self.textures, getTexture(modInfo:getPoster(id)))
			end
		end
		
		self.sourceposter = 0
		self.nextposter = 1
		self.selectedmod = i
	end
	
	if self.sourceposter ~= self.nextposter then
		self.leftImage.texture = self.textures[self.nextposter - 1]
		self.centerImage.texture = self.textures[self.nextposter]
		self.rightImage.texture = self.textures[self.nextposter + 1]
		self.sourceposter = self.nextposter
	end
	
	ISPanelJoypad.prerender(self)
end

--[[function ModPanelPoster:render()
	ISPanelJoypad.render(self)
	
	if self.leftImage:getTexture() then
		self.leftImage:drawRectBorder(0, 0, self.leftImage:getWidth(), self.leftImage:getHeight(), 1, 1, 1, 1)
	end
	if self.rightImage:getTexture() then
		self.rightImage:drawRectBorder(0, 0, self.rightImage:getWidth(), self.rightImage:getHeight(), 1, 1, 1, 1)
	end
	if self.centerImage:getTexture() then
		self.centerImage:drawRectBorder(0, 0, self.centerImage:getWidth(), self.centerImage:getHeight(), 1, 1, 1, 1)
	end
end]]

function ModPanelPoster:prevPoster()
	if self.sourceposter > 1 then
		self.nextposter = self.sourceposter - 1
	end
end

function ModPanelPoster:nextPoster()
	if self.sourceposter < self.postercount then
		self.nextposter = self.sourceposter + 1
	end
end

function ModPanelPoster:onMouseWheel(step)
	self.nextposter = self.sourceposter + step
	if self.nextposter >= self.postercount then self.nextposter = self.postercount end
	if self.nextposter <= 1 then self.nextposter = 1 end
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
	self.saveComboBox:addOptionWithData(getText("UI_NRK_ModSelector_Save_AllDisabled"), "clear")
	self:readModList()
	for save_name, _ in pairs(self.savelist) do
		self.saveComboBox:addOptionWithData(save_name, "user")
	end
	self.saveComboBox.selected = 0 -- no selection
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
		local s = luautils.split(line, ":")
		self.savelist[s[1]] = luautils.split(s[2], ";")
		line = file:readLine()
	end
	file:close()
end

function ModPanelSave:writeModList()
	local file = getFileWriter(self.savefile, true, false)
	for save_name, save_list in pairs(self.savelist) do
		file:write(save_name..":"..table.concat(save_list, ";").."\n")
	end
	file:close()
end

function ModPanelSave:onSelected()
	local selectedItem = self.saveComboBox.options[self.saveComboBox.selected]
	local name, data = selectedItem.text, selectedItem.data
	
	self.delButton:setEnable(data == "user")
	
	for _, item in ipairs(self.parent.listBox.items) do
		item.item.isActive = false
	end
	if data == "user" then
		for _, id in ipairs(self.savelist[name]) do
			self.parent.listBox:getItemById(id).item.isActive = true
		end
	end
	
	-- mark mods activated by require
	-- TODO: make as function
	for _, item in ipairs(self.parent.listBox.items) do
		local modID = item.item.modInfo:getId()
		local requires = item.item.modInfo:getRequire()
		if item.item.isActive and requires and not requires:isEmpty() then
			for i = 0, requires:size() - 1 do
				local requireItem = self.parent.listBox:getItemById(requires:get(i))
				if type(requireItem.item.isActive) == "table" then
					table.insert(requireItem.item.isActive, modID)
				else
					requireItem.item.isActive = {modID}
				end
			end
		end
	end
end

function ModPanelSave:onValidateSaveName(text)
	return not text:contains(":") and not text:contains(";")
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
	modal.validateText = getText("UI_NRK_ModSelector_Save_SaveButton_tt")
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
		
		self.saveComboBox.options = {}
		self.saveComboBox:addOptionWithData(getText("UI_NRK_ModSelector_Save_AllDisabled"), "clear")
		for save_name, _ in pairs(self.savelist) do
			self.saveComboBox:addOptionWithData(save_name, "user")
		end
		self.saveComboBox:select(name)
		self.delButton:setEnable(true)
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
		
		self.saveComboBox.options = {}
		self.saveComboBox:addOptionWithData(getText("UI_NRK_ModSelector_Save_AllDisabled"), "clear")
		for save_name, _ in pairs(self.savelist) do
			self.saveComboBox:addOptionWithData(save_name, "user")
		end
		self.saveComboBox.selected = 0 -- no selection
		self.delButton:setEnable(false)
	end
end

-- TODO: Events.OnModsModified - WTF? Reread mod-list from disk?
-- TODO: get/set OptionModsEnabled - no need?
-- TODO: mapGroups/mapConflicts/ModOrderUI - it's work?
-- TODO: Joypad - now only "Back/Accept" work
-- TODO: Create new mod / edit mod.info???
