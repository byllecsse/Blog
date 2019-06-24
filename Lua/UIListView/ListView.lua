-- 列表控件
-- ListView中的元素一开始全部创建完毕，优点是接口简单，支持更多的操作事件。适用于列表数目可控且数量不大的情况，如背包、排行榜
-- cell的高度和宽度固定，如果reuseItem为true，则刷新item的时候会复用之前的gameObject
-- 当列表元素数目很大的时候，使用TableView，TableView会动态计算并更新可显示的元素
-- 排版注意事项，prefab设置为左上角对齐，起始点由prefab在Content中的位置决定，大小由prefab创建的大小决定，间距可以通过space调整

-- 默认支持的事件回调（在界面中直接写同名函数，如果有多个listview可以使用特例化的函数名，格式为  回调函数_控件名 ，例如OnCreateItem_ScrollRect1）
-- OnCreateItem(index)
-- OnSelectItem(index, go)
-- OnUnselectItem(index, go)
------------------------------------------------------------
ListView = class('ListView', BaseCtrl)

function ListView:ctor(scroll, prefab, delegate, name)
    ---- region 需要外部设置的属性
    self.PaddingStart = 0  -- [顶部留空]，[仅]计算content的[大小]时用到，与安排元素[位置]无关
    self.PaddingEnd = 0    -- [尾部留空]，[仅]计算content的[大小]时用到，与安排元素[位置]无关

    self.space = 0  -- 元素间距 如果只有一列或者一行，则直接指定space即可。否则需要指定spaceX和spaceY
    self.spaceX = 0
    self.spaceY = 0
    self.maxCountPerLine = 1    -- 每行（列）的最大元素数目，如果是垂直滑动，则限制水平方向的元素数目
    self.enableMultiSelect = false  -- 是否允许多选
    self.horizontal = scroll.horizontal -- 是否是水平方向排版，默认根据scroll.horizontal来设置，不过有特殊界面不可滑动，但是依然需要一个变量以标识排版方向
    self.contnetInitSize = 0
    self.contnetMinSize = 0
    self.startX = 0     -- 初始元素X Pos
    self.startY = 0     -- 初始元素Y Pos
    self.reuseItem = false  -- 复用控件，Reload的时候会优先取之前的go。如果go有事件绑定则不能复用
    ---- regionend

    self.scroll = scroll    -- 滑动控件
    self.prefab = prefab    -- 如果设置了prefab，则listView自动创建元素，然后回调函数中只负责控件赋值。如果没设置，则回调函数中负责创建
    self._delegate = delegate
    self._name = name

    if self.prefab then
        -- 注意prefab的anchor要调整为左上角对齐，否则排版可能不正确。这里直接调整无法同时修正坐标，等找到正确的方式后再做修改
--        local tr = self.prefab.transform
        -- local pos = tr.position
        -- tr.anchorMin = Vector2(0, 1)
        -- tr.anchorMax = Vector2(0, 1)
        -- tr.pivot = Vector2(0, 1)
        -- tr.position = pos
        SetActive(self.prefab, false)
    end

    self.content = self.scroll.content

    self.isForbidScroll = false
    self.isHoriScroll = self.horizontal       -- 记录之前的滑动方向，以便还原
    self.isVertScroll = not self.horizontal

    self.maxCount = 0   -- 最大元素数目
    self.itemList = {}  -- 所有的列表元素

    self.itemParent = nil --列表项父节点

    self.onCreateItem = self:_GetFunction('OnCreateItem')

    if not self.onCreateItem then
        error('界面没有实现OnCreateItem')
        return
    end
end

-- 获取索引位置的元素
function ListView:CellAtIndex(index)
    return self.itemList[index]
end

-- 获取索引位置的元素 -- 和CellAtIndex的区别??
function ListView:GetItem(index)
    return self.itemList[index]
end

-- 返回视图的列表项的数目
function ListView:Length()
    return #self.itemList
end

