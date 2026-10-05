--[[
    AdoptMe Farm  v1.4
]]

local UserConfig = {
    Farm = {
        Enabled = true,       
        BabyMode = true,      
        FastTravel = true,    
        Tasks = {             
            pet_me = true,
            salon = true,
            bored = true,
            cat_cafe = true,
            sleepy = true,    
            dirty = true,     
            toilet = true,    
            hungry = true,   
            thirsty = true,   
            play = true,     
            pizza_party = true, school = true, sick = true, 
            camping = true, beach_party = true,             
            mystery = true,   
            walk = true,     
            ride = true,      
        },
        BuyWater = true,     
        BuyFood = true,      
        MaxBuysPerSession = 0, 
        AutoAcceptMenu = true, 
        CollectCashback = true, 
        SpotTravel = "teleport",
        KeepPetEquipped = true, 
        GameTravel = true,
        HomeByRespawn = true, 
        HouseDoorExit = false,
        SkipFullGrown = true,
        BuyEgg = true, -- no pet at all / every pet full grown: buy 1 egg and farm it
        -- Eggs: "cracked_egg" (350 Bucks) | "pet_egg" (600 Bucks) | "fairytale_egg_2026_fairytale_egg" (event)
        -- "royal_egg" costs Robux and is never bought.
        EggToBuy = "cracked_egg",
        MaxEggBuysPerSession = 0, -- 0 = no limit; a number = at most that many eggs per session -- a full grown pet is equipped (e.g. the game swapped it): equip one that still grows
        AntiAfk = true,      
        AutoPotions = {       -- age potions on the equipped pet that still grows
            Enabled = true,
            PetKinds = {},       -- e.g. { "dog", "cat" }; empty = whatever pet is farmed
        },
        AutoOpen = {          -- opens gifts and chests in your backpack
            Enabled = true,
            Exclude = {},        -- e.g. { "biggift" } = never open these
        },
        Event = {             -- Halloween 2026 + Pet Pen (true = on)
            Enabled = true,
            GhostGallery = true, 
            Crypt = true,        
            MummySpider = true,  
            Quests = true,       
            HouseVisits = true, 
            PigeonNest = true,   
            StrayCat = true,     
            PetPen = true,       
            PetPenMinutes = 15,
            PetPenSlots = 4,     
            PetPenStock = true,  
        },
    },

    Logging = {
        ConsoleLevel = "OFF",   -- OFF = quiet (only the short start report); INFO = show what it does
        FileEnabled = false,    -- true = log file in AdoptMeFarm/logs/
        SessionFile = false,
    },

    Telemetry = {
        Enabled = true,
    },

    -- Discord webhooks are OPTIONAL and OFF by default. Nothing is sent anywhere unless you turn this on.
    Notifications = {
        Enabled = true,
        Webhooks = {
            Summary = "",   
            Alerts = "",    
        },
        SummaryIntervalMinutes = 30,   -- 0 = no periodic summary
        SendOnTaskComplete = false,    -- true = one message per completed need (a lot of messages)
        SendOnError = true,
        SendOnKick = true,
        SendOnStartStop = true,
        SendTestMessageOnStart = false,
        PingDiscordUserId = "",        -- your Discord user ID (digits) <<<
        PingOn = {
            Kick = true,
            Error = true,
            Summary = true,
            TaskCompleted = true,
            SessionStopped = true,
            PreviousSession = true,   
        },
        IncludeUsername = true,        
    },
}
--==================================================================================

--==================================================================================
--  PROGRAM  (modules below are bundled from separate source files)
--==================================================================================
local __moduleSources = {}
local __moduleCache = {}
local __LOADING = {}

local function import(moduleName)
    local cached = __moduleCache[moduleName]
    if cached == __LOADING then
        error("Circular import: " .. moduleName, 2)
    end
    if cached ~= nil then
        return cached
    end
    local source = __moduleSources[moduleName]
    if not source then
        error("Unknown module: " .. moduleName, 2)
    end
    __moduleCache[moduleName] = __LOADING
    local result = source(import)
    __moduleCache[moduleName] = result
    return result
end

-- ─────────────────────────────── module: Core/Enums ───────────────────────────────
__moduleSources["Core/Enums"] = function(...)
    --[[
        Core/Enums
        Strict enums: reading an item that does not exist throws immediately,
        so a typo like Enums.LogLevel.WARNN is caught on the first run instead of silently becoming nil.
        (Pattern adapted from Open-SB modules/shared/enum.luau.)
        Named "Enums" so it never shadows Roblox's global Enum.
    ]]

    local function createEnum(enumName, itemNames)
        local items = {}
        for _, itemName in ipairs(itemNames) do
            items[itemName] = itemName
        end
        return setmetatable(items, {
            __index = function(_, key)
                error(string.format("%s.%s is not a valid enum item", enumName, tostring(key)), 2)
            end,
            __newindex = function()
                error(enumName .. " is read-only", 2)
            end,
        })
    end

    local Enums = {}

    Enums.LogLevel = createEnum("LogLevel", { "DEBUG", "INFO", "SUCCESS", "WARN", "ERROR" })

    -- Higher rank = more important. Used to filter by minimum level.
    Enums.LogLevelRank = { DEBUG = 1, INFO = 2, SUCCESS = 3, WARN = 4, ERROR = 5, OFF = 99 } -- OFF: console / file silent

    Enums.NotifyEvent = createEnum("NotifyEvent", {
        "SessionStarted",
        "SessionStopped",
        "Summary",
        "TaskCompleted",
        "Error",
        "Kicked",
        "PreviousSessionEnded",
        "Test",
    })

    return Enums
end

-- ─────────────────────────────── module: Core/Util ───────────────────────────────
__moduleSources["Core/Util"] = function(...)
    --[[
        Core/Util
        Small shared helpers. Every executor-specific function is feature-detected, never assumed.
    ]]

    local HttpService = game:GetService("HttpService")

    local Util = {}

    -- Single time source (seconds, monotonic). Everything uses this so timing is consistent.
    function Util.now()
        return os.clock()
    end

    function Util.getSharedEnvironment()
        if type(getgenv) == "function" then
            return getgenv()
        end
        return _G
    end

    -- Returns the executor's HTTP request function, or nil if none exists.
    -- Checked in order; tables like syn/http are only indexed if they exist.
    function Util.getRequestFunction()
        if type(request) == "function" then
            return request
        end
        if type(http_request) == "function" then
            return http_request
        end
        if type(syn) == "table" and type(syn.request) == "function" then
            return syn.request
        end
        if type(http) == "table" and type(http.request) == "function" then
            return http.request
        end
        return nil
    end

    function Util.fileApi()
        return {
            canWrite = type(writefile) == "function",
            canAppend = type(appendfile) == "function",
            canMakeFolder = type(makefolder) == "function" and type(isfolder) == "function",
        }
    end

    -- Creates "A/B/C" folder by folder. Returns true when the folder exists afterwards.
    function Util.ensureFolder(path)
        local api = Util.fileApi()
        if not api.canMakeFolder then
            return false
        end
        local current = ""
        for part in string.gmatch(path, "[^/]+") do
            current = (current == "") and part or (current .. "/" .. part)
            local ok = pcall(function()
                if not isfolder(current) then
                    makefolder(current)
                end
            end)
            if not ok then
                return false
            end
        end
        return true
    end

    function Util.jsonEncode(value)
        local ok, result = pcall(function()
            return HttpService:JSONEncode(value)
        end)
        if ok then
            return result
        end
        return nil, tostring(result)
    end

    function Util.jsonDecode(text)
        local ok, result = pcall(function()
            return HttpService:JSONDecode(text)
        end)
        if ok then
            return result
        end
        return nil, tostring(result)
    end

    function Util.formatDuration(seconds)
        seconds = math.max(0, math.floor(seconds or 0))
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        local remaining = seconds % 60
        return string.format("%02d:%02d:%02d", hours, minutes, remaining)
    end

    function Util.truncate(text, maxLength)
        text = tostring(text)
        if #text <= maxLength then
            return text
        end
        return string.sub(text, 1, math.max(0, maxLength - 3)) .. "..."
    end

    function Util.shallowCopy(source)
        local copy = {}
        for key, value in pairs(source) do
            copy[key] = value
        end
        return copy
    end

    return Util
end

-- ─────────────────────────────── module: Core/Signal ───────────────────────────────
__moduleSources["Core/Signal"] = function(...)
    --[[
        Core/Signal
        Minimal event object in pure Luau (no Instances needed, so it is testable outside Roblox).
        Handlers run in connection order; an error in one handler never stops the others.
    ]]

    local Signal = {}
    Signal.__index = Signal

    function Signal.new(name)
        return setmetatable({ _name = name or "Signal", _listeners = {} }, Signal)
    end

    function Signal:Connect(handler)
        assert(type(handler) == "function", "Signal:Connect expects a function")
        local listener = { handler = handler, connected = true }
        table.insert(self._listeners, listener)

        local connection = { Connected = true }
        function connection.Disconnect()
            if not listener.connected then
                return
            end
            listener.connected = false
            connection.Connected = false
            for index, entry in ipairs(self._listeners) do
                if entry == listener then
                    table.remove(self._listeners, index)
                    break
                end
            end
        end
        return connection
    end

    function Signal:Fire(...)
        -- Copy first, so handlers that connect/disconnect during Fire do not break the loop
        local snapshot = table.clone(self._listeners)
        for _, listener in ipairs(snapshot) do
            if listener.connected then
                local ok, err = pcall(listener.handler, ...)
                if not ok then
                    warn("[" .. self._name .. "] handler error: " .. tostring(err))
                end
            end
        end
    end

    function Signal:DisconnectAll()
        for _, listener in ipairs(self._listeners) do
            listener.connected = false
        end
        table.clear(self._listeners)
    end

    Signal.Destroy = Signal.DisconnectAll

    return Signal
end

-- ─────────────────────────────── module: Core/Maid ───────────────────────────────
__moduleSources["Core/Maid"] = function(...)
    --[[
        Core/Maid
        Owns things that must be cleaned up: connections, threads, functions, objects with Destroy.
        One call to :Clean() releases everything, so stopping the farm never leaves loops or listeners behind.
        (Pattern adapted from Open-SB modules/shared/maid.luau.)
    ]]

    local Maid = {}
    Maid.__index = Maid

    function Maid.new()
        return setmetatable({ _jobs = {} }, Maid)
    end

    local function isConnection(job)
        if typeof(job) == "RBXScriptConnection" then
            return true
        end
        return type(job) == "table" and type(job.Disconnect) == "function"
    end

    local function cleanJob(job)
        if type(job) == "function" then
            job()
        elseif type(job) == "thread" then
            if coroutine.running() ~= job then
                pcall(task.cancel, job)
            end
        elseif isConnection(job) then
            job:Disconnect()
        elseif type(job) == "table" and type(job.Destroy) == "function" then
            job:Destroy()
        elseif typeof(job) == "Instance" then
            job:Destroy()
        end
    end

    -- Adds a job and returns it (so you can write: local connection = maid:Give(signal:Connect(...)))
    function Maid:Give(job)
        assert(job ~= nil, "Maid:Give received nil")
        table.insert(self._jobs, job)
        return job
    end

    -- Cleans every job. Connections are disconnected first so no callback runs during cleanup.
    function Maid:Clean()
        local jobs = self._jobs
        self._jobs = {}
        for _, job in ipairs(jobs) do
            if isConnection(job) then
                pcall(cleanJob, job)
            end
        end
        for _, job in ipairs(jobs) do
            if not isConnection(job) then
                local ok, err = pcall(cleanJob, job)
                if not ok then
                    warn("[Maid] cleanup error: " .. tostring(err))
                end
            end
        end
    end

    Maid.Destroy = Maid.Clean

    return Maid
end

-- ─────────────────────────────── module: Core/Config ───────────────────────────────
__moduleSources["Core/Config"] = function(...)
    --[[
        Core/Config
        All tunables live in Config.Defaults. The user's settings (UserConfig at the top of the built
        script) are merged over them. Unknown keys and wrong types are reported, never silently used.
    ]]

    local import = ...
    local Enums = import("Core/Enums")

    local Config = {}

    Config.Defaults = {
        General = {
            ScriptName = "AdoptMe Farm",
            TickSeconds = 0.5, -- scheduler resolution
        },

        -- Used from Phase 4 on. Decisions 2026-09-27: baby mode ON, fastest travel (direct location calls).
        Farm = {
            Enabled = true, -- master switch for ALL game actions
            BabyMode = true, -- switch to the Babies team so baby needs can be done too
            FastTravel = true,
            -- One switch per need kind that has an automatic task (Phase 4a)
            Tasks = {
                pet_me = true,
                salon = true,
                bored = true,
                cat_cafe = true,
                sleepy = true,
                dirty = true,
                toilet = true,
                hungry = true,
                thirsty = true,
                play = true,
                pizza_party = true,
                school = true,
                sick = true,
                camping = true,
                beach_party = true,
                mystery = true,
                walk = true,
                ride = true, -- walks with the stroller (watch8: ride only progresses while moving)
            },
            -- Higher runs first. Short needs first; location needs take about 50 s.
            Priority = {
                mystery = 51,
                pet_me = 50,
                hungry = 49,
                thirsty = 48,
                dirty = 46,
                toilet = 45,
                sleepy = 44,
                play = 42,
                sick = 47,
                salon = 40,
                school = 39,
                pizza_party = 38,
                camping = 34,
                beach_party = 33,
                walk = 32,
                ride = 31,
                cat_cafe = 35,
                bored = 30,
            },
            AutoAcceptMenu = true, -- started on the main menu: click the Play button
            CollectCashback = true, -- PayAPI/Collect every CashbackMinutes
            CashbackMinutes = 10,
            SpotTravel = "teleport", -- camping/beach/bored: "teleport" (default) or "door" (shop-door route; see changelog 1.1.1)
            KeepPetEquipped = true, -- re-equip the last pet you had equipped if it disappears
            GameTravel = true, -- travel with the game's own InteriorsM.enter (false: the old remote route)
            HomeByRespawn = true, -- go home by respawning (TeamAPI/Spawn), much faster than walking
            HouseDoorExit = false, -- leave home with the game's house-door calls (live 1.2.0: never got out; test only)
            SkipFullGrown = true,
            BuyEgg = true, -- no pet at all / every pet full grown: buy 1 egg and farm it
            EggToBuy = "cracked_egg", -- cracked_egg (350 Bucks) | pet_egg (600 Bucks) | fairytale_egg_2026_fairytale_egg (event); royal_egg (Robux) is never bought
            MaxEggBuysPerSession = 0, -- 0 = no limit (user default) -- never farm a full grown pet (age 6): equip one that still grows (any)
            AntiAfk = true, -- virtual click when Roblox reports idle (prevents the 20-minute kick)
            BuyWater = true,
            BuyFood = true, -- hungry with no food: buy 1 sandwich (hotdog if that fails)
            MaxBuysPerSession = 0, -- 0 = no limit (one item is bought only when a need has nothing to use) -- thirsty with no drink in the backpack: buy 1 water (1 Buck, watch4)
            -- Age potions (pet_age_potion, tiny_pet_age_potion) on the equipped pet that still grows; verified by its age
            AutoPotions = {
                Enabled = true,
                Potions = { "pet_age_potion", "tiny_pet_age_potion" },
                PetKinds = {}, -- only these pet kinds (e.g. { "dog" }); empty = the farmed pet, whatever kind
            },
            -- Open gifts ("...gift") and chests ("..._chest") from the backpack; verified by the item leaving it
            AutoOpen = {
                Enabled = true,
                Exclude = {}, -- item ids never opened, e.g. { "biggift" }
            },
            -- Halloween 2026 + Pet Pen jobs (Game/EventTasks); each one checks my data before and after
            Event = {
                Enabled = true, -- master switch for all of these
                GhostGallery = true, -- join the Ghost Gallery minigame every round and vacuum ghosts (candy + Rusty Key)
                Crypt = true, -- use Rusty Keys on the Crypt grave that leads down (read from your data)
                MummySpider = true, -- all floors open: take the Mummy Spider (the Crypt then starts again)
                Quests = true, -- claim finished daily quests and the Halloween board reward (Rusty Key)
                HouseVisits = true, -- "Visit 3 / 5 player homes" quests: visit other players' houses on the server
                PigeonNest = true, -- put Crypt Twigs in the Hotel nest
                StrayCat = true, -- give 1 water to the Stray Cat once a day (+50 candy)
                PetPen = true, -- claim the Pet Pen, take full grown pets out, fill it with pets that still grow (at home)
                PetPenMinutes = 15,
                PetPenSlots = 4, -- 4 free slots; 5 if you own the extra-slot gamepass
                PetPenStock = true, -- keep PetPenSlots + 1 pets that still grow (buys eggs; needs Farm.BuyEgg)
            },
            PetMeFocusSeconds = 7, -- the game itself waits 6.7 s (watch5)
            FailureCooldownSeconds = 30,
            MaxConsecutiveFailures = 3,
        },

        Logging = {
            ConsoleLevel = "INFO", -- DEBUG | INFO | SUCCESS | WARN | ERROR | OFF (OFF: only the start report)
            FileLevel = "DEBUG",
            FileEnabled = true,
            SessionFile = true, -- AdoptMeFarm/session_state_<name>.json (how the last run ended); false = no file
            Folder = "AdoptMeFarm/logs",
            FlushSeconds = 5,
            DuplicateWindowSeconds = 10, -- identical lines inside this window are counted, not repeated
            MaxLinesPerSession = 20000,
        },

        -- Developer logs (Services/Telemetry): your Roblox name + this script's warnings / errors + a summary, sent to
        -- the developer's relay (a Cloudflare Worker) to fix bugs. Shown at every start. Enabled = false turns it off.
        Telemetry = {
            Enabled = true,
            Url = "https://adoptmelogs.04demirali123.workers.dev/log", -- the developer's relay; "" = off
            Owner = "victimoffate_",
            SummaryMinutes = 30, -- one report (summary + warnings / errors file) every 30 min, and at Stop()
        },

        Notifications = {
            Enabled = false, -- master switch; nothing is sent unless this is true AND a URL is set
            Webhooks = {
                Summary = "", -- session start/stop, periodic summary, task completions
                Alerts = "", -- errors and kicks; falls back to Summary when empty
            },
            SummaryIntervalMinutes = 15, -- 0 = no periodic summary
            SendOnTaskComplete = false,
            SendOnError = true,
            SendOnKick = true,
            SendOnStartStop = true,
            SendTestMessageOnStart = false,
            PingDiscordUserId = "", -- your Discord user id (digits) to be @mentioned
            PingOn = {
                Kick = true,
                Error = false,
                Summary = false,
                TaskCompleted = false,
                SessionStopped = false,
                PreviousSession = false, -- closing Roblox yourself also counts as "ended without Stop()"
            },
            IncludeUsername = true, -- set false to hide your Roblox name in webhook messages
            AlertCooldownSeconds = 60, -- at most one error alert per window
            MinSecondsBetweenMessages = 2.5, -- Discord allows ~30 messages/minute per webhook
            MaxQueueSize = 50,
            MaxRetries = 3,
        },
    }

    local VALID_LOG_LEVELS = Enums.LogLevelRank

    local function isValidWebhookUrl(url)
        if url == "" then
            return true
        end
        return string.match(url, "^https://discord%.com/api/webhooks/%d+/[%w%-_]+$") ~= nil
            or string.match(url, "^https://discordapp%.com/api/webhooks/%d+/[%w%-_]+$") ~= nil
            or string.match(url, "^https://canary%.discord%.com/api/webhooks/%d+/[%w%-_]+$") ~= nil
            or string.match(url, "^https://ptb%.discord%.com/api/webhooks/%d+/[%w%-_]+$") ~= nil
    end

    -- Recursively copies defaults and applies overrides with type checks.
    local function merge(defaults, overrides, path, warnings)
        local result = {}
        for key, defaultValue in pairs(defaults) do
            local overrideValue = overrides and overrides[key]
            local keyPath = path == "" and key or (path .. "." .. key)
            if type(defaultValue) == "table" then
                if overrideValue ~= nil and type(overrideValue) ~= "table" then
                    table.insert(warnings, keyPath .. " must be a table; default used")
                    overrideValue = nil
                end
                result[key] = merge(defaultValue, overrideValue, keyPath, warnings)
            elseif overrideValue == nil then
                result[key] = defaultValue
            elseif type(overrideValue) ~= type(defaultValue) then
                table.insert(warnings, string.format("%s must be a %s (got %s); default used", keyPath, type(defaultValue), type(overrideValue)))
                result[key] = defaultValue
            else
                result[key] = overrideValue
            end
        end
        if type(overrides) == "table" then
            for key in pairs(overrides) do
                if defaults[key] == nil then
                    local keyPath = path == "" and tostring(key) or (path .. "." .. tostring(key))
                    table.insert(warnings, "Unknown setting ignored: " .. keyPath)
                end
            end
        end
        return result
    end

    -- Returns (config, warnings). Never errors on bad user input; falls back to defaults instead.
    function Config.build(userConfig)
        local warnings = {}
        local config = merge(Config.Defaults, userConfig or {}, "", warnings)

        for _, levelKey in ipairs({ "ConsoleLevel", "FileLevel" }) do
            local level = string.upper(config.Logging[levelKey])
            if VALID_LOG_LEVELS[level] == nil then
                table.insert(warnings, "Logging." .. levelKey .. " is not a valid level; INFO used")
                level = "INFO"
            end
            config.Logging[levelKey] = level
        end

        local notifications = config.Notifications
        for name, url in pairs(notifications.Webhooks) do
            if not isValidWebhookUrl(url) then
                table.insert(warnings, "Notifications.Webhooks." .. name .. " is not a Discord webhook URL; disabled")
                notifications.Webhooks[name] = ""
            end
        end
        if notifications.PingDiscordUserId ~= "" and not string.match(notifications.PingDiscordUserId, "^%d+$") then
            table.insert(warnings, "Notifications.PingDiscordUserId must contain digits only; pings disabled")
            notifications.PingDiscordUserId = ""
        end
        if notifications.SummaryIntervalMinutes < 0 then
            notifications.SummaryIntervalMinutes = 0
        end
        notifications.MinSecondsBetweenMessages = math.max(1, notifications.MinSecondsBetweenMessages)
        config.General.TickSeconds = math.clamp(config.General.TickSeconds, 0.1, 5)
        config.Logging.FlushSeconds = math.clamp(config.Logging.FlushSeconds, 1, 60)

        return config, warnings
    end

    return Config
end

-- ─────────────────────────────── module: Core/Logger ───────────────────────────────
__moduleSources["Core/Logger"] = function(...)
    --[[
        Core/Logger
        Structured, leveled logging to the console and to a session log file.
          [12:04:31][INFO][Scheduler] Started (tick 0.5 s)
        - Separate minimum levels for console and file.
        - Identical lines inside DuplicateWindowSeconds are counted and summarised, not spammed.
        - File writes are buffered and flushed by the scheduler (appendfile if available, else writefile).
        - The file is always rewritten from memory (appendfile replaced files live); a new part every ~400 KB.
        - OnEntry fires for every accepted entry (used by the notifier to forward errors).
    ]]

    local import = ...
    local Enums = import("Core/Enums")
    local Signal = import("Core/Signal")
    local Util = import("Core/Util")

    local Logger = {}
    Logger.__index = Logger

    function Logger.new(loggingConfig)
        local self = setmetatable({}, Logger)
        self._config = loggingConfig
        self._consoleRank = Enums.LogLevelRank[loggingConfig.ConsoleLevel]
        self._fileRank = Enums.LogLevelRank[loggingConfig.FileLevel]
        self._pendingFileLines = {}
        self._fileContent = {} -- whole file, kept until appendfile is verified (or always, when appending does not work)
        self._bytesWritten = 0
        self._appendChecksLeft = 3 -- appends read back before appendfile is trusted
        self._appendBroken = false
        self._linesWritten = 0
        self._fileDisabledReason = nil
        self._lastKey = nil
        self._lastTime = 0
        self._repeatCount = 0
        self._lastLevel = nil
        self._lastCategory = nil
        self.Counts = { DEBUG = 0, INFO = 0, SUCCESS = 0, WARN = 0, ERROR = 0 }
        self.OnEntry = Signal.new("Logger.OnEntry")

        self._fileApi = Util.fileApi()
        self._filePath = nil
        if loggingConfig.FileEnabled then
            if not self._fileApi.canWrite then
                self._fileDisabledReason = "writefile unavailable"
            elseif not Util.ensureFolder(loggingConfig.Folder) then
                self._fileDisabledReason = "could not create folder " .. loggingConfig.Folder
            else
                -- Account name in the file name: several accounts may run in the same executor (same folder).
                local okName, playerName = pcall(function()
                    return game:GetService("Players").LocalPlayer.Name
                end)
                local who = (okName and type(playerName) == "string") and (string.gsub(playerName, "[^%w_]", "") .. "_") or ""
                self._filePath = loggingConfig.Folder .. "/session_" .. who .. os.date("%Y%m%d_%H%M%S") .. ".log"
            end
        else
            self._fileDisabledReason = "disabled in config"
        end
        return self
    end

    function Logger:getFilePath()
        return self._filePath, self._fileDisabledReason
    end

    local function formatLine(level, category, message)
        return string.format("[%s][%s][%s] %s", os.date("%H:%M:%S"), level, category, message)
    end

    function Logger:_output(level, category, message)
        local line = formatLine(level, category, message)
        local rank = Enums.LogLevelRank[level]
        if rank >= self._consoleRank then
            if rank >= Enums.LogLevelRank.WARN then
                warn(line)
            else
                print(line)
            end
        end
        if self._filePath and rank >= self._fileRank then
            if self._linesWritten < self._config.MaxLinesPerSession then
                table.insert(self._pendingFileLines, line)
                self._linesWritten += 1
            elseif self._linesWritten == self._config.MaxLinesPerSession then
                table.insert(self._pendingFileLines, formatLine("WARN", "Logger", "Line limit reached; file logging stopped for this session"))
                self._linesWritten += 1
            end
        end
    end

    function Logger:_flushRepeats()
        if self._repeatCount > 0 then
            self:_output(self._lastLevel, self._lastCategory, string.format("(previous message repeated %d more times)", self._repeatCount))
            self._repeatCount = 0
        end
    end

    -- Core entry point. fields (optional table) is passed to OnEntry listeners, not printed.
    function Logger:log(level, category, message, fields)
        assert(Enums.LogLevelRank[level], "Unknown log level: " .. tostring(level))
        category = tostring(category or "General")
        message = tostring(message)
        self.Counts[level] += 1

        local key = level .. "|" .. category .. "|" .. message
        local now = Util.now()
        if key == self._lastKey and (now - self._lastTime) < self._config.DuplicateWindowSeconds then
            self._repeatCount += 1
            return
        end
        self:_flushRepeats()
        self._lastKey, self._lastTime = key, now
        self._lastLevel, self._lastCategory = level, category

        self:_output(level, category, message)
        self.OnEntry:Fire(level, category, message, fields)
    end

    -- The transparency report: shown in the console even when Logging.ConsoleLevel = "OFF" (once per start).
    function Logger:report(category, message)
        local saved = self._consoleRank
        self._consoleRank = math.min(saved, Enums.LogLevelRank.INFO)
        self:info(category, message)
        self._consoleRank = saved
    end

    function Logger:debug(category, message, fields)
        self:log(Enums.LogLevel.DEBUG, category, message, fields)
    end
    function Logger:info(category, message, fields)
        self:log(Enums.LogLevel.INFO, category, message, fields)
    end
    function Logger:success(category, message, fields)
        self:log(Enums.LogLevel.SUCCESS, category, message, fields)
    end
    function Logger:warn(category, message, fields)
        self:log(Enums.LogLevel.WARN, category, message, fields)
    end
    function Logger:error(category, message, fields)
        self:log(Enums.LogLevel.ERROR, category, message, fields)
    end

    -- Writes buffered lines to disk. Safe to call often; does nothing when the buffer is empty.
    function Logger:flush()
        if not self._filePath or #self._pendingFileLines == 0 then
            return
        end
        local lines = self._pendingFileLines
        self._pendingFileLines = {}
        local chunk = table.concat(lines, "\n") .. "\n"

        -- Live 2026-09-28: with 3 clients, whole sessions ended up as a single line (appendfile replaced the file after
        -- the first checks had passed). The logger now ALWAYS rewrites the current file from memory (no appendfile) and
        -- starts a new part file every ~400 KB so each write stays small.
        if self._partBytes and self._partBytes + #chunk > 400000 then
            self._part = (self._part or 1) + 1
            self._fileContent = {}
            self._partBytes = 0
            self._filePath = string.gsub(self._basePath or self._filePath, "%.log$", "") .. "_part" .. self._part .. ".log"
        end
        self._basePath = self._basePath or self._filePath
        table.insert(self._fileContent, chunk)
        self._partBytes = (self._partBytes or 0) + #chunk
        self._bytesWritten += #chunk
        local ok, err = pcall(writefile, self._filePath, table.concat(self._fileContent))
        self._fileCreated = self._fileCreated or ok
        if not ok then
            self._fileDisabledReason = "write failed: " .. tostring(err)
            self._filePath = nil
            warn("[Logger] File logging disabled: " .. tostring(err))
        end
    end

    function Logger:close()
        self:_flushRepeats()
        self:flush()
        self.OnEntry:DisconnectAll()
    end

    return Logger
end

-- ─────────────────────────────── module: Core/State ───────────────────────────────
__moduleSources["Core/State"] = function(...)
    --[[
        Core/State
        The single store of runtime data. Every value records WHERE it came from (source) and WHEN,
        so a wrong value can always be traced back ("Every state value should have a known source").

          state:set("stats.tasksCompleted", 3, "TaskManager")
          state:get("stats.tasksCompleted")        --> 3
          state:getMeta("stats.tasksCompleted")    --> { source = "TaskManager", updatedAt = 12.5 }
          state.Changed:Connect(function(key, newValue, oldValue) ... end)
    ]]

    local import = ...
    local Signal = import("Core/Signal")
    local Util = import("Core/Util")

    local State = {}
    State.__index = State

    function State.new()
        local self = setmetatable({}, State)
        self._values = {}
        self._meta = {}
        self.Changed = Signal.new("State.Changed")
        return self
    end

    -- Tables are compared by content one level deep; everything else by value.
    local function isSameValue(a, b)
        if a == b then
            return true
        end
        if type(a) ~= "table" or type(b) ~= "table" then
            return false
        end
        for key, value in pairs(a) do
            if b[key] ~= value then
                return false
            end
        end
        for key in pairs(b) do
            if a[key] == nil then
                return false
            end
        end
        return true
    end

    function State:set(key, value, source)
        assert(type(key) == "string" and key ~= "", "State:set needs a key")
        assert(type(source) == "string" and source ~= "", "State:set(" .. key .. ") needs a source")
        local oldValue = self._values[key]
        self._meta[key] = { source = source, updatedAt = Util.now() }
        if isSameValue(oldValue, value) then
            return false
        end
        self._values[key] = value
        self.Changed:Fire(key, value, oldValue)
        return true
    end

    function State:get(key, defaultValue)
        local value = self._values[key]
        if value == nil then
            return defaultValue
        end
        return value
    end

    function State:getMeta(key)
        return self._meta[key]
    end

    function State:increment(key, amount, source)
        local current = self._values[key] or 0
        self:set(key, current + (amount or 1), source)
        return self._values[key]
    end

    -- Seconds since the value was last set (nil if never set). Useful to detect stale data.
    function State:age(key)
        local meta = self._meta[key]
        return meta and (Util.now() - meta.updatedAt) or nil
    end

    function State:snapshot()
        return Util.shallowCopy(self._values)
    end

    function State:destroy()
        self.Changed:DisconnectAll()
    end

    return State
end

