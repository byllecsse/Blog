-- 简单的树型控件
ExpandListView = class('ExpandListView', BaseCtrl)

-- OnCreateGroup
-- OnCreateItem
-- panelPrefab  可选的第二层元素的父节点的prefab。提供定制化可能，如给第二层加背景。
function ExpandListView:ctor(scroll, groupPrefab, itemPrefab, panelPrefab, delegate, name)
    ---- region 需要外部设置的属性
    self.origin = Vector2(0, 0)     -- 列表元素起始点，默认为(0,0)，惯用法：可以通过prefab坐标来设置设个值
    self.originGroup = Vector2(0, 0)
    self.space = 0  -- 元素间距
    self.spaceGroup = 0 -- 组间距
    self.topSpace = 0  -- 顶部留空
    self.enableMultiSelect = false  -- 是否允许多选
    ---- regionend

    self.scroll = scroll   -- 滑动控件
    self.scroll.horizontal = false
    self.content = self.scroll.content
    self.groupPrefab = groupPrefab
    self.itemPrefab = itemPrefab
    self.panelPrefab = panelPrefab
    self._delegate = delegate
    self._name = name

    self.maxCount = {}  -- 每个组的最大数目
    self.groupList = {}  -- 所有的列表元素
end

-- 展开一组
function ExpandListView:Expand(groupIndex)
    self.groupList[groupIndex].expand = true
    self:_ReLayout()

    local func = self:_GetFunction('OnExpandGroup')
    if func then
        -- 这里需要获取其他的数据 所以直接传group进去
        func(self._delegate, groupIndex, self.groupList[groupIndex])
    end
end

-- 收缩一组
function ExpandListView:Collapse(groupIndex)
    self.groupList[groupIndex].expand = false
    self:_ReLayout()

    local func = self:_GetFunction('OnCollapseGroup')
    if func then
        func(self._delegate, groupIndex, self.groupList[groupIndex])
    end
end

-- 在展开和折叠之间切换
function ExpandListView:ToggleExpand(groupIndex)
    self.groupList[groupIndex].expand = not self.groupList[groupIndex].expand

    local func
    if self.groupList[groupIndex].expand then
        func = self:_GetFunction('OnExpandGroup')
    else
        func = self:_GetFunction('OnCollapseGroup')
    end
    
    if func then
        func(self._delegate, groupIndex, self.groupList[groupIndex])
    end
    self:_ReLayout()
end

function ExpandListView:_ReLayout()
    local y = 0
    for i,v in ipairs(self.groupList) do
        local expand = v.expand
        local group = v.group
        local panel = v.panel

        if i == 1 then
            y = group.anchoredPosition.y - self.topSpace
            self.topSpace = 0
        end

        group:SetAnchoredPositionY(y)
        y = y - group.sizeDelta.y - self.spaceGroup

        if expand then
            panel:SetSizeDelta(v.panelWidth, v.panelHeight)
            panel:SetAnchoredPosition(panel.anchoredPosition.x, y)
            y = y - panel.sizeDelta.y
            SetActive(panel, true)
        else
            panel:SetSizeDelta(0,0)
            SetActive(panel, false)
        end
    end

    self.content:SetSizeDeltaY(-y)
end

-- 为了SetMaxCount的时候可以连组的数目也改变，这里就粗暴地删除所有已有的了
function ExpandListView:ClearAllGroup()
    for i, v in ipairs(self.groupList) do
        self:Clear(i)
        Destroy(v.panel.gameObject)
        Destroy(v.group.gameObject)
    end
    self.groupList = {}
end

-- 设置最大数目 传递的是一个数组，里面是每个组的最大数目，如 {5,4,5,6}
function ExpandListView:SetMaxCount(maxCount)
    self:ClearAllGroup()
    
    self.maxCount = maxCount
    local y = 0
    for i,v in ipairs(self.maxCount) do
        table.insert(self.groupList, {count=v, expand=false, group=nil, panel=nil, itemList={},panelHeight=0})

        y = self:_CreateGroup(i, y)

        local size = self:_ReloadGroup(i)
        y = y - size.y
    end
    self.content:SetSizeDeltaY(-y)
    self:_ReLayout()
end