-- 获取所有元素
function ListView:GetAllCellsArray()
    return self.itemList
end

-- 禁止滑动
function ListView:ForbidScroll()
    if self.isForbidScroll then return end
    self.isForbidScroll = true

    self.isHoriScroll = self.scroll.horizontal
    self.isVertScroll = self.scroll.vertical
    self.scroll.horizontal = false
    self.scroll.vertical   = false
    self.scroll:StopMovement()
end

--重启可以滑动
function ListView:RestartScroll()
    self.isForbidScroll = false
    self.scroll.horizontal = self.isHoriScroll
    self.scroll.vertical   = self.isVertScroll
end

--直接滑动到顶部
function ListView:ScrollToTop()
    if self.horizontal then
        if self.scroll.horizontalNormalizedPosition ~= 0 then
            self.scroll.horizontalNormalizedPosition = 0
        end
    else
    	if self.scroll.verticalNormalizedPosition ~= 1 then
            self.scroll.verticalNormalizedPosition = 1
        end
    end
end

--直接滑动到指定的index
function ListView:ScrollTo(index)
    if self.maxCount < index or index <= 0   then
        error("error index " .. tostring(index))
        return
    end
    if self.maxCountPerLine <= 0 then
        return
    end

    -- 总行数、当前数应该是向上取整
    local totalRow = math.ceil(self.maxCount / self.maxCountPerLine)
    local curRow = math.ceil(index / self.maxCountPerLine)
    --[[
        1 2 3 4
      1 x x x x
      2 x x x x
      3 x x x x
      x为列表项,左边和上边分别为列表的行列数
      第1行应该滑到的位置为 (1 - 1)/(3 - 1) = 0 的位置
      第2行应该滑到的位置为 (2 - 1)/(3 - 1) = 0.5 的位置
      第3行应该滑到的位置为 (3 - 1)/(3 - 1) = 1 的位置
    ]]
    -- 防止除0错误
    if totalRow - 1 <= 0 then
        return
    end
    local pos = (curRow - 1) / (totalRow - 1)


    if self.horizontal then
        if self.scroll.horizontalNormalizedPosition ~= pos then
            self.scroll.horizontalNormalizedPosition = pos
        end
    else
        -- 竖直排列需要反过来
        pos = 1 - pos
        if self.scroll.verticalNormalizedPosition ~= pos then
            self.scroll.verticalNormalizedPosition = pos
        end
    end
end

--[[
    滑动到指定索引，利用的是Item的相对anchoredPosition。
    cantExceed可选，对Elastic的ScrollRect控件有影响。如果cantExceed为false，且目标索引上的列表项设置位置后会超出Viewport，那么视觉上会看见弹性效果。
    组件上的Viewport字段要设置好
    NOTE: 实现时的思路基于前提：anchor为左上角
]]
function ListView:ScrollToBasedOnItemPos(index, cantExceed)
    -- default args.
    if cantExceed == nil then cantExceed = true end

    local go = self.itemList[index]
    if go then
        --[[ 实现时的思路基于前提：anchor为左上角 ]]
        -- 考虑pivot
        if self.horizontal then
            local extraSize = go:GetAnchoredPosition().x - go:GetSize().x * (go.transform.pivot.x)
            if cantExceed then
                local maxSize = math.max(0, self.content:GetSize().x - self:GetViewportSize().x)  -- 保证大于等于0
                -- maxSize是0的时候意味着内容区域小于视图，等于pin在原点。
                extraSize = math.min(extraSize, maxSize)
            end
            self.content:SetAnchoredPositionX(-extraSize)  -- negative
        else
            local extraSize = -(go:GetAnchoredPosition().y) - go:GetSize().y * (1 - go.transform.pivot.y)
            if cantExceed then
                local maxSize = math.max(0, self.content:GetSize().y - self:GetViewportSize().y)  -- 保证大于等于0
                -- maxSize是0的时候意味着内容区域小于视图，等于pin在原点。
                extraSize = math.min(extraSize, maxSize)
            end
            self.content:SetAnchoredPositionY(extraSize)  -- positive
        end
    end
