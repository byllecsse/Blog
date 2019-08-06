-- 仿iOS的UITableView 功能：
-- 1、动态增加、删除或插入元素
-- 2、根据可显示区域创建并复用控件，适用于列表元素数目非常大的情况
-- 3、列表元素高度可不同，prefab也可不同

-- 默认支持的事件回调
-- OnCreateItem(index, cell, isNewCell) -- 如果有指定prefab，则此回调会自动创建cell，界面代码只负责更新控件，否则界面代码要使用PopObject创建cell并返回
-- OnItemSizeAtIndex(index)             -- 返回cell的大小，它是先于OnCreateItem调用的
-- OnSelectItem(index, cell)
-- OnUnselectItem(index, cell)

-- ps:
-- 返回的cell是个table
-- AddItem/RemoveItem优化过

TableView = class('TableView', BaseCtrl)
local DEFAULT_POOL = 'TableViewPool'
local DefaultSize = Vector2(100, 100)

function TableView:ctor(scroll, prefab, delegate, name)
    -- regionbegin 外部设置的变量
    self.space = 0  -- 元素间距
    self.spaceX = 0 -- 非滑动方向的间距
    self.spaceY = 0
    self.fixedSize = nil    -- 固定大小
    self.maxCountPerLine = 1    -- 每行（列）的最大元素数目，如果是垂直滑动，则限制水平方向的元素数目
    self.enableMultiSelect = false  -- 是否允许多选
    self.viewBufferSize = 0     -- 缓冲区域大小 设置的大一些可以多显示一些元素，以便优化表现效果
    self.contentSizeExpand = 0  -- 滑动区域扩大大小
    self.onGetCell = nil        -- 获取cell后调用，如果设置了这个回调函数，则不再执行cell本身的Show函数，主要目的是避免SetActive提高性能
    self.onFreeCell = nil       -- 回收cell后调用
    -- regionend

    self._delegate = delegate
    self._name = name
    self.scroll = scroll    -- 滑动控件
    self.poolList = {}      -- 缓存池列表 {{name='xx', stack={}}, ...}
    self.prefab = prefab    -- 元素prefab，如果设置了prefab，则列表会自动创建元素，然后通知逻辑更新。如果不同的格子显示不同的prefab，则不要设置这个参数
    self.horizontal = self.scroll.horizontal  -- 是否是横向滑动的,不能直接修改这个值,使用SetHorizontal修改
    self.content = self.scroll.content        -- 列表元素的父节点

    -- 是否锁定滑动
    self.isForbidScroll = false

    if self.prefab then
        SetActive(self.prefab, false)
        local prefabRectTrans = self.prefab.transform
        local pivotOffsetX, pivotOffsetY = self:_GetCellPivotOffset(prefabRectTrans)
        local pos = prefabRectTrans.anchoredPosition
        self.origin = Vector2(pos.x - pivotOffsetX, pos.y - pivotOffsetY)
    else
        self.origin = Vector2(0, 0)  -- 起始元素坐标
    end

    self.maxCount = 0           -- 最大元素数目
    self.cellsInUse = {}        -- 正在使用的cell列表
    self.cellsOffsets = {}      -- 所有cell的坐标

    self.cellsInUseTemp = {}    -- 这两个table用在onValueChanged里面，防止频繁的创建table表
    self.cellsInUseIndex = {}

    -- 监测滑动
    self.scroll.onValueChanged:AddListener(handler(self, self._OnValueChanged))

    self.onCreateItem = self:_GetFunction('OnCreateItem')
    self.onItemSizeAtIndex = self:_GetFunction('OnItemSizeAtIndex')
    self.onSelectitem = nil
    self.onUnSelectItem = nil
end

function TableView:GetCurContentSize()
    return self.content:GetSize()
end

function TableView:GetViewportSize()
    return self.scroll.viewport:GetSize()
end

-- 设置监听函数，外部可监听当前滑动到什么位置
function TableView:AddOnValueChangedListener(handler)
    self.onValueChangedFunc = handler
end

