require "ISUI/ISPanel"


ISPanelCompact = ISPanel:derive("ISPanelCompact")

function ISPanelCompact:new(x, y, width, height)
	local o = ISPanel:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	
	o.imageexpanded = getTexture("media/ui/ArrowUp.png")
	o.imagecollapsed = getTexture("media/ui/ArrowDown.png")
	o.expanded = false
	o.font = UIFont.Small
	o.text = ""
	
	return o
end

function ISPanelCompact:createChildren()
	self.popup = ISPanelCompactPopup:new()
	self.popup.parentPanel = self
	self.popup.drawBorder = true
	self.popup:initialise()
	self.popup:instantiate()
	self.popup:setAlwaysOnTop(true)
	self.popup:setCapture(true)
end

function ISPanelCompact:showPopup()
	self.expanded = true
	
	self.popup:setX(self:getAbsoluteX())
	self.popup:setWidth(self:getWidth())
	self.popup:setY(self:getAbsoluteY() + self:getHeight())
	self.popup:resize()
	
	self.popup:addToUIManager()
end

function ISPanelCompact:hidePopup()
	self.expanded = false
	self.popup:removeFromUIManager()
end

function ISPanelCompact:onMouseDown(x, y)
	self.sawMouseDown = true
end

function ISPanelCompact:onMouseUp(x, y)
	if self.sawMouseDown then
		self.sawMouseDown = false
		self:showPopup()
	end
end

function ISPanelCompact:onMouseUpOutside(x, y)
	self.sawMouseDown = false
end

function ISPanelCompact:prerender()
	local image = self.expanded and self.imageexpanded or self.imagecollapsed
	local c = self:isMouseOver() and 1 or 0.4
	local image_x = self.width - image:getWidthOrig() - 3
	local image_y = self.height/2 - image:getHeight()/2
	
	self:drawRect(
		0, 0, self.width, self.height,
		1, 0, 0, 0
	)
	self:drawRectBorder(
		0, 0, self.width, self.height,
		1, 0.4, 0.4, 0.4
	)
	self:drawTexture(
		image, image_x, image_y,
		1, c, c, c
	)
	
	self:clampStencilRectToParent(0, 0, image_x - 3, self.height)
	self:drawText(
		self.text,
		10, (self.height - getTextManager():getFontHeight(self.font))/2,
		0.9, 0.9, 0.9, 1,
		self.font
	)
	self:clearStencilRect()
end


ISPanelCompactPopup = ISPanel:derive("ISPanelCompactPopup")

function ISPanelCompactPopup:new()
	local o = ISPanel:new(0, 0, 0, 0)
	setmetatable(o, self)
	self.__index = self
	
	o.backgroundColor = {r=0, g=0, b=0, a=1}
	
	return o
end

function ISPanelCompactPopup:resize()
	self:setHeight(200)
end

function ISPanelCompactPopup:onMouseDown(x, y)
	if not self:isMouseOver() then
		self.parentPanel:hidePopup()
	end
end
