[Back](index.md)

# Lua coroutine 实现延时

``` lua
--------------------------------------------------------------------------------
--      Copyright (c) 2015 - 2016 , 蒙占志(topameng) topameng@gmail.com
--      All rights reserved.
--      Use, modification and distribution are subject to the "MIT License"
--------------------------------------------------------------------------------

local create = coroutine.create
local running = coroutine.running
local resume = coroutine.resume
local yield = coroutine.yield
local error = error
local unpack = unpack
local debug = debug
local comap = {}
local util = require 'Utils.xlua.util'

setmetatable(comap, {__mode = "kv"})

-- 在Unity运行时，创建一个Coroutine_Runner GameObject
local gameobject = CS.UnityEngine.GameObject('Coroutine_Runner')
-- 设置成NontDestroyOnLoad，在Unity运行后会创建一个临时DontDestroyOnLoad Scene
CS.UnityEngine.Object.DontDestroyOnLoad(gameobject)
-- Coroutine_Runner gameObject上挂载Coroutine_Runner C#脚本
local cs_coroutine_runner = gameobject:AddComponent(typeof(CS.Coroutine_Runner))

local function async_yield_return(to_yield, cb)
    -- 调用C#的方法，用StartCoroutine实现
    -- 这个调用基于XLua，在函数名前用[LuaCallCSharp]标识
    cs_coroutine_runner:YieldAndCallback(to_yield, cb)
end

local yield_return = util.async_to_sync(async_yield_return)
local WaitForSeconds = CS.UnityEngine.WaitForSeconds
local WaitForEndOfFrame = CS.UnityEngine.WaitForEndOfFrame

function coroutine.start(f, ...)
	local co = create(f)
	local flag, msg = resume(co, ...)
	if not flag then
		msg = debug.traceback(co, msg)
		error(msg)
	end

	return co
end

function coroutine.wait(t)
	yield_return(WaitForSeconds(t))
end

function DestroyCoroutine()
	Destroy(gameobject)
end

function coroutine.delay(f, ...)
    local co = coroutine.start(function(...) yield_return(WaitForEndOfFrame()) f(...) end)
end

```


``` csharp
using UnityEngine;
using XLua;
using System.Collections.Generic;
using System.Collections;
using System;

[LuaCallCSharp]
public class Coroutine_Runner : MonoBehaviour
{
    public void YieldAndCallback(object to_yield, Action callback)
    {
        StartCoroutine(CoBody(to_yield, callback));
    }

    private IEnumerator CoBody(object to_yield, Action callback)
    {
        if (to_yield is IEnumerator)
            yield return StartCoroutine((IEnumerator)to_yield);
        else
            yield return to_yield;
        callback();
    }
}

public static class CoroutineConfig
{
    [LuaCallCSharp]
    public static List<Type> LuaCallCSharp
    {
        get
        {
            return new List<Type>()
            {
                typeof(WaitForSeconds),
                typeof(WWW)
            };
        }
    }
}

```