-- 通过外部回调获取某个cell的大小
function TableView:GetCellSize(index)
    -- 如果指定了固定大小，则直接返回这个大小即可
    if self.fixedSize then return self.fixedSize end

    -- 如果没有指定大小的接口，并且没有设置大小的话，可以从prefab中获取大小
    if self.onItemSizeAtIndex == nil then
        if self.prefab then
            local size = self.prefab.transform.rect
            self.fixedSize = Vector2(size.width, size.height)
        else
            -- 没有指定prefab的话，就随便指定一个大小
            self.fixedSize = DefaultSize
        end
        return self.fixedSize
    end

    -- 计算元素宽高
    return self.onItemSizeAtIndex(self._delegate, index) or DefaultSize
end

function TableView:GetCellPivot()
    if self.prefab then
        return self.prefab.transform.pivot
    end
    return Vector2(0, 0)
end

-- 弹出元素 如果没有指定prefab而是外部创建元素的时候需要先调用此接口获取可复用控件，如果没有的话，再创建新的控件
-- 注意，一定要使用此接口来创建GameObject，除非有明确的需求否则不要直接使用newObject
function TableView:PopObject(poolName, prefab, preferIndex)
    -- 返回的tableCell
    local cell

    -- 先查缓存
    poolName = poolName or DEFAULT_POOL
    preferIndex = preferIndex or -1
    local pool = self.poolList[poolName]
    if pool ~= nil then
        -- 优先复用原来那个
        for i, v in ipairs(pool.stack) do
            if v.index == preferIndex or i == #pool.stack then
                cell = v
                table.remove(pool.stack, i)
                break
            end
        end

        if cell then
            cell.index = preferIndex

            -- 有的时候仅仅是内部逻辑复用cell，cell没有被隐藏
            if not cell.isInUse then
                if self.onGetCell then
                    self.onGetCell(cell)
                else
                    cell:Show()
                end
            end
            return cell, false
        end
    end

    if prefab == nil then
        error('没有指定prefab')
        return nil, false
    end

    -- 创建新的
    -- 如果有指定prefab，则创建对应的go，并设置好缓存池名字
    cell = TableCell.new(Instantiate(prefab, prefab.name .. preferIndex)) -- 区分不同prefab
    cell.index = preferIndex
    cell.spawnIndex = preferIndex
    cell.pool = poolName

    if self.onGetCell then
        self.onGetCell(cell)
    else
        cell:Show()
    end

    return cell, true
end

-- 根据初始数据初始化滑动列表，初始元素的对应控件会全部创建出来，如果不创建的话，就不知道整体大小
function TableView:SetMaxCount(count, reloadData)
    self.maxCount = count

    if reloadData == true or reloadData == nil then
        self:ReloadData()
    end
end

-- 重新加载所有数据
function TableView:ReloadData()
    -- 先统一释放，从后往前释放，这样后面复用的时候可以保证优先取到的就是之前的go
    if #self.cellsInUse > 0 then
        for i = #self.cellsInUse, 1, -1 do
            self:_StoreReuseObject(self.cellsInUse[i])
        end
    end

    table.clear(self.cellsInUse)

    -- 计算每个单元
    self:_UpdateCellPosition()
    self:_UpdateContentSize()

    -- 这里面显示单元
    if self.maxCount > 0 then
        self:_OnValueChanged()
    end
    self.maxCellInUse = #self.cellsInUse
end

-- 插入一个cell
-- TODO插入在最后没问题。中间插入要调用self:_OnValueChanged(nil) 方便回收
function TableView:AddItem(index)
    index = index or self.maxCount + 1
    if index <= 0 or index > self.maxCount + 1 then
        return
    end

    self.maxCount = self.maxCount + 1
    -- 往后移一单位
    for i, v in ipairs(self.cellsInUse) do
        if v.index >= index then
            v.index = v.index + 1
        end
    end

    -- 创建并插入cell
    local cell = self:_CreateCell(index)

    -- 插入一个位置。后面的统一后移
    local cellSize = self:GetCellSize(index)
    local plus = (self.horizontal and cellSize.x or cellSize.y) + self.space

    table.insert(self.cellsOffsets, index, self.cellsOffsets[index])
    for i = index + 1, #self.cellsOffsets do
        self.cellsOffsets[i] = self.cellsOffsets[i] + plus
    end

    -- 应用这个
    self:_UseCell(cell)
    self:_UpdateContentSize()

    -- 位置从新排列。如果是中间插入。向后移的可能被回收
    for i, v in ipairs(self.cellsInUse) do
        if v.index > index then
            local x, y = self:_GetCellAnchoredPosition(v)
            v:SetAnchoredPosition(x, y)
        end
    end
