[Back](../index.md)

# ListView 固定列表
挂载在ScrollView上的ListView.lua代码。
它创建即完成所有的item创建，没有缓存池和动态item位置更新，所以仅适用于少量的列表展示，10行以下是最好的，item prefab设置为左上角对齐，起始点由Prefab在content中的位置决定。

self:_GetFunction('OnCreateItem')
获取外部创建ListView控件的panel代码内的OnCreateItem方法刷新Item数据显示。

## 入口函数SetMaxCount
刷新ListView创建item的数量，仅创建gameObject和进行位置调整。

``` lua
function ListView:SetMaxCount(count, refresh, scrollToTop)
    -- 缓存count
    -- 是否刷新
        -- 刷新元素 ReloadData()
        -- 是否移到顶部
            -- 移到顶部
end

function ListView:ReloadData()
    -- 清理旧控件 Destroy
    -- 创建prefab，调用onCreateItem
    -- 将创建好的prefab gameObject插入self.itemList数组
    -- 清理多余的itemList gameObejct
    -- 记录itemList初始位置
    -- 更新Item位置
end
```

## 创建ListView

``` lua
-- 创建listview组件
function Window:CreateListView(name, prefabName, typeName)
    local scroll = self:GetChild(name, typeName or 'ScrollRect')
    local prefab

    if prefabName then
        prefab = FindChild(scroll, prefabName, nil, true)
    end

    -- window是页面继承基类，这里的self，实际是当前panel页面
    -- self传递了panel代码内的所有变量，包括值和方法
    return ListView.new(scroll, prefab, self, name)
end
```

## UpdateItemPos()

``` lua
function ListView:UpdateItemPos()
    -- 遍历itemList
        -- 获取item transform & transform.sizeDelta
        -- 判断水平/垂直
            -- x, y是循环外变量，每次循环加上itemSize.x/y+space会成为下一个Item的位置
            -- 如果是水平/垂直，设置x/y=startY/startX
        
        -- 减去结尾间距space
    -- 重设content sizeDelta
end

```

## ScrollTo(index)

``` lua 
function ListView:ScrollTo(index)
    -- index越界判断
    -- 确定行数，向上取整
    -- 防止除0错误
    -- scroll计算滑动百分比
end
```

[代码](ListView.lua)