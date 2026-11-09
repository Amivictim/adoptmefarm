local SCRIPT_ID   = "14638ac1cc5352cd047495287556b971"
local LOADER_URL  = "https://api.luarmor.net/files/v4/loaders/14638ac1cc5352cd047495287556b971.lua"
local GET_KEY_URL = "https://ads.luarmor.net/get_key?for=Adopt_Victims-wJmqPVYSplcL"
local DISCORD_URL = "https://discord.gg/P7YpzeF5X"
local PFP_URL     = "https://raw.githubusercontent.com/Amivictim/adoptmefarm/refs/heads/main/victimoffate_.png"
local WINDUI_URL  = "https://github.com/Footagesus/WindUI/releases/download/1.6.66/main.lua"
local KEY_FILE    = "AdoptVictims/key.txt"

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
while not LP do task.wait(0.2); LP = Players.LocalPlayer end
local G = (type(getgenv) == "function" and getgenv()) or _G

local okLib, api = pcall(function()
    return loadstring(game:HttpGet("https://sdkapi-public.luarmor.net/library.lua"))()
end)
if not okLib or type(api) ~= "table" then
    LP:Kick("Adopt Victim's: couldn't reach Luarmor. Check your internet and try again.")
    return
end
api.script_id = SCRIPT_ID

local function readSaved()
    local ok, text = pcall(function()
        if type(isfile) == "function" and isfile(KEY_FILE) then return readfile(KEY_FILE) end
    end)
    return ok and type(text) == "string" and (text:gsub("%s", "")) or nil
end
local function save(key)
    pcall(function()
        if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder("AdoptVictims") then
            makefolder("AdoptVictims")
        end
        if type(writefile) == "function" then writefile(KEY_FILE, key) end
    end)
end
local function forget()
    pcall(function() if type(delfile) == "function" and isfile(KEY_FILE) then delfile(KEY_FILE) end end)
end

local MESSAGES = {
    KEY_VALID = "You're in, loading...",
    KEY_EXPIRED = "Your key ran out, grab a fresh one.",
    KEY_BANNED = "This key is banned.",
    KEY_HWID_LOCKED = "This key belongs to another device. Reset it in our Discord.",
    KEY_INCORRECT = "That key didn't match, copy it again.",
    KEY_INVALID = "That key didn't match, copy it again.",
    INVALID_EXECUTOR = "Your executor isn't supported, sorry.",
    SCRIPT_ID_INCORRECT = "Key system is still being set up, try again soon.",
    SCRIPT_ID_INVALID = "Key system is still being set up, try again soon.",
    SECURITY_ERROR = "Couldn't verify, turn off your VPN and retry.",
    TIME_ERROR = "Your device clock is off, set date and time to automatic.",
}

local function check(key)
    if type(key) ~= "string" or #key < 10 then return false, "KEY_INCORRECT" end
    local ok, status = pcall(api.check_key, key)
    if not ok or type(status) ~= "table" then return false, "UNKNOWN_ERROR" end
    return status.code == "KEY_VALID", tostring(status.code or "UNKNOWN_ERROR")
end

local function start(key)
    script_key = key
    G.script_key = key
    loadstring(game:HttpGet(LOADER_URL))()
end

local preset = (type(script_key) == "string" and script_key ~= "" and script_key) or G.script_key or readSaved()
if type(preset) == "string" and preset ~= "" then
    local valid, code = check(preset)
    if valid then
        save(preset)
        start(preset)
        return
    end
    if code == "KEY_EXPIRED" or code == "KEY_BANNED" or code == "KEY_INCORRECT" or code == "KEY_INVALID" then forget() end
end

local okUI, WindUI = pcall(function()
    return loadstring(game:HttpGet(WINDUI_URL))()
end)
if not okUI or type(WindUI) ~= "table" then
    LP:Kick("Adopt Victim's: couldn't load the key window. Try again.")
    return
end

local function copy(text)
    local f = setclipboard or toclipboard or (type(Clipboard) == "table" and Clipboard.set)
    return type(f) == "function" and pcall(f, text)
end

local Window = WindUI:CreateWindow({
    Title = "please get yourself a key",
    Icon = PFP_URL,
    Author = "Adopt Victim's v4",
    Folder = "AdoptVictims",
    Size = UDim2.fromOffset(380, 248),
    Theme = "Dark",
    SideBarWidth = 150,
    HideSearchBar = true,
    Resizable = false,
    IgnoreAlerts = true,
})

local tab = Window:Tab({ Title = "Key", Icon = "key" })

local info = tab:Paragraph({
    Title = "put your key here",
    Desc = "Tap Get Key, finish the page, then paste your key below. It checks itself.",
})

local busy, done = false, false
local keyBox

local function verify(text)
    if busy or done then return end
    local key = tostring(text or ""):gsub("%s", "")
    if key == "" then return end
    busy = true
    pcall(function() info:SetDesc("Checking your key...") end)
    local valid, code = check(key)
    busy = false
    if valid then
        done = true
        save(key)
        pcall(function() info:SetDesc(MESSAGES.KEY_VALID) end)
        WindUI:Notify({ Title = "Adopt Victim's", Content = MESSAGES.KEY_VALID, Duration = 4 })
        task.wait(0.6)
        pcall(function() Window:Destroy() end)
        start(key)
    else
        local text2 = MESSAGES[code] or ("Couldn't check that key (" .. code .. "), try again in a minute.")
        if code == "KEY_HWID_LOCKED" then copy(DISCORD_URL) end
        pcall(function() info:SetDesc(text2) end)
        WindUI:Notify({ Title = "Adopt Victim's", Content = text2, Duration = 5 })
    end
end

keyBox = tab:Input({
    Title = "Key",
    Placeholder = "paste your key here",
    Callback = function(text) task.spawn(verify, text) end,
})

tab:Button({
    Title = "Get Key",
    Icon = "external-link",
    Callback = function()
        if copy(GET_KEY_URL) then
            WindUI:Notify({ Title = "Link copied", Content = "Open it in your browser, finish the steps, then paste the key.", Duration = 6 })
        else
            WindUI:Notify({ Title = "Get your key at", Content = GET_KEY_URL, Duration = 10 })
        end
    end,
})

tab:Button({
    Title = "Copy Discord Link",
    Icon = "message-circle",
    Callback = function()
        copy(DISCORD_URL)
        WindUI:Notify({ Title = "Discord copied", Content = DISCORD_URL, Duration = 6 })
    end,
})

pcall(function() Window:SelectTab(1) end)
pcall(function() tab:Select() end)
