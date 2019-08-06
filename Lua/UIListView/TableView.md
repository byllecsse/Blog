[Back](../index.md)

# TableView 可复用控件的ListView
仿iOS的UITableView 功能：
1、动态增加、删除或插入元素
2、根据可显示区域创建并复用控件，适用于列表元素数目非常大的情况
3、列表元素高度可不同，prefab也可不同

tableView内用table实现了一个缓存池，在有scroll滑动，需要更新控件显示时，进行压栈弹出处理，并更新控件位置显示。
由于页面存在数据index和控件index，控件index是控制页面可见元素的排列显示，数据index则是外部进行数据刷新。

## PopObject() 弹出元素
``` lua

```

[代码](TableView.lua)