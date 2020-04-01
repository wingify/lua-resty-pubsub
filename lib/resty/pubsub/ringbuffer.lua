-- This module has references from "lua-resty-kafka, version 0.0.8", Copyright (C) 2014-2020, Dejiang Zhu, under the BSD license.
-- Source - https://github.com/doujiang24/lua-resty-kafka

--[[
	Copyright (c) 2014, doujiang
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this
    list of conditions and the following disclaimer.

    * Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

    * Neither the name of lua-resty-kafka nor the names of its
    contributors may be used to endorse or promote products derived from
    this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
    FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
    SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]


local setmetatable = setmetatable
local ngx_null = ngx.null

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local _M = {}
local mt = { __index = _M }

function _M.new(self, batch_num, max_buffering)
    local sendbuffer = {
        queue = new_tab(max_buffering, 0),
        batch_num = batch_num,
        size = max_buffering,
        start = 1,
        num = 0,
    }
    return setmetatable(sendbuffer, mt)
end


function _M.add(self, message)
    local num = self.num
    local size = self.size

    if num >= size then
        return nil, "buffer overflow"
    end

    local index = (self.start + num) % size
    local queue = self.queue

    queue[index] = message

    self.num = num + 1

    return true
end


function _M.pop(self)
    local num = self.num
    if num <= 0 then
        return nil, "empty buffer"
    end

    self.num = num - 1

    local start = self.start
    local queue = self.queue

    self.start = (start + 1) % self.size

    local message = queue[start]

    queue[start] = ngx_null

    return message
end


function _M.left_num(self)
    return self.num
end


function _M.need_send(self)
    return self.num >= self.batch_num
end


return _M