-- 创建Group
function ExpandListView:_CreateGroup(index, y)
    -- 创建元素，如果有设置事件，则优先使用设置的事件，否则取界面的创建函数
    local go = nil
    local func = self:_GetFunction('OnCreateGroup')
    if not func then
        error('界面没有实现OnCreateGroup')
        return
    end

    if self.groupPrefab == nil then
        go = func(self._delegate, index)
    else
        go = Instantiate(self.groupPrefab, 'group'..tostring(index))
        func(self._delegate, index, go)
    end

    local tr = go.transform

    if index == 1 then
        y = tr.anchoredPosition.y
    end

    local size = tr.sizeDelta

    -- 组标题
    tr:SetParent(self.content, false)
    SetActive(go, true)
    tr:SetAnchoredPositionY(y)
    self.groupList[index].group = tr

    -- 点击Group标题可以在展开和折叠之间进行切换
    local button = go:GetComponent('UIButton')
    if button then
        button.onClick:AddListener(function()
            self:ToggleExpand(index)
        end)
    else
        local toggle = go:GetComponent('UIToggle')
        if toggle then
            toggle.onValueChanged:AddListener(function(value)
                self:ToggleExpand(index)
            end)
        end
    end

    -- 存放所有的
    local goPanel
    if self.panelPrefab then
        goPanel = Instantiate(self.panelPrefab, 'Panel w/ prefab '..tostring(index))
    else
        goPanel = GameObject('Panel'..tostring(index))
    end
    local panel = goPanel:GetComponent(typeof(UnityEngine.RectTransform))
    if IsNull(panel) then
        panel = goPanel:AddComponent(typeof(UnityEngine.RectTransform))
    end
    panel:SetParent(self.content, false)
    panel.anchorMin = Vector2(0, 1)
    panel.anchorMax = Vector2(0, 1)
    panel.pivot = Vector2(0, 1)
    panel:SetAnchoredPosition(0, y - size.y)
    self.groupList[index].panel = panel
    return y - size.y
end

-- 选中列表项
function ExpandListView:SelectItem(groupIndex, itemIndex)
    if self._delegate == nil then return end

    local func = self:_GetFunction('OnSelectItem')
    if func then
        func(self._delegate, groupIndex, itemIndex, self.groupList[index].itemList[itemIndex])
    end

    func = self:_GetFunction('OnUnselectItem')

    -- 如果不允许多选，则取消其他列表选择
    if func and not self.enableMultiSelect then
        for i,v in ipairs(self.groupList) do
            for ii,vv in ipairs(v.itemList) do
                if i ~= groupIndex or ii ~= itemIndex then
                    func(self._delegate, i, ii, vv)
                end
            end
        end
    end
end

-- 设置容器大小(实际滑动内容控件的大小，不是裁剪区域的大小)
function ExpandListView:_FixContentSize()
    if self.flexibleSize then
        -- 自适应的高度需要根据实际元素计算，滑动区域的大小不在这里设置，而是等元素创建完统一设置
        return
    end

    local count = self.maxCount
    local size = self.content.sizeDelta
    -- 竖直滑动
    --注意在制作vertical滑动的scrollView的时候将content的anchor 设置为 (0.5, 1)
    local maxHeight = math.ceil(count / self.maxCountPerLine) * self.cell.y
    self.content:SetSizeDeltaY(maxHeight)
end

-- 设置滑动区域大小
function ExpandListView:SetContentSize(maxSize)
    local size = self.content.sizeDelta
    self.content:SetSizeDeltaY(maxSize)
end

-- 清理所有的子控件
function ExpandListView:Clear(groupIndex)
    for c,v in pairs( self.groupList[groupIndex].itemList) do
        Destroy(v)
    end
    self.groupList[groupIndex].itemList = {}
end

-- 刷新列表。这个不会重新创建【组】
function ExpandListView:ReloadData()
    for i,v in ipairs(self.groupList) do
        self:_ReloadGroup(i)
    end
end

-- 刷新列表中的一个组
function ExpandListView:_ReloadGroup(groupIndex)
    local group = self.groupList[groupIndex]
    self:Clear(groupIndex)

    local size = Vector2(0, 0)
    local lastSize = Vector2(0, 0)
    local x, y = 0, 0
    for i = 1, group.count do
        if i ~= 1 then
            y = y - lastSize.y - self.space
        end

        -- 创建元素，如果有设置事件，则优先使用设置的事件，否则取界面的创建函数
        local go = nil
        local func = self:_GetFunction('OnCreateItem')
        if not func then
            error('界面没有实现OnCreateItem')
            return
        end

        local itemIndex = i
        if self.itemPrefab == nil then
            go = func(self._delegate, groupIndex, itemIndex)
        else
            go = Instantiate(self.itemPrefab, tostring(itemIndex))
            func(self._delegate, groupIndex, go, itemIndex)
        end

        local tr = go.transform

        lastSize = tr.sizeDelta
        if lastSize.x > size.x then
            size.x = lastSize.x
        end

        tr:SetParent(group.panel, false)
        SetActive(go, true)
        tr:SetAnchoredPositionY(y)
        size.y = size.y + lastSize.y + self.space
        table.insert(group.itemList, go)
    end
    group.panelHeight = size.y
    group.panelWidth = size.x
    group.panel:SetSizeDelta(group.panelWidth, group.panelHeight)
    return size
end

-- 设置当前滚动的百分比，起点是1，终点是0
function ExpandListView:ScrollToPos(percent)
    if self.scroll.horizontal then
        if self.scroll.horizontalNormalizedPosition ~= percent then
            self.scroll.horizontalNormalizedPosition = percent
        end
    else
        if self.scroll.verticalNormalizedPosition ~= percent then
            self.scroll.verticalNormalizedPosition = percent
        end
    end
end