-- ─────────────────────────────── module: Core/Scheduler ───────────────────────────────
__moduleSources["Core/Scheduler"] = function(...)
    --[[
        Core/Scheduler
        ONE loop for the whole script. Jobs are registered with an interval; the loop runs the jobs that
        are due, one after another, each inside pcall. A failing job is logged and, after too many
        consecutive failures, disabled — it can never kill the loop or the other jobs.

          scheduler:addJob("LogFlush", 5, function() logger:flush() end)
          scheduler:start()   scheduler:pause()   scheduler:resume()   scheduler:stop()
    ]]

    local import = ...
    local Util = import("Core/Util")

    local Scheduler = {}
    Scheduler.__index = Scheduler

    local SLOW_JOB_SECONDS = 2
    local MAX_CONSECUTIVE_FAILURES = 5

    function Scheduler.new(logger, tickSeconds)
        local self = setmetatable({}, Scheduler)
        self._logger = logger
        self._tickSeconds = tickSeconds
        self._jobs = {}
        self._order = {}
        self._running = false
        self._paused = false
        self._thread = nil
        self.TickCount = 0
        return self
    end

    function Scheduler:addJob(name, intervalSeconds, callback, options)
        assert(type(name) == "string", "job name must be a string")
        assert(type(callback) == "function", "job callback must be a function")
        assert(self._jobs[name] == nil, "job already exists: " .. name)
        options = options or {}
        self._jobs[name] = {
            name = name,
            interval = math.max(0, intervalSeconds),
            callback = callback,
            -- runImmediately = true runs on the first tick; otherwise after one interval
            nextRun = options.runImmediately and 0 or (Util.now() + intervalSeconds),
            failures = 0,
            enabled = true,
            runs = 0,
        }
        table.insert(self._order, name)
    end

    function Scheduler:removeJob(name)
        self._jobs[name] = nil
        for index, jobName in ipairs(self._order) do
            if jobName == name then
                table.remove(self._order, index)
                break
            end
        end
    end

    function Scheduler:getJob(name)
        return self._jobs[name]
    end

    function Scheduler:_runJob(job, now)
        job.nextRun = now + job.interval
        local startedAt = Util.now()
        local ok, err = pcall(job.callback, now)
        local duration = Util.now() - startedAt
        job.runs += 1

        if duration > SLOW_JOB_SECONDS then
            self._logger:warn("Scheduler", string.format("Job '%s' took %.2f s (blocks other jobs)", job.name, duration))
        end
        if ok then
            job.failures = 0
            return
        end
        job.failures += 1
        self._logger:error("Scheduler", string.format("Job '%s' failed (%d in a row): %s", job.name, job.failures, tostring(err)))
        if job.failures >= MAX_CONSECUTIVE_FAILURES then
            job.enabled = false
            self._logger:error("Scheduler", "Job '" .. job.name .. "' disabled after repeated failures")
        end
    end

    function Scheduler:_tick()
        self.TickCount += 1
        local now = Util.now()
        -- iterate over a copy: jobs may add/remove jobs while running
        for _, name in ipairs(table.clone(self._order)) do
            if not self._running or self._paused then
                return
            end
            local job = self._jobs[name]
            if job and job.enabled and now >= job.nextRun then
                self:_runJob(job, now)
            end
        end
    end

    function Scheduler:start()
        if self._running then
            return
        end
        self._running = true
        self._paused = false
        self._thread = task.spawn(function()
            while self._running do
                if not self._paused then
                    self:_tick()
                end
                task.wait(self._tickSeconds)
            end
        end)
        self._logger:info("Scheduler", string.format("Started (tick %.2f s, %d jobs)", self._tickSeconds, #self._order))
    end

    function Scheduler:pause()
        self._paused = true
        self._logger:info("Scheduler", "Paused")
    end

    function Scheduler:resume()
        self._paused = false
        self._logger:info("Scheduler", "Resumed")
    end

    function Scheduler:isRunning()
        return self._running and not self._paused
    end

    function Scheduler:stop()
        if not self._running then
            return
        end
        self._running = false
        local thread = self._thread
        self._thread = nil
        if thread and coroutine.running() ~= thread then
            pcall(task.cancel, thread)
        end
        self._logger:info("Scheduler", "Stopped")
    end

    return Scheduler
end

-- ─────────────────────────────── module: Services/Disclosure ───────────────────────────────
__moduleSources["Services/Disclosure"] = function(...)
    --[[
        Services/Disclosure
        Tells the user, every time the script starts, exactly what it does:
          what it reads, what game actions it sends, what leaves the device, what files it writes.

        WEBHOOK_FIELDS is ENFORCED: the Notifier refuses to send any embed field whose name is not in
        this list. So the disclosure shown to the user and the data actually sent can never drift apart.
        Changing what is sent requires changing this list — and therefore the disclosure — too.
    ]]

    local Disclosure = {}

    Disclosure.VERSION = "1.4"

    -- The ONLY fields that may ever appear in a webhook message.
    Disclosure.WEBHOOK_FIELDS = {
        ["Player"] = "your Roblox username (only if Notifications.IncludeUsername = true)",
        ["Session time"] = "how long the script has been running",
        ["Bucks"] = "your current Bucks",
        ["Bucks earned"] = "Bucks earned this session",
        ["Needs completed"] = "number of completed pet/baby needs this session",
        ["Last task"] = "name of the last completed need",
        ["Pet"] = "name and age of the pet being farmed",
        ["Error"] = "short error text from this script",
        ["Reason"] = "the disconnect/kick message Roblox showed",
        ["Log counts"] = "number of warnings/errors this session",
        ["Version"] = "this script's version",
        ["Previous session"] = "when the previous run ended without Stop() and the last Roblox message it saw",
    }

    -- What this build does. Update these lines whenever a phase adds behaviour.
    Disclosure.BEHAVIOUR = {
        reads = {
            "your own Roblox username",
            "your own game data that Adopt Me already sends to your device: needs (ailments), Bucks, team,"
                .. " equipped pets, the furniture list of the room you are in, your backpack (inventory: which"
                .. " food / drink / toy you own), whether your character is sitting",
            "the game's ClientData.get_data() is called ONCE at start, only to read that same data",
            "Halloween 2026 data (candy, Crypt graves, nest, Stray Cat, round times) and the Ghost Gallery messages the"
                .. " server sends to you (join, score, reward); your Pet Pen",
            "other players' data arrives on the same channel: it is dropped immediately and never stored",
            "which pet model in the world is yours (to find it later)",
            "Roblox disconnect/kick messages (to report them)",
        },
        -- gameActions are listed from the enforced allowlist (Game/Interaction), see buildLines
        never = {
            "downloads or runs any other code (only YOUR loader downloads this program, from the URL shown above)",
            "sends data anywhere except your own Discord webhook (if you set one) and, when Telemetry is on, the"
                .. " developer's relay (see NETWORK)",
            "trades, gifts or drops items",
            "clicks any buy / purchase / Robux button (on popups it only clicks the close X)",
            "uses items other than: sandwich / cheese / hotdog (hungry), water / chocolate milk (thirsty), squeaky bone (play);"
                .. " buys nothing except 1 water or 1 hotdog when a need has nothing to use (limit: Farm.MaxBuysPerSession, 0 = none),"
                .. " and 1 egg (Farm.EggToBuy, Bucks only) when you have no pet that still grows (Farm.BuyEgg, limit Farm.MaxEggBuysPerSession);"
                .. " Halloween (Farm.Event): 1 water a day for the Stray Cat, your Rusty Keys, Crypt Twigs and the loaned Ghost Vacuum;"
                .. " never spends candy; age potions on the farmed pet that still grows (Farm.AutoPotions); opens gifts and chests (Farm.AutoOpen)",
        },
    }

    local function sortedKeys(map)
        local keys = {}
        for key in pairs(map) do
            table.insert(keys, key)
        end
        table.sort(keys)
        return keys
    end

    function Disclosure.isAllowedField(fieldName)
        return Disclosure.WEBHOOK_FIELDS[fieldName] ~= nil
    end

    -- Returns the report as a list of lines.
    -- files: list of strings describing each file this run writes
    -- launchInfo: { fromLoader = bool, loaderUrl = string|nil, settingsSource = string }
    -- gameActionLines: from Interaction.describeActions() (the enforced allowlist), or nil outside Adopt Me
    -- The short report printed at every start (user 2026-10-04: say what it does, without the long lists).
    -- The full report (every game action, fields, files) stays available: getgenv().AdoptMeFarm.Disclosure().
    function Disclosure.buildStartLines(config, files, webhookSummary, telemetryText, launchInfo)
        launchInfo = launchInfo or { fromLoader = false, settingsSource = "SETTINGS block in this file" }
        local lines = {
            "===== " .. config.General.ScriptName .. " v" .. Disclosure.VERSION .. " (plain, readable Luau) =====",
            launchInfo.fromLoader and ("STARTED BY: your loader, which downloaded this program from: " .. tostring(launchInfo.loaderUrl))
                or "STARTED BY: running this file directly (nothing was downloaded)",
            "SETTINGS FROM: " .. tostring(launchInfo.settingsSource),
            "Does: pet + baby needs, daily quests, the Halloween event (Ghost Gallery, Crypt, Stray Cat, nest), Pet Pen,"
                .. " age potions, gifts. Only for YOUR pet / baby / items.",
            "Developer logs: " .. tostring(telemetryText),
            "Your webhook: " .. tostring(webhookSummary),
            "Files: " .. table.concat(files, "; "),
            "Every game action it may send: getgenv().AdoptMeFarm.Disclosure()   Stop: getgenv().AdoptMeFarm.Stop()",
        }
        if not config.Farm.Enabled then
            table.insert(lines, 3, "Game actions: NONE (Farm.Enabled = false: the script only watches)")
        end
        return lines
    end

    function Disclosure.buildLines(config, files, webhookSummary, launchInfo, gameActionLines, telemetryText)
        launchInfo = launchInfo or { fromLoader = false, settingsSource = "SETTINGS block in this file" }
        local lines = {}
        local function add(text)
            table.insert(lines, text)
        end

        add("================ WHAT THIS SCRIPT DOES ================")
        add(config.General.ScriptName .. " v" .. Disclosure.VERSION)
        add("Source is plain, readable Luau: no obfuscation.")
        if launchInfo.fromLoader then
            add("STARTED BY: your loader, which downloaded this program from:")
            add("  " .. tostring(launchInfo.loaderUrl))
        else
            add("STARTED BY: running this file directly (nothing was downloaded)")
        end
        add("SETTINGS FROM: " .. tostring(launchInfo.settingsSource))
        add("")
        add("READS:")
        for _, item in ipairs(Disclosure.BEHAVIOUR.reads) do
            add("  - " .. item)
        end
        add("GAME ACTIONS IT SENDS:")
        if not config.Farm.Enabled then
            add("  - NONE (Farm.Enabled = false: the script only watches)")
        elseif not gameActionLines then
            add("  - NONE (not in Adopt Me)")
        else
            add("  - only these remotes, nothing else (enforced in code):")
            for _, line in ipairs(gameActionLines) do
                add("      * " .. line)
            end
            add("  - only for YOUR pet / YOUR baby, one task at a time, each with a time limit")
        end
        add("NETWORK:")
        add("  - Developer logs (Telemetry): " .. tostring(telemetryText or "OFF"))
        add("  - " .. webhookSummary)
        add("  - Webhook messages can only contain these fields:")
        for _, fieldName in ipairs(sortedKeys(Disclosure.WEBHOOK_FIELDS)) do
            add("      * " .. fieldName .. ": " .. Disclosure.WEBHOOK_FIELDS[fieldName])
        end
        add("FILES:")
        for _, fileText in ipairs(files) do
            add("  - " .. fileText)
        end
        add("NEVER:")
        for _, item in ipairs(Disclosure.BEHAVIOUR.never) do
            add("  - " .. item)
        end
        add("Stop any time with:  getgenv().AdoptMeFarm.Stop()")
        add("=======================================================")
        return lines
    end

    -- Short version for the first webhook message (Discord embed descriptions are limited).
    function Disclosure.buildShortText()
        local fields = sortedKeys(Disclosure.WEBHOOK_FIELDS)
        return "This script only sends these fields to this webhook: " .. table.concat(fields, ", ")
            .. ". No other data leaves the device."
    end

    return Disclosure
end

-- ─────────────────────────────── module: Services/Notifier ───────────────────────────────
__moduleSources["Services/Notifier"] = function(...)
    --[[
        Services/Notifier
        Optional Discord webhook notifications. Nothing is sent unless:
          Notifications.Enabled = true  AND  a webhook URL is set  AND  the executor has an HTTP function.

        Safety rules built in:
          - Only fields listed in Disclosure.WEBHOOK_FIELDS can be sent (others are dropped + logged).
          - Webhook URLs are secrets: they are never printed or written to the log.
          - allowed_mentions is always set, so text can never trigger @everyone/@here pings;
            only the user id YOU configure can be pinged, only for the events YOU choose.
          - One message in flight per webhook, spaced by MinSecondsBetweenMessages; HTTP 429 is respected.
          - Webhook problems are logged under category "Notifier" and can never stop the farm.
    ]]

    local import = ...
    local Enums = import("Core/Enums")
    local Util = import("Core/Util")
    local Disclosure = import("Services/Disclosure")

    local Players = game:GetService("Players")

    local Notifier = {}
    Notifier.__index = Notifier

    -- route: which webhook; toggle: config switch; ping: key in Notifications.PingOn
    local EVENT_STYLE = {
        SessionStarted = { title = "Session started", color = 0x3BA55D, route = "Summary", toggle = "SendOnStartStop" },
        SessionStopped = { title = "Session stopped", color = 0x747F8D, route = "Summary", toggle = "SendOnStartStop", ping = "SessionStopped" },
        Summary = { title = "Farm summary", color = 0x5865F2, route = "Summary", ping = "Summary" },
        TaskCompleted = { title = "Need completed", color = 0x57F287, route = "Summary", toggle = "SendOnTaskComplete", ping = "TaskCompleted" },
        Error = { title = "Error", color = 0xED4245, route = "Alerts", toggle = "SendOnError", ping = "Error", cooldown = true },
        Kicked = { title = "Disconnected / kicked", color = 0xED4245, route = "Alerts", toggle = "SendOnKick", ping = "Kick" },
        PreviousSessionEnded = { title = "Previous run ended without Stop()", color = 0xE67E22, route = "Alerts", toggle = "SendOnKick", ping = "PreviousSession" },
        Test = { title = "Webhook test", color = 0xFEE75C, route = "Summary" },
    }

    local FIELD_VALUE_LIMIT = 1000
    local DESCRIPTION_LIMIT = 3500

    function Notifier.new(notificationsConfig, logger, scriptName, version)
        local self = setmetatable({}, Notifier)
        self._config = notificationsConfig
        self._logger = logger
        self._scriptName = scriptName
        self._version = version
        self._requestFunction = Util.getRequestFunction()
        self._queues = {} -- [routeName] = queue
        self._lastAlertAt = -math.huge
        self._suppressedAlerts = 0
        self.SentCount = 0
        self.DroppedCount = 0

        local webhooks = notificationsConfig.Webhooks
        local hasAnyUrl = webhooks.Summary ~= "" or webhooks.Alerts ~= ""
        if not notificationsConfig.Enabled then
            self._disabledReason = "Notifications.Enabled = false"
        elseif not hasAnyUrl then
            self._disabledReason = "no webhook URL set"
        elseif not self._requestFunction then
            self._disabledReason = "executor has no HTTP request function"
        end
        self._enabled = self._disabledReason == nil
        return self
    end

    function Notifier:isEnabled()
        return self._enabled
    end

    -- Human-readable status for the disclosure. Never includes the URLs themselves.
    function Notifier:getStatusText()
        if not self._enabled then
            return "Discord webhooks: OFF (" .. self._disabledReason .. "). Nothing is sent over the network."
        end
        local webhooks = self._config.Webhooks
        local parts = {}
        if webhooks.Summary ~= "" then
            table.insert(parts, "Summary")
        end
        if webhooks.Alerts ~= "" then
            table.insert(parts, "Alerts")
        end
        return "Discord webhooks: ON (" .. table.concat(parts, " + ")
            .. " webhook set by you). Messages go ONLY to discord.com webhook URLs from your config."
    end

    -- Picks the URL for a route, falling back to the other webhook when one is empty.
    function Notifier:_resolveRoute(route)
        local webhooks = self._config.Webhooks
        if webhooks[route] ~= "" then
            return route, webhooks[route]
        end
        local other = route == "Alerts" and "Summary" or "Alerts"
        if webhooks[other] ~= "" then
            return other, webhooks[other]
        end
        return nil, nil
    end

    function Notifier:_getQueue(routeName, url)
        local queue = self._queues[routeName]
        if not queue then
            queue = { name = routeName, url = url, items = {}, inFlight = false, nextAllowed = 0, disabled = false }
            self._queues[routeName] = queue
        end
        return queue
    end

    local function buildFields(self, fields)
        local result = {}
        if self._config.IncludeUsername then
            local player = Players.LocalPlayer
            table.insert(result, { name = "Player", value = player and player.Name or "?", inline = true })
        end
        for _, field in ipairs(fields or {}) do
            if Disclosure.isAllowedField(field.name) then
                table.insert(result, {
                    name = field.name,
                    value = Util.truncate(field.value, FIELD_VALUE_LIMIT),
                    inline = field.inline == true,
                })
            else
                self._logger:warn("Notifier", "Blocked a field that is not in the disclosure list: " .. tostring(field.name))
            end
        end
        table.insert(result, { name = "Version", value = self._version, inline = true })
        return result
    end

    --[[
        notify(eventName, fields, description)
          eventName   : one of Enums.NotifyEvent
          fields      : { { name = "<allowed field>", value = "...", inline = bool }, ... }
          description : optional short text (written by this script, never raw user input)
        Returns true when queued.
    ]]
    function Notifier:notify(eventName, fields, description)
        local style = EVENT_STYLE[Enums.NotifyEvent[eventName]] -- strict: unknown event names throw
        if not self._enabled then
            return false
        end
        if style.toggle and not self._config[style.toggle] then
            return false
        end
        if style.cooldown then
            local now = Util.now()
            if now - self._lastAlertAt < self._config.AlertCooldownSeconds then
                self._suppressedAlerts += 1
                return false
            end
            self._lastAlertAt = now
            if self._suppressedAlerts > 0 then
                description = (description and (description .. "\n") or "")
                    .. string.format("(%d more alerts were suppressed by the cooldown)", self._suppressedAlerts)
                self._suppressedAlerts = 0
            end
        end

        local routeName, url = self:_resolveRoute(style.route)
        if not url then
            return false
        end
        local queue = self:_getQueue(routeName, url)
        if queue.disabled then
            return false
        end

        local pingId = self._config.PingDiscordUserId
        local shouldPing = pingId ~= "" and style.ping ~= nil and self._config.PingOn[style.ping] == true

        local embed = {
            title = style.title,
            description = description and Util.truncate(description, DESCRIPTION_LIMIT) or nil,
            color = style.color,
            fields = buildFields(self, fields),
            footer = { text = self._scriptName },
        }
        pcall(function()
            embed.timestamp = DateTime.now():ToIsoDate()
        end)

        local payload = {
            username = self._scriptName,
            embeds = { embed },
            -- Never let message text ping anyone; only the configured user id may be mentioned.
            allowed_mentions = shouldPing and { users = { pingId } } or { parse = {} },
        }
        if shouldPing then
            payload.content = "<@" .. pingId .. ">"
        end

        local body, encodeError = Util.jsonEncode(payload)
        if not body then
            self._logger:error("Notifier", "Could not encode message: " .. tostring(encodeError))
            return false
        end

        if #queue.items >= self._config.MaxQueueSize then
            table.remove(queue.items, 1)
            self.DroppedCount += 1
            self._logger:warn("Notifier", queue.name .. " queue full; dropped the oldest message")
        end
        table.insert(queue.items, { body = body, event = eventName, attempts = 0 })
        return true
    end

    function Notifier:_send(queue)
        local item = queue.items[1]
        if not item then
            queue.inFlight = false
            return
        end
        local ok, response = pcall(self._requestFunction, {
            Url = queue.url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = item.body,
        })
        local status = ok and type(response) == "table" and tonumber(response.StatusCode) or nil
        local now = Util.now()

        if status and status >= 200 and status < 300 then
            table.remove(queue.items, 1)
            self.SentCount += 1
            queue.nextAllowed = now + self._config.MinSecondsBetweenMessages
            self._logger:debug("Notifier", "Sent " .. item.event .. " to " .. queue.name .. " webhook")
        elseif status == 429 then
            local retryAfter = 5
            local decoded = type(response.Body) == "string" and Util.jsonDecode(response.Body)
            if type(decoded) == "table" and tonumber(decoded.retry_after) then
                retryAfter = tonumber(decoded.retry_after)
            end
            queue.nextAllowed = now + retryAfter + 0.5
            self._logger:warn("Notifier", string.format("Discord rate limit on %s webhook; waiting %.1f s", queue.name, retryAfter))
        elseif status == 401 or status == 403 or status == 404 then
            queue.disabled = true
            self.DroppedCount += #queue.items
            table.clear(queue.items)
            self._logger:error("Notifier", string.format("%s webhook rejected (HTTP %d). Check the URL. This webhook is now off.", queue.name, status))
        elseif status == 400 then
            table.remove(queue.items, 1)
            self.DroppedCount += 1
            self._logger:error("Notifier", "Discord refused a " .. item.event .. " message (HTTP 400): "
                .. Util.truncate(tostring(response.Body), 200))
        else
            item.attempts += 1
            local reason = ok and ("HTTP " .. tostring(status)) or tostring(response)
            if item.attempts > self._config.MaxRetries then
                table.remove(queue.items, 1)
                self.DroppedCount += 1
                self._logger:error("Notifier", "Gave up sending " .. item.event .. " after retries: " .. Util.truncate(reason, 200))
            else
                queue.nextAllowed = now + (2 ^ item.attempts)
                self._logger:warn("Notifier", "Send failed (" .. Util.truncate(reason, 120) .. "); retry " .. item.attempts)
            end
        end
        queue.inFlight = false
    end

    -- Called by the scheduler. Starts at most one send per webhook; never blocks the scheduler.
    function Notifier:pump()
        if not self._enabled then
            return
        end
        local now = Util.now()
        for _, queue in pairs(self._queues) do
            if not queue.inFlight and not queue.disabled and #queue.items > 0 and now >= queue.nextAllowed then
                queue.inFlight = true
                task.spawn(function()
                    local ok, err = pcall(self._send, self, queue)
                    if not ok then
                        queue.inFlight = false
                        self._logger:error("Notifier", "Internal send error: " .. tostring(err))
                    end
                end)
            end
        end
    end

    function Notifier:pendingCount()
        local count = 0
        for _, queue in pairs(self._queues) do
            if not queue.disabled then
                count += #queue.items
            end
        end
        return count
    end

    -- Keeps pumping until everything is sent or the timeout passes. Must be called from a thread.
    function Notifier:flush(timeoutSeconds)
        local deadline = Util.now() + timeoutSeconds
        while self:pendingCount() > 0 and Util.now() < deadline do
            self:pump()
            task.wait(0.25)
        end
        return self:pendingCount() == 0
    end

    return Notifier
end

-- ─────────────────────────────── module: Services/SessionWatcher ───────────────────────────────
__moduleSources["Services/SessionWatcher"] = function(...)
    --[[
        Services/SessionWatcher
        Detects when Roblox shows a disconnect/kick message and reports it (log + optional webhook ping).

        Uses the standard Roblox API GuiService.ErrorMessageChanged / GuiService:GetErrorMessage().
        UNVERIFIED LIVE: whether the executor keeps running long enough after a kick to send the
        webhook has not been tested yet. The message is also written to the log file immediately.
    ]]

    local import = ...
    local Enums = import("Core/Enums")

    local GuiService = game:GetService("GuiService")

    local SessionWatcher = {}

    function SessionWatcher.start(maid, logger, notifier, state, sessionStore)
        local okSignal, errorSignal = pcall(function()
            return GuiService.ErrorMessageChanged
        end)
        if not okSignal or errorSignal == nil then
            logger:warn("Session", "GuiService.ErrorMessageChanged unavailable; kick detection is off")
            return false
        end

        local lastReported = nil
        maid:Give(errorSignal:Connect(function(messageArgument)
            local message = type(messageArgument) == "string" and messageArgument or ""
            if message == "" then
                pcall(function()
                    message = GuiService:GetErrorMessage()
                end)
            end
            if type(message) ~= "string" or message == "" or message == lastReported then
                return
            end
            lastReported = message
            state:set("session.disconnectReason", message, "SessionWatcher")
            if sessionStore then
                sessionStore:recordMessage(message) -- survives even if the executor stops right after
            end
            -- WARN (not ERROR) so the error bridge does not send a second, duplicate alert
            logger:warn("Session", "Roblox disconnect/kick message: " .. message)
            logger:flush()
            notifier:notify(Enums.NotifyEvent.Kicked, { { name = "Reason", value = message } })
            notifier:pump()
        end))
        logger:debug("Session", "Kick detection active")
        return true
    end

    return SessionWatcher
end

-- ─────────────────────────────── module: Services/SessionStore ───────────────────────────────
__moduleSources["Services/SessionStore"] = function(...)
    --[[
        Services/SessionStore
        Keeps a tiny status file so the NEXT run can report how the previous run ended.
        Why: after a disconnect the executor may stop almost immediately (confirmed live 2026-09-27:
        the disconnect was detected and logged, but no webhook could be sent afterwards).

        File: AdoptMeFarm/session_state_<player>.json
          { version, startedAt, lastSeen, cleanStop, lastMessage }   (times are os.time() seconds)
        Nothing else is stored.

        Note (confirmed live): closing Roblox yourself ALSO produces "Lost connection to the game server",
        so "ended without Stop()" does not always mean a kick.
    ]]

    local import = ...
    local Util = import("Core/Util")

    local SessionStore = {}
    SessionStore.__index = SessionStore

    SessionStore.FOLDER = "AdoptMeFarm"
    -- One file per account: several accounts may run in the same executor (same workspace folder).
    SessionStore.PATH = (function()
        local ok, name = pcall(function()
            return game:GetService("Players").LocalPlayer.Name
        end)
        local who = (ok and type(name) == "string") and string.gsub(name, "[^%w_]", "") or ""
        return who ~= "" and ("AdoptMeFarm/session_state_" .. who .. ".json") or "AdoptMeFarm/session_state.json"
    end)()

    function SessionStore.new(logger, version, enabled)
        local self = setmetatable({}, SessionStore)
        self._logger = logger
        self._version = version
        self._record = nil
        self._available = enabled ~= false and type(writefile) == "function" and type(readfile) == "function"
            and type(isfile) == "function"
        return self
    end

    function SessionStore:isAvailable()
        return self._available
    end

    function SessionStore:_write()
        if not self._available or not self._record then
            return
        end
        local text = Util.jsonEncode(self._record)
        if not text then
            return
        end
        local ok, err = pcall(writefile, SessionStore.PATH, text)
        if not ok then
            self._available = false
            self._logger:warn("SessionStore", "Could not write session file; delayed reports disabled: " .. tostring(err))
        end
    end

    -- Reads the previous record and starts a new one.
    -- Returns the previous record ONLY if that run ended without Stop(); otherwise nil.
    function SessionStore:begin()
        if not self._available then
            self._logger:debug("SessionStore", "readfile/isfile/writefile missing; delayed reports disabled")
            return nil
        end
        Util.ensureFolder(SessionStore.FOLDER)

        local previous = nil
        local okRead, text = pcall(function()
            if isfile(SessionStore.PATH) then
                return readfile(SessionStore.PATH)
            end
            return nil
        end)
        if okRead and type(text) == "string" and text ~= "" then
            local decoded = Util.jsonDecode(text)
            if type(decoded) == "table" and decoded.cleanStop == false then
                previous = decoded
            elseif decoded == nil then
                self._logger:warn("SessionStore", "Session file was unreadable; starting a new one")
            end
        end

        local now = os.time()
        self._record = { version = self._version, startedAt = now, lastSeen = now, cleanStop = false, lastMessage = "" }
        self:_write()
        return previous
    end

    function SessionStore:heartbeat()
        if self._record then
            self._record.lastSeen = os.time()
            self:_write()
        end
    end

    function SessionStore:recordMessage(message)
        if self._record then
            self._record.lastSeen = os.time()
            self._record.lastMessage = tostring(message)
            self:_write()
        end
    end

    function SessionStore:markCleanStop()
        if self._record then
            self._record.lastSeen = os.time()
            self._record.cleanStop = true
            self:_write()
        end
    end

    -- One line describing how a previous run ended, for the log and the webhook.
    function SessionStore.describe(previous)
        local function when(seconds)
            return tonumber(seconds) and os.date("%Y-%m-%d %H:%M", tonumber(seconds)) or "?"
        end
        local message = (type(previous.lastMessage) == "string" and previous.lastMessage ~= "") and previous.lastMessage
            or "no Roblox message was recorded"
        return string.format("Previous run (started %s) ended without Stop() around %s. Last Roblox message: %s",
            when(previous.startedAt), when(previous.lastSeen), message)
    end

    return SessionStore
end

-- ─────────────────────────────── module: Services/Telemetry ───────────────────────────────
__moduleSources["Services/Telemetry"] = function(...)
    --[[
        Services/Telemetry
        Sends the developer what he needs to fix bugs, ONLY to the relay URL in the config (a Cloudflare Worker that
        forwards to the developer's Discord; the Discord webhook itself is never in this file):
          - your Roblox name and user id, this script's version, a session id
          - every Telemetry.SummaryMinutes one report: a session summary (minutes, needs done, Bucks / candy earned,
            Ghost Gallery rounds, Rusty Keys, quests, potions, gifts) + this script's WARN / ERROR lines as a file
          - one "started" message per run (the developer's server shows an execution counter)
        Other players' names are replaced with "<player>" before sending. Nothing else is read or sent.
        Off with: Telemetry = { Enabled = false } in the settings. Shown in the start report.
    ]]

    local import = ...
    local Util = import("Core/Util")
    local Enums = import("Core/Enums")

    local Telemetry = {}
    Telemetry.__index = Telemetry

    -- Only relay endpoints on Cloudflare Workers (the developer's relay); anything else is refused.
    local URL_PATTERN = "^https://[%w%-]+%.[%w%-]+%.workers%.dev/[%w%-/]*$"
    local MAX_QUEUE = 250 -- WARN / ERROR lines kept for one report
    local MAX_TEXT = 200

    function Telemetry.isAllowedUrl(url)
        return type(url) == "string" and string.match(url, URL_PATTERN) ~= nil
    end

    function Telemetry.new(config, logger, version, state)
        local self = setmetatable({}, Telemetry)
        self._config = config or {}
        self._logger = logger
        self._version = version
        self._state = state
        self._lines = {}
        self._counts = {}
        self._dropped = 0
        self._failures = 0
        self._nextSend = 0
        self._nextSummary = Util.now() + (tonumber(self._config.SummaryMinutes) or 30) * 60
        self._session = string.format("%x%x", os.time() % 0xFFFFFF, math.random(0, 0xFFFF))
        self._startPending = true -- the first send says "started" (execution counter)
        self._request = Util.getRequestFunction()
        if not self._config.Enabled then
            self._off = "turned off in the settings (Telemetry.Enabled = false)"
        elseif not Telemetry.isAllowedUrl(self._config.Url) then
            self._off = "no relay URL set"
        elseif not self._request then
            self._off = "executor has no HTTP request function"
        end
        return self
    end

    function Telemetry:isEnabled()
        return self._off == nil
    end

    function Telemetry:statusText()
        if self._off then
            return "OFF (" .. self._off .. ")"
        end
        return "ON: your Roblox name + a session summary (needs, Bucks, candy, rounds) + this script's warnings / errors every "
            .. tostring(self._config.SummaryMinutes or 30) .. " min (and that this run started) go to " .. tostring(self._config.Owner or "the developer")
            .. " via " .. self._config.Url .. " to fix bugs. Turn off: Telemetry = { Enabled = false }"
    end

    -- Other players' names out of the text (e.g. "visited Bob's house").
    local function scrub(text)
        text = Util.truncate(tostring(text), MAX_TEXT)
        local ok, players = pcall(function()
            return game:GetService("Players"):GetPlayers()
        end)
        local me = game:GetService("Players").LocalPlayer
        for _, player in ipairs(ok and players or {}) do
            if player ~= me and type(player.Name) == "string" and #player.Name >= 3 then
                text = string.gsub(text, (string.gsub(player.Name, "%p", "%%%0")), "<player>")
            end
        end
        return text
    end

    -- Counted from this script's own log lines (no extra game reads): what the session achieved.
    local COUNTERS = {
        { key = "rounds", pattern = "^Ghost Gallery: %d+ points" },
        { key = "keys", pattern = "Rusty Key EARNED" },
        { key = "quests", pattern = "^Quests: .* claimed" },
        { key = "potions", pattern = "^Age potion:" },
        { key = "gifts", pattern = "^Opened " },
        { key = "houseVisits", pattern = "^Quest %a+: visited" },
    }

    function Telemetry:setGameData(gameData)
        self._gameData = gameData
        local candy = gameData and tonumber(gameData:get("candy_2026"))
        self._candyStart = self._candyStart or candy
    end

    function Telemetry:start(maid)
        if not self:isEnabled() then
            return
        end
        self._lines = {}
        self._counts = {}
        maid:Give(self._logger.OnEntry:Connect(function(level, category, message)
            if category == "Telemetry" or category == "Disclosure" then
                return
            end
            message = tostring(message)
            for _, counter in ipairs(COUNTERS) do
                if string.find(message, counter.pattern) then
                    self._counts[counter.key] = (self._counts[counter.key] or 0) + 1
                end
            end
            -- User 2026-10-05: only the script's WARN / ERROR lines, sent as a file with the 30-min report.
            if level == Enums.LogLevel.WARN or level == Enums.LogLevel.ERROR then
                if #self._lines >= MAX_QUEUE then
                    table.remove(self._lines, 1)
                    self._dropped += 1
                end
                table.insert(self._lines, string.format("%s [%s] %s: %s", os.date("%H:%M:%S"), level, category, scrub(message)))
            end
        end))
    end

    function Telemetry:_summary()
        local counts = self._logger.Counts or {}
        local data = self._gameData
        local candyNow = data and tonumber(data:get("candy_2026"))
        if candyNow and not self._candyStart then
            self._candyStart = candyNow
        end
        return {
            minutes = math.floor((Util.now() - (self._state:get("session.startedAt") or Util.now())) / 60),
            needs = self._state:get("stats.needsCompleted") or 0,
            bucks = self._state:get("stats.bucksEarned") or 0,
            bucksNow = data and tonumber(data:get("money")) or nil,
            candy = (candyNow and self._candyStart) and (candyNow - self._candyStart) or nil,
            candyNow = candyNow,
            rounds = self._counts.rounds or 0,
            keys = self._counts.keys or 0,
            quests = self._counts.quests or 0,
            potions = self._counts.potions or 0,
            gifts = self._counts.gifts or 0,
            houseVisits = self._counts.houseVisits or 0,
            warnings = counts.WARN or 0,
            errors = counts.ERROR or 0,
        }
    end

    function Telemetry:_payload(report)
        local me = game:GetService("Players").LocalPlayer
        local payload = {
            v = self._version,
            user = me and me.Name or "?",
            userId = me and me.UserId or 0,
            session = self._session,
            start = self._startPending or nil,
        }
        self._startPending = false
        if report then
            payload.report = true
            payload.summary = self:_summary()
            payload.lines = self._lines
            payload.dropped = self._dropped
            self._lines = {}
            self._dropped = 0
        end
        return payload
    end

    -- Called by the scheduler: the start ping once, then one report every Telemetry.SummaryMinutes. Never blocks.
    function Telemetry:pump(force)
        if not self:isEnabled() or self._inFlight then
            return
        end
        -- Live 1.2 report: "Candy +0" in the first report: my data was not loaded yet when the session started, so the
        -- start value was taken 30 min later. Take it as soon as the data has it.
        if not self._candyStart and self._gameData then
            self._candyStart = tonumber(self._gameData:get("candy_2026"))
        end
        local now = Util.now()
        local reportDue = force or now >= self._nextSummary
        if not reportDue and not self._startPending then
            return
        end
        if reportDue then
            self._nextSummary = now + (tonumber(self._config.SummaryMinutes) or 30) * 60
        end
        local body = Util.jsonEncode(self:_payload(reportDue))
        if not body then
            return
        end
        self._inFlight = true
        task.spawn(function()
            local ok, response = pcall(self._request, {
                Url = self._config.Url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body,
            })
            local status = ok and type(response) == "table" and tonumber(response.StatusCode) or nil
            if status and status >= 200 and status < 300 then
                self._failures = 0
            elseif status == 429 then
                self._nextSummary = math.min(self._nextSummary, Util.now() + 120) -- the relay is busy: try again soon
            else
                self._failures += 1
                if self._failures >= 3 then
                    self._off = "the relay did not answer 3 times"
                    self._logger:warn("Telemetry", "Developer logs turned off for this session: " .. self._off)
                end
            end
            self._inFlight = false
        end)
    end

    return Telemetry
end

-- ─────────────────────────────── module: Game/GameConstants ───────────────────────────────
__moduleSources["Game/GameConstants"] = function(...)
    --[[
        Game/GameConstants
        EVERY Adopt Me specific name used by this script lives here, and nowhere else.
        If the game updates and something breaks, this is the only file to fix.
        Each entry cites the discovery file where it was observed (see 11_GAME_FINDINGS.md).
    ]]

    local GameConstants = {}

    -- snapshot_20260927_002422 (game.PlaceId)
    GameConstants.PlaceId = 920587237

    -- snapshot_20260927_002422: ReplicatedStorage.API holds remotes named "Service/Method"
    GameConstants.Remotes = {
        Folder = "API",
        -- server -> client, args (playerName, key, value, timestamp); broadcast for ALL players (watch2)
        DataChanged = "DataAPI/DataChanged",
        -- server -> client, args (playerName, { {replicated_key_path, serialized_partial_value, set_timestamp}, ... }) (watch2)
        DataPartiallyChanged = "DataAPI/DataPartiallyChanged",
        -- server -> client, args (petUnique, kind, { bucks, xp }) (watch2, watch4)
        PetAilmentCompleted = "AilmentsAPI/PetAilmentCompleted",
        -- server -> client, args (player, kind, { bucks }) (watch2, watch4)
        BabyAilmentCompleted = "AilmentsAPI/BabyAilmentCompleted",
        -- server -> client, args (gameId, messageName, ...) (halloween11 + halloween12: join_accepted, join_minigame,
        -- enter_game {intermission_end_time, end_time, ...}, ghost_clusters_score (points), leave_game {results, rewards})
        MinigameMessage = "MinigameAPI/MessageClient",
        -- Halloween 2026 remotes live in a second folder, named "Halloween2026/<Method>" (halloween11 RS scan)
        EventFolder = "adoptme_new_net",
    }

    -- Keys of my data that this script keeps a copy of (watch2, watch4). Everything else is ignored.
    GameConstants.DataKeys = {
        Ailments = "ailments_manager", -- { ailments = {[petUnique] = {[kind] = entry}}, baby_ailments = {[kind] = entry} }
        Money = "money", -- number
        Equip = "equip_manager", -- { pets = { {unique, kind, properties = {age, xp, ...}} }, food = {}, ... }
        Team = "team", -- "Parents" | "Babies"
        Interior = "house_interior", -- CURRENT interior: { interior_name, furniture = {[key] = {id, cframe, occupied}} }
        PetWrappers = "pet_char_wrappers_raw", -- {[StreamingId] = {char, pet_unique, pet_id, pet_progression, location}}
        Inventory = "inventory", -- { food = {[unique] = {id, kind, unique, properties = {uses_left}}}, toys = {...}, pets = {...}, ... } (watch7)
        -- { is_sitting = true|false, states = { {id = "UseFurniture", furniture_id = "basiccrib"} } } (watch7_20260927_231531)
        StateManager = "state_manager_raw",
        -- halloween11/12 (2026-10-04), all CONFIRMED in my data:
        CharWrapper = "char_wrapper_raw", -- { location = { destination_id, full_destination_id } }
        Candy = "candy_2026", -- event currency (number); every need pays +200 now
        PetPen = "idle_progression_manager", -- { active_pets = {[unique] = {placed_timestamp, xp_timestamp, max_age, ...}} }
        StrayCat = "halloween_2026_stray_cat_manager", -- { total_gifts, fed_today, last_fed_cycle }
        Crypt = "halloween_2026_crypt_manager", -- { seed, opened = {ids}, floors = {[f] = {coffins = {[i] = reward}}} }
        PigeonNest = "halloween_2026_jacobean_pigeon_nest_manager", -- { twigs_contributed }
        GhostCycle = "ghost_clusters_cycle_timestamp", -- { timestamp = next round start (unix), identifier }
        -- { serialized_tabs = { [tab] = { active_dailies = {[kind] = {state = {steps_to_complete, steps_completed}}},
        --   rewards = {...}, reward_claimed, total_dailies_completed_today } } } (halloween12)
        Dailies = "dailies_manager",
    }

    -- Ailment entry fields (watch2): ailment_key, kind, components, created_timestamp, progress, rate, rate_timestamp
    -- rate = 0 while waiting; rate > 0 while being fulfilled (watch2, watch4)

    -- workspace.Pets holds ALL nearby players' pets (remotes_20260927_004819); a pet model's
    -- "StreamingId" attribute equals the `char` of my pet wrapper (snapshot + watch2)
    GameConstants.PetsFolderName = "Pets"
    GameConstants.PetModelIdAttribute = "StreamingId"

    -- modules_20260927_004819 / probe4: loaded module with get_data/get/register_callback...
    GameConstants.ClientDataModulePath = { "ClientModules", "Core", "ClientData" }

    --[[ ACTIONS — the ONLY remotes this script may send (enforced by Game/Interaction).
         Each was observed working in watch4_20260927_011225 (sent by a hub, effect confirmed by the game's data)
         or remotes_20260927_004819 (sent by the game itself). The disclosure lists exactly this table. ]]
    GameConstants.Actions = {
        ChooseTeam = { remote = "TeamAPI/ChooseTeam", purpose = "switch your team to Babies (Farm.BabyMode)" },
        FocusPet = { remote = "AdoptAPI/FocusPet", purpose = "pet_me: focus your pet" },
        PetPetted = { remote = "PetAPI/PetPetted", purpose = "pet_me: pet your pet" },
        ProgressPetMe = { remote = "AilmentsAPI/ProgressPetMeAilment", purpose = "pet_me: report the petting" },
        UnfocusPet = { remote = "AdoptAPI/UnfocusPet", purpose = "pet_me: unfocus your pet" },
        DoorEnter = { remote = "AdoptAPI/SendPassiveDoorEnter", purpose = "travel: enter a place (house, salon, cat cafe, main map)" },
        SetLocation = { remote = "LocationAPI/SetLocation", purpose = "travel: move to that place" },
        SubscribeToHouse = { remote = "HousingAPI/SubscribeToHouse", purpose = "travel: load YOUR house when going home" },
        -- watch7 (game) + watch8 (hub): DoorEnter away from home -> UnsubscribeFromHouse(me) -> SetLocation
        UnsubscribeFromHouse = { remote = "HousingAPI/UnsubscribeFromHouse", purpose = "travel: unload YOUR house when leaving it" },
        -- User capture (SimpleSpy, 2026-09-29): the game's own calls when walking out of the house door, in this order:
        -- SendPassiveDoorEnter("exit_housing", "MainDoor", {skip_set_player_collisions = true,
        -- skip_send_passive_door_request = true, house_owner = me, camera_rootpart_cframe_offset = CFrame,
        -- exiting_door = workspace.HouseInteriors.blueprint.<me>.Doors.MainDoor}) -> MarkEnteredDoorTime() ->
        -- PushFurnitureChanges({}) -> PetAPI/ExitFurnitureUseStates() -> UnsubscribeFromHouse(me).
        MarkEnteredDoorTime = { remote = "AdoptAPI/MarkEnteredDoorTime", purpose = "leaving your house: the game's own door-time mark (no arguments)" },
        PushFurnitureChanges = { remote = "HousingAPI/PushFurnitureChanges", purpose = "leaving your house: sent EMPTY ({}) as the game does; never changes furniture", emptyOnly = true },
        -- user's SimpleSpy capture 2026-09-28, no arguments; effect checked by my Bucks
        CollectCashback = { remote = "PayAPI/Collect", purpose = "collect your cashback Bucks (Farm.CollectCashback)" },
        -- user's SimpleSpy capture 2026-09-28: (petUnique, "mystery", 1, "cat_cafe")
        ChooseMystery = { remote = "AilmentsAPI/ChooseMysteryAilment", purpose = "mystery: pick a need this script can do" },
        -- Live 0.8.0: the server answers only when the use ENDS (bed 15 s) -> do not wait; my data verifies the start.
        ActivateFurniture = { remote = "HousingAPI/ActivateFurniture", purpose = "use YOUR bed / shower / toilet for your pet or baby",
            answersWhenDone = true },
        -- watch7_20260927_231531 (all sent by the GAME itself):
        ExitSeatStates = { remote = "AdoptAPI/ExitSeatStates", purpose = "get your character (baby) up from furniture" },
        ExitFurnitureUseStates = { remote = "PetAPI/ExitFurnitureUseStates", purpose = "get your pet up if it stays on furniture" },
        EquipItem = { remote = "ToolAPI/Equip", purpose = "hold YOUR food, drink, toy, Rusty Key, Crypt Twig or the loaned Ghost Vacuum; re-equip YOUR pet ({equip_as_last=true}, as the game at spawn)" },
        -- User (2026-09-28): the Roblox-menu respawn fixed the white screen and started at home; the call is
        -- TeamAPI/Spawn (InvokeServer, no arguments given).
        Respawn = { remote = "TeamAPI/Spawn", purpose = "go home fast by respawning (Farm.HomeByRespawn); recover when stuck on the loading screen" },
        UseTool = { remote = "ToolAPI/ServerUseTool", purpose = "eat / drink / throw the item you hold; switch on the Ghost Vacuum (its answer is the vacuum token)" },
        UnequipItem = { remote = "ToolAPI/Unequip", purpose = "put the item away" },
        -- watch8_20260928_053142 (the game, stroller ride): Equip(stroller, {chars_to_sit = {pet wrapper}}) ...
        -- ServerUseTool START/END while walking -> UnequipStroller() + Unequip(stroller, nil)
        -- watch8_20260928_073936 (the game, user talked to the hospital doctor): ("f-14" = id "doctor", "UseBlock", "Yes", <character>)
        ActivateInteriorFurniture = { remote = "HousingAPI/ActivateInteriorFurniture", purpose = "sick: talk to the doctor in the Hospital" },
        UnequipStroller = { remote = "AdoptAPI/UnequipStroller", purpose = "ride: put the stroller away" },
        CreatePetObject = { remote = "PetObjectAPI/CreatePetObject", purpose = "give food/drink to your pet, throw a toy for it" },
        ConsumeFoodObject = { remote = "PetAPI/ConsumeFoodObject", purpose = "your pet eats the given food (only if the game did not)" },
        GrabPetObject = { remote = "PetObjectAPI/GrabPetObject", purpose = "your pet catches the toy (only if the game did not)" },
        DropPetObject = { remote = "PetObjectAPI/DropPetObject", purpose = "your pet gives the toy back" },
        -- halloween11 (the game, user claimed the Pet Pen by hand): AddPet(unique), RemovePet(unique),
        -- CommitAllProgression(true) = "CLAIM ALL" (+xp for each pen pet, +Bucks hint)
        PetPenAdd = { remote = "IdleProgressionAPI/AddPet", purpose = "Pet Pen: put one of YOUR growing pets in the pen (Farm.Event.PetPen)" },
        PetPenRemove = { remote = "IdleProgressionAPI/RemovePet", purpose = "Pet Pen: take a FULL GROWN pet out of the pen" },
        PetPenClaim = { remote = "IdleProgressionAPI/CommitAllProgression", purpose = "Pet Pen: CLAIM ALL (the pen's xp and Bucks)" },
        -- halloween11 (manual pet_me, the game): ReplicateActivePerformances(pet, {FocusPet, Petting}) -> {FocusPet,
        -- PettingHappy} -> PetPetted + ProgressPetMeAilment -> completed. Our calls without these never completed (7o).
        PetPerformance = { remote = "PetAPI/ReplicateActivePerformances", purpose = "pet_me: show the petting animation, as the game does" },
        -- halloween12: StrayCatGiftFood({unique}) while holding food -> {ok=true, amount=50 candy}; once a day
        StrayCatFeed = { remote = "Halloween2026/StrayCatGiftFood", folder = "EventFolder", purpose = "Halloween: give 1 water to the Stray Cat once a day (Farm.Event.StrayCat)" },
        -- halloween11: Equip(rusty key) -> UnlockPadlock({padlock_index, floor_index}) -> crypt_manager.opened grew
        UnlockPadlock = { remote = "Halloween2026/UnlockPadlock", folder = "EventFolder", purpose = "Halloween: use YOUR Rusty Key on a Crypt grave (Farm.Event.Crypt)" },
        -- halloween12 typechecker: JacobeanPigeonNestContributeTwig({unique: string}); call itself not seen yet
        PigeonNestTwig = { remote = "Halloween2026/JacobeanPigeonNestContributeTwig", folder = "EventFolder", purpose = "Halloween: put YOUR Crypt Twig in the Hotel nest (Farm.Event.PigeonNest)" },
        -- halloween11/12: AttemptJoin("ghost_clusters", true, nil) -> join_accepted -> join_minigame(interior, gameId)
        MinigameJoin = { remote = "MinigameAPI/AttemptJoin", purpose = "Halloween: join the Ghost Gallery minigame (Farm.Event.GhostGallery)" },
        -- halloween11/12: MessageServer(gameId, "start_contribute" | "stop_contribute", {use_token, ghost_id})
        -- halloween12: also "start_prop_contribute" | "stop_prop_contribute", {use_token, unique = "f-NN"} (haunted furniture)
        MinigameMessage = { remote = "MinigameAPI/MessageServer", purpose = "Ghost Gallery: vacuum a ghost or a haunted prop (start / stop only)",
            allowedMessages = { start_contribute = true, stop_contribute = true, start_prop_contribute = true, stop_prop_contribute = true } },
        -- User's SimpleSpy capture (2026-10-04, quests claimed by hand): FireServer("halloween_2026") on both;
        -- halloween11: the game sent :9("vanilla") twice, +25 Bucks each.
        QuestClaim = { remote = "adoptme_new.modules.Dailies.DailiesNetService:9", folder = "EventFolder",
            purpose = "claim a finished daily quest (Halloween / normal tab) (Farm.Event.Quests)",
            allowedFirstArg = { halloween_2026 = true, vanilla = true } },
        -- halloween12 2026-10-04 (user, by hand): :15("vanilla") when the board showed 3 done today -> Fairytale Egg
        QuestTabReward = { remote = "adoptme_new.modules.Dailies.DailiesNetService:15", folder = "EventFolder",
            purpose = "claim a quest board reward after 3 quests of the day (Rusty Key / egg) (Farm.Event.Quests)",
            allowedFirstArg = { halloween_2026 = true, vanilla = true } },
        -- halloween12 2026-10-04 (the game): gifts: Equip -> ServerUseTool START -> ShopAPI/OpenGift(unique) -> END;
        -- chests: Equip -> START -> Unequip -> END -> LootBoxAPI/ExchangeItemForReward(id, unique)
        OpenGift = { remote = "ShopAPI/OpenGift", purpose = "open YOUR gift (Farm.AutoOpen)" },
        OpenChest = { remote = "LootBoxAPI/ExchangeItemForReward", purpose = "open YOUR chest (Farm.AutoOpen)" },
        -- User's SimpleSpy capture (2026-10-04): InvokeServer() with no arguments, after the last Crypt floor
        ClaimTombSpider = { remote = "Halloween2026/ClaimTombSpider", folder = "EventFolder",
            purpose = "Halloween: take the Mummy Spider at the bottom of the Crypt (Farm.Event.Crypt)" },
        BuyItem = { remote = "ShopAPI/BuyItem", purpose = "buy 1 water / 1 hotdog when you have none; 1 egg (Farm.EggToBuy) when you have no pet that still grows (Farm.BuyEgg)" },
    }

    -- watch4: ChooseTeam("Babies", options) -> team changed to "Babies" in my data
    GameConstants.BabiesTeam = "Babies"
    GameConstants.ChooseTeamOptions = { dont_respawn = true, source_for_logging = "avatar_editor" }

    --[[ Travel recipes: SendPassiveDoorEnter(destination, door, {start_transparency = 1}) then
         SetLocation(destination, nil, spawn).
         - Salon: watch4 (from the house), the salon need started 0.3 s after SetLocation.
         - MainMap: watch4 door "Neighborhood!MainDoor", spawn "Default"; the bored need started 1.8 s after.
         - CatCafe: remotes_20260927_004819 (the game's own call: door "MainDoor", spawn nil). ]]
    GameConstants.Travel = {
        -- watch4 (hub) + watch5 (game): DoorEnter("housing","MainDoor",{house_owner=me,...}) -> SubscribeToHouse(me)
        -- -> SetLocation("housing", me, nil)
        housing = { door = "MainDoor", spawn = nil, ownHouse = true },
        Salon = { door = "MainDoor", spawn = nil },
        MainMap = { door = "Neighborhood!MainDoor", spawn = "Default" },
        CatCafe = { door = "MainDoor", spawn = nil },
        -- watch8_20260927_200148 (hub calls, confirmed by my data: interior_name changed + the need completed)
        PizzaShop = { door = "MainDoor", spawn = nil },
        School = { door = "MainDoor", spawn = nil },
        Hospital = { door = "MainDoor", spawn = nil },
        -- watch8_20260928_073936 (the game, user walked through every door): same door recipe for these shops
        CampingShop = { door = "MainDoor", spawn = nil },
        BeachShop = { door = "MainDoor", spawn = nil },
        BabyShop = { door = "MainDoor", spawn = nil },
        -- watch10_20261001: the egg shop (user walked in and out)
        Nursery = { door = "MainDoor", spawn = nil },
        -- halloween11/12 (the game's calls): Halloween 2026 places, each with door "MainDoor"
        HauntedManor = { door = "MainDoor", spawn = nil }, -- Ghost Gallery lobby
        TheCrypt = { door = "MainDoor", spawn = nil }, -- house_interior has NO name there: see CharWrapperPlaces
        HauntedHotel = { door = "MainDoor", spawn = nil }, -- the pigeon nest
    }
    -- Places whose house_interior arrives without interior_name (halloween11: TheCrypt "INTERIOR -> nil" while
    -- char_wrapper_raw.location.destination_id = "TheCrypt"); for these the location in char_wrapper_raw is used.
    GameConstants.CharWrapperPlaces = { TheCrypt = true }

    -- Leaving a building the game sends DoorEnter("MainMap", "<Place>/MainDoor", {...}) + SetLocation("MainMap", nil,
    -- "Default") and the character stands at that building's door (watch8_20260928_073936). Nearest door per spot:
    --   camping     <- CampingShop exit (-50, -1198), camp site 155 studs away
    --   beach_party <- BeachShop exit (-705, -1442), beach spot 135 studs away
    --   bored       <- BabyShop exit (-457, -1672), playground 105 studs away
    -- (the MainMap spawn is 130 / 440 / 760 studs from playground / beach / camp site)
    -- Needs that may need a talk inside the place (found by furniture id in the place's own data, not by key).
    GameConstants.InteriorTalkForAilment = {
        sick = { furniture = "doctor", use = "UseBlock", choice = "Yes" },
    }

    GameConstants.SpotDoor = {
        camping = { place = "CampingShop", exit = { x = -50.4, z = -1197.7 } },
        beach_party = { place = "BeachShop", exit = { x = -704.8, z = -1442.3 } },
        bored = { place = "BabyShop", exit = { x = -457.4, z = -1672.1 } },
    }

    --[[ Location needs: be in the place until the need completes (rate 0.02 = about 50 s).
         salon, bored: CONFIRMED (watch4, pet + baby completed together).
         cat_cafe: destination name confirmed; that the need completes there is STRONGLY INDICATED only. ]]
    GameConstants.LocationForAilment = {
        salon = "Salon",
        bored = "MainMap",
        cat_cafe = "CatCafe",
        -- watch8: pet + baby completed in that place (pizza_party ~50 s, school ~50 s, sick ~6 s)
        pizza_party = "PizzaShop",
        school = "School",
        sick = "Hospital",
        -- watch8: rate 0.02 in MainMap while the character stood at the spot below; completed there (pet + baby)
        camping = "MainMap",
        beach_party = "MainMap",
    }

    --[[ SPOTS inside MainMap (watch8_20260927_200148, character root positions while the need ran and completed):
         camping: next to the camp site (lodgesleepingbag furniture at -55, 33.7, -1071), completed after ~50 s
         beach_party: in the water at the beach (Humanoid state Swimming), completed after ~50 s
         Moving there is a LOCAL change of my own character position (no remote), done by Game/Interaction:moveTo. ]]
    -- Main menu Play button. The remote alone does NOT close the menu; the button must be clicked.
    -- PlayButtonFind (2026-09-28): the VISIBLE one is NewsApp...Buttons.PlayButton (ImageButton, text "Play!");
    -- ExperimentalNewsApp...Contents.PlayButton exists too but its ScreenGui is disabled. Firing the button's
    -- getconnections closed the menu within 2 s, then the game put me on team Parents.
    GameConstants.PlayButtonPath = { "NewsApp", "EnclosingFrame", "MainFrame", "Buttons", "PlayButton" }

    -- mystery: choose one of these (fast, confirmed tasks first). The chosen need must appear in my data.
    GameConstants.MysteryPreference = { "toilet", "dirty", "sleepy", "hungry", "thirsty", "sick", "cat_cafe", "salon",
        "school", "pizza_party", "camping", "beach_party", "bored", "pet_me" }
    GameConstants.MysterySlot = 1 -- third argument in the capture; meaning not known yet

    -- walk / ride (watch8_20260928_053142): progress rises only while the character MOVES with the pet (rate 1/30 while
    -- walking, 0 when standing); walk completed after ~30 s of walking (no leash needed; a leash is only the bonus),
    -- ride the same with the stroller equipped and the pet in it.
    GameConstants.StrollerCategory = "strollers"
    GameConstants.WalkSeconds = 45

    GameConstants.Spots = {
        camping = { x = -18.443, y = 37.204, z = -1046.005, purpose = "camping: the camp site in the neighborhood" },
        -- watch8_20260928_053142 (user walked there): rate 0.02 started at (-495.7, -1469.0); the character then stood at
        -- (-579.5, 25.6, -1496.4) for 46 s and pet + baby completed. The old point in the water (-671, -1413) never worked live.
        beach_party = { x = -579.456, y = 25.634, z = -1496.408, purpose = "beach_party: the beach in the neighborhood" },
        -- Need card (screenshot 2026-09-28): "Take your pet to the Playground". watch8: baby bored ran and completed
        -- while the character stood here; live 0.6.0/0.8.0: it did NOT start at the MainMap spawn.
        bored = { x = -401.629, y = 29.779, z = -1760.047, purpose = "bored: the playground in the neighborhood" },
        -- halloween12: the user stood here (MainMap!Halloween) when the Stray Cat took the water
        stray_cat = { x = -243.6, y = 87.0, z = -1118.2, purpose = "Halloween: next to the Stray Cat" },
    }
    GameConstants.SpotForAilment = {
        camping = "camping",
        beach_party = "beach_party",
        bored = "bored",
    }

    --[[ HOUSE + FURNITURE (furniture6_20260927_103131, watch5_20260927_100834)
         - At home, my data's house_interior.interior_name is nil; this script calls that place "housing".
         - Furniture models: workspace.HouseInteriors.furniture["<Owner>/1/nil/true/<key>"].<Model>
           with attributes furniture_unique = <key>, furniture_kind = <id>; use parts in <Model>.UseBlocks.
         - ActivateFurniture(player, key, useName, { cframe = usePart.CFrame * CFrame.new(0, usePart.Size.Y / 2, 0) }, target)
           (the top face of the use part: matched in all 18 recorded uses, 7 furniture kinds). ]]
    GameConstants.HouseInteriorName = "housing"
    GameConstants.HouseExitDestination = "exit_housing"
    -- Captured value (user, 2026-09-29), used only if the live camera offset cannot be computed.
    GameConstants.HouseExitCameraOffset = { x = 0.68896484375, y = 8.55078125, z = 8.8720703125,
        rx = -0.7369100451469421, ry = 0.05742141604423523, rz = 0.05203080177307129 }
    -- Pet age 6 = Full Grown (screenshots: Newborn = 1 ... Full Grown = 6). Farm.SkipFullGrown skips those.
    GameConstants.FullGrownAge = 6
    -- Eggs this script may buy (Farm.EggToBuy). Bucks only: royal_egg costs Robux and is NEVER bought.
    -- Ids as the game names items; the event egg was seen in the Nursery on 2026-10-01 (watch10).
    -- User capture (SimpleSpy, 2026-10-01): ShopAPI/BuyItem("pets", "cracked_egg", {buy_count = 1}) (InvokeServer);
    -- the bought egg is equipped by the game itself.
    -- Every purchase is verified by my backpack (a new pet of that kind); not there -> try once more in the Nursery.
    GameConstants.Eggs = {
        "cracked_egg", -- 350 Bucks (default)
        "pet_egg", -- 600 Bucks
        "fairytale_egg_2026_fairytale_egg", -- current event egg (price unknown)
    }
    GameConstants.NeverBuyEggs = { royal_egg = true } -- Robux
    GameConstants.EggCategory = "pets"
    -- Live 1.4.1 (3 new accounts, 2026-10-01): the tutorial "practice_dog" (age 1) is equipped by Equip and removed by
    -- the game 1 s later, every time. Never picked as the pet to farm.
    GameConstants.NotFarmablePets = { practice_dog = true }
    function GameConstants.isEgg(kind)
        if type(kind) ~= "string" then
            return false
        end
        for _, id in ipairs(GameConstants.Eggs) do
            if kind == id then
                return true
            end
        end
        return kind == "royal_egg" or string.match(kind, "_egg$") ~= nil and not string.find(kind, "^basic_egg_")
    end
    -- MainMap spots and doors are all within x -800..100, z -1900..-1000. Interiors sit far away at z ~ -9000 (live:
    -- (-5986, -9011), (35, -9020), (12011, -9030), (-2989, -9030)): a character there is NOT on MainMap.
    function GameConstants.isOnMainMapArea(p)
        return p.X > -1500 and p.X < 1000 and p.Z > -3000 and p.Z < 0
    end
    GameConstants.HouseFurnitureFolderPath = { "HouseInteriors", "furniture" }
    GameConstants.FurnitureUniqueAttribute = "furniture_unique"

    --[[ Which of MY furniture fulfils which need. Only kinds whose effect was seen in my data:
         sleepy: basicbed (pet + baby, watch5), dirty: stylishshower (pet + baby, watch5),
         toilet: toilet (pet; rate 1/7 seen in session_20260927_095123). ]]
    GameConstants.FurnitureForAilment = {
        sleepy = { "basicbed" },
        -- watch8_20260928_123452 (the game, alt house): modernshower f-27 UseBlock for the baby AND the pet;
        -- cheap_pet_bathtub_tutorial f-15 UseBlock for the pet (occupied UseBlock = pet). Pet-only: see below.
        dirty = { "stylishshower", "modernshower", "cheap_pet_bathtub_tutorial" },
        toilet = { "toilet" },
    }
    -- watch8: pet on the free food bowl (occupied UseBlock = pet) -> hungry rate 1/7 -> completed (twice)
    GameConstants.PetFoodBowls = { "ailments_refresh_2024_cheap_food_bowl" }
    GameConstants.PetOnlyFurniture = { cheap_pet_bathtub_tutorial = true }
    GameConstants.UseBlockForFurniture = {
        modernshower = "UseBlock",
        cheap_pet_bathtub_tutorial = "UseBlock",
        ailments_refresh_2024_cheap_food_bowl = "UseBlock",
        basicbed = "Seat1",
        stylishshower = "UseBlock",
        toilet = "Seat1",
    }

    --[[ ITEM NEEDS (watch7_20260927_231531, 11_GAME_FINDINGS 7f). Only item ids whose effect was seen:
         - pet hungry: sandwich-default completed it; pet water drink ran the same flow (pet thirsty itself not yet seen)
         - baby thirsty: water (watch4, 8 uses) and chocolate_milk (watch7, 5 uses) completed it
         - baby hungry: tool cycle confirmed in watch4/watch5; sandwich-default is the only food id seen working
         The food category also holds NON-food (pet_trick_potion, fishing rods, bait): never pick by category alone. ]]
    GameConstants.ItemCategory = "food"
    GameConstants.ItemsForAilment = {
        hungry = { "sandwich-default", "cheese", "hotdog" }, -- watch8: baby hungry +1/3 per sandwich use, +1/2 per cheese use
        thirsty = { "water", "chocolate_milk" },
    }
    -- watch4: ShopAPI/BuyItem("food", "water", {}) -> new water item, cost 1 Buck
    GameConstants.BuyForAilment = {
        thirsty = { category = "food", ids = { "water" }, options = {}, setting = "BuyWater" },
        -- User's SimpleSpy capture 2026-09-28: BuyItem("food", "hotdog", {buy_count = 1}) works from anywhere (no shop).
        -- Same format for the sandwich (its id is in the inventory; its effect on hungry is CONFIRMED). Hotdog's effect on
        -- hungry is NOT seen yet: it is only bought if the sandwich purchase fails, and the task checks progress.
        -- Live 0.9.9: buying "sandwich-default" never arrived (3x); "hotdog" arrived every time (2 Bucks) and hungry completed.
        hungry = { category = "food", ids = { "hotdog" }, options = { buy_count = 1 }, setting = "BuyFood" },
    }
    -- Pet food flow: Equip -> FocusPet -> ServerUseTool START -> CreatePetObject(type 2, {...}) -> Unequip(unique, nil)
    -- -> the game's pet walks to workspace.PetObjects.<Food> and sends ConsumeFoodObject(object, petUnique) -> completed.
    GameConstants.PetObjectsFolderName = "PetObjects"
    GameConstants.FoodObjectCreator = "__Enum_PetObjectCreatorType_2"
    -- Toy flow: Equip -> ServerUseTool START + CreatePetObject(type 1, {reaction_name, unique_id}) -> Unequip(toy,
    -- {from_throw_toy = true}) -> ServerUseTool END; the pet grabs it (GrabPetObject) and play progress rises by 1/3.
    GameConstants.ToyObjectCreator = "__Enum_PetObjectCreatorType_1"
    GameConstants.ThrowToyReaction = "ThrowToyReaction"
    GameConstants.ToyCategory = "toys"
    GameConstants.ToysForPlay = { "squeaky_bone_default" }

    -- halloween12 2026-10-04: potions are "food" items; age potions age the pet at once (age 4 -> 5)
    GameConstants.AgePotions = { "pet_age_potion", "tiny_pet_age_potion" }
    GameConstants.GiftCategory = "gifts"
    -- only the kinds whose opening was recorded: "...gift" -> OpenGift, "..._chest" -> ExchangeItemForReward
    GameConstants.GiftPatterns = { gift = "gift$", chest = "_chest$" }

    --[[ HALLOWEEN 2026 (11_GAME_FINDINGS 7v, 7w, 7x) ]]
    GameConstants.Event = {
        -- toys category ids
        RustyKey = "halloween_2026_rusty_key",
        Twig = "halloween_2026_twig",
        Vacuum = "halloween_2026_ghost_vacuum", -- loaned for one round (properties.ghost_clusters_loan = true)
        NestTwigs = 8, -- playadopt.me notes: 8 twigs build the nest
        CatFood = { "water", "chocolate_milk" }, -- halloween12: water worked (+50 candy)
        -- grave rewards (crypt_manager.floors[f].coffins[i]); "ladder" = the way down to the next floor
        Ladder = "ladder",
        GraveValue = { candy_corn_pile_ginormous = 3, candy_corn_pile_small = 2, twig = 1 },
        -- STRONGLY INDICATED (4 of 4 ids fit): crypt_manager.opened holds floor * 16 + grave index
        OpenedIdPerFloor = 16,
        PetPenSlots = 4, -- the 5th slot is a gamepass ("EXTRA SLOT")
        MinigameId = "ghost_clusters",
        MinigameInteriorPrefix = "ManorMinigameInterior",
        RoundSeconds = 600, -- halloween11: rounds 1791068144 -> 1791068744; cycle data steps 600 per identifier
        GhostsFolder = "GhostClustersVisuals", -- workspace.GhostClustersVisuals.Ghost_<Size>_<ghost_id>
        GhostNamePattern = "^Ghost_%a+_([%x%-]+)$",
        VacuumReachStuds = 15, -- ASSUMPTION (not measured): farther than this we move next to the target again
        -- halloween12: the boss is the only "Ghost_Large_<id>" of a round (after "ghost_clusters_boss_breakout"); the
        -- Small / Medium ghosts around it are its guards. User 2026-10-04: hitting the boss while guards live does not win.
        BossSize = "Large",
        BossStandOff = 18, -- the boss model is big: stand farther away (ASSUMPTION)
        -- Live 1.5.0 (3 accounts, 6 rounds): ServerUseTool(vacuum, "START") answers false. halloween12: the game sends
        -- the first start_contribute with a NEW token in the same moment as START (no answer awaited) -> the client makes
        -- the token: a lower-case GUID without braces (e.g. "d8286d68-7607-45b3-93ad-d81abaad7040").
        QuestTabs = { "halloween_2026", "vanilla" },
        QuestsPerBoardReward = 3, -- halloween12: reward claimed at total_dailies_completed_today = 3 (both boards)
    }

    return GameConstants
end

-- ─────────────────────────────── module: Game/GameData ───────────────────────────────
__moduleSources["Game/GameData"] = function(...)
    --[[
        Game/GameData
        Keeps a private COPY of my own Adopt Me data (only the keys in GameConstants.DataKeys).

        Sources, in order:
          1. Initial snapshot: the game's ClientData.get_data(), called once (read-only).
          2. DataAPI/DataChanged         -> replaces a whole key
          3. DataAPI/DataPartiallyChanged -> replaces one nested value (e.g. one furniture piece)

        Other players' updates arrive on the same remotes; they are dropped immediately, never stored.
        Everything is deep-copied: this module never holds or modifies the game's own tables.

        gameData.KeyChanged:Connect(function(key, value) ... end)   -- fires after any change to a tracked key
    ]]

    local import = ...
    local Signal = import("Core/Signal")
    local GameConstants = import("Game/GameConstants")

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local GameData = {}
    GameData.__index = GameData

    local MAX_COPY_DEPTH = 12

    local function deepCopy(value, depth, seen)
        if type(value) ~= "table" then
            return value
        end
        depth = depth or 0
        seen = seen or {}
        if seen[value] then
            return seen[value]
        end
        if depth > MAX_COPY_DEPTH then
            return nil
        end
        local copy = {}
        seen[value] = copy
        for key, item in pairs(value) do
            copy[deepCopy(key, depth + 1, seen)] = deepCopy(item, depth + 1, seen)
        end
        return copy
    end
    GameData.deepCopy = deepCopy

    function GameData.new(logger)
        local self = setmetatable({}, GameData)
        self._logger = logger
        self._data = {}
        self._tracked = {}
        for _, key in pairs(GameConstants.DataKeys) do
            self._tracked[key] = true
        end
        self.KeyChanged = Signal.new("GameData.KeyChanged")
        self.SnapshotSource = nil -- how the initial data was obtained (for the log/status)
        return self
    end

    function GameData:get(key)
        return self._data[key]
    end

    function GameData:isTracked(key)
        return self._tracked[key] == true
    end

    function GameData:_setKey(key, value)
        if not self._tracked[key] then
            return
        end
        self._data[key] = deepCopy(value)
        self.KeyChanged:Fire(key, self._data[key])
    end

    -- change = { replicated_key_path = {"house_interior", "furniture", "f-2"}, serialized_partial_value = ... }
    function GameData:_applyPartial(change)
        if type(change) ~= "table" or type(change.replicated_key_path) ~= "table" then
            return
        end
        local path = change.replicated_key_path
        local rootKey = path[1]
        if not self._tracked[rootKey] then
            return
        end
        if #path == 1 then
            self:_setKey(rootKey, change.serialized_partial_value)
            return
        end
        if type(self._data[rootKey]) ~= "table" then
            self._data[rootKey] = {}
        end
        local node = self._data[rootKey]
        for index = 2, #path - 1 do
            local part = path[index]
            if type(node[part]) ~= "table" then
                node[part] = {}
            end
            node = node[part]
        end
        node[path[#path]] = deepCopy(change.serialized_partial_value) -- nil removes the entry
        self.KeyChanged:Fire(rootKey, self._data[rootKey])
    end

    local function findByPath(root, names)
        local node = root
        for _, name in ipairs(names) do
            node = node and node:FindFirstChild(name)
        end
        return node
    end

    local function describeKeys(tableValue, limit)
        local keys = {}
        for key in pairs(tableValue) do
            table.insert(keys, tostring(key))
            if #keys >= limit then
                break
            end
        end
        return table.concat(keys, ", ")
    end

    --[[
        Reads the current data once at start (DataChanged only reports CHANGES).
        ASSUMPTION (labelled, verified at runtime by the shape check below): ClientData.get_data()
        needs no arguments and returns either { [playerName] = myData } or myData itself.
        If the shape is not recognised nothing is used, and the reason is logged.
    ]]
    function GameData:_loadSnapshot()
        local moduleScript = findByPath(ReplicatedStorage, GameConstants.ClientDataModulePath)
        if not moduleScript then
            return nil, "ClientData module not found"
        end
        local requireOk, clientData = pcall(require, moduleScript)
        if not requireOk or type(clientData) ~= "table" then
            return nil, "require(ClientData) failed: " .. tostring(clientData)
        end
        if type(clientData.get_data) ~= "function" then
            return nil, "ClientData.get_data is not a function"
        end
        local callOk, allData = pcall(clientData.get_data)
        if not callOk then
            return nil, "ClientData.get_data() failed: " .. tostring(allData)
        end
        if type(allData) ~= "table" then
            return nil, "ClientData.get_data() returned " .. typeof(allData)
        end
        local myName = Players.LocalPlayer and Players.LocalPlayer.Name
        local mine = myName and allData[myName]
        if type(mine) == "table" then
            return mine, "ClientData.get_data()[playerName]"
        end
        if allData[GameConstants.DataKeys.Ailments] ~= nil or allData[GameConstants.DataKeys.Money] ~= nil then
            return allData, "ClientData.get_data()"
        end
        return nil, "ClientData.get_data() returned an unknown shape (keys: " .. describeKeys(allData, 8) .. ")"
    end

    -- Connects the remotes and loads the snapshot. Returns true if live updates are connected.
    function GameData:start(maid)
        local myName = Players.LocalPlayer and Players.LocalPlayer.Name
        local apiFolder = ReplicatedStorage:FindFirstChild(GameConstants.Remotes.Folder)
        if not apiFolder then
            self._logger:error("GameData", "ReplicatedStorage." .. GameConstants.Remotes.Folder .. " not found; game data unavailable")
            return false
        end

        local dataChanged = apiFolder:FindFirstChild(GameConstants.Remotes.DataChanged)
        if not (dataChanged and dataChanged:IsA("RemoteEvent")) then
            self._logger:error("GameData", GameConstants.Remotes.DataChanged .. " not found; game data unavailable")
            return false
        end
        maid:Give(dataChanged.OnClientEvent:Connect(function(playerName, key, value)
            if playerName ~= myName then
                return -- another player's data: ignored, never stored
            end
            self:_setKey(key, value)
        end))

        local partialChanged = apiFolder:FindFirstChild(GameConstants.Remotes.DataPartiallyChanged)
        if partialChanged and partialChanged:IsA("RemoteEvent") then
            maid:Give(partialChanged.OnClientEvent:Connect(function(playerName, changes)
                if playerName ~= myName or type(changes) ~= "table" then
                    return
                end
                for _, change in ipairs(changes) do
                    self:_applyPartial(change)
                end
            end))
        else
            self._logger:warn("GameData", GameConstants.Remotes.DataPartiallyChanged .. " not found; nested updates will be missed")
        end

        local snapshot, how = self:_loadSnapshot()
        if snapshot then
            self.SnapshotSource = how
            for key in pairs(self._tracked) do
                if snapshot[key] ~= nil and self._data[key] == nil then
                    self:_setKey(key, snapshot[key])
                end
            end
            self._logger:info("GameData", "Initial data loaded via " .. how)
        else
            self.SnapshotSource = nil
            self._logger:warn("GameData", "No initial data (" .. tostring(how) .. "). Values appear as the game sends updates.")
        end
        return true
    end

    -- Kind of one of my pets ("dog"), from equipped pets or pet wrappers. nil if unknown.
    function GameData:getPetKind(petUnique)
        local equip = self._data[GameConstants.DataKeys.Equip]
        if type(equip) == "table" and type(equip.pets) == "table" then
            for _, pet in pairs(equip.pets) do
                if type(pet) == "table" and pet.unique == petUnique then
                    return pet.kind or pet.id
                end
            end
        end
        local wrappers = self._data[GameConstants.DataKeys.PetWrappers]
        if type(wrappers) == "table" then
            for _, wrapper in pairs(wrappers) do
                if type(wrapper) == "table" and wrapper.pet_unique == petUnique then
                    return wrapper.pet_id
                end
            end
        end
        return nil
    end

    -- true if that pet is equipped right now. ailments_manager also lists needs of pets that are NOT
    -- equipped (watch7: an unequipped egg had sleepy + dirty), and those cannot be done.
    function GameData:isPetEquipped(petUnique)
        local equip = self._data[GameConstants.DataKeys.Equip]
        if type(equip) ~= "table" or type(equip.pets) ~= "table" then
            return true -- unknown: do not block
        end
        for _, pet in pairs(equip.pets) do
            if type(pet) == "table" and pet.unique == petUnique then
                return true
            end
        end
        return false
    end

    -- Items of one inventory category whose id is in `ids` (in the order of `ids`, then by unique).
    -- Returns a list of { unique, id, usesLeft }.
    function GameData:findItems(category, ids)
        local inventory = self._data[GameConstants.DataKeys.Inventory]
        local items = type(inventory) == "table" and inventory[category]
        local result = {}
        if type(items) ~= "table" then
            return result
        end
        local rank = {}
        for index, id in ipairs(ids or {}) do
            rank[id] = index
        end
        for unique, item in pairs(items) do
            if type(item) == "table" and item.id ~= nil and (ids == nil or rank[item.id]) then
                local properties = type(item.properties) == "table" and item.properties or {}
                table.insert(result, { unique = tostring(item.unique or unique), id = item.id, usesLeft = tonumber(properties.uses_left) })
            end
        end
        table.sort(result, function(a, b)
            if rank[a.id] ~= rank[b.id] then
                return rank[a.id] < rank[b.id]
            end
            return a.unique < b.unique
        end)
        return result
    end

    -- uses_left of one item, or nil when the item is gone.
    function GameData:itemUsesLeft(category, unique)
        local inventory = self._data[GameConstants.DataKeys.Inventory]
        local item = type(inventory) == "table" and type(inventory[category]) == "table" and inventory[category][unique]
        if type(item) ~= "table" then
            return nil
        end
        local properties = type(item.properties) == "table" and item.properties or {}
        return tonumber(properties.uses_left) or 1
    end

    function GameData:equippedPetCount()
        local equip = self._data[GameConstants.DataKeys.Equip]
        local count = 0
        for _, pet in pairs(type(equip) == "table" and type(equip.pets) == "table" and equip.pets or {}) do
            if type(pet) == "table" and pet.unique then
                count += 1
            end
        end
        return count, equip ~= nil
    end

    function GameData:firstEquippedPet()
        local equip = self._data[GameConstants.DataKeys.Equip]
        for _, pet in pairs(type(equip) == "table" and type(equip.pets) == "table" and equip.pets or {}) do
            if type(pet) == "table" and pet.unique then
                return pet.unique
            end
        end
        return nil
    end

    -- Equipped pets as { unique, age } (age nil when unknown).
    function GameData:equippedPetList()
        local equip = self._data[GameConstants.DataKeys.Equip]
        local result = {}
        for _, pet in pairs(type(equip) == "table" and type(equip.pets) == "table" and equip.pets or {}) do
            if type(pet) == "table" and pet.unique then
                local properties = type(pet.properties) == "table" and pet.properties or {}
                local age = tonumber(properties.age)
                if age == nil then
                    age = self:petAge(pet.unique)
                end
                table.insert(result, { unique = pet.unique, age = age })
            end
        end
        return result
    end

    function GameData:petAge(unique)
        local inventory = self._data[GameConstants.DataKeys.Inventory]
        local pets = type(inventory) == "table" and inventory.pets
        local pet = type(pets) == "table" and pets[unique]
        local properties = type(pet) == "table" and type(pet.properties) == "table" and pet.properties
        return properties and tonumber(properties.age) or nil
    end

    -- Pets in my Pet Pen right now (idle_progression_manager.active_pets, halloween11): set of uniques.
    function GameData:petPenPets()
        local pen = self._data[GameConstants.DataKeys.PetPen]
        local result = {}
        for unique, record in pairs(type(pen) == "table" and type(pen.active_pets) == "table" and pen.active_pets or {}) do
            result[tostring(unique)] = type(record) == "table" and record or {}
        end
        return result
    end

    -- Pets in my backpack that are NOT full grown, oldest first (closest to full grown), then by unique.
    -- Pets sitting in the Pet Pen are left out: the farm does not equip them (the pen grows them).
    function GameData:growablePets()
        local inventory = self._data[GameConstants.DataKeys.Inventory]
        local pets = type(inventory) == "table" and inventory.pets
        local inPen = self:petPenPets()
        local result = {}
        for key, pet in pairs(type(pets) == "table" and pets or {}) do
            if type(pet) == "table" and not inPen[tostring(pet.unique or key)] then
                local properties = type(pet.properties) == "table" and pet.properties or {}
                local age = tonumber(properties.age)
                local kind = tostring(pet.kind or pet.id or "?")
                if age == nil and GameConstants.isEgg(kind) then
                    age = 0 -- an egg still grows (hatches)
                end
                if age and age < GameConstants.FullGrownAge and not GameConstants.NotFarmablePets[kind] then
                    table.insert(result, { unique = tostring(pet.unique or key), age = age, kind = kind })
                end
            end
        end
        table.sort(result, function(a, b)
            if a.age ~= b.age then
                return a.age > b.age
            end
            return a.unique < b.unique
        end)
        return result
    end

    -- True once my backpack's pet list has arrived (an empty list is "no pets", a missing one is "not known yet").
    function GameData:petInventoryKnown()
        local inventory = self._data[GameConstants.DataKeys.Inventory]
        return type(inventory) == "table" and type(inventory.pets) == "table"
    end

    -- Uniques of my backpack pets of one kind (to see a purchase arrive).
    function GameData:petUniquesOfKind(kind)
        local inventory = self._data[GameConstants.DataKeys.Inventory]
        local pets = type(inventory) == "table" and inventory.pets
        local result = {}
        for key, pet in pairs(type(pets) == "table" and pets or {}) do
            if type(pet) == "table" and tostring(pet.kind or pet.id) == kind then
                result[tostring(pet.unique or key)] = true
            end
        end
        return result
    end

    -- Items of one inventory category with that id (list of uniques, sorted).
    function GameData:itemsOfId(category, id)
        local list = {}
        for _, item in ipairs(self:findItems(category, { id })) do
            table.insert(list, item.unique)
        end
        return list
    end

    function GameData:isSitting()
        local manager = self._data[GameConstants.DataKeys.StateManager]
        return type(manager) == "table" and manager.is_sitting == true
    end

    function GameData:destroy()
        self.KeyChanged:DisconnectAll()
    end

    return GameData
end

-- ─────────────────────────────── module: Game/PetLocator ───────────────────────────────
__moduleSources["Game/PetLocator"] = function(...)
    --[[
        Game/PetLocator
        Finds MY pet's model in workspace.Pets (which also contains other players' pets).
        Link (confirmed in watch2 + snapshot): pet_char_wrappers_raw[StreamingId] = { char = StreamingId, pet_unique = "2_..." }
        and the pet model has attribute StreamingId == char.
    ]]

    local import = ...
    local GameConstants = import("Game/GameConstants")

    local PetLocator = {}
    PetLocator.__index = PetLocator

    function PetLocator.new(gameData)
        return setmetatable({ _gameData = gameData }, PetLocator)
    end

    -- Returns the StreamingId ("char") of my pet with this unique id, or nil.
    function PetLocator:getStreamingId(petUnique)
        local wrappers = self._gameData:get(GameConstants.DataKeys.PetWrappers)
        if type(wrappers) ~= "table" then
            return nil
        end
        for _, wrapper in pairs(wrappers) do
            if type(wrapper) == "table" and wrapper.pet_unique == petUnique and type(wrapper.char) == "string" then
                return wrapper.char
            end
        end
        return nil
    end

    -- Returns (model) or (nil, reason). Never assumes the first pet in the folder is mine.
    function PetLocator:findModel(petUnique)
        local streamingId = self:getStreamingId(petUnique)
        if not streamingId then
            return nil, "no pet wrapper for this pet yet"
        end
        local folder = workspace:FindFirstChild(GameConstants.PetsFolderName)
        if not folder then
            return nil, "workspace." .. GameConstants.PetsFolderName .. " not found"
        end
        for _, model in ipairs(folder:GetChildren()) do
            local ok, value = pcall(function()
                return model:GetAttribute(GameConstants.PetModelIdAttribute)
            end)
            if ok and value == streamingId then
                return model
            end
        end
        return nil, "model not streamed in yet"
    end

    -- My equipped pets as plain tables: { unique, kind, age, xp }
    function PetLocator:getEquippedPets()
        local equip = self._gameData:get(GameConstants.DataKeys.Equip)
        local result = {}
        if type(equip) ~= "table" or type(equip.pets) ~= "table" then
            return result
        end
        for _, pet in pairs(equip.pets) do
            if type(pet) == "table" and type(pet.unique) == "string" then
                local properties = type(pet.properties) == "table" and pet.properties or {}
                table.insert(result, {
                    unique = pet.unique,
                    kind = tostring(pet.kind or pet.id or "?"),
                    age = tonumber(properties.age),
                    xp = tonumber(properties.xp),
                })
            end
        end
        table.sort(result, function(a, b)
            return a.unique < b.unique
        end)
        return result
    end

    return PetLocator
end

-- ─────────────────────────────── module: Game/PlayerSync ───────────────────────────────
__moduleSources["Game/PlayerSync"] = function(...)
    --[[
        Game/PlayerSync
        Copies simple values from my game data into State, each tagged with its source:
          player.bucks     [money]
          player.team      [team]            "Parents" | "Babies"
          player.interior  [house_interior]  e.g. "MainMap!Default", "Salon", my house
          pets.equipped    [equip_manager]   list of { unique, kind, age, xp }
    ]]

    local import = ...
    local GameConstants = import("Game/GameConstants")

    local PlayerSync = {}

    local KEYS = GameConstants.DataKeys

    -- Read-only log for Phase 4b: which furniture exists in each room I enter (id x count), once per room.
    local function describeFurniture(interior)
        local counts = {}
        for _, piece in pairs(type(interior.furniture) == "table" and interior.furniture or {}) do
            if type(piece) == "table" and type(piece.id) == "string" then
                counts[piece.id] = (counts[piece.id] or 0) + 1
            end
        end
        local parts = {}
        for id, count in pairs(counts) do
            table.insert(parts, id .. " x" .. count)
        end
        table.sort(parts)
        return #parts > 0 and table.concat(parts, ", ") or "none"
    end

    function PlayerSync.start(maid, state, gameData, petLocator, logger)
        local furnitureLoggedFor = nil
        -- halloween11: in TheCrypt house_interior has no interior_name; the place is in char_wrapper_raw.location.
        local function placeFromCharWrapper()
            local wrapper = gameData:get(KEYS.CharWrapper)
            local location = type(wrapper) == "table" and type(wrapper.location) == "table" and wrapper.location
            local id = location and location.destination_id
            return (type(id) == "string" and GameConstants.CharWrapperPlaces[id]) and id or nil
        end
        local function apply(key, value)
            if key == KEYS.CharWrapper then
                local interior = gameData:get(KEYS.Interior)
                local place = placeFromCharWrapper()
                if place and state:get("player.interior") == nil and type(interior) == "table"
                    and type(interior.interior_name) ~= "string" and interior.house_pos == nil then
                    state:set("player.interior", place, "DataChanged:" .. key)
                end
                return
            end
            if key == KEYS.Money and tonumber(value) then
                state:set("player.bucks", tonumber(value), "DataChanged:" .. key)
            elseif key == KEYS.Team and type(value) == "string" then
                state:set("player.team", value, "DataChanged:" .. key)
            elseif key == KEYS.Interior and type(value) == "table" then
                -- At home interior_name is nil (furniture6_20260927_103131): this script calls that place "housing".
                -- Leaving a place the game sends house_interior = {} (watch7, watch8): that is "on the way", not home.
                -- My house always has house_pos / furniture (watch8).
                local name = type(value.interior_name) == "string" and value.interior_name
                    or ((value.house_pos ~= nil or next(type(value.furniture) == "table" and value.furniture or {}) ~= nil)
                        and GameConstants.HouseInteriorName or nil)
                name = name or placeFromCharWrapper()
                state:set("player.interior", name, "DataChanged:" .. key)
                if name == nil then
                    return
                end
                if logger and furnitureLoggedFor ~= name then
                    furnitureLoggedFor = name
                    logger:debug("Furniture", "In " .. name .. ": " .. describeFurniture(value))
                end
            elseif key == KEYS.Equip then
                state:set("pets.equipped", petLocator:getEquippedPets(), "DataChanged:" .. key)
            end
        end
        maid:Give(gameData.KeyChanged:Connect(apply))
        for _, key in ipairs({ KEYS.Money, KEYS.Team, KEYS.Interior, KEYS.Equip }) do
            local value = gameData:get(key)
            if value ~= nil then
                apply(key, value)
            end
        end
    end

    return PlayerSync
end

-- ─────────────────────────────── module: Game/AilmentTracker ───────────────────────────────
__moduleSources["Game/AilmentTracker"] = function(...)
    --[[
        Game/AilmentTracker
        Turns the game's ailments_manager data into a clean list in State, logs what changes,
        and counts completions (from the game's own completion events).

        State written (source in brackets):
          ailments.active    : list of { owner = "pet"|"baby", petUnique, petKind, kind, inProgress, rate, createdAt, preferredItem }
          ailments.known     : true once the list has been received at least once
          stats.needsCompleted, stats.bucksEarned, stats.lastTask   [AilmentsAPI completion events]
    ]]

    local import = ...
    local Enums = import("Core/Enums")
    local Signal = import("Core/Signal")
    local GameConstants = import("Game/GameConstants")

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local AilmentTracker = {}
    AilmentTracker.__index = AilmentTracker

    local SOURCE_DATA = "DataChanged:" .. GameConstants.DataKeys.Ailments

    function AilmentTracker.new(logger, state, notifier, gameData)
        local self = setmetatable({}, AilmentTracker)
        self._logger = logger
        self._state = state
        self._notifier = notifier
        self._gameData = gameData
        self._previous = {} -- [id] = entry
        -- Fires (owner, petUnique|nil, kind) for every completion of MY pet / MY baby
        self.Completed = Signal.new("AilmentTracker.Completed")
        return self
    end

    local function entryId(entry)
        return (entry.owner == "baby" and "baby" or entry.petUnique) .. "|" .. entry.kind
    end

    function AilmentTracker:ownerLabel(entry)
        if entry.owner == "baby" then
            return "baby"
        end
        return "pet " .. tostring(entry.petKind or "?")
    end

    local function readEntry(rawEntry, kindKey)
        local components = type(rawEntry) == "table" and rawEntry.components
        local preference = type(components) == "table" and components.preference
        local rate = type(rawEntry) == "table" and tonumber(rawEntry.rate) or 0
        -- mystery: components.mystery.components = { toilet = {}, camping = {}, ... } (watch8)
        local mysteryOptions = nil
        local mystery = type(components) == "table" and components.mystery
        if type(mystery) == "table" and type(mystery.components) == "table" then
            mysteryOptions = {}
            for kind in pairs(mystery.components) do
                table.insert(mysteryOptions, tostring(kind))
            end
            table.sort(mysteryOptions)
        end
        return {
            mysteryOptions = mysteryOptions,
            kind = tostring(type(rawEntry) == "table" and rawEntry.kind or kindKey),
            rate = rate,
            inProgress = rate > 0,
            progress = type(rawEntry) == "table" and tonumber(rawEntry.progress) or 0, -- rises per toy catch (play, watch7)
            createdAt = type(rawEntry) == "table" and tonumber(rawEntry.created_timestamp) or nil,
            preferredItem = type(preference) == "table" and preference.item_kind or nil,
        }
    end

    -- Converts ailments_manager into a sorted flat list.
    function AilmentTracker:parse(manager)
        local list = {}
        if type(manager) ~= "table" then
            return list
        end
        if type(manager.ailments) == "table" then
            for petUnique, ailments in pairs(manager.ailments) do
                if type(ailments) == "table" then
                    for kindKey, rawEntry in pairs(ailments) do
                        local entry = readEntry(rawEntry, kindKey)
                        entry.owner = "pet"
                        entry.petUnique = tostring(petUnique)
                        entry.petKind = self._gameData:getPetKind(entry.petUnique)
                        table.insert(list, entry)
                    end
                end
            end
        end
        if type(manager.baby_ailments) == "table" then
            for kindKey, rawEntry in pairs(manager.baby_ailments) do
                local entry = readEntry(rawEntry, kindKey)
                entry.owner = "baby"
                table.insert(list, entry)
            end
        end
        table.sort(list, function(a, b)
            return (a.createdAt or 0) < (b.createdAt or 0)
        end)
        return list
    end

    function AilmentTracker:_onAilmentsChanged(manager)
        local list = self:parse(manager)
        local current = {}
        for _, entry in ipairs(list) do
            local id = entryId(entry)
            current[id] = entry
            local before = self._previous[id]
            local label = self:ownerLabel(entry) .. " " .. entry.kind
            if not before then
                local extra = entry.preferredItem and (" (prefers " .. entry.preferredItem .. ")") or ""
                self._logger:info("Needs", "New need: " .. label .. extra)
            elseif entry.inProgress and not before.inProgress then
                self._logger:info("Needs", string.format("In progress: %s (about %d s)", label, math.floor(1 / entry.rate + 0.5)))
            elseif not entry.inProgress and before.inProgress then
                -- Only a problem while this script is working on it (a manual stop/restart is normal)
                -- Public reports 2026-10-05: most WARN lines were this (walk / ride pauses that recover by themselves);
                -- the task's own FAILED line is the real problem signal. INFO keeps it in the log, out of the reports.
                if self._state:get("farm.currentTask") == entry.kind then
                    self._logger:info("Needs", "Progress stopped: " .. label)
                else
                    self._logger:debug("Needs", "Progress stopped: " .. label)
                end
            end
        end
        for id, before in pairs(self._previous) do
            if not current[id] then
                self._logger:debug("Needs", "Removed from list: " .. self:ownerLabel(before) .. " " .. before.kind)
            end
        end
        self._previous = current
        self._state:set("ailments.active", list, SOURCE_DATA)
        self._state:set("ailments.known", true, SOURCE_DATA)
    end

    -- A pet is mine if my own data mentions it (equipped/wrappers) or it has an ailment in my list.
    function AilmentTracker:_isMyPet(petUnique)
        if self._gameData:getPetKind(petUnique) ~= nil then
            return true
        end
        for _, entry in pairs(self._previous) do
            if entry.petUnique == petUnique then
                return true
            end
        end
        return false
    end

    function AilmentTracker:_onCompleted(owner, petUnique, kind, rewards)
        local bucks = type(rewards) == "table" and tonumber(rewards.bucks) or 0
        local xp = type(rewards) == "table" and tonumber(rewards.xp) or nil
        local label = owner == "baby" and "baby" or ("pet " .. tostring(self._gameData:getPetKind(petUnique) or "?"))
        local source = owner == "baby" and GameConstants.Remotes.BabyAilmentCompleted or GameConstants.Remotes.PetAilmentCompleted

        local completed = self._state:increment("stats.needsCompleted", 1, source)
        local earned = self._state:increment("stats.bucksEarned", bucks, source)
        local taskText = label .. " " .. tostring(kind)
        self._state:set("stats.lastTask", taskText, source)

        self._logger:success("Needs", string.format("Completed: %s (+%d Bucks%s)", taskText, bucks, xp and (", +" .. xp .. " XP") or ""))
        self.Completed:Fire(owner, petUnique, tostring(kind))
        self._notifier:notify(Enums.NotifyEvent.TaskCompleted, {
            { name = "Last task", value = taskText, inline = true },
            { name = "Needs completed", value = tostring(completed), inline = true },
            { name = "Bucks earned", value = tostring(earned), inline = true },
        })
    end

    function AilmentTracker:start(maid)
        maid:Give(function()
            self.Completed:DisconnectAll()
        end)
        maid:Give(self._gameData.KeyChanged:Connect(function(key, value)
            if key == GameConstants.DataKeys.Ailments then
                self:_onAilmentsChanged(value)
            end
        end))
        -- data may already be present from the initial snapshot
        local existing = self._gameData:get(GameConstants.DataKeys.Ailments)
        if existing ~= nil then
            self:_onAilmentsChanged(existing)
        end

        local apiFolder = ReplicatedStorage:FindFirstChild(GameConstants.Remotes.Folder)
        local petCompleted = apiFolder and apiFolder:FindFirstChild(GameConstants.Remotes.PetAilmentCompleted)
        if petCompleted and petCompleted:IsA("RemoteEvent") then
            maid:Give(petCompleted.OnClientEvent:Connect(function(petUnique, kind, rewards)
                -- Not verified whether the server sends other players' completions too: only count my pets
                if not self:_isMyPet(tostring(petUnique)) then
                    self._logger:debug("Needs", "Ignored a completion for a pet that is not mine")
                    return
                end
                self:_onCompleted("pet", tostring(petUnique), kind, rewards)
            end))
        else
            self._logger:warn("Needs", GameConstants.Remotes.PetAilmentCompleted .. " not found; pet completions not counted")
        end
        local babyCompleted = apiFolder and apiFolder:FindFirstChild(GameConstants.Remotes.BabyAilmentCompleted)
        if babyCompleted and babyCompleted:IsA("RemoteEvent") then
            maid:Give(babyCompleted.OnClientEvent:Connect(function(player, kind, rewards)
                if player ~= Players.LocalPlayer then
                    self._logger:debug("Needs", "Ignored a baby completion for another player")
                    return
                end
                self:_onCompleted("baby", nil, kind, rewards)
            end))
        else
            self._logger:warn("Needs", GameConstants.Remotes.BabyAilmentCompleted .. " not found; baby completions not counted")
        end
    end

    return AilmentTracker
end

-- ─────────────────────────────── module: Game/Interaction ───────────────────────────────
__moduleSources["Game/Interaction"] = function(...)
    --[[
        Game/Interaction
        The ONLY place that sends anything to the game server.
          interaction:send("FocusPet", petModel)   -> ok, resultOrReason

        Safety:
          - Only actions listed in GameConstants.Actions can be sent (unknown names throw).
          - RemoteEvent -> FireServer, RemoteFunction -> InvokeServer (decided by the object's class, not assumed).
          - InvokeServer is waited on with a timeout, so a server that never answers cannot hang a task.
          - Every send is logged (DEBUG) and counted (State farm.actionsSent).
    ]]

    local import = ...
    local Util = import("Core/Util")
    local GameConstants = import("Game/GameConstants")

    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local Interaction = {}
    Interaction.__index = Interaction

    local INVOKE_TIMEOUT_SECONDS = 10

    function Interaction.new(logger, state)
        local self = setmetatable({}, Interaction)
        self._logger = logger
        self._state = state
        self._sent = 0
        return self
    end

    -- Lines for the transparency report: exactly what may be sent, and why.
    function Interaction.describeActions()
        local names = {}
        for name in pairs(GameConstants.Actions) do
            table.insert(names, name)
        end
        table.sort(names)
        local lines = {}
        for _, name in ipairs(names) do
            local action = GameConstants.Actions[name]
            table.insert(lines, action.remote .. " — " .. action.purpose)
        end
        table.insert(lines, "LOCAL teleport of your character inside the neighborhood to the camp site / beach / playground (Farm.SpotTravel)")
        table.insert(lines, "LOCAL click on the main menu Play button and then HOME in \"Choose Location!\" — only on the menu (Farm.AutoAcceptMenu)")
        table.insert(lines, "LOCAL call of the game's OWN travel function (InteriorsM.enter, the one every door uses): it sends the game's own door / location requests (Farm.GameTravel); also to visit other players' houses for the \"Visit player homes\" quests (Farm.Event.HouseVisits)")
        table.insert(lines, "LOCAL walking of your character in long diagonal legs (~30 studs) — ONLY for the walk need (and ride); if the game left it anchored on solid ground, it is un-anchored first")
        table.insert(lines, "LOCAL teleport of your character next to the Stray Cat (Halloween map) and, inside the Ghost Gallery minigame only, next to the ghost it vacuums (Farm.Event)")
        table.insert(lines, "LOCAL virtual click — only when Roblox says you are idle, to avoid the 20-minute kick (Farm.AntiAfk)")
        return lines
    end

    -- Virtual right click (Roblox VirtualUser), only when Roblox reports the player idle. Local input, no remote.
    function Interaction.virtualClick()
        return pcall(function()
            local virtualUser = game:GetService("VirtualUser")
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end

    -- Clicks a GUI button. Methods, tried in this order by the caller (each verified by the caller):
    --   "touch"       VirtualInputManager touch at the button centre (phones)
    --   "mouse"       VirtualInputManager mouse click at the button centre
    --   "connections" getconnections(signal) -> connection:Fire() / connection.Function()
    --   "firesignal"  firesignal(signal)
    -- Returns ran (bool), detail (string).
    -- Live: PlayButtonFind closed the menu with connections; the farm (0.7.7) with firesignal after the others did not.
    Interaction.CLICK_METHODS = { "firesignal", "connections", "touch", "mouse" }
    local CLICK_SIGNALS = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up" }

    local function buttonCentre(button)
        local screenGui = button:FindFirstAncestorOfClass("ScreenGui")
        local inset = (screenGui and screenGui.IgnoreGuiInset) and Vector2.new(0, 0)
            or game:GetService("GuiService"):GetGuiInset()
        return button.AbsolutePosition.X + button.AbsoluteSize.X / 2 + inset.X,
            button.AbsolutePosition.Y + button.AbsoluteSize.Y / 2 + inset.Y
    end

    function Interaction.clickButton(button, method)
        if method == "connections" then
            if type(getconnections) ~= "function" then
                return false, "getconnections missing"
            end
            local fired = 0
            for _, signalName in ipairs(CLICK_SIGNALS) do
                pcall(function()
                    for _, connection in ipairs(getconnections(button[signalName])) do
                        if pcall(function() connection:Fire() end) or pcall(connection.Function) then
                            fired += 1
                        end
                    end
                end)
            end
            return fired > 0, "(" .. fired .. " connections)"
        elseif method == "firesignal" then
            if type(firesignal) ~= "function" then
                return false, "firesignal missing"
            end
            for _, signalName in ipairs(CLICK_SIGNALS) do
                pcall(firesignal, button[signalName])
            end
            return true, ""
        end
        local ok, err = pcall(function()
            local vim = game:GetService("VirtualInputManager")
            local x, y = buttonCentre(button)
            if method == "touch" then
                vim:SendTouchEvent(1, 0, x, y) -- 0 = Begin
                task.wait(0.1)
                vim:SendTouchEvent(1, 2, x, y) -- 2 = End
            else
                vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
                task.wait(0.1)
                vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
            end
        end)
        return ok, ok and "" or tostring(err)
    end

    -- Teleports MY character to a recorded spot (local PivotTo, no remote), after the game unanchors me; checks
    -- after 2 s that I am still there (the game sometimes puts me back), up to 3 tries.
    function Interaction:teleportTo(spotName)
        local spot = GameConstants.Spots[spotName]
        if not spot then
            error("Interaction: spot is not in the allowlist: " .. tostring(spotName), 2)
        end
        local player = game:GetService("Players").LocalPlayer
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then
            return false, "no character"
        end
        self._sent += 1
        self._state:set("farm.actionsSent", self._sent, "Interaction")
        local waited = 0
        while root.Anchored and waited < 10 do
            task.wait(0.5)
            waited += 0.5
        end
        -- Live 0.9.4-0.9.9 (screenshots, user): at the spot the map was not loaded yet (black void, the character hanging
        -- in the air) and the need never started. 1) ask Roblox to stream the area in, 2) teleport, 3) wait up to 20 s
        -- until there is ground under the spot (the game loads it once I am there), 4) stand on it.
        local canCheck = true -- false when the executor cannot raycast: then we do not wait for ground
        local function groundY()
            local y
            local ok = pcall(function()
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = { character }
                local hit = workspace:Raycast(Vector3.new(spot.x, spot.y + 60, spot.z), Vector3.new(0, -200, 0), params)
                y = hit and hit.Position.Y
            end)
            canCheck = ok
            return y
        end
        local streamed = pcall(function()
            player:RequestStreamAroundAsync(Vector3.new(spot.x, spot.y, spot.z), 15)
        end)
        self._logger:debug("Action", "Stream around " .. spotName .. ": " .. (streamed and "requested" or "not available"))
        local ground = groundY()
        for attempt = 1, 3 do
            local ok, err = pcall(function()
                character:PivotTo(CFrame.new(spot.x, ground and (ground + 3) or (spot.y + 2), spot.z))
            end)
            if not ok then
                return false, tostring(err)
            end
            task.wait(2)
            local p = root.Position
            if math.abs(p.X - spot.x) < 25 and math.abs(p.Z - spot.z) < 25 then
                if not ground and canCheck then
                    local seconds = 0
                    while not ground and seconds < 20 do
                        task.wait(1)
                        seconds += 1
                        ground = groundY()
                    end
                    if not ground then
                        return false, "the map at " .. spotName .. " did not load within 20 s"
                    end
                    self._logger:debug("Action", string.format("Map at %s loaded after %d s: standing on it", spotName, seconds))
                    pcall(function()
                        character:PivotTo(CFrame.new(spot.x, ground + 3, spot.z))
                    end)
                elseif ground then
                    self._logger:debug("Action", string.format("Ground at %s: y=%.1f (recorded %.1f)", spotName, ground, spot.y))
                end
                return true
            end
            self._logger:debug("Action", string.format("Teleport to %s undone (now at %.0f, %.0f), try %d", spotName, p.X, p.Z, attempt))
        end
        return false, "the game moved the character back"
    end

    -- Ghost Gallery (inside the minigame interior only): moves MY character next to a position (local PivotTo, no
    -- remote). Counted like an action. The score messages of the game verify whether vacuuming then works.
    function Interaction:teleportNear(position, standOff)
        local character = game:GetService("Players").LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root or typeof(position) ~= "Vector3" then
            return false, "no character"
        end
        self._sent += 1
        self._state:set("farm.actionsSent", self._sent, "Interaction")
        local ok, err = pcall(function()
            local from = root.Position
            local dx, dz = from.X - position.X, from.Z - position.Z
            local length = math.sqrt(dx * dx + dz * dz)
            local off = standOff or 10
            local x = length > 0.1 and position.X + dx / length * off or position.X + off
            local z = length > 0.1 and position.Z + dz / length * off or position.Z
            character:PivotTo(CFrame.new(Vector3.new(x, from.Y, z), Vector3.new(position.X, from.Y, position.Z)))
        end)
        return ok, ok and nil or tostring(err)
    end

    -- Live 1.2.2: in all 35 "not moving" samples the root was ANCHORED (state Freefall/Running, walkSpeed 16), also
    -- right after arriving at the MainMap spawn with no teleport: the game anchors the character on arrival and, after our
    -- remote travel, never lets go (its own door code does that). Unanchor MY root locally, only when there is ground
    -- under it (so I do not fall into an unloaded map). Returns true if it is (now) free.
    function Interaction:releaseAnchor(root, character, reason)
        if not root or not root.Anchored then
            return true
        end
        local below
        pcall(function()
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { character }
            local hit = workspace:Raycast(root.Position, Vector3.new(0, -25, 0), params)
            below = hit and hit.Position
        end)
        if not below then
            self._logger:debug("Action", "Root anchored, no ground under it yet: leaving it")
            return false
        end
        local ok = pcall(function()
            root.Anchored = false
        end)
        self._logger:info("Action", "My character was left anchored by the game (" .. tostring(reason) .. "): released it"
            .. (ok and "" or " (failed)"))
        return ok and not root.Anchored
    end

    -- Walks MY character in long diagonal legs (Humanoid:MoveTo, ~40 studs each) until done() or `seconds` pass.
    -- Local only: no remote. Returns true if done() became true.
    function Interaction:walkAround(seconds, done, tick)
        local character = game:GetService("Players").LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root then
            return false
        end
        -- User (2026-09-29): with 12-stud legs the character never left the pet's follow range (~15-20 studs), so
        -- the pet stood still and walk/ride did not progress. Now long diagonal legs (like the other hub): forward-left,
        -- forward-right, back to the start, ~40 studs each; a new leg starts when the point is reached, after 5 s,
        -- or when blocked (no movement for 1.5 s).
        self._logger:debug("Action", "Walking long diagonal legs for up to " .. seconds .. " s")
        if root.Anchored then
            local waited = 0
            while root.Anchored and waited < 3 do -- the game's own unanchor, if it comes
                task.wait(0.5)
                waited += 0.5
            end
            self:releaseAnchor(root, character, "before walking")
        end
        local start = root.Position
        local fx, fz = 0, -1
        pcall(function()
            local look = root.CFrame.LookVector
            local length = math.sqrt(look.X * look.X + look.Z * look.Z)
            if length > 0.1 then
                fx, fz = look.X / length, look.Z / length
            end
        end)
        local rx, rz = -fz, fx -- right of forward
        local LEG = 30
        local points = {
            Vector3.new(start.X + (fx - rx) * LEG, start.Y, start.Z + (fz - rz) * LEG), -- forward-left
            Vector3.new(start.X + (fx + rx) * LEG, start.Y, start.Z + (fz + rz) * LEG), -- forward-right
            Vector3.new(start.X, start.Y, start.Z), -- back
        }
        local elapsed, index = 0, 0
        while elapsed < seconds do
            if done() then
                return true
            end
            index = index % #points + 1
            local target = points[index]
            local legTime, still, last = 0, 0, root.Position
            while legTime < 5 and elapsed < seconds do
                humanoid:MoveTo(target) -- repeated: Roblox drops a MoveTo after 8 s
                task.wait(0.5)
                legTime += 0.5
                elapsed += 0.5
                if tick then
                    tick()
                end
                if done() then
                    return true
                end
                local p = root.Position
                if math.sqrt((p.X - target.X) ^ 2 + (p.Z - target.Z) ^ 2) < 4 then
                    break
                end
                if math.sqrt((p.X - last.X) ^ 2 + (p.Z - last.Z) ^ 2) < 0.5 then
                    still += 0.5
                    if still == 1 then
                        -- Live 1.2.1: "moved 0 studs" in 68 of 95 samples (MoveTo had no effect). Record why and try to
                        -- get going: stand up, no platform stand, then push with Humanoid:Move for this leg.
                        local diag = {}
                        pcall(function()
                            table.insert(diag, "anchored=" .. tostring(root.Anchored))
                            table.insert(diag, "sit=" .. tostring(humanoid.Sit))
                            table.insert(diag, "platformStand=" .. tostring(humanoid.PlatformStand))
                            table.insert(diag, "walkSpeed=" .. tostring(humanoid.WalkSpeed))
                            table.insert(diag, "state=" .. tostring(humanoid:GetState()))
                        end)
                        self.walkDiag = table.concat(diag, " ")
                        self:releaseAnchor(root, character, "while walking")
                        pcall(function()
                            if humanoid.Sit then
                                humanoid.Sit = false
                            end
                            if humanoid.PlatformStand then
                                humanoid.PlatformStand = false
                            end
                            local dx, dz = target.X - p.X, target.Z - p.Z
                            local length = math.sqrt(dx * dx + dz * dz)
                            if length > 0.1 then
                                humanoid:Move(Vector3.new(dx / length, 0, dz / length), false)
                            end
                        end)
                    elseif still >= 2.5 then
                        break -- blocked: next leg
                    end
                else
                    still = 0
                    self.walkDiag = nil
                end
                last = p
            end
        end
        return done()
    end

    -- Moves MY character to one of the recorded spots (GameConstants.Spots). Local only: no remote is sent.
    function Interaction:moveTo(spotName)
        local spot = GameConstants.Spots[spotName]
        if not spot then
            error("Interaction: spot is not in the allowlist: " .. tostring(spotName), 2)
        end
        local character = game:GetService("Players").LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root then
            return false, "no character"
        end
        self._sent += 1
        self._state:set("farm.actionsSent", self._sent, "Interaction")
        -- Live 0.9.0: a TELEPORT (PivotTo) to the spot made the game reset the character ~4 s later (all needs resent,
        -- progress stopped), so the character now WALKS there (PathfindingService waypoints, Humanoid:MoveTo). Local only.
        local waited = 0
        while root.Anchored and waited < 10 do
            task.wait(0.5)
            waited += 0.5
        end
        local target = Vector3.new(spot.x, spot.y, spot.z)
        local function distance()
            local p = root.Position
            return math.sqrt((p.X - spot.x) ^ 2 + (p.Z - spot.z) ^ 2)
        end
        local function walkTo(point, limit)
            humanoid:MoveTo(point)
            local t = 0
            while t < limit do
                task.wait(0.25)
                t += 0.25
                local p = root.Position
                if math.sqrt((p.X - point.X) ^ 2 + (p.Z - point.Z) ^ 2) < 4 then
                    return true
                end
            end
            return false
        end
        self._logger:debug("Action", string.format("Walking to %s (%.0f, %.0f), %.0f studs", spotName, spot.x, spot.z, distance()))
        local waypoints
        pcall(function()
            local path = game:GetService("PathfindingService"):CreatePath({ AgentCanJump = true })
            path:ComputeAsync(root.Position, target)
            if path.Status == Enum.PathStatus.Success then
                waypoints = path:GetWaypoints()
            end
        end)
        local started = os.clock()
        if waypoints then
            for _, waypoint in ipairs(waypoints) do
                if waypoint.Action == Enum.PathWaypointAction.Jump then
                    humanoid.Jump = true
                end
                walkTo(waypoint.Position, 4)
                if os.clock() - started > 90 then
                    break
                end
            end
        else
            self._logger:debug("Action", "No path found: walking straight")
            for _ = 1, 12 do -- MoveTo gives up after 8 s: repeat until there
                if walkTo(target, 8) or distance() < 10 then
                    break
                end
            end
        end
        if distance() < 15 then
            return true
        end
        return false, string.format("could not walk there (still %.0f studs away)", distance())
    end

    local function describeArgs(...)
        local parts = {}
        for index = 1, select("#", ...) do
            local value = select(index, ...)
            if typeof(value) == "Instance" then
                table.insert(parts, "<" .. value.Name .. ">")
            elseif type(value) == "table" then
                table.insert(parts, "{...}")
            else
                table.insert(parts, tostring(value))
            end
        end
        return table.concat(parts, ", ")
    end

    function Interaction:send(actionName, ...)
        local action = GameConstants.Actions[actionName]
        if not action then
            error("Interaction: action is not in the allowlist: " .. tostring(actionName), 2)
        end
        if action.emptyOnly then
            local first = ...
            if select("#", ...) ~= 1 or type(first) ~= "table" or next(first) ~= nil then
                error("Interaction: " .. actionName .. " may only be sent with an empty table", 2)
            end
        end
        if action.allowedFirstArg then
            local first = ...
            if not action.allowedFirstArg[first] then
                error("Interaction: " .. actionName .. " may not be sent with " .. tostring(first), 2)
            end
        end
        if action.allowedMessages then
            local _, message = ...
            if not action.allowedMessages[message] then
                error("Interaction: " .. actionName .. " may not send message " .. tostring(message), 2)
            end
        end
        -- Halloween 2026 remotes live in ReplicatedStorage.adoptme_new_net (halloween11), all others in API.
        local folderName = action.folder and GameConstants.Remotes[action.folder] or GameConstants.Remotes.Folder
        local apiFolder = ReplicatedStorage:FindFirstChild(folderName)
        local remote = apiFolder and apiFolder:FindFirstChild(action.remote)
        if not remote then
            self._logger:error("Action", "Remote not found: " .. action.remote)
            return false, "remote not found"
        end

        self._sent += 1
        self._state:set("farm.actionsSent", self._sent, "Interaction")
        self._logger:debug("Action", "Send " .. action.remote .. "(" .. describeArgs(...) .. ")")

        if remote:IsA("RemoteFunction") then
            local finished, callOk, result = false, false, nil
            local args = table.pack(...)
            task.spawn(function()
                callOk, result = pcall(function()
                    return remote:InvokeServer(table.unpack(args, 1, args.n))
                end)
                finished = true
            end)
            local deadline = Util.now() + (action.answersWhenDone and 2 or INVOKE_TIMEOUT_SECONDS)
            while not finished and Util.now() < deadline do
                task.wait(0.1)
            end
            if not finished and action.answersWhenDone then
                return true, "pending" -- the answer comes when the use ends; the caller checks my data
            end
            if not finished then
                self._logger:warn("Action", action.remote .. " did not answer within " .. INVOKE_TIMEOUT_SECONDS .. " s")
                return false, "no answer from server"
            end
            if not callOk then
                self._logger:warn("Action", action.remote .. " failed: " .. tostring(result))
                return false, tostring(result)
            end
            return true, result
        end

        if remote:IsA("RemoteEvent") then
            local ok, err = pcall(function(...)
                remote:FireServer(...)
            end, ...)
            if not ok then
                self._logger:warn("Action", action.remote .. " failed: " .. tostring(err))
                return false, tostring(err)
            end
            return true
        end

        self._logger:error("Action", action.remote .. " is a " .. remote.ClassName .. ", not a remote")
        return false, "not a remote"
    end

    return Interaction
end

-- ─────────────────────────────── module: Game/Travel ───────────────────────────────
__moduleSources["Game/Travel"] = function(...)
    --[[
        Game/Travel
        Moves the player to a named place using the recipes in GameConstants.Travel, then VERIFIES the move:
        my data's current interior name (State player.interior) must change within the timeout.
          local ok, reason = travel:goTo("Salon")
    ]]

    local import = ...
    local Util = import("Core/Util")
    local GameConstants = import("Game/GameConstants")

    local Players = game:GetService("Players")

    local Travel = {}
    Travel.__index = Travel

    local DOOR_TO_LOCATION_DELAY = 1 -- seconds; the game itself waits 1-4 s between the two calls
    local ARRIVAL_TIMEOUT_SECONDS = 12

    function Travel.new(logger, state, interaction, farmConfig)
        return setmetatable({ _logger = logger, _state = state, _interaction = interaction, _farmConfig = farmConfig }, Travel)
    end

    function Travel:canGoTo(destination)
        return GameConstants.Travel[destination] ~= nil
    end

    -- ASSUMPTION (seen for MainMap!Default and Neighborhood!Default): an interior name starts with its place name.
    function Travel:isAt(destination)
        local interior = self._state:get("player.interior")
        return type(interior) == "string" and string.sub(interior, 1, #destination) == destination
    end

    -- Leaves the building I am in through its door onto MainMap (as the game does, watch8_20260928_073936).
    function Travel:exitToMainMap()
        local place = self._state:get("player.interior")
        if type(place) ~= "string" or not GameConstants.Travel[place] or place == "MainMap" then
            return false, "not in a building"
        end
        self._logger:info("Travel", "Leaving " .. place .. " through its door")
        local ok, reason = self._interaction:send("DoorEnter", "MainMap", place .. "/MainDoor", { start_transparency = 1 })
        if not ok then
            return false, "door enter failed: " .. tostring(reason)
        end
        task.wait(DOOR_TO_LOCATION_DELAY)
        ok, reason = self._interaction:send("SetLocation", "MainMap", nil, "Default")
        if not ok then
            return false, "set location failed: " .. tostring(reason)
        end
        local deadline = Util.now() + ARRIVAL_TIMEOUT_SECONDS
        while Util.now() < deadline do
            if self:isAt("MainMap") then
                self._logger:info("Travel", "Arrived: MainMap (from " .. place .. ")")
                return true
            end
            task.wait(0.25)
        end
        return false, "still in " .. tostring(self._state:get("player.interior"))
    end

    -- Leaves MY house through its door exactly as the game does (user's SimpleSpy capture, 2026-09-29).
    -- Live 1.1.1: going from home straight to a place reset the character ~7 s after arriving in 85 of 86 trips;
    -- trips starting outside the house almost never did. Verified by my data: I must be out of the house.
    function Travel:exitHouse()
        local me = Players.LocalPlayer
        local blueprint = workspace:FindFirstChild("HouseInteriors")
        blueprint = blueprint and blueprint:FindFirstChild("blueprint")
        local mine = blueprint and blueprint:FindFirstChild(me.Name)
        local doors = mine and mine:FindFirstChild("Doors")
        local door = doors and doors:FindFirstChild("MainDoor")
        if not door then
            return false, "house door not found (workspace.HouseInteriors.blueprint." .. me.Name .. ".Doors.MainDoor)"
        end
        local offset
        pcall(function()
            local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
            local camera = workspace.CurrentCamera
            if root and camera then
                offset = root.CFrame:ToObjectSpace(camera.CFrame)
            end
        end)
        if not offset then
            local c = GameConstants.HouseExitCameraOffset
            pcall(function()
                offset = CFrame.new(c.x, c.y, c.z) * CFrame.Angles(c.rx, c.ry, c.rz)
            end)
        end
        self._logger:info("Travel", "Leaving the house through its door")
        local ok, reason = self._interaction:send("DoorEnter", GameConstants.HouseExitDestination, "MainDoor", {
            skip_set_player_collisions = true,
            skip_send_passive_door_request = true,
            house_owner = me,
            camera_rootpart_cframe_offset = offset,
            exiting_door = door,
        })
        if not ok then
            return false, "door enter failed: " .. tostring(reason)
        end
        self._interaction:send("MarkEnteredDoorTime")
        self._interaction:send("PushFurnitureChanges", {})
        self._interaction:send("ExitFurnitureUseStates")
        self._interaction:send("UnsubscribeFromHouse", me)
        local deadline = Util.now() + ARRIVAL_TIMEOUT_SECONDS
        while Util.now() < deadline do
            local now = self._state:get("player.interior")
            if now ~= nil and now ~= GameConstants.HouseInteriorName then
                self._logger:info("Travel", "Out of the house: " .. tostring(now))
                return true
            end
            task.wait(0.25)
        end
        return false, "still in " .. tostring(self._state:get("player.interior")) .. " after the house door"
    end

    -- Live 1.2.1: ~12 times "Arrived: MainMap" while my character was still standing in the old interior's area
    -- (z ~ -9000: (35, -9020), (12011, -9030), (-2989, -9030)); teleports were undone and walking moved 0 studs.
    -- So after arriving on MainMap: wait for the game to place me; not placed in 8 s -> SetLocation once more; still not
    -- -> fail with the position (the task retries later).
    local function rootPosition()
        local character = Players.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        return root and root.Position
    end

    function Travel:_waitPlacedOnMainMap(seconds)
        local deadline = Util.now() + seconds
        while Util.now() < deadline do
            local p = rootPosition()
            if not p or GameConstants.isOnMainMapArea(p) then
                return true
            end
            task.wait(0.25)
        end
        return false
    end

    function Travel:_checkPlacedOnMainMap(recipe, me)
        if self:_waitPlacedOnMainMap(8) then
            return true
        end
        local p = rootPosition()
        self._logger:warn("Travel", string.format("Data says MainMap but my character is still at (%.0f, %.0f) (an interior's"
            .. " area): asking for MainMap once more", p.X, p.Z))
        self._interaction:send("SetLocation", "MainMap", nil, recipe.spawn)
        if self:_waitPlacedOnMainMap(8) then
            self._logger:info("Travel", "Placed on MainMap after asking again")
            return true
        end
        p = rootPosition()
        return false, string.format("not placed on MainMap (character at %.0f, %.0f)", p.X, p.Z)
    end

    -- 1.3.0: travel the way the game itself does. watch9/watch10 (2026-09-30): every door goes through the game's client
    -- module InteriorsM: enter(destination_id, door_id, options). It sends the door request + SetLocation itself,
    -- anchors my character, places it at the door of the new place and UN-anchors it (the step our remote copy never
    -- did: frozen character, not placed on MainMap, resets). After a respawn the game itself calls
    -- enter("housing", "MainDoor", {house_owner = me, start_transparency = 1, studs_ahead_of_door = 4, char_id = ...}).
    local INTERIORS_PATH = { "ClientModules", "Core", "InteriorsM", "InteriorsM" }

    function Travel:_interiorsModule()
        if self._interiorsM ~= nil then
            return self._interiorsM or nil
        end
        local node = game:GetService("ReplicatedStorage")
        for _, name in ipairs(INTERIORS_PATH) do
            node = node and node:FindFirstChild(name)
        end
        local ok, module = false, nil
        if node then
            ok, module = pcall(require, node)
        end
        if ok and type(module) == "table" and type(module.enter) == "function" then
            self._interiorsM = module
            self._logger:info("Travel", "Using the game's own travel (InteriorsM.enter)")
            return module
        end
        self._interiorsM = false
        self._logger:warn("Travel", "The game's travel module was not found: using the remote route")
        return nil
    end

    -- Door ids as the game passes them: "Neighborhood/MainDoor" (our old recipe wrote "Neighborhood!MainDoor").
    local function gameDoorId(recipe)
        return (string.gsub(recipe.door, "!", "/"))
    end

    function Travel:_waitArrival(destination, seconds)
        local deadline = Util.now() + seconds
        while Util.now() < deadline do
            if self:isAt(destination) then
                -- the game un-anchors me once it has placed me; give it a moment
                local character = Players.LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                local settle = Util.now() + 5
                while root and root.Anchored and Util.now() < settle do
                    task.wait(0.25)
                end
                return true
            end
            task.wait(0.25)
        end
        return false
    end

    function Travel:_gameTravel(destination, recipe)
        local me = Players.LocalPlayer
        local before = self._state:get("player.interior")
        -- User: home by respawn is much faster than walking (watch10: after a respawn the game enters the house itself).
        if recipe.ownHouse and self._farmConfig.HomeByRespawn ~= false then
            self._logger:info("Travel", "Going home by respawn (now in " .. tostring(before) .. ")")
            local sent = self._interaction:send("Respawn")
            if sent and self:_waitArrival(destination, ARRIVAL_TIMEOUT_SECONDS + 5) then
                self._logger:info("Travel", "Arrived: " .. tostring(self._state:get("player.interior")) .. " (respawn)")
                return true
            end
            self._logger:info("Travel", "Respawn did not bring me home: using the game's door instead") -- fallback, not a failure
            if self:isAt(destination) then
                return true
            end
        end
        local module = self:_interiorsModule()
        if not module then
            return false, "no InteriorsM"
        end
        local options = {}
        if recipe.ownHouse then
            options.house_owner = me
        end
        local doorId = gameDoorId(recipe)
        self._logger:info("Travel", "Going to " .. destination .. " (now in " .. tostring(before) .. ", game travel via "
            .. doorId .. ")")
        task.spawn(function()
            local ok, err = pcall(module.enter, destination, doorId, options)
            if not ok then
                self._logger:warn("Travel", "InteriorsM.enter failed: " .. tostring(err))
            end
        end)
        if not self:_waitArrival(destination, ARRIVAL_TIMEOUT_SECONDS + 5) then
            return false, "still in " .. tostring(self._state:get("player.interior"))
        end
        self._logger:info("Travel", "Arrived: " .. tostring(self._state:get("player.interior")))
        if destination == "MainMap" then
            return self:_checkPlacedOnMainMap(recipe, me)
        end
        return true
    end

    -- Quest "Visit 3 / 5 player homes" (quests13b): the game's own door function with another player as house_owner,
    -- the way it enters my own house (house_owner = me). halloween12 020059: the game entered other players' houses
    -- with house_owner = <Player>. The caller verifies with the quest's own data and leaves afterwards.
    function Travel:visitHouse(player)
        local module = self:_interiorsModule()
        if not module then
            return false, "no InteriorsM"
        end
        self._logger:info("Travel", "Visiting the house of " .. tostring(player.Name) .. " (quest)")
        task.spawn(function()
            local ok, err = pcall(module.enter, "housing", "MainDoor", { house_owner = player })
            if not ok then
                self._logger:warn("Travel", "InteriorsM.enter (house visit) failed: " .. tostring(err))
            end
        end)
        return true
    end

    function Travel:goTo(destination)
        local recipe = GameConstants.Travel[destination]
        if not recipe then
            return false, "no known route to " .. tostring(destination)
        end
        if self:isAt(destination) then
            self._logger:debug("Travel", "Already at " .. destination)
            return true
        end
        -- Live 1.2.0: 0 of 177 house-door exits got me out (data: "?" then back in the house after a reset). Off by
        -- default until the rest of the game's exit (after UnsubscribeFromHouse) is recorded.
        if self._farmConfig and self._farmConfig.HouseDoorExit and not recipe.ownHouse and self:isAt(GameConstants.HouseInteriorName) then
            local out, outReason = self:exitHouse()
            if not out then
                self._logger:warn("Travel", "House door exit did not work (" .. tostring(outReason) .. "): going directly")
            elseif self:isAt(destination) then
                return true
            end
        end
        if self._farmConfig and self._farmConfig.GameTravel ~= false then
            local arrived, why = self:_gameTravel(destination, recipe)
            if arrived then
                return true
            end
            self._logger:info("Travel", "Game travel to " .. destination .. " did not work (" .. tostring(why)
                .. "): using the remote route")
            if self:isAt(destination) then
                return true
            end
        end
        local before = self._state:get("player.interior")
        self._logger:info("Travel", "Going to " .. destination .. " (now in " .. tostring(before) .. ")")

        local me = Players.LocalPlayer
        local doorOptions = { start_transparency = 1 }
        if recipe.ownHouse then
            doorOptions.house_owner = me
        end
        local ok, reason = self._interaction:send("DoorEnter", destination, recipe.door, doorOptions)
        if not ok then
            return false, "door enter failed: " .. tostring(reason)
        end
        -- Live 0.8.2: sending UnsubscribeFromHouse when LEAVING home sent the character back home ~8 s after arriving
        -- (salon/cat_cafe/school "Progress stopped"; the same trip from MainMap, without it, completed). Not sent any more.
        if recipe.ownHouse then
            self._interaction:send("SubscribeToHouse", me)
        end
        task.wait(DOOR_TO_LOCATION_DELAY)
        ok, reason = self._interaction:send("SetLocation", destination, recipe.ownHouse and me or nil, recipe.spawn)
        if not ok then
            return false, "set location failed: " .. tostring(reason)
        end

        local started = Util.now()
        local deadline = started + ARRIVAL_TIMEOUT_SECONDS
        local resubscribed = false
        while Util.now() < deadline do
            local now = self._state:get("player.interior")
            if now ~= nil and now ~= before then
                self._logger:info("Travel", "Arrived: " .. tostring(now))
                if destination == "MainMap" then
                    return self:_checkPlacedOnMainMap(recipe, me)
                end
                return true
            end
            -- Live 0.8.x: going home, sometimes my house data never arrives ("still in nil"). After 6 s ask again,
            -- the way the game leaves and enters a house (UnsubscribeFromHouse then SubscribeToHouse, watch7).
            if recipe.ownHouse and not resubscribed and Util.now() - started > 6 then
                resubscribed = true
                self._logger:info("Travel", "House data did not arrive: subscribing again")
                self._interaction:send("UnsubscribeFromHouse", me)
                self._interaction:send("SubscribeToHouse", me)
            end
            task.wait(0.25)
        end
        return false, "still in " .. tostring(self._state:get("player.interior")) .. " after " .. ARRIVAL_TIMEOUT_SECONDS .. " s"
    end

    return Travel
end

-- ─────────────────────────────── module: Game/Furniture ───────────────────────────────
__moduleSources["Game/Furniture"] = function(...)
    --[[
        Game/Furniture
        Finds a piece of MY furniture that can fulfil a need, and computes what ActivateFurniture needs.

          local spot, reason = furniture:findSpot({ "basicbed" })
          -- spot = { key = "f-15", kind = "basicbed", useName = "Seat1", cframe = <CFrame> }

        Rules (see GameConstants, measured in furniture6_20260927_103131):
          - only furniture in MY house (the room must be "housing" and the model folder must start with my name)
          - the position is the top face of the use part: usePart.CFrame * CFrame.new(0, usePart.Size.Y / 2, 0)
    ]]

    local import = ...
    local GameConstants = import("Game/GameConstants")

    local Players = game:GetService("Players")

    local Furniture = {}
    Furniture.__index = Furniture

    function Furniture.new(gameData, state)
        return setmetatable({ _gameData = gameData, _state = state }, Furniture)
    end

    -- Keys of my furniture of the wanted kinds, from my data (sorted, so the choice is deterministic)
    function Furniture:_keysOfKinds(kinds)
        local wanted = {}
        for _, kind in ipairs(kinds) do
            wanted[kind] = true
        end
        local interior = self._gameData:get(GameConstants.DataKeys.Interior)
        local keys = {}
        if type(interior) ~= "table" or type(interior.furniture) ~= "table" then
            return keys
        end
        for key, piece in pairs(interior.furniture) do
            if type(piece) == "table" and wanted[piece.id] then
                table.insert(keys, { key = tostring(key), kind = piece.id })
            end
        end
        table.sort(keys, function(a, b)
            return a.key < b.key
        end)
        return keys
    end

    -- The furniture model of one of MY pieces, or nil while it is not streamed in.
    function Furniture:_findModel(key)
        local folder = workspace
        for _, name in ipairs(GameConstants.HouseFurnitureFolderPath) do
            folder = folder and folder:FindFirstChild(name)
        end
        if not folder then
            return nil
        end
        local myPrefix = Players.LocalPlayer.Name .. "/"
        local suffix = "/" .. key
        for _, holder in ipairs(folder:GetChildren()) do
            local name = holder.Name
            if string.sub(name, 1, #myPrefix) == myPrefix and string.sub(name, -#suffix) == suffix then
                for _, child in ipairs(holder:GetChildren()) do
                    if child:IsA("Model") and child:GetAttribute(GameConstants.FurnitureUniqueAttribute) == key then
                        return child
                    end
                end
            end
        end
        return nil
    end

    function Furniture.useCFrame(usePart)
        return usePart.CFrame * CFrame.new(0, usePart.Size.Y / 2, 0)
    end

    -- Returns a spot for the first usable piece of the given kinds, or nil + reason.
    function Furniture:findSpot(kinds)
        if self._state:get("player.interior") ~= GameConstants.HouseInteriorName then
            return nil, "not at home"
        end
        local candidates = self:_keysOfKinds(kinds)
        if #candidates == 0 then
            return nil, "no " .. table.concat(kinds, "/") .. " in your house"
        end
        for _, candidate in ipairs(candidates) do
            local model = self:_findModel(candidate.key)
            local useName = GameConstants.UseBlockForFurniture[candidate.kind]
            local useBlocks = model and model:FindFirstChild("UseBlocks")
            local usePart = useBlocks and useName and useBlocks:FindFirstChild(useName)
            if usePart then
                return {
                    key = candidate.key,
                    kind = candidate.kind,
                    useName = useName,
                    cframe = Furniture.useCFrame(usePart),
                }
            end
        end
        return nil, table.concat(kinds, "/") .. " model not loaded yet"
    end

    return Furniture
end

-- ─────────────────────────────── module: Game/Tasks ───────────────────────────────
__moduleSources["Game/Tasks"] = function(...)
    --[[
        Game/Tasks
        Declarative task definitions. The TaskManager picks one and calls run(ctx, group, attempt).

        A task:
          id              unique name (also the config switch in Farm.Tasks and the priority key)
          handles(kind)   true if this task can fulfil that need kind
          timeoutSeconds  hard limit enforced by the TaskManager (the task is cancelled and cleaned up)
          run(ctx, group, attempt) -> true | false, reason
              Performs the actions AND verifies them against the game's data. Never assumes success.

        group (built by the TaskManager for one need kind):
          kind, entries (all active entries of that kind: pet and/or baby), petEntry (first pet entry or nil),
          anyInProgress, maxRate

        ctx:
          logger, state, interaction, travel, petLocator, farmConfig
          maid                   cleanup that ALWAYS runs when the task ends (success, failure, timeout)
          waitUntil(fn, seconds) -> true when fn() returned true before the time ran out
          isKindGone(kind)       -> true when no entry of that kind is left in my needs
          completedSince(kind, owner, petUnique) -> true if the game reported that completion after the task started
    ]]

    local import = ...
    local GameConstants = import("Game/GameConstants")
    local Util = import("Core/Util")
    local ensurePetModel -- defined below (needs equipPetAgain)

    local Players = game:GetService("Players")

    local Tasks = {}

    -- The character (baby) stays seated/anchored after a furniture need until it gets up (reported live, 0.4.0).
    -- The game's own way (watch7): jump -> AdoptAPI/ExitSeatStates() -> state_manager_raw.is_sitting = false and the
    -- furniture's occupied entry is cleared. Verified by my data, never assumed.
    local function standUp(ctx)
        if not ctx.gameData or not ctx.gameData:isSitting() then
            return true
        end
        ctx.logger:info("Tasks", "Your character is sitting: getting up first")
        ctx.interaction:send("ExitSeatStates")
        if ctx.waitUntil(function()
            return not ctx.gameData:isSitting()
        end, 4) then
            return true
        end
        return false, "your character is still sitting (ExitSeatStates had no effect)"
    end
    Tasks.standUp = standUp

    -- My pet still sitting on some furniture (house_interior occupied = its StreamingId): ask it to get up
    -- (PetAPI/ExitFurnitureUseStates(petUnique), sent by the game itself in watch7). Verified by my data.
    local function petOffFurniture(ctx, petUnique)
        local pid = ctx.petLocator:getStreamingId(petUnique)
        local interior = ctx.gameData and ctx.gameData:get(GameConstants.DataKeys.Interior)
        if not pid or type(interior) ~= "table" or type(interior.furniture) ~= "table" then
            return true
        end
        local function isOn()
            local now = ctx.gameData:get(GameConstants.DataKeys.Interior)
            for _, piece in pairs(type(now) == "table" and type(now.furniture) == "table" and now.furniture or {}) do
                if type(piece) == "table" and type(piece.occupied) == "table" then
                    for _, who in pairs(piece.occupied) do
                        if who == pid then
                            return true
                        end
                    end
                end
            end
            return false
        end
        if not isOn() then
            return true
        end
        ctx.logger:info("Tasks", "Your pet is still on furniture: getting it off first")
        ctx.interaction:send("ExitFurnitureUseStates", petUnique)
        if ctx.waitUntil(function()
            return not isOn()
        end, 4) then
            return true
        end
        return false, "pet is still on furniture (ExitFurnitureUseStates had no effect)"
    end
    Tasks.petOffFurniture = petOffFurniture

    -- Characters of mine that still occupy one piece of furniture (values of house_interior.furniture[key].occupied)
    local function occupants(ctx, key)
        local interior = ctx.gameData and ctx.gameData:get(GameConstants.DataKeys.Interior)
        local piece = type(interior) == "table" and type(interior.furniture) == "table" and interior.furniture[key]
        local list = {}
        if type(piece) == "table" and type(piece.occupied) == "table" then
            for _, who in pairs(piece.occupied) do
                table.insert(list, tostring(who))
            end
        end
        return list
    end

    -- pet_me: FocusPet -> wait -> PetPetted + ProgressPetMeAilment -> completion -> UnfocusPet (watch4)
    Tasks.pet_me = {
        id = "pet_me",
        handles = function(kind)
            return kind == "pet_me"
        end,
        timeoutSeconds = 40,
        run = function(ctx, group, attempt)
            local petEntry = group.petEntry
            if not petEntry then
                return false, "pet_me is only for pets"
            end
            local model, reason = ensurePetModel(ctx, petEntry.petUnique)
            if not model then
                return false, "pet model: " .. tostring(reason)
            end
            local off, offReason = petOffFurniture(ctx, petEntry.petUnique)
            if not off then
                return false, offReason
            end
            local ok, sendReason = ctx.interaction:send("FocusPet", model)
            if not ok then
                return false, "focus failed: " .. tostring(sendReason)
            end
            ctx.maid:Give(function()
                ctx.interaction:send("UnfocusPet", model)
            end)
            -- halloween11 (the game, the user petted by hand; 7v): FocusPet -> 3.3 s -> ReplicateActivePerformances(pet,
            -- {FocusPet, Petting}) -> 3.5 s -> {FocusPet, PettingHappy} -> 1.2 s -> {FocusPet} + PetPetted +
            -- ProgressPetMeAilment -> completed (8.1 s after FocusPet). Live 1.1.1: without the performance steps it
            -- never completed (9 tries).
            local function completed()
                return ctx.completedSince("pet_me", "pet", petEntry.petUnique)
            end
            if ctx.waitUntil(completed, 3.3) then
                return true
            end
            ctx.interaction:send("PetPerformance", model, { FocusPet = true, Petting = true })
            if ctx.waitUntil(completed, 3.5) then
                return true
            end
            ctx.interaction:send("PetPerformance", model, { FocusPet = true, PettingHappy = true })
            if ctx.waitUntil(completed, 1.2) then
                return true
            end
            ctx.interaction:send("PetPerformance", model, { FocusPet = true })
            ctx.interaction:send("PetPetted", petEntry.petUnique, Players.LocalPlayer)
            ctx.interaction:send("ProgressPetMe", petEntry.petUnique)
            if ctx.waitUntil(function()
                return ctx.completedSince("pet_me", "pet", petEntry.petUnique)
            end, 6) then
                return true
            end
            return false, "no completion after petting"
        end,
    }

    -- Location needs: go there, check the need STARTED (rate > 0), then wait until it is completed.
    local LOCATION_START_SECONDS = 10
    local LOCATION_EXTRA_SECONDS = 20
    -- Live 1.1.0 (3 accounts): bored STARTED where I already was on MainMap (account A 22:23:20 at the spawn, account B
    -- 22:23:45) and stopped the same second the spot teleport moved me; the teleport was then followed by a character
    -- reset (pet unequipped, needs resent, sent home). So a spot need first waits here before any move.
    local SPOT_WAIT_BEFORE_MOVE_SECONDS = 6
    -- Live 1.1.0: leaving a shop with our door options left the character at (-5986, -9011) (4 of 5 exits, BabyShop and
    -- CampingShop alike) = where the building's interior was, not on MainMap; ~6 s later the game reset the character.
    -- MainMap spots/doors are all within x -800..100, z -1900..-1000.
    local isOnMainMapArea = GameConstants.isOnMainMapArea
    Tasks._isOnMainMapArea = isOnMainMapArea

    -- Waits for my character's root part (the server cannot equip a pet without it: live 1.1.1, 61x
    -- "EquipLogicDB:395: attempt to perform arithmetic (add) on nil and Vector3" right after a character reset).
    local function waitForCharacter(ctx, seconds)
        return ctx.waitUntil(function()
            local character = Players.LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            return root ~= nil
        end, seconds)
    end

    -- Equip the pet again (the game's own call at spawn), verified by my data. Used inside tasks too.
    local function equipPetAgain(ctx, unique)
        if not unique then
            return false, "no pet known"
        end
        if not waitForCharacter(ctx, 10) then
            return false, "no character"
        end
        task.wait(2) -- the character was just (re)loaded
        local sent, reason = ctx.interaction:send("EquipItem", unique, { equip_as_last = true })
        if not sent then
            return false, "Equip failed: " .. tostring(reason)
        end
        local function equipped()
            local count = ctx.gameData:equippedPetCount()
            return ctx.gameData:isPetEquipped(unique) and count > 0
        end
        if ctx.waitUntil(equipped, 8) then
            task.wait(1)
            if equipped() then
                return true
            end
            return false, "the pet was equipped, then gone again"
        end
        return false, "the pet did not appear as equipped"
    end
    Tasks._equipPetAgain = equipPetAgain

    -- Live 1.3.0: going home by respawn reloads my character and the pet ("pets: none"); the next pet task then failed at
    -- once: "no model to put on the basicbed" 17x, toilet / shower 10x, "no pet wrapper" 6x. Wait for the game to equip
    -- the pet again (4 s), else equip it myself, then wait for its model (10 s).
    ensurePetModel = function(ctx, unique)
        local model, reason = ctx.petLocator:findModel(unique)
        if model then
            return model
        end
        if ctx.gameData and not ctx.gameData:isPetEquipped(unique) then
            ctx.waitUntil(function()
                return ctx.gameData:isPetEquipped(unique)
            end, 4)
            if not ctx.gameData:isPetEquipped(unique) then
                ctx.logger:info("Tasks", "Pet not equipped after the trip: equipping it before using it")
                equipPetAgain(ctx, unique)
            end
        end
        ctx.waitUntil(function()
            model, reason = ctx.petLocator:findModel(unique)
            return model ~= nil
        end, 10)
        return model, reason
    end

    -- A pet need can vanish from my list only because the pet was UNEQUIPPED (needs of unequipped pets are ignored),
    -- live 1.1.0: "sick (pet) Done in 0.3 s" while "pets: none". That is not a completion.
    local function petDroppedDuringTask(ctx, group)
        if not group.petEntry or not ctx.gameData then
            return false
        end
        local count, known = ctx.gameData:equippedPetCount()
        return known and count == 0
    end

    Tasks.location = {
        id = "location",
        handles = function(kind)
            return GameConstants.LocationForAilment[kind] ~= nil
        end,
        timeoutSeconds = 180,
        run = function(ctx, group, attempt)
            local destination = GameConstants.LocationForAilment[group.kind]
            local stoodUp, standReason = standUp(ctx)
            if not stoodUp then
                return false, standReason
            end
            if not group.anyInProgress then
                local ok, reason = ctx.travel:goTo(destination)
                if not ok then
                    return false, "travel: " .. tostring(reason)
                end
                local spotName = GameConstants.SpotForAilment[group.kind]
                -- 1.1.1: the shop-door route is used only with Farm.SpotTravel = "door" (live 1.1.0: our door options left
                -- the character outside MainMap 4 of 5 times, then a reset). Back as the alternate route once the exact
                -- door options of the game are known.
                local door = spotName and ctx.farmConfig.SpotTravel == "door" and GameConstants.SpotDoor[spotName] or nil
                local useTeleport = spotName and ctx.farmConfig.SpotTravel == "teleport"
                -- Give the need a chance to start where I am (bored did at the MainMap spawn) before moving at all.
                if spotName then
                    local function startedHere()
                        local current = ctx.currentGroup(group.kind)
                        return current == nil or current.anyInProgress
                    end
                    if ctx.waitUntil(startedHere, SPOT_WAIT_BEFORE_MOVE_SECONDS) then
                        ctx.logger:info("Tasks", group.kind .. " started where I am: not moving")
                        useTeleport, door = false, nil
                    end
                end
                if useTeleport then
                    task.wait(1)
                    local moved, moveReason = ctx.interaction:teleportTo(spotName)
                    ctx.logger:info("Tasks", "Teleport to " .. spotName .. ": " .. (moved and "ok" or tostring(moveReason)))
                    if moved then
                        door = nil
                        -- User (the other hub's rule): the pet unequipped right after a teleport = I teleported but the
                        -- game did not load it (live: reset). Equip the pet again and teleport once more.
                        if group.petEntry and ctx.waitUntil(function()
                            local current = ctx.currentGroup(group.kind)
                            return petDroppedDuringTask(ctx, group) or (current ~= nil and current.anyInProgress)
                        end, 8) and petDroppedDuringTask(ctx, group) then
                            ctx.logger:info("Tasks", "Pet unequipped after the teleport (map not loaded): equipping it and teleporting again")
                            equipPetAgain(ctx, group.petEntry.petUnique)
                            moved, moveReason = ctx.interaction:teleportTo(spotName)
                            ctx.logger:info("Tasks", "Teleport again to " .. spotName .. ": " .. (moved and "ok" or tostring(moveReason)))
                        end
                    end
                end
                if door then
                    -- Enter the nearest shop and leave through its door (the game puts me at that door).
                    local inOk = ctx.travel:goTo(door.place)
                    if inOk then
                        task.wait(1)
                        local outOk, outReason = ctx.travel:exitToMainMap()
                        if not outOk then
                            ok, reason = ctx.travel:goTo(destination)
                            if not ok then
                                return false, "travel after " .. tostring(outReason) .. ": " .. tostring(reason)
                            end
                        end
                    end
                    local character = Players.LocalPlayer.Character
                    local root = character and character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local p = root.Position
                        local near = math.sqrt((p.X - door.exit.x) ^ 2 + (p.Z - door.exit.z) ^ 2) < 60
                        ctx.logger:info("Tasks", string.format("After the %s door: at (%.0f, %.0f), %s", door.place, p.X, p.Z,
                            near and "at the door" or "NOT at the door"))
                        if not isOnMainMapArea(p) then
                            ctx.logger:warn("Tasks", string.format("After the %s door I am OUTSIDE MainMap (%.0f, %.0f): the"
                                .. " game did not place me (white-screen state)", door.place, p.X, p.Z))
                            return false, "the door exit left me outside MainMap"
                        end
                    end
                end
                -- User rule (2026-09-28): the character never walks except for the walk need. Spot needs are tried
                -- from the shop door only; if the need does not start there it fails (3x -> off for the session).
                local function hasStarted()
                    local current = ctx.currentGroup(group.kind)
                    return current == nil or current.anyInProgress
                end
                local talk = GameConstants.InteriorTalkForAilment[group.kind]
                local started
                if talk then
                    -- sick: the first one starts on arrival; later ones need the doctor (live: "did not start").
                    started = ctx.waitUntil(hasStarted, 4)
                    if not started then
                        local interior = ctx.gameData:get(GameConstants.DataKeys.Interior)
                        local key
                        for furnitureKey, piece in pairs(type(interior) == "table" and type(interior.furniture) == "table"
                            and interior.furniture or {}) do
                            if type(piece) == "table" and piece.id == talk.furniture then
                                key = furnitureKey
                            end
                        end
                        if key then
                            ctx.logger:info("Tasks", "Talking to the " .. talk.furniture .. " (" .. key .. ")")
                            ctx.interaction:send("ActivateInteriorFurniture", key, talk.use, talk.choice, Players.LocalPlayer.Character)
                        else
                            ctx.logger:warn("Tasks", "No " .. talk.furniture .. " in " .. destination)
                        end
                    end
                end
                started = started or ctx.waitUntil(hasStarted, LOCATION_START_SECONDS)
                if not started then
                    return false, "arrived at " .. destination .. " but the need did not start"
                end
            end
            -- Live 1.1.1 (85 of 86 trips that LEFT HOME, 3 accounts): ~7 s after arriving the character is reset and
            -- the pet unequipped; the need itself keeps running at the place. So the pet is equipped again HERE (up to
            -- 2 times) and the wait goes on, instead of failing and leaving (was 22-34 failures per account in 7 h).
            local reequips = 0
            local function handleDrop()
                if not petDroppedDuringTask(ctx, group) then
                    return "no"
                end
                if reequips >= 2 then
                    return "fail"
                end
                reequips += 1
                ctx.logger:info("Tasks", "Your pet was unequipped at " .. destination .. ": equipping it again, then waiting")
                local ok, reason = equipPetAgain(ctx, group.petEntry.petUnique)
                if not ok then
                    ctx.logger:warn("Tasks", "Equipping the pet again failed: " .. tostring(reason))
                end
                return "again"
            end
            local waited = 0
            local extended = false
            local taskStart = Util.now() - 1
            local current = ctx.currentGroup(group.kind)
            while true do
                if current == nil then
                    local drop = handleDrop()
                    if drop == "fail" then
                        return false, "the pet was unequipped (its need is hidden, not completed)"
                    elseif drop == "no" then
                        -- Live 1.2.1: the reset REMOVES the baby's need and re-adds it 1 s later; that was "Done: salon
                        -- in 10.9 s" with no reward. Done only with the game's completion event.
                        if ctx.kindCompletedSince and not ctx.kindCompletedSince(group.kind, taskStart) then
                            ctx.waitUntil(function()
                                return ctx.kindCompletedSince(group.kind, taskStart) or ctx.currentGroup(group.kind) ~= nil
                            end, 6)
                            if not ctx.kindCompletedSince(group.kind, taskStart) then
                                if ctx.currentGroup(group.kind) ~= nil then
                                    ctx.logger:info("Tasks", group.kind .. " was removed and re-added (reset): still waiting")
                                    current = ctx.currentGroup(group.kind)
                                    continue
                                end
                                return false, group.kind .. " vanished without a completion (expired?)"
                            end
                        end
                        return true -- completed
                    end
                    current = ctx.currentGroup(group.kind)
                else
                    local expected = current.maxRate > 0 and (1 / current.maxRate) or 50
                    local limit = expected + LOCATION_EXTRA_SECONDS - waited
                    if limit <= 0 then
                        return false, group.kind .. " did not complete in time"
                    end
                    ctx.logger:info("Tasks", string.format("Waiting at %s for %s (about %d s)", destination, group.kind, math.floor(expected + 0.5)))
                    local t0 = Util.now()
                    local gone = ctx.waitUntil(function()
                        return ctx.isKindGone(group.kind)
                    end, limit)
                    waited += math.max(Util.now() - t0, 0)
                    if not gone then
                        -- Live 1.5.1 (camping 4 done / 18 failed): the baby finished, the pet's part started ~25 s later
                        -- (still in progress) and the wait ended 4 s before it would have completed. One extension while
                        -- the game still shows progress.
                        local still = ctx.currentGroup(group.kind)
                        if not extended and still and still.anyInProgress then
                            extended = true
                            local more = (still.maxRate > 0 and (1 / still.maxRate) or 50) + 10
                            ctx.logger:info("Tasks", string.format("%s still in progress: waiting %d s more", group.kind, math.floor(more)))
                            if ctx.waitUntil(function()
                                return ctx.isKindGone(group.kind)
                            end, more) then
                                current = nil
                                continue
                            end
                        end
                        return false, group.kind .. " did not complete in time"
                    end
                    current = nil
                end
            end
        end,
    }

    -- Furniture needs (sleepy, dirty, toilet): go home, find MY furniture of a verified kind, then for each owner
    -- (pet first, then baby, like the game did in watch5): ActivateFurniture -> the need must START within
    -- 5 s -> it must be completed within 1/rate + 10 s.
    local FURNITURE_START_SECONDS = 5
    local FURNITURE_EXTRA_SECONDS = 10

    Tasks.furniture = {
        id = "furniture",
        handles = function(kind)
            return GameConstants.FurnitureForAilment[kind] ~= nil
        end,
        timeoutSeconds = 110,
        run = function(ctx, group)
            local kinds = GameConstants.FurnitureForAilment[group.kind]
            local stoodUp, standReason = standUp(ctx)
            if not stoodUp then
                return false, standReason
            end
            if not ctx.travel:isAt(GameConstants.HouseInteriorName) then
                local ok, reason = ctx.travel:goTo(GameConstants.HouseInteriorName)
                if not ok then
                    return false, "going home: " .. tostring(reason)
                end
            end
            local spot, spotReason = nil, nil
            ctx.waitUntil(function()
                spot, spotReason = ctx.furniture:findSpot(kinds)
                return spot ~= nil
            end, 10)
            if not spot then
                return false, tostring(spotReason)
            end

            local ordered = table.clone(group.entries)
            table.sort(ordered, function(a, b)
                return a.owner == "pet" and b.owner ~= "pet"
            end)
            -- Live 1.4.3 (2 new accounts): the baby's dirty picked the pet-only cheap_pet_bathtub_tutorial (3x -> dirty
            -- disabled) although a modernshower was there. The baby gets its own spot without pet-only furniture.
            local babySpot
            if GameConstants.PetOnlyFurniture[spot.kind] then
                local babyKinds = {}
                for _, k in ipairs(kinds) do
                    if not GameConstants.PetOnlyFurniture[k] then
                        table.insert(babyKinds, k)
                    end
                end
                if #babyKinds > 0 then
                    ctx.waitUntil(function()
                        babySpot = ctx.furniture:findSpot(babyKinds)
                        return babySpot ~= nil
                    end, 10)
                end
            end
            local petSpot = spot
            for _, entry in ipairs(ordered) do
                local spot = (entry.owner == "baby" and babySpot) or petSpot
                local label = entry.owner == "baby" and "baby" or ("pet " .. tostring(entry.petKind or "?"))
                local current = ctx.findEntry(group.kind, entry.owner, entry.petUnique)
                if current then
                    if not current.inProgress then
                        local target
                        if entry.owner == "pet" then
                            target = ensurePetModel(ctx, entry.petUnique)
                        else
                            target = Players.LocalPlayer.Character
                        end
                        if not target then
                            return false, "no model to put on the " .. spot.kind .. " (" .. label .. ")"
                        end
                        if entry.owner == "baby" and GameConstants.PetOnlyFurniture[spot.kind] then
                            return false, "the " .. spot.kind .. " is only for pets (baby " .. group.kind .. ")"
                        end
                        if entry.owner == "pet" then
                            local off, offReason = petOffFurniture(ctx, entry.petUnique)
                            if not off then
                                return false, offReason
                            end
                        end
                        ctx.logger:info("Tasks", string.format("Using %s %s for %s", spot.kind, spot.key, label))
                        local ok, reason = ctx.interaction:send("ActivateFurniture", Players.LocalPlayer, spot.key, spot.useName,
                            { cframe = spot.cframe }, target)
                        if not ok then
                            return false, "ActivateFurniture failed: " .. tostring(reason)
                        end
                        local started = ctx.waitUntil(function()
                            local now = ctx.findEntry(group.kind, entry.owner, entry.petUnique)
                            return now == nil or now.inProgress
                        end, FURNITURE_START_SECONDS)
                        if not started then
                            return false, "used the " .. spot.kind .. " but the " .. label .. " need did not start"
                        end
                    end
                    local now = ctx.findEntry(group.kind, entry.owner, entry.petUnique)
                    local expected = (now and now.rate > 0) and (1 / now.rate) or 15
                    if not ctx.waitUntil(function()
                        return ctx.findEntry(group.kind, entry.owner, entry.petUnique) == nil
                    end, expected + FURNITURE_EXTRA_SECONDS) then
                        return false, label .. " " .. group.kind .. " did not complete in time"
                    end
                    -- Get off the furniture (watch7: the pet leaves the toilet by itself; the character does not).
                    if entry.owner == "baby" then
                        ctx.waitUntil(function()
                            return not ctx.gameData:isSitting()
                        end, 1)
                        local up, upReason = standUp(ctx)
                        if not up then
                            return false, upReason
                        end
                    else
                        local pid = ctx.petLocator:getStreamingId(entry.petUnique)
                        local function petStillOn()
                            for _, who in ipairs(occupants(ctx, spot.key)) do
                                if who == pid then
                                    return true
                                end
                            end
                            return false
                        end
                        if pid and not ctx.waitUntil(function()
                            return not petStillOn()
                        end, 2) then
                            ctx.logger:info("Tasks", "Your pet is still on the " .. spot.kind .. ": getting it off")
                            ctx.interaction:send("ExitFurnitureUseStates", entry.petUnique)
                            if not ctx.waitUntil(function()
                                return not petStillOn()
                            end, 4) then
                                return false, "pet is still on the " .. spot.kind
                            end
                        end
                    end
                end
            end
            return true
        end,
    }

    -- Pet objects (food given to a pet, a thrown toy) appear in workspace.PetObjects (watch7).
    local function petObjectsSnapshot()
        local folder = workspace:FindFirstChild(GameConstants.PetObjectsFolderName)
        local set = {}
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                set[child] = true
            end
        end
        return set
    end
    local function newPetObject(before)
        local folder = workspace:FindFirstChild(GameConstants.PetObjectsFolderName)
        if not folder then
            return nil
        end
        for _, child in ipairs(folder:GetChildren()) do
            if not before[child] then
                return child
            end
        end
        return nil
    end

    -- A usable item for the need, buying 1 water first when allowed and nothing is left.
    local function pickItem(ctx, kind)
        local ids = GameConstants.ItemsForAilment[kind]
        local found = ctx.gameData:findItems(GameConstants.ItemCategory, ids)
        if found[1] then
            return found[1]
        end
        local buy = GameConstants.BuyForAilment[kind]
        if not (buy and ctx.farmConfig[buy.setting]) then
            return nil, "no " .. table.concat(ids, " / ") .. " in your backpack"
        end
        for _, id in ipairs(buy.ids) do
            local buysThisSession = ctx.gameData.buysThisSession or 0 -- per GameData = per session
            local limit = ctx.farmConfig.MaxBuysPerSession -- 0 or less = no limit (user's choice, 2026-09-28)
            if type(limit) == "number" and limit > 0 and buysThisSession >= limit then
                return nil, "purchase limit reached (" .. limit .. " this session)"
            end
            buysThisSession += 1
            ctx.gameData.buysThisSession = buysThisSession
            local bucksBefore = ctx.gameData:get(GameConstants.DataKeys.Money)
            ctx.logger:info("Tasks", string.format("Nothing for %s: buying 1 %s (purchase %d this session)", kind, id, buysThisSession))
            ctx.interaction:send("BuyItem", buy.category, id, table.clone(buy.options))
            local bought
            ctx.waitUntil(function()
                bought = ctx.gameData:findItems(GameConstants.ItemCategory, ids)[1]
                return bought ~= nil
            end, 6)
            if bought then
                local bucksAfter = ctx.gameData:get(GameConstants.DataKeys.Money)
                if type(bucksBefore) == "number" and type(bucksAfter) == "number" then
                    ctx.logger:info("Tasks", string.format("Bought %s for %d Bucks", id, bucksBefore - bucksAfter))
                end
                return bought
            end
            ctx.logger:warn("Tasks", "Bought " .. id .. " but it did not appear in your backpack")
        end
        return nil, "could not buy " .. table.concat(buy.ids, " / ")
    end

    -- Pet: Equip -> FocusPet -> START -> CreatePetObject(type 2) -> Unequip; the game's pet eats it
    -- (ConsumeFoodObject). If the game does not send that within 10 s we send it for the new PetObject.
    local PET_EAT_SECONDS = 10

    -- Same calls for any item the pet takes from my hand (food, drink, age potion; halloween12 2026-10-04: the game
    -- used exactly this flow for pet_age_potion / pet_bonus_bucks_potion / cure_all_potion). done() verifies.
    function Tasks.givePetItem(ctx, petUnique, item, done, label)
        local model, reason = ensurePetModel(ctx, petUnique)
        if not model then
            return false, "pet model: " .. tostring(reason)
        end
        local before = petObjectsSnapshot()
        local held = true
        ctx.maid:Give(function()
            if held then
                ctx.interaction:send("UnequipItem", item.unique, nil)
            end
        end)
        ctx.logger:info("Tasks", string.format("Giving %s to your pet (%s)", item.id, label))
        ctx.interaction:send("EquipItem", item.unique, {})
        task.wait(0.5)
        ctx.interaction:send("FocusPet", model)
        ctx.interaction:send("UseTool", item.unique, "START")
        local created, createAnswer = ctx.interaction:send("CreatePetObject", GameConstants.FoodObjectCreator,
            { additional_consume_uniques = {}, pet_unique = petUnique, unique_id = item.unique })
        ctx.interaction:send("UnequipItem", item.unique, nil)
        held = false
        ctx.interaction:send("UnfocusPet", model)
        if not created then
            -- Public reports: "PetObjectHelper:135: attempt to index nil with 'entry'" = the server refused the item
            return false, string.format("the game refused %s for %s (age %s): %s", item.id,
                tostring(ctx.gameData:getPetKind(petUnique)), tostring(ctx.gameData:petAge(petUnique)), tostring(createAnswer))
        end
        if ctx.waitUntil(done, PET_EAT_SECONDS) then
            return true
        end
        local object = newPetObject(before)
        if not object then
            return false, "no object appeared for your pet"
        end
        ctx.logger:info("Tasks", "Your pet did not take it by itself: sending ConsumeFoodObject")
        ctx.interaction:send("ConsumeFoodObject", object, petUnique)
        if ctx.waitUntil(done, 5) then
            return true
        end
        return false, label .. " not done after giving " .. item.id
    end

    local function feedPet(ctx, kind, entry, item)
        local model, reason = ensurePetModel(ctx, entry.petUnique)
        if not model then
            return false, "pet model: " .. tostring(reason)
        end
        local before = petObjectsSnapshot()
        local held = true
        ctx.maid:Give(function()
            if held then
                ctx.interaction:send("UnequipItem", item.unique, nil)
            end
        end)
        ctx.logger:info("Tasks", string.format("Giving %s to your pet (%s)", item.id, kind))
        ctx.interaction:send("EquipItem", item.unique, {})
        task.wait(0.5)
        ctx.interaction:send("FocusPet", model)
        ctx.interaction:send("UseTool", item.unique, "START")
        ctx.interaction:send("CreatePetObject", GameConstants.FoodObjectCreator,
            { additional_consume_uniques = {}, pet_unique = entry.petUnique, unique_id = item.unique })
        ctx.interaction:send("UnequipItem", item.unique, nil)
        held = false
        ctx.interaction:send("UnfocusPet", model)
        local function done()
            return ctx.completedSince(kind, "pet", entry.petUnique) or ctx.findEntry(kind, "pet", entry.petUnique) == nil
        end
        if ctx.waitUntil(done, PET_EAT_SECONDS) then
            return true
        end
        local object = newPetObject(before)
        if not object then
            return false, "no food object appeared for your pet"
        end
        ctx.logger:info("Tasks", "Your pet did not eat by itself: sending ConsumeFoodObject")
        ctx.interaction:send("ConsumeFoodObject", object, entry.petUnique)
        if ctx.waitUntil(done, 5) then
            return true
        end
        return false, "pet " .. kind .. " not completed after feeding"
    end

    -- Baby: Equip, then START / END until uses_left drops to 0 or the need completes, then Unequip (watch4, watch7).
    local BABY_HOLD_SECONDS = 1.5

    local function feedBaby(ctx, kind, item)
        local held = true
        ctx.maid:Give(function()
            if held then
                ctx.interaction:send("UnequipItem", item.unique, nil)
            end
        end)
        ctx.logger:info("Tasks", string.format("Baby uses %s (%s)", item.id, kind))
        ctx.interaction:send("EquipItem", item.unique, {})
        task.wait(0.5)
        local function done()
            return ctx.completedSince(kind, "baby", nil) or ctx.findEntry(kind, "baby", nil) == nil
        end
        for _ = 1, 12 do
            if done() then
                break
            end
            local usesBefore = ctx.gameData:itemUsesLeft(GameConstants.ItemCategory, item.unique)
            if usesBefore == nil then
                break -- item used up
            end
            ctx.interaction:send("UseTool", item.unique, "START")
            task.wait(BABY_HOLD_SECONDS)
            ctx.interaction:send("UseTool", item.unique, "END", nil)
            if not ctx.waitUntil(function()
                local now = ctx.gameData:itemUsesLeft(GameConstants.ItemCategory, item.unique)
                return done() or now == nil or now < usesBefore
            end, 3) then
                return false, item.id .. ": uses_left did not go down"
            end
            task.wait(0.3)
        end
        if ctx.gameData:itemUsesLeft(GameConstants.ItemCategory, item.unique) ~= nil then
            ctx.interaction:send("UnequipItem", item.unique, nil)
        end
        held = false
        ctx.waitUntil(done, 3)
        return done()
    end

    -- Pet hungry on MY free food bowl (watch8): go home, ActivateFurniture(UseBlock, pet) -> rate 1/7 -> completed.
    -- Returns true (done), false + reason (failed), or nil (no bowl in my house: use an item instead).
    local function bowlForPet(ctx, kind, entry)
        if not ctx.travel:isAt(GameConstants.HouseInteriorName) then
            local ok, reason = ctx.travel:goTo(GameConstants.HouseInteriorName)
            if not ok then
                return false, "going home: " .. tostring(reason)
            end
        end
        local spot
        ctx.waitUntil(function()
            spot = ctx.furniture:findSpot(GameConstants.PetFoodBowls)
            return spot ~= nil
        end, 5)
        if not spot then
            return nil
        end
        local model, reason = ensurePetModel(ctx, entry.petUnique)
        if not model then
            return false, "pet model: " .. tostring(reason)
        end
        local off, offReason = petOffFurniture(ctx, entry.petUnique)
        if not off then
            return false, offReason
        end
        ctx.logger:info("Tasks", string.format("Using food bowl %s for your pet", spot.key))
        local ok, sendReason = ctx.interaction:send("ActivateFurniture", Players.LocalPlayer, spot.key, spot.useName, { cframe = spot.cframe }, model)
        if not ok then
            return false, "ActivateFurniture failed: " .. tostring(sendReason)
        end
        if not ctx.waitUntil(function()
            local now = ctx.findEntry(kind, "pet", entry.petUnique)
            return now == nil or now.inProgress
        end, 5) then
            return false, "used the food bowl but hungry did not start"
        end
        local now = ctx.findEntry(kind, "pet", entry.petUnique)
        local expected = (now and now.rate > 0) and (1 / now.rate) or 7
        if ctx.waitUntil(function()
            return ctx.findEntry(kind, "pet", entry.petUnique) == nil
        end, expected + 10) then
            return true
        end
        return false, "pet hungry did not complete at the food bowl"
    end

    -- hungry, thirsty: pet first, then baby. A baby may need a second item when the first runs out.
    Tasks.feed = {
        id = "feed",
        handles = function(kind)
            return GameConstants.ItemsForAilment[kind] ~= nil
        end,
        timeoutSeconds = 120,
        run = function(ctx, group)
            local stoodUp, standReason = standUp(ctx)
            if not stoodUp then
                return false, standReason
            end
            local ordered = table.clone(group.entries)
            table.sort(ordered, function(a, b)
                return a.owner == "pet" and b.owner ~= "pet"
            end)
            for _, entry in ipairs(ordered) do
                for _ = 1, 3 do
                    if not ctx.findEntry(group.kind, entry.owner, entry.petUnique) then
                        break
                    end
                    if entry.owner == "pet" and group.kind == "hungry" and not entry.triedBowl then
                        entry.triedBowl = true
                        local bowlOk, bowlReason = bowlForPet(ctx, group.kind, entry)
                        if bowlOk == false then
                            return false, bowlReason
                        elseif bowlOk == true then
                            break
                        end
                    end
                    local item, reason = pickItem(ctx, group.kind)
                    if not item then
                        return false, reason
                    end
                    local ok, feedReason
                    if entry.owner == "pet" then
                        ok, feedReason = feedPet(ctx, group.kind, entry, item)
                        if not ok then
                            return false, feedReason
                        end
                    else
                        ok, feedReason = feedBaby(ctx, group.kind, item)
                        if feedReason then
                            return false, feedReason
                        end
                    end
                end
                if ctx.findEntry(group.kind, entry.owner, entry.petUnique) then
                    return false, (entry.owner == "baby" and "baby" or "pet") .. " " .. group.kind .. " still there after 3 items"
                end
            end
            return true
        end,
    }

    -- play (pet only): throw my squeaky bone; each catch raises the need's progress by 1/3 (watch7).
    -- If the game's pet does not catch it within 6 s we send GrabPetObject for the new PetObject.
    local THROW_CATCH_SECONDS = 6

    Tasks.play = {
        id = "play",
        handles = function(kind)
            return kind == "play"
        end,
        timeoutSeconds = 80,
        run = function(ctx, group)
            local entry = group.petEntry
            if not entry then
                return false, "play is only for pets"
            end
            local stoodUp, standReason = standUp(ctx)
            if not stoodUp then
                return false, standReason
            end
            local toy = ctx.gameData:findItems(GameConstants.ToyCategory, GameConstants.ToysForPlay)[1]
            if not toy then
                return false, "no " .. table.concat(GameConstants.ToysForPlay, " / ") .. " in your backpack"
            end
            local model, reason = ensurePetModel(ctx, entry.petUnique)
            if not model then
                return false, "pet model: " .. tostring(reason)
            end
            local petHasToy = false
            ctx.maid:Give(function()
                if petHasToy then
                    ctx.interaction:send("EquipItem", toy.unique, {})
                    ctx.interaction:send("DropPetObject", model)
                    ctx.interaction:send("UnequipItem", toy.unique, nil)
                end
            end)
            local function current()
                return ctx.findEntry("play", "pet", entry.petUnique)
            end
            for throw = 1, 6 do
                local now = current()
                if not now or ctx.completedSince("play", "pet", entry.petUnique) then
                    return true
                end
                local progressBefore = now.progress or 0
                local before = petObjectsSnapshot()
                ctx.logger:info("Tasks", string.format("Throwing %s (throw %d, progress %d%%)", toy.id, throw, math.floor(progressBefore * 100 + 0.5)))
                ctx.interaction:send("EquipItem", toy.unique, {})
                if petHasToy then
                    ctx.interaction:send("DropPetObject", model)
                    petHasToy = false
                end
                task.wait(0.5)
                ctx.interaction:send("UseTool", toy.unique, "START")
                ctx.interaction:send("CreatePetObject", GameConstants.ToyObjectCreator,
                    { reaction_name = GameConstants.ThrowToyReaction, unique_id = toy.unique })
                ctx.interaction:send("UnequipItem", toy.unique, { from_throw_toy = true })
                ctx.interaction:send("UseTool", toy.unique, "END", nil)
                local function caught()
                    local after = current()
                    return after == nil or (after.progress or 0) > progressBefore
                end
                if not ctx.waitUntil(caught, THROW_CATCH_SECONDS) then
                    local object = newPetObject(before)
                    if not object then
                        return false, "no toy object appeared after the throw"
                    end
                    ctx.logger:info("Tasks", "Your pet did not catch the toy by itself: sending GrabPetObject")
                    ctx.interaction:send("GrabPetObject", model, object, nil)
                    if not ctx.waitUntil(caught, 4) then
                        return false, "play progress did not rise after throw " .. throw
                    end
                end
                petHasToy = true
                task.wait(1)
            end
            if current() then
                return false, "play not completed after 6 throws"
            end
            return true
        end,
    }

    -- mystery (pet): choose a need this script can do. Capture by the user (SimpleSpy, 2026-09-28):
    -- AilmentsAPI/ChooseMysteryAilment(petUnique, "mystery", 1, "cat_cafe"). Success = mystery gone AND the chosen
    -- need appears in my data; otherwise the next option is tried (max 3), then the task fails.
    Tasks.mystery = {
        id = "mystery",
        handles = function(kind)
            return kind == "mystery"
        end,
        timeoutSeconds = 60,
        run = function(ctx, group)
            local entry = group.petEntry
            if not entry then
                return false, "mystery is only handled for pets"
            end
            local offered = {}
            for _, kind in ipairs(entry.mysteryOptions or {}) do
                offered[kind] = true
            end
            local choices = {}
            for _, kind in ipairs(GameConstants.MysteryPreference) do
                local doable = kind ~= "mystery" and Tasks.findFor(kind) ~= nil and ctx.farmConfig.Tasks[kind] == true
                if doable and (entry.mysteryOptions == nil or offered[kind]) and not ctx.findEntry(kind, "pet", entry.petUnique) then
                    table.insert(choices, kind)
                end
            end
            if #choices == 0 then
                return false, "no doable need among the mystery options"
            end
            -- Live 0.8.2: with slot 1 only, toilet/thirsty/hungry were all refused on one pet. The capture chose card 1
            -- ("cat_cafe"): the 3rd argument is probably the card position, so each kind is tried on slots 1-3.
            -- Live 1.5.6 (night, 3 accounts): only 3 kinds were tried -> 9 of 14 mystery tasks failed when none of them was
            -- on the 3 cards. Now every doable kind is tried (2.5 s each) until 52 s are used.
            local started = Util.now()
            for index = 1, #choices do
                local kind = choices[index]
                for slot = 1, 3 do
                    if Util.now() - started > 52 then
                        return false, "mystery did not change into a chosen need"
                    end
                    ctx.logger:info("Tasks", string.format("Mystery: choosing %s (card %d)", kind, slot))
                    ctx.interaction:send("ChooseMystery", entry.petUnique, "mystery", slot, kind)
                    if ctx.waitUntil(function()
                        return ctx.findEntry("mystery", "pet", entry.petUnique) == nil
                            and ctx.findEntry(kind, "pet", entry.petUnique) ~= nil
                    end, 2.5) then
                        ctx.logger:info("Tasks", string.format("Mystery accepted: %s on card %d", kind, slot))
                        return true
                    end
                    if not ctx.findEntry("mystery", "pet", entry.petUnique) then
                        return true -- mystery turned into something else by itself (watch8 saw that too)
                    end
                end
            end
            return false, "mystery did not change into a chosen need"
        end,
    }

    -- walk / ride (pet): the need progresses only while the character moves with the pet (watch8_20260928_053142).
    -- walk: go to MainMap (open plaza) and walk long diagonal legs. ride: the same with MY stroller equipped and the pet
    -- sitting in it: Equip(stroller, {chars_to_sit = {<the pet's wrapper, char = its model>}}), ServerUseTool START/END
    -- now and then while walking (as the game did), then UnequipStroller() + Unequip(stroller, nil).
    local function movingNeed(kind)
        return {
            id = kind,
            handles = function(k)
                return k == kind
            end,
            timeoutSeconds = 170,
            run = function(ctx, group)
                local entry = group.petEntry
                if not entry then
                    return false, kind .. " is only for pets"
                end
                local stoodUp, standReason = standUp(ctx)
                if not stoodUp then
                    return false, standReason
                end
                if not ctx.travel:isAt("MainMap") then
                    local ok, reason = ctx.travel:goTo("MainMap")
                    if not ok then
                        return false, "travel: " .. tostring(reason)
                    end
                    task.wait(3)
                end
                local stroller
                if kind == "ride" then
                    local item = ctx.gameData:findItems(GameConstants.StrollerCategory, { "stroller-default" })[1]
                        or (function()
                            local inventory = ctx.gameData:get(GameConstants.DataKeys.Inventory)
                            for unique, it in pairs(type(inventory) == "table" and inventory.strollers or {}) do
                                if type(it) == "table" then
                                    return { unique = tostring(it.unique or unique), id = it.id }
                                end
                            end
                            return nil
                        end)()
                    if not item then
                        return false, "no stroller in your backpack"
                    end
                    -- Live 1.2.0: 8x "no pet wrapper for this pet yet" right after a re-equip: wait for it a little.
                    local model, reason
                    ctx.waitUntil(function()
                        model, reason = ctx.petLocator:findModel(entry.petUnique)
                        return model ~= nil
                    end, 8)
                    if not model then
                        return false, "pet model: " .. tostring(reason)
                    end
                    local wrappers = ctx.gameData:get(GameConstants.DataKeys.PetWrappers)
                    local sit
                    for _, wrapper in pairs(type(wrappers) == "table" and wrappers or {}) do
                        if type(wrapper) == "table" and wrapper.pet_unique == entry.petUnique then
                            sit = table.clone(wrapper)
                        end
                    end
                    if not sit then
                        return false, "no data for the pet"
                    end
                    sit.char = model
                    sit.controller = Players.LocalPlayer
                    sit.entity_controller = Players.LocalPlayer
                    sit.player = Players.LocalPlayer
                    stroller = item.unique
                    ctx.maid:Give(function()
                        ctx.interaction:send("UnequipStroller")
                        ctx.interaction:send("UnequipItem", stroller, nil)
                    end)
                    ctx.logger:info("Tasks", "Putting your pet in the stroller (" .. tostring(item.id) .. ")")
                    ctx.interaction:send("EquipItem", stroller, { chars_to_sit = { sit } })
                    task.wait(1)
                end
                -- User (2026-09-29): follow the need's progress live instead of walking a fixed time and then asking
                -- "done?". Every 2 s: the need's progress / running state, how far I moved, how far the pet is.
                -- Keep walking while it progresses; stalled for STALL s -> move once to an open spot (live 1.2.0: walk
                -- ran at once at the beach spot, never at the MainMap spawn), stalled again -> fail WITH the reason.
                local STALL = 15
                local unique = entry.petUnique
                local function now()
                    return ctx.findEntry(kind, "pet", unique)
                end
                local function gone()
                    return now() == nil and not petDroppedDuringTask(ctx, group)
                end
                local character = Players.LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                local lastPos = root and root.Position
                local moved, lastLog, sinceActive, elapsed = 0, 0, 0, 0
                local best = (now() or {}).progress or 0
                local lastUse = 0
                local function petDistance()
                    local model = ctx.petLocator:findModel(unique)
                    if not model or not root then
                        return nil
                    end
                    local ok, pos = pcall(function()
                        return model:GetPivot().Position
                    end)
                    if not ok or not pos then
                        return nil
                    end
                    return math.sqrt((pos.X - root.Position.X) ^ 2 + (pos.Z - root.Position.Z) ^ 2)
                end
                local function sample()
                    local e = now()
                    local progress = e and e.progress or best
                    local active = e ~= nil and (e.inProgress or progress > best + 1e-6)
                    if progress > best then
                        best = progress
                    end
                    if active then
                        sinceActive = 0
                    else
                        sinceActive += 2
                    end
                    return e, active
                end
                local stalled = false
                local tickCount = 0
                local function tick()
                    tickCount += 1
                    if stroller and os.clock() - lastUse > 2 then
                        lastUse = os.clock()
                        ctx.interaction:send("UseTool", stroller, "START")
                        ctx.interaction:send("UseTool", stroller, "END", nil)
                    end
                    if root and lastPos then
                        local p = root.Position
                        moved += math.sqrt((p.X - lastPos.X) ^ 2 + (p.Z - lastPos.Z) ^ 2)
                        lastPos = p
                    end
                    if tickCount % 4 == 0 then -- every 2 s
                        elapsed += 2
                        local e, active = sample()
                        if elapsed - lastLog >= 6 then
                            lastLog = elapsed
                            local d = petDistance()
                            local where = ""
                            if root then
                                local rp = root.Position
                                where = string.format(", at (%.0f, %.0f)%s", rp.X, rp.Z, isOnMainMapArea(rp) and "" or " NOT ON MAINMAP")
                            end
                            ctx.logger:info("Tasks", string.format("%s: progress %d%%, %s, moved %d studs, pet %s%s%s", kind,
                                math.floor(((e and e.progress) or best) * 100), active and "running" or "NOT running",
                                math.floor(moved), d and (math.floor(d) .. " studs away") or "not found", where,
                                (moved < 1 and ctx.interaction.walkDiag) and (" [not moving: " .. ctx.interaction.walkDiag .. "]") or ""))
                            moved = 0
                        end
                        if sinceActive >= STALL then
                            stalled = true
                        end
                    end
                end
                local function walkPhase(seconds)
                    stalled, sinceActive = false, 0
                    character = Players.LocalPlayer.Character
                    root = character and character:FindFirstChild("HumanoidRootPart")
                    lastPos = root and root.Position
                    return ctx.interaction:walkAround(seconds, function()
                        return gone() or stalled
                    end, tick)
                end
                walkPhase(75)
                if gone() then
                    return true
                end
                if stalled and GameConstants.Spots.beach_party then
                    ctx.logger:info("Tasks", kind .. " is not progressing here: moving to the open beach spot and walking there")
                    local teleported, why = ctx.interaction:teleportTo("beach_party")
                    ctx.logger:info("Tasks", "Teleport to beach_party: " .. (teleported and "ok" or tostring(why)))
                    if petDroppedDuringTask(ctx, group) or ctx.waitUntil(function()
                        return petDroppedDuringTask(ctx, group)
                    end, 5) then
                        equipPetAgain(ctx, unique)
                    end
                    walkPhase(60)
                    if gone() then
                        return true
                    end
                elseif not stalled then
                    -- still progressing when the time ran out: keep going
                    walkPhase(45)
                    if gone() then
                        return true
                    end
                end
                local e = now()
                if petDroppedDuringTask(ctx, group) then
                    return false, "the pet was unequipped while walking"
                end
                return false, string.format("%s stopped progressing (progress %d%%)", kind, math.floor(((e and e.progress) or best) * 100))
            end,
        }
    end
    Tasks.walk = movingNeed("walk")
    Tasks.ride = movingNeed("ride")

    -- recover: stuck on the place-changing screen -> the normal trip home (DoorEnter + SubscribeToHouse + SetLocation,
    -- with the "subscribing again" fallback). Success = my data says I am home.
    Tasks.recover = {
        id = "recover",
        handles = function()
            return false
        end,
        timeoutSeconds = 40,
        run = function(ctx)
            -- 1) respawn (user: this is what got a stuck client home), 2) else the normal trip home.
            ctx.logger:info("Tasks", "Recover: respawning")
            ctx.interaction:send("Respawn")
            if ctx.waitUntil(function()
                return ctx.travel:isAt(GameConstants.HouseInteriorName)
            end, 20) then
                return true
            end
            ctx.logger:info("Tasks", "Recover: respawn did not bring me home, travelling")
            local ok, reason = ctx.travel:goTo(GameConstants.HouseInteriorName)
            if not ok then
                return false, "recover: " .. tostring(reason)
            end
            return true
        end,
    }

    -- equip pet: the pet was unequipped live (e.g. right after the doctor), so pet needs were skipped for hours.
    -- The game equips a pet with ToolAPI/Equip(petUnique, {equip_as_last = true}) (watch7). Verified by equip_manager.
    Tasks.equipPet = {
        id = "equip_pet",
        handles = function()
            return false
        end,
        timeoutSeconds = 15,
        run = function(ctx, group)
            ctx.logger:info("Tasks", "Your pet is not equipped: equipping it again")
            local ok, reason = equipPetAgain(ctx, group.petUnique)
            if not ok and group.onFail then
                group.onFail()
            end
            return ok, reason
        end,
    }

    -- buy egg (user, 2026-10-01): no pet that still grows -> buy 1 egg of Farm.EggToBuy, verified by my backpack.
    Tasks.buyEgg = {
        name = "buy_egg",
        timeoutSeconds = 90,
        run = function(ctx, group)
            local id = ctx.farmConfig.EggToBuy or "cracked_egg"
            if GameConstants.NeverBuyEggs[id] then
                return false, id .. " costs Robux: never bought"
            end
            local known = false
            for _, egg in ipairs(GameConstants.Eggs) do
                known = known or egg == id
            end
            if not known then
                ctx.logger:warn("Tasks", "Farm.EggToBuy = " .. tostring(id) .. " is not in the egg list: trying it anyway")
            end
            local function tryBuy(where)
                local before = ctx.gameData:petUniquesOfKind(id)
                local bucks = ctx.gameData:get(GameConstants.DataKeys.Money)
                ctx.logger:info("Tasks", "No pet that still grows: buying 1 " .. id .. where)
                local sent, reason = ctx.interaction:send("BuyItem", GameConstants.EggCategory, id, { buy_count = 1 })
                if not sent then
                    ctx.logger:warn("Tasks", "BuyItem(" .. id .. ") failed: " .. tostring(reason))
                end
                local newUnique
                ctx.waitUntil(function()
                    for unique in pairs(ctx.gameData:petUniquesOfKind(id)) do
                        if not before[unique] then
                            newUnique = unique
                            return true
                        end
                    end
                    return false
                end, 8)
                if newUnique then
                    local after = ctx.gameData:get(GameConstants.DataKeys.Money)
                    ctx.logger:info("Tasks", string.format("Bought %s%s", id, (tonumber(bucks) and tonumber(after))
                        and string.format(" for %d Bucks", bucks - after) or ""))
                end
                return newUnique
            end
            local unique = tryBuy("")
            if not unique and ctx.travel:canGoTo("Nursery") then
                local ok, why = ctx.travel:goTo("Nursery")
                if not ok then
                    return false, "egg not bought, and the Nursery trip failed: " .. tostring(why)
                end
                unique = tryBuy(" in the Nursery")
            end
            if not unique then
                return false, "no " .. id .. " arrived in your backpack (not enough Bucks, or the shop call differs)"
            end
            if group and group.onBought then
                group.onBought()
            end
            return true
        end,
    }

    -- team: ChooseTeam("Babies", options) (watch4), verified by my data's team value.
    Tasks.team = {
        id = "team",
        timeoutSeconds = 25,
        run = function(ctx)
            local ok, reason = ctx.interaction:send("ChooseTeam", GameConstants.BabiesTeam, table.clone(GameConstants.ChooseTeamOptions))
            if not ok then
                return false, "ChooseTeam failed: " .. tostring(reason)
            end
            if ctx.waitUntil(function()
                return ctx.state:get("player.team") == GameConstants.BabiesTeam
            end, 10) then
                return true
            end
            return false, "team is still " .. tostring(ctx.state:get("player.team"))
        end,
    }

    -- Order matters only when two tasks could handle the same kind (they do not today).
    Tasks.ALL = { Tasks.pet_me, Tasks.location, Tasks.furniture, Tasks.feed, Tasks.play, Tasks.mystery, Tasks.walk, Tasks.ride }

    function Tasks.findFor(kind)
        for _, taskDefinition in ipairs(Tasks.ALL) do
            if taskDefinition.handles(kind) then
                return taskDefinition
            end
        end
        return nil
    end

    return Tasks
end

-- ─────────────────────────────── module: Game/Minigame ───────────────────────────────
__moduleSources["Game/Minigame"] = function(...)
    --[[
        Game/Minigame
        READ-ONLY watcher of the minigame messages the server sends to ME (MinigameAPI/MessageClient), for the
        Halloween 2026 Ghost Gallery (minigame id "ghost_clusters"). Recorded in halloween11/12 (11_GAME_FINDINGS 7v, 7w):
          ("ghost_clusters", "join_accepted", n, {})                         my join request was accepted
          ("ghost_clusters", "join_minigame", "ManorMinigameInterior::<id>", "ghost_clusters::<id>")   the round starts
          ("ghost_clusters::<id>", "enter_game", {intermission_end_time, end_time, boss_spawn_at, ...})
          ("ghost_clusters::<id>", "ghost_clusters_score", points)          points for my vacuuming
          ("ghost_clusters::<id>", "leave_game", {results = {...}, rewards = {{kind = "candy_2026", amount}}}, {...})
        Sends nothing.
    ]]

    local import = ...
    local Util = import("Core/Util")
    local GameConstants = import("Game/GameConstants")

    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local Minigame = {}
    Minigame.__index = Minigame

    function Minigame.new(logger)
        local self = setmetatable({}, Minigame)
        self._logger = logger
        self:reset()
        return self
    end

    -- Forgets everything about the previous round (called before a new join).
    function Minigame:reset()
        self.joinAcceptedAt = nil
        self.join = nil -- { interior, gameId, at }
        self.enter = nil -- { intermissionEnd, endTime, at }
        self.score = 0
        self.scoreCount = 0
        self.lastScoreAt = nil
        self.leave = nil -- { candy, results, at }
        -- halloween12: "ghost_clusters_cast_wave" lists props that are haunted now ({unique, haunted = true, spawn_size});
        -- vacuuming one -> "ghost_clusters_prop_progress" (unique, 0..1) -> "ghost_clusters_prop_resolved" (unique,
        -- hadGhost) -> a ghost of spawn_size appears; "ghost_clusters_prop_restored" (unique) later.
        self.haunted = {} -- [unique] = true
        self.propProgress = {} -- [unique] = last progress
        self.propsResolved = 0
        self.bossOut = false
    end

    -- Server clock (unix seconds), the clock the round times in my data use.
    function Minigame.serverNow()
        local ok, value = pcall(function()
            return workspace:GetServerTimeNow()
        end)
        if ok and type(value) == "number" then
            return value
        end
        return os.time()
    end

    local function isMine(gameKey)
        local id = GameConstants.Event.MinigameId
        return type(gameKey) == "string" and (gameKey == id or string.sub(gameKey, 1, #id + 2) == id .. "::")
    end

    -- Messages already understood or known as noise (halloween11/12); any other type is logged once per session.
    local KNOWN = {
        join_accepted = true, join_minigame = true, enter_game = true, ghost_clusters_score = true, leave_game = true,
        ghost_clusters_cast_wave = true, ghost_clusters_prop_progress = true, ghost_clusters_prop_resolved = true,
        ghost_clusters_prop_restored = true, ghost_clusters_boss_breakout = true, ghost_clusters_props = true,
        ghost_clusters_vacuum_beam = true, ghost_clusters_attack_windup = true, ghost_clusters_attack_fire = true,
        ghost_clusters_attack_end = true, ghost_clusters_tornado_catch = true, ghost_clusters_tornado_release = true,
    }

    local function short(value, depth)
        depth = depth or 0
        if type(value) == "table" then
            if depth >= 3 then
                return "{...}"
            end
            local parts, n = {}, 0
            for k, v in pairs(value) do
                n += 1
                if n > 12 then
                    table.insert(parts, "...")
                    break
                end
                table.insert(parts, tostring(k) .. "=" .. short(v, depth + 1))
            end
            return "{" .. table.concat(parts, ", ") .. "}"
        end
        return tostring(value)
    end

    function Minigame:_onMessage(gameKey, message, a, b)
        if not isMine(gameKey) then
            return
        end
        if type(message) == "string" and not KNOWN[message] then
            self._seenTypes = self._seenTypes or {}
            if not self._seenTypes[message] then
                self._seenTypes[message] = true
                self._logger:info("Minigame", "New message type: " .. message .. " " .. Util.truncate(short(a) .. " " .. short(b), 300))
            end
        end
        local now = Util.now()
        if message == "join_accepted" then
            self.joinAcceptedAt = now
        elseif message == "join_minigame" and type(b) == "string" then
            self.join = { interior = a, gameId = b, at = now }
            self._logger:info("Minigame", "Round starting: " .. tostring(b))
        elseif message == "enter_game" and type(a) == "table" then
            self.enter = { intermissionEnd = tonumber(a.intermission_end_time), endTime = tonumber(a.end_time), at = now }
        elseif message == "ghost_clusters_cast_wave" and type(a) == "table" then
            for _, prop in pairs(a) do
                if type(prop) == "table" and prop.haunted == true and prop.resolved ~= true and type(prop.unique) == "string" then
                    self.haunted[prop.unique] = true
                end
            end
        elseif message == "ghost_clusters_boss_breakout" then
            self.bossOut = true
            self._logger:info("Minigame", "Boss is out: guards first, then the boss")
        elseif message == "ghost_clusters_prop_progress" and type(a) == "string" then
            self.propProgress[a] = tonumber(b) or 0
        elseif message == "ghost_clusters_prop_resolved" and type(a) == "string" then
            self.haunted[a] = nil
            self.propsResolved += 1
        elseif message == "ghost_clusters_prop_restored" and type(a) == "string" then
            self.haunted[a] = nil
        elseif message == "ghost_clusters_score" and tonumber(a) then
            self.score += tonumber(a)
            self.scoreCount += 1
            self.lastScoreAt = now
        elseif message == "leave_game" then
            local candy = 0
            if type(a) == "table" and type(a.rewards) == "table" then
                for _, reward in pairs(a.rewards) do
                    if type(reward) == "table" and reward.kind == GameConstants.DataKeys.Candy then
                        candy += tonumber(reward.amount) or 0
                    end
                end
            end
            self.leave = { candy = candy, results = type(a) == "table" and a.results or nil, at = now }
            self._logger:info("Minigame", string.format("Round over: %d points from %d hits, reward %d candy", self.score,
                self.scoreCount, candy))
            -- Live 1.5.6: 12 of 57 rounds ended ~80 s in with 0 candy on several accounts at once; the key came at any
            -- score. The game's own round result says why (results, rewards, flags).
            self._logger:info("Minigame", "Round result: " .. Util.truncate(short(a) .. " | " .. short(b), 400))
        end
    end

    function Minigame:start(maid)
        local folder = ReplicatedStorage:FindFirstChild(GameConstants.Remotes.Folder)
        local remote = folder and folder:FindFirstChild(GameConstants.Remotes.MinigameMessage)
        if not (remote and remote:IsA("RemoteEvent")) then
            self._logger:warn("Minigame", GameConstants.Remotes.MinigameMessage .. " not found: Ghost Gallery is off")
            return false
        end
        maid:Give(remote.OnClientEvent:Connect(function(...)
            local ok, err = pcall(self._onMessage, self, ...)
            if not ok then
                self._logger:debug("Minigame", "message not understood: " .. tostring(err))
            end
        end))
        self.available = true
        return true
    end

    return Minigame
end

-- ─────────────────────────────── module: Game/EventTasks ───────────────────────────────
__moduleSources["Game/EventTasks"] = function(...)
    --[[
        Game/EventTasks
        Jobs that are not pet/baby needs (11_GAME_FINDINGS 7v, 7w, 7x). Same contract as Game/Tasks:
          run(ctx, group) -> true | false, reason        every step is verified by MY data (or the game's messages)

          pet_pen       claim the pen, take full grown pets out, fill free slots with pets that still grow (at home only)
          stray_cat     once a day: hold 1 water next to the Stray Cat and give it (+50 candy)
          crypt         a Rusty Key in the backpack: open the "ladder" grave of the current floor (read from my data)
          pigeon_nest   a Crypt Twig in the backpack: put it in the Hotel nest (8 build the nest)
          ghost_gallery join the Ghost Gallery round, vacuum ghosts, collect the candy reward

        Pure helpers (cryptPlan, nextRoundStart, penPlan, findGhosts) are exported for the tests.
    ]]

    local import = ...
    local Util = import("Core/Util")
    local GameConstants = import("Game/GameConstants")
    local Minigame = import("Game/Minigame")
    local Tasks = import("Game/Tasks")

    local EventTasks = {}

    local E = GameConstants.Event
    local KEYS = GameConstants.DataKeys
    local TOYS = GameConstants.ToyCategory

    local function count(map)
        local n = 0
        for _ in pairs(map) do
            n += 1
        end
        return n
    end

    local function sortedNumberKeys(map)
        local keys = {}
        for key in pairs(type(map) == "table" and map or {}) do
            if tonumber(key) then
                table.insert(keys, tonumber(key))
            end
        end
        table.sort(keys)
        return keys
    end

    -- Which grave to open next. Floors are cleared by opening their "ladder" grave; the last floor has none
    -- (then the most valuable unopened grave). Returns { floor, grave, reward } or nil, reason.
    function EventTasks.cryptPlan(crypt)
        if type(crypt) ~= "table" or type(crypt.floors) ~= "table" then
            return nil, "crypt data not known yet"
        end
        local opened = {}
        for _, id in pairs(type(crypt.opened) == "table" and crypt.opened or {}) do
            if tonumber(id) then
                opened[tonumber(id)] = true
            end
        end
        local function lookup(map, number)
            return map[number] or map[tostring(number)]
        end
        for _, floor in ipairs(sortedNumberKeys(crypt.floors)) do
            local graves = lookup(crypt.floors, floor)
            graves = type(graves) == "table" and graves.coffins
            if type(graves) == "table" then
                local ladder
                for _, index in ipairs(sortedNumberKeys(graves)) do
                    if lookup(graves, index) == E.Ladder then
                        ladder = index
                    end
                end
                if ladder then
                    if not opened[floor * E.OpenedIdPerFloor + ladder] then
                        return { floor = floor, grave = ladder, reward = E.Ladder }
                    end
                else
                    local best, bestValue
                    for _, index in ipairs(sortedNumberKeys(graves)) do
                        if not opened[floor * E.OpenedIdPerFloor + index] then
                            local value = E.GraveValue[lookup(graves, index)] or 0
                            if not best or value > bestValue then
                                best, bestValue = index, value
                            end
                        end
                    end
                    if best then
                        return { floor = floor, grave = best, reward = tostring(lookup(graves, best)) }
                    end
                    return { spider = true, floor = floor }
                end
            end
        end
        -- every floor's ladder is open: the bottom of the Crypt = the Mummy Spider (playadopt.me notes: 4 levels, then the
        -- spider; user 2026-10-04: claimed it by hand after floor 3 with ClaimTombSpider())
        if #sortedNumberKeys(crypt.floors) > 0 then
            return { spider = true }
        end
        return nil, "no Crypt floors in your data yet"
    end

    -- Quests that can be claimed now (dailies_manager, halloween12). Returns a list of { action, tab }.
    --   QuestClaim(tab): a daily of that tab has steps_completed >= steps_to_complete
    --   QuestTabReward(tab): the board reward is not claimed and no daily of the tab is left unfinished (ASSUMPTION;
    --   checked by my data after the claim)
    function EventTasks.questsToClaim(dailies)
        local list = {}
        local tabs = type(dailies) == "table" and type(dailies.serialized_tabs) == "table" and dailies.serialized_tabs or {}
        for _, tabName in ipairs(E.QuestTabs) do
            local tab = tabs[tabName]
            if type(tab) == "table" then
                local finished, unfinished = 0, 0
                for _, daily in pairs(type(tab.active_dailies) == "table" and tab.active_dailies or {}) do
                    local progress = type(daily) == "table" and type(daily.state) == "table" and daily.state or {}
                    local need, done = tonumber(progress.steps_to_complete), tonumber(progress.steps_completed)
                    if need and done and done >= need then
                        finished += 1
                    else
                        unfinished += 1
                    end
                end
                if finished > 0 then
                    table.insert(list, { action = "QuestClaim", tab = tabName })
                end
                -- halloween12: both boards' rewards were claimed at "done today 3" (claim of the 3rd quest first)
                if tab.reward_claimed == false and (tonumber(tab.total_dailies_completed_today) or 0) >= E.QuestsPerBoardReward then
                    table.insert(list, { action = "QuestTabReward", tab = tabName })
                end
            end
        end
        return list
    end

    -- One line about the quest boards (for the log): per tab finished / unfinished quests and the board reward.
    function EventTasks.describeQuests(dailies)
        local tabs = type(dailies) == "table" and type(dailies.serialized_tabs) == "table" and dailies.serialized_tabs
        if not tabs then
            return "no quest data"
        end
        local parts = {}
        for _, tabName in ipairs(E.QuestTabs) do
            local tab = tabs[tabName]
            if type(tab) == "table" then
                local quests = {}
                for kind, daily in pairs(type(tab.active_dailies) == "table" and tab.active_dailies or {}) do
                    local state = type(daily) == "table" and type(daily.state) == "table" and daily.state or {}
                    table.insert(quests, string.format("%s %s/%s", tostring(kind), tostring(state.steps_completed),
                        tostring(state.steps_to_complete)))
                end
                table.sort(quests)
                table.insert(parts, string.format("%s [%s] done today %s, board reward %s", tabName,
                    #quests > 0 and table.concat(quests, ", ") or "no open quests", tostring(tab.total_dailies_completed_today),
                    tab.reward_claimed == true and "claimed" or "not claimed"))
            end
        end
        return #parts > 0 and table.concat(parts, " | ") or "no Halloween / normal board"
    end

    -- Start (server unix time) of the round to join: the cycle data holds the NEXT round start (halloween11/12: the
    -- round joined had intermission_end = timestamp + 14). Old values are moved forward in 600 s steps.
    function EventTasks.nextRoundStart(cycle, now)
        local start = type(cycle) == "table" and tonumber(cycle.timestamp)
        if not start or type(now) ~= "number" then
            return nil
        end
        while start + 20 < now do
            start += E.RoundSeconds
        end
        return start
    end

    -- What the pen job does: { claim, remove = {uniques}, add = {uniques} }.
    -- pen: GameData:petPenPets(), growable: GameData:growablePets() (pen pets already left out),
    -- keep: set of uniques that must stay with the farm (equipped / the farmed pet).
    function EventTasks.penPlan(pen, growable, keep, slots)
        local plan = { claim = count(pen) > 0, remove = {}, add = {} }
        for unique, record in pairs(pen) do
            if type(record) == "table" and record.max_age == true then
                table.insert(plan.remove, unique)
            end
        end
        table.sort(plan.remove)
        local free = slots - count(pen) + #plan.remove
        for _, pet in ipairs(growable) do
            if free <= 0 then
                break
            end
            if not keep[pet.unique] then
                table.insert(plan.add, pet.unique)
                free -= 1
            end
        end
        return plan
    end

    -- Ghost models of the running round: { id, model } (workspace.GhostClustersVisuals.Ghost_<Size>_<id>, halloween12).
    function EventTasks.findGhosts(folder)
        local list = {}
        if not folder then
            return list
        end
        for _, child in ipairs(folder:GetChildren()) do
            local id = string.match(child.Name, E.GhostNamePattern)
            if id then
                table.insert(list, { id = id, model = child, size = string.match(child.Name, "^Ghost_(%a+)_") })
            end
        end
        return list
    end

    local function myRoot()
        local character = game:GetService("Players").LocalPlayer.Character
        return character and character:FindFirstChild("HumanoidRootPart")
    end

    local function modelPosition(model)
        local ok, position = pcall(function()
            return model:GetPivot().Position
        end)
        return ok and position or nil
    end

    local function distance(a, b)
        return math.sqrt((a.X - b.X) ^ 2 + (a.Y - b.Y) ^ 2 + (a.Z - b.Z) ^ 2)
    end

    -- Holds one item; the cleanup puts it away again.
    local function hold(ctx, unique, category)
        local ok, reason = ctx.interaction:send("EquipItem", unique, {})
        if not ok then
            return false, "could not hold the item: " .. tostring(reason)
        end
        ctx.maid:Give(function()
            if ctx.gameData:itemUsesLeft(category, unique) ~= nil then -- not used up
                ctx.interaction:send("UnequipItem", unique, nil)
            end
        end)
        return true
    end

    -------------------------------------------------------------------------------------------------- Pet Pen
    local function penSignature(ctx)
        local parts = {}
        for unique, record in pairs(ctx.gameData:petPenPets()) do
            table.insert(parts, unique .. ":" .. tostring(record.xp_timestamp) .. ":" .. tostring(record.currency_timestamp))
        end
        table.sort(parts)
        return table.concat(parts, "|")
    end

    EventTasks.petPen = {
        id = "pet_pen",
        timeoutSeconds = 60,
        run = function(ctx, group)
            if not ctx.travel:isAt(GameConstants.HouseInteriorName) then
                return false, "the Pet Pen job runs only at home"
            end
            local keep = {}
            for _, pet in ipairs(ctx.gameData:equippedPetList()) do
                keep[pet.unique] = true
            end
            if group and group.keep then
                keep[group.keep] = true
            end
            local slots = tonumber(ctx.farmConfig.Event.PetPenSlots) or E.PetPenSlots
            local plan = EventTasks.penPlan(ctx.gameData:petPenPets(), ctx.gameData:growablePets(), keep, slots)
            local done = {}
            if plan.claim then
                local before = penSignature(ctx)
                local bucks = ctx.gameData:get(KEYS.Money)
                ctx.interaction:send("PetPenClaim", true)
                if not ctx.waitUntil(function()
                    return penSignature(ctx) ~= before
                end, 8) then
                    return false, "CLAIM ALL had no effect in my data"
                end
                local after = ctx.gameData:get(KEYS.Money)
                table.insert(done, "claimed" .. ((tonumber(after) and tonumber(bucks) and after > bucks)
                    and string.format(" (+%d Bucks)", after - bucks) or ""))
            end
            for _, unique in ipairs(plan.remove) do
                ctx.interaction:send("PetPenRemove", unique)
                if not ctx.waitUntil(function()
                    return ctx.gameData:petPenPets()[unique] == nil
                end, 6) then
                    return false, "full grown pet " .. unique .. " did not leave the pen"
                end
                table.insert(done, "took out a full grown pet")
            end
            for _, unique in ipairs(plan.add) do
                ctx.interaction:send("PetPenAdd", unique)
                if not ctx.waitUntil(function()
                    return ctx.gameData:petPenPets()[unique] ~= nil
                end, 6) then
                    return false, "pet " .. unique .. " did not arrive in the pen"
                end
                table.insert(done, "added " .. tostring(ctx.gameData:getPetKind(unique) or unique))
            end
            ctx.logger:info("Event", "Pet Pen: " .. (#done > 0 and table.concat(done, ", ") or "nothing to do")
                .. string.format(" (%d of %d slots used)", count(ctx.gameData:petPenPets()), slots))
            return true
        end,
    }

    -- Am I really next to that spot? Live 1.5.1 (6 "too_far" fails): right after joining, the Play menu put my character
    -- back in the Neighborhood after the teleport ("Teleport to stray_cat undone (now at -12311, 2962)").
    local function nearSpot(spotName, studs)
        local spot = GameConstants.Spots[spotName]
        local root = myRoot()
        if not (spot and root) then
            return false
        end
        local p = root.Position
        return math.sqrt((p.X - spot.x) ^ 2 + (p.Z - spot.z) ^ 2) <= studs
    end
    EventTasks._nearSpot = nearSpot

    -- Travel to MainMap and stand at the spot; one full second try when the game moved me away again.
    local function standAt(ctx, spotName)
        for try = 1, 2 do
            local arrived, why = ctx.travel:goTo("MainMap")
            if not arrived then
                return false, "travel to the Halloween map failed: " .. tostring(why)
            end
            local moved, notMoved = ctx.interaction:teleportTo(spotName)
            task.wait(1.5)
            if moved and nearSpot(spotName, 20) and ctx.travel:isAt("MainMap") then
                return true
            end
            ctx.logger:info("Event", string.format("Not next to %s after the teleport (%s), try %d", spotName,
                moved and "moved away again" or tostring(notMoved), try))
        end
        return false, "could not stay next to " .. spotName
    end

    -------------------------------------------------------------------------------------------------- Stray Cat
    EventTasks.strayCat = {
        id = "stray_cat",
        timeoutSeconds = 90,
        run = function(ctx)
            local function cat()
                local data = ctx.gameData:get(KEYS.StrayCat)
                return type(data) == "table" and data or {}
            end
            if cat().fed_today == true then
                return true
            end
            local giftsBefore = tonumber(cat().total_gifts) or 0
            local item = ctx.gameData:findItems(GameConstants.ItemCategory, E.CatFood)[1]
            if not item then
                if not ctx.farmConfig.BuyWater then
                    return false, "no water for the cat (Farm.BuyWater = false)"
                end
                ctx.interaction:send("BuyItem", "food", "water", {})
                ctx.waitUntil(function()
                    item = ctx.gameData:findItems(GameConstants.ItemCategory, E.CatFood)[1]
                    return item ~= nil
                end, 8)
                if not item then
                    return false, "could not buy a water for the cat"
                end
            end
            local there, notThere = standAt(ctx, "stray_cat")
            if not there then
                return false, notThere
            end
            local held, holdWhy = hold(ctx, item.unique, GameConstants.ItemCategory)
            if not held then
                return false, holdWhy
            end
            task.wait(1)
            local sent, result = ctx.interaction:send("StrayCatFeed", { unique = item.unique })
            local reason = type(result) == "table" and result.reason or nil
            -- Live 1.5.0: one account got "too_far" right after the teleport (the game had not placed me yet): stand there
            -- again and retry, twice at most.
            for _ = 1, 2 do
                if reason ~= "too_far" then
                    break
                end
                ctx.logger:info("Event", "Stray Cat: too far, moving next to it again")
                if not standAt(ctx, "stray_cat") then
                    break
                end
                sent, result = ctx.interaction:send("StrayCatFeed", { unique = item.unique })
                reason = type(result) == "table" and result.reason or nil
            end
            if ctx.waitUntil(function()
                return cat().fed_today == true or (tonumber(cat().total_gifts) or 0) > giftsBefore
            end, 5) then
                ctx.logger:success("Event", string.format("Stray Cat fed with %s%s", item.id,
                    (type(result) == "table" and result.amount) and (" (+" .. tostring(result.amount) .. " candy)") or ""))
                return true
            end
            if reason == "cat_full" then
                ctx.logger:info("Event", "Stray Cat is already full today")
                return true
            end
            return false, "the cat did not take it (" .. (sent and ("answer: " .. tostring(reason or result)) or "send failed") .. ")"
        end,
    }

    -------------------------------------------------------------------------------------------------- Crypt
    EventTasks.crypt = {
        id = "crypt",
        timeoutSeconds = 90,
        run = function(ctx)
            local key = ctx.gameData:itemsOfId(TOYS, E.RustyKey)[1]
            local plan, why = EventTasks.cryptPlan(ctx.gameData:get(KEYS.Crypt))
            if not plan then
                ctx.logger:info("Event", "Crypt: " .. tostring(why))
                return true
            end
            if not plan.spider and not key then
                return true
            end
            local arrived, travelWhy = ctx.travel:goTo("TheCrypt")
            if not arrived then
                return false, "travel to the Crypt failed: " .. tostring(travelWhy)
            end
            if plan.spider then
                local function signature()
                    local data = ctx.gameData:get(KEYS.Crypt)
                    local opened = type(data) == "table" and type(data.opened) == "table" and #data.opened or -1
                    return tostring(type(data) == "table" and data.seed) .. "/" .. opened
                end
                local before = signature()
                local _, answer = ctx.interaction:send("ClaimTombSpider")
                if ctx.waitUntil(function()
                    return signature() ~= before
                end, 8) then
                    ctx.logger:success("Event", "Crypt: Mummy Spider claimed, the Crypt starts again")
                    return true
                end
                return false, "the Mummy Spider claim changed nothing in my data (answer: " .. tostring(answer) .. ")"
            end
            local function openedSet()
                local set, n = {}, 0
                local data = ctx.gameData:get(KEYS.Crypt)
                for _, id in pairs(type(data) == "table" and type(data.opened) == "table" and data.opened or {}) do
                    set[tonumber(id) or id] = true
                    n += 1
                end
                return set, n
            end
            local _, before = openedSet()
            local held, holdWhy = hold(ctx, key, TOYS)
            if not held then
                return false, holdWhy
            end
            task.wait(1)
            ctx.logger:info("Event", string.format("Crypt: opening grave %d on floor %d (%s)", plan.grave, plan.floor, plan.reward))
            local _, answer = ctx.interaction:send("UnlockPadlock", { padlock_index = plan.grave, floor_index = plan.floor })
            if not ctx.waitUntil(function()
                local _, n = openedSet()
                return n > before
            end, 6) then
                return false, "the grave did not open (answer: " .. tostring(answer) .. ")"
            end
            local set = openedSet()
            if not set[plan.floor * E.OpenedIdPerFloor + plan.grave] then
                ctx.logger:warn("Event", "Crypt: a grave opened, but not with the expected id (floor * 16 + grave)")
            end
            ctx.logger:success("Event", "Crypt: opened " .. plan.reward .. " on floor " .. plan.floor)
            return true
        end,
    }

    -------------------------------------------------------------------------------------------------- Pigeon nest
    EventTasks.pigeonNest = {
        id = "pigeon_nest",
        timeoutSeconds = 90,
        run = function(ctx)
            local twig = ctx.gameData:itemsOfId(TOYS, E.Twig)[1]
            local function placed()
                local data = ctx.gameData:get(KEYS.PigeonNest)
                return type(data) == "table" and tonumber(data.twigs_contributed) or 0
            end
            if not twig or placed() >= E.NestTwigs then
                return true
            end
            local before = placed()
            local arrived, why = ctx.travel:goTo("HauntedHotel")
            if not arrived then
                return false, "travel to the Hotel failed: " .. tostring(why)
            end
            local held, holdWhy = hold(ctx, twig, TOYS)
            if not held then
                return false, holdWhy
            end
            task.wait(1)
            local _, answer = ctx.interaction:send("PigeonNestTwig", { unique = twig })
            if ctx.waitUntil(function()
                return placed() > before
            end, 6) then
                ctx.logger:success("Event", string.format("Pigeon nest: twig placed (%d of %d)", placed(), E.NestTwigs))
                return true
            end
            return false, "the nest did not take the twig (answer: " .. tostring(answer) .. ")"
        end,
    }

    -------------------------------------------------------------------------------------------------- Ghost Gallery
    EventTasks.ghostGallery = {
        id = "ghost_gallery",
        timeoutSeconds = 330,
        run = function(ctx, group)
            local mg = ctx.minigame
            if not mg or not mg.available then
                return false, "minigame messages are not available"
            end
            local start = group and group.start
            if not start then
                return false, "round time unknown"
            end
            local candyBefore = tonumber(ctx.gameData:get(KEYS.Candy))
            local keysBefore = #ctx.gameData:itemsOfId(TOYS, E.RustyKey)
            local arrived, why = ctx.travel:goTo("HauntedManor")
            if not arrived then
                return false, "travel to the Manor failed: " .. tostring(why)
            end
            mg:reset()
            ctx.waitUntil(function()
                return Minigame.serverNow() >= start - 3
            end, math.max(0, start - Minigame.serverNow()) + 5)
            -- 1) join: as the game does when the round opens (halloween11/12)
            ctx.logger:info("Event", "Ghost Gallery: joining the round")
            local joinUntil = Util.now() + 30
            while not mg.joinAcceptedAt and not mg.join and Util.now() < joinUntil do
                ctx.interaction:send("MinigameJoin", E.MinigameId, true, nil)
                ctx.waitUntil(function()
                    return mg.joinAcceptedAt ~= nil or mg.join ~= nil
                end, 3)
            end
            if not mg.joinAcceptedAt and not mg.join then
                return false, "join was not accepted"
            end
            if not ctx.waitUntil(function()
                return mg.join ~= nil
            end, 40) then
                return false, "accepted, but the round did not take me in"
            end
            local gameId = mg.join.gameId
            -- 2) the game's own client follows into the round (it sent AttemptJoin(gameId) itself, halloween11/12)
            local function inRound()
                return ctx.travel:isAt(E.MinigameInteriorPrefix)
            end
            if not ctx.waitUntil(inRound, 5) then
                ctx.interaction:send("MinigameJoin", gameId, true, nil)
            end
            if not ctx.waitUntil(inRound, 20) then
                return false, "did not arrive in the minigame"
            end
            -- From here on I am in the round: every way out waits for the round to end (live 1.5.0: a failed round left
            -- the next job trying to travel out of the minigame interior while the round was still running).
            local endTime = Minigame.serverNow() + 170
            local function finish(ok, reason)
                ctx.waitUntil(function()
                    return mg.leave ~= nil or not inRound()
                end, math.max(0, endTime - Minigame.serverNow()) + 25)
                -- Live 1.5.1: pet_me / thirsty / play right after a round, in the Manor, failed 9 times (no pet object,
                -- no completion); the same needs at home worked. Go home first (best effort, not part of the result).
                ctx.waitUntil(function()
                    return not inRound()
                end, 15)
                local home, homeWhy = ctx.travel:goTo(GameConstants.HouseInteriorName)
                if not home then
                    ctx.logger:info("Event", "Ghost Gallery: going home after the round did not work (" .. tostring(homeWhy) .. ")")
                end
                return ok, reason
            end
            -- 3) the loaned vacuum
            local vacuum
            ctx.waitUntil(function()
                vacuum = ctx.gameData:itemsOfId(TOYS, E.Vacuum)[1]
                return vacuum ~= nil
            end, 10)
            if not vacuum then
                return finish(false, "no vacuum in the backpack")
            end
            ctx.interaction:send("EquipItem", vacuum, {})
            ctx.waitUntil(function()
                return mg.enter ~= nil
            end, 10)
            endTime = (mg.enter and mg.enter.endTime) or endTime
            if mg.enter and mg.enter.intermissionEnd then
                ctx.waitUntil(function()
                    return Minigame.serverNow() >= mg.enter.intermissionEnd
                end, 40)
            end
            -- 4) vacuum: ghosts first (points), else a haunted prop (releases a ghost). Each use = ServerUseTool START +
            -- a NEW client-made use_token; start_* every 0.4 s with that token, stop_* when switching (halloween12).
            local folder = workspace:FindFirstChild(E.GhostsFolder)
            local uses, ghostUses, propUses, idle = 0, 0, 0, 0
            while not mg.leave and Minigame.serverNow() < endTime + 5 do
                folder = folder or workspace:FindFirstChild(E.GhostsFolder)
                local target = EventTasks.pickTarget(ctx, folder, mg)
                if not target then
                    idle += 1
                    task.wait(0.5)
                else
                    local standOff = target.boss and E.BossStandOff or 10
                    local function closeIn()
                        -- the target moves and the boss's tornadoes carry me away: check before every few sends
                        local root = myRoot()
                        local position = target.model and modelPosition(target.model) or target.position
                        if root and position and distance(position, root.Position) > E.VacuumReachStuds + (target.boss and 10 or 0) then
                            ctx.interaction:teleportNear(position, standOff)
                            task.wait(0.2)
                        end
                    end
                    closeIn()
                    ctx.interaction:send("UseTool", vacuum, "START")
                    local token = EventTasks.newToken()
                    uses += 1
                    local isGhost = target.kind == "ghost"
                    local payload = isGhost and { use_token = token, ghost_id = target.id } or { use_token = token, unique = target.id }
                    local startMessage = isGhost and "start_contribute" or "start_prop_contribute"
                    local stopMessage = isGhost and "stop_contribute" or "stop_prop_contribute"
                    -- Live 1.5.2 (user): bots stood under the boss while 3 guards lived. Short uses (~2.4 s) so a new guard
                    -- is picked quickly; the boss is left as soon as a guard appears.
                    for send = 1, 8 do
                        if mg.leave or (isGhost and target.model.Parent == nil) or (not isGhost and not mg.haunted[target.id]) then
                            break
                        end
                        if target.boss and send > 1 and EventTasks.pickTarget(ctx, folder, mg) ~= nil
                            and not EventTasks.pickTarget(ctx, folder, mg).boss then
                            break -- a guard appeared: it comes first
                        end
                        if send % 3 == 0 then
                            closeIn()
                        end
                        ctx.interaction:send("MinigameMessage", gameId, startMessage, payload)
                        task.wait(0.3)
                    end
                    ctx.interaction:send("MinigameMessage", gameId, stopMessage, payload)
                    if isGhost then
                        ghostUses += 1
                    else
                        propUses += 1
                    end
                end
            end
            ctx.waitUntil(function()
                return mg.leave ~= nil
            end, 20)
            local candyAfter = tonumber(ctx.gameData:get(KEYS.Candy))
            local gained = (candyAfter and candyBefore) and (candyAfter - candyBefore) or nil
            local myProps = 0
            for _, progress in pairs(mg.propProgress) do
                if progress > 0 then
                    myProps += 1
                end
            end
            ctx.logger:info("Event", string.format("Ghost Gallery: %d points (%d hits), props moved %d, vacuum uses %d (ghosts %d,"
                .. " props %d), reward %s candy%s", mg.score, mg.scoreCount, myProps, uses, ghostUses, propUses,
                tostring(mg.leave and mg.leave.candy or "?"), gained and string.format(", candy %+d", gained) or ""))
            local keysAfter = #ctx.gameData:itemsOfId(TOYS, E.RustyKey)
            -- User 2026-10-04: accounts with ~100k score got a Rusty Key without beating the boss -> report the key only.
            ctx.logger:info("Event", string.format("Ghost Gallery: Rusty Key %s (score %d, boss %s)",
                keysAfter > keysBefore and "EARNED (+1)" or "not earned", mg.score, mg.bossOut and "came out" or "did not come out"))
            if mg.scoreCount == 0 and not (mg.leave and mg.leave.candy > 0) and not (gained and gained > 0) then
                return finish(false, uses == 0 and "no ghost or haunted prop found" or "no points and no reward: vacuuming did not count")
            end
            return finish(true)
        end,
    }

    -- A new vacuum token: the game's are lower-case GUIDs without braces (halloween12).
    function EventTasks.newToken()
        local ok, guid = pcall(function()
            return game:GetService("HttpService"):GenerateGUID(false)
        end)
        return string.lower(ok and tostring(guid) or string.format("%08x-0000-4000-8000-%012x", math.random(0, 0x7fffffff), os.time()))
    end

    -- Nearest ghost, else nearest haunted prop (its position from my data: house_interior.furniture[unique].cframe).
    -- Returns { kind = "ghost" | "prop", id, position, model } or nil.
    function EventTasks.pickTarget(ctx, folder, mg)
        local root = myRoot()
        if not root then
            return nil
        end
        -- Guards (Small / Medium) before the boss (Large): the nearest guard, the boss only when no guard is left.
        local best, bestDistance, boss
        for _, ghost in ipairs(EventTasks.findGhosts(folder)) do
            local position = modelPosition(ghost.model)
            if position then
                local target = { kind = "ghost", id = ghost.id, position = position, model = ghost.model,
                    boss = ghost.size == E.BossSize }
                if target.boss then
                    boss = boss or target
                else
                    local d = distance(position, root.Position)
                    if not best or d < bestDistance then
                        best, bestDistance = target, d
                    end
                end
            end
        end
        if best or boss then
            return best or boss
        end
        local interior = ctx.gameData:get(KEYS.Interior)
        local furniture = type(interior) == "table" and type(interior.furniture) == "table" and interior.furniture or {}
        for unique in pairs(mg.haunted) do
            local piece = furniture[unique]
            local ok, position = pcall(function()
                return piece.cframe.Position
            end)
            if ok and position ~= nil and type(position.X) == "number" then
                local d = distance(position, root.Position)
                if not best or d < bestDistance then
                    best, bestDistance = { kind = "prop", id = unique, position = position }, d
                end
            end
        end
        return best
    end

    -------------------------------------------------------------------------------------------------- Quests
    EventTasks.quests = {
        id = "quests",
        timeoutSeconds = 30,
        run = function(ctx)
            local function tabSignature(tabName)
                local data = ctx.gameData:get(KEYS.Dailies)
                local tab = type(data) == "table" and type(data.serialized_tabs) == "table" and data.serialized_tabs[tabName]
                if type(tab) ~= "table" then
                    return "none"
                end
                local parts = { tostring(tab.reward_claimed), tostring(tab.total_dailies_completed) }
                for kind, daily in pairs(type(tab.active_dailies) == "table" and tab.active_dailies or {}) do
                    local state = type(daily) == "table" and type(daily.state) == "table" and daily.state or {}
                    table.insert(parts, tostring(kind) .. ":" .. tostring(state.steps_completed))
                end
                table.sort(parts)
                return table.concat(parts, "|")
            end
            local todo = EventTasks.questsToClaim(ctx.gameData:get(KEYS.Dailies))
            if #todo == 0 then
                return true
            end
            local changed = 0
            for _, item in ipairs(todo) do
                local before = tabSignature(item.tab)
                local money, candy = ctx.gameData:get(KEYS.Money), ctx.gameData:get(KEYS.Candy)
                ctx.interaction:send(item.action, item.tab)
                if ctx.waitUntil(function()
                    return tabSignature(item.tab) ~= before
                end, 6) then
                    changed += 1
                    local gains = {}
                    local moneyNow, candyNow = ctx.gameData:get(KEYS.Money), ctx.gameData:get(KEYS.Candy)
                    if tonumber(money) and tonumber(moneyNow) and moneyNow > money then
                        table.insert(gains, "+" .. (moneyNow - money) .. " Bucks")
                    end
                    if tonumber(candy) and tonumber(candyNow) and candyNow > candy then
                        table.insert(gains, "+" .. (candyNow - candy) .. " candy")
                    end
                    ctx.logger:success("Event", string.format("Quests: %s claimed on the %s board%s",
                        item.action == "QuestTabReward" and "board reward" or "finished quest", item.tab,
                        #gains > 0 and (" (" .. table.concat(gains, ", ") .. ")") or ""))
                else
                    ctx.logger:info("Event", "Quests: " .. item.action .. "(" .. item.tab .. ") changed nothing in my data")
                end
            end
            if changed == 0 then
                return false, "no quest claim changed my data"
            end
            return true
        end,
    }

    -------------------------------------------------------------------------------------------------- House visits
    -- An unfinished "Visit 3 / 5 player homes" quest (housewarming / neighborhood_tour, quests13b):
    -- { kind, need, done, visited = {[userId string] = true} } or nil.
    EventTasks.VisitQuests = { housewarming = true, neighborhood_tour = true }
    function EventTasks.visitQuest(dailies)
        local tabs = type(dailies) == "table" and type(dailies.serialized_tabs) == "table" and dailies.serialized_tabs or {}
        for _, tab in pairs(tabs) do
            for kind, daily in pairs(type(tab) == "table" and type(tab.active_dailies) == "table" and tab.active_dailies or {}) do
                local state = type(daily) == "table" and type(daily.state) == "table" and daily.state or nil
                if EventTasks.VisitQuests[kind] and state then
                    local need, done = tonumber(state.steps_to_complete) or 0, tonumber(state.steps_completed) or 0
                    if done < need then
                        local visited = {}
                        for userId in pairs(type(state.houses_visited_by_userid) == "table" and state.houses_visited_by_userid or {}) do
                            visited[tostring(userId)] = true
                        end
                        return { kind = kind, need = need, done = done, visited = visited }
                    end
                end
            end
        end
        return nil
    end

    EventTasks._visitTried = {} -- [userId] = time of the last try (a house that did not count is skipped 30 min)
    local VISITS_PER_RUN = 2

    EventTasks.houseVisits = {
        id = "house_visits",
        timeoutSeconds = 120,
        run = function(ctx)
            local quest = EventTasks.visitQuest(ctx.gameData:get(KEYS.Dailies))
            if not quest then
                return true
            end
            local Players = game:GetService("Players")
            local me = Players.LocalPlayer
            local counted, tries = 0, 0
            for _, player in ipairs(Players:GetPlayers()) do
                if tries >= VISITS_PER_RUN then
                    break
                end
                local id = tostring(player.UserId)
                local last = EventTasks._visitTried[id]
                if player ~= me and not quest.visited[id] and not (last and Util.now() - last < 1800) then
                    tries += 1
                    EventTasks._visitTried[id] = Util.now()
                    ctx.travel:visitHouse(player)
                    local ok = ctx.waitUntil(function()
                        local now = EventTasks.visitQuest(ctx.gameData:get(KEYS.Dailies))
                        return now == nil or now.visited[id] == true or now.done > quest.done
                    end, 15)
                    if ok then
                        counted += 1
                        local now = EventTasks.visitQuest(ctx.gameData:get(KEYS.Dailies))
                        ctx.logger:success("Event", string.format("Quest %s: visited %s's house (%d of %d)", quest.kind,
                            player.Name, now and now.done or quest.need, quest.need))
                    else
                        ctx.logger:info("Event", "Quest " .. quest.kind .. ": the visit to " .. player.Name .. " did not count")
                    end
                    -- leave the other house: being there looks like "home" to the farm
                    ctx.travel:goTo("MainMap")
                    quest = EventTasks.visitQuest(ctx.gameData:get(KEYS.Dailies))
                    if not quest then
                        break
                    end
                end
            end
            if tries == 0 then
                ctx.logger:info("Event", "Quest: no other player's house left to visit on this server")
                return true
            end
            if counted == 0 then
                return false, "house visits did not count for the quest"
            end
            return true
        end,
    }

    -------------------------------------------------------------------------------------------------- Age potions
    -- The equipped pet that still grows and may get potions (Farm.AutoPotions.PetKinds: empty = any), or nil.
    function EventTasks.potionTarget(gameData, farm)
        local settings = type(farm.AutoPotions) == "table" and farm.AutoPotions or {}
        local kinds = {}
        for _, kind in ipairs(type(settings.PetKinds) == "table" and settings.PetKinds or {}) do
            kinds[kind] = true
        end
        for _, pet in ipairs(gameData:equippedPetList()) do
            local age = pet.unique and gameData:petAge(pet.unique)
            if age and age < GameConstants.FullGrownAge and (next(kinds) == nil or kinds[gameData:getPetKind(pet.unique) or ""]) then
                return pet.unique
            end
        end
        return nil
    end

    EventTasks.agePotion = {
        id = "age_potion",
        timeoutSeconds = 40,
        run = function(ctx)
            local petUnique = EventTasks.potionTarget(ctx.gameData, ctx.farmConfig)
            local settings = ctx.farmConfig.AutoPotions or {}
            local item = ctx.gameData:findItems(GameConstants.ItemCategory, settings.Potions or GameConstants.AgePotions)[1]
            if not petUnique or not item then
                return true
            end
            local ageBefore = ctx.gameData:petAge(petUnique)
            local kind = ctx.gameData:getPetKind(petUnique) or petUnique
            local ok, why = Tasks.givePetItem(ctx, petUnique, item, function()
                return ctx.gameData:itemUsesLeft(GameConstants.ItemCategory, item.unique) == nil
                    or (ctx.gameData:petAge(petUnique) or 0) > (ageBefore or 0)
            end, "age potion")
            if not ok then
                return false, why
            end
            ctx.waitUntil(function()
                return (ctx.gameData:petAge(petUnique) or 0) > (ageBefore or 0)
            end, 3)
            ctx.logger:success("Event", string.format("Age potion: %s age %s -> %s (%s)", kind, tostring(ageBefore),
                tostring(ctx.gameData:petAge(petUnique)), item.id))
            return true
        end,
    }

    -------------------------------------------------------------------------------------------------- Gifts / chests
    -- The first gift or chest in the backpack this script knows how to open: { unique, id, how = "gift" | "chest" }.
    function EventTasks.nextGift(gameData, farm)
        local settings = type(farm.AutoOpen) == "table" and farm.AutoOpen or {}
        local skip = {}
        for _, id in ipairs(type(settings.Exclude) == "table" and settings.Exclude or {}) do
            skip[id] = true
        end
        local list = {}
        for _, item in ipairs(gameData:findItems(GameConstants.GiftCategory, nil)) do
            if not skip[item.id] then
                for how, pattern in pairs(GameConstants.GiftPatterns) do
                    if string.find(item.id, pattern) then
                        table.insert(list, { unique = item.unique, id = item.id, how = how })
                    end
                end
            end
        end
        table.sort(list, function(a, b)
            return a.unique < b.unique
        end)
        return list[1]
    end

    EventTasks.openGift = {
        id = "open_gift",
        timeoutSeconds = 30,
        run = function(ctx)
            local gift = EventTasks.nextGift(ctx.gameData, ctx.farmConfig)
            if not gift then
                return true
            end
            local function gone()
                return ctx.gameData:itemUsesLeft(GameConstants.GiftCategory, gift.unique) == nil
            end
            ctx.interaction:send("EquipItem", gift.unique, {})
            task.wait(0.5)
            ctx.interaction:send("UseTool", gift.unique, "START")
            task.wait(1)
            if gift.how == "gift" then
                ctx.interaction:send("OpenGift", gift.unique)
                ctx.waitUntil(gone, 4)
                ctx.interaction:send("UseTool", gift.unique, "END", nil)
            else
                ctx.interaction:send("UnequipItem", gift.unique, nil)
                ctx.interaction:send("UseTool", gift.unique, "END", nil)
                ctx.interaction:send("OpenChest", gift.id, gift.unique)
            end
            if ctx.waitUntil(gone, 6) then
                ctx.logger:success("Event", "Opened " .. gift.id)
                return true
            end
            ctx.interaction:send("UnequipItem", gift.unique, nil)
            return false, gift.id .. " is still in the backpack after opening"
        end,
    }

    return EventTasks
end

-- ─────────────────────────────── module: Game/TaskManager ───────────────────────────────
__moduleSources["Game/TaskManager"] = function(...)
    --[[
        Game/TaskManager
        SCAN -> SELECT -> EXECUTE -> VERIFY -> SUCCESS / FAILED / TIMEOUT -> CLEANUP -> (next tick) RESCAN

        - Runs at most ONE task at a time.
        - Each task has a hard time limit; when it is exceeded the task thread is cancelled and its
          cleanup (e.g. unfocusing the pet) still runs.
        - Failures put that need kind on a cooldown; after MaxConsecutiveFailures it is disabled for the
          session with an ERROR (which also reaches the Alerts webhook).
        - Needs with no automatic task yet are logged once, then ignored.

        State written: farm.currentTask ("none" or the need kind), farm.tasksSucceeded, farm.tasksFailed
    ]]

    local import = ...
    local Util = import("Core/Util")
    local Maid = import("Core/Maid")
    local GameConstants = import("Game/GameConstants")
    local Tasks = import("Game/Tasks")
    local EventTasks = import("Game/EventTasks")
    local Minigame = import("Game/Minigame")

    local TaskManager = {}
    TaskManager.__index = TaskManager

    local TEAM_KEY = "team"
    -- Halloween / Pet Pen jobs (Game/EventTasks): seconds until the same job is looked at again (success or not).
    local EVENT_RECHECK_SECONDS = { ghost_gallery = 120, stray_cat = 1800, crypt = 60, pigeon_nest = 60, quests = 300, pen_stock = 20, age_potion = 5, open_gift = 3, house_visits = 300 }
    local GHOST_GALLERY_LEAD_SECONDS = 75 -- start the trip to the Manor this long before the round

    function TaskManager.new(deps)
        local self = setmetatable({}, TaskManager)
        self._logger = deps.logger
        self._state = deps.state
        self._tracker = deps.tracker
        self._interaction = deps.interaction
        self._travel = deps.travel
        self._petLocator = deps.petLocator
        self._furniture = deps.furniture
        self._gameData = deps.gameData
        self._farmConfig = deps.farmConfig
        self._minigame = deps.minigame
        self._nextEventAt = {} -- [event job key] = time
        self._running = nil
        self._stopped = false
        self._failures = {} -- [key] = consecutive failures
        self._cooldownUntil = {} -- [key] = time
        self._disabled = {} -- [key] = true
        self._completions = {} -- ["kind|owner|petUnique"] = time
        self._announcedUnsupported = {}
        self._state:set("farm.currentTask", "none", "TaskManager")
        return self
    end

    function TaskManager:start(maid)
        maid:Give(self._tracker.Completed:Connect(function(owner, petUnique, kind)
            self._completions[kind .. "|" .. owner .. "|" .. tostring(petUnique)] = Util.now()
        end))
        maid:Give(function()
            self:stop()
        end)
    end

    -- Groups my active needs by kind. Returns the group for one kind, or nil if none is active.
    -- Needs of pets that are not equipped are listed by the game too (watch7) but cannot be done.
    function TaskManager:_isDoable(entry)
        if entry.owner ~= "pet" or not self._gameData then
            return true
        end
        return self._gameData:isPetEquipped(entry.petUnique)
    end

    function TaskManager:_group(kind)
        local group = nil
        for _, entry in ipairs(self._state:get("ailments.active", {})) do
            if entry.kind == kind and self:_isDoable(entry) then
                group = group or { kind = kind, entries = {}, anyInProgress = false, maxRate = 0, oldest = math.huge }
                table.insert(group.entries, entry)
                if entry.owner == "pet" and not group.petEntry then
                    group.petEntry = entry
                end
                if entry.inProgress then
                    group.anyInProgress = true
                end
                group.maxRate = math.max(group.maxRate, entry.rate or 0)
                group.oldest = math.min(group.oldest, entry.createdAt or math.huge)
            end
        end
        return group
    end

    function TaskManager:_isBlocked(key)
        return self._disabled[key] or Util.now() < (self._cooldownUntil[key] or 0)
    end

    function TaskManager:_selectGroup()
        -- Live 1.1.1: a location need failed (pet unequipped), was running again 3 s later where I stood, and the farm
        -- walked away to another need because of the 30 s cooldown. A need already running here is continued first.
        if self._travel then
            for _, entry in ipairs(self._state:get("ailments.active", {})) do
                local destination = GameConstants.LocationForAilment[entry.kind]
                if entry.inProgress and destination and not GameConstants.SpotForAilment[entry.kind]
                    and not self._disabled[entry.kind] and self._farmConfig.Tasks[entry.kind] == true
                    and self._travel:isAt(destination) then
                    local group = self:_group(entry.kind)
                    if group then
                        return group, Tasks.findFor(entry.kind)
                    end
                end
            end
        end
        local best, bestTask, bestPriority = nil, nil, -math.huge
        local seen = {}
        for _, entry in ipairs(self._state:get("ailments.active", {})) do
            local kind = entry.kind
            if not seen[kind] then
                seen[kind] = true
                local taskDefinition = Tasks.findFor(kind)
                if not taskDefinition or self._farmConfig.Tasks[kind] ~= true then
                    if not self._announcedUnsupported[kind] then
                        self._announcedUnsupported[kind] = true
                        local why = taskDefinition and "turned off in Farm.Tasks" or "no automatic task yet"
                        self._logger:info("Tasks", "Skipping '" .. kind .. "' (" .. why .. ")")
                    end
                elseif not self:_isBlocked(kind) then
                    local group = self:_group(kind)
                    local priority = self._farmConfig.Priority[kind] or 0
                    if group and (priority > bestPriority or (priority == bestPriority and group.oldest < best.oldest)) then
                        best, bestTask, bestPriority = group, taskDefinition, priority
                    end
                end
            end
        end
        return best, bestTask
    end

    function TaskManager:_needsTeamSwitch()
        local team = self._state:get("player.team")
        return self._farmConfig.BabyMode and team ~= nil and team ~= GameConstants.BabiesTeam and not self:_isBlocked(TEAM_KEY)
    end

    function TaskManager:_makeContext(runMaid, startedAt)
        local context = {
            logger = self._logger,
            state = self._state,
            interaction = self._interaction,
            travel = self._travel,
            petLocator = self._petLocator,
            furniture = self._furniture,
            gameData = self._gameData,
            farmConfig = self._farmConfig,
            minigame = self._minigame,
            maid = runMaid,
        }
        function context.waitUntil(predicate, seconds)
            local deadline = Util.now() + seconds
            while true do
                if predicate() then
                    return true
                end
                if Util.now() >= deadline then
                    return false
                end
                task.wait(0.25)
            end
        end
        function context.completedSince(kind, owner, petUnique)
            local at = self._completions[kind .. "|" .. owner .. "|" .. tostring(petUnique)]
            return at ~= nil and at >= startedAt
        end
        function context.currentGroup(kind)
            return self:_group(kind)
        end
        function context.findEntry(kind, owner, petUnique)
            for _, entry in ipairs(self._state:get("ailments.active", {})) do
                if entry.kind == kind and entry.owner == owner and (owner == "baby" or entry.petUnique == petUnique) then
                    return entry
                end
            end
            return nil
        end
        function context.isKindGone(kind)
            return self:_group(kind) == nil
        end
        -- A real completion (the game's completion event) of this kind at or after `since`.
        function context.kindCompletedSince(kind, since)
            for key, at in pairs(self._completions) do
                if at >= since and string.sub(key, 1, #kind + 1) == kind .. "|" then
                    return true
                end
            end
            return false
        end
        return context
    end

    function TaskManager:_start(key, label, taskDefinition, group, isEventJob)
        local attempt = (self._failures[key] or 0) + 1
        local runMaid = Maid.new()
        local startedAt = Util.now()
        local running = {
            key = key,
            label = label,
            startedAt = startedAt,
            deadline = startedAt + taskDefinition.timeoutSeconds,
            maid = runMaid,
            eventJob = isEventJob == true,
        }
        self._running = running
        self._state:set("farm.currentTask", key, "TaskManager")
        self._logger:info("Tasks", string.format("Start: %s (attempt %d, limit %d s)", label, attempt, taskDefinition.timeoutSeconds))

        local context = self:_makeContext(runMaid, startedAt)
        running.thread = task.spawn(function()
            local ok, result, reason = pcall(taskDefinition.run, context, group, attempt)
            if self._running ~= running then
                return -- already finished (timeout or stop)
            end
            if not ok then
                self:_finish("FAILED", "script error: " .. tostring(result))
            elseif result == true then
                self:_finish("SUCCESS")
            else
                self:_finish("FAILED", tostring(reason or "unknown reason"))
            end
        end)
    end

    function TaskManager:_finish(result, reason)
        local running = self._running
        if not running then
            return
        end
        self._running = nil
        if running.thread and coroutine.running() ~= running.thread then
            pcall(task.cancel, running.thread)
        end
        -- Cleanup may talk to the server; never let it block the scheduler.
        task.spawn(function()
            running.maid:Clean()
        end)
        self._state:set("farm.currentTask", "none", "TaskManager")

        local key = running.key
        local seconds = Util.now() - running.startedAt
        if running.eventJob then
            local wait = key == "pet_pen" and (tonumber(self._farmConfig.Event.PetPenMinutes) or 15) * 60
                or EVENT_RECHECK_SECONDS[key] or 60
            self._nextEventAt[key] = Util.now() + wait
        end
        local travelTrouble = result ~= "SUCCESS" and type(reason) == "string"
            and (string.find(reason, "travel", 1, true) or string.find(reason, "still in", 1, true)
                or string.find(reason, "going home", 1, true))
        if travelTrouble and key ~= "recover" then
            self._travelFailures = (self._travelFailures or 0) + 1
        elseif result == "SUCCESS" then
            self._travelFailures = 0
        end
        if result == "SUCCESS" then
            self._failures[key] = 0
            self._state:increment("farm.tasksSucceeded", 1, "TaskManager")
            self._logger:success("Tasks", string.format("Done: %s in %.1f s", running.label, seconds))
            return
        end

        self._state:increment("farm.tasksFailed", 1, "TaskManager")
        local failures = (self._failures[key] or 0) + 1
        self._failures[key] = failures
        self._cooldownUntil[key] = Util.now() + self._farmConfig.FailureCooldownSeconds
        local message = string.format("%s: %s after %.1f s — %s", result, running.label, seconds, tostring(reason))
        if failures >= self._farmConfig.MaxConsecutiveFailures and key ~= "recover" then
            self._disabled[key] = true
            self._logger:error("Tasks", message .. string.format(" (%d failures in a row: disabled for this session)", failures))
        else
            self._logger:warn("Tasks", message .. string.format(" (retry in %d s)", self._farmConfig.FailureCooldownSeconds))
        end
    end

    -- Called by the scheduler every second.
    -- Which pet this session farms. Recorded on EVERY tick (also while a task runs): live 1.1.1 (account A) the pet was seen
    -- only for 6 s during a task, so it was never recorded and stayed unequipped for an hour.
    function TaskManager:_trackPet()
        if not self._gameData then
            return
        end
        local current = self._gameData:firstEquippedPet()
        if current then
            self._lastPet = current
            self._farmPet = self._farmPet or current
            if self._badPets then
                self._badPets[current] = nil -- it can be equipped after all
            end
        end
    end

    function TaskManager:tick()
        if self._stopped or not self._farmConfig.Enabled then
            return
        end
        self:_trackPet()
        if self._running then
            if Util.now() > self._running.deadline then
                self:_finish("TIMEOUT", "no result within " .. math.floor(self._running.deadline - self._running.startedAt) .. " s")
            end
            return
        end
        if self._state:get("session.disconnectReason") ~= nil or self._state:get("game.ready") ~= true then
            return
        end
        -- Public reports 2026-10-05 (4 of 10): "equip pet: no character" and "ChooseTeam failed ... update_team" right
        -- after the start, while the Play menu was still open (team "Choosing"). Wait until a team is chosen.
        if self._state:get("player.team") == "Choosing" then
            return
        end
        -- Stuck-in-transit watchdog (screenshot 2026-09-28: one client stayed on the white "changing place" screen).
        -- My data then has no place (house_interior = {} -> player.interior nil). After 25 s: go home again.
        if self._state:get("player.interior") == nil and self._hadPlace then
            self._transitSince = self._transitSince or Util.now()
            if Util.now() - self._transitSince > 25 then
                self._transitSince = nil
                self._logger:warn("Tasks", "Stuck while changing place for 25 s: going home to recover")
                self:_start("recover", "recover: go home", Tasks.recover, nil)
                return
            end
        else
            self._hadPlace = self._state:get("player.interior") ~= nil or self._hadPlace
            self._transitSince = nil
        end
        -- Repeated travel failures also mean "stuck": recover (respawn) after 2 in a row.
        if (self._travelFailures or 0) >= 2 then
            self._travelFailures = 0
            self._logger:warn("Tasks", "2 trips in a row failed: recovering")
            self:_start("recover", "recover: go home", Tasks.recover, nil)
            return
        end
        -- Keep the pet equipped (live: unequipped for hours after the doctor -> pet needs skipped).
        if self._gameData and self._farmConfig.KeepPetEquipped then
            local current = self._gameData:firstEquippedPet()
            local count, known = self._gameData:equippedPetCount()
            -- User (2026-09-29): always have ONE pet equipped, any pet is fine, but never farm a full grown one.
            -- Live 1.1.1: at 00:00:02 the game swapped every account to "2d_kitty" age 6 and it was farmed for 6 h.
            local skipGrown = self._farmConfig.SkipFullGrown
            local list = self._gameData:equippedPetList()
            local growableEquipped = false
            for _, pet in ipairs(list) do
                if pet.age == nil or pet.age < GameConstants.FullGrownAge then
                    growableEquipped = true
                end
            end
            -- 1.4.2: a pet that cannot be equipped (2 failed equips, e.g. a tutorial "practice_dog") is skipped, so the
            -- farm moves on to the next pet / buys an egg instead of standing with "pets: none" (user screenshot).
            self._badPets = self._badPets or {}
            local function usable(unique)
                return unique ~= nil and (self._badPets[unique] or 0) < 2
            end
            local function pickGrowable()
                local farmAge = self._farmPet and self._gameData:petAge(self._farmPet)
                if usable(self._farmPet) and farmAge and farmAge < GameConstants.FullGrownAge then
                    return self._farmPet
                end
                for _, candidate in ipairs(self._gameData:growablePets()) do
                    if usable(candidate.unique) then
                        return candidate.unique
                    end
                end
                return nil
            end
            local function onEquipFail(unique)
                return function()
                    self._badPets[unique] = (self._badPets[unique] or 0) + 1
                    if self._badPets[unique] == 2 then
                        self._logger:warn("Tasks", "Pet " .. tostring(unique) .. " could not be equipped twice: skipping it")
                    end
                end
            end
            -- Why no pet is equipped, once a minute (user: "the character stands idle with pets: none").
            if not current and known and count == 0 then
                local nowT = Util.now()
                if not self._lastNoPetLog or nowT - self._lastNoPetLog > 60 then
                    self._lastNoPetLog = nowT
                    self._logger:info("Tasks", string.format("No pet equipped: %d pets in the backpack still grow (usable: %s),"
                        .. " pet list %s, egg buying %s", #self._gameData:growablePets(), tostring(pickGrowable() ~= nil),
                        self._gameData:petInventoryKnown() and "known" or "NOT known yet",
                        not self._farmConfig.BuyEgg and "off" or (self:_isBlocked("buy_egg") and "paused after failures" or "on")))
                end
            end
            -- User (2026-10-01): no pet at all, or every pet full grown -> buy an egg (Farm.EggToBuy) and farm it.
            local lastAgeUnknown = self._lastPet ~= nil and self._gameData:petAge(self._lastPet) == nil
            if self._farmConfig.BuyEgg and known and self._gameData:petInventoryKnown() and not pickGrowable()
                and not (lastAgeUnknown and not current) and not self:_isBlocked("buy_egg") then
                local max = tonumber(self._farmConfig.MaxEggBuysPerSession) or 0
                self._eggBuys = self._eggBuys or 0
                if max <= 0 or self._eggBuys < max then
                    local nothing = (not current and count == 0 and not self._lastPet)
                    local allGrown = #list > 0 and not growableEquipped
                    if nothing or allGrown or (not current and count == 0) then
                        self:_start("buy_egg", "buy an egg", Tasks.buyEgg, { onBought = function()
                            self._eggBuys += 1
                        end })
                        return
                    end
                end
            end
            if not current and known and count == 0 and not self:_isBlocked("equip_pet") then
                local wanted = skipGrown and (pickGrowable() or self._lastPet) or self._lastPet
                if wanted and usable(wanted) then
                    self:_start("equip_pet", "equip pet", Tasks.equipPet, { petUnique = wanted, onFail = onEquipFail(wanted) })
                    return
                end
            elseif skipGrown and #list > 0 and not growableEquipped and not self:_isBlocked("keep_pet") then
                local wanted = pickGrowable()
                if wanted then
                    self._logger:info("Tasks", "Your equipped pet is full grown: equipping one that still grows (Farm.SkipFullGrown)")
                    self._farmPet = wanted
                    self:_start("keep_pet", "equip a pet that still grows", Tasks.equipPet, { petUnique = wanted, onFail = onEquipFail(wanted) })
                    return
                elseif not self._announcedAllGrown then
                    self._announcedAllGrown = true
                    self._logger:warn("Tasks", "Every pet in your backpack is full grown: farming the equipped one"
                        .. (self._farmConfig.BuyEgg and " (buying an egg was not possible)" or " (Farm.BuyEgg = false)"))
                end
            end
        end
        if self:_needsTeamSwitch() then
            self:_start(TEAM_KEY, "switch team to " .. GameConstants.BabiesTeam, Tasks.team, nil)
            return
        end
        local eventKey, eventLabel, eventTask, eventGroup = self:_selectEventJob()
        if eventKey then
            self:_start(eventKey, eventLabel, eventTask, eventGroup, true)
            return
        end
        local group, taskDefinition = self:_selectGroup()
        if group then
            local owners = {}
            for _, entry in ipairs(group.entries) do
                table.insert(owners, entry.owner == "baby" and "baby" or tostring(entry.petKind or "pet"))
            end
            self:_start(group.kind, group.kind .. " (" .. table.concat(owners, " + ") .. ")", taskDefinition, group)
        end
    end

    -- The Halloween / Pet Pen job that is due now, or nil. Each job decides from MY data whether there is anything to do.
    function TaskManager:_selectEventJob()
        local event = self._farmConfig.Event
        local data = self._gameData
        if not data then
            return nil
        end
        -- Live 1.5.1: event jobs started while the Play menu was still open (team "Choosing", no character): the game
        -- then put me back at the spawn. Wait until I am really in the game.
        local team = self._state:get("player.team")
        local character = game:GetService("Players").LocalPlayer.Character
        if team ~= "Parents" and team ~= GameConstants.BabiesTeam or not (character and character:FindFirstChild("HumanoidRootPart")) then
            return nil
        end
        -- Not event-bound (user 2026-10-04): age potions on the farmed pet, opening gifts / chests.
        do
            local nowExtra = Util.now()
            local function dueExtra(key)
                return not self:_isBlocked(key) and nowExtra >= (self._nextEventAt[key] or 0)
            end
            local potions = self._farmConfig.AutoPotions
            if type(potions) == "table" and potions.Enabled and dueExtra("age_potion")
                and EventTasks.potionTarget(data, self._farmConfig)
                and data:findItems(GameConstants.ItemCategory, potions.Potions or GameConstants.AgePotions)[1] then
                return "age_potion", "age potion", EventTasks.agePotion, nil
            end
            local open = self._farmConfig.AutoOpen
            if type(open) == "table" and open.Enabled and dueExtra("open_gift") and EventTasks.nextGift(data, self._farmConfig) then
                return "open_gift", "open a gift", EventTasks.openGift, nil
            end
        end
        if type(event) ~= "table" or not event.Enabled then
            return nil
        end
        local now = Util.now()
        local function due(key)
            return event[key] ~= false and not self:_isBlocked(key) and now >= (self._nextEventAt[key] or 0)
        end
        local E = GameConstants.Event
        local KEYS = GameConstants.DataKeys
        if event.GhostGallery and due("ghost_gallery") and self._minigame and self._minigame.available then
            local serverNow = Minigame.serverNow()
            local start = EventTasks.nextRoundStart(data:get(KEYS.GhostCycle), serverNow)
            if start and start - serverNow <= GHOST_GALLERY_LEAD_SECONDS and start - serverNow > -10 then
                return "ghost_gallery", "Ghost Gallery round", EventTasks.ghostGallery, { start = start }
            end
        end
        if event.StrayCat and due("stray_cat") then
            local cat = data:get(KEYS.StrayCat)
            if type(cat) == "table" and cat.fed_today == false then
                return "stray_cat", "feed the Stray Cat", EventTasks.strayCat, nil
            end
        end
        if event.Crypt and due("crypt") and data:get(KEYS.Crypt) ~= nil then
            local plan = EventTasks.cryptPlan(data:get(KEYS.Crypt))
            if plan and plan.spider and event.MummySpider ~= false then
                return "crypt", "claim the Mummy Spider", EventTasks.crypt, nil
            elseif plan and not plan.spider and #data:itemsOfId(GameConstants.ToyCategory, E.RustyKey) > 0 then
                return "crypt", "open a Crypt grave", EventTasks.crypt, nil
            end
        end
        -- Live 1.5.1: no quest was claimed in 1.5 h on 3 accounts. Every 10 min: what the quest boards show (diagnosis).
        if event.Quests and now >= (self._questLogAt or 0) then
            self._questLogAt = now + 600
            self._logger:info("Event", "Quests: " .. EventTasks.describeQuests(data:get(KEYS.Dailies)))
        end
        if event.HouseVisits ~= false and event.Quests and due("house_visits") and EventTasks.visitQuest(data:get(KEYS.Dailies)) then
            return "house_visits", "visit player homes (quest)", EventTasks.houseVisits, nil
        end
        if event.Quests and due("quests") and #EventTasks.questsToClaim(data:get(KEYS.Dailies)) > 0 then
            return "quests", "claim quests", EventTasks.quests, nil
        end
        if event.PigeonNest and due("pigeon_nest") and #data:itemsOfId(GameConstants.ToyCategory, E.Twig) > 0 then
            local nest = data:get(KEYS.PigeonNest)
            if type(nest) == "table" and (tonumber(nest.twigs_contributed) or 0) < E.NestTwigs then
                return "pigeon_nest", "twig to the pigeon nest", EventTasks.pigeonNest, nil
            end
        end
        -- User (2026-10-04): the pen takes no full grown pets -> keep PetPenSlots + 1 pets that still grow (pen + the
        -- farmed one); buy eggs (Farm.EggToBuy, Farm.BuyEgg, Farm.MaxEggBuysPerSession) until there are enough.
        if event.PetPen and event.PetPenStock ~= false and self._farmConfig.BuyEgg and due("pen_stock")
            and not self:_isBlocked("buy_egg") and data:get(KEYS.PetPen) ~= nil and data:petInventoryKnown()
            and self._travel and self._travel:isAt(GameConstants.HouseInteriorName) then
            local wanted = (tonumber(event.PetPenSlots) or E.PetPenSlots) + 1
            local inPen = 0
            for _ in pairs(data:petPenPets()) do
                inPen += 1
            end
            local stock = inPen + #data:growablePets()
            local max = tonumber(self._farmConfig.MaxEggBuysPerSession) or 0
            self._eggBuys = self._eggBuys or 0
            if stock < wanted and (max <= 0 or self._eggBuys < max) then
                self._logger:info("Event", string.format("Pet Pen stock: %d of %d pets still grow (pen %d): buying an egg",
                    stock, wanted, inPen))
                return "pen_stock", "buy an egg for the Pet Pen", Tasks.buyEgg, { onBought = function()
                    self._eggBuys += 1
                    self._nextEventAt.pet_pen = 0 -- put it in the pen right away
                end }
            end
        end
        if event.PetPen and due("pet_pen") and data:get(KEYS.PetPen) ~= nil and self._travel
            and self._travel:isAt(GameConstants.HouseInteriorName) then
            return "pet_pen", "Pet Pen", EventTasks.petPen, { keep = self._farmPet }
        end
        return nil
    end

    -- A single allowlisted call outside a task (cashback). Not sent while a task runs.
    function TaskManager:sendDirect(actionName, ...)
        if self._running or self._stopped then
            return false, "busy"
        end
        return self._interaction:send(actionName, ...)
    end

    function TaskManager:isBusy()
        return self._running ~= nil
    end

    function TaskManager:stop()
        if self._stopped then
            return
        end
        self._stopped = true
        if self._running then
            self:_finish("CANCELLED", "farm stopped")
        end
    end

    return TaskManager
end

-- ─────────────────────────────── module: main ───────────────────────────────
__moduleSources["main"] = function(...)
    --[[
        main
        Bootstrap: builds config, starts core services in order, prints the transparency report,
        starts the read-only game layer (Adopt Me only), registers scheduler jobs, exposes a control API:

          getgenv().AdoptMeFarm.Stop()        -- stops everything and cleans up
          getgenv().AdoptMeFarm.State         -- read-only use recommended
          getgenv().AdoptMeFarm.Version

        Executing the script again stops the previous instance first (no duplicate loops).
    ]]

    local import = ...
    local Enums = import("Core/Enums")
    local Util = import("Core/Util")
    local Config = import("Core/Config")
    local Maid = import("Core/Maid")
    local Logger = import("Core/Logger")
    local State = import("Core/State")
    local Scheduler = import("Core/Scheduler")
    local Disclosure = import("Services/Disclosure")
    local Notifier = import("Services/Notifier")
    local SessionWatcher = import("Services/SessionWatcher")
    local SessionStore = import("Services/SessionStore")
    local Telemetry = import("Services/Telemetry")
    local GameConstants = import("Game/GameConstants")
    local GameData = import("Game/GameData")
    local PetLocator = import("Game/PetLocator")
    local PlayerSync = import("Game/PlayerSync")
    local AilmentTracker = import("Game/AilmentTracker")
    local Interaction = import("Game/Interaction")
    local Travel = import("Game/Travel")
    local TaskManager = import("Game/TaskManager")
    local Furniture = import("Game/Furniture")
    local Minigame = import("Game/Minigame")

    local Players = game:GetService("Players")

    local GLOBAL_KEY = "AdoptMeFarm"
    local STOP_FLUSH_SECONDS = 6
    local SESSION_HEARTBEAT_SECONDS = 30
    local STATUS_CHECK_SECONDS = 5
    local TASK_TICK_SECONDS = 1

    local function buildSummaryFields(state, logger)
        local startedAt = state:get("session.startedAt", Util.now())
        local fields = {
            { name = "Session time", value = Util.formatDuration(Util.now() - startedAt), inline = true },
            { name = "Needs completed", value = tostring(state:get("stats.needsCompleted", 0)), inline = true },
            { name = "Bucks earned", value = tostring(state:get("stats.bucksEarned", 0)), inline = true },
        }
        local bucks = state:get("player.bucks")
        if bucks then
            table.insert(fields, { name = "Bucks", value = tostring(bucks), inline = true })
        end
        local pets = state:get("pets.equipped", {})
        if #pets > 0 then
            local names = {}
            for _, pet in ipairs(pets) do
                table.insert(names, pet.kind .. (pet.age and (" (age " .. pet.age .. ")") or ""))
            end
            table.insert(fields, { name = "Pet", value = table.concat(names, ", "), inline = true })
        end
        local lastTask = state:get("stats.lastTask")
        if lastTask then
            table.insert(fields, { name = "Last task", value = lastTask, inline = true })
        end
        table.insert(fields, { name = "Log counts", value = string.format("%d warnings, %d errors", logger.Counts.WARN, logger.Counts.ERROR), inline = true })
        return fields
    end

    -- One readable status line built only from State (so it shows exactly what the script believes)
    local function buildStatusLine(state, petLocator)
        local parts = {}
        table.insert(parts, "Bucks " .. tostring(state:get("player.bucks", "?")))
        table.insert(parts, "team " .. tostring(state:get("player.team", "?")))
        table.insert(parts, "in " .. tostring(state:get("player.interior", "?")))

        local petTexts = {}
        for _, pet in ipairs(state:get("pets.equipped", {})) do
            local model = petLocator:findModel(pet.unique)
            table.insert(petTexts, string.format("%s age %s%s", pet.kind, tostring(pet.age or "?"), model and "" or " [model not found]"))
        end
        table.insert(parts, "pets: " .. (#petTexts > 0 and table.concat(petTexts, ", ") or "none"))

        if not state:get("ailments.known", false) then
            table.insert(parts, "needs: unknown yet")
        else
            local needTexts = {}
            for _, entry in ipairs(state:get("ailments.active", {})) do
                local owner = entry.owner == "baby" and "baby" or tostring(entry.petKind or "pet")
                table.insert(needTexts, owner .. ":" .. entry.kind .. (entry.inProgress and "*" or ""))
            end
            table.insert(parts, "needs: " .. (#needTexts > 0 and table.concat(needTexts, ", ") or "none"))
        end
        table.insert(parts, "task: " .. tostring(state:get("farm.currentTask", "none")))
        return table.concat(parts, " | ")
    end

    -- launchInfo (from the START block): { fromLoader, loaderUrl, settingsSource }
    return function(userConfig, launchInfo)
        local sharedEnvironment = Util.getSharedEnvironment()

        -- 1. Stop a previous instance (re-execution guard)
        local previous = sharedEnvironment[GLOBAL_KEY]
        if type(previous) == "table" and type(previous.Stop) == "function" then
            pcall(previous.Stop, "replaced by a new execution")
        end

        -- 2. Config + logger
        local config, configWarnings = Config.build(userConfig)
        local maid = Maid.new()
        local logger = Logger.new(config.Logging)
        for _, warning in ipairs(configWarnings) do
            logger:warn("Config", warning)
        end

        -- 3. State
        local state = State.new()
        local localPlayer = Players.LocalPlayer
        state:set("session.startedAt", Util.now(), "main")
        state:set("player.name", localPlayer and localPlayer.Name or "?", "Players.LocalPlayer")
        state:set("stats.needsCompleted", 0, "main")
        state:set("stats.bucksEarned", 0, "main")

        -- 4. Notifier, session file, transparency report (always shown, cannot be disabled)
        local notifier = Notifier.new(config.Notifications, logger, config.General.ScriptName, Disclosure.VERSION)
        local sessionStore = SessionStore.new(logger, Disclosure.VERSION, config.Logging.SessionFile)
        local previousRun = sessionStore:begin()

        local files = {}
        local logFilePath, logFileProblem = logger:getFilePath()
        table.insert(files, logFilePath and ("log: " .. logFilePath) or ("no log file (" .. tostring(logFileProblem) .. ")"))
        if sessionStore:isAvailable() then
            table.insert(files, "session status: " .. SessionStore.PATH .. " (start time, last seen, clean stop, last Roblox message)")
        end
        local isAdoptMe = game.PlaceId == GameConstants.PlaceId
        local gameActionLines = isAdoptMe and Interaction.describeActions() or nil
        local telemetry = Telemetry.new(config.Telemetry, logger, Disclosure.VERSION, state)
        telemetry:start(maid)
        local disclosureLines = Disclosure.buildLines(config, files, notifier:getStatusText(), launchInfo, gameActionLines,
            telemetry:statusText())
        for _, line in ipairs(Disclosure.buildStartLines(config, files, notifier:getStatusText(), telemetry:statusText(), launchInfo)) do
            logger:report("Disclosure", line)
        end

        -- 5. Forward this script's own errors to the Alerts webhook (never the Notifier's own errors: no loops)
        maid:Give(logger.OnEntry:Connect(function(level, category, message)
            if level == Enums.LogLevel.ERROR and category ~= "Notifier" then
                notifier:notify(Enums.NotifyEvent.Error, { { name = "Error", value = category .. ": " .. message } })
            end
        end))

        -- 6. Report how the previous run ended (only if it ended without Stop())
        if previousRun then
            local description = SessionStore.describe(previousRun)
            logger:warn("Session", description)
            notifier:notify(Enums.NotifyEvent.PreviousSessionEnded, {
                { name = "Previous session", value = description },
            })
        end

        -- 7. Read-only game layer (Adopt Me only)
        local petLocator = nil
        local taskManager = nil
        if not isAdoptMe then
            logger:warn("Game", string.format("PlaceId %s is not Adopt Me (%d): game features are off", tostring(game.PlaceId), GameConstants.PlaceId))
        else
            -- Wait for Roblox to finish loading the game (user request 2026-09-28).
            local loadedOk, isLoaded = pcall(function()
                return game:IsLoaded()
            end)
            if loadedOk and not isLoaded then
                logger:info("Game", "Waiting for game:IsLoaded()...")
                game.Loaded:Wait()
            end
            -- Started before the game finished loading (live 2026-09-27: "ReplicatedStorage.API not found" twice):
            -- wait up to 2 minutes for the API folder instead of giving up.
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            if not ReplicatedStorage:FindFirstChild(GameConstants.Remotes.Folder) then
                logger:info("Game", "Waiting for the game to finish loading...")
                local waited = 0
                while not ReplicatedStorage:FindFirstChild(GameConstants.Remotes.Folder) and waited < 120 do
                    task.wait(1)
                    waited += 1
                end
            end
            local interaction = Interaction.new(logger, state)
            -- Main menu (live 0.7.3: the character ALREADY exists behind the menu, so "no character" is not the test).
            -- Menu open = the Play button exists, is visible and its ScreenGui is enabled. Success = the menu closed.
            local localPlayer = game:GetService("Players").LocalPlayer
            local playerGui = type(localPlayer.FindFirstChild) == "function" and localPlayer:FindFirstChild("PlayerGui")
            local function findPlayButton()
                local node = playerGui
                for _, name in ipairs(GameConstants.PlayButtonPath) do
                    node = node and node:FindFirstChild(name)
                end
                return node
            end
            local function menuOpen(button)
                local ok, open = pcall(function()
                    local menu = playerGui:FindFirstChild(GameConstants.PlayButtonPath[1])
                    return button.Parent ~= nil and button.Visible ~= false and (menu == nil or menu.Enabled ~= false)
                end)
                return ok and open == true
            end
            -- Live 0.7.5/0.7.6: the menu appears some seconds AFTER loading, so a one-time check missed it.
            -- Now a background watcher looks for the open menu every second for 3 minutes (never blocks the farm).
            -- Clicks `button` with each method until isOpen() turns false. Logs which method worked.
            local function clickUntilClosed(label, button, isOpen)
                logger:info("Game", label .. " is open: clicking")
                for _, method in ipairs(Interaction.CLICK_METHODS) do
                    local ran, detail = Interaction.clickButton(button, method)
                    if ran then
                        local waited = 0
                        while isOpen() and waited < 8 do
                            task.wait(1)
                            waited += 1
                        end
                        if not isOpen() then
                            logger:success("Game", label .. ": click worked (" .. method .. ")")
                            return true
                        end
                        logger:warn("Game", label .. ": click (" .. method .. ") had no effect " .. tostring(detail or ""))
                    else
                        logger:warn("Game", label .. ": click (" .. method .. ") not available: " .. tostring(detail))
                    end
                end
                logger:warn("Game", "Could not close " .. label .. "; please tap it yourself")
                return false
            end

            -- A visible text (TextLabel/TextButton) on an enabled ScreenGui, found by its words, and the button
            -- that holds it. Used for the "Choose Location!" dialog after Play (screenshot 2026-09-28).
            local function isOnScreen(object)
                local ok, visible = pcall(function()
                    local screenGui = object:FindFirstAncestorOfClass("ScreenGui")
                    if not screenGui or not screenGui.Enabled then
                        return false
                    end
                    local node = object
                    while node and node ~= screenGui do
                        if node:IsA("GuiObject") and node.Visible == false then
                            return false
                        end
                        node = node.Parent
                    end
                    return true
                end)
                return ok and visible == true
            end
            local function findText(root, pattern)
                for _, object in ipairs(root:GetDescendants()) do
                    if (object:IsA("TextLabel") or object:IsA("TextButton")) and type(object.Text) == "string" and string.find(string.lower(object.Text), pattern)
                        and isOnScreen(object) then
                        return object
                    end
                end
                return nil
            end
            local function handleLocationDialog()
                for _ = 1, 30 do
                    local title = findText(playerGui, "choose location")
                    if title then
                        task.wait(1.5) -- let it animate in
                        local dialog = title:FindFirstAncestorOfClass("ScreenGui")
                        local homeText = findText(dialog, "^%s*home%s*$")
                        local homeButton = homeText and (homeText:IsA("GuiButton") and homeText or homeText:FindFirstAncestorWhichIsA("GuiButton"))
                        if homeButton then
                            clickUntilClosed("Choose Location (Home)", homeButton, function()
                                return isOnScreen(title)
                            end)
                        else
                            local names = {}
                            for _, object in ipairs(dialog:GetDescendants()) do
                                if object:IsA("GuiButton") and isOnScreen(object) then
                                    table.insert(names, object:GetFullName())
                                end
                            end
                            logger:warn("Game", "Choose Location dialog: no HOME button found. Visible buttons: "
                                .. table.concat(names, " | "))
                        end
                        return
                    end
                    task.wait(1)
                end
                logger:debug("Game", "No Choose Location dialog after Play")
            end

            -- Promotion popups after Play (screenshot 2026-09-28: "SALE ... BUY BUCKS" with a red X): the pet does not
            -- come until it is closed. Only a CLOSE button is ever clicked (name close/exit/x); a button that says or is
            -- named buy/purchase/robux is NEVER clicked. Verified by the popup text disappearing.
            local POPUP_TEXTS = { "buy bucks", "^%s*sale%s*$" }
            local function isForbidden(button)
                local function bad(text)
                    text = string.lower(tostring(text or ""))
                    return string.find(text, "buy") ~= nil or string.find(text, "purchase") ~= nil or string.find(text, "robux") ~= nil
                end
                if bad(button.Name) or (button:IsA("TextButton") and bad(button.Text)) then
                    return true
                end
                for _, object in ipairs(button:GetDescendants()) do
                    if (object:IsA("TextLabel") or object:IsA("TextButton")) and bad(object.Text) then
                        return true
                    end
                end
                return false
            end
            local function closePopups()
                local quietSeconds = 0
                for _ = 1, 90 do
                    local marker
                    for _, pattern in ipairs(POPUP_TEXTS) do
                        marker = marker or findText(playerGui, pattern)
                    end
                    if not marker then
                        quietSeconds += 1
                        if quietSeconds >= 15 then
                            -- For the next version: which ScreenGuis show a close-like button now (SALE text may be an image)
                            local seen = {}
                            for _, object in ipairs(playerGui:GetDescendants()) do
                                local name = string.lower(object.Name)
                                if object:IsA("GuiButton") and (string.find(name, "close") or string.find(name, "exit") or name == "x")
                                    and isOnScreen(object) then
                                    table.insert(seen, object:GetFullName())
                                end
                            end
                            logger:debug("Game", "No popup text found. Visible close-like buttons: "
                                .. (#seen > 0 and table.concat(seen, " | ") or "none"))
                            return
                        end
                    else
                        quietSeconds = 0
                        task.wait(1.5)
                        local popupGui = marker:FindFirstAncestorOfClass("ScreenGui")
                        local closeButton
                        local visibleNames = {}
                        for _, object in ipairs(popupGui:GetDescendants()) do
                            if object:IsA("GuiButton") and isOnScreen(object) then
                                table.insert(visibleNames, object:GetFullName())
                                local name = string.lower(object.Name)
                                if not closeButton and not isForbidden(object)
                                    and (string.find(name, "close") or string.find(name, "exit") or name == "x") then
                                    closeButton = object
                                end
                            end
                        end
                        if not closeButton then
                            logger:warn("Game", "Popup '" .. tostring(marker.Text) .. "': no close button found. Visible buttons: "
                                .. table.concat(visibleNames, " | "))
                            return
                        end
                        if not clickUntilClosed("Popup '" .. tostring(marker.Text) .. "' (close)", closeButton, function()
                            return isOnScreen(marker)
                        end) then
                            return
                        end
                    end
                    task.wait(1)
                end
            end

            if config.Farm.Enabled and config.Farm.AutoAcceptMenu and playerGui then
                local function watchMenu()
                    for _ = 1, 180 do
                        local button = findPlayButton()
                        if button and menuOpen(button) then
                            task.wait(2) -- the menu is still animating in when it first becomes visible
                            if clickUntilClosed("Main menu (Play)", button, function()
                                return menuOpen(button)
                            end) then
                                handleLocationDialog()
                                closePopups()
                            end
                            return
                        end
                        task.wait(1)
                    end
                    logger:debug("Game", "Main menu not seen within 3 minutes (already playing?)")
                end
                maid:Give(task.spawn(watchMenu))
            end
            local gameData = GameData.new(logger)
            telemetry:setGameData(gameData)
            maid:Give(function()
                gameData:destroy()
            end)
            petLocator = PetLocator.new(gameData)
            if gameData:start(maid) then
                PlayerSync.start(maid, state, gameData, petLocator, logger)
                local tracker = AilmentTracker.new(logger, state, notifier, gameData)
                tracker:start(maid)
                local minigame = Minigame.new(logger)
                minigame:start(maid)
                taskManager = TaskManager.new({
                    minigame = minigame,
                    logger = logger,
                    state = state,
                    tracker = tracker,
                    interaction = interaction,
                    travel = Travel.new(logger, state, interaction, config.Farm),
                    petLocator = petLocator,
                    furniture = Furniture.new(gameData, state),
                    gameData = gameData,
                    farmConfig = config.Farm,
                })
                taskManager:start(maid)
                state:set("game.ready", true, "main")
            else
                state:set("game.ready", false, "main")
            end
        end

        -- 8. Scheduler jobs
        local scheduler = Scheduler.new(logger, config.General.TickSeconds)
        scheduler:addJob("LogFlush", config.Logging.FlushSeconds, function()
            logger:flush()
        end)
        scheduler:addJob("TelemetryPump", 5, function()
            telemetry:pump()
        end)
        scheduler:addJob("NotifierPump", 1, function()
            notifier:pump()
        end, { runImmediately = true })
        scheduler:addJob("SessionHeartbeat", SESSION_HEARTBEAT_SECONDS, function()
            sessionStore:heartbeat()
        end)
        if notifier:isEnabled() and config.Notifications.SummaryIntervalMinutes > 0 then
            scheduler:addJob("SummaryWebhook", config.Notifications.SummaryIntervalMinutes * 60, function()
                notifier:notify(Enums.NotifyEvent.Summary, buildSummaryFields(state, logger))
            end)
        end
        if petLocator then
            local lastStatus = nil
            scheduler:addJob("GameStatus", STATUS_CHECK_SECONDS, function()
                local status = buildStatusLine(state, petLocator)
                if status ~= lastStatus then
                    lastStatus = status
                    logger:info("Status", status)
                end
            end, { runImmediately = true })
        end
        if taskManager then
            scheduler:addJob("Tasks", TASK_TICK_SECONDS, function()
                taskManager:tick()
            end)
        end
        -- Cashback: PayAPI/Collect (user's capture, 2026-09-28). Verified by my Bucks going up; logged either way.
        if taskManager and config.Farm.Enabled and config.Farm.CollectCashback then
            scheduler:addJob("Cashback", config.Farm.CashbackMinutes * 60, function()
                if state:get("game.ready") ~= true or state:get("session.disconnectReason") ~= nil then
                    return
                end
                local before = state:get("player.bucks")
                taskManager:sendDirect("CollectCashback")
                task.delay(5, function()
                    local after = state:get("player.bucks")
                    if type(before) == "number" and type(after) == "number" and after > before then
                        logger:success("Cashback", string.format("Collected: +%d Bucks", after - before))
                    else
                        logger:debug("Cashback", "Nothing collected (Bucks unchanged)")
                    end
                end)
            end)
        end
        scheduler:addJob("Heartbeat", 60, function()
            logger:debug("Core", string.format("Heartbeat: ticks=%d, webhook sent=%d dropped=%d pending=%d",
                scheduler.TickCount, notifier.SentCount, notifier.DroppedCount, notifier:pendingCount()))
        end)

        -- 9. Session watcher (kick/disconnect)
        SessionWatcher.start(maid, logger, notifier, state, sessionStore)

        -- 9b. Anti-AFK (live 2026-09-27: "You were disconnected for being idle 20 minutes"; remote calls are not input).
        -- Roblox fires LocalPlayer.Idled before the idle kick; a virtual click (VirtualUser) counts as input. No remote.
        if config.Farm.Enabled and config.Farm.AntiAfk then
            local localPlayer = game:GetService("Players").LocalPlayer
            local idled = localPlayer and localPlayer.Idled
            if idled then
                maid:Give(idled:Connect(function()
                    local ok, reason = Interaction.virtualClick()
                    if ok then
                        logger:info("AntiAfk", "Idle warning from Roblox: sent a virtual click")
                    else
                        logger:warn("AntiAfk", "Virtual click failed: " .. tostring(reason))
                    end
                end))
            else
                logger:warn("AntiAfk", "LocalPlayer.Idled not available: idle kick cannot be prevented")
            end
        end

        -- 10. Start
        notifier:notify(Enums.NotifyEvent.SessionStarted, {
            { name = "Session time", value = "00:00:00", inline = true },
        }, Disclosure.buildShortText())
        if config.Notifications.SendTestMessageOnStart then
            notifier:notify(Enums.NotifyEvent.Test, {}, "If you can read this, the webhook works.")
        end
        scheduler:start()
        logger:success("Core", "Started. Version " .. Disclosure.VERSION)

        -- 11. Control API
        local api = { Version = Disclosure.VERSION, State = state, Disclosure = function()
            for _, line in ipairs(disclosureLines) do
                logger:report("Disclosure", line)
            end
        end }
        local stopped = false

        function api.Stop(reason)
            if stopped then
                return
            end
            stopped = true
            reason = tostring(reason or "stopped by user")
            scheduler:stop()
            if taskManager then
                taskManager:stop()
            end
            sessionStore:markCleanStop()
            logger:info("Core", "Stopping: " .. reason)
            telemetry:pump(true) -- last report of this session
            notifier:notify(Enums.NotifyEvent.SessionStopped, buildSummaryFields(state, logger), "Reason: " .. reason)
            if sharedEnvironment[GLOBAL_KEY] == api then
                sharedEnvironment[GLOBAL_KEY] = nil
            end
            maid:Clean()
            -- Final webhook flush + log close run in their own thread so Stop() returns immediately
            task.spawn(function()
                notifier:flush(STOP_FLUSH_SECONDS)
                logger:info("Core", "Stopped cleanly")
                logger:close()
                state:destroy()
            end)
        end

        sharedEnvironment[GLOBAL_KEY] = api
        return api
    end
end

--==================================================================================
--  START
--  Settings come from your loader (getgenv().AdoptMeFarmSettings) when present,
--  otherwise from the SETTINGS block at the top of this file.
--==================================================================================
local startOk, startError = pcall(function()
    local environment = (type(getgenv) == "function" and getgenv()) or _G
    local settings = UserConfig
    local launchInfo = { fromLoader = false, settingsSource = "SETTINGS block in this file" }
    if type(environment.AdoptMeFarmSettings) == "table" then
        settings = environment.AdoptMeFarmSettings
        launchInfo.settingsSource = "your loader (getgenv().AdoptMeFarmSettings)"
    end
    local loaderInfo = environment.AdoptMeFarmLoaderInfo
    if type(loaderInfo) == "table" and type(loaderInfo.Url) == "string" then
        launchInfo.fromLoader = true
        launchInfo.loaderUrl = loaderInfo.Url
    end
    return import("main")(settings, launchInfo)
end)
if not startOk then
    warn("[AdoptMe Farm] Failed to start: " .. tostring(startError))
end
