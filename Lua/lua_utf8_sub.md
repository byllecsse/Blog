[Back](../index.md)

# Lua中文字符串截取

lua的utf8中文字长度为3，在工作中遇到一个截取玩家名，截取前4位导致结果只有一个中文字加上一个乱码字符的问题。
正确截取包含非英文字符串的正确解法是要计算每个字符的实际占字符数，再以此进行截断处理。


``` lua
--截取中英混合的UTF8字符串，endIndex可缺省
function SubStringUTF8(str, startIndex, endIndex)
    if startIndex < 0 then  -- 若是负数，要计算从结尾开始的字符位置
        startIndex = SubStringGetTotalIndex(str) + startIndex + 1;
    end

    if endIndex ~= nil and endIndex < 0 then
        endIndex = SubStringGetTotalIndex(str) + endIndex + 1;
    end

    if endIndex == nil then 
        return string.sub(str, SubStringGetTrueIndex(str, startIndex));
    else
        return string.sub(str, SubStringGetTrueIndex(str, startIndex), SubStringGetTrueIndex(str, endIndex + 1) - 1);
    end
end

--获取中英混合UTF8字符串的真实字符数量
function SubStringGetTotalIndex(str)
    local curIndex = 0;
    local i = 1;
    local lastCount = 1;
    repeat 
        lastCount = SubStringGetByteCount(str, i)
        i = i + lastCount;
        curIndex = curIndex + 1;
    until(lastCount == 0); -- 到了字符串末尾，字符为nil，结束
    return curIndex - 1; -- -1是为了去掉最后一次做判断的nil索引
end

function SubStringGetTrueIndex(str, index)
    local curIndex = 0;
    local i = 1;
    local lastCount = 1;
    repeat 
        lastCount = SubStringGetByteCount(str, i)
        i = i + lastCount;
        curIndex = curIndex + 1;
    until(curIndex >= index); -- 这里我感觉可以用while
    return i - lastCount; 

    --[[
        while curIndex < index
            lastCount = SubStringGetByteCount(str, i)
            i = i + lastCount
            curIndex = curIndex + 1
        end
        return lastCount
    ]]--
end

--返回当前字符实际占用的字符数
function SubStringGetByteCount(str, index)
    local curByte = string.byte(str, index) -- byte 转换字符为整数值
    local byteCount = 1;

    -- 由此方式可以知道每个字符占多数位
    if curByte == nil then
        byteCount = 0
    elseif curByte > 0 and curByte <= 127 then
        byteCount = 1
    elseif curByte>=192 and curByte<=223 then
        byteCount = 2
    elseif curByte>=224 and curByte<=239 then
        byteCount = 3
    elseif curByte>=240 and curByte<=247 then
        byteCount = 4
    end
    return byteCount;

```

大致思路是：
1. 用string.byte(arg[,int])计算每个字符的实际占字符数；
2. 加起来得到整个字符串实际的字符长度；
3. 计算startIndex, endIndex实际在字符串中的索引位置；
4. 用string.sub(s,i,j))截取。



#### 还有一种实现方式

UTF8的编码规则：
1. 字符的第一个字节范围： 0x00—0x7F(0-127),或者 0xC2—0xF4(194-244); UTF8 是兼容 ascii 的，所以 0~127 就和 ascii 完全一致  
2. 0xC0, 0xC1,0xF5—0xFF(192, 193 和 245-255)不会出现在UTF8编码中   
3. 0x80—0xBF(128-191)只会出现在第二个及随后的编码中(针对多字节编码，如汉字)   

``` lua
-- 将每个字符分离出来，放到table中，一个单元内一个字符
function StringToTable(s)
    local tb = {}
    for utfChar in string.gmatch(s, "%z\1-\127\194-\244][\128-\191]*") do
        table.insert(tb.utfChar)
    end
    return tb
end

-- 获取字符串长度，设一个中文长度为2，其他长度为1（这个做法比上面的看起来要随意）
function GetUTFLen(s)
    local sTable = StringToTable(s)
    local len = 0
    local charLen = 0

    for i=1, #sTable do
        local utfCharLen = string.len(sTable[i]) -- 计算字符串长度
        if utfCharLen > 1 then -- 中文
            charLen = 2
        else
            charLen = 1
        end
    end
    return len
end

-- 获取指定字符个数的字符串的实际长度，设一个中文长度为2，其他长度为1，count:-1表示不限制
function GetUTFLenWithCount(s, count)
    local sTable = StringToTable(s)
    local len = 0
    local charLen = 0
    local isLimited = (count >= 0)

    for i=1, #sTable do
        local utfCharLen = string.len(sTable[i])
        if utfCharLen > 1 then
            charLen = 2
        else
            charLen = 1
        end

        len = len + utfCharLen

        if isLimited then -- 若是从正向索引开始
            count = count - charLen -- 传入索引减去字符串最后一位的实际字符数
            if count <= 0 then
                break
            end
        end
    end
    return len
end

-- 截取指定字符个数的字符串，超过指定个数的，截取，然后添加...
function GetMaxLenString(s, maxLen)
    local len = GetUTFLen(s)
    local dstString = s

    if len > maxLen then
        dstString = string.sub(s, 1, GetUTFLenWithCount(s, maxLen))
        dstString = dstString .. "..."
    end

    return dstString
end
```


两种做法大同小异，都是计算出单个字符的实际占字符数，只是第一种方法用的string.byte()判断属于哪种字符，第二种则用的string.len()直接得到字符长度。