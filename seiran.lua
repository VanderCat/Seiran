local curl

local seiran = {}

seiran.VERSION = "2.0.2"

seiran.json = {}
seiran.apiVersion = "5.131"
seiran.__boundary = "X-SEIRAN-BOUNDARY"

function seiran:new(token) -- BREAKING CHANGE
    local _seiran = {}
    setmetatable(_seiran, self)
    self.__index = self
    _seiran.accessToken = token

    _seiran.__metatables = {
        endpoint = {},
        group = {}
    }
    
    _seiran.__metatables.endpoint.__metatable = "endpoint"
    
    _seiran.__metatables.group.__metatable = "group"
    
    function _seiran.__metatables.group:__index(key)
        local table = {group = key}
        setmetatable(table, _seiran.__metatables.endpoint)
        return table
    end
    
    _seiran.api = {}
    setmetatable(_seiran.api, _seiran.__metatables.group)
    function _seiran.__metatables.endpoint:__index(key)
        local group = self.group
        local point = key
        return function(args)
            local response = _seiran:getResponse(group..'.'..point, args)
            if response.error then
                local err = response.error
                local string = string.format("Server responded with error %i:\n\t%s\n", err.error_code, err.error_msg)
                for _, v in ipairs(err.request_params) do
                    string = string.."\t\t"..v.key.."="..v.value.."\n"
                end
                error(string)
            end
            return response.response
        end
    end
    return _seiran
end

function seiran:setJsonHandler(encode, decode)
    self.json.decode = decode
    self.json.encode = encode
end

--- cJSON Initialization
local cjson = cjson

if cjson == nil then
    local success, err = pcall(require, "cjson")
    if success then
        seiran:setJsonHandler(err.encode, err.decode)
    else
        (warn or print)(err or "Error loading cjson")
    end
end

function seiran:reader(handle)
    local reader = {}
    reader.handle = handle or io.tmpfile()
    function reader:close()
        self.handle:close()
    end
    function reader:write(ctx)
        self.handle:write(ctx)
    end
    function reader:get()
        local pos = self.handle:seek()
        self.handle:seek("set")
        local result = self.handle:read("*a")
        self.handle:seek("set", pos)
        return result
    end
    return reader
end

function seiran:encodeHeaders(data)
    local str = {}
    for k, v in pairs(data) do
        str[#str+1]=k..": "..v
    end
    return str
end

function seiran:formData(name, data)
    return string.format("--%s\r\n"..
    'Content-Disposition: form-data; name="%s"\r\n'..
    "\r\n"..
    "%s\r\n", self.__boundary, name, data)
end

function seiran:formFile(name, data, contentType, filename)
    contentType = contentType or "application/octet-stream"
    filename = filename or "data.bin"
    return string.format("--%s\r\n"..
    'Content-Disposition: form-data; name="%s"; filename="%s"\r\n'..
    "Content-Type: %s\r\n"..
    "\r\n"..
    "%s\r\n", self.__boundary, name, filename, contentType, data)
end

function seiran:post(url, data, headers)
    curl = curl or require "lcurl" -- lcurl is a soft dependency now
    local reader = self:reader()
    local form = ""
    curl.easy()
        :setopt_url(url)
        :setopt_writefunction(function (ctx)
            reader:write(ctx)
        end)
        :setopt_httpheader(self:encodeHeaders(headers))
        :setopt_postfields(data or "")
        :perform()
    :close()
    return reader
end

function seiran:getResponse(name, args)
    args = args or {}
    args.v = args.v or self.apiVersion
    args.access_token = args.access_token or self.accessToken
    
    local form = ""
    for name, value in pairs(args) do
        local val
        if type(value)=="table" then
            val = self.json.encode(value)
        end
        form=form..self:formData(name, val or value)
    end
    form=form.."--"..self.__boundary.."--\r\n"
    local response = self:post('https://api.vk.com/method/'..name, form, {
        ["Content-Type"]="multipart/form-data; boundary="..self.__boundary
    })
    local decoded = ""
    local success, error = pcall(function()
        decoded = self.json.decode(response:get())
    end)
    response:close()
    if not success then
        if warn then warn(error) else print(error) end
    end
    return decoded
end

function seiran:longPollStart(arg)
    self.longPollSettings = self.api[(arg.group_id and "groups" or "messages")].getLongPollServer(arg)
    self.longPollSettings.ts = math.tointeger(self.longPollSettings.ts)
end

function seiran:longPollListen(arg)
    local argString = ""
    arg = arg or {}
    arg.act = arg.act or "a_check"
    arg.key = arg.key or self.longPollSettings.key
    arg.ts = arg.ts or self.longPollSettings.ts
    arg.wait = arg.wait or 25
    arg.mode = arg.mode or 2
    arg.version = arg.version or 3
    arg.access_token = arg.access_token or self.accessToken
    for name, value in pairs(arg) do
        argString=argString..name.."="..value..'&'
    end
    --argString=urlencode.encode_url(argString)
    local response = ""
    curl.easy{
        url = (string.sub(self.longPollSettings.server, 1, 4)=="http" and "" or 'https://')..self.longPollSettings.server..'?'..argString,
        writefunction = function(a) response = response..a end -- use io.stderr:write()
      }
      :perform()
    :close()
    response = self.json.decode(response)
    self.longPollSettings.ts = response.ts
    return response.updates
end

return seiran