[Back](index.md)

# Lua 计时器

支持多开计时器，关闭界面时统一清理。

``` lua
function Window:StartTimer(func, time)
    if self.timerList == nil then
        self.timerList = {}
    end

    local timer = CallbackTimer.New(handler(self, func), time, -1)
    table.insert(self.timerList, timer)
    timer:Start()
    return timer
end

-- 清理所有的计时器
function Window:ClearTimer()
    if self.timerList == nil then return end
    for i,v in ipairs(self.timerList) do
        if v and v.running then
            v:Stop()
        end
    end
    self.timerList = nil
end

```

新增一个timer对象插入self.timerList用来管理所有的timer