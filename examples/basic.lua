local vk = require "seiran"
local i = require "inspect"
if warn then warn("@on") end

local at = io.open("accesstoken.vk", "r")
vk.accessToken = at:read()
at:close()

local user = vk.api.users.get{
    user_ids=arg[1] or "vander_cat"
}.response[1]
print(user.first_name.." "..user.last_name)