end

-- 获取视口尺寸
function ListView:GetViewportSize()
    return self.scroll.viewport:GetSize()
end

-- 只是简单地设置了NormalizedPosition而已，待结合实际用途优化
function ListView:ScrollToPos(pos)
    pos = math.max(0, math.min(pos, 1))
    if self.horizontal then
        if self.scroll.horizontalNormalizedPosition ~= pos then
            self.scroll.horizontalNormalizedPosition = pos
        end
    else
        if self.scroll.verticalNormalizedPosition ~= pos then
            self.scroll.verticalNormalizedPosition = pos
        end
    end
end

-- 添加一个元素到列表末尾
function ListView:AddItem(go)
    local size = self.content.sizeDelta
    go:SetParent(self.itemParent or self.content, false)
    SetActive(go, true)
    go:SetAnchoredPosition(size.x, -size.y)
    table.insert(self.itemList, go)

    -- 更新最大元素数量
    self.maxCount = self.maxCount + 1
    if self.horizontal then
        self.content:SetSizeDelta(size.x + go.transform.sizeDelta.x, size.y)
    else
        self.content:SetSizeDelta(size.x, size.y + go.transform.sizeDelta.y)
    end
end

-- 删除元素
function ListView:RemoveItem(index)
    if index ~= nil then
        table.remove(self.itemList, index)
    end
end

-- 设置最大数目
function ListView:SetMaxCount(count, refresh, scrollToTop)
    self.maxCount = count

    if refresh ~= false then
        -- 刷新元素
        self:ReloadData()

        -- 移到顶部
        if scrollToTop ~= false then
            self:ScrollToTop()
        end
    end
end

-- 选中列表项
function ListView:SelectItem(index, refresh)
    local func = self:_GetFunction('OnSelectItem')
    if func then
        func(self._delegate, index, self.itemList[index])
    end

    local funcUn = self:_GetFunction('OnUnselectItem')
    if funcUn then
        -- 如果不允许多选，则取消其他列表选择
        if not self.enableMultiSelect then
            for i,v in ipairs(self.itemList) do
                if i ~= index then
                    funcUn(self._delegate, i, v)
                end
            end
        end
    end

    if refresh == true then
        self:UpdateItemPos()
    end
end

function ListView:UnSelectItem(index, refresh)
    local funcUn = self:_GetFunction('OnUnselectItem')
    if funcUn then
        funcUn(self._delegate, index, self.itemList[index])
    end

    if refresh == true then
        self:UpdateItemPos()
    end
end

function ListView:AddContentSize(addSize)
    self.content.sizeDelta = self.content.sizeDelta + addSize
end

function ListView:GetContentHeight()
    return self.content.sizeDelta.y
end

-- 设置滑动区域大小
function ListView:_SetContentSize(maxSize)
    local size = self.content.sizeDelta
    if self.horizontal then
        self.content.sizeDelta = Vector2(maxSize, size.y)
    else
        self.content.sizeDelta = Vector2(size.x, maxSize)
    end
end

-- 刷新列表
function ListView:ReloadData()
    -- 清理旧控件
    if not self.reuseItem then
        for c,v in pairs(self.itemList) do
            Destroy(v)
        end
    end

    local oldItemList = self.itemList

    self.itemList = {}
    for i = 1, self.maxCount do
        -- 创建元素
        local go = nil
        if self.prefab == nil then
            go = self.onCreateItem(self._delegate, i)

            -- 回调函数里面创建的go，只能之后设置了，如果有逻辑问题，可以在回调里面自己SetActive
            go:SetParent(self.itemParent or self.content, false)
            SetActive(go, true)
        else
            if self.reuseItem and oldItemList[i] then
                go = oldItemList[i]
            else
                go = Instantiate(self.prefab, tostring(i))
            end

            -- 先SetActive，这样才会调用控件的Awake等函数，防止一些异常情况
            go:SetParent(self.itemParent or self.content, false)
            SetActive(go, true)
            self.onCreateItem(self._delegate, i, go)
        end

        table.insert(self.itemList, go)
    end

    -- 清理不用的go
    if self.reuseItem and #oldItemList > self.maxCount then
        for i = self.maxCount + 1, #oldItemList do
            Destroy(oldItemList[i])
        end
    end

    if #self.itemList >= 1 then
        local pos = self.itemList[1].transform.anchoredPosition
        self.startX = pos.x
        self.startY = pos.y
    end

    self:UpdateItemPos()
