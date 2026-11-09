local SCRIPT_ID   = "7237a75ecd8f44aefe931d6a4d6f4c75"
local GET_KEY_URL = "https://ads.luarmor.net/get_key?for=Adopt_Victims-wJmqPVYSplcL"
local DISCORD_URL = "https://discord.gg/P7YpzeF5X"
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
    KEY_VALID = "You're in! Loading...",
    KEY_EXPIRED = "Your key ran out. Grab a fresh one.",
    KEY_BANNED = "This key is banned.",
    KEY_HWID_LOCKED = "This key belongs to another device. Reset it in our Discord.",
    KEY_INCORRECT = "That key didn't match. Copy it again from the key page.",
    KEY_INVALID = "That key didn't match. Copy it again from the key page.",
    INVALID_EXECUTOR = "Your executor isn't supported, sorry.",
    SCRIPT_ID_INCORRECT = "Loader hiccup. Please tell the dev.",
    SCRIPT_ID_INVALID = "Loader hiccup. Please tell the dev.",
    SECURITY_ERROR = "Couldn't verify. Turn off your VPN and retry.",
    TIME_ERROR = "Your device clock looks off. Set date & time to automatic.",
}

local function check(key)
    if type(key) ~= "string" or #key < 10 then return false, "KEY_INCORRECT" end
    local ok, status = pcall(api.check_key, key)
    if not ok or type(status) ~= "table" then return false, "UNKNOWN_ERROR" end
    return status.code == "KEY_VALID", tostring(status.code or "UNKNOWN_ERROR"), status
end

local function start(key)
    script_key = key
    G.script_key = key
    api.load_script()
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

local parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
local gui = Instance.new("ScreenGui")
gui.Name = "AVKey"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
if not pcall(function() gui.Parent = parent end) then gui.Parent = LP:WaitForChild("PlayerGui") end

local ACCENT = Color3.fromRGB(129, 140, 248)
local BG     = Color3.fromRGB(20, 20, 27)
local CARD   = Color3.fromRGB(32, 32, 42)
local TEXT   = Color3.fromRGB(236, 236, 245)
local MUTED  = Color3.fromRGB(150, 150, 170)

local function new(class, props, children)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = o end
    return o
end
local function round(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end

local frame = new("Frame", {
    Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(300, 212), BackgroundColor3 = BG, BorderSizePixel = 0,
}, { round(16), new("UIStroke", { Color = Color3.fromRGB(55, 55, 72), Thickness = 1 }),
     new("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20),
        PaddingTop = UDim.new(0, 18), PaddingBottom = UDim.new(0, 18) }),
     new("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })

new("TextLabel", {
    Parent = frame, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1,
    Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "Welcome",
})
local status = new("TextLabel", {
    Parent = frame, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 2,
    Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = MUTED, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    Text = "Grab a free key, paste it below, and you're set.",
})
local box = new("TextBox", {
    Parent = frame, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 3,
    BackgroundColor3 = CARD, BorderSizePixel = 0, ClearTextOnFocus = false,
    Font = Enum.Font.Code, TextSize = 14, TextColor3 = TEXT, PlaceholderText = "paste your key",
    PlaceholderColor3 = Color3.fromRGB(110, 110, 130), Text = "",
}, { round(10), new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }) })

local row = new("Frame", {
    Parent = frame, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 4, BackgroundTransparency = 1,
}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10),
        HorizontalAlignment = Enum.HorizontalAlignment.Center }) })

local function button(text, w, color, order)
    return new("TextButton", {
        Parent = row, Size = UDim2.new(0, w, 1, 0), LayoutOrder = order,
        BackgroundColor3 = color, BorderSizePixel = 0, AutoButtonColor = true,
        Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = TEXT, Text = text,
    }, { round(10) })
end
local getKey = button("Get Key", 124, CARD, 1)
local verify = button("Verify", 124, ACCENT, 2)

local function say(text, good)
    status.Text = text
    status.TextColor3 = good == true and Color3.fromRGB(110, 225, 160)
        or good == false and Color3.fromRGB(250, 130, 130) or MUTED
end

local function copy(text)
    local f = setclipboard or toclipboard or (type(Clipboard) == "table" and Clipboard.set)
    return type(f) == "function" and pcall(f, text)
end

getKey.MouseButton1Click:Connect(function()
    if copy(GET_KEY_URL) then
        say("Link copied! Open it in your browser, finish the steps, then paste the key here.")
    else
        say("Open this in your browser:\n" .. GET_KEY_URL)
    end
end)

local busy, done = false, false
local function tryKey()
    if busy or done then return end
    local key = (box.Text or ""):gsub("%s", "")
    if key == "" then say("Paste your key first.", false) return end
    busy = true
    verify.Text = "Checking..."
    local valid, code = check(key)
    busy = false
    verify.Text = "Verify"
    if valid then
        done = true
        say(MESSAGES.KEY_VALID, true)
        save(key)
        task.wait(0.6)
        gui:Destroy()
        start(key)
    else
        local text = MESSAGES[code] or "Couldn't check that key. Try again in a minute."
        if code == "KEY_HWID_LOCKED" then
            copy(DISCORD_URL)
            text = text .. " (link copied)"
        end
        say(text, false)
    end
end
verify.MouseButton1Click:Connect(tryKey)
box.FocusLost:Connect(function(enter) if enter then tryKey() end end)
