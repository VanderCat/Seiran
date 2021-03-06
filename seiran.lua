local curl = require "lcurl"

local seiran = {}
seiran.json = {}
seiran.apiVersion = "5.131"
local cjson = cjson
if cjson == nil then
    local success, err = pcall(require, "cjson")
    if success then
        function seiran.json.decode(str)
            return err.decode(str)
        end
        function seiran.json.encode(obj)
            return err.encode(obj)
        end
    else
        (warn or print)(err or "Error loading cjson")
    end
end

function seiran:setJsonHandler(encode, decode)
    self.json.decode = decode
    self.json.encode = decode
end

function seiran:getResponse(name, args)
    local response = ""
    local form = curl.form()
    args = args or {}
    args.v = args.v or self.apiVersion
    args.access_token = args.access_token or self.accessToken
    for name, value in pairs(args) do
        form:add_content(name, value)
    end
    --argString=urlencode.encode_url(argString)
    curl.easy()
        :setopt_url('https://api.vk.com/method/'..name)
        :setopt_writefunction(function(a)response = response..a end)
        :setopt_httppost(form)
        :perform()
    :close()
    local success, error = pcall(function()
        response = self.json.decode(response)
    end)
    if not success then
        if warn then warn(error) else print(error) end
    end
    return response
end

function seiran:longPollStart(arg)
    self.longPollSettings = self.api[(arg.group_id and "groups" or "messages")].getLongPollServer(arg).response
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

seiran.__metatables = {
    endpoint = {},
    group = {}
}

seiran.__metatables.endpoint.__metatable = "endpoint"

function seiran.__metatables.endpoint:__index(key)
    local group = self.group
    local point = key
    return function(args)
        return seiran:getResponse(group..'.'..point, args)
    end
end

seiran.__metatables.group.__metatable = "group"

function seiran.__metatables.group:__index(key)
    local table = {group = key}
    setmetatable(table, seiran.__metatables.endpoint)
    return table
end

seiran.api = {}
setmetatable(seiran.api, seiran.__metatables.group)

return seiran