end

-- 移除cell
function TableView:RemoveItem(index)
    if index <= 0 or index > self.maxCount then
        return
    end

    -- 移除一个后面的往前移
    local minus = self.cellsOffsets[index + 1] - self.cellsOffsets[index]
    for i = index + 1, #self.cellsOffsets do
        self.cellsOffsets[i - 1] = self.cellsOffsets[i] - minus
    end
    table.remove(self.cellsOffsets, #self.cellsOffsets)

    local cell = self:CellAtIndex(index)
    if cell then
        -- 先移除指定的cell
        self:_MoveCellOutOfSight(cell)
    end
    self.maxCount = self.maxCount - 1

    -- 更新滑动区域的大小
    self:_UpdateContentSize()

    -- 有的回收。有的要新增显示
    -- 下面这个遍历有点繁琐
    for i, v in ipairs(self.cellsInUse) do
        if v.index > index then
            v.index = v.index - 1
            local x, y = self:_GetCellAnchoredPosition(v)
            v:SetAnchoredPosition(x, y)
        end
    end
    self:_OnValueChanged(nil)
end

-- 选中列表项
function TableView:SelectItem(index)
    if self.onSelectitem == nil then
        self.onSelectitem = self:_GetFunction('OnSelectItem')
    end

    if self.onSelectitem then
        self.onSelectitem(self._delegate, index, self:CellAtIndex(index))
    end

    if self.enableMultiSelect then
        return
    end

    if self.onUnSelectItem == nil then
        self.onUnSelectItem = self:_GetFunction('OnUnselectItem')
    end

    if not self.onUnSelectItem then
        return
    end

    -- 如果不允许多选，则取消其他列表选择
    for i, v in ipairs(self.cellsInUse) do
        if v.index ~= index then
            self.onUnSelectItem(self._delegate, v.index, v)
        end
    end
end

function TableView:UnSelectItem(index)
    if self.onUnSelectItem == nil then
        self.onUnSelectItem = self:_GetFunction('OnUnselectItem')
    end

    if not self.onUnSelectItem then
        return
    end
    self.onUnSelectItem(self._delegate, index, self:CellAtIndex(index))
end

------------------------ 滑动位置相关 ------------------------
-- 类似于GetCurrScrollPos()，这个是获取从起始位置开始的距离（正数）
function TableView:GetCurrScrollLength()
    local size = self:GetCurContentSize()
    local contentLength = self.horizontal and size.x or size.y

    -- SetMaxCount那还有个参数可以不执行Reload，如果不执行，数据就不会刷新，contentSize也不会更新
    if self.maxCount < 1 then
        contentLength = 0
    end

    if contentLength == 0 then
        return 0
    else
        return (1 - self:GetCurrScrollPos()) * contentLength
    end
end

-- 类似于ScrollToPos(percent)，这个是滚动一段距离（从起始位置开始的正数）
function TableView:ScrollToLengthFromStart(length)
    local size = self:GetCurContentSize()
    local contentLength = self.horizontal and size.x or size.y

    -- SetMaxCount那还有个参数可以不执行Reload，如果不执行，数据就不会刷新，contentSize也不会更新
    if self.maxCount < 1 then
        contentLength = 0
    end

    if contentLength == 0 then return end

    if length >= contentLength then
        self:ScrollToPos(0)
    elseif length <= 0 then
        self:ScrollToPos(1)
    else
        self:ScrollToPos(1 - length / contentLength)
    end
end

-- 获取当前滚动的百分比，起点是1，终点是0
function TableView:GetCurrScrollPos()
    return self.horizontal and self.scroll.horizontalNormalizedPosition or self.scroll.verticalNormalizedPosition
end

-- 设置当前滚动的百分比，起点是1，终点是0
function TableView:ScrollToPos(percent)
    if self.horizontal then
        if self.scroll.horizontalNormalizedPosition ~= percent then
            self.scroll.horizontalNormalizedPosition = percent
        end
    else
        if self.scroll.verticalNormalizedPosition ~= percent then
            self.scroll.verticalNormalizedPosition = percent
        end
    end

    if not self:CheckVisable() then
        self:_OnValueChanged()
    end
end

function TableView:CheckVisable()
    if IsNull(self.scroll.gameObject) then
        return true
    end

    return self.scroll.gameObject.activeInHierarchy
end

-- 滚动到最下面(横向就是最左面)
function TableView:ScrollToBottom()
    self:ScrollToPos(0)
end

--直接滑动到顶部(横向就是最右面)
function TableView:ScrollToTop()
    self:ScrollToPos(1)
end

function TableView:StepToBottom()
    self:StepMove(-1)
end

function TableView:StepToTop()
    self:StepMove(1)
end

function TableView:StepMove(positiveNegative1)
    local hidden = self.maxCount - self.maxCellInUse
    if hidden <= 0 then return end

    local stepPercent = 1 / hidden

    if self.horizontal then
        self.scroll.horizontalNormalizedPosition = self.scroll.horizontalNormalizedPosition + positiveNegative1 * stepPercent
    else
        self.scroll.verticalNormalizedPosition = self.scroll.verticalNormalizedPosition + positiveNegative1 * stepPercent
    end
    self:_OnValueChanged()
end

-- 滑动到指定index
function TableView:ScrollTo(index)
    local pos = self:GetScrollPosByIndex(index)

    if not pos then
        return
    end

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

--- 代替GetScrollPosByIndex和ScrollTo，会准确滚到指定序号的位置
--- 指定序号完整出现在viewport的滚动方向终点
function TableView:ScrollToIndexPrecise(index)
    if not self.prefab then
        return
    end

    if index < 1 or index > self.maxCount then
        return
    end

    local viewSize = self:GetViewportSize()
    local contentSize = self:GetCurContentSize()

    local viewLen
    local contentLen

    local oriLen
    if self.horizontal then
        viewLen = viewSize.x
        contentLen = contentSize.x
        oriLen = self.origin.x
    else
        viewLen = viewSize.y
        contentLen = contentSize.y
        oriLen = self.origin.y
    end

    local realLen = contentLen - viewLen
    if realLen <= 0 then
        return
    end

    -- 滚动距离的数字是 真实移动距离/（content - viewPort）
    local itemSize = self:GetCellSize(index)
    local itemLen = self.horizontal and itemSize.x or itemSize.y
    local walkLen = self.cellsOffsets[index] + itemLen + self.space

    local itemRealLen = walkLen + oriLen - viewLen
    local percent = 0
    if itemRealLen <= 0 then
        percent = 1
    else
        percent = 1 - itemRealLen / realLen
    end

    self:ScrollToPos(percent)

    -- 通过回调触发_OnValueChanged可能会延后，所以手动触发一下
    self:_OnValueChanged()
end

-- 类似 ScrollToIndexPrecise
-- 指定序号完整出现在viewport的滚动方向起点
function TableView:ScrollToIndexAtViewportHead(index)
    if not self.prefab then
        return
    end

    if index < 1 or index > self.maxCount then
        return
    end

    local viewSize = self:GetViewportSize()
    local contentSize = self:GetCurContentSize()

    local viewLen
    local contentLen

    local oriLen
    if self.horizontal then
        viewLen = viewSize.x
        contentLen = contentSize.x
        oriLen = self.origin.x
    else
        viewLen = viewSize.y
        contentLen = contentSize.y
        oriLen = self.origin.y
    end
    
    local realLen = contentLen - viewLen
    if realLen <= 0 then
        return
    end

    -- 滚动距离的数字是 真实移动距离/（content - viewPort）
    local itemSize = self:GetCellSize(index)
    local itemLen = self.horizontal and itemSize.x or itemSize.y
    local walkLen = self.cellsOffsets[index]

    local itemRealLen = walkLen
    local percent = 0
    if itemRealLen <= 0 then
        percent = 1
    else
        percent = 1 - itemRealLen / realLen
    end

    self:ScrollToPos(percent)

    -- 通过回调触发_OnValueChanged可能会延后，所以手动触发一下
    self:_OnValueChanged()
end

function TableView:GetScrollPosByIndex(index)
    if self.maxCount < index or index <= 0   then
        error("error index " .. tostring(index))
        return nil
    end

    if self.maxCountPerLine <= 0 then
        return nil
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
        return nil
    end

    local pos = (curRow - 1) / (totalRow - 1)

    if self.horizontal then
        return pos
    else
        -- 竖直排列需要反过来
        return 1 - pos
    end
end
------------------------ 滑动位置相关 ------------------------

-- 刷新cell,同时更新列表各个Item的位置
function TableView:RefreshItem(index)
    local cell = self:CellAtIndex(index)
    if cell == nil then return end

    -- 在显示区域内，刷新
    if self.onCreateItem then
        cell = self.onCreateItem(self._delegate, index, cell, false)
    end
    self:RefreshAllItemPos()
end

-- 更新所有item的坐标,用于在外部状态改变导致item的size改变时更新坐标
function TableView:RefreshAllItemPos()
    -- 更新坐标记录和滑动区域的大小
    self:_UpdateCellPosition()
    self:_UpdateContentSize()
    for i, v in ipairs(self.cellsInUse) do
        local x, y = self:_GetCellAnchoredPosition(v)
        v:SetAnchoredPosition(x, y)
    end
end

-- 将元素压入到缓存池（这些元素不显示，用来复用）
function TableView:_StoreReuseObject(cell, hideCell)
    -- 隐藏cell
    if hideCell == true or hideCell == nil then
        if self.onFreeCell then
            self.onFreeCell(cell)
        else
            cell:Hide()
        end
    end

    -- 添加元素到缓存池中
    local poolName = cell.pool or DEFAULT_POOL
    local pool = self.poolList[poolName]
    if pool == nil then
        pool = { name = poolName, stack = {} }
        self.poolList[poolName] = pool
    end

    table.insert(pool.stack, cell)
end

-- 获取某个索引的cell
function TableView:CellAtIndex(index)
    for c, v in ipairs(self.cellsInUse) do
        if v.index == index then
            return v
        end
    end

    return nil
end

-- 获取所有在使用的cell
function TableView:GetInUseCells()
    local res = {}
    for _, cell in ipairs(self.cellsInUse) do
        table.insert(res, cell)
    end
    return res
end

-- 在指定索引创建一个cell
function TableView:_CreateCell(index)
    if not self.onCreateItem then
        error('没有实现 OnCreateItem')
        return nil
    end

    local cell

    -- 创建新的控件（外部创建的时候会复用已有控件）
    if self.prefab ~= nil then
        -- 如果有指定prefab，则外部只需要负责设置控件
        -- 获取新元素，先从缓存池中取，如果没有的话，就创建
        local isNewCell
        cell, isNewCell = self:PopObject(DEFAULT_POOL, self.prefab, index)
        -- 通知外部逻辑更新控件内容
        self.onCreateItem(self._delegate, index, cell, isNewCell)
    else
        -- 没有指定prefab，则外部负责创建元素，可以支持多种不同prefab的情况
        cell = self.onCreateItem(self._delegate, index, nil, false)
    end

    if cell then
        cell.index = index
    end

    return cell
end

-- 更新并记录每个元素的坐标
function TableView:_UpdateCellPosition()
    -- 清理不需要的索引
    for i = self.maxCount + 1, #self.cellsOffsets do
        self.cellsOffsets[i] = nil
    end

    local index = 1
    local currentOffset = self.horizontal and self.origin.x or self.origin.y
    self.cellsOffsets[index] = currentOffset

    -- 注意:额外的一个元素，以便获取整个滑动区域的大小
    for i = 1, self.maxCount do
        local cellSize = self:GetCellSize(i)

        -- 一行中的多个元素，偏移值是一样的
        local oneZero = ((i % self.maxCountPerLine == 0) or i == self.maxCount) and 1 or 0
        if self.horizontal then
            currentOffset = currentOffset + (cellSize.x + self.space) * oneZero
        else
            currentOffset = currentOffset + (cellSize.y + self.space) * oneZero
        end

        index = index + 1
        self.cellsOffsets[index] = currentOffset
    end
end

-- 更新整个滑动区域的大小
function TableView:_UpdateContentSize()
    if self.maxCount > 0 then
        local maxPosition = self.cellsOffsets[#self.cellsOffsets] + self.contentSizeExpand
        local currSize = self.content:GetSize()
        if self.horizontal then
            self.content:SetSize(maxPosition, currSize.y)
        else
            self.content:SetSize(currSize.x, maxPosition)
        end
    end
end

function TableView:_OffsetFromIndex(index)
    local offsetX, offsetY = self.origin.x, self.origin.y
    if not self.cellsOffsets[index] then
        return offsetX, offsetY
    end

    local cellSize = self:GetCellSize(index)
    if self.horizontal then
        offsetX = offsetX + self.cellsOffsets[index]
        offsetY = offsetY - ((index - 1) % self.maxCountPerLine) * (cellSize.y + self.spaceY)
    else
        offsetX = offsetX + ((index - 1) % self.maxCountPerLine) * (cellSize.x + self.spaceX)
        offsetY = offsetY - self.cellsOffsets[index]
    end
    return offsetX, offsetY
end

-- 算出这是对应哪个显示区域
function TableView:_IndexFromOffset(offsetX, offsetY, searchStart)
    local maxVal = self.cellsOffsets[#self.cellsOffsets]
    local search = -1

    if self.horizontal then
        if offsetX >= maxVal then
            return self.maxCount
        elseif offsetX < 0 then
            return 1
        end
        search = offsetX
    else
        if offsetY >= maxVal then
            return self.maxCount
        elseif offsetY < 0 then
            return 1
        end
        search = offsetY
    end

    local index = 1
    local low = 1
    local high = #self.cellsOffsets

    -- 折半查找法
    while high >= low do
        index = math.floor(low + (high - low) / 2)
        local cellStart = self.cellsOffsets[index]
        local cellEnd = self.cellsOffsets[index + 1] or maxVal
        if search >= cellStart and search <= cellEnd then
            -- 找到了
            break
        elseif search < cellStart then
            high = index - 1
        else
            low = index + 1
        end
    end

    if low > high then
        index = 1
    end

    index = math.max(1, math.min(index, self.maxCount))
    -- 计算当前是第几行(列)
    local firstD = math.ceil(index / self.maxCountPerLine)
    -- searchStart表示要找是开头还是结尾元素
    if searchStart then
        -- 获取当前行第一个元素
        return (firstD - 1) * self.maxCountPerLine + 1
    else
        -- 获取当前行最后一个元素,最后一个元素不能大于maxCount
        return math.min(firstD * self.maxCountPerLine, self.maxCount)
    end
end

function TableView:_MoveCellOutOfSight(cell)
    self:_StoreReuseObject(cell)

    local index = cell.index
    for i, v in ipairs(self.cellsInUse) do
        if i == index then
            table.remove(self.cellsInUse, i)
            self.isUsedCellsDirty = true
            break
        end
    end
end

function TableView:_UseCell(cell)
    if not cell then return end

    if not cell.hasSetParent then
        cell:SetParent(self.content)
    end

    local x, y = self:_GetCellAnchoredPosition(cell)
    cell:SetAnchoredPosition(x, y)

    table.insert(self.cellsInUse, cell)
    self.isUsedCellsDirty = true
end

function TableView:GetStartEndIndex()
    local offsetX, offsetY = GetAnchoredPosition(self.content)

    -- 向左x是负的，向上y是正的
    offsetX = -offsetX
    local startIndex = self:_IndexFromOffset(offsetX, offsetY, true)

    --    用sizeDelta的话受限于scroll的锚点选择，如果锚点不是一个点（anchorMin和anchorMax不是一个值），sizeDelta会变为差值
    --    举例：scroll的锚点选择的是(0, 0)(1, 1)，即宽高都基于父组件，如果和父组件一样大，并且重合放置，则sizeDelta是(0, 0)
    --    用viewport.rect得到的就是纯2D的宽高了，和锚点无关
    --    by bengda
    -- 竟然可能是负数
    --offset.x = self.scroll.transform.sizeDelta.x + offset.x
    --offset.y = offset.y + self.scroll.transform.sizeDelta.y
    local width, height = GetSize(self.scroll.viewport)
    offsetX = offsetX + width
    offsetY = offsetY + height

    return startIndex, self:_IndexFromOffset(offsetX, offsetY, false)
end

-- 当scrollrect滑动后调用 更新tableview
function TableView:_OnValueChanged(vec2)
    if self.maxCount == 0 then return end
    -- 获取显示区间
    local startIndex, endIndex = self:GetStartEndIndex()

    table.clear(self.cellsInUseTemp)
    table.clear(self.cellsInUseIndex)

    -- 先查看哪些cell还在范围内
    for c, v in ipairs(self.cellsInUse) do
        if v.index < startIndex or v.index > endIndex then
            -- 超出显示区域，回收控件
            self:_StoreReuseObject(v)
            self.isUsedCellsDirty = true
        else
            -- 标记在范围内正在在使用的cell，这些cell不需要刷新，也不会改变坐标
            self.cellsInUseIndex[v.index] = true
            table.insert(self.cellsInUseTemp, v)
        end
    end

    -- 交换两个表
    local temp = self.cellsInUse
    self.cellsInUse = self.cellsInUseTemp
    self.cellsInUseTemp = temp

    for i = startIndex, endIndex do
        if not self.cellsInUseIndex[i] and i > 0 and i <= self.maxCount then
            -- 创建新的cell（会进行资源复用）
            self:_UseCell(self:_CreateCell(i))
            self.cellsInUseIndex[i] = true
        end
    end

    if self.onValueChangedFunc then
        self.onValueChangedFunc(self._delegate, vec2, self.horizontal
                                                        and self.scroll.horizontalNormalizedPosition
                                                        or self.scroll.verticalNormalizedPosition)
    end
end

function TableView:_GetCellPivotOffset(rectTrans)
    local pivotOffsetX, pivotOffsetY = 0, 0
    if self.horizontal then
        pivotOffsetX = GetPivotX(rectTrans) * GetSizeX(rectTrans)
    else
        -- 纵向移动的时候，offset取的是上边沿，所以算的是pivot向上的偏移量，下方向为负
        pivotOffsetY = -1 * (1 - GetPivotY(rectTrans)) *  GetSizeY(rectTrans)
    end

    return pivotOffsetX, pivotOffsetY
end

function TableView:_GetCellAnchoredPosition(cell)
    local offsetX, offsetY = self:_OffsetFromIndex(cell.index)
    local pivotOffsetX, pivotOffsetY = self:_GetCellPivotOffset(cell.transform)
    return offsetX + pivotOffsetX, offsetY + pivotOffsetY
end

function TableView:GetCellAnchoredPosition(cell)
    return self:_GetCellAnchoredPosition(cell)
end

-- 动画
function TableView:CellAnimation()
    local duration = 0.3

    local top_index = self.maxCount
    for k, v in ipairs(self.cellsInUse) do
        if v.index < top_index then
            top_index = v.index
        end
    end

    for k, v in ipairs(self.cellsInUse) do
        local position = v.transform.position
        local x, y = self:_OffsetFromIndex(top_index)
        v:SetAnchoredPosition(x, y)
        v.transform:DOMove(position, duration)
    end
end

-- 设置TableView扩展区域大小，刷新的时候才会应用(设置MaxCount，增减，刷新个体大小这类操作)
function TableView:SetContentSizeExpand(expandLength)
    self.contentSizeExpand = expandLength
end

-- 禁止滑动
function TableView:ForbidScroll()
    if self.isForbidScroll then return end
    self.isForbidScroll = true

    self.scroll.horizontal = false
    self.scroll.vertical   = false
    self.scroll:StopMovement()
end

--重启可以滑动
function TableView:RestartScroll()
    self.isForbidScroll = false
    if self.horizontal then
        self.scroll.horizontal = true
    else
        self.scroll.vertical = false
    end
end

-- 判断cell是否正在使用
function TableView:CellIsInUse(index)
    return self.cellsInUseIndex[index]
end

-- 设置是否横向滑动
function TableView:SetHorizontal(isHorizontal)
    self.horizontal = isHorizontal
    self:UpdateOrgin()
end

function TableView:UpdateOrgin()
    if self.prefab then
        SetActive(self.prefab, false)
        local prefabRectTrans = self.prefab.transform
        local pivotOffsetX, pivotOffsetY = self:_GetCellPivotOffset(prefabRectTrans)
        local pos = prefabRectTrans.anchoredPosition
        self.origin = Vector2(pos.x - pivotOffsetX, pos.y - pivotOffsetY)
    else
        self.origin = Vector2(0, 0)  -- 起始元素坐标
    end
end