end

function ListView:UpdateItemPos()
    local x,y = 0,0
    local maxSize = 0
    local itemSize = Vector3(0,0)
    for i = 1, self.maxCount do
        -- 创建元素
        local go = self.itemList[i]
        local tr = go.transform

        itemSize = tr.sizeDelta -- 记录元素的大小

        -- 第一个元素设置起始偏移
        if i == 1 then
            x = self.startX
            y = self.startY
            -- yunmu 2017/09/20 星际探索开采界面使用
            if not self.horizontal then
                maxSize =  self.contnetInitSize
            end
        end

        go:SetAnchoredPosition(x, y)

        -- 设置高度
        if self.horizontal then
            -- 水平滑动
            if i % self.maxCountPerLine == 0 then
                maxSize = maxSize + itemSize.x + self.space + self.spaceX
                x = x + itemSize.x + self.space + self.spaceX
                y = self.startY
            else
                 y = y - itemSize.y - self.spaceY
            end
        else
            -- 垂直滑动或者不滑动
            if i % self.maxCountPerLine == 0 then
                maxSize = maxSize + itemSize.y + self.space + self.spaceY
                x = self.startX
                y = y - itemSize.y - self.space - self.spaceY
            else
                x = x + itemSize.x + self.spaceX
            end
        end
    end

    -- maxSize会多加一个结尾的间距，要减掉
    if self.maxCount > 0 then
        if self.horizontal then
            -- 水平滑动
            maxSize = maxSize - self.space - self.spaceX
        else
            -- 垂直滑动或者不滑动
            maxSize = maxSize - self.space - self.spaceY
        end
    end

    if self.maxCount % self.maxCountPerLine ~= 0 then
         if self.horizontal then
            maxSize = maxSize + itemSize.x + self.space + self.spaceX
         else
            maxSize = maxSize + itemSize.y + self.space + self.spaceY
         end
    end

    if self.contnetMinSize then
        maxSize = math.max(maxSize, self.contnetMinSize)
    end

    -- 留空有更多选择
    maxSize = maxSize + self.PaddingStart + self.PaddingEnd
    self:_SetContentSize(maxSize)
end

-- 列表项的偏移值
function ListView:AddItemOffset(i, offset)
    local go = self.itemList[i]
    local tr = go.transform
    local pos = tr.anchoredPosition - offset
    tr:SetAnchoredPosition(pos.x, pos.y)
end

function ListView:SetVisible(visible)
    SetActive(self.scroll, visible)
end

function ListView:IsVisible()
    return self.scroll:IsActive()
end

function ListView:SwapWithFirstItem(index)
    if index and index <= #self.itemList then
        self.itemList[index], self.itemList[1] = self.itemList[1], self.itemList[index]
    end
end

function ListView:SwapItem(firstIndex, secondIndex)
    if not firstIndex or not secondIndex then return end
    if firstIndex > self.maxCount or firstIndex < 1 then return end
    if secondIndex > self.maxCount or secondIndex < 1 or secondIndex == firstIndex then return end

    local item = self.itemList[firstIndex]
    self.itemList[firstIndex] = self.itemList[secondIndex]
    self.itemList[secondIndex] = item
end

-- 设置是否横向滑动
function ListView:SetHorizontal(isHorizontal)
    self.horizontal = isHorizontal
end