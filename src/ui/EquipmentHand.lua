local love = require("love")
local EquipmentItem = require("src/utils/equipment_item")

local EquipmentHand = {}
EquipmentHand.__index = EquipmentHand

function EquipmentHand.new(opts)
    opts = opts or {}
    local self = setmetatable({}, EquipmentHand)

    self.x = opts.x or 0
    self.y = opts.y or 0
    self.width = opts.width or 400
    self.itemSize = opts.itemSize or 64
    self.spacing = opts.spacing or 10

    self.items = {}
    self.maxSlots = 6
    self.unlockedSlots = 1

    self.draggedItem = nil

    self.onItemClicked = opts.onItemClicked
    self.onItemHovered = opts.onItemHovered

    return self
end

function EquipmentHand:setUnlockedSlots(n)
    self.unlockedSlots = math.max(0, math.min(self.maxSlots, n))
end

function EquipmentHand:syncItems(itemDataList)
    local newItems = {}
    local needsReflow = false

    if itemDataList then
        for i, data in ipairs(itemDataList) do
            if i <= self.unlockedSlots then
                local existing = self.items[i]
                if existing and existing.id == data.id then
                    newItems[i] = existing
                else
                    local item = EquipmentItem.new(data)
                    item:setSize(self.itemSize, self.itemSize)

                    local handRef = self
                    item.onClick = function(c)
                        if handRef.onItemClicked then
                            handRef.onItemClicked(i, c)
                        end
                    end

                    newItems[i] = item
                    needsReflow = true
                end
            end
        end
    end

    -- Check if items were removed
    for i = 1, self.maxSlots do
        if self.items[i] and not newItems[i] then
            needsReflow = true
        end
    end

    self.items = newItems

    if needsReflow then
        self:_reflow()
    end
end

function EquipmentHand:_reflow()
    local totalW = self.maxSlots * self.itemSize + (self.maxSlots - 1) * self.spacing
    local startX = self.x - totalW / 2 + self.itemSize / 2

    for i = 1, self.maxSlots do
        local cx = startX + (i - 1) * (self.itemSize + self.spacing)
        local cy = self.y

        local item = self.items[i]
        if item then
            item.zIndex = i
            item:setPosition(cx, cy)
            item:setRotation(0)
        end
    end
end

function EquipmentHand:mousemoved(mx, my, dx, dy)
    for _, item in pairs(self.items) do
        item:mousemoved(mx, my, dx, dy)
    end
end

function EquipmentHand:mousepressed(mx, my, button)
    for i = self.maxSlots, 1, -1 do
        local item = self.items[i]
        if item then
            if item:mousepressed(mx, my, button) then
                if button == 1 then
                    self.draggedItem = item
                    item:startDrag(mx, my)
                end
                return true
            end
        end
    end
    return false
end

function EquipmentHand:mousereleased(mx, my, button)
    for _, item in pairs(self.items) do
        item:mousereleased(mx, my, button)
    end
    if self.draggedItem and button == 1 then
        self.draggedItem:stopDrag()
        self.draggedItem = nil
    end
end

function EquipmentHand:update(dt)
    local mx, my = love.mouse.getPosition()
    for _, item in pairs(self.items) do
        item:update(dt, mx, my)
    end

    -- Update positions continuously just in case root x/y changed
    local totalW = self.maxSlots * self.itemSize + (self.maxSlots - 1) * self.spacing
    local startX = self.x - totalW / 2 + self.itemSize / 2
    for i = 1, self.maxSlots do
        local cx = startX + (i - 1) * (self.itemSize + self.spacing)
        local cy = self.y
        local item = self.items[i]
        if item then
            item.baseX = cx
            item.baseY = cy
        end
    end
end

function EquipmentHand:draw()
    local totalW = self.maxSlots * self.itemSize + (self.maxSlots - 1) * self.spacing
    local startX = self.x - totalW / 2
    local startY = self.y - self.itemSize / 2

    for i = 1, self.maxSlots do
        local cx = startX + (i - 1) * (self.itemSize + self.spacing)

        if i <= self.unlockedSlots then
            love.graphics.setColor(0.15, 0.15, 0.18, 0.8)
            love.graphics.rectangle("fill", cx, startY, self.itemSize, self.itemSize, 8, 8)
            love.graphics.setColor(0.3, 0.3, 0.35, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cx, startY, self.itemSize, self.itemSize, 8, 8)
            love.graphics.setLineWidth(1)
        else
            love.graphics.setColor(0.08, 0.08, 0.1, 0.8)
            love.graphics.rectangle("fill", cx, startY, self.itemSize, self.itemSize, 8, 8)
            love.graphics.setColor(0.2, 0.2, 0.2, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cx, startY, self.itemSize, self.itemSize, 8, 8)
            love.graphics.setLineWidth(1)
            love.graphics.line(cx + 10, startY + 10, cx + self.itemSize - 10, startY + self.itemSize - 10)
            love.graphics.line(cx + self.itemSize - 10, startY + 10, cx + 10, startY + self.itemSize - 10)
        end
    end

    local sorted = {}
    for i = 1, self.maxSlots do
        if self.items[i] then
            table.insert(sorted, self.items[i])
        end
    end
    table.sort(sorted, function(a, b)
        if a == self.draggedItem then return false end
        if b == self.draggedItem then return true end
        if a.hovered ~= b.hovered then
            return not a.hovered
        end
        return a.zIndex < b.zIndex
    end)

    for _, item in ipairs(sorted) do
        item:draw()
    end
end

return EquipmentHand
