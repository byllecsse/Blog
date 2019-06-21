[Back](../../index.md)

# Lua UI ListView

[ListView](Lua/UIListView/ListView.md)
全刷列表，没有控件重用，不设缓存池，刷新及全刷新列表，适用于数据较少的列表显示。

[TableView](Lua/UIListView/TableView.md)
只刷新可见区域，增加控件重用，需要注意新创建列表项和重用列表项的刷新，适用于数据较多的列表显示，会相对省去一些创建销毁的内存开销。

[ExpandListView](Lua/UIListView/ExpandListView.md)
![ExpandListView图片](Lua/UIListView/Image/expand_list_view_img.png)
可展开列表，用于存在第二级分页标题的情况，他对界面的耦合性较强，不是很通用。