[Back](../index.md)

# Lua ExpandListView 可展开列表

该列表代码内仅做列表项的位置计算，不关心数据刷新，数据刷新用委托，由原控件页面，比如这个ExpandListView是RakGroupPanel的控件，数据刷新还是在RankGroupPanel内处理。

OnCreateGroup   通知外部标题组创建，刷新标题；
OnCreateItem    通知外部次级标题创建，刷新次级标题；
SetMaxCount     设置列表的控件数量，它的参数是个数组。

## SetMaxCount(maxCount)
比如图中的个人信息，传递的参数就是
maxCount = {
    [1] = 3,
}
如果对应for i, v in pairs(maxCount) do 那么i是‘个人信息’大分类，v是‘综合战力’‘等级’‘任务战力’小标题。

``` lua
-- 设置最大数目 传递的是一个数组，里面是每个组的最大数目，如 {5,4,5,6}
function ExpandListView:SetMaxCount(maxCount)
    -- 清理旧gameObject
    -- 清理旧界面排版数据

    -- 缓存maxCount
    
    -- 遍历maxCount
        -- _CreateGroup 创建组gameObject，交给外部刷新数据
        -- _ReloadGroup 创建组内gameObject，交给外部刷新数据

        -- 计算组archorPosition

    -- 设置scrollView content的sizeDelta高度
    -- _ReLayout 重新排版
end
```

## _CreateGroup(index, y)
创建组对象，包括按钮和下拉列表容器。
获取RankGroupPanel内的OnCreateGroup方法，Lua中文件内的所有变量、数组、方法，都是基础类型，八大基础类型分别是：nil, boolean, number, string, userdata, function, thread and table.

``` lua
function ExpandListView:_CreateGroup(index, y)
    -- 获取外部OnCreateGroup方法委托

    -- 创建Instantiate groupPrefab
    -- 调用OnCreateGroup

    -- 设置新创建的group gameObject父节点和位置，并保存在self.groupList[].group
    -- 添加toggle/button点击的监听

    -- 创建Instantiate panelPrefab
    -- 设置新创建的panel gameObject父节点和位置，并保存在self.groupList[].panel
end
```

## _ReloadGroup(groupIndex)
创建组内对象，这次的组内全是button/toggle，具体由外部决定。
和_CreateGroup()类似，组内按钮的显示内容由外部OnCreateItem负责，此处只处理位置排列。

``` lua
function ExpandListView:_ReloadGroup(groupIndex)
    -- 清理self.groupList[groupIndex]数据

    -- 遍历group下次级列表
        -- 当i>1时，排列位置加上按钮间距

        -- 调用OnCreateItem
        -- 创建itemPrefab，并设置父节点和位置

    -- 刷新group.panel的宽高
end
```

## _ReLayout()
``` lua
function ExpandListView:_ReLayout()
    -- 遍历groupList
        -- if 是第一个组
            -- group y 从topSpace开始排列
        
        --排列group item

        -- if 展开
            -- 加上展开列表panel的高度偏移
        -- else
            -- 不偏移
end
```

## SelectItem(groupIndex, itemIndex)
优先查找外部有没有提供OnSelectItem，这是ExpandListView提供了一个接口，让外部可以自定义一些特殊逻辑操作，在控件内部，则处理是是否允许多开的情况。

_其他的一些方法，设置容器实际控件大小，滑动区域，刷新列表，滚动到某个位置，直接看代码_

[代码在此](ExpandListView.lua)