<h1 align="center">Seiran<a href="https://en.touhouwiki.net/wiki/Seiran">*</a></h1>
<p align="center">Lightweight VK API library for Lua 5.4 named after Touhou character.</p>

**NOTICE:** This library only tested on linux! 
## Table of Content
- [Table of Content](#table-of-content)
- [Usage](#usage)
- [Features](#features)
- [Requirements](#requirements)
- [TODO:](#todo)
- [API](#api)
  - [`seiran.api.<GROUP>.<METHOD>{..}`](#seiranapigroupmethod)
    - [Descirpton:](#descirpton)
    - [Usage:](#usage-1)
  - [`seiran:setJsonHandler(encode, decode)`](#seiransetjsonhandlerencode-decode)
    - [Descirpton:](#descirpton-1)
    - [Usage:](#usage-2)
  - [`seiran:longPollStart{...}`](#seiranlongpollstart)
    - [See:](#see)
    - [Usage:](#usage-3)
  - [`seiran:longPollListen{}`](#seiranlongpolllisten)
    - [See:](#see-1)
    - [Usage:](#usage-4)

## Usage
```lua
local VK = require "seiran"

-- if using a file:
local at = io.open("accesstoken.vk", "r")
local vk1 = VK:new(at:read())
at:close()

-- Non-Secure way:
local vk2 = VK:new("VK.a.b19c3403c42a6d0d85d86efa1784be286ff6e6fc94c18e82c421b906cc33aeea")

local user = vk.api.users.get{
    user_ids="vander_cat"
}[1]
print(user.first_name.." "..user.last_name)
```
You can also execute the example:
```sh
$ lua examples/basic.lua vander_cat
```
You will need to create an `accesstoken.vk` file contains your token though

## Features
- Longpoll
- No special API code
    - there's actually no method like users.get, so if vk will rename something, you will only need to rename same in code
- lightweight
    - this library is only about 110 lines
- You only use a token to do everything (_not like in some python vk api libraries_)

## Requirements
```
Lua-cURLv3*
```
* You now can (!!!) write a new post function and dont use a Lua-cURLv3! just remake `seiran:post(url, data, headers)`!

Optional:
```
Lua-cJSON
```
If you're not using cJSON, then you must setup json handlers:
```lua
local vk = require "seiran"
local json = require "json"

seiran:setJsonHandler(json.encode, json.decode)
```

## TODO:
- Add callback support
- Login with credentials
- Cleanup a code (?)
- Test on other platforms

## API
### `seiran.api.<GROUP>.<METHOD>{..}`
- **Returns** decoded json response from server
#### Descirpton:
this is how you access the api
#### Usage:
```lua
local user = seiran.api.users.get{
    user_ids="vander_cat"
}.response[1]

print(user.first_name.." "..user.last_name)
```

### `seiran:setJsonHandler(encode, decode)`
- function **`encode`** - Function used for encoding to json
- function **`decode`** - Function used for decoding from json
#### Descirpton:
Use this function if you don't have `cJSON` installed or do not want to use it
#### Usage:
```lua
local json = require "json"

seiran:setJsonHandler(json.encode, json.decode)
```

### `seiran:longPollStart{...}`
#### See: 
https://dev.vk.com/method/messages.getLongPollServer
#### Usage:
```lua
seiran:longPollStart{
    need_pts = 1, --default
    grou_id = 12345 -- Only for group's token
    lp_version=3 --default
}
```

### `seiran:longPollListen{}`
#### See: 
https://dev.vk.com/api/user-long-poll/getting-started#%D0%9F%D0%BE%D0%B4%D0%BA%D0%BB%D1%8E%D1%87%D0%B5%D0%BD%D0%B8%D0%B5
#### Usage:
```lua
seiran:longPollStart()

while true do
    for i, v in ipairs(seiran:longPollListen()) do
        if math.tointeger(v[1]) == 4 then
            local msg = seiran.api.messages.getById{
                message_ids=math.tointeger(v[2])
            }.response.items[1]
            local reciever = seiran.api.users.get{
                user_ids=math.tointeger(v[4])..","..math.tointeger(msg.from_id)
            }.response
            reciever[2] = reciever[2] or reciever[1]
            io.write(reciever[2].first_name.." "..reciever[2].last_name.." ( ID:"..math.tointeger(reciever[2].id)..") Wrote message \""..msg.text.."\" ")
            io.write("In chat "..reciever[1].first_name.." "..reciever[1].last_name.." ( ID:"..math.tointeger(reciever[1].id)..")\n")
        end
    end
end
```