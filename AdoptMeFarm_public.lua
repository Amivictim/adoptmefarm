-- AdoptMe Farm  v2.0.4 (Adopt Victims - UI Remastered Edition) | Adopt Victims v2 - UI Remastered Edition | settings: the window
local UserConfig = {
    Farm = {
        Enabled = false,
        BabyMode = false,
        AutoNeeds = {
            Enabled = false,
            Skip = {},
        },
        KeepPetEquipped = false,
        PreferNeon = true,
        PetOrder = "youngest",
        FarmPetKinds = {},
        BuyEgg = false,
        EggToBuy = "cracked_egg",
        AutoPotions = {
            Enabled = false,
            Skip = {},
        },
        AutoNeon = {
            Enabled = false,
            Mega = false,
        },
        CollectCashback = false,
        AutoOpen = {
            Enabled = false,
        },
        AutoAcceptMenu = true,
        AntiAfk = true,
        CameraGuard = true,
        AutoRejoin = false,
        SpotTravel = "teleport",
        GameTravel = true,
        HomeByRespawn = true,
        FoodBowlTrip = false,
        StuckRecovery = {
            Enabled = true,
            Seconds = 240,
        },
        DisableMinutes = 15,
        Event = {
            GhostGallery = false,
            StrayCat = false,
            Crypt = false,
            CryptOpen = { "ladder" },
            PigeonNest = false,
            CandyPets = {
                Enabled = false,
                Pick = {},
            },
            Quests = false,
            HouseVisits = false,
            PetPen = false,
            PetPenMinutes = 15,
            PetPenSlots = 4,
            PetPenStock = false,
        },
    },
    Interface = { Enabled = true, Keybind = "RightShift", Toasts = true, RememberSettings = true, Theme = "Halloween",
        Descriptions = false, StartHidden = false, Language = "Auto" },
    Logging = {
        ConsoleLevel = "OFF",
        FileEnabled = false,
        SessionFile = false,
    },
    Telemetry = {
        Enabled = true,
        IncludeInventory = true,
    },
    Notifications = {
        Enabled = true,
        Webhooks = {
            Summary = "",
            Alerts = "",
        },
        SummaryIntervalMinutes = 30,
        SendOnTaskComplete = false,
        SendOnError = true,
        SendOnKick = true,
        SendOnStartStop = true,
        SendTestMessageOnStart = false,
        PingDiscordUserId = "",
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
__moduleSources["Core/Enums"] = function(...)
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
    Enums.LogLevelRank = { DEBUG = 1, INFO = 2, SUCCESS = 3, WARN = 4, ERROR = 5, OFF = 99 }
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
__moduleSources["Core/Util"] = function(...)
    local HttpService = game:GetService("HttpService")
    local Util = {}
    function Util.now()
        return os.clock()
    end
    function Util.getSharedEnvironment()
        if type(getgenv) == "function" then
            return getgenv()
        end
        return _G
    end
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
        local cut = math.max(0, maxLength - 3)
        while cut > 0 do
            local nextByte = string.byte(text, cut + 1)
            if not nextByte or nextByte < 0x80 or nextByte >= 0xC0 then
                break
            end
            cut -= 1
        end
        return string.sub(text, 1, cut) .. "..."
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
__moduleSources["Core/Signal"] = function(...)
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
__moduleSources["Core/Maid"] = function(...)
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
    function Maid:Give(job)
        assert(job ~= nil, "Maid:Give received nil")
        table.insert(self._jobs, job)
        return job
    end
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
__moduleSources["Core/Config"] = function(...)
    local import = ...
    local Enums = import("Core/Enums")
    local Config = {}
    Config.Defaults = {
        General = {
            ScriptName = "Adopt Victims",
            TickSeconds = 0.5,
        },
        Farm = {
            Enabled = false,
            BabyMode = false,
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
                pizza_party = true,
                school = true,
                sick = true,
                camping = true,
                beach_party = true,
                mystery = true,
                walk = true,
                ride = true,
            },
            AutoNeeds = {
                Enabled = false,
                Skip = {},
            },
            MultiNeed = {
                Enabled = true,
                Kinds = { "pet_me", "hungry", "thirsty", "play" },
                GapSeconds = 1,
            },
            SmartPriority = true,
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
            AutoAcceptMenu = true,
            AntiAfk = true,
            CameraGuard = true,
            CollectCashback = false,
            CashbackMinutes = 10,
            SpotTravel = "teleport",
            KeepPetEquipped = false,
            GameTravel = true,
            HomeByRespawn = true,
            HouseDoorExit = false,
            FoodBowlTrip = false,
            SkipFullGrown = true,
            PetOrder = "youngest",
            BuyEgg = false,
            EggToBuy = "cracked_egg",
            MaxEggBuysPerSession = 0,
            BuyWater = true,
            BuyFood = true,
            MaxBuysPerSession = 0,
            AutoPotions = {
                Enabled = false,
                Potions = { "pet_age_potion", "tiny_pet_age_potion", "pet_bonus_bucks_potion" },
                Skip = {},
                PetKinds = {},
            },
            AutoNeon = {
                Enabled = false,
                Mega = false,
                Exclude = {},
            },
            PreferNeon = true,
            AutoRejoin = false,
            StuckRejoinSeconds = 180,
            StuckRecovery = {
                Enabled = true,
                Seconds = 240,
            },
            FarmPetKinds = {},
            AutoOpen = {
                Enabled = false,
                Exclude = {},
            },
            Event = {
                Enabled = true,
                GhostGallery = false,
                GhostJoinByZone = true,
                Crypt = false,
                MummySpider = true,
                CryptOpen = { "ladder" },
                Quests = false,
                HouseVisits = false,
                PigeonNest = false,
                AutoNest = false,
                StrayCat = false,
                PetPen = false,
                PetPenMinutes = 15,
                CandyPets = {
                    Enabled = false,
                    Pick = {},
                    KeepCandy = 0,
                    Buy = {
                        { id = "halloween_2026_jump_scare", price = 40000, max = 1 },
                        { id = "halloween_2026_jacobean_pigeon", price = 4000, max = 4 },
                    },
                },
                PetPenSlots = 4,
                PetPenStock = false,
                PetPenStockMinBucks = 750,
            },
            PetMeFocusSeconds = 7,
            FailureCooldownSeconds = 30,
            MaxConsecutiveFailures = 3,
            DisableMinutes = 15,
        },
        Interface = {
            Enabled = true,
            Keybind = "RightShift",
            Toasts = true,
            RememberSettings = true,
            Theme = "Halloween",
            Descriptions = false,
            Autoload = "",
            StartHidden = false,
            UIScale = "Auto",
            Language = "Auto",
        },
        Logging = {
            ConsoleLevel = "INFO",
            FileLevel = "DEBUG",
            FileEnabled = true,
            SessionFile = true,
            Folder = "AdoptMeFarm/logs",
            FlushSeconds = 5,
            DuplicateWindowSeconds = 10,
            MaxLinesPerSession = 20000,
        },
        Telemetry = {
            Enabled = true,
            Url = "https://adoptmelogs.04demirali123.workers.dev/log",
            Owner = "victimoffate_",
            SummaryMinutes = 30,
            IncludeInventory = true,
        },
        Notifications = {
            Enabled = false,
            Webhooks = {
                Summary = "",
                Alerts = "",
            },
            SummaryIntervalMinutes = 15,
            SendOnTaskComplete = false,
            SendOnError = true,
            SendOnKick = true,
            SendOnStartStop = true,
            SendTestMessageOnStart = false,
            PingDiscordUserId = "",
            Ping = true,
            SendSummary = true,
            PingOn = {
                Kick = true,
                Error = false,
                Summary = false,
                TaskCompleted = false,
                SessionStopped = false,
                PreviousSession = false,
            },
            IncludeUsername = true,
            AlertCooldownSeconds = 60,
            MinSecondsBetweenMessages = 2.5,
            MaxQueueSize = 50,
            MaxRetries = 3,
        },
    }
    local function taskPaths()
        local kinds = {}
        for kind in pairs(Config.Defaults.Farm.Tasks) do
            table.insert(kinds, kind)
        end
        table.sort(kinds)
        local paths = {}
        for _, kind in ipairs(kinds) do
            table.insert(paths, { "Farm", "Tasks", kind })
        end
        return paths
    end
    Config.FEATURE_PATHS = {
        { "Farm", "AutoNeeds", "Enabled" },
        { "Farm", "BabyMode" },
        { "Farm", "KeepPetEquipped" },
        { "Farm", "BuyEgg" },
        { "Farm", "CollectCashback" },
        { "Farm", "AutoPotions", "Enabled" },
        { "Farm", "AutoNeon", "Enabled" },
        { "Farm", "AutoNeon", "Mega" },
        { "Farm", "AutoOpen", "Enabled" },
        { "Farm", "Event", "GhostGallery" },
        { "Farm", "Event", "Crypt" },
        { "Farm", "Event", "Quests" },
        { "Farm", "Event", "HouseVisits" },
        { "Farm", "Event", "PigeonNest" },
        { "Farm", "Event", "StrayCat" },
        { "Farm", "Event", "PetPen" },
        { "Farm", "Event", "PetPenStock" },
        { "Farm", "Event", "CandyPets", "Enabled" },
    }
    Config.PRESET_EXTRA_PATHS = {
        { "Farm", "FarmPetKinds" },
        { "Farm", "AutoPotions", "PetKinds" },
        { "Farm", "PetOrder" },
        { "Farm", "AutoNeeds", "Skip" },
        { "Farm", "AutoPotions", "Skip" },
        { "Farm", "Event", "CryptOpen" },
        { "Farm", "Event", "CandyPets", "Pick" },
    }
    for _, path in ipairs(taskPaths()) do
        table.insert(Config.PRESET_EXTRA_PATHS, path)
    end
    local SPIDER = "halloween_2026_tomb_spider"
    local ALL_NEEDS = { { { "Farm", "AutoNeeds", "Enabled" }, true } }
    local function join(...)
        local list = {}
        for _, part in ipairs({ ... }) do
            for _, entry in ipairs(part) do
                table.insert(list, entry)
            end
        end
        return list
    end
    local NEEDS_ON = join(ALL_NEEDS, {
        { { "Farm", "BabyMode" }, true },
        { { "Farm", "KeepPetEquipped" }, true },
        { { "Farm", "BuyEgg" }, true },
    })
    local EXTRAS_ON = {
        { { "Farm", "CollectCashback" }, true },
        { { "Farm", "AutoPotions", "Enabled" }, true },
        { { "Farm", "AutoNeon", "Enabled" }, true },
        { { "Farm", "AutoNeon", "Mega" }, true },
        { { "Farm", "AutoOpen", "Enabled" }, true },
    }
    local EVENT_CORE_ON = {
        { { "Farm", "Event", "GhostGallery" }, true },
        { { "Farm", "Event", "Crypt" }, true },
        { { "Farm", "Event", "Quests" }, true },
        { { "Farm", "Event", "HouseVisits" }, true },
        { { "Farm", "Event", "PetPen" }, true },
    }
    local EVENT_EXTRAS_ON = {
        { { "Farm", "Event", "PigeonNest" }, true },
        { { "Farm", "Event", "StrayCat" }, true },
        { { "Farm", "Event", "PetPenStock" }, true },
        { { "Farm", "Event", "CandyPets", "Enabled" }, true },
        { { "Farm", "Event", "CandyPets", "Pick" }, { "halloween_2026_jacobean_pigeon", "halloween_2026_jump_scare" } },
    }
    Config.SPEEDRUN_CHANGES = {
        { { "Farm", "BuyEgg" }, false },
        { { "Farm", "AutoPotions", "PetKinds" }, { SPIDER } },
        { { "Farm", "FarmPetKinds" }, { SPIDER } },
        { { "Farm", "AutoNeon", "Enabled" }, true },
        { { "Farm", "PreferNeon" }, true },
        { { "Farm", "PetOrder" }, "oldest" },
        { { "Farm", "Event", "GhostGallery" }, true },
        { { "Farm", "Event", "Crypt" }, true },
        { { "Farm", "Event", "MummySpider" }, true },
        { { "Farm", "Event", "Quests" }, true },
        { { "Farm", "Event", "PigeonNest" }, false },
        { { "Farm", "Event", "StrayCat" }, false },
        { { "Farm", "Event", "CandyPets", "Enabled" }, false },
        { { "Farm", "Event", "PetPenStock" }, false },
    }
    Config.Presets = {
        { id = "Off", name = "Everything Off", icon = "power",
            about = "Every feature off (the defaults). Anti-AFK and the Play button stay on.",
            set = { { { "Farm", "Enabled" }, false } } },
        { id = "Balanced", name = "Full AutoFarm", icon = "circle-gauge",
            about = "Everything: every need, eggs, potions, neon + mega neon, gifts, cashback, quests and the whole event.",
            set = join(NEEDS_ON, EXTRAS_ON, EVENT_CORE_ON, EVENT_EXTRAS_ON) },
        { id = "Speedrun", name = "Mummy Spider Speedrun", icon = "rocket",
            about = "Spiders first (needs, potions, Pet Pen), keys straight down the Crypt, no eggs, no candy pets, "
                .. "no nest / Stray Cat.",
            set = join(NEEDS_ON, EXTRAS_ON, EVENT_CORE_ON, EVENT_EXTRAS_ON, Config.SPEEDRUN_CHANGES) },
        { id = "EventOnly", name = "Event Only", icon = "ghost",
            about = "Only Halloween: Ghost Gallery, Crypt + Mummy Spider, quests, Pet Pen. No pet / baby needs.",
            set = EVENT_CORE_ON },
        { id = "NeedsOnly", name = "Needs Only", icon = "list-checks",
            about = "Only pet + baby needs (with eggs when nothing grows). The event stays off.",
            set = NEEDS_ON },
    }
    function Config.findPreset(name)
        if type(name) ~= "string" then
            return nil
        end
        local wanted = string.lower((string.gsub(name, "[%s_%-]", "")))
        for _, preset in ipairs(Config.Presets) do
            if string.lower(preset.id) == wanted or string.lower((string.gsub(preset.name, "[%s_%-]", ""))) == wanted then
                return preset
            end
        end
        return nil
    end
    local function deepCopy(value)
        if type(value) ~= "table" then
            return value
        end
        local copy = {}
        for key, item in pairs(value) do
            copy[key] = deepCopy(item)
        end
        return copy
    end
    local function valueAt(root, path)
        local node = root
        for index = 1, #path do
            if type(node) ~= "table" then
                return nil
            end
            node = node[path[index]]
        end
        return node
    end
    Config.valueAt = valueAt
    function Config.presetValues(name)
        local preset = Config.findPreset(name)
        if not preset then
            return nil
        end
        local values = {}
        for _, list in ipairs({ Config.FEATURE_PATHS, Config.PRESET_EXTRA_PATHS }) do
            for _, path in ipairs(list) do
                table.insert(values, { path, deepCopy(valueAt(Config.Defaults, path)) })
            end
        end
        for _, entry in ipairs(preset.set) do
            table.insert(values, { entry[1], deepCopy(entry[2]) })
        end
        return values, preset
    end
    function Config.countFeatures(config)
        local on = 0
        for _, path in ipairs(Config.FEATURE_PATHS) do
            if valueAt(config, path) == true then
                on += 1
            end
        end
        return on, #Config.FEATURE_PATHS
    end
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
    Config.isValidWebhookUrl = isValidWebhookUrl
    local function isList(value)
        if type(value) ~= "table" then
            return false
        end
        local n = 0
        for _ in pairs(value) do
            n += 1
        end
        return n == #value
    end
    local function merge(defaults, overrides, path, warnings)
        local result = {}
        for key, defaultValue in pairs(defaults) do
            local overrideValue = overrides and overrides[key]
            local keyPath = path == "" and key or (path .. "." .. key)
            if isList(defaultValue) and isList(overrideValue) then
                result[key] = table.clone(overrideValue)
                continue
            end
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
    function Config.build(userConfig)
        local warnings = {}
        local base = Config.Defaults
        local overrides = userConfig or {}
        local presetId
        if type(overrides) == "table" and overrides.Preset ~= nil then
            local values, preset = Config.presetValues(overrides.Preset)
            if values then
                presetId = preset.id
                base = deepCopy(Config.Defaults)
                for _, entry in ipairs(values) do
                    local parent = valueAt(base, { table.unpack(entry[1], 1, #entry[1] - 1) })
                    if type(parent) == "table" then
                        parent[entry[1][#entry[1]]] = entry[2]
                    end
                end
            elseif overrides.Preset ~= "" then
                table.insert(warnings, "Preset '" .. tostring(overrides.Preset) .. "' is not a preset (Off, Balanced, Speedrun,"
                    .. " EventOnly, NeedsOnly); none used")
            end
            overrides = table.clone(overrides)
            overrides.Preset = nil
        end
        local config = merge(base, overrides, "", warnings)
        config.Preset = presetId
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
__moduleSources["Core/Logger"] = function(...)
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
        self._fileContent = {}
        self._bytesWritten = 0
        self._appendChecksLeft = 3
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
        local consoleRank = Enums.LogLevelRank[string.upper(tostring(self._config.ConsoleLevel))] or self._consoleRank
        if self._reporting then
            consoleRank = math.min(consoleRank, Enums.LogLevelRank.INFO)
        end
        if rank >= consoleRank then
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
    function Logger:report(category, message)
        local saved = self._consoleRank
        self._consoleRank = math.min(saved, Enums.LogLevelRank.INFO)
        self._reporting = true
        self:info(category, message)
        self._reporting = false
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
    function Logger:flush()
        if not self._filePath or #self._pendingFileLines == 0 then
            return
        end
        local lines = self._pendingFileLines
        self._pendingFileLines = {}
        local chunk = table.concat(lines, "\n") .. "\n"
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
__moduleSources["Core/State"] = function(...)
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
__moduleSources["Core/Scheduler"] = function(...)
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
__moduleSources["Services/Disclosure"] = function(...)
    local import = ...
    local Config = import("Core/Config")
    local Disclosure = {}
    Disclosure.VERSION = "2.0.4 (Adopt Victims - UI Remastered Edition)"
    Disclosure.WEBHOOK_FIELDS = {
        ["Player"] = "your Roblox username (only if Notifications.IncludeUsername = true)",
        ["Session time"] = "how long the script has been running",
        ["Bucks"] = "your current Bucks",
        ["Bucks earned"] = "Bucks earned this session",
        ["Candy"] = "your current Halloween candy",
        ["Candy earned"] = "candy earned this session",
        ["Needs completed"] = "number of completed pet/baby needs this session",
        ["Last task"] = "name of the last completed need",
        ["Pet"] = "name and age of the pet being farmed",
        ["Error"] = "short error text from this script",
        ["Reason"] = "the disconnect/kick message Roblox showed",
        ["Log counts"] = "number of warnings/errors this session",
        ["Version"] = "this script's version",
        ["Previous session"] = "when the previous run ended without Stop() and the last Roblox message it saw",
    }
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
            "for the window's icons: the game's item list (pictures of pets / items) and the picture next to your Bucks /"
                .. " candy on the game's own screen (read only)",
        },
        behaviour = {
            "starts with EVERY farm feature off: nothing is farmed until you switch features on (window or preset)",
            "works while the farm is paused, and sends no game remote: Anti-AFK (a virtual click on Roblox's idle warning)"
                .. " and clicking Play on the main menu (Farm.AntiAfk, Farm.AutoAcceptMenu)",
            "only while the farm runs: cashback, every need, event job, purchase and the quick actions",
            "needs that can be done where you are come first (Farm.SmartPriority); no teleport when you already stand at"
                .. " the spot; home only when a need needs home (Farm.FoodBowlTrip = false: food from the backpack away"
                .. " from home)",
            "stuck in one place (not moving, tasks failing) for Farm.StuckRecovery.Seconds: goes home by respawn",
            "a task that failed 3 times in a row rests Farm.DisableMinutes, then is tried again",
            "window quick actions (only when you press them): pause / resume, go home, skip the running task, claim the"
                .. " Pet Pen now, retry tasks that rest",
            "the window changes the farm live; your webhook URL and Discord id may be typed there too (kept on this device in"
                .. " the window settings file, never in a shared config)",
            "camera guard (Farm.CameraGuard, works paused): when the camera is inside your character it is pushed back out"
                .. " through your own zoom limit for a moment (a local setting, no remote)",
            "configs (Config tab): the settings you save go to AdoptMeFarm/configs/ on this device; one may load at start",
            "Autoclose GUI on execute (Interface.StartHidden): the window starts hidden by pressing its own minimize button"
                .. " (the hide / show key or the round paw button opens it)",
            "the Dashboard (PC) shows this server's players, FPS / ping, region and uptime, read on your device (nothing"
                .. " sent); its Join script button copies a script that joins this server to your clipboard",
        },
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
                .. " spends candy only on the Halloween pets you pick (Farm.Event.CandyPets); age / bucks potions on the farmed pet"
                .. " that still grows (Farm.AutoPotions; never fly / ride potions); opens gifts and chests (Farm.AutoOpen);"
                .. " fuses 4 of your full grown pets of one kind into 1 neon, and 4 full grown neons into 1 mega neon (Farm.AutoNeon)",
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
    function Disclosure.buildStartLine(config, telemetryOn)
        local telemetry = config.Telemetry or {}
        local reports = telemetryOn and ("Bug reports go to the developer (your Roblox name, "
            .. (telemetry.IncludeInventory and "an inventory summary, " or "") .. "this script's logs);"
            .. " off: Telemetry = { Enabled = false }") or "Bug reports: off"
        return string.format("%s v%s • %s • Full report: Config > Settings > What this script does • Stop:"
            .. " getgenv().AdoptMeFarm.Stop()", config.General.ScriptName, Disclosure.VERSION, reports)
    end
    function Disclosure.buildStartLines(config, files, webhookSummary, telemetryText, launchInfo)
        launchInfo = launchInfo or { fromLoader = false, settingsSource = "SETTINGS block in this file" }
        local lines = {
            "===== " .. config.General.ScriptName .. " v" .. Disclosure.VERSION .. " (plain, readable Luau) =====",
            launchInfo.fromLoader and ("STARTED BY: your loader, which downloaded this program from: " .. tostring(launchInfo.loaderUrl))
                or "STARTED BY: running this file directly (the program itself was not downloaded)",
            "SETTINGS FROM: " .. tostring(launchInfo.settingsSource),
            "Window: " .. ((config.Interface and config.Interface.Enabled)
                and ("ON — loads the Starlight UI library from raw.nebulasoftworks.xyz"
                    .. (config.Interface.RememberSettings ~= false and "; remembers your changes in it on this device" or "")
                    .. " (Interface.Enabled = false: no window)")
                or "OFF (Interface.Enabled = false)"),
            "Can do (each ONLY when you switch it on; all off at the first start): pet + baby needs, daily quests, the"
                .. " Halloween event (Ghost Gallery, Crypt, Stray Cat, nest), Pet Pen, age potions, gifts, neon fusion."
                .. " Only for YOUR pet / baby / items.",
            "Features on now: " .. Disclosure.featureSummary(config),
            "Developer logs: " .. tostring(telemetryText),
            "Your webhook: " .. tostring(webhookSummary),
            "Files: " .. table.concat(files, "; "),
            "Every game action it may send: getgenv().AdoptMeFarm.Disclosure()   Stop: getgenv().AdoptMeFarm.Stop()",
        }
        if not config.Farm.Enabled then
            table.insert(lines, 3, "Game actions: NONE (Farm.Enabled = false: the script only watches until you switch"
                .. " 'Farm running' on" .. Disclosure.helperText(config) .. ")")
        end
        return lines
    end
    function Disclosure.featureSummary(config)
        local on, total = Config.countFeatures(config)
        return string.format("%d of %d%s", on, total, config.Preset and (" (preset " .. tostring(config.Preset) .. ")") or "")
    end
    function Disclosure.helperText(config)
        local helpers = {}
        if config.Farm.AntiAfk then
            table.insert(helpers, "the Anti-AFK click")
        end
        if config.Farm.AutoAcceptMenu then
            table.insert(helpers, "the main menu's Play button")
        end
        return #helpers > 0 and ("; still on: " .. table.concat(helpers, " and ")) or ""
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
            add("STARTED BY: running this file directly (the program itself was not downloaded)")
        end
        add("SETTINGS FROM: " .. tostring(launchInfo.settingsSource))
        add("")
        add("READS:")
        for _, item in ipairs(Disclosure.BEHAVIOUR.reads) do
            add("  - " .. item)
        end
        add("HOW IT DECIDES:")
        for _, item in ipairs(Disclosure.BEHAVIOUR.behaviour) do
            add("  - " .. item)
        end
        add("  - features on now: " .. Disclosure.featureSummary(config))
        add("GAME ACTIONS IT SENDS:")
        if not config.Farm.Enabled then
            add("  - NONE (Farm.Enabled = false: the script only watches" .. Disclosure.helperText(config) .. ")")
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
        add("  - Window: " .. ((config.Interface and config.Interface.Enabled)
            and ("loads the Starlight UI library (raw.nebulasoftworks.xyz/starlight), which keeps its own empty folder"
                .. " 'Starlight Interface Suite/AdoptMeFarm'; its Support tab shows the developer's picture (downloaded once from"
                .. " raw.githubusercontent.com when your executor can show it, else Roblox's own avatar picture);"
                .. " Interface.Enabled = false: nothing loaded")
            or "OFF (nothing loaded)"))
        add("  - Developer logs (Telemetry): " .. tostring(telemetryText or "OFF"))
        add("  - " .. webhookSummary)
        add("  - Webhook summaries show the farmed pet's own picture: its address is asked once from Roblox's thumbnail"
            .. " service (thumbnails.roblox.com; only the picture's number is sent there)")
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
    function Disclosure.buildShortText()
        local fields = sortedKeys(Disclosure.WEBHOOK_FIELDS)
        return "This script only sends these fields to this webhook: " .. table.concat(fields, ", ")
            .. " (+ the farmed pet's picture). No other data leaves the device."
    end
    return Disclosure
end
__moduleSources["Services/Notifier"] = function(...)
    local import = ...
    local Enums = import("Core/Enums")
    local Util = import("Core/Util")
    local Disclosure = import("Services/Disclosure")
    local Players = game:GetService("Players")
    local Notifier = {}
    Notifier.__index = Notifier
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
        self._queues = {}
        self._lastAlertAt = -math.huge
        self._suppressedAlerts = 0
        self.SentCount = 0
        self.DroppedCount = 0
        return self
    end
    function Notifier:_offReason()
        local webhooks = self._config.Webhooks
        if not self._config.Enabled then
            return "Notifications.Enabled = false"
        elseif webhooks.Summary == "" and webhooks.Alerts == "" then
            return "no webhook URL set"
        elseif not self._requestFunction then
            return "executor has no HTTP request function"
        end
        return nil
    end
    function Notifier:isEnabled()
        return self:_offReason() == nil
    end
    function Notifier:getStatusText()
        local off = self:_offReason()
        if off then
            return "Discord webhooks: OFF (" .. off .. "). Nothing is sent over the network."
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
        elseif queue.url ~= url then
            queue.url = url
            queue.disabled = false
        end
        return queue
    end
    Notifier.FIELD_EMOJI = { ["Player"] = "👤", ["Session time"] = "⏱️", ["Bucks"] = "💵", ["Bucks earned"] = "💵",
        ["Candy"] = "🍬", ["Candy earned"] = "🍬", ["Needs completed"] = "✅", ["Last task"] = "📋", ["Pet"] = "🐾",
        ["Error"] = "❌", ["Reason"] = "🚪", ["Log counts"] = "🧾", ["Version"] = "🏷️", ["Previous session"] = "🕘" }
    local function shownName(name)
        local emoji = Notifier.FIELD_EMOJI[name]
        return emoji and (emoji .. " " .. name) or name
    end
    local function buildFields(self, fields)
        local result = {}
        if self._config.IncludeUsername then
            local player = Players.LocalPlayer
            table.insert(result, { name = shownName("Player"), value = player and player.Name or "?", inline = true })
        end
        for _, field in ipairs(fields or {}) do
            if Disclosure.isAllowedField(field.name) then
                table.insert(result, {
                    name = shownName(field.name),
                    value = Util.truncate(field.value, FIELD_VALUE_LIMIT),
                    inline = field.inline == true,
                })
            else
                self._logger:warn("Notifier", "Blocked a field that is not in the disclosure list: " .. tostring(field.name))
            end
        end
        table.insert(result, { name = shownName("Version"), value = self._version, inline = true })
        return result
    end
    function Notifier:notify(eventName, fields, description, options)
        local style = EVENT_STYLE[Enums.NotifyEvent[eventName]]
        if not self:isEnabled() then
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
        local shouldPing = self._config.Ping ~= false and pingId ~= "" and style.ping ~= nil and self._config.PingOn[style.ping] == true
        local embed = {
            title = style.title,
            description = description and Util.truncate(description, DESCRIPTION_LIMIT) or nil,
            color = style.color,
            fields = buildFields(self, fields),
            footer = { text = self._scriptName },
        }
        local thumbnail = type(options) == "table" and options.thumbnail
        if type(thumbnail) == "string" and string.match(thumbnail, "^https://tr%.rbxcdn%.com/[%w%-%._/]+$") then
            embed.thumbnail = { url = thumbnail }
        end
        pcall(function()
            embed.timestamp = DateTime.now():ToIsoDate()
        end)
        local payload = {
            username = self._scriptName,
            embeds = { embed },
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
    function Notifier:pump()
        if not self:isEnabled() then
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
__moduleSources["Services/SessionWatcher"] = function(...)
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
                sessionStore:recordMessage(message)
            end
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
__moduleSources["Services/SessionStore"] = function(...)
    local import = ...
    local Util = import("Core/Util")
    local SessionStore = {}
    SessionStore.__index = SessionStore
    SessionStore.FOLDER = "AdoptMeFarm"
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
__moduleSources["Services/Telemetry"] = function(...)
    local import = ...
    local Util = import("Core/Util")
    local Enums = import("Core/Enums")
    local Telemetry = {}
    Telemetry.__index = Telemetry
    local URL_PATTERN = "^https://[%w%-]+%.[%w%-]+%.workers%.dev/[%w%-/]*$"
    local MAX_QUEUE = 150
    local TAIL_LINES = 80
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
        self._startPending = true
        self._request = Util.getRequestFunction()
        local okExecutor, executor = pcall(function()
            return identifyexecutor and table.concat({ identifyexecutor() }, " ") or nil
        end)
        self._executor = okExecutor and executor or nil
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
        return self._off == nil and self._config.Enabled ~= false
    end
    function Telemetry:statusText()
        if self._off then
            return "OFF (" .. self._off .. ")"
        end
        if self._config.Enabled == false then
            return "OFF (turned off in the window)"
        end
        return "ON: every " .. tostring(self._config.SummaryMinutes or 30) .. " min your Roblox name, executor name, a session"
            .. " summary (needs, Bucks, candy, rounds), this script's state (team, place, task, pet, needs, why it waits),"
            .. " task results, its warnings / errors and its last " .. TAIL_LINES .. " log lines"
            .. (self._config.IncludeInventory and " + an inventory summary (Telemetry.IncludeInventory)" or "")
            .. " (and that this run started) go to " .. tostring(self._config.Owner or "the developer")
            .. " via " .. self._config.Url .. " to fix bugs. Turn off: Telemetry = { Enabled = false }"
    end
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
    local COUNTERS = {
        { key = "rounds", pattern = "^Ghost Gallery: %d+ points" },
        { key = "keys", pattern = "Rusty Key EARNED" },
        { key = "quests", pattern = "^Quests: .* claimed" },
        { key = "potions", pattern = "^Age potion:" },
        { key = "gifts", pattern = "^Opened " },
        { key = "houseVisits", pattern = "^Quest %a+: visited" },
    }
    local KEY_ITEMS = { "halloween_2026_rusty_key", "halloween_2026_twig", "pet_age_potion", "tiny_pet_age_potion", "trade_license" }
    local MAX_PET_LINES = 40
    function Telemetry:_inventory()
        local inventory = self._gameData and self._gameData:get("inventory")
        if type(inventory) ~= "table" then
            return nil
        end
        local categories, items, wanted = {}, {}, {}
        for _, id in ipairs(KEY_ITEMS) do
            wanted[id] = true
        end
        for category, list in pairs(inventory) do
            if type(list) == "table" then
                local n = 0
                for _, item in pairs(list) do
                    if type(item) == "table" then
                        n += 1
                        if wanted[item.id] then
                            items[item.id] = (items[item.id] or 0) + 1
                        end
                    end
                end
                categories[tostring(category)] = n
            end
        end
        local groups, petCount, fullGrown, kinds = {}, 0, 0, {}
        for _, pet in pairs(type(inventory.pets) == "table" and inventory.pets or {}) do
            if type(pet) == "table" then
                petCount += 1
                local properties = type(pet.properties) == "table" and pet.properties or {}
                local kind = tostring(pet.kind or pet.id or "?")
                local age = tonumber(properties.age)
                if age and age >= 6 then
                    fullGrown += 1
                end
                local flags = {}
                for key, value in pairs(properties) do
                    if value == true then
                        table.insert(flags, tostring(key))
                    end
                end
                table.sort(flags)
                local label = kind .. (age and (" a" .. age) or "") .. (#flags > 0 and (" [" .. table.concat(flags, ",") .. "]") or "")
                groups[label] = (groups[label] or 0) + 1
                kinds[kind] = true
            end
        end
        local list = {}
        for label, n in pairs(groups) do
            table.insert(list, { label = label, n = n })
        end
        table.sort(list, function(a, b)
            if a.n ~= b.n then
                return a.n > b.n
            end
            return a.label < b.label
        end)
        local pets = {}
        for index, entry in ipairs(list) do
            if index > MAX_PET_LINES then
                table.insert(pets, "... " .. (#list - MAX_PET_LINES) .. " more groups")
                break
            end
            table.insert(pets, entry.label .. " x" .. entry.n)
        end
        local kindCount = 0
        for _ in pairs(kinds) do
            kindCount += 1
        end
        return { categories = categories, items = items, pets = pets, petCount = petCount, fullGrown = fullGrown, petKinds = kindCount }
    end
    function Telemetry:setDiagnostics(provider)
        self._diagnostics = provider
    end
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
        self._tail = {}
        self._tasks = {}
        maid:Give(self._logger.OnEntry:Connect(function(level, category, message)
            if category == "Telemetry" or category == "Disclosure" then
                return
            end
            message = tostring(message)
            if level ~= Enums.LogLevel.DEBUG then
                table.insert(self._tail, string.format("%s [%s] %s: %s", os.date("%H:%M:%S"), level, category, scrub(message)))
                if #self._tail > TAIL_LINES then
                    table.remove(self._tail, 1)
                end
            end
            local plain = string.gsub(message, "^(%u+:) %(side%) ", "%1 ", 1)
            plain = string.gsub(plain, "^(Done:) %(side%) ", "%1 ", 1)
            local doneKind = string.match(plain, "^Done: ([%w_]+)")
            local failedKind = string.match(plain, "^FAILED: ([%w_]+)") or string.match(plain, "^TIMEOUT: ([%w_]+)")
            local kind = doneKind or failedKind
            if kind and category == "Tasks" then
                local entry = self._tasks[kind] or { done = 0, failed = 0 }
                if doneKind then
                    entry.done += 1
                else
                    entry.failed += 1
                end
                self._tasks[kind] = entry
            end
            for _, counter in ipairs(COUNTERS) do
                if string.find(message, counter.pattern) then
                    self._counts[counter.key] = (self._counts[counter.key] or 0) + 1
                end
            end
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
            executor = self._executor,
            tasks = self._tasks,
            state = self._diagnostics and select(2, pcall(self._diagnostics)) or nil,
            inventory = self._config.IncludeInventory and select(2, pcall(self._inventory, self)) or nil,
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
            payload.tail = self._tail
            self._lines = {}
            self._dropped = 0
        end
        return payload
    end
    function Telemetry:pump(force)
        if not self:isEnabled() or self._inFlight then
            return
        end
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
        local payload = self:_payload(reportDue)
        local body, encodeError = Util.jsonEncode(payload)
        if not body and payload.report then
            self._logger:warn("Telemetry", "Report could not be encoded (" .. tostring(encodeError) .. "): sending the short one")
            local summary = payload.summary or {}
            summary.state, summary.inventory, summary.tasks = nil, nil, nil
            payload.lines, payload.tail = { "full report not encodable: " .. Util.truncate(tostring(encodeError), 150) }, nil
            body = Util.jsonEncode(payload)
        end
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
                self._nextSummary = math.min(self._nextSummary, Util.now() + 120)
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
__moduleSources["Services/Lang"] = function(...)
    local Lang = {}
    Lang.LANGUAGES = {
        { code = "en", name = "English", country = "GB" },
        { code = "tr", name = "Türkçe", country = "TR" },
        { code = "es", name = "Español", country = "ES" },
        { code = "pt", name = "Português", country = "BR" },
    }
    Lang.COUNTRY = {
        TR = "tr", CY = "tr",
        ES = "es", MX = "es", AR = "es", CO = "es", CL = "es", PE = "es", VE = "es", EC = "es", GT = "es", CU = "es",
        BO = "es", DO = "es", HN = "es", PY = "es", SV = "es", NI = "es", CR = "es", PA = "es", UY = "es", PR = "es",
        GQ = "es",
        BR = "pt", PT = "pt", AO = "pt", MZ = "pt", CV = "pt", GW = "pt", ST = "pt", TL = "pt",
    }
    Lang.current = "en"
    function Lang.flag(country)
        country = string.upper(tostring(country or ""))
        if not string.match(country, "^%u%u$") then
            return ""
        end
        return utf8.char(0x1F1E6 + string.byte(country, 1) - 65, 0x1F1E6 + string.byte(country, 2) - 65)
    end
    function Lang.info(code)
        for _, language in ipairs(Lang.LANGUAGES) do
            if language.code == code then
                return language
            end
        end
        return nil
    end
    function Lang.pick(setting, country, locale)
        if type(setting) == "string" and setting ~= "Auto" and Lang.info(setting) then
            return setting
        end
        local fromCountry = Lang.COUNTRY[string.upper(tostring(country or ""))]
        if fromCountry then
            return fromCountry
        end
        local fromLocale = string.match(string.lower(tostring(locale or "")), "^(%a%a)")
        if fromLocale and Lang.info(fromLocale) then
            return fromLocale
        end
        return "en"
    end
    function Lang.use(code)
        Lang.current = Lang.info(code) and code or "en"
        return Lang.current
    end
    local S = {}
    Lang.STRINGS = S
    local function add(en, tr, es, pt)
        S[en] = { tr = tr, es = es, pt = pt }
    end
    add("Farm", "Çiftlik", "Granja", "Fazenda")
    add("Setup", "Kurulum", "Ajustes", "Ajustes")
    add("Support", "Destek", "Apoyo", "Apoio")
    add("Main", "Ana sayfa", "Principal", "Principal")
    add("Event", "Etkinlik", "Evento", "Evento")
    add("Webhook", "Webhook", "Webhook", "Webhook")
    add("Config", "Ayarlar", "Config", "Config")
    add("Dashboard", "Panel", "Panel", "Painel")
    add("Farm status", "Çiftlik durumu", "Estado de la granja", "Status da fazenda")
    add("Quick actions", "Hızlı işlemler", "Acciones rápidas", "Ações rápidas")
    add("Auto tasks", "Otomatik görevler", "Tareas automáticas", "Tarefas automáticas")
    add("Pet Pen", "Pet Ağılı", "Corral", "Cercadinho")
    add("Auto needs", "Otomatik ihtiyaçlar", "Necesidades automáticas", "Necessidades automáticas")
    add("Pets", "Petler", "Mascotas", "Pets")
    add("Potions & neon", "İksirler ve neon", "Pociones y neón", "Poções e neon")
    add("Halloween 2026", "Cadılar Bayramı 2026", "Halloween 2026", "Halloween 2026")
    add("Crypt", "Mahzen", "Cripta", "Cripta")
    add("Candy Shop", "Şeker Dükkanı", "Tienda de dulces", "Loja de doces")
    add("Event status", "Etkinlik durumu", "Estado del evento", "Status do evento")
    add("Discord webhook", "Discord webhook", "Webhook de Discord", "Webhook do Discord")
    add("Messages", "Mesajlar", "Mensajes", "Mensagens")
    add("Configs", "Kayıtlı ayarlar", "Configuraciones", "Configurações")
    add("Settings", "Genel", "Opciones", "Opções")
    add("Presets by the developer", "Geliştiricinin hazır ayarları", "Ajustes del desarrollador", "Predefinições do desenvolvedor")
    add("Advanced", "Gelişmiş", "Avanzado", "Avançado")
    add("Developer", "Geliştirici", "Desarrollador", "Desenvolvedor")
    add("Changelog", "Yenilikler", "Novedades", "Novidades")
    add("Executor", "Executor", "Executor", "Executor")
    add("Donate", "Bağış", "Donar", "Doar")
    add("Game passes", "Oyun geçişleri", "Pases de juego", "Passes de jogo")
    add("Crypto (tap to copy)", "Kripto (kopyalamak için dokun)", "Cripto (toca para copiar)", "Cripto (toque para copiar)")
    add("Discord", "Discord", "Discord", "Discord")
    add("Farm running", "Çiftlik çalışıyor", "Granja activa", "Fazenda ligada")
    add("Go home", "Eve git", "Ir a casa", "Ir para casa")
    add("Skip current task", "Şu anki görevi atla", "Saltar tarea actual", "Pular tarefa atual")
    add("Retry resting tasks", "Dinlenen görevleri dene", "Reintentar tareas en pausa", "Tentar tarefas em pausa")
    add("Stop the farm", "Çiftliği durdur", "Detener la granja", "Parar a fazenda")
    add("Claim quests", "Görevleri topla", "Reclamar misiones", "Resgatar missões")
    add("Visit homes for quests", "Görev için ev ziyareti", "Visitar casas (misiones)", "Visitar casas (missões)")
    add("Collect cashback", "Para iadesini topla", "Cobrar reembolso", "Coletar cashback")
    add("Open gifts and chests", "Hediye ve sandık aç", "Abrir regalos y cofres", "Abrir presentes e baús")
    add("Auto Pet Pen", "Otomatik Pet Ağılı", "Corral automático", "Cercadinho automático")
    add("Claim every", "Toplama aralığı", "Reclamar cada", "Coletar a cada")
    add("Keep it full (buys eggs)", "Dolu tut (yumurta alır)", "Mantener lleno (compra huevos)", "Manter cheio (compra ovos)")
    add("Claim Pet Pen now", "Pet Ağılını şimdi topla", "Reclamar corral ahora", "Coletar cercadinho agora")
    add("Baby needs too", "Bebek ihtiyaçları da", "También bebés", "Bebês também")
    add("Skip these needs", "Bu ihtiyaçları atla", "Saltar estas necesidades", "Pular estas necessidades")
    add("Keep growing pet equipped", "Büyüyen pet hep elde", "Mascota en crecimiento equipada", "Manter pet crescendo equipado")
    add("Farm first", "Önce bunları besle", "Primero estas", "Primeiro estes")
    add("Buy an egg if none grows", "Büyüyen yoksa yumurta al", "Comprar huevo si nada crece", "Comprar ovo se nada cresce")
    add("Egg to buy", "Alınacak yumurta", "Huevo a comprar", "Ovo para comprar")
    add("Use potions", "İksir kullan", "Usar pociones", "Usar poções")
    add("Don't use", "Kullanma", "No usar", "Não usar")
    add("Auto neon pets", "Otomatik neon pet", "Mascotas neón automáticas", "Pets neon automáticos")
    add("Auto mega neon pets", "Otomatik mega neon pet", "Mega neón automático", "Mega neon automático")
    add("Ghost Gallery", "Hayalet Galerisi", "Galería de fantasmas", "Galeria dos fantasmas")
    add("Auto Stray Cat", "Otomatik sokak kedisi", "Gato callejero automático", "Gato de rua automático")
    add("Use Rusty Keys", "Paslı anahtarları kullan", "Usar llaves oxidadas", "Usar chaves enferrujadas")
    add("Open", "Aç", "Abrir", "Abrir")
    add("Give twigs to the nest", "Dalları yuvaya götür", "Llevar ramitas al nido", "Levar gravetos ao ninho")
    add("Auto buy", "Otomatik satın al", "Compra automática", "Compra automática")
    add("Buy", "Satın al", "Comprar", "Comprar")
    add("Your event", "Etkinliğin", "Tu evento", "Seu evento")
    add("Webhook URL", "Webhook adresi", "URL del webhook", "URL do webhook")
    add("User ID", "Kullanıcı ID", "ID de usuario", "ID de usuário")
    add("Ping me", "Beni etiketle", "Mencionarme", "Me mencionar")
    add("Ping me on", "Şunlarda etiketle", "Mencionarme en", "Me mencionar em")
    add("Send summary", "Özet gönder", "Enviar resumen", "Enviar resumo")
    add("Summary every", "Özet aralığı", "Resumen cada", "Resumo a cada")
    add("Send test message", "Test mesajı gönder", "Enviar mensaje de prueba", "Enviar mensagem de teste")
    add("Each finished need", "Biten her ihtiyaç", "Cada necesidad hecha", "Cada necessidade feita")
    add("Kick / disconnect", "Atılma / bağlantı kopması", "Expulsión / desconexión", "Expulsão / desconexão")
    add("Errors", "Hatalar", "Errores", "Erros")
    add("Start / stop", "Başlat / durdur", "Inicio / parada", "Início / parada")
    add("Show my Roblox name", "Roblox adımı göster", "Mostrar mi nombre de Roblox", "Mostrar meu nome do Roblox")
    add("Alerts URL", "Uyarı adresi", "URL de alertas", "URL de alertas")
    add("Config name", "Kayıt adı", "Nombre", "Nome")
    add("Saved configs", "Kayıtlı ayarlar", "Configuraciones guardadas", "Configurações salvas")
    add("Save as new config", "Yeni kayıt olarak sakla", "Guardar como nueva", "Salvar como nova")
    add("Overwrite selected", "Seçilenin üzerine yaz", "Sobrescribir seleccionada", "Sobrescrever selecionada")
    add("Load selected", "Seçileni yükle", "Cargar seleccionada", "Carregar selecionada")
    add("Delete selected", "Seçileni sil", "Borrar seleccionada", "Apagar selecionada")
    add("Autosave", "Otomatik kaydet", "Guardado automático", "Salvamento automático")
    add("Autoload selected", "Seçileni açılışta yükle", "Cargar al iniciar", "Carregar ao iniciar")
    add("Anti-AFK", "Anti-AFK", "Anti-AFK", "Anti-AFK")
    add("Auto click Play (menu)", "Menüde Play'e otomatik bas", "Pulsar Play en el menú", "Clicar em Play no menu")
    add("Camera guard", "Kamera koruması", "Protector de cámara", "Proteção da câmera")
    add("Event pop-ups", "Olay bildirimleri", "Avisos de eventos", "Avisos de eventos")
    add("Autoclose GUI on execute", "Açılışta pencereyi gizle", "Ocultar ventana al ejecutar", "Ocultar janela ao executar")
    add("Theme", "Tema", "Tema", "Tema")
    add("UI scale", "Arayüz boyutu", "Tamaño de la interfaz", "Tamanho da interface")
    add("How big the window is drawn (Auto: smaller on phones)", "Pencerenin boyutu (Otomatik: telefonda daha küçük)", "Tamaño de la ventana (Automático: más pequeña en móviles)", "Tamanho da janela (Automático: menor no celular)")
    add("Language", "Dil", "Idioma", "Idioma")
    add("Hide / show key", "Gizle / göster tuşu", "Tecla mostrar / ocultar", "Tecla mostrar / ocultar")
    add("Help lines", "Yardım satırları", "Líneas de ayuda", "Linhas de ajuda")
    add("Reset to loader settings", "Loader ayarlarına dön", "Volver a los ajustes del loader", "Voltar às opções do loader")
    add("What this script does (report)", "Bu script ne yapıyor (rapor)", "Qué hace este script (informe)", "O que este script faz (relatório)")
    add("Closed the window?", "Pencereyi kapattın mı?", "¿Cerraste la ventana?", "Fechou a janela?")
    add("Needs doable here first", "Burada yapılabilenler önce", "Primero lo que se hace aquí", "Primeiro o que dá pra fazer aqui")
    add("Stuck recovery (go home)", "Takılınca kurtar (eve git)", "Recuperar si se atasca (a casa)", "Recuperar se travar (ir pra casa)")
    add("Stuck after", "Takılmış sayılma", "Atascado tras", "Travado após")
    add("Rejoin when stuck", "Takılınca yeniden katıl", "Reunirse si se atasca", "Reentrar se travar")
    add("Rejoin after", "Yeniden katılma", "Reunirse tras", "Reentrar após")
    add("Game travel (doors)", "Oyunun kapılarıyla git", "Viajar por puertas", "Viajar pelas portas")
    add("Go home by respawn", "Eve respawn ile git", "Ir a casa reapareciendo", "Ir pra casa renascendo")
    add("Food bowl trips", "Mama kabı yolculukları", "Viajes al plato", "Idas ao pote de comida")
    add("Camp / beach", "Kamp / plaj", "Campamento / playa", "Acampamento / praia")
    add("Retry failed after", "Başarısızı tekrar deneme", "Reintentar fallidas tras", "Tentar falhas após")
    add("Fails before rest", "Dinlenmeden önce hata", "Fallos antes de pausar", "Falhas antes da pausa")
    add("Rest for", "Dinlenme süresi", "Pausa de", "Pausa de")
    add("Console shows", "Konsolda göster", "La consola muestra", "O console mostra")
    add("Copy Discord invite", "Discord davetini kopyala", "Copiar invitación de Discord", "Copiar convite do Discord")
    add("Copy GitHub link", "GitHub bağlantısını kopyala", "Copiar enlace de GitHub", "Copiar link do GitHub")
    add("Your setup", "Kurulumun", "Tu equipo", "Seu sistema")
    add("Correct network only", "Sadece doğru ağ", "Solo la red correcta", "Somente a rede certa")
    add("Auto", "Otomatik", "Automático", "Automático")
    add("Pet me", "Sev beni", "Acaríciame", "Me acaricie")
    add("Hungry", "Aç", "Hambre", "Fome")
    add("Thirsty", "Susamış", "Sed", "Sede")
    add("Play", "Oyun", "Jugar", "Brincar")
    add("Sleepy", "Uykulu", "Sueño", "Sono")
    add("Dirty", "Kirli", "Sucio", "Sujo")
    add("Toilet", "Tuvalet", "Baño", "Banheiro")
    add("Walk", "Yürüyüş", "Paseo", "Passeio")
    add("Ride", "Gezinti", "Paseo en carrito", "Passeio de carrinho")
    add("Mystery card", "Gizemli kart", "Carta misteriosa", "Carta misteriosa")
    add("Salon", "Kuaför", "Salón", "Salão")
    add("Cat Cafe", "Kedi Kafe", "Café de gatos", "Café dos gatos")
    add("Pizza party", "Pizza partisi", "Fiesta de pizza", "Festa da pizza")
    add("School", "Okul", "Escuela", "Escola")
    add("Sick", "Hasta", "Enfermo", "Doente")
    add("Camping", "Kamp", "Campamento", "Acampamento")
    add("Beach party", "Plaj partisi", "Fiesta en la playa", "Festa na praia")
    add("Bored", "Sıkılmış", "Aburrido", "Entediado")
    add("Age-Up Potion", "Yaş İksiri", "Poción de edad", "Poção de idade")
    add("Tiny Age-Up Potion", "Küçük Yaş İksiri", "Poción de edad pequeña", "Poção de idade pequena")
    add("Bucks Potion", "Bucks İksiri", "Poción de Bucks", "Poção de Bucks")
    add("Next floor (Mummy Spider)", "Sonraki kat (Mumya Örümcek)", "Siguiente piso (Araña momia)", "Próximo andar (Aranha múmia)")
    add("Twig", "Dal", "Ramita", "Graveto")
    add("Big candy pile", "Büyük şeker yığını", "Montón grande de dulces", "Pilha grande de doces")
    add("Small candy pile", "Küçük şeker yığını", "Montón pequeño de dulces", "Pilha pequena de doces")
    add("Cracked Egg (350 Bucks)", "Çatlak Yumurta (350 Bucks)", "Huevo agrietado (350 Bucks)", "Ovo rachado (350 Bucks)")
    add("Pet Egg (600 Bucks)", "Pet Yumurtası (600 Bucks)", "Huevo de mascota (600 Bucks)", "Ovo de pet (600 Bucks)")
    add("Fairytale Egg (event)", "Masal Yumurtası (etkinlik)", "Huevo de cuento (evento)", "Ovo de conto (evento)")
    add("Summaries", "Özetler", "Resúmenes", "Resumos")
    add("Finished needs", "Biten ihtiyaçlar", "Necesidades hechas", "Necessidades feitas")
    add("Stopped", "Durduruldu", "Detenido", "Parado")
    add("Last run ended badly", "Son çalışma kötü bitti", "La última sesión terminó mal", "A última sessão terminou mal")
    add("Neon pets", "Neon petler", "Mascotas neón", "Pets neon")
    add("Oldest pets (closest to grown)", "En yaşlı petler (büyümeye yakın)", "Las más viejas (casi adultas)", "Os mais velhos (quase adultos)")
    add("Teleport", "Işınlan", "Teletransporte", "Teleporte")
    add("Shop door", "Dükkan kapısı", "Puerta de la tienda", "Porta da loja")
    add("Nothing skipped: every need", "Hiçbiri atlanmıyor: her ihtiyaç", "Nada saltado: todas", "Nada pulado: todas")
    add("Any growing pet (youngest first)", "Büyüyen herhangi bir pet (en genç önce)", "Cualquiera que crezca (la más joven primero)", "Qualquer pet crescendo (o mais novo primeiro)")
    add("Using every potion", "Her iksir kullanılıyor", "Usando todas las pociones", "Usando todas as poções")
    add("Pick what to buy", "Alınacakları seç", "Elige qué comprar", "Escolha o que comprar")
    add("No pings", "Etiket yok", "Sin menciones", "Sem menções")
    add("Pick a saved config", "Kayıtlı bir ayar seç", "Elige una configuración", "Escolha uma configuração")
    add("e.g. main farm", "ör. ana çiftlik", "ej. granja principal", "ex. fazenda principal")
    add("digits, e.g. 123456789012345678", "rakamlar, ör. 123456789012345678", "dígitos, ej. 123456789012345678", "dígitos, ex. 123456789012345678")
    add("errors / kicks go here; empty = the main one", "hatalar / atılmalar buraya; boş = ana adres", "errores / expulsiones aquí; vacío = el principal", "erros / expulsões aqui; vazio = o principal")
    add("Stops the running task and goes home (respawn first).", "Çalışan görevi durdurur ve eve gider (önce respawn).", "Detiene la tarea y va a casa (reaparece primero).", "Para a tarefa e vai pra casa (renasce primeiro).")
    add("Stops the running task; it is not chosen again for 90 s.", "Çalışan görevi durdurur; 90 sn tekrar seçilmez.", "Detiene la tarea; no se elige otra vez en 90 s.", "Para a tarefa; não é escolhida de novo por 90 s.")
    add("Tasks that failed 3 times in a row may run again now.", "Üst üste 3 kez başarısız olan görevler şimdi tekrar çalışabilir.", "Las tareas que fallaron 3 veces seguidas pueden volver a correr.", "Tarefas que falharam 3 vezes seguidas podem rodar de novo.")
    add("Everything stops and cleans up (run the loader again to start).", "Her şey durur ve temizlenir (başlatmak için loader'ı tekrar çalıştır).", "Todo se detiene y se limpia (ejecuta el loader para empezar).", "Tudo para e é limpo (rode o loader de novo para começar).")
    add("Claims the pen (at home), takes full grown pets out, fills it with pets that still grow", "Ağılı toplar (evde), büyümüş petleri çıkarır, büyüyenlerle doldurur", "Reclama el corral (en casa), saca las adultas y lo llena con las que crecen", "Coleta o cercadinho (em casa), tira os adultos e enche com pets crescendo")
    add("Buys eggs (Bucks) so the pen always has pets that grow; needs 'Buy an egg'", "Ağılda hep büyüyen pet olsun diye yumurta alır (Bucks); 'Yumurta al' açık olmalı", "Compra huevos (Bucks) para que el corral tenga mascotas que crecen; necesita 'Comprar huevo'", "Compra ovos (Bucks) para o cercadinho ter pets crescendo; precisa de 'Comprar ovo'")
    add("Goes home if needed and claims / refills the Pet Pen once.", "Gerekirse eve gider ve Pet Ağılını bir kez toplar / doldurur.", "Va a casa si hace falta y reclama / rellena el corral una vez.", "Vai pra casa se preciso e coleta / enche o cercadinho uma vez.")
    add("Does every pet need; pick below the ones to skip. Buys 1 food / water only when it has none.", "Her pet ihtiyacını yapar; atlanacakları aşağıdan seç. Yiyecek / su yoksa sadece 1 tane alır.", "Hace cada necesidad; elige abajo las que saltar. Compra 1 comida / agua solo si no tiene.", "Faz cada necessidade; escolha abaixo as que pular. Compra 1 comida / água só quando não tem.")
    add("Needs picked here are NOT done", "Burada seçilen ihtiyaçlar YAPILMAZ", "Las elegidas aquí NO se hacen", "As escolhidas aqui NÃO são feitas")
    add("Keeps a pet that still grows equipped; a full grown one is swapped", "Büyüyen bir peti elde tutar; büyümüş olan değiştirilir", "Mantiene equipada una mascota que crece; una adulta se cambia", "Mantém um pet crescendo equipado; um adulto é trocado")
    add("These pets get the needs, potions and Pet Pen first", "Bu petler ihtiyaç, iksir ve Pet Ağılında önceliklidir", "Estas mascotas reciben primero necesidades, pociones y corral", "Estes pets recebem primeiro necessidades, poções e cercadinho")
    add("Uses every potion that helps farming on the growing pet; pick below the ones to keep", "Farma yardım eden her iksiri büyüyen pette kullanır; saklanacakları aşağıdan seç", "Usa cada poción útil en la mascota que crece; elige abajo las que guardar", "Usa toda poção útil no pet crescendo; escolha abaixo as que guardar")
    add("Potions picked here are kept (never used)", "Burada seçilen iksirler saklanır (kullanılmaz)", "Las elegidas aquí se guardan (nunca se usan)", "As escolhidas aqui são guardadas (nunca usadas)")
    add("4 full grown pets of one kind -> 1 neon", "Aynı türden 4 büyümüş pet -> 1 neon", "4 adultas del mismo tipo -> 1 neón", "4 adultos do mesmo tipo -> 1 neon")
    add("4 full grown neons of one kind -> 1 mega neon", "Aynı türden 4 büyümüş neon -> 1 mega neon", "4 neones adultos del mismo tipo -> 1 mega neón", "4 neons adultos do mesmo tipo -> 1 mega neon")
    add("Joins every round and vacuums the ghosts (Rusty Keys)", "Her tura katılır ve hayaletleri süpürür (Paslı Anahtar)", "Entra a cada ronda y aspira fantasmas (llaves oxidadas)", "Entra em cada rodada e aspira fantasmas (chaves enferrujadas)")
    add("Opens Crypt graves with your Rusty Keys; pick below what to open", "Paslı anahtarlarla mahzen mezarlarını açar; ne açılacağını aşağıdan seç", "Abre tumbas de la cripta con tus llaves; elige abajo qué abrir", "Abre túmulos da cripta com suas chaves; escolha abaixo o que abrir")
    add("What a Rusty Key opens, in this order", "Paslı anahtarın açacakları, bu sırayla", "Lo que abre una llave, en este orden", "O que uma chave abre, nesta ordem")
    add("Has a Crypt Twig: takes it to the Hotel nest", "Mahzen dalı varsa Otel'deki yuvaya götürür", "Si tiene una ramita, la lleva al nido del hotel", "Se tiver um graveto, leva ao ninho do hotel")
    add("Buys the pets picked below with candy, as many as the candy pays for", "Aşağıda seçilen petleri şekerle, şekerin yettiği kadar alır", "Compra con dulces las mascotas elegidas, tantas como alcance", "Compra com doces os pets escolhidos, quantos der")
    add("No limit: bought whenever the candy is enough", "Sınır yok: şeker yettikçe alınır", "Sin límite: se compra cuando alcanza", "Sem limite: compra quando der")
    add("Sends one test message to your webhook.", "Webhook'una bir test mesajı gönderir.", "Envía un mensaje de prueba a tu webhook.", "Envia uma mensagem de teste para o seu webhook.")
    add("@mentions you on the messages picked below", "Aşağıda seçilen mesajlarda seni etiketler", "Te menciona en los mensajes elegidos abajo", "Menciona você nas mensagens escolhidas abaixo")
    add("Which messages @mention you", "Hangi mesajlar seni etiketlesin", "Qué mensajes te mencionan", "Quais mensagens mencionam você")
    add("A summary message (needs done, Bucks, pet) every few minutes", "Birkaç dakikada bir özet mesajı (ihtiyaçlar, Bucks, pet)", "Un resumen (necesidades, Bucks, mascota) cada pocos minutos", "Um resumo (necessidades, Bucks, pet) a cada poucos minutos")
    add("Saves every setting of the window under the name above.", "Penceredeki tüm ayarları yukarıdaki adla saklar.", "Guarda todos los ajustes con el nombre de arriba.", "Salva todas as opções com o nome acima.")
    add("Saves the current settings into the picked config.", "Şu anki ayarları seçilen kayda yazar.", "Guarda los ajustes actuales en la elegida.", "Salva as opções atuais na escolhida.")
    add("Puts the picked config's settings in place now.", "Seçilen kaydın ayarlarını şimdi uygular.", "Aplica ahora los ajustes elegidos.", "Aplica agora as opções escolhidas.")
    add("Deletes the picked config file.", "Seçilen kayıt dosyasını siler.", "Borra el archivo elegido.", "Apaga o arquivo escolhido.")
    add("On: every change in the window is kept on this device. Off: changes last until you leave; save a config instead", "Açık: penceredeki her değişiklik bu cihazda saklanır. Kapalı: oyundan çıkana kadar sürer; bunun yerine kayıt al", "Sí: cada cambio se guarda en este dispositivo. No: dura hasta salir; guarda una configuración", "Ligado: cada mudança fica salva neste aparelho. Desligado: dura até sair; salve uma configuração")
    add("At every start, the config picked above is put in place", "Her açılışta yukarıda seçilen kayıt uygulanır", "En cada inicio se aplica la configuración elegida", "A cada início a configuração escolhida é aplicada")
    add("Clicks on Roblox's idle warning (no idle kick)", "Roblox'un boşta uyarısına tıklar (atılmazsın)", "Pulsa el aviso de inactividad (sin expulsión)", "Clica no aviso de inatividade (sem expulsão)")
    add("The camera went inside your character: it is zoomed back out", "Kamera karakterinin içine girerse geri uzaklaştırılır", "Si la cámara entra en tu personaje, se aleja", "Se a câmera entrar no personagem, ela se afasta")
    add("Pop-ups for keys, neon, purchases, rounds", "Anahtar, neon, alışveriş ve tur bildirimleri", "Avisos de llaves, neón, compras, rondas", "Avisos de chaves, neon, compras, rodadas")
    add("Every change made in the window goes back to the loader's value, now and at the next start.", "Pencerede yapılan her değişiklik loader değerine döner, şimdi ve sonraki açılışta.", "Cada cambio vuelve al valor del loader, ahora y al próximo inicio.", "Cada mudança volta ao valor do loader, agora e no próximo início.")
    add("Back to the loader's settings.", "Loader ayarlarına dönüldü.", "Ajustes del loader de nuevo.", "Opções do loader de novo.")
    add("Drag, or tap the number to type a value.", "Sürükle ya da sayıya dokunup yaz.", "Arrastra o toca el número para escribirlo.", "Arraste ou toque no número para digitar.")
    add("Copies the Discord invite", "Discord davetini kopyalar", "Copia la invitación de Discord", "Copia o convite do Discord")
    add("Which language the window uses (Auto: your country's)", "Pencerenin dili (Otomatik: ülkenin dili)", "Idioma de la ventana (Automático: el de tu país)", "Idioma da janela (Automático: o do seu país)")
    add("Master switch. Off = no game actions at all", "Ana şalter. Kapalı = hiçbir oyun işlemi yok", "Interruptor principal. No = ninguna acción", "Chave geral. Desligado = nenhuma ação")
    add("Joins the Babies team to do baby needs too", "Bebek ihtiyaçları için Bebek takımına geçer", "Se une al equipo Bebés para sus necesidades", "Entra no time Bebês para as necessidades deles")
    add("While waiting at a place: food, drink, toy, petting", "Bir yerde beklerken: yemek, içecek, oyuncak, sevme", "Mientras espera: comida, bebida, juguete, caricias", "Enquanto espera: comida, bebida, brinquedo, carinho")
    add("No drink left: buys 1 water (1 Buck)", "İçecek kalmazsa 1 su alır (1 Buck)", "Sin bebida: compra 1 agua (1 Buck)", "Sem bebida: compra 1 água (1 Buck)")
    add("No food left: buys 1 sandwich / hotdog", "Yiyecek kalmazsa 1 sandviç / sosisli alır", "Sin comida: compra 1 sándwich / perrito", "Sem comida: compra 1 sanduíche / cachorro-quente")
    add("No pet out: equips a pet that still grows", "Pet yoksa büyüyen bir pet çıkarır", "Sin mascota: equipa una que crece", "Sem pet: equipa um que ainda cresce")
    add("Swaps a full grown pet for a growing one", "Büyümüş peti büyüyen biriyle değiştirir", "Cambia una adulta por una que crece", "Troca um adulto por um que cresce")
    add("Growing neon pets are farmed first", "Büyüyen neon petler önce beslenir", "Primero las neón que crecen", "Primeiro os neons crescendo")
    add("Age potions on the farmed growing pet", "Beslenen pete yaş iksiri", "Pociones de edad en la mascota", "Poções de idade no pet")
    add("4 full grown of one kind -> 1 neon", "Aynı türden 4 büyümüş -> 1 neon", "4 adultas del mismo tipo -> 1 neón", "4 adultos do mesmo tipo -> 1 neon")
    add("No growing pet left: buys 1 egg (Bucks only)", "Büyüyen pet kalmazsa 1 yumurta alır (sadece Bucks)", "Sin mascota que crezca: compra 1 huevo (solo Bucks)", "Sem pet crescendo: compra 1 ovo (só Bucks)")
    add("Opens gifts and chests in your backpack", "Çantandaki hediye ve sandıkları açar", "Abre regalos y cofres de tu mochila", "Abre presentes e baús da mochila")
    add("Master switch for every Halloween job", "Tüm Cadılar Bayramı işleri için ana şalter", "Interruptor de todo Halloween", "Chave geral do Halloween")
    add("Joins each round, vacuums ghosts (Rusty Keys)", "Her tura katılır, hayaletleri süpürür (Paslı Anahtar)", "Entra a cada ronda, aspira fantasmas", "Entra em cada rodada, aspira fantasmas")
    add("Joins by standing in the Manor circle", "Malikanedeki çembere girerek katılır", "Entra parándose en el círculo de la mansión", "Entra ficando no círculo da mansão")
    add("Uses Rusty Keys on the grave going down", "Aşağı inerken mezarda Paslı Anahtar kullanır", "Usa llaves en la tumba al bajar", "Usa chaves no túmulo ao descer")
    add("Bottom of the Crypt: takes the spider", "Mahzenin dibinde örümceği alır", "Fondo de la cripta: toma la araña", "Fundo da cripta: pega a aranha")
    add("Claims finished daily + board quests", "Biten günlük ve pano görevlerini toplar", "Reclama misiones diarias y del tablero", "Resgata missões diárias e do quadro")
    add("Visit-homes quests: visits houses here", "Ev ziyareti görevleri: buradaki evleri gezer", "Misiones de visitas: visita casas aquí", "Missões de visita: visita casas aqui")
    add("Puts Crypt Twigs into the Hotel nest", "Mahzen dallarını Otel'deki yuvaya koyar", "Pone ramitas en el nido del hotel", "Põe gravetos no ninho do hotel")
    add("Twig graves first until the nest is built", "Yuva bitene kadar önce dallı mezarlar", "Primero tumbas con ramitas hasta el nido", "Primeiro túmulos com gravetos até o ninho")
    add("1 water to the Stray Cat a day (+candy)", "Sokak kedisine günde 1 su (+şeker)", "1 agua al gato callejero al día (+dulces)", "1 água ao gato de rua por dia (+doces)")
    add("Claims the pen, keeps it full (at home)", "Ağılı toplar, dolu tutar (evde)", "Reclama el corral y lo llena (en casa)", "Coleta o cercadinho e mantém cheio (em casa)")
    add("Buys eggs so the pen stays full", "Ağıl dolu kalsın diye yumurta alır", "Compra huevos para llenar el corral", "Compra ovos para manter o cercadinho cheio")
    add("How often the pen is claimed", "Ağılın ne sıklıkla toplandığı", "Cada cuánto se reclama el corral", "De quanto em quanto tempo coletar")
    add("Saves candy for the pets in your list", "Listendeki petler için şeker biriktirir", "Ahorra dulces para tu lista", "Guarda doces para a sua lista")
    add("Clicks on Roblox's idle warning (also paused)", "Roblox'un boşta uyarısına tıklar (durakken de)", "Pulsa el aviso de inactividad (también en pausa)", "Clica no aviso de inatividade (também pausado)")
    add("Clicks Play on the main menu (also paused)", "Ana menüde Play'e basar (durakken de)", "Pulsa Play en el menú (también en pausa)", "Clica em Play no menu (também pausado)")
    add("Collects cashback Bucks (while running)", "Para iadesi Bucks'ları toplar (çalışırken)", "Cobra el reembolso de Bucks (activa)", "Coleta o cashback de Bucks (ligada)")
    add("No place / character: rejoins a PUBLIC server", "Yer / karakter yoksa HERKESE AÇIK sunucuya girer", "Sin lugar / personaje: entra a un servidor PÚBLICO", "Sem lugar / personagem: entra num servidor PÚBLICO")
    add("How long before that rejoin", "Yeniden katılmadan önceki süre", "Cuánto antes de reunirse", "Quanto antes de reentrar")
    add("Travels with the game's own doors", "Oyunun kendi kapılarıyla gider", "Viaja por las puertas del juego", "Viaja pelas portas do jogo")
    add("Goes home by respawn (fastest)", "Eve respawn ile gider (en hızlı)", "Va a casa reapareciendo (más rápido)", "Vai pra casa renascendo (mais rápido)")
    add("Route to camping / beach / playground", "Kamp / plaj / oyun parkı yolu", "Ruta al campamento / playa / parque", "Rota para acampamento / praia / parquinho")
    add("Goes home for the free bowl even with food", "Yiyecek olsa da bedava mama kabı için eve gider", "Va a casa por el plato gratis aunque tenga comida", "Vai pra casa pelo pote grátis mesmo com comida")
    add("Which growing pet first: youngest / oldest", "Önce hangi pet: en genç / en yaşlı", "Cuál primero: la más joven / vieja", "Qual primeiro: o mais novo / velho")
    add("Egg bought with Bucks (never Robux)", "Bucks ile alınan yumurta (asla Robux)", "Huevo con Bucks (nunca Robux)", "Ovo com Bucks (nunca Robux)")
    add("Pet kinds farmed first, comma separated", "Önce beslenen türler, virgülle", "Tipos primero, separados por comas", "Tipos primeiro, separados por vírgula")
    add("Potions only on these kinds (empty = any)", "İksir sadece bu türlere (boş = hepsi)", "Pociones solo en estos tipos (vacío = todos)", "Poções só nestes tipos (vazio = todos)")
    add("Needs doable right here go first", "Burada yapılabilen ihtiyaçlar önce", "Primero lo que se hace aquí", "Primeiro o que dá pra fazer aqui")
    add("Not moving, tasks failing: respawn home", "Hareket yok, görevler başarısız: eve respawn", "Sin moverse y fallando: reaparece en casa", "Parado e falhando: renasce em casa")
    add("How long before it counts as stuck", "Takılmış sayılmadan önceki süre", "Cuánto antes de contar como atascado", "Quanto antes de contar como travado")
    add("3 fails in a row: rest (0 = whole session)", "Üst üste 3 hata: dinlen (0 = tüm oturum)", "3 fallos seguidos: pausa (0 = toda la sesión)", "3 falhas seguidas: pausa (0 = sessão toda)")
    add("Max food / water buys (0 = no limit)", "En fazla yiyecek / su alımı (0 = sınırsız)", "Máx. compras de comida / agua (0 = sin límite)", "Máx. compras de comida / água (0 = sem limite)")
    add("Max egg buys (0 = no limit)", "En fazla yumurta alımı (0 = sınırsız)", "Máx. huevos (0 = sin límite)", "Máx. ovos (0 = sem limite)")
    add("Window colours", "Pencere renkleri", "Colores de la ventana", "Cores da janela")
    add("These lines (the window opens again)", "Bu satırlar (pencere yeniden açılır)", "Estas líneas (la ventana se reabre)", "Estas linhas (a janela reabre)")
    add("Starts closed: the key / paw button opens it", "Kapalı başlar: tuş / pati düğmesi açar", "Empieza cerrada: la tecla / botón de pata la abre", "Começa fechada: a tecla / botão de pata abre")
    add("Bug reports to the developer (off: at once)", "Geliştiriciye hata raporu (kapatınca hemen durur)", "Informes de errores al desarrollador", "Relatórios de erro ao desenvolvedor")
    add("How often cashback is collected", "Para iadesinin toplanma sıklığı", "Cada cuánto se cobra el reembolso", "De quanto em quanto coletar o cashback")
    add("4 free slots; 5 with the extra-slot pass", "4 bedava yer; ek yer geçişiyle 5", "4 espacios gratis; 5 con el pase", "4 vagas grátis; 5 com o passe")
    add("Buys pen eggs only above these Bucks", "Ağıl yumurtasını sadece bu Bucks üstünde alır", "Compra huevos solo con más Bucks que esto", "Compra ovos só acima destes Bucks")
    add("Which quick needs run beside a place need", "Bir yer ihtiyacının yanında hangi hızlı ihtiyaçlar", "Qué necesidades rápidas van junto a otra", "Quais necessidades rápidas junto de outra")
    add("Pause between two quick needs", "İki hızlı ihtiyaç arası bekleme", "Pausa entre dos necesidades rápidas", "Pausa entre duas necessidades rápidas")
    add("Pet kinds that are never fused", "Asla birleştirilmeyen türler", "Tipos que nunca se fusionan", "Tipos que nunca são fundidos")
    add("Gifts / chests that are never opened", "Asla açılmayan hediye / sandıklar", "Regalos / cofres que nunca se abren", "Presentes / baús que nunca são abertos")
    add("Which age potions may be used", "Hangi yaş iksirleri kullanılabilir", "Qué pociones de edad se usan", "Quais poções de idade usar")
    add("Wait after a failed task before a retry", "Başarısız görevden sonra tekrar deneme beklemesi", "Espera tras un fallo antes de reintentar", "Espera após falha antes de tentar")
    add("Fails in a row before a task rests", "Görev dinlenmeden önce üst üste hata", "Fallos seguidos antes de pausar", "Falhas seguidas antes da pausa")
    add("Experimental: leave home by its door", "Deneysel: evden kapıdan çık", "Experimental: salir por la puerta", "Experimental: sair pela porta")
    add("Candy kept back, whatever the list wants", "Liste ne isterse istesin ayrılan şeker", "Dulces que se guardan siempre", "Doces guardados sempre")
    add("How much the console shows (OFF = quiet)", "Konsolun ne kadar gösterdiği (OFF = sessiz)", "Cuánto muestra la consola (OFF = silencio)", "Quanto o console mostra (OFF = silêncio)")
    add("Reports also list item / pet counts", "Raporlar eşya / pet sayılarını da gösterir", "Los informes listan objetos / mascotas", "Relatórios listam itens / pets")
    add("Key that hides / shows this window", "Bu pencereyi gizleyen / gösteren tuş", "Tecla que muestra / oculta la ventana", "Tecla que mostra / oculta a janela")
    add("Message when the farm starts / stops", "Çiftlik başlayınca / durunca mesaj", "Mensaje al iniciar / detener", "Mensagem ao iniciar / parar")
    add("One message per finished need (many)", "Biten her ihtiyaç için mesaj (çok)", "Un mensaje por necesidad (muchos)", "Uma mensagem por necessidade (muitas)")
    add("Message on this script's errors", "Script hatalarında mesaj", "Mensaje en errores del script", "Mensagem nos erros do script")
    add("Message on a kick / disconnect", "Atılma / kopmada mesaj", "Mensaje al ser expulsado / desconectado", "Mensagem ao ser expulso / desconectado")
    add("Your Roblox name in the messages", "Mesajlarda Roblox adın", "Tu nombre de Roblox en los mensajes", "Seu nome do Roblox nas mensagens")
    add("@mention you for these messages", "Bu mesajlarda seni etiketler", "Te menciona en estos mensajes", "Menciona você nestas mensagens")
    add("Pets your pet until the need is done", "İhtiyaç bitene kadar peti sever", "Acaricia a tu mascota hasta terminar", "Acaricia o pet até terminar")
    add("Bowl at home, else your food; buys if on", "Evdeki mama kabı, yoksa yiyeceğin; açıksa alır", "Plato en casa, si no tu comida; compra si está activo", "Pote em casa, senão sua comida; compra se ligado")
    add("Your water / milk; buys 1 water if on", "Suyun / sütün; açıksa 1 su alır", "Tu agua / leche; compra 1 agua si está activo", "Sua água / leite; compra 1 água se ligado")
    add("Throws your squeaky bone", "Ötücü kemiğini atar", "Lanza tu hueso con sonido", "Joga seu osso de apertar")
    add("Your bed at home (goes home)", "Evdeki yatağın (eve gider)", "Tu cama en casa (va a casa)", "Sua cama em casa (vai pra casa)")
    add("Your shower at home (goes home)", "Evdeki duşun (eve gider)", "Tu ducha en casa (va a casa)", "Seu chuveiro em casa (vai pra casa)")
    add("Your toilet at home (goes home)", "Evdeki tuvaletin (eve gider)", "Tu baño en casa (va a casa)", "Seu vaso em casa (vai pra casa)")
    add("Walks your character until done", "Bitene kadar karakterini yürütür", "Camina hasta terminar", "Anda até terminar")
    add("Walks with your stroller until done", "Bitene kadar bebek arabasıyla yürür", "Pasea con el carrito hasta terminar", "Passeia com o carrinho até terminar")
    add("Picks a card this script can do", "Scriptin yapabildiği bir kart seçer", "Elige una carta que el script puede hacer", "Escolhe uma carta que o script consegue")
    add("Goes to the Salon and waits", "Kuaföre gidip bekler", "Va al salón y espera", "Vai ao salão e espera")
    add("Goes to the Cat Cafe and waits", "Kedi Kafe'ye gidip bekler", "Va al café de gatos y espera", "Vai ao café dos gatos e espera")
    add("Goes to the Pizza Shop and waits", "Pizzacıya gidip bekler", "Va a la pizzería y espera", "Vai à pizzaria e espera")
    add("Goes to School and waits", "Okula gidip bekler", "Va a la escuela y espera", "Vai à escola e espera")
    add("Hospital: talks to the doctor", "Hastane: doktorla konuşur", "Hospital: habla con el doctor", "Hospital: fala com o médico")
    add("Camp site spot on the map", "Haritadaki kamp yeri", "Zona de campamento del mapa", "Ponto de acampamento no mapa")
    add("Beach spot on the map", "Haritadaki plaj yeri", "Zona de playa del mapa", "Ponto da praia no mapa")
    add("Playground spot on the map", "Haritadaki oyun parkı", "Parque del mapa", "Parquinho no mapa")
    add("Stop the farm?", "Çiftlik durdurulsun mu?", "¿Detener la granja?", "Parar a fazenda?")
    add("Everything stops and cleans up. Run the loader again to start.", "Her şey durur ve temizlenir. Başlatmak için loader'ı tekrar çalıştır.", "Todo se detiene. Ejecuta el loader para empezar.", "Tudo para. Rode o loader de novo para começar.")
    add("Stop", "Durdur", "Detener", "Parar")
    add("Cancel", "Vazgeç", "Cancelar", "Cancelar")
    add("Apply", "Uygula", "Aplicar", "Aplicar")
    add("Apply + start", "Uygula + başlat", "Aplicar + iniciar", "Aplicar + iniciar")
    add("Reset", "Sıfırla", "Restablecer", "Redefinir")
    add("Delete", "Sil", "Borrar", "Apagar")
    add("Stopped.", "Durduruldu.", "Detenido.", "Parado.")
    add("Done", "Tamam", "Hecho", "Feito")
    add("Not possible now", "Şu an olmuyor", "No es posible ahora", "Não dá agora")
    add("Not valid", "Geçersiz", "No válido", "Inválido")
    add("Not available in this version", "Bu sürümde yok", "No disponible en esta versión", "Indisponível nesta versão")
    add("Window", "Pencere", "Ventana", "Janela")
    add("Building the window again...", "Pencere yeniden kuruluyor...", "Rehaciendo la ventana...", "Refazendo a janela...")
    add("Applies when the window opens again.", "Pencere yeniden açılınca geçerli olur.", "Se aplica al reabrir la ventana.", "Vale ao reabrir a janela.")
    add("Type a name first", "Önce bir ad yaz", "Escribe un nombre primero", "Digite um nome primeiro")
    add("Pick a saved config first", "Önce kayıtlı bir ayar seç", "Elige una configuración primero", "Escolha uma configuração primeiro")
    add("The config file is deleted from this device.", "Kayıt dosyası bu cihazdan silinir.", "El archivo se borra de este dispositivo.", "O arquivo é apagado deste aparelho.")
    add("Autoload", "Açılışta yükle", "Carga al iniciar", "Carregar ao iniciar")
    add("Autoload: off", "Açılışta yükleme: kapalı", "Carga al iniciar: no", "Carregar ao iniciar: não")
    add("Autosave off: save a config instead", "Otomatik kayıt kapalı: bunun yerine kayıt al", "Guardado automático no: guarda una configuración", "Salvamento automático desligado: salve uma configuração")
    add("Autosave: on (this device)", "Otomatik kayıt: açık (bu cihaz)", "Guardado automático: sí (este dispositivo)", "Salvamento automático: ligado (este aparelho)")
    add("Reset to loader settings?", "Loader ayarlarına dönülsün mü?", "¿Volver a los ajustes del loader?", "Voltar às opções do loader?")
    add("Transparency report", "Şeffaflık raporu", "Informe de transparencia", "Relatório de transparência")
    add("Printed to the console (F9 / executor console).", "Konsola yazıldı (F9 / executor konsolu).", "Escrito en la consola (F9 / consola del executor).", "Escrito no console (F9 / console do executor).")
    add("Hide / show: tap the round paw button", "Gizle / göster: yuvarlak pati düğmesine dokun", "Mostrar / ocultar: toca el botón de pata", "Mostrar / ocultar: toque no botão de pata")
    add("the round paw button", "yuvarlak pati düğmesi", "el botón redondo de pata", "o botão redondo de pata")
    add("the hide / show key", "gizle / göster tuşu", "la tecla mostrar / ocultar", "a tecla mostrar / ocultar")
    add("Run: getgenv().AdoptMeFarm.OpenInterface()", "Çalıştır: getgenv().AdoptMeFarm.OpenInterface()", "Ejecuta: getgenv().AdoptMeFarm.OpenInterface()", "Rode: getgenv().AdoptMeFarm.OpenInterface()")
    add("The farm is running.", "Çiftlik çalışıyor.", "La granja está activa.", "A fazenda está ligada.")
    add("Switch 'Farm running' on to start.", "Başlatmak için 'Çiftlik çalışıyor'u aç.", "Activa 'Granja activa' para empezar.", "Ligue 'Fazenda ligada' para começar.")
    add("Webhook", "Webhook", "Webhook", "Webhook")
    add("Webhook removed.", "Webhook kaldırıldı.", "Webhook eliminado.", "Webhook removido.")
    add("Saved on this device. Press 'Send test message'.", "Bu cihaza kaydedildi. 'Test mesajı gönder'e bas.", "Guardado aquí. Pulsa 'Enviar mensaje de prueba'.", "Salvo aqui. Toque em 'Enviar mensagem de teste'.")
    add("That is not a Discord webhook URL (Channel settings > Integrations > Webhooks)", "Bu bir Discord webhook adresi değil (Kanal ayarları > Entegrasyonlar > Webhooklar)", "No es una URL de webhook de Discord (Canal > Integraciones > Webhooks)", "Não é uma URL de webhook do Discord (Canal > Integrações > Webhooks)")
    add("That is not a Discord webhook URL", "Bu bir Discord webhook adresi değil", "No es una URL de webhook de Discord", "Não é uma URL de webhook do Discord")
    add("Digits only (Discord: Settings > Advanced > Developer Mode, then right click yourself > Copy ID)", "Sadece rakam (Discord: Ayarlar > Gelişmiş > Geliştirici Modu, sonra kendine sağ tık > ID'yi kopyala)", "Solo dígitos (Discord: Ajustes > Avanzado > Modo desarrollador, luego clic derecho en ti > Copiar ID)", "Só dígitos (Discord: Configurações > Avançado > Modo desenvolvedor, depois clique direito em você > Copiar ID)")
    add("Webhook: checking...", "Webhook: kontrol ediliyor...", "Webhook: comprobando...", "Webhook: verificando...")
    add("Webhook: ON", "Webhook: AÇIK", "Webhook: SÍ", "Webhook: LIGADO")
    add("Webhook: OFF (no URL yet)", "Webhook: KAPALI (adres yok)", "Webhook: NO (sin URL)", "Webhook: DESLIGADO (sem URL)")
    add("Waiting for your data...", "Verilerin bekleniyor...", "Esperando tus datos...", "Esperando seus dados...")
    add("Join script", "Katılma scripti", "Script para unirse", "Script para entrar")
    add("Copied: run it in your executor to join this server", "Kopyalandı: bu sunucuya girmek için executor'da çalıştır", "Copiado: ejecútalo para unirte a este servidor", "Copiado: rode no executor para entrar neste servidor")
    add("Could not copy", "Kopyalanamadı", "No se pudo copiar", "Não deu para copiar")
    add("Rusty Key earned", "Paslı Anahtar kazanıldı", "Llave oxidada ganada", "Chave enferrujada ganha")
    add("Mummy Spider claimed", "Mumya Örümcek alındı", "Araña momia obtenida", "Aranha múmia pega")
    add("Neon fusion", "Neon birleştirme", "Fusión neón", "Fusão neon")
    add("Mega neon!", "Mega neon!", "¡Mega neón!", "Mega neon!")
    add("Candy shop", "Şeker dükkanı", "Tienda de dulces", "Loja de doces")
    add("Quest reward", "Görev ödülü", "Premio de misión", "Prêmio de missão")
    add("Pigeon nest built", "Güvercin yuvası bitti", "Nido de paloma hecho", "Ninho de pombo pronto")
    add("Ghost Gallery round", "Hayalet Galerisi turu", "Ronda de la galería", "Rodada da galeria")
    add("Task resting", "Görev dinleniyor", "Tarea en pausa", "Tarefa em pausa")
    add("Stuck: going home", "Takıldı: eve gidiyor", "Atascado: a casa", "Travado: indo pra casa")
    add("Made Adopt Victims: plain, readable Luau.", "Adopt Victims'ı yaptı: sade, okunabilir Luau.", "Creó Adopt Victims: Luau simple y legible.", "Criou o Adopt Victims: Luau simples e legível.")
    add("Thank you for using it!", "Kullandığın için teşekkürler!", "¡Gracias por usarlo!", "Obrigado por usar!")
    add("Send each coin only on the network written next to it. Tokens sent on another network are lost.", "Her coini sadece yanında yazan ağdan gönder. Başka ağdan gönderilen tokenler kaybolur.", "Envía cada moneda solo por la red indicada. Los tokens en otra red se pierden.", "Envie cada moeda só pela rede indicada. Tokens em outra rede se perdem.")
    add("supported", "destekleniyor", "compatible", "compatível")
    add("not tested with this script", "bu scriptle denenmedi", "no probado con este script", "não testado com este script")
    add("Everything stopped. Run the loader again to start.", "Her şey durdu. Başlatmak için loader'ı tekrar çalıştır.", "Todo detenido. Ejecuta el loader para empezar.", "Tudo parado. Rode o loader de novo para começar.")
    add("Nothing is on yet: switch features on (Main / Event) or pick a preset (Config), then switch Farm running on.", "Henüz hiçbir şey açık değil: özellikleri aç (Ana sayfa / Etkinlik) ya da hazır ayar seç (Ayarlar), sonra 'Çiftlik çalışıyor'u aç.", "Nada activo aún: activa funciones (Principal / Evento) o elige un ajuste (Config) y luego 'Granja activa'.", "Nada ligado ainda: ligue funções (Principal / Evento) ou escolha uma predefinição (Config) e depois 'Fazenda ligada'.")
    add("Waiting for the game to load...", "Oyunun yüklenmesi bekleniyor...", "Esperando a que cargue el juego...", "Esperando o jogo carregar...")
    add("Running, but no feature is on: pick a preset or switch features on.", "Çalışıyor ama hiçbir özellik açık değil: hazır ayar seç ya da özellik aç.", "Activa, pero sin funciones: elige un ajuste o activa funciones.", "Ligada, mas sem funções: escolha uma predefinição ou ligue funções.")
    add("Running", "Çalışıyor", "Activa", "Ligada")
    add("Paused: no game actions.", "Duraklatıldı: oyun işlemi yok.", "En pausa: ninguna acción.", "Pausada: nenhuma ação.")
    add("FARM: STOPPED", "ÇİFTLİK: DURDU", "GRANJA: DETENIDA", "FAZENDA: PARADA")
    add("FARM: OFF", "ÇİFTLİK: KAPALI", "GRANJA: APAGADA", "FAZENDA: DESLIGADA")
    add("FARM: ON", "ÇİFTLİK: AÇIK", "GRANJA: ACTIVA", "FAZENDA: LIGADA")
    add("nothing yet", "henüz yok", "nada aún", "nada ainda")
    add("none equipped", "elde pet yok", "ninguna equipada", "nenhum equipado")
    add("Next Ghost Gallery: unknown yet", "Sonraki Hayalet Galerisi: henüz bilinmiyor", "Próxima galería: aún no se sabe", "Próxima galeria: ainda não se sabe")
    add("Tap to join the discord of your script.", "Scriptin Discord'una katılmak için dokun.", "Toca para unirte al Discord del script.", "Toque para entrar no Discord do script.")
    add("Your Executor Seems To Be Supported By This Script.", "Executor'ın bu scriptle uyumlu görünüyor.", "Tu executor parece compatible con este script.", "Seu executor parece compatível com este script.")
    add("Your Executor Is Supported By \nThis Script.", "Executor'ın bu scriptle \nuyumlu.", "Tu executor es compatible \ncon este script.", "Seu executor é compatível \ncom este script.")
    add("Your Executor Is Unsupported \nBy This Script.", "Executor'ın bu scriptle \nuyumlu değil.", "Tu executor no es compatible \ncon este script.", "Seu executor não é compatível \ncom este script.")
    add("Everything Off", "Hepsi kapalı", "Todo apagado", "Tudo desligado")
    add("Full AutoFarm", "Tam otomatik çiftlik", "AutoFarm completo", "AutoFarm completo")
    add("Mummy Spider Speedrun", "Mumya Örümcek Speedrun", "Speedrun de la Araña momia", "Speedrun da Aranha múmia")
    add("Spiders first (needs, potions, Pet Pen), keys straight down the Crypt, no eggs, no candy pets, no nest / Stray Cat.",
        "Önce örümcekler (ihtiyaç, iksir, Pet Ağılı), anahtarlar doğrudan mahzenin dibine, yumurta yok, şeker peti yok, yuva / sokak kedisi yok.",
        "Arañas primero (necesidades, pociones, corral), llaves directo al fondo de la cripta, sin huevos, sin mascotas de dulces, sin nido / gato.",
        "Aranhas primeiro (necessidades, poções, cercadinho), chaves direto ao fundo da cripta, sem ovos, sem pets de doces, sem ninho / gato.")
    add("Event Only", "Sadece etkinlik", "Solo evento", "Só evento")
    add("Needs Only", "Sadece ihtiyaçlar", "Solo necesidades", "Só necessidades")
    add("Every feature off (the defaults). Anti-AFK and the Play button stay on.", "Her özellik kapalı (varsayılan). Anti-AFK ve Play düğmesi açık kalır.", "Todo apagado (por defecto). Anti-AFK y el botón Play siguen activos.", "Tudo desligado (padrão). Anti-AFK e o botão Play continuam ligados.")
    add("Everything: every need, eggs, potions, neon + mega neon, gifts, cashback, quests and the whole event.", "Her şey: tüm ihtiyaçlar, yumurta, iksir, neon + mega neon, hediye, para iadesi, görevler ve tüm etkinlik.", "Todo: necesidades, huevos, pociones, neón + mega neón, regalos, reembolso, misiones y el evento.", "Tudo: necessidades, ovos, poções, neon + mega neon, presentes, cashback, missões e o evento todo.")
    add("Only Halloween: Ghost Gallery, Crypt + Mummy Spider, quests, Pet Pen. No pet / baby needs.", "Sadece Cadılar Bayramı: Hayalet Galerisi, Mahzen + Mumya Örümcek, görevler, Pet Ağılı. Pet / bebek ihtiyacı yok.", "Solo Halloween: galería, cripta + araña momia, misiones, corral. Sin necesidades.", "Só Halloween: galeria, cripta + aranha múmia, missões, cercadinho. Sem necessidades.")
    add("Only pet + baby needs (with eggs when nothing grows). The event stays off.", "Sadece pet + bebek ihtiyaçları (büyüyen yoksa yumurta). Etkinlik kapalı kalır.", "Solo necesidades de mascota + bebé (huevos si nada crece). El evento queda apagado.", "Só necessidades de pet + bebê (ovos se nada cresce). O evento fica desligado.")
    add("New window: game icons, your language, live Farm card, presets.", "Yeni pencere: oyun ikonları, senin dilin, canlı Çiftlik kartı, hazır ayarlar.", "Ventana nueva: iconos del juego, tu idioma, tarjeta de granja en vivo, ajustes.", "Janela nova: ícones do jogo, seu idioma, cartão da fazenda ao vivo, predefinições.")
    add("Game icons", "Oyun ikonları", "Iconos del juego", "Ícones do jogo")
    add("The game's icons and your language", "Oyunun ikonları ve senin dilin", "Iconos del juego y tu idioma", "Ícones do jogo e seu idioma")
    add("Game icons everywhere; the window speaks your language (flag = your country).", "Her yerde oyun ikonları; pencere senin dilinde (bayrak = ülken).", "Iconos del juego en todas partes; la ventana habla tu idioma.", "Ícones do jogo em todo lugar; a janela fala o seu idioma.")
    add("The window in your language: English, Türkçe, Español, Português", "Pencere senin dilinde: English, Türkçe, Español, Português", "La ventana en tu idioma: English, Türkçe, Español, Português", "A janela no seu idioma: English, Türkçe, Español, Português")
    add("Your country's flag on the Dashboard", "Panelde ülkenin bayrağı", "La bandera de tu país en el panel", "A bandeira do seu país no painel")
    add("The game's own icons: Bucks, candy, home, eggs, potions, keys", "Oyunun kendi ikonları: Bucks, şeker, ev, yumurta, iksir, anahtar", "Iconos del juego: Bucks, dulces, casa, huevos, pociones, llaves", "Ícones do jogo: Bucks, doces, casa, ovos, poções, chaves")
    add("No emojis: coloured status icons", "Emoji yok: renkli durum ikonları", "Sin emojis: iconos de estado con color", "Sem emojis: ícones de status coloridos")
    add("See-through dashboard cards", "Yarı saydam panel kartları", "Tarjetas del panel translúcidas", "Cartões do painel translúcidos")
    add("Webhook: candy + your pet's picture", "Webhook: şeker + petinin resmi", "Webhook: dulces + foto de tu mascota", "Webhook: doces + foto do seu pet")
    add("Autoclose GUI on execute (Config > Settings)", "Açılışta pencereyi gizle (Ayarlar > Ayarlar)", "Ocultar ventana al ejecutar (Config > Opciones)", "Ocultar janela ao executar (Config > Opções)")
    add("Good Morning!", "Günaydın!", "¡Buenos días!", "Bom dia!")
    add("How's Your Day Going?", "Günün nasıl geçiyor?", "¿Qué tal tu día?", "Como está seu dia?")
    add("Sweet Dreams.", "Tatlı rüyalar.", "Dulces sueños.", "Bons sonhos.")
    add("Jeez you should be asleep...", "Hey, uyuman lazım...", "Deberías estar durmiendo...", "Você devia estar dormindo...")
    local TEMPLATES = {}
    Lang.TEMPLATES = TEMPLATES
    local function template(en, tr, es, pt)
        add(en, tr, es, pt)
        table.insert(TEMPLATES, en)
    end
    template("Copied: %s", "Kopyalandı: %s", "Copiado: %s", "Copiado: %s")
    template("Error: %s", "Hata: %s", "Error: %s", "Erro: %s")
    template("Delete '%s'?", "'%s' silinsin mi?", "¿Borrar '%s'?", "Apagar '%s'?")
    template("Saved '%s'", "'%s' kaydedildi", "'%s' guardada", "'%s' salva")
    template("Overwrote '%s'", "'%s' üzerine yazıldı", "'%s' sobrescrita", "'%s' sobrescrita")
    template("Could not read '%s'", "'%s' okunamadı", "No se pudo leer '%s'", "Não deu para ler '%s'")
    template("Loaded '%s' (%d settings)", "'%s' yüklendi (%d ayar)", "'%s' cargada (%d ajustes)", "'%s' carregada (%d opções)")
    template("'%s' exists: pick it and press Overwrite", "'%s' zaten var: seç ve Üzerine yaz'a bas", "'%s' ya existe: elígela y pulsa Sobrescribir", "'%s' já existe: escolha e toque em Sobrescrever")
    template("Deleted '%s'", "'%s' silindi", "'%s' borrada", "'%s' apagada")
    template("Autoload: '%s' at start", "Açılışta yükle: '%s'", "Carga al iniciar: '%s'", "Carregar ao iniciar: '%s'")
    template("Autosave: %d change(s) kept", "Otomatik kayıt: %d değişiklik saklandı", "Guardado automático: %d cambio(s)", "Salvamento automático: %d mudança(s)")
    template("Preset: %s", "Hazır ayar: %s", "Ajuste: %s", "Predefinição: %s")
    template("%d of %d features on. %s", "%d/%d özellik açık. %s", "%d de %d funciones activas. %s", "%d de %d funções ligadas. %s")
    template("%s Your other settings stay.", "%s Diğer ayarların aynı kalır.", "%s Tus otros ajustes se quedan.", "%s Suas outras opções ficam.")
    template("The window starts hidden: %s opens it", "Pencere gizli başlar: %s açar", "La ventana empieza oculta: %s la abre", "A janela começa oculta: %s abre")
    template("Hide / show: %s", "Gizle / göster: %s", "Mostrar / ocultar: %s", "Mostrar / ocultar: %s")
    template("Ready. %s hides / shows the window.", "Hazır. %s pencereyi gizler / gösterir.", "Listo. %s muestra / oculta la ventana.", "Pronto. %s mostra / oculta a janela.")
    template("Ready. Round paw button: hide / show. Square button at the top: full screen. Sliders: tap the number to type.",
        "Hazır. Yuvarlak pati düğmesi: gizle / göster. Üstteki kare düğme: tam ekran. Kaydırıcılar: sayıya dokunup yaz.",
        "Listo. Botón de pata: mostrar / ocultar. Botón cuadrado arriba: pantalla completa. Deslizadores: toca el número para escribir.",
        "Pronto. Botão de pata: mostrar / ocultar. Botão quadrado no topo: tela cheia. Controles: toque no número para digitar.")
    template("Executor: %s", "Executor: %s", "Executor: %s", "Executor: %s")
    template("Status: %s", "Durum: %s", "Estado: %s", "Status: %s")
    template("Player: %s", "Oyuncu: %s", "Jugador: %s", "Jogador: %s")
    template("Server: %s players", "Sunucu: %s oyuncu", "Servidor: %s jugadores", "Servidor: %s jogadores")
    template("Script: v%s", "Script: v%s", "Script: v%s", "Script: v%s")
    template("What's new in v%s", "v%s yenilikleri", "Novedades de v%s", "Novidades da v%s")
    template("• %s", "• %s", "• %s", "• %s")
    template("Welcome, %s", "Hoş geldin, %s", "Bienvenido, %s", "Bem-vindo, %s")
    template("%s | %s", "%s | %s", "%s | %s", "%s | %s")
    template("%s (%s candy)", "%s (%s şeker)", "%s (%s dulces)", "%s (%s doces)")
    template("%d/%d features on", "%d/%d özellik açık", "%d/%d funciones activas", "%d/%d funções ligadas")
    template("%d of %d features on", "%d/%d özellik açık", "%d de %d funciones activas", "%d de %d funções ligadas")
    template("Paused: no game actions. %s", "Duraklatıldı: oyun işlemi yok. %s", "En pausa: ninguna acción. %s", "Pausada: nenhuma ação. %s")
    template("Switch Farm running on to start.", "Başlatmak için 'Çiftlik çalışıyor'u aç.", "Activa 'Granja activa' para empezar.", "Ligue 'Fazenda ligada' para começar.")
    template("Waiting for the game to load... %s", "Oyunun yüklenmesi bekleniyor... %s", "Esperando a que cargue el juego... %s", "Esperando o jogo carregar... %s")
    template("Running • %s", "Çalışıyor • %s", "Activa • %s", "Ligada • %s")
    template("preset %s", "hazır ayar %s", "ajuste %s", "predefinição %s")
    template("%s features on", "%s özellik açık", "%s funciones activas", "%s funções ligadas")
    template("Last done: %s", "Son yapılan: %s", "Lo último: %s", "Última: %s")
    template("Pet: %s", "Pet: %s", "Mascota: %s", "Pet: %s")
    template("%s (age %s)", "%s (yaş %s)", "%s (edad %s)", "%s (idade %s)")
    template("Session: %d min • %s needs", "Oturum: %d dk • %s ihtiyaç", "Sesión: %d min • %s necesidades", "Sessão: %d min • %s necessidades")
    template("Bucks: %s (+%s)", "Bucks: %s (+%s)", "Bucks: %s (+%s)", "Bucks: %s (+%s)")
    template("Candy: %s (+%s)", "Şeker: %s (+%s)", "Dulces: %s (+%s)", "Doces: %s (+%s)")
    template("Tasks: %s done • %s failed", "Görevler: %s bitti • %s hata", "Tareas: %s hechas • %s fallidas", "Tarefas: %s feitas • %s falhas")
    template("Doing: %s", "Yapılan: %s", "Haciendo: %s", "Fazendo: %s")
    template("Doing: nothing (stopped)", "Yapılan: hiçbir şey (durdu)", "Haciendo: nada (detenida)", "Fazendo: nada (parada)")
    template("Doing: nothing (paused)", "Yapılan: hiçbir şey (duraklatıldı)", "Haciendo: nada (en pausa)", "Fazendo: nada (pausada)")
    template("Doing: nothing to do right now", "Yapılan: şu an iş yok", "Haciendo: nada por ahora", "Fazendo: nada por agora")
    template("Needs: %s", "İhtiyaçlar: %s", "Necesidades: %s", "Necessidades: %s")
    template("Needs: none", "İhtiyaçlar: yok", "Necesidades: ninguna", "Necessidades: nenhuma")
    template("Ghost Gallery: off", "Galeri: kapalı", "Galería: apagada", "Galeria: desligada")
    template("Ghost Gallery: in %s", "Galeri: %s sonra", "Galería: en %s", "Galeria: em %s")
    template("Ghost Gallery: waiting", "Galeri: bekleniyor", "Galería: esperando", "Galeria: esperando")
    template("Pet Pen: off", "Pet Ağılı: kapalı", "Corral: apagado", "Cercadinho: desligado")
    template("Pet Pen: %d/%d • claim %s", "Pet Ağılı: %d/%d • toplama %s", "Corral: %d/%d • reclamar en %s", "Cercadinho: %d/%d • coletar em %s")
    template("Pet Pen: %d/%d • claim now", "Pet Ağılı: %d/%d • şimdi topla", "Corral: %d/%d • reclamar ya", "Cercadinho: %d/%d • coletar agora")
    template("Pet Pen: no data yet", "Pet Ağılı: henüz veri yok", "Corral: sin datos aún", "Cercadinho: sem dados ainda")
    template("Resting: %s", "Dinlenen: %s", "En pausa: %s", "Em pausa: %s")
    template("Resting: none", "Dinlenen: yok", "En pausa: ninguna", "Em pausa: nenhuma")
    template("%s (%d min)", "%s (%d dk)", "%s (%d min)", "%s (%d min)")
    template("Rusty Keys: %s  •  Twigs: %s", "Paslı Anahtar: %s  •  Dal: %s", "Llaves oxidadas: %s  •  Ramitas: %s", "Chaves enferrujadas: %s  •  Gravetos: %s")
    template("Nest: %s / 8 twigs", "Yuva: %s / 8 dal", "Nido: %s / 8 ramitas", "Ninho: %s / 8 gravetos")
    template("Nest: ?", "Yuva: ?", "Nido: ?", "Ninho: ?")
    template("Next Ghost Gallery in %s", "Sonraki Hayalet Galerisi: %s", "Próxima galería en %s", "Próxima galeria em %s")
    template("%s/%s players", "%s/%s oyuncu", "%s/%s jugadores", "%s/%s jogadores")
    template("%s FPS • %s ms", "%s FPS • %s ms", "%s FPS • %s ms", "%s FPS • %s ms")
    template("server %s", "sunucu %s", "servidor %s", "servidor %s")
    template("baby %s", "bebek %s", "bebé %s", "bebê %s")
    local NEED_WORDS = {
        ["pet me"] = { "sevme", "caricias", "carinho" }, hungry = { "aç", "hambre", "fome" },
        thirsty = { "susamış", "sed", "sede" }, play = { "oyun", "jugar", "brincar" }, sleepy = { "uykulu", "sueño", "sono" },
        dirty = { "kirli", "sucio", "sujo" }, toilet = { "tuvalet", "baño", "banheiro" }, walk = { "yürüyüş", "paseo", "passeio" },
        ride = { "gezinti", "carrito", "carrinho" }, mystery = { "gizem", "misterio", "mistério" },
        salon = { "kuaför", "salón", "salão" }, ["cat cafe"] = { "kedi kafe", "café de gatos", "café dos gatos" },
        ["pizza party"] = { "pizza partisi", "fiesta de pizza", "festa da pizza" }, school = { "okul", "escuela", "escola" },
        sick = { "hasta", "enfermo", "doente" }, camping = { "kamp", "campamento", "acampamento" },
        ["beach party"] = { "plaj partisi", "fiesta en la playa", "festa na praia" }, bored = { "sıkılmış", "aburrido", "entediado" },
        ["ghost gallery"] = { "hayalet galerisi", "galería", "galeria" }, ["pet pen"] = { "pet ağılı", "corral", "cercadinho" },
    }
    for word, words in pairs(NEED_WORDS) do
        if not S[word] then
            add(word, words[1], words[2], words[3])
        end
    end
    local function exact(text)
        local entry = S[text]
        local value = entry and entry[Lang.current]
        if value then
            return value
        end
        local before, core, after = string.match(text, "^(%s*)(.-)(%s*)$")
        if core ~= text and core ~= "" then
            entry = S[core]
            value = entry and entry[Lang.current]
            if value then
                return before .. value .. after
            end
        end
        return nil
    end
    local compiled
    Lang._memo, Lang._memoSize = {}, 0
    local function compile()
        compiled = {}
        for _, key in ipairs(TEMPLATES) do
            local count = 0
            local pattern = string.gsub(key, "(%%?)(.)", function(percent, char)
                if percent == "%" and (char == "s" or char == "d") then
                    count += 1
                    return char == "s" and "(.-)" or "(%-?[%d,]+)"
                end
                local text = percent .. char
                return (string.gsub(text, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
            end)
            if count > 0 then
                table.insert(compiled, { key = key, pattern = "^" .. pattern .. "$", count = count })
            end
        end
        table.sort(compiled, function(a, b)
            return #a.key > #b.key
        end)
    end
    local function fill(translated, values)
        local index = 0
        return (string.gsub(translated, "%%([sd])", function()
            index += 1
            return values[index] or ""
        end))
    end
    function Lang.tr(text)
        if Lang.current == "en" or type(text) ~= "string" or text == "" then
            return text
        end
        local hit = exact(text)
        if hit then
            return hit
        end
        if string.find(text, "\n", 1, true) then
            local lines = {}
            for line in string.gmatch(text .. "\n", "(.-)\n") do
                table.insert(lines, Lang.tr(line))
            end
            return table.concat(lines, "\n")
        end
        if not compiled then
            compile()
        end
        local memo = Lang._memo[Lang.current]
        if memo and memo[text] then
            return memo[text]
        end
        local result = text
        for _, entry in ipairs(compiled) do
            local values = { string.match(text, entry.pattern) }
            if #values == entry.count then
                for index, value in ipairs(values) do
                    values[index] = exact(value) or value
                end
                result = fill(S[entry.key][Lang.current] or entry.key, values)
                break
            end
        end
        memo = memo or {}
        if Lang._memoSize > 400 then
            memo, Lang._memoSize = {}, 0
        end
        memo[text] = result
        Lang._memo[Lang.current] = memo
        Lang._memoSize += 1
        return result
    end
    function Lang.t(text, ...)
        local translated = Lang.tr(text)
        if select("#", ...) == 0 then
            return translated
        end
        local ok, result = pcall(string.format, translated, ...)
        if ok then
            return result
        end
        return string.format(text, ...)
    end
    return Lang
end
__moduleSources["Services/Interface"] = function(...)
    local import = ...
    local Config = import("Core/Config")
    local Lang = import("Services/Lang")
    local T = Lang.t
    local Interface = {}
    Interface.TITLE = "Adopt Victims"
    Interface.EDITION = "v2  •  UI Remastered Edition"
    Interface.LIBRARY_URL = "https://raw.nebulasoftworks.xyz/starlight"
    Interface.DISCORD_INVITE = "drCrvFqWSQ"
    Interface.DONATION_LINKS = {
        { name = "NOWPayments", icon = "wallet", link = "https://nowpayments.io/donation/victimoffate_" },
        { name = "Buy Me a Coffee", icon = "coffee", link = "https://buymeacoffee.com/victimoffate_" },
    }
    Interface.CRYPTO = {
        { name = "BTC — Bitcoin", icon = "bitcoin", address = "bc1q7chk329my7q565zwzgvt08xq6avxwakxhrr6vh" },
        { name = "ETH — Ethereum", icon = "gem", address = "0x9059B726B686F8A7331589E79b3b48743D4238Fc" },
        { name = "USDT — Ethereum (ERC-20)", icon = "coins", address = "0x9059B726B686F8A7331589E79b3b48743D4238Fc" },
        { name = "USDC — Ethereum (ERC-20)", icon = "coins", address = "0x9059B726B686F8A7331589E79b3b48743D4238Fc" },
        { name = "SOL — Solana", icon = "sun", address = "2L5QzYscmeWY3EToMNAQqBrstD3NuxMnMAUQzMShyyxL" },
        { name = "LTC — Litecoin", icon = "coins", address = "Lc4tjBQ1PPdHyAwpdRAEeAYRMbdXKfeYmZ" },
        { name = "DOGE — Dogecoin", icon = "dog", address = "D68nRuNHi1m1CKFeitxyNRHfFb2VGhFfTJ" },
        { name = "XRP — XRP Ledger", icon = "coins", address = "rPo5BAZ5do5rpSGDch5SMQhwKS1VESTF7v" },
        { name = "TRX — Tron", icon = "coins", address = "TNnh6xN4QoVVgHRBRsQnkrBZ9MztsuwzN6" },
    }
    Interface.GAMEPASSES = {
    }
    local ICON_IDS = {
        ["activity"] = 116785635688905,
        ["at-sign"] = 104314582758551,
        ["baby"] = 134780923890658,
        ["badge-check"] = 102864233048311,
        ["banknote"] = 83624352345036,
        ["bed"] = 103703460158347,
        ["bell"] = 111725241873349,
        ["bird"] = 127082032570770,
        ["bitcoin"] = 120165823908407,
        ["bone"] = 93032826374472,
        ["bug"] = 108064626456459,
        ["camera"] = 102911860111235,
        ["candy"] = 121602796953412,
        ["cat"] = 132587012252853,
        ["check"] = 83827110621355,
        ["circle-dot"] = 73332621255981,
        ["circle-gauge"] = 84688454826847,
        ["circle-pause"] = 75601858754638,
        ["code"] = 102858857098762,
        ["coffee"] = 75171771078867,
        ["coins"] = 128784569032326,
        ["copy"] = 87942399647942,
        ["cpu"] = 115781787166822,
        ["crosshair"] = 114929017287945,
        ["cup-soda"] = 116064630908908,
        ["dices"] = 117821030233748,
        ["dog"] = 111571812945872,
        ["door-open"] = 133814065231262,
        ["download"] = 93868047445509,
        ["egg"] = 73908680452587,
        ["eraser"] = 101514212866613,
        ["eye-off"] = 112375739491233,
        ["fence"] = 136027177552403,
        ["file-text"] = 77346633411296,
        ["flask-conical"] = 77588155748536,
        ["footprints"] = 128293375583452,
        ["gem"] = 111750318675671,
        ["ghost"] = 121912141443713,
        ["gift"] = 104098622197576,
        ["graduation-cap"] = 137048485405567,
        ["hand-heart"] = 112348965568014,
        ["heart"] = 111284155515598,
        ["heart-handshake"] = 116921190920035,
        ["history"] = 87356875172942,
        ["hourglass"] = 97354459771104,
        ["house"] = 127889862453151,
        ["info"] = 117194610053749,
        ["key-round"] = 80439075172197,
        ["keyboard"] = 78021479821645,
        ["layers"] = 92401939426051,
        ["link"] = 73034596791310,
        ["list-checks"] = 86457557777962,
        ["list-ordered"] = 90091028350622,
        ["map-pin"] = 125589857044225,
        ["monitor"] = 73331152826648,
        ["mouse-pointer-click"] = 107709798577185,
        ["octagon-x"] = 117018306251145,
        ["package"] = 132935702099654,
        ["palette"] = 72590019059979,
        ["party-popper"] = 109041559217985,
        ["paw-print"] = 92297066485556,
        ["ph:discord-logo"] = 101359832205037,
        ["pizza"] = 95650659741106,
        ["power"] = 139821907770093,
        ["refresh-cw"] = 76845925482586,
        ["rocket"] = 79846157539863,
        ["rotate-ccw"] = 103593823592882,
        ["save"] = 126786081818943,
        ["scissors"] = 73848300538397,
        ["scroll-text"] = 86918746287564,
        ["send"] = 120131238507529,
        ["settings"] = 101463883805422,
        ["shield-check"] = 83449656859552,
        ["shopping-bag"] = 128835919419658,
        ["shower-head"] = 73619400343212,
        ["skip-forward"] = 96350165788710,
        ["skull"] = 89401908547230,
        ["sliders-horizontal"] = 104021219611587,
        ["smartphone"] = 109476896891915,
        ["sparkles"] = 130602425201313,
        ["stethoscope"] = 105982582717298,
        ["sun"] = 79901529465096,
        ["target"] = 81035867308138,
        ["tent"] = 135834669198083,
        ["ticket"] = 104336783939037,
        ["timer"] = 96119720980390,
        ["toilet"] = 82858381666593,
        ["trash-2"] = 79564839810840,
        ["tree-palm"] = 128164120447244,
        ["triangle-alert"] = 76712741040235,
        ["utensils"] = 92328553872866,
        ["wallet"] = 82693664006746,
        ["wand-sparkles"] = 109636225248973,
        ["wrench"] = 108764185264619,
        ["users"] = 109023655602096,
        ["scaling"] = 72422884764012,
        ["wifi"] = 101360393607039,
        ["globe"] = 111578783307093,
        ["languages"] = 99917326264912,
        ["zap"] = 99546940565021,
    }
    Interface.GAME_ICON_FALLBACK = { ["game:bucks"] = "banknote", ["game:candy"] = "candy", ["game:home"] = "house" }
    Interface.gameIconIds = {}
    local function I(name, fallback)
        if type(name) == "string" and string.find(name, "|", 1, true) then
            name, fallback = string.match(name, "^(.-)|(.*)$")
        end
        if type(name) == "string" and (string.sub(name, 1, 5) == "game:" or string.sub(name, 1, 5) == "item:") then
            local id
            if type(Interface.gameIcon) == "function" then
                local ok, picture = pcall(Interface.gameIcon, name)
                id = ok and type(picture) == "string" and tonumber(string.match(picture, "^rbxassetid://(%d+)$")
                    or string.match(picture, "[?&]id=(%d+)")) or nil
            end
            if id then
                Interface.gameIconIds[id] = true
                return id
            end
            return ICON_IDS[fallback or Interface.GAME_ICON_FALLBACK[name] or "circle-dot"]
        end
        return ICON_IDS[name]
    end
    Interface.I = I
    Interface.ICON_IDS = ICON_IDS
    Interface.SPEEDRUN_PRESET = Config.SPEEDRUN_CHANGES
    Interface.TOASTS = {
        { pattern = "Rusty Key EARNED", title = "Rusty Key earned", icon = "key-round" },
        { pattern = "^Crypt: Mummy Spider claimed", title = "Mummy Spider claimed", icon = "bug" },
        { pattern = "^Neon fusion: ", title = "Neon fusion", icon = "wand-sparkles" },
        { pattern = "^Mega neon fusion: ", title = "Mega neon!", icon = "sparkles" },
        { pattern = "^Bought halloween_2026_", title = "Candy shop", icon = "candy" },
        { pattern = "^Quests: .* claimed", title = "Quest reward", icon = "scroll-text" },
        { pattern = "^Nest completed", title = "Pigeon nest built", icon = "bird" },
        { pattern = "^Ghost Gallery: %d+ points", title = "Ghost Gallery round", icon = "ghost" },
        { pattern = "failures in a row: disabled", title = "Task resting", icon = "octagon-x" },
        { pattern = "^Stuck in .*Farm.StuckRecovery", title = "Stuck: going home", icon = "rotate-ccw" },
    }
    Interface.THEMES = { "Starlight", "Hollywood Dark", "Tokyo Night", "Catppuccin Mocha", "Crimson", "Nebula", "Neo (Dark)",
        "Orca", "Glacier", "Pacific", "Evergreen", "Luna", "OperaGX", "Ubuntu", "BBot", "Hollywood Fluent", "Hollywood Light",
        "Catppuccin Latte" }
    Interface.THEME_NAMES = { "Default", "Halloween", "Fresh", "Dark Minimal" }
    Interface.THEME_PROFILES = {
        Default = { base = "Starlight", fallback = { "Starlight" } },
        Halloween = {
            base = "Starlight",
            fallback = { "OperaGX", "Crimson", "Nebula" },
            accent = { { 255, 128, 24 }, { 236, 72, 153 }, { 147, 51, 234 } },
            bright = { { 255, 186, 107 }, { 249, 150, 200 }, { 196, 150, 255 } },
            backgrounds = { Dark = { 13, 9, 19 }, Medium = { 18, 12, 26 }, Light = { 28, 19, 40 }, Groupbox = { 24, 16, 35 },
                Highlight = { 10, 7, 15 } },
            divider = { 124, 82, 170 },
        },
        Fresh = {
            base = "Starlight",
            fallback = { "Evergreen", "Pacific", "Glacier" },
            accent = { { 52, 211, 153 }, { 45, 212, 191 }, { 56, 189, 248 } },
            bright = { { 134, 239, 172 }, { 153, 246, 228 }, { 125, 211, 252 } },
            backgrounds = { Dark = { 14, 25, 27 }, Medium = { 17, 30, 33 }, Light = { 23, 38, 42 }, Groupbox = { 26, 43, 47 },
                Highlight = { 10, 19, 21 } },
            divider = { 110, 176, 166 },
        },
        ["Dark Minimal"] = {
            base = "Hollywood Dark",
            fallback = { "Hollywood Dark", "Neo (Dark)", "Tokyo Night" },
            accent = { { 236, 236, 236 }, { 186, 186, 186 }, { 140, 140, 140 } },
            bright = { { 255, 255, 255 }, { 216, 216, 216 }, { 176, 176, 176 } },
        },
    }
    Interface.PALETTE = {
        pumpkin = { 255, 140, 40 }, candy = { 255, 92, 170 }, witch = { 168, 85, 247 }, ghost = { 94, 234, 212 },
        slime = { 132, 204, 22 }, blood = { 239, 68, 68 }, moon = { 250, 204, 21 }, night = { 96, 165, 250 },
        bone = { 214, 211, 209 }, teal = { 45, 212, 191 }, discord = { 99, 102, 241 }, gray = { 148, 163, 184 },
        green = { 34, 197, 94 },
    }
    Interface.BOX_COLORS = {
        discord = "discord", changelog = "pumpkin", executor = "blood", farm = "moon", needs = "slime", pen = "green",
        pets = "candy", growth = "witch", tasks = "teal", halloween = "pumpkin", crypt = "bone", shop = "candy",
        eventInfo = "ghost", hook = "discord", messages = "night", configs = "witch", settings = "night", presets = "pumpkin",
        advanced = "gray", developer = "witch", donate = "candy", passes = "pumpkin", crypto = "moon",
    }
    Interface.DASHBOARD_COLORS = {
        Discord = { "discord", "witch" }, Server = { "slime", "teal" }, Changelog = { "pumpkin", "moon" },
        Executor = { "blood", "candy" }, Friends = { "moon", "pumpkin" }, Account = { "witch", "night" },
    }
    local DASHBOARD_ORDER = { "witch", "slime", "pumpkin", "blood", "moon", "night" }
    Interface.DASHBOARD_KNOWN = { Discord = true, Server = true, Changelog = true, Executor = true, Friends = true }
    Interface.SUPPORTED_EXECUTORS = { "Delta" }
    Interface.NEED_NAMES = {
        { "pet_me", "Pet me" }, { "hungry", "Hungry" }, { "thirsty", "Thirsty" }, { "play", "Play" }, { "sleepy", "Sleepy" },
        { "dirty", "Dirty" }, { "toilet", "Toilet" }, { "walk", "Walk" }, { "ride", "Ride" }, { "mystery", "Mystery card" },
        { "salon", "Salon" }, { "cat_cafe", "Cat Cafe" }, { "pizza_party", "Pizza party" }, { "school", "School" },
        { "sick", "Sick" }, { "camping", "Camping" }, { "beach_party", "Beach party" }, { "bored", "Bored" },
    }
    Interface.POTION_NAMES = { pet_age_potion = "Age-Up Potion", tiny_pet_age_potion = "Tiny Age-Up Potion",
        pet_bonus_bucks_potion = "Bucks Potion" }
    Interface.CRYPT_NAMES = { { "ladder", "Next floor (Mummy Spider)" }, { "twig", "Twig" },
        { "candy_corn_pile_ginormous", "Big candy pile" }, { "candy_corn_pile_small", "Small candy pile" } }
    Interface.SHOP_NAMES = { halloween_2026_jump_scare = "Jump Scare", halloween_2026_jacobean_pigeon = "Jacobean Pigeon" }
    Interface.EGG_NAMES = { { "cracked_egg", "Cracked Egg (350 Bucks)" }, { "pet_egg", "Pet Egg (600 Bucks)" },
        { "fairytale_egg_2026_fairytale_egg", "Fairytale Egg (event)" } }
    Interface.PING_NAMES = { Kick = "Kick / disconnect", Error = "Errors", Summary = "Summaries", TaskCompleted = "Finished needs",
        SessionStopped = "Stopped", PreviousSession = "Last run ended badly" }
    Interface.CHANGELOG = {
        "Adopt Victims v2 - UI Remastered Edition (07 Oct 2026, 16:28 TR)",
        "The window in your language: English, Türkçe, Español, Português",
        "Your country's flag on the Dashboard",
        "The game's own icons: Bucks, candy, home, eggs, potions, keys",
        "No emojis: coloured status icons",
        "See-through dashboard cards",
        "Webhook: candy + your pet's picture",
        "One line at start (full report: Config)",
        "Dashboard as you drew it, Farm status card",
        "Autoclose GUI on execute (Config > Settings)",
    }
    Interface.CHANGELOG_LATEST = {
        Title = "v2 - UI Remastered Edition",
        Date = "07 Oct 2026, 16:28 (TR)",
        Description = "New window: game icons, your language, live Farm card, presets.",
    }
    Interface.DEVELOPER = {
        name = "Victim",
        user = "victimoffate_",
        github = "https://github.com/Amivictim/adoptmefarm",
        avatarUrl = "https://raw.githubusercontent.com/Amivictim/adoptmefarm/refs/heads/main/victimoffate_.png",
        avatarFile = "AdoptMeFarm/victimoffate_.png",
    }
    function Interface.developerAvatar()
        local dev = Interface.DEVELOPER
        if type(getcustomasset) == "function" and type(writefile) == "function" then
            local ok, image = pcall(function()
                if not (type(isfile) == "function" and isfile(dev.avatarFile)) then
                    local data = game:HttpGet(dev.avatarUrl)
                    if type(data) ~= "string" or (string.sub(data, 1, 8) ~= "\137PNG\r\n\26\n" and string.sub(data, 1, 3) ~= "\255\216\255") then
                        error("not a PNG / JPEG picture")
                    end
                    writefile(dev.avatarFile, data)
                end
                return getcustomasset(dev.avatarFile)
            end)
            if ok and type(image) == "string" and image ~= "" then
                return image
            end
        end
        local ok, image = pcall(function()
            local Players = game:GetService("Players")
            local userId = Players:GetUserIdFromNameAsync(dev.user)
            return (Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150))
        end)
        return ok and type(image) == "string" and image or nil
    end
    local DOT = { on = "🟢", wait = "🟡", bad = "🔴", off = "⚪" }
    Interface.DOT = DOT
    local NEED_INFO = {
        pet_me = { "Pet me (petting)", "hand-heart", "A" }, hungry = { "Hungry (food)", "utensils", "A" },
        thirsty = { "Thirsty (drink)", "cup-soda", "A" }, play = { "Play (squeaky bone)", "bone", "A" },
        sleepy = { "Sleepy (your bed)", "bed", "A" }, dirty = { "Dirty (your shower)", "shower-head", "A" },
        toilet = { "Toilet (your toilet)", "toilet", "A" }, walk = { "Walk", "footprints", "A" },
        ride = { "Ride (stroller)", "baby", "A" }, mystery = { "Mystery card", "dices", "A" },
        salon = { "Salon", "scissors", "B" }, cat_cafe = { "Cat Cafe", "cat", "B" },
        pizza_party = { "Pizza party", "pizza", "B" }, school = { "School", "graduation-cap", "B" },
        sick = { "Sick (hospital)", "stethoscope", "B" }, camping = { "Camping (camp site)", "tent", "B" },
        beach_party = { "Beach party", "tree-palm", "B" }, bored = { "Bored (playground)", "party-popper", "B" },
    }
    Interface.DESCRIPTIONS = {
        ["Farm.Enabled"] = "Master switch. Off = no game actions at all",
        ["Farm.BabyMode"] = "Joins the Babies team to do baby needs too",
        ["Farm.MultiNeed.Enabled"] = "While waiting at a place: food, drink, toy, petting",
        ["Farm.BuyWater"] = "No drink left: buys 1 water (1 Buck)",
        ["Farm.BuyFood"] = "No food left: buys 1 sandwich / hotdog",
        ["Farm.KeepPetEquipped"] = "No pet out: equips a pet that still grows",
        ["Farm.SkipFullGrown"] = "Swaps a full grown pet for a growing one",
        ["Farm.PreferNeon"] = "Growing neon pets are farmed first",
        ["Farm.AutoPotions.Enabled"] = "Age potions on the farmed growing pet",
        ["Farm.AutoNeon.Enabled"] = "4 full grown of one kind -> 1 neon",
        ["Farm.BuyEgg"] = "No growing pet left: buys 1 egg (Bucks only)",
        ["Farm.AutoOpen.Enabled"] = "Opens gifts and chests in your backpack",
        ["Farm.Event.Enabled"] = "Master switch for every Halloween job",
        ["Farm.Event.GhostGallery"] = "Joins each round, vacuums ghosts (Rusty Keys)",
        ["Farm.Event.GhostJoinByZone"] = "Joins by standing in the Manor circle",
        ["Farm.Event.Crypt"] = "Uses Rusty Keys on the grave going down",
        ["Farm.Event.MummySpider"] = "Bottom of the Crypt: takes the spider",
        ["Farm.Event.Quests"] = "Claims finished daily + board quests",
        ["Farm.Event.HouseVisits"] = "Visit-homes quests: visits houses here",
        ["Farm.Event.PigeonNest"] = "Puts Crypt Twigs into the Hotel nest",
        ["Farm.Event.AutoNest"] = "Twig graves first until the nest is built",
        ["Farm.Event.StrayCat"] = "1 water to the Stray Cat a day (+candy)",
        ["Farm.Event.PetPen"] = "Claims the pen, keeps it full (at home)",
        ["Farm.Event.PetPenStock"] = "Buys eggs so the pen stays full",
        ["Farm.Event.PetPenMinutes"] = "How often the pen is claimed",
        ["Farm.Event.CandyPets.Enabled"] = "Saves candy for the pets in your list",
        ["Farm.AntiAfk"] = "Clicks on Roblox's idle warning (also paused)",
        ["Farm.AutoAcceptMenu"] = "Clicks Play on the main menu (also paused)",
        ["Farm.CollectCashback"] = "Collects cashback Bucks (while running)",
        ["Farm.AutoRejoin"] = "No place / character: rejoins a PUBLIC server",
        ["Farm.StuckRejoinSeconds"] = "How long before that rejoin",
        ["Farm.GameTravel"] = "Travels with the game's own doors",
        ["Farm.HomeByRespawn"] = "Goes home by respawn (fastest)",
        ["Farm.SpotTravel"] = "Route to camping / beach / playground",
        ["Farm.FoodBowlTrip"] = "Goes home for the free bowl even with food",
        ["Farm.PetOrder"] = "Which growing pet first: youngest / oldest",
        ["Farm.EggToBuy"] = "Egg bought with Bucks (never Robux)",
        ["Farm.FarmPetKinds"] = "Pet kinds farmed first, comma separated",
        ["Farm.AutoPotions.PetKinds"] = "Potions only on these kinds (empty = any)",
        ["Farm.SmartPriority"] = "Needs doable right here go first",
        ["Farm.StuckRecovery.Enabled"] = "Not moving, tasks failing: respawn home",
        ["Farm.StuckRecovery.Seconds"] = "How long before it counts as stuck",
        ["Farm.DisableMinutes"] = "3 fails in a row: rest (0 = whole session)",
        ["Farm.MaxBuysPerSession"] = "Max food / water buys (0 = no limit)",
        ["Farm.MaxEggBuysPerSession"] = "Max egg buys (0 = no limit)",
        ["Interface.Toasts"] = "Pop-ups for keys, neon, purchases, rounds",
        ["Interface.Theme"] = "Window colours",
        ["Interface.Descriptions"] = "These lines (the window opens again)",
        ["Interface.StartHidden"] = "Starts closed: the key / paw button opens it",
        ["Telemetry.Enabled"] = "Bug reports to the developer (off: at once)",
        ["Farm.CashbackMinutes"] = "How often cashback is collected",
        ["Farm.Event.PetPenSlots"] = "4 free slots; 5 with the extra-slot pass",
        ["Farm.Event.PetPenStockMinBucks"] = "Buys pen eggs only above these Bucks",
        ["Farm.MultiNeed.Kinds"] = "Which quick needs run beside a place need",
        ["Farm.MultiNeed.GapSeconds"] = "Pause between two quick needs",
        ["Farm.AutoNeon.Exclude"] = "Pet kinds that are never fused",
        ["Farm.AutoOpen.Exclude"] = "Gifts / chests that are never opened",
        ["Farm.AutoPotions.Potions"] = "Which age potions may be used",
        ["Farm.FailureCooldownSeconds"] = "Wait after a failed task before a retry",
        ["Farm.MaxConsecutiveFailures"] = "Fails in a row before a task rests",
        ["Farm.HouseDoorExit"] = "Experimental: leave home by its door",
        ["Farm.Event.CandyPets.KeepCandy"] = "Candy kept back, whatever the list wants",
        ["Logging.ConsoleLevel"] = "How much the console shows (OFF = quiet)",
        ["Telemetry.IncludeInventory"] = "Reports also list item / pet counts",
        ["Interface.Keybind"] = "Key that hides / shows this window",
        ["Notifications.SendOnStartStop"] = "Message when the farm starts / stops",
        ["Notifications.SendOnTaskComplete"] = "One message per finished need (many)",
        ["Notifications.SendOnError"] = "Message on this script's errors",
        ["Notifications.SendOnKick"] = "Message on a kick / disconnect",
        ["Notifications.IncludeUsername"] = "Your Roblox name in the messages",
        ["Notifications.PingOn"] = "@mention you for these messages",
    }
    Interface.KEYBINDS = { "RightShift", "LeftShift", "RightControl", "LeftControl", "RightAlt", "LeftAlt", "Insert", "Home",
        "End", "Delete", "PageUp", "PageDown", "F1", "F2", "F3", "F4", "F6", "F7", "F8", "F9", "K", "M", "P" }
    Interface.CONSOLE_LEVELS = { "OFF", "ERROR", "WARN", "SUCCESS", "INFO", "DEBUG" }
    Interface.PING_FLAGS = { "Kick", "Error", "Summary", "TaskCompleted", "SessionStopped", "PreviousSession" }
    Interface.QUICK_NEEDS = { "pet_me", "hungry", "thirsty", "play" }
    Interface.AGE_POTIONS = { "pet_age_potion", "tiny_pet_age_potion" }
    local NEED_DESCRIPTIONS = {
        pet_me = "Pets your pet until the need is done", hungry = "Bowl at home, else your food; buys if on",
        thirsty = "Your water / milk; buys 1 water if on", play = "Throws your squeaky bone",
        sleepy = "Your bed at home (goes home)", dirty = "Your shower at home (goes home)",
        toilet = "Your toilet at home (goes home)", walk = "Walks your character until done",
        ride = "Walks with your stroller until done", mystery = "Picks a card this script can do",
        salon = "Goes to the Salon and waits", cat_cafe = "Goes to the Cat Cafe and waits",
        pizza_party = "Goes to the Pizza Shop and waits", school = "Goes to School and waits",
        sick = "Hospital: talks to the doctor", camping = "Camp site spot on the map",
        beach_party = "Beach spot on the map", bored = "Playground spot on the map",
    }
    for kind, text in pairs(NEED_DESCRIPTIONS) do
        Interface.DESCRIPTIONS["Farm.Tasks." .. kind] = text
    end
    local function commas(value)
        local number = tonumber(value)
        if not number then
            return "?"
        end
        local negative = number < 0
        local text = tostring(math.floor(math.abs(number) + 0.5))
        text = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
        text = string.gsub(text, "^,", "")
        return (negative and "-" or "") .. text
    end
    Interface.commas = commas
    local function prettyKind(kind)
        kind = tostring(kind or "?")
        kind = string.gsub(kind, "^halloween_2026_", "")
        kind = string.gsub(kind, "^basic_egg_2022_", "")
        return (string.gsub(kind, "_", " "))
    end
    local function clock(seconds)
        seconds = math.max(0, math.floor(tonumber(seconds) or 0))
        return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
    end
    local function fit(text, width)
        text = tostring(text)
        width = math.max(8, width or 64)
        local length = utf8.len(text) or #text
        if length <= width then
            return text
        end
        local cut = utf8.offset(text, width - 2) or (width - 2)
        return string.sub(text, 1, cut - 1) .. "..."
    end
    Interface.fit = fit
    local function deepCopy(value)
        if type(value) ~= "table" then
            return value
        end
        local copy = {}
        for key, item in pairs(value) do
            copy[key] = deepCopy(item)
        end
        return copy
    end
    local function isStringList(value)
        if type(value) ~= "table" then
            return false
        end
        local count = 0
        for key, item in pairs(value) do
            if type(key) ~= "number" or type(item) ~= "string" then
                return false
            end
            count += 1
        end
        return count == #value
    end
    local function sameValue(a, b)
        if type(a) == "table" and type(b) == "table" then
            if #a ~= #b then
                return false
            end
            for index = 1, #a do
                if a[index] ~= b[index] then
                    return false
                end
            end
            return true
        end
        return a == b
    end
    function Interface.parseList(text)
        local list = {}
        for item in string.gmatch(tostring(text or ""), "[^,]+") do
            item = string.match(item, "^%s*(.-)%s*$")
            if item ~= "" and not table.find(list, item) then
                table.insert(list, item)
            end
        end
        return list
    end
    function Interface.buildTheme(themes, name)
        local profile = Interface.THEME_PROFILES[name]
        if not profile or not profile.accent or type(themes) ~= "table" then
            return nil
        end
        if type(Color3) ~= "table" and type(Color3) ~= "userdata" or ColorSequence == nil or ColorSequenceKeypoint == nil then
            return nil
        end
        local base = themes[profile.base] or themes.Starlight
        if type(base) ~= "table" or type(base.Accents) ~= "table" then
            return nil
        end
        local ok, theme = pcall(function()
            local copy = deepCopy(base)
            local function rgb(c)
                return Color3.fromRGB(c[1], c[2], c[3])
            end
            local function sequence(colors)
                local points = {}
                for index, c in ipairs(colors) do
                    table.insert(points, ColorSequenceKeypoint.new((index - 1) / math.max(1, #colors - 1), rgb(c)))
                end
                return ColorSequence.new(points)
            end
            copy.Accents.Main = sequence(profile.accent)
            copy.Accents.Brighter = sequence(profile.bright or profile.accent)
            if profile.backgrounds and type(copy.Backgrounds) == "table" then
                for key, c in pairs(profile.backgrounds) do
                    if copy.Backgrounds[key] ~= nil then
                        copy.Backgrounds[key] = rgb(c)
                    end
                end
            end
            if profile.divider and type(copy.Miscellaneous) == "table" and copy.Miscellaneous.Divider ~= nil then
                copy.Miscellaneous.Divider = rgb(profile.divider)
            end
            return copy
        end)
        return ok and theme or nil
    end
    function Interface.themeChoice(library, name)
        local themes = type(library) == "table" and library.Themes
        if type(themes) ~= "table" or type(name) ~= "string" then
            return nil
        end
        local profile = Interface.THEME_PROFILES[name]
        if profile then
            local built = Interface.buildTheme(themes, name)
            if built then
                return built
            end
            for _, fallback in ipairs(profile.fallback) do
                if themes[fallback] ~= nil then
                    return fallback
                end
            end
            return nil
        end
        return themes[name] ~= nil and name or nil
    end
    function Interface.press(signal)
        return (pcall(function()
            assert(signal ~= nil, "no button")
            if type(firesignal) == "function" then
                firesignal(signal)
            elseif type(getconnections) == "function" then
                local fired = false
                for _, connection in ipairs(getconnections(signal)) do
                    if type(connection.Fire) == "function" then
                        connection:Fire()
                        fired = true
                    end
                end
                assert(fired, "no connection")
            else
                error("no firesignal")
            end
        end))
    end
    function Interface.openTab(tab)
        local ok, signal = pcall(function()
            return tab.Instances.Button.Interact.MouseButton1Click
        end)
        return ok and Interface.press(signal)
    end
    function Interface.hideWindow(instance)
        local ok, signal = pcall(function()
            local screen = instance:FindFirstAncestorOfClass("ScreenGui")
            for _, item in ipairs(screen:GetDescendants()) do
                if item.Name == "Minimize" and item.Parent and item.Parent.Name == "Controls" then
                    return item.MouseButton1Click
                end
            end
            return nil
        end)
        return ok and Interface.press(signal)
    end
    local function paletteColor(name)
        local c = type(name) == "table" and name or Interface.PALETTE[name]
        return c and Color3.fromRGB(c[1], c[2], c[3]) or nil
    end
    local function hexColor(name)
        local c = Interface.PALETTE[name] or { 255, 255, 255 }
        return string.format("#%02X%02X%02X", c[1], c[2], c[3])
    end
    local tintBase = setmetatable({}, { __mode = "k" })
    local function isWhite(c)
        return c.R >= 0.999 and c.G >= 0.999 and c.B >= 0.999
    end
    function Interface.tintFrame(frame, colors, fromAmount, toAmount, rotation, see)
        local gradient = frame:FindFirstChild("AmeFarmGradient")
        if not gradient then
            if frame:FindFirstChildOfClass("UIGradient") then
                return false
            end
            gradient = Instance.new("UIGradient")
            gradient.Name = "AmeFarmGradient"
            gradient.Parent = frame
        end
        local current = frame.BackgroundColor3
        if not isWhite(current) then
            tintBase[frame] = current
        end
        local base = tintBase[frame] or current
        frame.BackgroundColor3 = Color3.new(1, 1, 1)
        gradient.Color = ColorSequence.new(base:Lerp(paletteColor(colors[1]), fromAmount),
            base:Lerp(paletteColor(colors[2] or colors[1]), toAmount))
        gradient.Rotation = rotation or 0
        if type(see) == "table" then
            gradient.Transparency = NumberSequence.new(see[1], see[2] or see[1])
        end
        return true
    end
    local innerWatched = setmetatable({}, { __mode = "k" })
    function Interface.tintGroupbox(box, color)
        local instance = type(box) == "table" and box.Instance
        if not instance then
            return false
        end
        local c = paletteColor(color)
        local iconId = type(box.Values) == "table" and box.Values.Icon
        instance.Header.Icon.ImageColor3 = Interface.gameIconIds[iconId] and Color3.new(1, 1, 1) or c
        instance.Header.TextColor3 = c:Lerp(Color3.new(1, 1, 1), 0.45)
        local backdrop = instance.PART_Backdrop
        local stroke = backdrop:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = c
            stroke.Transparency = 0.55
        end
        local inner = backdrop.Inner
        inner.Size = UDim2.new(1, -2, 1, -2)
        if not innerWatched[inner] then
            innerWatched[inner] = true
            instance.PART_Content:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                task.defer(function()
                    inner.Size = UDim2.new(1, -2, 1, -2)
                end)
            end)
        end
        Interface.tintFrame(inner, { color, color }, 0.16, 0, 90)
        return true
    end
    Interface.DASHBOARD_LAYOUT = { leftWidth = 0.36, gap = 8, topHeight = 84 }
    local function findCard(holder, name)
        for _, side in ipairs(holder:GetChildren()) do
            local card = side:FindFirstChild(name)
            if card then
                return card
            end
        end
        return nil
    end
    function Interface.dashboardCards(homeTab)
        local cards = {}
        local page = homeTab.Instances.Page
        for _, name in ipairs({ "Holder", "AmeFarmHolder" }) do
            local holder = page:FindFirstChild(name)
            for _, side in ipairs(holder and holder:GetChildren() or {}) do
                if side:IsA("Frame") then
                    for _, card in ipairs(side:GetChildren()) do
                        if card:IsA("Frame") then
                            table.insert(cards, card)
                        end
                    end
                end
            end
        end
        return cards
    end
    Interface.CARD_TINT = { from = 0.34, to = 0.05, rotation = 35, see = { 0.22, 0.42 } }
    function Interface.paintDashboard(homeTab, overrides)
        local painted, other = 0, 0
        for _, card in ipairs(Interface.dashboardCards(homeTab)) do
            local colors = overrides and overrides[card] or Interface.DASHBOARD_COLORS[card.Name]
            if not colors then
                other += 1
                local name = DASHBOARD_ORDER[(other - 1) % #DASHBOARD_ORDER + 1]
                colors = { name, name }
            end
            local tint = Interface.CARD_TINT
            if Interface.tintFrame(card, colors, tint.from, tint.to, tint.rotation, tint.see) then
                painted += 1
            end
        end
        return painted
    end
    function Interface.findFarmCard(homeTab)
        local ok, found = pcall(function()
            for _, side in ipairs(homeTab.Instances.Page:FindFirstChild("Holder"):GetChildren()) do
                if side:IsA("Frame") then
                    for _, card in ipairs(side:GetChildren()) do
                        if card:IsA("Frame") and not Interface.DASHBOARD_KNOWN[card.Name] then
                            local words = { card.Name }
                            for _, item in ipairs(card:GetDescendants()) do
                                if item:IsA("TextLabel") then
                                    table.insert(words, tostring(item.Text))
                                end
                            end
                            local text = string.lower(table.concat(words, " "))
                            if string.find(text, "account", 1, true) or string.find(text, "coming soon", 1, true) then
                                return card
                            end
                        end
                    end
                end
            end
            return nil
        end)
        return ok and found or nil
    end
    function Interface.layoutDashboard(homeTab, farmCard)
        local page = homeTab.Instances.Page
        local done = page:FindFirstChild("AmeFarmHolder")
        if done then
            return done
        end
        local holder = page:FindFirstChild("Holder")
        if not holder then
            return nil
        end
        local discord, changelog, executor = findCard(holder, "Discord"), findCard(holder, "Changelog"), findCard(holder, "Executor")
        if not (discord and changelog and executor and farmCard) then
            return nil
        end
        local L = Interface.DASHBOARD_LAYOUT
        local box = Instance.new("Frame")
        box.Name = "AmeFarmHolder"
        box.BackgroundTransparency = 1
        box.BorderSizePixel = 0
        box.AnchorPoint = holder.AnchorPoint
        box.Position = holder.Position
        box.Size = holder.Size
        box.ZIndex = holder.ZIndex
        box.LayoutOrder = holder.LayoutOrder
        local function column(name, position, size)
            local frame = Instance.new("Frame")
            frame.Name = name
            frame.BackgroundTransparency = 1
            frame.BorderSizePixel = 0
            frame.Position = position
            frame.Size = size
            frame.ZIndex = holder.ZIndex
            local list = Instance.new("UIListLayout")
            list.FillDirection = Enum.FillDirection.Vertical
            list.SortOrder = Enum.SortOrder.LayoutOrder
            list.Padding = UDim.new(0, L.gap)
            list.Parent = frame
            frame.Parent = box
            return frame
        end
        local left = column("AmeFarmLeft", UDim2.new(0, 0, 0, 0), UDim2.new(L.leftWidth, -L.gap / 2, 1, 0))
        local right = column("AmeFarmRight", UDim2.new(L.leftWidth, L.gap / 2, 0, 0), UDim2.new(1 - L.leftWidth, -L.gap / 2, 1, 0))
        local top = UDim2.new(1, 0, 0, L.topHeight)
        local rest = UDim2.new(1, 0, 1, -(L.topHeight + L.gap))
        for _, entry in ipairs({ { discord, left, 1, top }, { changelog, left, 2, rest }, { executor, right, 1, top },
            { farmCard, right, 2, rest } }) do
            local card = entry[1]
            card.AnchorPoint = Vector2.new(0, 0)
            card.Position = UDim2.new(0, 0, 0, 0)
            card.Size = entry[4]
            card.LayoutOrder = entry[3]
            card.Parent = entry[2]
        end
        box.Parent = page
        holder.Visible = false
        return box
    end
    Interface.CARD_ROW_HEIGHT = 20
    local farmCardParts = setmetatable({}, { __mode = "k" })
    function Interface.makeFarmCard(card)
        if farmCardParts[card] then
            return farmCardParts[card]
        end
        local header = card:FindFirstChild("Header")
        if header then
            header.Text = T("Farm status")
        end
        for _, item in ipairs(card:GetDescendants()) do
            if item:IsA("TextLabel") and item ~= header and not (header and item:IsDescendantOf(header)) then
                item.Visible = false
            end
        end
        local top = 44
        pcall(function()
            local position, size, anchor = header.Position, header.Size, header.AnchorPoint
            if position.Y.Scale == 0 and size.Y.Scale == 0 then
                top = math.clamp(position.Y.Offset + (1 - anchor.Y) * size.Y.Offset + 10, 30, 70)
            end
        end)
        local zIndex = header and header.ZIndex or 5
        local function label(parent, name, position, size, textSize)
            local text = Instance.new("TextLabel")
            text.Name = name
            text.BackgroundTransparency = 1
            text.Position = position
            text.Size = size
            text.TextXAlignment = Enum.TextXAlignment.Left
            text.TextYAlignment = Enum.TextYAlignment.Center
            text.TextWrapped = false
            text.TextTruncate = Enum.TextTruncate.AtEnd
            text.RichText = true
            text.TextSize = textSize
            text.TextColor3 = Color3.fromRGB(240, 234, 250)
            text.ZIndex = zIndex
            pcall(function()
                text.FontFace = header.FontFace
            end)
            text.Text = ""
            text.Parent = parent
            return text
        end
        local function column(name, position, size)
            local frame = Instance.new("Frame")
            frame.Name = name
            frame.BackgroundTransparency = 1
            frame.BorderSizePixel = 0
            frame.Position = position
            frame.Size = size
            frame.ZIndex = zIndex
            local list = Instance.new("UIListLayout")
            list.FillDirection = Enum.FillDirection.Vertical
            list.SortOrder = Enum.SortOrder.LayoutOrder
            list.Padding = UDim.new(0, 2)
            list.Parent = frame
            frame.Parent = card
            return frame
        end
        local state = label(card, "AmeFarmLive", UDim2.new(0, 16, 0, top), UDim2.new(1, -32, 0, 20), 14)
        local facts = column("AmeFarmFacts", UDim2.new(0, 16, 0, top + 30), UDim2.new(0.5, -20, 1, -(top + 38)))
        local dots = column("AmeFarmDots", UDim2.new(0.5, 4, 0, top + 30), UDim2.new(0.5, -20, 1, -(top + 38)))
        local rows = {}
        for index, row in ipairs(Interface.statusRows(nil, 30)) do
            local line = Instance.new("Frame")
            line.Name = "Row_" .. row.key
            line.BackgroundTransparency = 1
            line.BorderSizePixel = 0
            line.LayoutOrder = index
            line.Size = UDim2.new(1, 0, 0, Interface.CARD_ROW_HEIGHT)
            line.ZIndex = zIndex
            local icon = Instance.new("ImageLabel")
            icon.Name = "Icon"
            icon.BackgroundTransparency = 1
            icon.AnchorPoint = Vector2.new(0, 0.5)
            icon.Position = UDim2.new(0, 0, 0.5, 0)
            icon.Size = UDim2.new(0, 16, 0, 16)
            icon.ScaleType = Enum.ScaleType.Fit
            icon.ZIndex = zIndex
            icon.Parent = line
            local offset = 22
            local text = label(line, "Text", UDim2.new(0, offset, 0, 0), UDim2.new(1, -offset, 1, 0), 13)
            line.Parent = row.dot and dots or facts
            rows[row.key] = { text = text, icon = icon, color = Interface.ROW_COLORS[row.key] or "moon", lucide = row.icon,
                game = row.game, dot = row.dot }
        end
        local parts = { state = state, rows = rows }
        farmCardParts[card] = parts
        return parts
    end
    Interface.ROW_COLORS = { last = "pumpkin", pet = "candy", session = "teal", bucks = "slime", candy = "candy",
        tasks = "moon", doing = "pumpkin", needs = "slime", ghost = "ghost", pen = "green", off = "blood" }
    local function escapeRich(text)
        return (string.gsub(tostring(text), "[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }))
    end
    function Interface.farmCardRows(status, width)
        width = width or 30
        local s = type(status) == "table" and status or {}
        local title, _, state = Interface.stateHeader(s)
        local line = title .. (tonumber(s.featuresOn) and (" • " .. T("%d/%d features on", s.featuresOn,
            tonumber(s.featuresTotal) or 0)) or "") .. (s.preset and (" • " .. Lang.tr(tostring(s.preset))) or "")
        local rows = {}
        for _, row in ipairs(Interface.statusRows(s, width)) do
            local text = escapeRich(row.text)
            local name, value = string.match(text, "^(.-:)(.*)$")
            table.insert(rows, { key = row.key, dot = row.dot == true, icon = row.icon, state = row.state,
                text = name and string.format('<font color="%s"><b>%s</b></font>%s', hexColor(Interface.ROW_COLORS[row.key]
                    or "moon"), name, value) or text })
        end
        return string.format('<font color="%s">●</font>  <b>%s</b>', hexColor(Interface.STATE_COLORS[state] or "gray"),
            escapeRich(fit(line, width * 2))), rows, state
    end
    function Interface.fillFarmCard(parts, status, icons)
        local state, rows = Interface.farmCardRows(status, 30)
        parts.state.Text = state
        for _, row in ipairs(rows) do
            local slot = parts.rows[row.key]
            if slot then
                slot.text.Text = row.text
                if slot.icon then
                    local picture = not row.dot and type(icons) == "table" and type(icons[row.key]) == "string" and icons[row.key]
                        or nil
                    local own = ICON_IDS[slot.lucide]
                    slot.icon.Image = picture or (own and ("rbxassetid://" .. own) or "")
                    local color = row.dot and (Interface.STATE_COLORS[row.state] or "gray") or slot.color
                    slot.icon.ImageColor3 = picture and Color3.new(1, 1, 1) or paletteColor(color)
                end
            end
        end
    end
    Interface.SERVER_CHIPS = {
        { key = "players", color = "slime", icon = "users" }, { key = "latency", color = "teal", icon = "wifi" },
        { key = "region", color = "moon", icon = "globe" }, { key = "uptime", color = "witch", icon = "timer" },
        { key = "join", color = "pumpkin", button = true, icon = "copy" },
    }
    function Interface.serverStrip(homeTab)
        local page = homeTab.Instances.Page
        local anchor = page:FindFirstChild("playerUser")
        if not anchor or page:FindFirstChild("AmeFarmServer") then
            return nil
        end
        local position, size, point = anchor.Position, anchor.Size, anchor.AnchorPoint
        local strip = Instance.new("Frame")
        strip.Name = "AmeFarmServer"
        strip.BackgroundTransparency = 1
        strip.BorderSizePixel = 0
        strip.AnchorPoint = Vector2.new(0, 0)
        strip.Position = UDim2.new(position.X.Scale - point.X * size.X.Scale, position.X.Offset - point.X * size.X.Offset,
            position.Y.Scale + (1 - point.Y) * size.Y.Scale, position.Y.Offset + (1 - point.Y) * size.Y.Offset + 6)
        strip.Size = UDim2.new(0, 620, 0, 22)
        strip.ZIndex = anchor.ZIndex
        local list = Instance.new("UIListLayout")
        list.FillDirection = Enum.FillDirection.Horizontal
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.VerticalAlignment = Enum.VerticalAlignment.Center
        list.Padding = UDim.new(0, 12)
        list.Parent = strip
        local chips = {}
        for index, chip in ipairs(Interface.SERVER_CHIPS) do
            local holder = Instance.new(chip.button and "TextButton" or "Frame")
            if chip.button then
                holder.Text = ""
                holder.AutoButtonColor = true
                chips[chip.key .. "Button"] = holder
            end
            holder.Name = "AmeFarm_" .. chip.key
            holder.LayoutOrder = index
            holder.AutomaticSize = Enum.AutomaticSize.X
            holder.Size = UDim2.new(0, 0, 1, 0)
            holder.BackgroundTransparency = 1
            holder.BorderSizePixel = 0
            holder.ZIndex = anchor.ZIndex
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = holder
            local padding = Instance.new("UIPadding")
            padding.PaddingLeft = UDim.new(0, 0)
            padding.PaddingRight = UDim.new(0, 6)
            padding.Parent = holder
            local row = Instance.new("UIListLayout")
            row.FillDirection = Enum.FillDirection.Horizontal
            row.SortOrder = Enum.SortOrder.LayoutOrder
            row.VerticalAlignment = Enum.VerticalAlignment.Center
            row.Padding = UDim.new(0, 5)
            row.Parent = holder
            local icon = Instance.new("ImageLabel")
            icon.Name = "Icon"
            icon.BackgroundTransparency = 1
            icon.Size = UDim2.new(0, 14, 0, 14)
            icon.LayoutOrder = 1
            icon.ScaleType = Enum.ScaleType.Fit
            icon.Image = ICON_IDS[chip.icon] and ("rbxassetid://" .. ICON_IDS[chip.icon]) or ""
            icon.ImageColor3 = paletteColor(chip.color):Lerp(Color3.new(1, 1, 1), 0.15)
            icon.ZIndex = anchor.ZIndex
            icon.Parent = holder
            local label = Instance.new("TextLabel")
            label.Name = "Text"
            label.LayoutOrder = 2
            label.AutomaticSize = Enum.AutomaticSize.X
            label.Size = UDim2.new(0, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.TextColor3 = Color3.fromRGB(226, 220, 236)
            label.TextSize = 12
            label.ZIndex = anchor.ZIndex
            label.Text = ""
            pcall(function()
                label.FontFace = anchor.FontFace
            end)
            label.Parent = holder
            holder.Parent = strip
            chips[chip.key] = label
        end
        strip.Parent = page
        return chips, strip
    end
    local function duration(seconds)
        seconds = math.max(0, math.floor(tonumber(seconds) or 0))
        if seconds >= 3600 then
            return string.format("%dh %dm", seconds // 3600, (seconds % 3600) // 60)
        elseif seconds >= 60 then
            return string.format("%dm", seconds // 60)
        end
        return seconds .. "s"
    end
    function Interface.serverChipTexts(info)
        local i = type(info) == "table" and info or {}
        return {
            players = T("%s/%s players", tostring(i.players or "?"), tostring(i.maxPlayers or "?")),
            latency = T("%s FPS • %s ms", tostring(i.fps or "?"), tostring(i.ping or "?")),
            region = (Lang.flag(i.region) ~= "" and (Lang.flag(i.region) .. " ") or "") .. tostring(i.region or "?"),
            uptime = T("server %s", i.uptime and duration(i.uptime) or "?"),
            join = T("Join script"),
        }
    end
    function Interface.clearStrip(strip, box)
        local overlap = strip.AbsolutePosition.Y + strip.AbsoluteSize.Y + 6 - box.AbsolutePosition.Y
        if overlap > 0 and overlap < 80 then
            local a = box.AnchorPoint.Y
            box.Position = box.Position + UDim2.new(0, 0, 0, (1 - a) * overlap)
            box.Size = box.Size - UDim2.new(0, 0, 0, overlap)
            return overlap
        end
        return 0
    end
    Interface.SAVE_PATH = "AdoptMeFarm/window_settings.txt"
    Interface.NOT_SAVED = {}
    Interface.SAVED_OTHERS = { ["Interface.Toasts"] = true, ["Interface.Theme"] = true, ["Interface.Descriptions"] = true,
        ["Interface.Keybind"] = true, ["Telemetry.Enabled"] = true, ["Telemetry.IncludeInventory"] = true,
        ["Logging.ConsoleLevel"] = true, ["Notifications.SendOnStartStop"] = true, ["Notifications.SendOnTaskComplete"] = true,
        ["Notifications.SendOnError"] = true, ["Notifications.SendOnKick"] = true, ["Notifications.IncludeUsername"] = true,
        ["Notifications.Enabled"] = true, ["Notifications.Webhooks.Summary"] = true, ["Notifications.Webhooks.Alerts"] = true,
        ["Notifications.PingDiscordUserId"] = true, ["Notifications.Ping"] = true, ["Notifications.SendSummary"] = true,
        ["Notifications.SummaryIntervalMinutes"] = true,
        ["Interface.RememberSettings"] = true, ["Interface.Autoload"] = true, ["Interface.StartHidden"] = true,
        ["Interface.Language"] = true, ["Interface.UIScale"] = true }
    Interface.META_KEYS = { ["Interface.RememberSettings"] = true, ["Interface.Autoload"] = true }
    Interface.PRIVATE_KEYS = { ["Notifications.Webhooks.Summary"] = true, ["Notifications.Webhooks.Alerts"] = true,
        ["Notifications.PingDiscordUserId"] = true, ["Notifications.Enabled"] = true }
    Interface.CONFIG_FOLDER = "AdoptMeFarm/configs"
    Interface.CONFIG_EXTENSION = ".cfg"
    for _, flag in ipairs(Interface.PING_FLAGS) do
        Interface.SAVED_OTHERS["Notifications.PingOn." .. flag] = true
    end
    Interface.saved = { changes = {}, originals = {} }
    function Interface.resolve(root, path)
        local node = root
        for index = 1, #path - 1 do
            if type(node) ~= "table" then
                return nil
            end
            local segment = path[index]
            local child = node[segment]
            if child == nil and type(segment) == "string" and node[1] ~= nil then
                for _, entry in ipairs(node) do
                    if type(entry) == "table" and entry.id == segment then
                        child = entry
                        break
                    end
                end
            end
            node = child
        end
        if type(node) ~= "table" then
            return nil
        end
        return node, path[#path]
    end
    local function splitPath(key)
        return string.split(key, ".")
    end
    function Interface.canSave(key)
        if type(key) ~= "string" or Interface.NOT_SAVED[key] then
            return false
        end
        return string.sub(key, 1, 5) == "Farm." or Interface.SAVED_OTHERS[key] == true
    end
    function Interface.encodeSaved(changes, header)
        local keys = {}
        for key in pairs(changes) do
            table.insert(keys, key)
        end
        table.sort(keys)
        local lines = header or {
            "# AdoptMe Farm: the settings you changed in the window. Applied at every start, over the loader's settings.",
            "# To forget them: Config > Settings > Reset to loader settings (or delete this file).",
        }
        for _, key in ipairs(keys) do
            local value = changes[key]
            local kind, text
            if type(value) == "boolean" then
                kind, text = "bool", tostring(value)
            elseif type(value) == "number" then
                kind, text = "number", tostring(value)
            elseif type(value) == "string" then
                kind, text = "text", value
            elseif isStringList(value) then
                kind, text = "list", table.concat(value, ",")
            end
            if kind and Interface.canSave(key) and not string.find(text, "[\t\r\n]") then
                table.insert(lines, key .. "\t" .. kind .. "\t" .. text)
            end
        end
        return table.concat(lines, "\n") .. "\n"
    end
    function Interface.decodeSaved(text)
        local changes = {}
        for line in string.gmatch(tostring(text or ""), "[^\r\n]+") do
            local key, kind, raw = string.match(line, "^([%w_%.]+)\t(%a+)\t(.*)$")
            local value
            if kind == "bool" then
                if raw == "true" then
                    value = true
                elseif raw == "false" then
                    value = false
                end
            elseif kind == "number" then
                value = tonumber(raw)
                if value and (value ~= value or math.abs(value) > 1e9) then
                    value = nil
                end
            elseif kind == "text" then
                value = #raw <= 200 and raw or nil
            elseif kind == "list" then
                value = {}
                for item in string.gmatch(raw, "[^,]+") do
                    table.insert(value, item)
                end
                if #value > 40 then
                    value = nil
                end
            end
            if key and value ~= nil then
                changes[key] = value
            end
        end
        return changes
    end
    local function applyValues(config, values, saved)
        local applied, skipped = 0, 0
        for key, value in pairs(values) do
            local fits = false
            if Interface.canSave(key) then
                local tbl, leaf = Interface.resolve(config, splitPath(key))
                if type(tbl) == "table" then
                    local current = tbl[leaf]
                    if type(value) == "table" then
                        fits = isStringList(current) and isStringList(value)
                    else
                        fits = current ~= nil and type(current) == type(value)
                    end
                    if fits then
                        if saved.originals[key] == nil then
                            saved.originals[key] = deepCopy(current)
                        end
                        saved.changes[key] = deepCopy(value)
                        tbl[leaf] = deepCopy(value)
                    end
                end
            end
            if fits then
                applied += 1
            else
                skipped += 1
            end
        end
        return applied, skipped
    end
    function Interface.applySaved(config, logger)
        local saved = { changes = {}, originals = {} }
        Interface.saved = saved
        local okRead, text = pcall(function()
            return isfile(Interface.SAVE_PATH) and readfile(Interface.SAVE_PATH) or nil
        end)
        local applied, skipped = 0, 0
        if okRead and type(text) == "string" then
            applied, skipped = applyValues(config, Interface.decodeSaved(text), saved)
            if logger and (applied > 0 or skipped > 0) then
                logger:info("Interface", string.format("Your window settings: %d applied over the loader's%s (%s)", applied,
                    skipped > 0 and string.format(", %d skipped (not a setting of this version)", skipped) or "",
                    Interface.SAVE_PATH))
            end
        end
        local autoload = config.Interface and config.Interface.Autoload
        if type(autoload) == "string" and autoload ~= "" then
            local values = Interface.readConfig(autoload)
            if values then
                local count = applyValues(config, values, saved)
                applied += count
                if logger then
                    logger:info("Interface", string.format("Autoload: config '%s' (%d settings)", autoload, count))
                end
            elseif logger then
                logger:warn("Interface", "Autoload: no config called '" .. autoload .. "' (Config tab)")
            end
        end
        return applied
    end
    function Interface.writeSaved(changes, rememberAll)
        local keep = changes
        if rememberAll == false then
            keep = {}
            for key, value in pairs(changes) do
                if Interface.META_KEYS[key] then
                    keep[key] = value
                end
            end
        end
        return pcall(function()
            if isfolder and makefolder and not isfolder("AdoptMeFarm") then
                makefolder("AdoptMeFarm")
            end
            writefile(Interface.SAVE_PATH, Interface.encodeSaved(keep))
        end)
    end
    function Interface.configName(text)
        local name = string.match(tostring(text or ""), "^%s*(.-)%s*$")
        name = string.gsub(name, "[^%w _%-]", "")
        return string.sub(name, 1, 30)
    end
    function Interface.configPath(name)
        return Interface.CONFIG_FOLDER .. "/" .. name .. Interface.CONFIG_EXTENSION
    end
    function Interface.listConfigs()
        local names = {}
        pcall(function()
            for _, file in ipairs(listfiles(Interface.CONFIG_FOLDER)) do
                local name = string.match(tostring(file), "([^/\\]+)%.cfg$")
                if name then
                    table.insert(names, name)
                end
            end
        end)
        table.sort(names)
        return names
    end
    function Interface.writeConfig(name, values)
        name = Interface.configName(name)
        if name == "" then
            return false, "Type a name first"
        end
        local keep = {}
        for key, value in pairs(values) do
            if Interface.canSave(key) and not Interface.PRIVATE_KEYS[key] and not Interface.META_KEYS[key] then
                keep[key] = value
            end
        end
        local ok, err = pcall(function()
            for _, folder in ipairs({ "AdoptMeFarm", Interface.CONFIG_FOLDER }) do
                if isfolder and makefolder and not isfolder(folder) then
                    makefolder(folder)
                end
            end
            writefile(Interface.configPath(name), Interface.encodeSaved(keep, {
                "# AdoptMe Farm config '" .. name .. "' (Config tab: Load / Overwrite / Delete).",
            }))
        end)
        return ok, ok and name or tostring(err)
    end
    function Interface.readConfig(name)
        name = Interface.configName(name)
        local ok, text = pcall(function()
            return isfile(Interface.configPath(name)) and readfile(Interface.configPath(name)) or nil
        end)
        if not ok or type(text) ~= "string" then
            return nil
        end
        return Interface.decodeSaved(text)
    end
    function Interface.deleteConfig(name)
        name = Interface.configName(name)
        return pcall(function()
            delfile(Interface.configPath(name))
        end)
    end
    local function countKeys(map)
        local count = 0
        for _ in pairs(map) do
            count += 1
        end
        return count
    end
    function Interface.stateHeader(status)
        local s = type(status) == "table" and status or {}
        local on, total = tonumber(s.featuresOn), tonumber(s.featuresTotal)
        local features = on and T("%d of %d features on", on, total or 0) or nil
        local preset = s.preset and (" • " .. T("preset %s", Lang.tr(tostring(s.preset)))) or ""
        if s.stopped then
            return T("FARM: STOPPED"), T("Everything stopped. Run the loader again to start."), "bad"
        elseif not s.farmEnabled then
            if on == 0 then
                return T("FARM: OFF"), T("Nothing is on yet: switch features on (Main / Event) or pick a preset (Config), "
                    .. "then switch Farm running on."), "off"
            end
            return T("FARM: OFF"), T("Paused: no game actions.") .. (features and (" " .. features .. preset .. ".") or "")
                .. " " .. T("Switch Farm running on to start."), "off"
        elseif not s.ready then
            return T("FARM: ON"), T("Waiting for the game to load...") .. (features and (" " .. features) or ""), "wait"
        elseif on == 0 then
            return T("FARM: ON"), T("Running, but no feature is on: pick a preset or switch features on."), "wait"
        end
        return T("FARM: ON"), T("Running") .. (features and (" • " .. features) or "") .. preset, "on"
    end
    Interface.STATE_COLORS = { on = "green", wait = "moon", bad = "blood", off = "gray" }
    function Interface.statusRows(status, width)
        local s = type(status) == "table" and status or {}
        local running = not s.stopped and s.farmEnabled
        local function word(id)
            return Lang.tr((string.gsub(tostring(id), "_", " ")))
        end
        local task = tostring(s.task or "none")
        local doing, doingState
        if not running then
            doing, doingState = T(s.stopped and "Doing: nothing (stopped)" or "Doing: nothing (paused)"), "off"
        elseif task == "none" then
            doing, doingState = T("Doing: nothing to do right now"), "wait"
        else
            doing, doingState = T("Doing: %s", word(task)), "on"
        end
        if s.sideTask and running then
            doing = doing .. " + " .. Lang.tr(tostring(s.sideTask))
        end
        local pets = {}
        for _, pet in ipairs(type(s.pets) == "table" and s.pets or {}) do
            table.insert(pets, T("%s (age %s)", prettyKind(pet.kind), tostring(pet.age or "?")))
        end
        local needs = {}
        for _, need in ipairs(type(s.needs) == "table" and s.needs or {}) do
            local name = word(need.kind)
            table.insert(needs, (need.owner == "baby" and T("baby %s", name) or name) .. (need.inProgress and " ●" or ""))
        end
        local function needsLine(count)
            local rest = #needs - count
            return T("Needs: %s", table.concat(needs, ", ", 1, count) .. (rest > 0 and (" +" .. rest) or ""))
        end
        local count = math.min(#needs, 4)
        while count > 1 and (utf8.len(needsLine(count)) or 0) > (width or 64) do
            count -= 1
        end
        local needsText = #needs > 0 and needsLine(count) or T("Needs: none")
        local ghost, ghostState
        if s.ghostEnabled == false then
            ghost, ghostState = T("Ghost Gallery: off"), "off"
        elseif s.nextRoundIn then
            ghost, ghostState = T("Ghost Gallery: in %s", clock(s.nextRoundIn)), "on"
        else
            ghost, ghostState = T("Ghost Gallery: waiting"), "wait"
        end
        local penText, penState
        local pen = type(s.pen) == "table" and s.pen or nil
        if s.petPenEnabled == false then
            penText, penState = T("Pet Pen: off"), "off"
        elseif pen and pen.known then
            local pets, slots = tonumber(pen.pets) or 0, tonumber(pen.slots) or 4
            if (tonumber(pen.nextClaimIn) or 0) > 0 then
                penText = T("Pet Pen: %d/%d • claim %s", pets, slots, clock(pen.nextClaimIn))
            else
                penText = T("Pet Pen: %d/%d • claim now", pets, slots)
            end
            penState = "on"
        else
            penText, penState = T("Pet Pen: no data yet"), "wait"
        end
        local off = {}
        for _, key in ipairs(type(s.disabled) == "table" and s.disabled or {}) do
            local minutes = type(s.restMinutes) == "table" and s.restMinutes[key]
            table.insert(off, minutes and T("%s (%d min)", word(key), minutes) or word(key))
        end
        local rows = {
            { key = "last", icon = "history", text = T("Last done: %s", s.lastTask and word(s.lastTask) or T("nothing yet")) },
            { key = "pet", icon = "paw-print", text = T("Pet: %s", #pets > 0 and table.concat(pets, ", ") or T("none equipped")) },
            { key = "session", icon = "timer", text = T("Session: %d min • %s needs", s.minutes or 0, commas(s.needsDone or 0)) },
            { key = "bucks", icon = "banknote", game = "game:bucks",
                text = T("Bucks: %s (+%s)", commas(s.bucks), commas(s.bucksEarned or 0)) },
            { key = "candy", icon = "candy", game = "game:candy",
                text = T("Candy: %s (+%s)", commas(s.candy), commas(s.candyEarned or 0)) },
            { key = "tasks", icon = "badge-check", text = T("Tasks: %s done • %s failed", commas(s.tasksSucceeded or 0),
                commas(s.tasksFailed or 0)) },
            { key = "doing", icon = "zap", text = doing, dot = true, state = doingState },
            { key = "needs", icon = "list-checks", text = needsText, dot = true, state = #needs > 0 and "wait" or "on" },
            { key = "ghost", icon = "ghost", text = ghost, dot = true, state = ghostState },
            { key = "pen", icon = "fence", text = penText, dot = true, state = penState },
            { key = "off", icon = "circle-pause", dot = true, state = #off > 0 and "bad" or "on",
                text = #off > 0 and T("Resting: %s", table.concat(off, ", ")) or T("Resting: none") },
        }
        for _, row in ipairs(rows) do
            row.text = fit(row.text, width or 64)
        end
        return rows
    end
    local FEED_INFO = { Event = true, Minigame = true }
    local FEED_MARK = { SUCCESS = "✅", WARN = "⚠️", ERROR = "❌" }
    Interface.FEED_LINES = 8
    function Interface.activityLine(level, category, message, stamp)
        level, category, message = tostring(level), tostring(category), tostring(message)
        if level == "DEBUG" or category == "Disclosure" or category == "Status" then
            return nil
        end
        if level == "INFO" and not FEED_INFO[category] and not (category == "Tasks" and string.find(message, "^Start: ")) then
            return nil
        end
        message = string.gsub(message, "halloween_2026_", "")
        message = string.gsub(message, "_", " ")
        return (stamp and (stamp .. "  ") or "") .. (FEED_MARK[level] or "•") .. " " .. fit(message, 90)
    end
    Interface.HIDDEN = {
        ["Farm.Tasks"] = "one Auto needs switch + a pick list of needs to skip",
        ["Farm.MultiNeed"] = "always on: it only works while a place need waits",
        ["Farm.BuyWater"] = "always on: 1 item, only when a need has nothing to use",
        ["Farm.BuyFood"] = "always on: 1 item, only when a need has nothing to use",
        ["Farm.MaxBuysPerSession"] = "no limit (1 item at a time, only when needed)",
        ["Farm.Priority"] = "the farm orders needs itself (short ones first, the ones doable here first)",
        ["Farm.SkipFullGrown"] = "part of Auto pet",
        ["Farm.AutoPotions.PetKinds"] = "Use potions = on the farmed growing pet",
        ["Farm.AutoPotions.Potions"] = "the farming potions; the window's 'Don't use' list picks from it",
        ["Farm.AutoNeon.Exclude"] = "Auto neon fuses every kind",
        ["Farm.AutoOpen.Exclude"] = "Open gifts opens every gift / chest",
        ["Farm.Event.Enabled"] = "every event job has its own switch",
        ["Farm.Event.MummySpider"] = "part of Crypt > Next floor",
        ["Farm.Event.GhostJoinByZone"] = "the safe way to join (like the popup's Yes)",
        ["Farm.Event.AutoNest"] = "Crypt > Open > Twig + Give twigs to the nest",
        ["Farm.Event.PetPenSlots"] = "4 slots (5 with the extra-slot pass: set it in the loader)",
        ["Farm.Event.PetPenStockMinBucks"] = "a reserve of 750 Bucks is kept",
        ["Farm.Event.CandyPets.KeepCandy"] = "the Candy Shop buys all it can",
        ["Farm.Event.CandyPets.Buy"] = "the Candy Shop has no limit (pick the pets)",
        ["Farm.MaxEggBuysPerSession"] = "no limit (1 egg only when nothing grows)",
        ["Farm.HouseDoorExit"] = "experimental, never worked live",
        ["Farm.CashbackMinutes"] = "every 10 minutes",
        ["Farm.FastTravel"] = "not read by the program",
        ["Farm.PetMeFocusSeconds"] = "not read by the program",
    }
    local TEXT_FIELDS = { "Name", "Tooltip", "Content", "Title", "Description", "Subtitle", "PlaceholderText", "Placeholder" }
    local function localizeFields(fields)
        if type(fields) == "table" then
            for _, field in ipairs(TEXT_FIELDS) do
                if type(fields[field]) == "string" then
                    fields[field] = Lang.tr(fields[field])
                end
            end
        end
        return fields
    end
    Interface.localizeFields = localizeFields
    local function wrapMethod(object, name, before, after)
        local original = type(object) == "table" and rawget(object, name) or nil
        if type(original) ~= "function" then
            local ok, found = pcall(function()
                return object[name]
            end)
            original = ok and type(found) == "function" and found or nil
        end
        if not original then
            return
        end
        object[name] = function(self, first, ...)
            if before then
                first = before(first)
            end
            local result = original(self, first, ...)
            if after then
                result = after(result)
            end
            return result
        end
    end
    local function localizeElement(element)
        if type(element) == "table" then
            wrapMethod(element, "Set", localizeFields)
            wrapMethod(element, "AddDropdown", function(nested)
                if type(nested) == "table" and type(nested.Placeholder) == "string" then
                    nested.Placeholder = Lang.tr(nested.Placeholder)
                end
                return nested
            end)
        end
        return element
    end
    local function localizeGroupbox(box)
        if type(box) == "table" then
            for _, name in ipairs({ "CreateToggle", "CreateSlider", "CreateButton", "CreateInput", "CreateLabel", "CreateParagraph" }) do
                wrapMethod(box, name, localizeFields, localizeElement)
            end
        end
        return box
    end
    local function localizeTab(tab)
        if type(tab) == "table" then
            wrapMethod(tab, "CreateGroupbox", localizeFields, localizeGroupbox)
        end
        return tab
    end
    local function localizeSection(section)
        if type(section) == "table" then
            wrapMethod(section, "CreateTab", localizeFields, localizeTab)
        end
        return section
    end
    function Interface.localize(library)
        if Lang.current == "en" or type(library) ~= "table" then
            return false
        end
        wrapMethod(library, "Notification", localizeFields)
        wrapMethod(library, "CreateWindow", localizeFields, function(window)
            if type(window) == "table" then
                wrapMethod(window, "CreateTabSection", function(name)
                    return type(name) == "string" and Lang.tr(name) or name
                end, localizeSection)
                wrapMethod(window, "PromptDialog", function(dialog)
                    localizeFields(dialog)
                    if type(dialog) == "table" and type(dialog.Actions) == "table" then
                        for _, action in pairs(dialog.Actions) do
                            localizeFields(action)
                        end
                    end
                    return dialog
                end)
                wrapMethod(window, "CreateHomeTab", function(home)
                    if type(home) == "table" and type(home.Changelog) == "table" then
                        for _, entry in ipairs(home.Changelog) do
                            localizeFields(entry)
                        end
                    end
                    return home
                end)
            end
            return window
        end)
        return true
    end
    function Interface.localizeTree(root, keepWatching, connections)
        if Lang.current == "en" or not root then
            return 0
        end
        local count = 0
        local function apply(label)
            local translated = Lang.tr(label.Text)
            if translated ~= label.Text then
                label.Text = translated
                count += 1
            end
        end
        for _, item in ipairs(root:GetDescendants()) do
            if item:IsA("TextLabel") or item:IsA("TextButton") then
                pcall(apply, item)
                if keepWatching and keepWatching[item.Name] and connections then
                    table.insert(connections, item:GetPropertyChangedSignal("Text"):Connect(function()
                        pcall(apply, item)
                    end))
                end
            end
        end
        return count
    end
    Interface.PC_SIZE = { 980, 600 }
    Interface.UI_SCALES = { "Auto", "0.5", "0.6", "0.7", "0.8", "0.9", "1", "1.1", "1.25" }
    function Interface.scaleFor(setting, touch, viewport)
        local chosen = tonumber(setting)
        if chosen then
            return math.clamp(chosen, 0.5, 1.25)
        end
        if not touch or not viewport then
            return 1
        end
        local fit = math.min((viewport.X - 40) / Interface.PC_SIZE[1], (viewport.Y - 70) / Interface.PC_SIZE[2])
        return math.clamp(math.floor(fit * 100) / 100, 0.4, 1)
    end
    function Interface.lookupCountry()
        if Interface.country then
            return Interface.country
        end
        local ok, country = pcall(function()
            local Players = game:GetService("Players")
            return game:GetService("LocalizationService"):GetCountryRegionForPlayerAsync(Players.LocalPlayer)
        end)
        if ok and type(country) == "string" and country ~= "" then
            Interface.country = country
        end
        return Interface.country
    end
    function Interface.start(api, options)
        options = options or {}
        assert(type(api) == "table" and type(api.Config) == "table", "Interface: the farm's control API is missing")
        if Interface.current then
            pcall(Interface.current.Close)
            Interface.current = nil
        end
        local config = api.Config
        local settings = config.Interface or options.settings or {}
        local farm = config.Farm
        local event = farm.Event or {}
        local load = options.loadLibrary or function()
            return loadstring(game:HttpGet(Interface.LIBRARY_URL))()
        end
        local okLoad, Starlight = pcall(load)
        if not okLoad or type(Starlight) ~= "table" then
            error("the Starlight UI library could not be loaded (" .. tostring(Starlight) .. ")", 0)
        end
        Interface.gameIcon = type(api.GameIcon) == "function" and api.GameIcon or nil
        local locale
        pcall(function()
            locale = game:GetService("LocalizationService").RobloxLocaleId
        end)
        local country = Interface.lookupCountry()
        Lang.use(Lang.pick(settings.Language, country, locale))
        pcall(Interface.localize, Starlight)
        local touch = options.touch
        if touch == nil then
            local okTouch, isTouch = pcall(function()
                return game:GetService("UserInputService").TouchEnabled
            end)
            touch = okTouch and isTouch == true
        end
        local viewport = options.viewport
        if viewport == nil then
            pcall(function()
                viewport = workspace.CurrentCamera.ViewportSize
            end)
        end
        local hasViewport = viewport ~= nil and tonumber(viewport.X) ~= nil and tonumber(viewport.Y) ~= nil
        local scale = Interface.scaleFor(settings.UIScale, touch, hasViewport and viewport or nil)
        local wide = not touch or scale < 1
        local columns = wide and 2 or 1
        local function col(n)
            return wide and n or 1
        end
        local rowWidth = wide and 40 or 64
        local aboutWidth = wide and 46 or 64
        local showDescriptions = settings.Descriptions ~= false
        local catalog = { petKinds = {}, giftIds = {} }
        if type(api.Catalog) == "function" then
            local okCatalog, result = pcall(api.Catalog)
            if okCatalog and type(result) == "table" then
                catalog.petKinds = type(result.petKinds) == "table" and result.petKinds or {}
                catalog.giftIds = type(result.giftIds) == "table" and result.giftIds or {}
            end
        end
        local alive = true
        local connections = {}
        local handle = { touch = touch }
        function handle.Close()
            if not alive then
                return
            end
            alive = false
            for _, connection in ipairs(connections) do
                pcall(function()
                    connection:Disconnect()
                end)
            end
            pcall(function()
                Starlight:Destroy()
            end)
        end
        local function notify(title, content, icon)
            pcall(function()
                Starlight:Notification({ Title = title, Content = content, Icon = I(icon or "info"), Duration = 4 })
            end)
        end
        local function copy(title, text)
            local copied = pcall(function()
                setclipboard(text)
            end)
            notify(title, copied and ("Copied: " .. text) or text, "copy")
        end
        local refreshers = {}
        local quiet = false
        handle.bound = {}
        local function remember(key, refresh)
            table.insert(refreshers, { key = key, refresh = refresh })
            handle.bound[key] = true
        end
        local function refresh(onlyKey)
            local wasQuiet = quiet
            quiet = true
            for _, entry in ipairs(refreshers) do
                if onlyKey == nil or entry.key == onlyKey then
                    pcall(entry.refresh)
                end
            end
            quiet = wasQuiet
        end
        local function read(path)
            local tbl, key = Interface.resolve(config, path)
            if type(tbl) == "table" then
                return tbl[key]
            end
            return nil
        end
        local savedInfo
        local savePending = false
        local function updateSavedInfo()
            if not savedInfo then
                return
            end
            local text
            if settings.RememberSettings == false then
                text = "Autosave off: save a config instead"
            else
                local count = countKeys(Interface.saved.changes)
                text = count == 0 and "Autosave: on (this device)" or T("Autosave: %d change(s) kept", count)
            end
            pcall(function()
                savedInfo:Set({ Name = text })
            end)
        end
        local function noteChange(key, value, before)
            if quiet or not Interface.canSave(key) then
                return
            end
            if settings.RememberSettings == false and not Interface.META_KEYS[key] then
                return
            end
            local saved = Interface.saved
            if saved.originals[key] == nil then
                saved.originals[key] = deepCopy(before)
            end
            if sameValue(value, saved.originals[key]) then
                saved.changes[key], saved.originals[key] = nil, nil
            else
                saved.changes[key] = deepCopy(value)
            end
            updateSavedInfo()
            if not savePending then
                savePending = true
                task.delay(1, function()
                    savePending = false
                    Interface.writeSaved(Interface.saved.changes, settings.RememberSettings ~= false)
                end)
            end
        end
        local function write(path, value)
            local tbl, key = Interface.resolve(config, path)
            if type(tbl) ~= "table" then
                return
            end
            local before = tbl[key]
            if sameValue(before, value) then
                return
            end
            tbl[key] = value
            local fullKey = table.concat(path, ".")
            noteChange(fullKey, value, before)
            refresh(fullKey)
        end
        local function about(path, text)
            return text or Interface.DESCRIPTIONS[table.concat(path, ".")]
        end
        local function describe(box, index, text)
            if showDescriptions and type(text) == "string" and text ~= "" then
                box:CreateLabel({ Name = fit(Lang.tr(text), aboutWidth), Icon = I("info") }, index .. "_about")
            end
        end
        local function bindToggle(box, index, icon, name, path, tooltip)
            if type(read(path)) ~= "boolean" then
                return nil
            end
            local text = about(path, tooltip)
            local element = box:CreateToggle({
                Name = name,
                Icon = I(icon),
                Tooltip = text,
                CurrentValue = read(path),
                Style = 2,
                Callback = function(value)
                    write(path, value == true)
                end,
            }, index)
            describe(box, index, text)
            remember(table.concat(path, "."), function()
                if element.Values.CurrentValue ~= read(path) then
                    element:Set({ CurrentValue = read(path) })
                end
            end)
            return element
        end
        local function bindSlider(box, index, icon, name, path, min, max, step, suffix, tooltip, scale)
            scale = scale or 1
            if type(read(path)) ~= "number" then
                return nil
            end
            local function shown()
                return math.clamp((tonumber(read(path)) or min * scale) / scale, min, max)
            end
            local text = about(path, tooltip)
            local element = box:CreateSlider({
                Name = name,
                Icon = I(icon),
                Tooltip = (text and (Lang.tr(text) .. ". ") or "") .. T("Drag, or tap the number to type a value."),
                Range = { min, max },
                Increment = step,
                Suffix = suffix,
                CurrentValue = shown(),
                Callback = function(value)
                    local number = tonumber(value)
                    if number and number ~= shown() then
                        write(path, math.clamp(number, min, max) * scale)
                    end
                end,
            }, index)
            describe(box, index, text)
            remember(table.concat(path, "."), function()
                if element.Values.CurrentValue ~= shown() then
                    element:Set({ CurrentValue = shown() })
                end
            end)
            return element
        end
        local fitPopup
        local function sameSet(a, b)
            if #a ~= #b then
                return false
            end
            local seen = {}
            for _, item in ipairs(a) do
                seen[item] = true
            end
            for _, item in ipairs(b) do
                if not seen[item] then
                    return false
                end
            end
            return true
        end
        local function bindPick(box, index, icon, name, path, choices, opts)
            opts = opts or {}
            local multi = opts.multi == true
            local get = opts.get or function()
                return read(path)
            end
            local current = get()
            if (multi and not isStringList(current)) or (not multi and type(current) ~= "string") then
                return nil
            end
            local list = table.clone(choices)
            for _, value in ipairs(multi and current or { current }) do
                local known = false
                for _, choice in ipairs(list) do
                    known = known or choice[1] == value
                end
                if not known then
                    table.insert(list, { value, opts.nameOf and opts.nameOf(value) or prettyKind(value) })
                end
            end
            for position, choice in ipairs(list) do
                list[position] = { choice[1], Lang.tr(choice[2]) }
            end
            local function names(values)
                local result = {}
                for _, choice in ipairs(list) do
                    if table.find(values, choice[1]) then
                        table.insert(result, choice[2])
                    end
                end
                return result
            end
            local labels = {}
            for _, choice in ipairs(list) do
                table.insert(labels, choice[2])
            end
            local label = box:CreateLabel({ Name = name, Icon = I(icon), Tooltip = opts.tooltip or (path and about(path)) }, index)
            local dropdown = label:AddDropdown({
                Options = labels,
                CurrentOption = names(multi and current or { current }),
                MultipleOptions = multi,
                Required = not multi and #labels > 0,
                Placeholder = opts.placeholder,
                Callback = function(selected)
                    local picked = {}
                    for _, item in ipairs(type(selected) == "table" and selected or { selected }) do
                        picked[item] = true
                    end
                    local values = {}
                    for _, choice in ipairs(list) do
                        if picked[choice[2]] then
                            table.insert(values, choice[1])
                        end
                    end
                    local now = get()
                    if multi then
                        if not sameSet(values, now) then
                            if opts.set then
                                opts.set(values)
                            else
                                write(path, values)
                            end
                        end
                    elseif values[1] and values[1] ~= now then
                        if opts.set then
                            opts.set(values[1])
                        else
                            write(path, values[1])
                        end
                        if opts.onPick then
                            opts.onPick(values[1])
                        end
                    end
                end,
            }, "Dropdown")
            fitPopup(dropdown)
            local function refreshPick()
                local want = names(multi and get() or { get() })
                local shownNow = dropdown and dropdown.Values and dropdown.Values.CurrentOption
                if type(shownNow) ~= "table" or not sameSet(shownNow, want) then
                    dropdown:Set({ CurrentOption = want })
                end
            end
            for _, key in ipairs(opts.keys or { path and table.concat(path, ".") }) do
                remember(key, refreshPick)
            end
            describe(box, index, opts.tooltip or (path and about(path)))
            return label, dropdown
        end
        local function bindText(box, index, icon, name, path, placeholder, accept, shown)
            if type(read(path)) ~= "string" then
                return nil
            end
            shown = shown or function(value)
                return value
            end
            local element
            element = box:CreateInput({
                Name = name,
                Icon = I(icon),
                Tooltip = about(path),
                CurrentValue = shown(read(path)),
                PlaceholderText = placeholder,
                Enter = true,
                Callback = function(typed)
                    typed = string.match(tostring(typed or ""), "^%s*(.-)%s*$")
                    if typed == shown(read(path)) then
                        return
                    end
                    local ok, why = accept(typed)
                    if ok then
                        write(path, typed)
                    else
                        notify(name, why or "Not valid", "triangle-alert")
                    end
                    pcall(function()
                        element:Set({ CurrentValue = shown(read(path)) })
                    end)
                end,
            }, index)
            remember(table.concat(path, "."), function()
                if tostring(element.Values.CurrentValue) ~= shown(read(path)) then
                    element:Set({ CurrentValue = shown(read(path)) })
                end
            end)
            return element
        end
        local function confirm(window, title, content, icon, actionName, action, extra)
            local actions = {
                Primary = { Name = actionName, Icon = I("check"), Callback = action },
                { Name = "Cancel", Callback = function() end },
            }
            if extra then
                table.insert(actions, 1, extra)
            end
            window:PromptDialog({
                Name = title,
                Content = content,
                Icon = I(icon),
                Type = 1,
                Actions = actions,
            })
        end
        local function rebuild(why)
            if type(api.OpenInterface) == "function" then
                notify("Window", why or "Building the window again...", "refresh-cw")
                task.delay(0.5, api.OpenInterface)
                return true
            end
            notify("Window", "Applies when the window opens again.", "info")
            return false
        end
        local function callApi(name, ...)
            local fn = api[name]
            if type(fn) ~= "function" then
                return false, "Not available in this version"
            end
            return fn(...)
        end
        local refreshStatus
        function fitPopup(dropdown)
            if handle.scale == nil or handle.scale == 1 then
                return
            end
            pcall(function()
                local scale = handle.scale
                local anchor, popup = dropdown.Instances[1], dropdown.Instances[2]
                local uiScale = popup:FindFirstChild("AmeFarmScale") or Instance.new("UIScale")
                uiScale.Name = "AmeFarmScale"
                uiScale.Scale = scale
                uiScale.Parent = popup
                local function width()
                    popup.Size = UDim2.fromOffset(math.ceil(anchor.AbsoluteSize.X / scale), popup.Size.Y.Offset)
                end
                width()
                table.insert(connections, anchor:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                    task.defer(width)
                end))
            end)
        end
        local tintIcon
        local function actionButton(box, index, icon, name, tooltip, run)
            return box:CreateButton({
                Name = name,
                Icon = I(icon),
                IndicatorStyle = 1,
                Tooltip = tooltip,
                Callback = function()
                    local okRun, ok, message = pcall(run)
                    if not okRun then
                        notify(name, "Error: " .. tostring(ok), "triangle-alert")
                    elseif message ~= false then
                        notify(name, tostring(message or (ok and "Done" or "Not possible now")), ok and "check" or "triangle-alert")
                    end
                    if refreshStatus then
                        refreshStatus()
                    end
                end,
            }, index)
        end
        local keybind = tostring(settings.Keybind or "RightShift")
        Starlight.WindowKeybind = keybind
        local version = tostring(api.Version or "?")
        local shortVersion = string.match(version, "^[%d%.]+") or version
        local windowSettings = {
            Name = Interface.TITLE,
            Subtitle = Interface.EDITION,
            Icon = I("paw-print"),
            LoadingEnabled = false,
            InterfaceAdvertisingPrompts = false,
            NotifyOnCallbackError = true,
            FileSettings = { ConfigFolder = "AdoptMeFarm" },
        }
        local windowWidth, windowHeight
        if hasViewport and UDim2 then
            local width, height
            if scale ~= 1 then
                width, height = Interface.PC_SIZE[1], Interface.PC_SIZE[2]
            else
                width = touch and math.min(viewport.X - 80, 900) or math.min(viewport.X - 120, 980)
                height = touch and math.min(viewport.Y - 120, 560) or math.min(viewport.Y - 160, 600)
            end
            windowWidth, windowHeight = math.floor(math.max(width, 320)), math.floor(math.max(height, 200))
            windowSettings.DefaultSize = UDim2.fromOffset(windowWidth, windowHeight)
        end
        local scaled = scale ~= 1 and pcall(function()
            local main = Starlight.Instance.MainWindow
            local uiScale = main:FindFirstChild("AmeFarmScale") or Instance.new("UIScale")
            uiScale.Name = "AmeFarmScale"
            uiScale.Scale = scale
            uiScale.Parent = main
        end)
        local Window = Starlight:CreateWindow(windowSettings)
        handle.scale = scale
        if scaled and windowWidth then
            local function place()
                pcall(function()
                    local main = Starlight.Instance.MainWindow
                    if not Starlight.Maximized then
                        main.Size = UDim2.fromOffset(windowWidth, windowHeight)
                    end
                    local inset = 36
                    pcall(function()
                        inset = game:GetService("GuiService"):GetGuiInset().Y
                    end)
                    local top = math.max(0, math.floor((viewport.Y - inset - windowHeight * scale) / 2))
                    main.Position = UDim2.fromOffset(math.floor((viewport.X - windowWidth * scale) / 2), top)
                end)
                pcall(function()
                    Starlight.Instance.Drag.Size = UDim2.new(0, 0, 0, 0)
                end)
            end
            place()
            task.delay(0.6, place)
        end
        local boxes = {}
        local liveColor = "gray"
        local localized = false
        local function track(tab)
            local create = tab.CreateGroupbox
            tab.CreateGroupbox = function(self, groupboxSettings, index)
                local box = create(self, groupboxSettings, index)
                boxes[index] = box
                return box
            end
            return tab
        end
        local paintAll
        local function paint()
            for index, box in pairs(boxes) do
                local color = index == "live" and liveColor or Interface.BOX_COLORS[index]
                if color then
                    pcall(Interface.tintGroupbox, box, color)
                end
                if not localized then
                    pcall(function()
                        box.Instance:FindFirstAncestorOfClass("ScreenGui").AutoLocalize = false
                        localized = true
                    end)
                end
            end
        end
        local homeTab
        if wide and type(Window.CreateHomeTab) == "function" then
            local okHome, result = pcall(function()
                return Window:CreateHomeTab({
                    SupportedExecutors = Interface.SUPPORTED_EXECUTORS,
                    UnsupportedExecutors = {},
                    DiscordInvite = Interface.DISCORD_INVITE,
                    Backdrop = 0,
                    IconStyle = 1,
                    Changelog = { Interface.CHANGELOG_LATEST },
                })
            end)
            homeTab = okHome and type(result) == "table" and result or nil
        end
        handle.dashboard = homeTab ~= nil
        local farmSection = Window:CreateTabSection("Farm")
        local setupSection
        local mainTab = track(farmSection:CreateTab({ Name = "Main", Icon = I("paw-print"), Columns = columns }, "main"))
        local rowElements, stateHeader = {}, nil
        if not homeTab then
            local live = mainTab:CreateGroupbox({ Name = "Farm status", Icon = I("activity"), Column = 1 }, "live")
            bindToggle(live, "farmEnabled", "power", "Farm running", { "Farm", "Enabled" })
            local headerTitle, headerText = Interface.stateHeader(nil)
            stateHeader = live:CreateParagraph({ Name = headerTitle, Icon = I("power"), Content = headerText }, "state")
            for _, row in ipairs(Interface.statusRows(nil, rowWidth)) do
                rowElements[row.key] = live:CreateLabel({ Name = row.text, Icon = I(row.game or row.icon, row.icon) },
                    "row_" .. row.key)
            end
        end
        local farmBox = mainTab:CreateGroupbox({ Name = "Quick actions", Icon = I("zap"), Column = 1 }, "farm")
        if homeTab then
            bindToggle(farmBox, "farmEnabled", "power", "Farm running", { "Farm", "Enabled" })
        end
        actionButton(farmBox, "qaHome", "game:home", "Go home", "Stops the running task and goes home (respawn first).", function()
            return callApi("GoHome")
        end)
        actionButton(farmBox, "qaSkip", "skip-forward", "Skip current task", "Stops the running task; it is not chosen again for 90 s.",
            function()
                return callApi("SkipTask")
            end)
        actionButton(farmBox, "qaRetry", "refresh-cw", "Retry resting tasks", "Tasks that failed 3 times in a row may run again now.",
            function()
                return callApi("RetryDisabled")
            end)
        farmBox:CreateButton({
            Name = "Stop the farm",
            Icon = I("octagon-x"),
            IndicatorStyle = 1,
            Tooltip = "Everything stops and cleans up (run the loader again to start).",
            Callback = function()
                confirm(Window, "Stop the farm?", "Everything stops and cleans up. Run the loader again to start.",
                    "octagon-x", "Stop", function()
                        api.Stop("stopped from the window")
                        notify(Interface.TITLE, "Stopped.", "octagon-x")
                    end)
            end,
        }, "stop")
        local tasksBox = mainTab:CreateGroupbox({ Name = "Auto tasks", Icon = I("badge-check"), Column = 1 }, "tasks")
        bindToggle(tasksBox, "quests", "scroll-text", "Claim quests", { "Farm", "Event", "Quests" })
        bindToggle(tasksBox, "visits", "game:home", "Visit homes for quests", { "Farm", "Event", "HouseVisits" })
        bindToggle(tasksBox, "cashback", "game:bucks", "Collect cashback", { "Farm", "CollectCashback" })
        bindToggle(tasksBox, "autoOpen", "gift", "Open gifts and chests", { "Farm", "AutoOpen", "Enabled" })
        local penBox = mainTab:CreateGroupbox({ Name = "Pet Pen", Icon = I("fence"), Column = 1 }, "pen")
        bindToggle(penBox, "pen", "fence", "Auto Pet Pen", { "Farm", "Event", "PetPen" },
            "Claims the pen (at home), takes full grown pets out, fills it with pets that still grow")
        bindSlider(penBox, "penMinutes", "timer", "Claim every", { "Farm", "Event", "PetPenMinutes" }, 1, 60, 1, "min")
        bindToggle(penBox, "penStock", "package", "Keep it full (buys eggs)", { "Farm", "Event", "PetPenStock" },
            "Buys eggs (Bucks) so the pen always has pets that grow; needs 'Buy an egg'")
        actionButton(penBox, "qaPen", "fence", "Claim Pet Pen now", "Goes home if needed and claims / refills the Pet Pen once.",
            function()
                return callApi("ClaimPetPen")
            end)
        local needsBox = mainTab:CreateGroupbox({ Name = "Auto needs", Icon = I("list-checks"), Column = col(2) }, "needs")
        bindToggle(needsBox, "autoNeeds", "list-checks", "Auto needs", { "Farm", "AutoNeeds", "Enabled" },
            "Does every pet need; pick below the ones to skip. Buys 1 food / water only when it has none.")
        bindToggle(needsBox, "babyMode", "baby", "Baby needs too", { "Farm", "BabyMode" })
        bindPick(needsBox, "needSkip", "octagon-x", "Skip these needs", { "Farm", "AutoNeeds", "Skip" }, Interface.NEED_NAMES,
            { multi = true, placeholder = "Nothing skipped: every need", tooltip = "Needs picked here are NOT done" })
        local petsBox = mainTab:CreateGroupbox({ Name = "Pets", Icon = I("paw-print"), Column = col(2) }, "pets")
        bindToggle(petsBox, "autoPet", "link", "Keep growing pet equipped", { "Farm", "KeepPetEquipped" },
            "Keeps a pet that still grows equipped; a full grown one is swapped")
        local firstChoices = { { "@neon", "Neon pets" }, { "@oldest", "Oldest pets (closest to grown)" } }
        local kindsShown = {}
        for _, kind in ipairs(type(farm.FarmPetKinds) == "table" and farm.FarmPetKinds or {}) do
            if not kindsShown[kind] then
                kindsShown[kind] = true
                table.insert(firstChoices, { kind, prettyKind(kind) })
            end
        end
        for _, kind in ipairs(catalog.petKinds) do
            if not kindsShown[kind] then
                kindsShown[kind] = true
                table.insert(firstChoices, { kind, prettyKind(kind) })
            end
        end
        bindPick(petsBox, "farmFirst", "list-ordered", "Farm first", nil, firstChoices, {
            multi = true,
            placeholder = "Any growing pet (youngest first)",
            tooltip = "These pets get the needs, potions and Pet Pen first",
            keys = { "Farm.PreferNeon", "Farm.PetOrder", "Farm.FarmPetKinds" },
            get = function()
                local values = {}
                if farm.PreferNeon then
                    table.insert(values, "@neon")
                end
                if farm.PetOrder == "oldest" then
                    table.insert(values, "@oldest")
                end
                for _, kind in ipairs(type(farm.FarmPetKinds) == "table" and farm.FarmPetKinds or {}) do
                    table.insert(values, kind)
                end
                return values
            end,
            set = function(values)
                local kinds = {}
                for _, value in ipairs(values) do
                    if string.sub(value, 1, 1) ~= "@" then
                        table.insert(kinds, value)
                    end
                end
                write({ "Farm", "PreferNeon" }, table.find(values, "@neon") ~= nil)
                write({ "Farm", "PetOrder" }, table.find(values, "@oldest") and "oldest" or "youngest")
                write({ "Farm", "FarmPetKinds" }, kinds)
            end,
        })
        local eggIcon = "item:" .. tostring(farm.EggToBuy or "cracked_egg") .. "|egg"
        bindToggle(petsBox, "buyEgg", eggIcon, "Buy an egg if none grows", { "Farm", "BuyEgg" })
        bindPick(petsBox, "eggChoice", eggIcon, "Egg to buy", { "Farm", "EggToBuy" }, Interface.EGG_NAMES)
        local growthBox = mainTab:CreateGroupbox({ Name = "Potions & neon", Icon = I("flask-conical"), Column = col(2) }, "growth")
        bindToggle(growthBox, "potions", "item:pet_age_potion|flask-conical", "Use potions", { "Farm", "AutoPotions", "Enabled" },
            "Uses every potion that helps farming on the growing pet; pick below the ones to keep")
        local potionChoices = {}
        for _, id in ipairs(type(farm.AutoPotions) == "table" and type(farm.AutoPotions.Potions) == "table"
            and farm.AutoPotions.Potions or {}) do
            table.insert(potionChoices, { id, Interface.POTION_NAMES[id] or prettyKind(id) })
        end
        bindPick(growthBox, "potionSkip", "octagon-x", "Don't use", { "Farm", "AutoPotions", "Skip" }, potionChoices,
            { multi = true, placeholder = "Using every potion", tooltip = "Potions picked here are kept (never used)" })
        bindToggle(growthBox, "autoNeon", "wand-sparkles", "Auto neon pets", { "Farm", "AutoNeon", "Enabled" },
            "4 full grown pets of one kind -> 1 neon")
        bindToggle(growthBox, "autoMega", "sparkles", "Auto mega neon pets", { "Farm", "AutoNeon", "Mega" },
            "4 full grown neons of one kind -> 1 mega neon")
        local eventTab = track(farmSection:CreateTab({ Name = "Event", Icon = I("ghost"), Columns = columns }, "event"))
        local halloweenBox = eventTab:CreateGroupbox({ Name = "Halloween 2026", Icon = I("ghost"), Column = 1 }, "halloween")
        bindToggle(halloweenBox, "ghostOn", "crosshair", "Ghost Gallery", { "Farm", "Event", "GhostGallery" },
            "Joins every round and vacuums the ghosts (Rusty Keys)")
        bindToggle(halloweenBox, "cat", "cat", "Auto Stray Cat", { "Farm", "Event", "StrayCat" })
        local cryptBox = eventTab:CreateGroupbox({ Name = "Crypt", Icon = I("item:halloween_2026_tomb_spider|skull"), Column = 1 },
            "crypt")
        bindToggle(cryptBox, "crypt", "item:halloween_2026_rusty_key|key-round", "Use Rusty Keys", { "Farm", "Event", "Crypt" },
            "Opens Crypt graves with your Rusty Keys; pick below what to open")
        bindPick(cryptBox, "cryptOpen", "item:halloween_2026_rusty_key|key-round", "Open", { "Farm", "Event", "CryptOpen" }, Interface.CRYPT_NAMES,
            { multi = true, placeholder = "Next floor (Mummy Spider)", tooltip = "What a Rusty Key opens, in this order" })
        bindToggle(cryptBox, "nest", "item:halloween_2026_twig|bird", "Give twigs to the nest", { "Farm", "Event", "PigeonNest" },
            "Has a Crypt Twig: takes it to the Hotel nest")
        local candy = event.CandyPets
        if type(candy) == "table" then
            local shopBox = eventTab:CreateGroupbox({ Name = "Candy Shop", Icon = I("game:candy"), Column = col(2) }, "shop")
            bindToggle(shopBox, "candyOn", "game:candy", "Auto buy", { "Farm", "Event", "CandyPets", "Enabled" },
                "Buys the pets picked below with candy, as many as the candy pays for")
            local shopChoices = {}
            for _, entry in ipairs(type(candy.Buy) == "table" and candy.Buy or {}) do
                if type(entry) == "table" and type(entry.id) == "string" then
                    table.insert(shopChoices, { entry.id, string.format("%s (%s candy)", Interface.SHOP_NAMES[entry.id]
                        or prettyKind(entry.id), commas(entry.price)) })
                end
            end
            bindPick(shopBox, "candyPick", "item:halloween_2026_jump_scare|shopping-bag", "Buy", { "Farm", "Event", "CandyPets", "Pick" }, shopChoices,
                { multi = true, placeholder = "Pick what to buy", tooltip = "No limit: bought whenever the candy is enough" })
        end
        local eventInfoBox = eventTab:CreateGroupbox({ Name = "Event status", Icon = I("game:candy"), Column = col(2) }, "eventInfo")
        local eventInfo = eventInfoBox:CreateParagraph({ Name = "Your event", Icon = I("ghost"), Content = "Waiting for your data..." },
            "eventText")
        setupSection = Window:CreateTabSection("Setup")
        local webhookTab = track(setupSection:CreateTab({ Name = "Webhook", Icon = I("bell"), Columns = columns }, "webhook"))
        local hookBox = webhookTab:CreateGroupbox({ Name = "Discord webhook", Icon = I("bell"), Column = 1 }, "hook")
        local function shortUrl(url)
            if url == "" then
                return ""
            end
            return string.sub(url, 1, 24) .. "..."
        end
        local hookInput = bindText(hookBox, "hookUrl", "link", "Webhook URL", { "Notifications", "Webhooks", "Summary" },
            "https://...", function(url)
                if url ~= "" and not Config.isValidWebhookUrl(url) then
                    return false, "That is not a Discord webhook URL (Channel settings > Integrations > Webhooks)"
                end
                if url ~= "" then
                    write({ "Notifications", "Enabled" }, true)
                end
                notify("Webhook", url == "" and "Webhook removed." or "Saved on this device. Press 'Send test message'.",
                    "check")
                return true
            end, shortUrl)
        bindText(hookBox, "hookUser", "at-sign", "User ID", { "Notifications", "PingDiscordUserId" },
            "123456789...", function(id)
                if id ~= "" and not string.match(id, "^%d+$") then
                    return false, "Digits only (Discord: Settings > Advanced > Developer Mode, then right click yourself > Copy ID)"
                end
                return true
            end)
        bindToggle(hookBox, "hookPing", "bell", "Ping me", { "Notifications", "Ping" }, "@mentions you on the messages picked below")
        local pingChoices = {}
        for _, flag in ipairs(Interface.PING_FLAGS) do
            table.insert(pingChoices, { flag, Interface.PING_NAMES[flag] or flag })
        end
        local pingKeys = {}
        for _, flag in ipairs(Interface.PING_FLAGS) do
            table.insert(pingKeys, "Notifications.PingOn." .. flag)
        end
        bindPick(hookBox, "pingOn", "at-sign", "Ping me on", nil, pingChoices, {
            multi = true,
            placeholder = "No pings",
            tooltip = "Which messages @mention you",
            keys = pingKeys,
            get = function()
                local values = {}
                for _, flag in ipairs(Interface.PING_FLAGS) do
                    if read({ "Notifications", "PingOn", flag }) == true then
                        table.insert(values, flag)
                    end
                end
                return values
            end,
            set = function(values)
                for _, flag in ipairs(Interface.PING_FLAGS) do
                    write({ "Notifications", "PingOn", flag }, table.find(values, flag) ~= nil)
                end
            end,
        })
        bindToggle(hookBox, "hookSummary", "file-text", "Send summary", { "Notifications", "SendSummary" },
            "A summary message (needs done, Bucks, pet) every few minutes")
        bindSlider(hookBox, "summaryMinutes", "timer", "Summary every", { "Notifications", "SummaryIntervalMinutes" }, 1, 120, 1, "min")
        actionButton(hookBox, "hookTest", "send", "Send test message", "Sends one test message to your webhook.", function()
            return callApi("TestWebhook")
        end)
        local hookState = hookBox:CreateLabel({ Name = "Webhook: checking...", Icon = I("info") }, "hookState")
        local messagesBox = webhookTab:CreateGroupbox({ Name = "Messages", Icon = I("scroll-text"), Column = col(2) }, "messages")
        bindToggle(messagesBox, "hookTasks", "badge-check", "Each finished need", { "Notifications", "SendOnTaskComplete" })
        bindToggle(messagesBox, "hookKicks", "octagon-x", "Kick / disconnect", { "Notifications", "SendOnKick" })
        bindToggle(messagesBox, "hookErrors", "triangle-alert", "Errors", { "Notifications", "SendOnError" })
        bindToggle(messagesBox, "hookStartStop", "power", "Start / stop", { "Notifications", "SendOnStartStop" })
        bindToggle(messagesBox, "hookName", "paw-print", "Show my Roblox name", { "Notifications", "IncludeUsername" })
        bindText(messagesBox, "hookAlerts", "link", "Alerts URL", { "Notifications", "Webhooks", "Alerts" },
            "https://...", function(url)
                if url ~= "" and not Config.isValidWebhookUrl(url) then
                    return false, "That is not a Discord webhook URL"
                end
                return true
            end, shortUrl)
        local configTab = track(setupSection:CreateTab({ Name = "Config", Icon = I("settings"), Columns = columns }, "config"))
        local configsBox = configTab:CreateGroupbox({ Name = "Configs", Icon = I("save"), Column = 1 }, "configs")
        local typedName = ""
        local selected = nil
        local nameInput = configsBox:CreateInput({
            Name = "Config name",
            Icon = I("file-text"),
            CurrentValue = "",
            PlaceholderText = "e.g. main farm",
            Enter = false,
            Callback = function(text)
                typedName = tostring(text or "")
            end,
        }, "configName")
        local function configChoices()
            local list = {}
            for _, name in ipairs(Interface.listConfigs()) do
                table.insert(list, name)
            end
            return list
        end
        local configLabel = configsBox:CreateLabel({ Name = "Saved configs", Icon = I("layers") }, "configList")
        local configDropdown = configLabel:AddDropdown({
            Options = configChoices(),
            CurrentOption = {},
            MultipleOptions = false,
            Required = false,
            Placeholder = "Pick a saved config",
            Callback = function(picked)
                local name = type(picked) == "table" and picked[1] or picked
                selected = (type(name) == "string" and name ~= "") and name or nil
            end,
        }, "Dropdown")
        fitPopup(configDropdown)
        local autoloadLabel
        local function updateAutoloadInfo()
            pcall(function()
                local name = settings.Autoload
                autoloadLabel:Set({ Name = (type(name) == "string" and name ~= "") and fit(T("Autoload: '%s' at start", name),
                    rowWidth) or "Autoload: off" })
            end)
        end
        local function refreshConfigList(pick)
            selected = pick or selected
            pcall(function()
                configDropdown:Set({ Options = configChoices(), CurrentOption = selected and { selected } or {} })
            end)
        end
        local function snapshot()
            local values = {}
            for key in pairs(handle.bound) do
                if Interface.canSave(key) and not Interface.PRIVATE_KEYS[key] and not Interface.META_KEYS[key] then
                    values[key] = deepCopy(read(splitPath(key)))
                end
            end
            return values
        end
        actionButton(configsBox, "configSave", "save", "Save as new config", "Saves every setting of the window under the name above.",
            function()
                local name = Interface.configName(typedName ~= "" and typedName or tostring(nameInput.Values.CurrentValue or ""))
                if name == "" then
                    return false, "Type a name first"
                end
                if table.find(Interface.listConfigs(), name) then
                    return false, "'" .. name .. "' exists: pick it and press Overwrite"
                end
                local ok, result = Interface.writeConfig(name, snapshot())
                if ok then
                    refreshConfigList(name)
                end
                return ok, ok and ("Saved '" .. name .. "'") or result
            end)
        actionButton(configsBox, "configOverwrite", "refresh-cw", "Overwrite selected", "Saves the current settings into the picked config.",
            function()
                if not selected then
                    return false, "Pick a saved config first"
                end
                local ok, result = Interface.writeConfig(selected, snapshot())
                return ok, ok and ("Overwrote '" .. selected .. "'") or result
            end)
        actionButton(configsBox, "configLoad", "download", "Load selected", "Puts the picked config's settings in place now.",
            function()
                if not selected then
                    return false, "Pick a saved config first"
                end
                local values = Interface.readConfig(selected)
                if not values then
                    return false, "Could not read '" .. selected .. "'"
                end
                local count = 0
                for key, value in pairs(values) do
                    if Interface.canSave(key) and not Interface.PRIVATE_KEYS[key] then
                        local tbl, leaf = Interface.resolve(config, splitPath(key))
                        local current = type(tbl) == "table" and tbl[leaf]
                        local fits = current ~= nil and (type(value) == "table" and isStringList(current) and isStringList(value)
                            or type(current) == type(value))
                        if fits then
                            write(splitPath(key), deepCopy(value))
                            count += 1
                        end
                    end
                end
                refresh()
                return true, string.format("Loaded '%s' (%d settings)", selected, count)
            end)
        actionButton(configsBox, "configDelete", "trash-2", "Delete selected", "Deletes the picked config file.", function()
            if not selected then
                return false, "Pick a saved config first"
            end
            local name = selected
            confirm(Window, "Delete '" .. name .. "'?", "The config file is deleted from this device.", "trash-2", "Delete", function()
                Interface.deleteConfig(name)
                if settings.Autoload == name then
                    write({ "Interface", "Autoload" }, "")
                    updateAutoloadInfo()
                end
                selected = nil
                refreshConfigList(nil)
                notify("Configs", "Deleted '" .. name .. "'", "trash-2")
            end)
            return true, false
        end)
        bindToggle(configsBox, "autosave", "save", "Autosave", { "Interface", "RememberSettings" },
            "On: every change in the window is kept on this device. Off: changes last until you leave; save a config instead")
        local autoloadToggle = configsBox:CreateToggle({
            Name = "Autoload selected",
            Icon = I("rocket"),
            Tooltip = "At every start, the config picked above is put in place",
            CurrentValue = type(settings.Autoload) == "string" and settings.Autoload ~= "",
            Style = 2,
            Callback = function(value)
                if value then
                    if not selected then
                        notify("Autoload", "Pick a saved config first", "triangle-alert")
                        write({ "Interface", "Autoload" }, "")
                    else
                        write({ "Interface", "Autoload" }, selected)
                    end
                else
                    write({ "Interface", "Autoload" }, "")
                end
                updateAutoloadInfo()
            end,
        }, "autoload")
        remember("Interface.Autoload", function()
            local on = type(settings.Autoload) == "string" and settings.Autoload ~= ""
            if autoloadToggle.Values.CurrentValue ~= on then
                autoloadToggle:Set({ CurrentValue = on })
            end
            updateAutoloadInfo()
        end)
        autoloadLabel = configsBox:CreateLabel({ Name = "Autoload: off", Icon = I("info") }, "autoloadInfo")
        updateAutoloadInfo()
        savedInfo = configsBox:CreateLabel({ Name = "", Icon = I("save") }, "savedInfo")
        updateSavedInfo()
        local look = configTab:CreateGroupbox({ Name = "Settings", Icon = I("settings"), Column = 1 }, "settings")
        bindToggle(look, "antiAfk", "shield-check", "Anti-AFK", { "Farm", "AntiAfk" }, "Clicks on Roblox's idle warning (no idle kick)")
        bindToggle(look, "autoMenu", "mouse-pointer-click", "Auto click Play (menu)", { "Farm", "AutoAcceptMenu" })
        bindToggle(look, "cameraGuard", "camera", "Camera guard", { "Farm", "CameraGuard" },
            "The camera went inside your character: it is zoomed back out")
        bindToggle(look, "toasts", "bell", "Event pop-ups", { "Interface", "Toasts" }, "Pop-ups for keys, neon, purchases, rounds")
        bindToggle(look, "startHidden", "eye-off", "Autoclose GUI on execute", { "Interface", "StartHidden" },
            "The window starts hidden: " .. (touch and "the round paw button" or "the hide / show key") .. " opens it")
        local canTheme = type(Starlight.Themes) == "table" and type(Starlight.SetTheme) == "function"
        local function applyTheme(name)
            local choice = canTheme and Interface.themeChoice(Starlight, name) or nil
            if choice ~= nil then
                pcall(function()
                    Starlight:SetTheme(choice)
                end)
                task.delay(0.2, function()
                    if paintAll then
                        paintAll()
                    end
                end)
            end
            return choice ~= nil
        end
        if canTheme then
            local themes = {}
            for _, name in ipairs(Interface.THEME_NAMES) do
                if Interface.themeChoice(Starlight, name) ~= nil then
                    table.insert(themes, { name, name })
                end
            end
            for _, name in ipairs(Interface.THEMES) do
                if Starlight.Themes[name] ~= nil then
                    table.insert(themes, { name, name })
                end
            end
            if #themes > 1 then
                bindPick(look, "theme", "palette", "Theme", { "Interface", "Theme" }, themes, { onPick = applyTheme })
            end
        end
        do
            local autoCode = Lang.pick("Auto", country, locale)
            local autoInfo = Lang.info(autoCode)
            local choices = { { "Auto", T("Auto") .. " (" .. Lang.flag(country or autoInfo.country) .. " " .. autoInfo.name .. ")" } }
            for _, language in ipairs(Lang.LANGUAGES) do
                table.insert(choices, { language.code, Lang.flag(language.country) .. " " .. language.name })
            end
            bindPick(look, "language", "languages", "Language", { "Interface", "Language" }, choices, {
                tooltip = "Which language the window uses (Auto: your country's)",
                onPick = function()
                    rebuild()
                end,
            })
        end
        local hideKey
        if not touch then
            local keys = {}
            for _, key in ipairs(Interface.KEYBINDS) do
                table.insert(keys, { key, key })
            end
            bindPick(look, "keybind", "keyboard", "Hide / show key", { "Interface", "Keybind" }, keys, { onPick = function(key)
                Starlight.WindowKeybind = key
                pcall(function()
                    hideKey:Set({ Name = "Hide / show: " .. key })
                end)
            end })
        end
        do
            local scaleChoices = {}
            for _, value in ipairs(Interface.UI_SCALES) do
                local percent = function(n)
                    return tostring(math.floor(n * 100 + 0.5)) .. "%"
                end
                table.insert(scaleChoices, { value, value == "Auto"
                    and (T("Auto") .. " (" .. percent(Interface.scaleFor("Auto", touch, hasViewport and viewport or nil)) .. ")")
                    or percent(tonumber(value)) })
            end
            bindPick(look, "uiScale", "scaling", "UI scale", { "Interface", "UIScale" }, scaleChoices, {
                tooltip = "How big the window is drawn (Auto: smaller on phones)",
                onPick = function()
                    rebuild()
                end,
            })
        end
        bindToggle(look, "descriptions", "info", "Help lines", { "Interface", "Descriptions" })
        look:CreateButton({
            Name = "Reset to loader settings",
            Icon = I("eraser"),
            IndicatorStyle = 1,
            Tooltip = "Every change made in the window goes back to the loader's value, now and at the next start.",
            Callback = function()
                confirm(Window, "Reset to loader settings?", "Every setting you changed in the window goes back to the loader's "
                    .. "value, now and at the next start. Saved configs stay.", "eraser", "Reset", function()
                    local saved = Interface.saved
                    quiet = true
                    for key, original in pairs(saved.originals) do
                        local tbl, leaf = Interface.resolve(config, splitPath(key))
                        if type(tbl) == "table" then
                            tbl[leaf] = deepCopy(original)
                        end
                    end
                    quiet = false
                    Interface.saved = { changes = {}, originals = {} }
                    Interface.writeSaved(Interface.saved.changes)
                    refresh()
                    applyTheme(settings.Theme)
                    Starlight.WindowKeybind = tostring(settings.Keybind or "RightShift")
                    updateSavedInfo()
                    updateAutoloadInfo()
                    notify("Settings", "Back to the loader's settings.", "eraser")
                end)
            end,
        }, "forget")
        look:CreateButton({
            Name = "What this script does (report)",
            Icon = I("file-text"),
            IndicatorStyle = 1,
            Callback = function()
                api.Disclosure()
                notify("Transparency report", "Printed to the console (F9 / executor console).", "file-text")
            end,
        }, "disclosure")
        hideKey = look:CreateLabel({ Name = touch and "Hide / show: tap the round paw button" or ("Hide / show: " .. keybind),
            Icon = I(touch and "smartphone" or "keyboard") }, "hideKey")
        look:CreateParagraph({ Name = "Closed the window?", Icon = I("rotate-ccw"),
            Content = "Run: getgenv().AdoptMeFarm.OpenInterface()" }, "reopen")
        local presets = configTab:CreateGroupbox({ Name = "Presets by the developer", Icon = I("sliders-horizontal"),
            Column = col(2) }, "presets")
        local function applyPreset(id, start)
            local values, preset = Config.presetValues(id)
            if not values then
                return
            end
            for _, entry in ipairs(values) do
                write(entry[1], deepCopy(entry[2]))
            end
            if start then
                write({ "Farm", "Enabled" }, true)
            end
            config.Preset = preset.id
            refresh()
            if refreshStatus then
                refreshStatus()
            end
            local on, total = Config.countFeatures(config)
            notify("Preset: " .. preset.name, string.format("%d of %d features on. %s", on, total,
                config.Farm.Enabled and "The farm is running." or "Switch 'Farm running' on to start."), preset.icon)
        end
        for _, preset in ipairs(Config.Presets) do
            presets:CreateButton({
                Name = preset.name,
                Icon = I(preset.icon),
                IndicatorStyle = 1,
                Tooltip = preset.about,
                Callback = function()
                    local isOff = preset.id == "Off"
                    confirm(Window, preset.name, preset.about .. (isOff and "" or " Your other settings stay."), preset.icon,
                        "Apply", function()
                            applyPreset(preset.id, false)
                        end, not isOff and { Name = "Apply + start", Icon = I("power"), Callback = function()
                            applyPreset(preset.id, true)
                        end } or nil)
                end,
            }, "preset" .. preset.id)
        end
        local advanced = configTab:CreateGroupbox({ Name = "Advanced", Icon = I("wrench"), Column = col(2) }, "advanced")
        bindToggle(advanced, "smartPriority", "target", "Needs doable here first", { "Farm", "SmartPriority" })
        bindToggle(advanced, "stuckRecovery", "rotate-ccw", "Stuck recovery (go home)", { "Farm", "StuckRecovery", "Enabled" })
        bindSlider(advanced, "stuckSeconds", "hourglass", "Stuck after", { "Farm", "StuckRecovery", "Seconds" }, 1, 10, 0.5, "min",
            nil, 60)
        bindToggle(advanced, "rejoin", "refresh-cw", "Rejoin when stuck", { "Farm", "AutoRejoin" },
            "No place / character: rejoins a PUBLIC server")
        bindSlider(advanced, "stuckMinutes", "hourglass", "Rejoin after", { "Farm", "StuckRejoinSeconds" },
            1, 10, 0.5, "min", nil, 60)
        bindToggle(advanced, "gameTravel", "door-open", "Game travel (doors)", { "Farm", "GameTravel" })
        bindToggle(advanced, "respawnHome", "rotate-ccw", "Go home by respawn", { "Farm", "HomeByRespawn" })
        bindToggle(advanced, "bowlTrip", "utensils", "Food bowl trips", { "Farm", "FoodBowlTrip" })
        bindPick(advanced, "spotTravel", "map-pin", "Camp / beach", { "Farm", "SpotTravel" },
            { { "teleport", "Teleport" }, { "door", "Shop door" } })
        bindSlider(advanced, "failCooldown", "timer", "Retry failed after", { "Farm", "FailureCooldownSeconds" }, 1, 120, 1, "s")
        bindSlider(advanced, "failLimit", "octagon-x", "Fails before rest", { "Farm", "MaxConsecutiveFailures" }, 1, 10, 1, nil)
        bindSlider(advanced, "restMinutes", "timer", "Rest for", { "Farm", "DisableMinutes" }, 0, 60, 1, "min")
        if config.Logging then
            local levels = {}
            for _, level in ipairs(Interface.CONSOLE_LEVELS) do
                table.insert(levels, { level, level })
            end
            bindPick(advanced, "consoleLevel", "scroll-text", "Console shows", { "Logging", "ConsoleLevel" }, levels)
        end
        local supportSection = Window:CreateTabSection("Support", false)
        pcall(function()
            supportSection.Instance.LayoutOrder = -2
        end)
        local supportTab = track(supportSection:CreateTab({ Name = "Support", Icon = I("heart-handshake"), Columns = columns }, "support"))
        local developerBox = supportTab:CreateGroupbox({ Name = "Developer", Icon = I("code"), Column = 1 }, "developer")
        local dev = Interface.DEVELOPER
        local devCard = developerBox:CreateParagraph({
            Name = dev.name .. "  •  " .. dev.user,
            Icon = I("heart"),
            Content = "Made Adopt Victims: plain, readable Luau.\nThank you for using it!",
        }, "devCard")
        task.spawn(function()
            local image = Interface.developerAvatar()
            if not image or not alive then
                return
            end
            for _ = 1, 30 do
                if type(devCard) == "table" and devCard.Instance then
                    break
                end
                task.wait(0.1)
            end
            pcall(function()
                local avatar = Instance.new("ImageLabel")
                avatar.Name = "AmeFarmAvatar"
                avatar.BackgroundTransparency = 1
                avatar.Size = UDim2.fromOffset(52, 52)
                avatar.AnchorPoint = Vector2.new(1, 0.5)
                avatar.Position = UDim2.new(1, -10, 0.5, 0)
                avatar.Image = image
                avatar.ZIndex = 10
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(1, 0)
                corner.Parent = avatar
                avatar.Parent = devCard.Instance
            end)
        end)
        developerBox:CreateButton({
            Name = "Copy Discord invite",
            Icon = I("ph:discord-logo"),
            IndicatorStyle = 1,
            Callback = function()
                copy("Discord", "https://discord.gg/" .. Interface.DISCORD_INVITE)
            end,
        }, "supportDiscord")
        developerBox:CreateButton({
            Name = "Copy GitHub link",
            Icon = I("link"),
            IndicatorStyle = 1,
            Callback = function()
                copy("GitHub", dev.github)
            end,
        }, "github")
        local executorInfo
        local function executorText()
            local name, player, players = "unknown", "?", "?"
            pcall(function()
                name = table.concat({ identifyexecutor() }, " ")
            end)
            pcall(function()
                local me = game:GetService("Players").LocalPlayer
                player = tostring(me.DisplayName or me.Name) .. " (@" .. tostring(me.Name) .. ")"
            end)
            pcall(function()
                players = tostring(#game:GetService("Players"):GetPlayers())
            end)
            local supported = false
            for _, known in ipairs(Interface.SUPPORTED_EXECUTORS) do
                supported = supported or string.find(string.lower(name), string.lower(known), 1, true) ~= nil
            end
            return table.concat({
                T("Executor: %s", name),
                T("Status: %s", T(supported and "supported" or "not tested with this script")),
                T("Player: %s", player),
                T("Server: %s players", players),
                T("Script: v%s", shortVersion),
            }, "\n")
        end
        if not homeTab then
            local changelog = supportTab:CreateGroupbox({ Name = "Changelog", Icon = I("scroll-text"), Column = 1 }, "changelog")
            changelog:CreateParagraph({
                Name = "What's new in v" .. shortVersion,
                Icon = I("sparkles"),
                Content = "• " .. table.concat(Interface.CHANGELOG, "\n• "),
            }, "changes")
            local executorBox = supportTab:CreateGroupbox({ Name = "Executor", Icon = I("cpu"), Column = col(2) }, "executor")
            executorInfo = executorBox:CreateParagraph({ Name = "Your setup", Icon = I("monitor"), Content = executorText() },
                "executorInfo")
        end
        local donate = supportTab:CreateGroupbox({ Name = "Donate", Icon = I("heart"), Column = 1 }, "donate")
        for index, entry in ipairs(Interface.DONATION_LINKS) do
            donate:CreateButton({
                Name = entry.name,
                Icon = I(entry.icon),
                IndicatorStyle = 1,
                Callback = function()
                    copy(entry.name, entry.link)
                end,
            }, "donateLink" .. index)
        end
        if #Interface.GAMEPASSES > 0 then
            local passes = supportTab:CreateGroupbox({ Name = "Game passes", Icon = I("ticket"), Column = 1 }, "passes")
            for index, entry in ipairs(Interface.GAMEPASSES) do
                passes:CreateButton({
                    Name = entry.name,
                    Icon = I("ticket"),
                    IndicatorStyle = 1,
                    Callback = function()
                        pcall(function()
                            game:GetService("MarketplaceService"):PromptGamePassPurchase(game:GetService("Players").LocalPlayer, entry.id)
                        end)
                    end,
                }, "pass" .. index)
            end
        end
        local crypto = supportTab:CreateGroupbox({ Name = "Crypto (tap to copy)", Icon = I("bitcoin"), Column = col(2) }, "crypto")
        crypto:CreateParagraph({
            Name = "Correct network only",
            Icon = I("triangle-alert"),
            Content = "Send each coin only on the network written next to it. Tokens sent on another network are lost.",
        }, "cryptoWarning")
        for index, entry in ipairs(Interface.CRYPTO) do
            crypto:CreateButton({
                Name = entry.name,
                Icon = I(entry.icon),
                IndicatorStyle = 1,
                Callback = function()
                    copy(entry.name, entry.address)
                end,
            }, "crypto" .. index)
        end
        handle.openSettings = function()
            return Interface.openTab(configTab)
        end
        if settings.Theme ~= nil and settings.Theme ~= "Starlight" and settings.Theme ~= "Default" then
            applyTheme(settings.Theme)
        end
        local shown = {}
        function tintIcon(element, color)
            pcall(function()
                element.Instance.Header.Icon.ImageColor3 = paletteColor(color)
            end)
        end
        local function setText(element, key, fields)
            local signature = (fields.Name or "") .. "\n" .. (fields.Content or "")
            if shown[key] ~= signature then
                shown[key] = signature
                pcall(function()
                    element:Set(fields)
                end)
            end
        end
        local function eventText(status)
            local s = type(status) == "table" and status or {}
            return table.concat({
                T("Candy: %s (+%s)", commas(s.candy), commas(s.candyEarned or 0)),
                T("Rusty Keys: %s  •  Twigs: %s", s.rustyKeys and tostring(s.rustyKeys) or "?",
                    s.twigs and tostring(s.twigs) or "?"),
                s.nestTwigs and T("Nest: %s / 8 twigs", tostring(s.nestTwigs)) or T("Nest: ?"),
                s.nextRoundIn and T("Next Ghost Gallery in %s", clock(s.nextRoundIn)) or T("Next Ghost Gallery: unknown yet"),
            }, "\n")
        end
        local dashboardReady, farmCardFrame, farmCard, serverChips = false, nil, nil, nil
        local serverInfo, frames, framesSince = {}, 0, os.clock()
        local function cardColors()
            return { liveColor == "gray" and "witch" or liveColor, "night" }
        end
        local function copyJoinScript()
            local okCopy = pcall(function()
                setclipboard(string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s", '
                    .. 'game:GetService("Players").LocalPlayer)', game.PlaceId, game.JobId))
            end)
            notify("Join script", okCopy and "Copied: run it in your executor to join this server" or "Could not copy",
                okCopy and "copy" or "triangle-alert")
        end
        local function setupDashboard()
            if dashboardReady or not homeTab or not alive then
                return
            end
            dashboardReady = true
            farmCardFrame = Interface.findFarmCard(homeTab)
            local okLayout, box = pcall(Interface.layoutDashboard, homeTab, farmCardFrame)
            if farmCardFrame then
                local okCard, parts = pcall(Interface.makeFarmCard, farmCardFrame)
                farmCard = okCard and parts or nil
                pcall(function()
                    table.insert(connections, farmCardFrame.Interact.MouseButton1Click:Connect(function()
                        Interface.openTab(mainTab)
                    end))
                end)
            end
            pcall(function()
                Interface.localizeTree(homeTab.Instances.Page, { playerUser = true, playerDisplay = true }, connections)
                Interface.localizeTree(homeTab.Instances.Button)
            end)
            local okStrip, chips, strip = pcall(Interface.serverStrip, homeTab)
            if okStrip and chips then
                serverChips = chips
                pcall(function()
                    table.insert(connections, (chips.joinButton or chips.join).MouseButton1Click:Connect(copyJoinScript))
                end)
                pcall(function()
                    table.insert(connections, game:GetService("RunService").Heartbeat:Connect(function()
                        frames += 1
                    end))
                end)
                serverInfo.region = country
                if not country then
                    task.spawn(function()
                        serverInfo.region = Interface.lookupCountry()
                    end)
                end
                if okLayout and box then
                    task.delay(1, function()
                        pcall(Interface.clearStrip, strip, box)
                    end)
                end
            end
        end
        local function readServer()
            local now = os.clock()
            serverInfo.fps = math.floor(frames / math.max(now - framesSince, 0.001) + 0.5)
            frames, framesSince = 0, now
            pcall(function()
                local Players = game:GetService("Players")
                serverInfo.players, serverInfo.maxPlayers = #Players:GetPlayers(), Players.MaxPlayers
            end)
            pcall(function()
                serverInfo.ping = math.floor(game:GetService("Stats").PerformanceStats.Ping:GetValue() + 0.5)
            end)
            pcall(function()
                serverInfo.uptime = workspace.DistributedGameTime
            end)
        end
        local function setLabel(label, key, text)
            if shown[key] ~= text then
                shown[key] = text
                pcall(function()
                    label.Text = text
                end)
            end
        end
        local tick = 0
        refreshStatus = function()
            local okStatus, status = pcall(api.Status)
            status = okStatus and status or nil
            if stateHeader then
                local title, text, state = Interface.stateHeader(status)
                setText(stateHeader, "header", { Name = title, Content = text })
                tintIcon(stateHeader, Interface.STATE_COLORS[state] or "gray")
            end
            for _, row in ipairs(Interface.statusRows(status, rowWidth)) do
                if rowElements[row.key] then
                    setText(rowElements[row.key], "row_" .. row.key, { Name = row.text })
                    if row.dot then
                        tintIcon(rowElements[row.key], Interface.STATE_COLORS[row.state] or "gray")
                    end
                end
            end
            setText(eventInfo, "event", { Content = eventText(status) })
            local webhookOn = type(status) == "table" and status.webhooksOn == true
            setText(hookState, "hook", { Name = webhookOn and T("Webhook: ON") or T("Webhook: OFF (no URL yet)") })
            tintIcon(hookState, webhookOn and "green" or "gray")
            if executorInfo and tick % 10 == 0 then
                setText(executorInfo, "executor", { Content = executorText() })
            end
            if farmCard then
                local okIcons, icons = false, nil
                if type(api.Icons) == "function" then
                    okIcons, icons = pcall(api.Icons)
                end
                pcall(Interface.fillFarmCard, farmCard, status, okIcons and icons or nil)
            end
            if serverChips then
                readServer()
                for key, text in pairs(Interface.serverChipTexts(serverInfo)) do
                    if serverChips[key] then
                        setLabel(serverChips[key], "chip_" .. key, text)
                    end
                end
            end
            local state = type(status) ~= "table" and "gray" or status.stopped and "blood" or not status.farmEnabled and "gray"
                or (not status.ready or status.featuresOn == 0) and "moon" or "green"
            if state ~= liveColor then
                liveColor = state
                pcall(Interface.tintGroupbox, boxes.live, liveColor)
                if farmCardFrame then
                    local tint = Interface.CARD_TINT
                    pcall(Interface.tintFrame, farmCardFrame, cardColors(), tint.from, tint.to, tint.rotation, tint.see)
                end
            end
        end
        function paintAll()
            paint()
            if homeTab then
                setupDashboard()
                pcall(Interface.paintDashboard, homeTab, farmCardFrame and { [farmCardFrame] = cardColors() } or nil)
            end
        end
        task.delay(0.3, paintAll)
        task.delay(1.5, paintAll)
        local queue = {}
        if options.logger and options.logger.OnEntry then
            table.insert(connections, options.logger.OnEntry:Connect(function(level, category, message)
                if not alive or settings.Toasts == false then
                    return
                end
                message = tostring(message)
                for _, toast in ipairs(Interface.TOASTS) do
                    if string.find(message, toast.pattern) then
                        if #queue >= 3 then
                            table.remove(queue, 1)
                        end
                        table.insert(queue, { title = toast.title, content = string.sub(message, 1, 140), icon = toast.icon })
                        break
                    end
                end
            end))
        end
        local descriptionsShown = showDescriptions
        task.spawn(function()
            while alive do
                if tick % 2 == 0 then
                    refreshStatus()
                end
                if (settings.Descriptions ~= false) ~= descriptionsShown then
                    descriptionsShown = settings.Descriptions ~= false
                    rebuild()
                end
                tick += 1
                task.wait(1)
            end
        end)
        task.spawn(function()
            while alive do
                local nextToast = table.remove(queue, 1)
                if nextToast then
                    notify(nextToast.title, nextToast.content, nextToast.icon)
                    task.wait(3.5)
                else
                    task.wait(0.5)
                end
            end
        end)
        Starlight:OnDestroy(function()
            handle.Close()
        end)
        Interface.opened = (Interface.opened or 0) + 1
        handle.startHidden = settings.StartHidden == true and Interface.opened == 1
        if handle.startHidden then
            task.delay(1, function()
                for _, box in pairs(boxes) do
                    if alive and type(box) == "table" and box.Instance then
                        handle.hidden = Interface.hideWindow(box.Instance)
                        return
                    end
                end
            end)
        end
        Interface.current = handle
        notify(Interface.TITLE, touch and T("Ready. Round paw button: hide / show. Square button at the top: full screen. "
            .. "Sliders: tap the number to type.") or T("Ready. %s hides / shows the window.", keybind), "paw-print")
        return handle
    end
    return Interface
end
__moduleSources["Game/GameConstants"] = function(...)
    local GameConstants = {}
    GameConstants.PlaceId = 920587237
    GameConstants.Remotes = {
        Folder = "API",
        DataChanged = "DataAPI/DataChanged",
        DataPartiallyChanged = "DataAPI/DataPartiallyChanged",
        PetAilmentCompleted = "AilmentsAPI/PetAilmentCompleted",
        BabyAilmentCompleted = "AilmentsAPI/BabyAilmentCompleted",
        MinigameMessage = "MinigameAPI/MessageClient",
        EventFolder = "adoptme_new_net",
    }
    GameConstants.DataKeys = {
        Ailments = "ailments_manager",
        Money = "money",
        Equip = "equip_manager",
        Team = "team",
        Interior = "house_interior",
        PetWrappers = "pet_char_wrappers_raw",
        Inventory = "inventory",
        StateManager = "state_manager_raw",
        CharWrapper = "char_wrapper_raw",
        Candy = "candy_2026",
        PetPen = "idle_progression_manager",
        StrayCat = "halloween_2026_stray_cat_manager",
        Crypt = "halloween_2026_crypt_manager",
        PigeonNest = "halloween_2026_jacobean_pigeon_nest_manager",
        GhostCycle = "ghost_clusters_cycle_timestamp",
        Dailies = "dailies_manager",
    }
    GameConstants.PetsFolderName = "Pets"
    GameConstants.PetModelIdAttribute = "StreamingId"
    GameConstants.ClientDataModulePath = { "ClientModules", "Core", "ClientData" }
    GameConstants.Actions = {
        ChooseTeam = { remote = "TeamAPI/ChooseTeam", purpose = "switch your team to Babies (Farm.BabyMode)" },
        FocusPet = { remote = "AdoptAPI/FocusPet", purpose = "pet_me: focus your pet" },
        PetPetted = { remote = "PetAPI/PetPetted", purpose = "pet_me: pet your pet" },
        ProgressPetMe = { remote = "AilmentsAPI/ProgressPetMeAilment", purpose = "pet_me: report the petting" },
        UnfocusPet = { remote = "AdoptAPI/UnfocusPet", purpose = "pet_me: unfocus your pet" },
        DoorEnter = { remote = "AdoptAPI/SendPassiveDoorEnter", purpose = "travel: enter a place (house, salon, cat cafe, main map)" },
        SetLocation = { remote = "LocationAPI/SetLocation", purpose = "travel: move to that place" },
        SubscribeToHouse = { remote = "HousingAPI/SubscribeToHouse", purpose = "travel: load YOUR house when going home" },
        UnsubscribeFromHouse = { remote = "HousingAPI/UnsubscribeFromHouse", purpose = "travel: unload YOUR house when leaving it" },
        MarkEnteredDoorTime = { remote = "AdoptAPI/MarkEnteredDoorTime", purpose = "leaving your house: the game's own door-time mark (no arguments)" },
        PushFurnitureChanges = { remote = "HousingAPI/PushFurnitureChanges", purpose = "leaving your house: sent EMPTY ({}) as the game does; never changes furniture", emptyOnly = true },
        CollectCashback = { remote = "PayAPI/Collect", purpose = "collect your cashback Bucks (Farm.CollectCashback)" },
        ChooseMystery = { remote = "AilmentsAPI/ChooseMysteryAilment", purpose = "mystery: pick a need this script can do" },
        ActivateFurniture = { remote = "HousingAPI/ActivateFurniture", purpose = "use YOUR bed / shower / toilet for your pet or baby",
            answersWhenDone = true },
        ExitSeatStates = { remote = "AdoptAPI/ExitSeatStates", purpose = "get your character (baby) up from furniture" },
        ExitFurnitureUseStates = { remote = "PetAPI/ExitFurnitureUseStates", purpose = "get your pet up if it stays on furniture" },
        EquipItem = { remote = "ToolAPI/Equip", purpose = "hold YOUR food, drink, toy, Rusty Key, Crypt Twig or the loaned Ghost Vacuum; re-equip YOUR pet ({equip_as_last=true}, as the game at spawn); neon fusion: hold each of the 4 pets once" },
        Respawn = { remote = "TeamAPI/Spawn", purpose = "go home fast by respawning (Farm.HomeByRespawn); recover when stuck on the loading screen" },
        UseTool = { remote = "ToolAPI/ServerUseTool", purpose = "eat / drink / throw the item you hold; switch on the Ghost Vacuum (its answer is the vacuum token)" },
        UnequipItem = { remote = "ToolAPI/Unequip", purpose = "put the item away" },
        ActivateInteriorFurniture = { remote = "HousingAPI/ActivateInteriorFurniture", purpose = "sick: talk to the doctor in the Hospital" },
        UnequipStroller = { remote = "AdoptAPI/UnequipStroller", purpose = "ride: put the stroller away" },
        CreatePetObject = { remote = "PetObjectAPI/CreatePetObject", purpose = "give food/drink to your pet, throw a toy for it" },
        ConsumeFoodObject = { remote = "PetAPI/ConsumeFoodObject", purpose = "your pet eats the given food (only if the game did not)" },
        GrabPetObject = { remote = "PetObjectAPI/GrabPetObject", purpose = "your pet catches the toy (only if the game did not)" },
        DropPetObject = { remote = "PetObjectAPI/DropPetObject", purpose = "your pet gives the toy back" },
        PetPenAdd = { remote = "IdleProgressionAPI/AddPet", purpose = "Pet Pen: put one of YOUR growing pets in the pen (Farm.Event.PetPen)" },
        PetPenRemove = { remote = "IdleProgressionAPI/RemovePet", purpose = "Pet Pen: take a FULL GROWN pet out of the pen" },
        PetPenClaim = { remote = "IdleProgressionAPI/CommitAllProgression", purpose = "Pet Pen: CLAIM ALL (the pen's xp and Bucks)" },
        PetPerformance = { remote = "PetAPI/ReplicateActivePerformances", purpose = "pet_me: show the petting animation, as the game does" },
        StrayCatFeed = { remote = "Halloween2026/StrayCatGiftFood", folder = "EventFolder", purpose = "Halloween: give 1 water to the Stray Cat once a day (Farm.Event.StrayCat)" },
        UnlockPadlock = { remote = "Halloween2026/UnlockPadlock", folder = "EventFolder", purpose = "Halloween: use YOUR Rusty Key on a Crypt grave (Farm.Event.Crypt)" },
        PigeonNestTwig = { remote = "Halloween2026/JacobeanPigeonNestContributeTwig", folder = "EventFolder", purpose = "Halloween: put YOUR Crypt Twig in the Hotel nest (Farm.Event.PigeonNest)" },
        MinigameJoin = { remote = "MinigameAPI/AttemptJoin", purpose = "Halloween: join the Ghost Gallery minigame (Farm.Event.GhostGallery)" },
        MinigameLeave = { remote = "MinigameAPI/AttemptJoin", purpose = "Ghost Gallery: leave a round I could not get into (the game's own exit call)",
            leaveOnly = true },
        MinigameMessage = { remote = "MinigameAPI/MessageServer", purpose = "Ghost Gallery: vacuum a ghost or a haunted prop (start / stop only)",
            allowedMessages = { start_contribute = true, stop_contribute = true, start_prop_contribute = true, stop_prop_contribute = true } },
        QuestClaim = { remote = "adoptme_new.modules.Dailies.DailiesNetService:9", folder = "EventFolder",
            purpose = "claim a finished daily quest (Halloween / normal tab) (Farm.Event.Quests)",
            allowedFirstArg = { halloween_2026 = true, vanilla = true } },
        QuestTabReward = { remote = "adoptme_new.modules.Dailies.DailiesNetService:15", folder = "EventFolder",
            purpose = "claim a quest board reward after 3 quests of the day (Rusty Key / egg) (Farm.Event.Quests)",
            allowedFirstArg = { halloween_2026 = true, vanilla = true } },
        OpenGift = { remote = "ShopAPI/OpenGift", purpose = "open YOUR gift (Farm.AutoOpen)" },
        OpenChest = { remote = "LootBoxAPI/ExchangeItemForReward", purpose = "open YOUR chest (Farm.AutoOpen)" },
        ClaimTombSpider = { remote = "Halloween2026/ClaimTombSpider", folder = "EventFolder",
            purpose = "Halloween: take the Mummy Spider at the bottom of the Crypt (Farm.Event.Crypt)" },
        NeonFusion = { remote = "PetAPI/DoNeonFusion", purpose = "neon fusion: 4 of YOUR full grown pets of one kind -> 1 neon (Farm.AutoNeon)" },
        BuyItem = { remote = "ShopAPI/BuyItem", purpose = "buy 1 water / 1 hotdog when you have none; 1 egg (Farm.EggToBuy) when you have no pet that still grows (Farm.BuyEgg); Halloween pets with candy (Farm.Event.CandyPets)" },
    }
    GameConstants.BabiesTeam = "Babies"
    GameConstants.ChooseTeamOptions = { dont_respawn = true, source_for_logging = "avatar_editor" }
    GameConstants.Travel = {
        housing = { door = "MainDoor", spawn = nil, ownHouse = true },
        Salon = { door = "MainDoor", spawn = nil },
        MainMap = { door = "Neighborhood!MainDoor", spawn = "Default" },
        CatCafe = { door = "MainDoor", spawn = nil },
        PizzaShop = { door = "MainDoor", spawn = nil },
        School = { door = "MainDoor", spawn = nil },
        Hospital = { door = "MainDoor", spawn = nil },
        CampingShop = { door = "MainDoor", spawn = nil },
        BeachShop = { door = "MainDoor", spawn = nil },
        BabyShop = { door = "MainDoor", spawn = nil },
        Nursery = { door = "MainDoor", spawn = nil },
        HauntedManor = { door = "MainDoor", spawn = nil },
        TheCrypt = { door = "MainDoor", spawn = nil },
        HauntedHotel = { door = "MainDoor", spawn = nil },
    }
    GameConstants.CharWrapperPlaces = { TheCrypt = true }
    GameConstants.InteriorTalkForAilment = {
        sick = { furniture = "doctor", use = "UseBlock", choice = "Yes" },
    }
    GameConstants.SpotDoor = {
        camping = { place = "CampingShop", exit = { x = -50.4, z = -1197.7 } },
        beach_party = { place = "BeachShop", exit = { x = -704.8, z = -1442.3 } },
        bored = { place = "BabyShop", exit = { x = -457.4, z = -1672.1 } },
    }
    GameConstants.LocationForAilment = {
        salon = "Salon",
        bored = "MainMap",
        cat_cafe = "CatCafe",
        pizza_party = "PizzaShop",
        school = "School",
        sick = "Hospital",
        camping = "MainMap",
        beach_party = "MainMap",
    }
    GameConstants.PlayButtonPath = { "NewsApp", "EnclosingFrame", "MainFrame", "Buttons", "PlayButton" }
    GameConstants.MysteryPreference = { "toilet", "dirty", "sleepy", "hungry", "thirsty", "pet_me", "play", "sick", "cat_cafe",
        "salon", "school", "pizza_party", "camping", "beach_party", "bored", "walk", "ride" }
    GameConstants.MysterySlot = 1
    GameConstants.StrollerCategory = "strollers"
    GameConstants.WalkSeconds = 45
    GameConstants.Spots = {
        camping = { x = -18.443, y = 37.204, z = -1046.005, purpose = "camping: the camp site in the neighborhood" },
        beach_party = { x = -579.456, y = 25.634, z = -1496.408, purpose = "beach_party: the beach in the neighborhood" },
        bored = { x = -401.629, y = 29.779, z = -1760.047, purpose = "bored: the playground in the neighborhood" },
        stray_cat = { x = -243.6, y = 87.0, z = -1118.2, purpose = "Halloween: next to the Stray Cat" },
    }
    GameConstants.SpotForAilment = {
        camping = "camping",
        beach_party = "beach_party",
        bored = "bored",
    }
    GameConstants.HouseInteriorName = "housing"
    GameConstants.HouseExitDestination = "exit_housing"
    GameConstants.HouseExitCameraOffset = { x = 0.68896484375, y = 8.55078125, z = 8.8720703125,
        rx = -0.7369100451469421, ry = 0.05742141604423523, rz = 0.05203080177307129 }
    GameConstants.FullGrownAge = 6
    function GameConstants.kindRank(farm)
        local list = type(farm) == "table" and farm.FarmPetKinds
        if type(list) ~= "table" or #list == 0 then
            return nil
        end
        local rank = {}
        for index, kind in ipairs(list) do
            rank[kind] = rank[kind] or index
        end
        return rank
    end
    function GameConstants.isNeonPet(properties)
        return type(properties) == "table" and (properties.neon == true or properties.mega_neon == true)
    end
    GameConstants.Eggs = {
        "cracked_egg",
        "pet_egg",
        "fairytale_egg_2026_fairytale_egg",
    }
    GameConstants.NeverBuyEggs = { royal_egg = true }
    GameConstants.EggCategory = "pets"
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
    function GameConstants.isOnMainMapArea(p)
        return p.X > -1500 and p.X < 1000 and p.Z > -3000 and p.Z < 0
    end
    GameConstants.HouseFurnitureFolderPath = { "HouseInteriors", "furniture" }
    GameConstants.FurnitureUniqueAttribute = "furniture_unique"
    GameConstants.FurnitureForAilment = {
        sleepy = { "basicbed" },
        dirty = { "stylishshower", "modernshower", "cheap_pet_bathtub_tutorial" },
        toilet = { "toilet" },
    }
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
    GameConstants.ItemCategory = "food"
    GameConstants.ItemsForAilment = {
        hungry = { "sandwich-default", "cheese", "hotdog" },
        thirsty = { "water", "chocolate_milk" },
    }
    GameConstants.BuyForAilment = {
        thirsty = { category = "food", ids = { "water" }, options = {}, setting = "BuyWater" },
        hungry = { category = "food", ids = { "hotdog" }, options = { buy_count = 1 }, setting = "BuyFood" },
    }
    GameConstants.PetObjectsFolderName = "PetObjects"
    GameConstants.FoodObjectCreator = "__Enum_PetObjectCreatorType_2"
    GameConstants.ToyObjectCreator = "__Enum_PetObjectCreatorType_1"
    GameConstants.ThrowToyReaction = "ThrowToyReaction"
    GameConstants.ToyCategory = "toys"
    GameConstants.ToysForPlay = { "squeaky_bone_default" }
    GameConstants.AgePotions = { "pet_age_potion", "tiny_pet_age_potion" }
    GameConstants.GiftCategory = "gifts"
    GameConstants.GiftPatterns = { gift = "gift$", chest = "_chest$" }
    GameConstants.Event = {
        RustyKey = "halloween_2026_rusty_key",
        Twig = "halloween_2026_twig",
        Vacuum = "halloween_2026_ghost_vacuum",
        NestTwigs = 8,
        CatFood = { "water", "chocolate_milk" },
        Ladder = "ladder",
        GraveValue = { candy_corn_pile_ginormous = 3, candy_corn_pile_small = 2, twig = 1 },
        OpenedIdPerFloor = 16,
        PetPenSlots = 4,
        MinigameId = "ghost_clusters",
        JoinZoneTeleportPath = { "StaticMap", "TeleportLocations", "ghost_clusters" },
        JoinZoneModelPath = { "Interiors", "HauntedManor", "GhostClustersMinigameJoinZone" },
        JoinZoneRadius = 15,
        MinigameInteriorPrefix = "ManorMinigameInterior",
        RoundSeconds = 600,
        GhostsFolder = "GhostClustersVisuals",
        GhostNamePattern = "^Ghost_%a+_([%x%-]+)$",
        BossSize = "Large",
        HoldBelowStuds = 50,
        PropStandOff = 10,
        QuestTabs = { "halloween_2026", "vanilla" },
        QuestsPerBoardReward = 3,
        CryptRewards = { "ladder", "twig", "candy_corn_pile_ginormous", "candy_corn_pile_small" },
    }
    GameConstants.FarmPotions = { "pet_age_potion", "tiny_pet_age_potion", "pet_bonus_bucks_potion" }
    function GameConstants.needOn(farm, kind)
        if type(farm) ~= "table" then
            return false
        end
        local tasks = type(farm.Tasks) == "table" and farm.Tasks or {}
        local auto = farm.AutoNeeds
        if type(auto) ~= "table" then
            return tasks[kind] == true
        end
        if auto.Enabled ~= true or tasks[kind] == false then
            return false
        end
        for _, skipped in ipairs(type(auto.Skip) == "table" and auto.Skip or {}) do
            if skipped == kind then
                return false
            end
        end
        return true
    end
    return GameConstants
end
__moduleSources["Game/GameData"] = function(...)
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
        self.SnapshotSource = nil
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
        node[path[#path]] = deepCopy(change.serialized_partial_value)
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
                return
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
        local inventory = self._data[GameConstants.DataKeys.Inventory]
        local pet = type(inventory) == "table" and type(inventory.pets) == "table" and inventory.pets[petUnique]
        if type(pet) == "table" then
            return pet.kind or pet.id
        end
        return nil
    end
    function GameData:isPetEquipped(petUnique)
        local equip = self._data[GameConstants.DataKeys.Equip]
        if type(equip) ~= "table" or type(equip.pets) ~= "table" then
            return true
        end
        for _, pet in pairs(equip.pets) do
            if type(pet) == "table" and pet.unique == petUnique then
                return true
            end
        end
        return false
    end
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
    function GameData:petPenPets()
        local pen = self._data[GameConstants.DataKeys.PetPen]
        local result = {}
        for unique, record in pairs(type(pen) == "table" and type(pen.active_pets) == "table" and pen.active_pets or {}) do
            result[tostring(unique)] = type(record) == "table" and record or {}
        end
        return result
    end
    function GameData:isPetNeon(unique)
        local inventory = self._data[GameConstants.DataKeys.Inventory]
        local pets = type(inventory) == "table" and inventory.pets
        local pet = type(pets) == "table" and pets[unique]
        return type(pet) == "table" and GameConstants.isNeonPet(pet.properties)
    end
    function GameData:growablePets(preferNeon, kindRank, youngestFirst)
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
                    age = 0
                end
                if age and age < GameConstants.FullGrownAge and not GameConstants.NotFarmablePets[kind] then
                    table.insert(result, { unique = tostring(pet.unique or key), age = age, kind = kind,
                        neon = GameConstants.isNeonPet(properties) })
                end
            end
        end
        table.sort(result, function(a, b)
            local ra = kindRank and kindRank[a.kind] or math.huge
            local rb = kindRank and kindRank[b.kind] or math.huge
            if ra ~= rb then
                return ra < rb
            end
            if preferNeon and a.neon ~= b.neon then
                return a.neon
            end
            if a.age ~= b.age then
                if youngestFirst then
                    return a.age < b.age
                end
                return a.age > b.age
            end
            return a.unique < b.unique
        end)
        return result
    end
    function GameData:neonFusionGroups(exclude, mega)
        local inventory = self._data[GameConstants.DataKeys.Inventory]
        local pets = type(inventory) == "table" and inventory.pets
        local inPen = self:petPenPets()
        local groups = {}
        for key, pet in pairs(type(pets) == "table" and pets or {}) do
            if type(pet) == "table" and type(pet.properties) == "table" then
                local unique = tostring(pet.unique or key)
                local kind = tostring(pet.kind or pet.id or "?")
                local age = tonumber(pet.properties.age)
                local fits
                if mega then
                    fits = pet.properties.neon == true and pet.properties.mega_neon ~= true
                else
                    fits = not GameConstants.isNeonPet(pet.properties)
                end
                if age == GameConstants.FullGrownAge and fits and not inPen[unique]
                    and not (exclude and exclude[kind]) and not GameConstants.NotFarmablePets[kind] then
                    groups[kind] = groups[kind] or {}
                    table.insert(groups[kind], unique)
                end
            end
        end
        for _, list in pairs(groups) do
            table.sort(list)
        end
        return groups
    end
    function GameData:neonCountOfKind(kind)
        local inventory = self._data[GameConstants.DataKeys.Inventory]
        local pets = type(inventory) == "table" and inventory.pets
        local n = 0
        for _, pet in pairs(type(pets) == "table" and pets or {}) do
            if type(pet) == "table" and tostring(pet.kind or pet.id) == kind and type(pet.properties) == "table"
                and pet.properties.neon == true then
                n += 1
            end
        end
        return n
    end
    function GameData:megaCountOfKind(kind)
        local inventory = self._data[GameConstants.DataKeys.Inventory]
        local pets = type(inventory) == "table" and inventory.pets
        local n = 0
        for _, pet in pairs(type(pets) == "table" and pets or {}) do
            if type(pet) == "table" and tostring(pet.kind or pet.id) == kind and type(pet.properties) == "table"
                and pet.properties.mega_neon == true then
                n += 1
            end
        end
        return n
    end
    function GameData:isPetMega(unique)
        local inventory = self._data[GameConstants.DataKeys.Inventory]
        local pets = type(inventory) == "table" and inventory.pets
        local pet = type(pets) == "table" and pets[unique]
        return type(pet) == "table" and type(pet.properties) == "table" and pet.properties.mega_neon == true
    end
    function GameData:petInventoryKnown()
        local inventory = self._data[GameConstants.DataKeys.Inventory]
        return type(inventory) == "table" and type(inventory.pets) == "table"
    end
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
__moduleSources["Game/GameIcons"] = function(...)
    local GameIcons = {}
    GameIcons.__index = GameIcons
    GameIcons.KNOWN = {
        bucks = { path = { "Resources", "BucksBillboard", "BillboardGui", "Frame", "ImageLabel" }, id = 3577407233 },
        candy = { path = { "Resources", "CRYPT_PIECES", "Crypt_2026_Floor03", "Game", "RewardSign", "SurfaceGui", "Frame",
            "RewardTemplate", "Icon" }, id = 14845052425 },
        home = { path = { "Resources", "HomeBillboard", "ImageLabel" }, id = 2000934070 },
    }
    local CURRENCY_TRIES = 10
    local SEARCH_GAP = 20
    function GameIcons.new(logger, clock)
        local self = setmetatable({}, GameIcons)
        self._logger = logger
        self._clock = clock or os.clock
        self._items = {}
        self._currency = {}
        self._tries = {}
        self._lastTry = {}
        return self
    end
    function GameIcons.image(value)
        if type(value) == "number" then
            return "rbxassetid://" .. math.floor(value)
        end
        if type(value) == "string" and (string.find(value, "^rbxassetid://%d+") or string.find(value, "^rbxasset://")
            or string.find(value, "^https?://")) then
            return value
        end
        return nil
    end
    function GameIcons.assetId(image)
        if type(image) ~= "string" then
            return nil
        end
        return tonumber(string.match(image, "^rbxassetid://(%d+)") or string.match(image, "[?&]id=(%d+)"))
    end
    function GameIcons:_db()
        if self._dbState ~= nil then
            return self._dbState or nil
        end
        local ok, db = pcall(function()
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local fsys = ReplicatedStorage:FindFirstChild("Fsys")
            if fsys then
                local loader = require(fsys)
                if type(loader) == "table" and type(loader.load) == "function" then
                    local inventory = loader.load("InventoryDB")
                    if type(inventory) == "table" then
                        return inventory
                    end
                end
            end
            local clientDB = ReplicatedStorage:FindFirstChild("ClientDB")
            local module = clientDB and clientDB:FindFirstChild("InventoryDB", true)
            if module and module:IsA("ModuleScript") then
                local inventory = require(module)
                if type(inventory) == "table" then
                    return inventory
                end
            end
            return nil
        end)
        self._dbState = ok and type(db) == "table" and db or false
        if not self._dbState and self._logger then
            self._logger:debug("Icons", "The game's item list was not found: the window keeps its own icons")
        end
        return self._dbState or nil
    end
    function GameIcons:known(key)
        local entry = GameIcons.KNOWN[key]
        if not entry then
            return nil
        end
        if self._known and self._known[key] then
            return self._known[key]
        end
        local picture
        pcall(function()
            local node = game:GetService("ReplicatedStorage")
            for _, name in ipairs(entry.path) do
                node = node and node:FindFirstChild(name)
            end
            if node and (node:IsA("ImageLabel") or node:IsA("ImageButton")) then
                picture = GameIcons.image(node.Image)
            end
        end)
        picture = picture or GameIcons.image(entry.id)
        self._known = self._known or {}
        self._known[key] = picture
        return picture
    end
    function GameIcons:picture(name)
        if type(name) ~= "string" then
            return nil
        end
        local kind, key = string.match(name, "^(%a+):(.+)$")
        if kind == "game" then
            return self:known(key)
        elseif kind == "item" then
            return self:item(key)
        end
        return nil
    end
    function GameIcons:item(id)
        if type(id) ~= "string" then
            return nil
        end
        if self._items[id] ~= nil then
            return self._items[id] or nil
        end
        local found = false
        local db = self:_db()
        if db then
            pcall(function()
                for _, category in pairs(db) do
                    local entry = type(category) == "table" and rawget(category, id)
                    if type(entry) == "table" and GameIcons.image(entry.image) then
                        found = GameIcons.image(entry.image)
                        return
                    end
                end
            end)
        end
        self._items[id] = found
        return found or nil
    end
    function GameIcons.nearestPicture(label)
        local best, bestDistance
        local center = label.AbsolutePosition + label.AbsoluteSize / 2
        for _, scope in ipairs({ label.Parent, label.Parent and label.Parent.Parent }) do
            if scope and not best then
                for _, item in ipairs(scope:GetDescendants()) do
                    if (item:IsA("ImageLabel") or item:IsA("ImageButton")) and item.Visible and item.Image ~= "" then
                        local size = item.AbsoluteSize
                        local ratio = size.Y > 0 and size.X / size.Y or 0
                        if ratio > 0.6 and ratio < 1.6 and size.Y <= label.AbsoluteSize.Y * 3 then
                            local distance = ((item.AbsolutePosition + size / 2) - center).Magnitude
                            if not best or distance < bestDistance then
                                best, bestDistance = item.Image, distance
                            end
                        end
                    end
                end
            end
        end
        return best
    end
    local function digits(text)
        return (string.gsub(tostring(text or ""), "%D", ""))
    end
    function GameIcons:currency(key, amount)
        if self._currency[key] then
            return self._currency[key]
        end
        amount = tonumber(amount)
        if not amount or amount < 10 then
            return nil
        end
        local now = self._clock()
        local tries = self._tries[key] or 0
        if tries >= CURRENCY_TRIES or (self._lastTry[key] and now - self._lastTry[key] < SEARCH_GAP) then
            return nil
        end
        self._tries[key], self._lastTry[key] = tries + 1, now
        local want = tostring(math.floor(amount))
        local ok, picture = pcall(function()
            local playerGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
            for _, screen in ipairs(playerGui and playerGui:GetChildren() or {}) do
                if screen:IsA("ScreenGui") and screen.Enabled then
                    for _, label in ipairs(screen:GetDescendants()) do
                        if label:IsA("TextLabel") and label.Visible and digits(label.Text) == want then
                            local found = GameIcons.nearestPicture(label)
                            if found then
                                return found
                            end
                        end
                    end
                end
            end
            return nil
        end)
        if ok and picture then
            self._currency[key] = picture
            return picture
        end
        return nil
    end
    return GameIcons
end
__moduleSources["Game/PetLocator"] = function(...)
    local import = ...
    local GameConstants = import("Game/GameConstants")
    local PetLocator = {}
    PetLocator.__index = PetLocator
    function PetLocator.new(gameData)
        return setmetatable({ _gameData = gameData }, PetLocator)
    end
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
__moduleSources["Game/PlayerSync"] = function(...)
    local import = ...
    local GameConstants = import("Game/GameConstants")
    local PlayerSync = {}
    local KEYS = GameConstants.DataKeys
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
__moduleSources["Game/AilmentTracker"] = function(...)
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
        self._previous = {}
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
            mysterySeed = type(mystery) == "table" and mystery.random_seed or nil,
            kind = tostring(type(rawEntry) == "table" and rawEntry.kind or kindKey),
            rate = rate,
            inProgress = rate > 0,
            progress = type(rawEntry) == "table" and tonumber(rawEntry.progress) or 0,
            createdAt = type(rawEntry) == "table" and tonumber(rawEntry.created_timestamp) or nil,
            preferredItem = type(preference) == "table" and preference.item_kind or nil,
        }
    end
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
        local existing = self._gameData:get(GameConstants.DataKeys.Ailments)
        if existing ~= nil then
            self:_onAilmentsChanged(existing)
        end
        local apiFolder = ReplicatedStorage:FindFirstChild(GameConstants.Remotes.Folder)
        local petCompleted = apiFolder and apiFolder:FindFirstChild(GameConstants.Remotes.PetAilmentCompleted)
        if petCompleted and petCompleted:IsA("RemoteEvent") then
            maid:Give(petCompleted.OnClientEvent:Connect(function(petUnique, kind, rewards)
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
__moduleSources["Game/Interaction"] = function(...)
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
        table.insert(lines, "LOCAL teleport of your character next to the Stray Cat (Halloween map), into the Ghost Gallery join circle in the Haunted Manor (where the popup's Yes puts you) and, inside the minigame only, 50 studs under the ghost it vacuums (held every frame, back on the floor after the round) (Farm.Event)")
        table.insert(lines, "LOCAL virtual click — only when Roblox says you are idle, to avoid the 20-minute kick (Farm.AntiAfk)")
        table.insert(lines, "ROBLOX rejoin of a server of this game (TeleportService) — only after 3 min with no place / no character, e.g. a white screen in a dead minigame (Farm.AutoRejoin)")
        return lines
    end
    function Interaction.virtualClick()
        return pcall(function()
            local virtualUser = game:GetService("VirtualUser")
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end
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
                vim:SendTouchEvent(1, 0, x, y)
                task.wait(0.1)
                vim:SendTouchEvent(1, 2, x, y)
            else
                vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
                task.wait(0.1)
                vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
            end
        end)
        return ok, ok and "" or tostring(err)
    end
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
        local canCheck = true
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
    function Interaction:teleportToJoinZone()
        local E = GameConstants.Event
        local function find(path)
            local node = workspace
            for _, name in ipairs(path) do
                node = node and node:FindFirstChild(name)
            end
            return node
        end
        local spot = find(E.JoinZoneTeleportPath)
        local character = game:GetService("Players").LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not spot or not spot:IsA("BasePart") or not root then
            return false, not spot and "join circle spot not found" or "no character"
        end
        self._sent += 1
        self._state:set("farm.actionsSent", self._sent, "Interaction")
        local ok, err = pcall(function()
            local p = spot.Position
            character:PivotTo(CFrame.new(p.X, p.Y + 1.5, p.Z))
        end)
        if not ok then
            return false, tostring(err)
        end
        local now = root.Position
        local dx, dz = now.X - spot.Position.X, now.Z - spot.Position.Z
        return math.sqrt(dx * dx + dz * dz) <= E.JoinZoneRadius, "not in the circle after the teleport"
    end
    function Interaction:keepNear(provider)
        local stats = { corrections = 0 }
        local running = true
        local players = game:GetService("Players")
        local function myRoot()
            local character = players.LocalPlayer.Character
            return character and character:FindFirstChild("HumanoidRootPart"), character
        end
        local startRoot = myRoot()
        local startSpot = startRoot and startRoot.Position or nil
        local lastSpot = nil
        local released = false
        local function hold(spot)
            local root, character = myRoot()
            if not root or released then
                return
            end
            local here = root.Position
            local fx, fy, fz = here.X - spot.X, here.Y - spot.Y, here.Z - spot.Z
            if fx * fx + fy * fy + fz * fz > 250 * 250 then
                released = true
                return
            end
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end)
            local now = root.Position
            local dx, dy, dz = now.X - spot.X, now.Y - spot.Y, now.Z - spot.Z
            if dx * dx + dy * dy + dz * dz <= 1 then
                return
            end
            if pcall(function()
                character:PivotTo(CFrame.new(spot.X, spot.Y, spot.Z))
            end) then
                stats.corrections += 1
            end
        end
        local function step()
            local position, mode = provider()
            if position == false then
                released = true
                return
            end
            if position ~= nil and type(position.X) == "number" and type(position.Y) == "number" and type(position.Z) == "number" then
                if mode == "below" then
                    lastSpot = Vector3.new(position.X, position.Y - GameConstants.Event.HoldBelowStuds, position.Z)
                else
                    local root = myRoot()
                    local from = root and root.Position or position
                    local off = tonumber(mode) or 10
                    local dx, dz = from.X - position.X, from.Z - position.Z
                    local length = math.sqrt(dx * dx + dz * dz)
                    local x = length > 0.1 and position.X + dx / length * off or position.X + off
                    local z = length > 0.1 and position.Z + dz / length * off or position.Z
                    lastSpot = Vector3.new(x, startSpot and startSpot.Y or from.Y, z)
                end
            end
            if lastSpot then
                hold(lastSpot)
            end
        end
        local connection
        local okSignal = pcall(function()
            connection = game:GetService("RunService").Heartbeat:Connect(function()
                if running then
                    step()
                end
            end)
        end)
        if not okSignal or not connection then
            task.spawn(function()
                while running do
                    step()
                    task.wait(0.05)
                end
            end)
        end
        local function stop(back)
            if not running then
                return
            end
            running = false
            if connection then
                connection:Disconnect()
                connection = nil
            end
            local root, character = myRoot()
            local stillHeld = false
            if root and lastSpot and not released then
                local here = root.Position
                local dx, dy, dz = here.X - lastSpot.X, here.Y - lastSpot.Y, here.Z - lastSpot.Z
                stillHeld = dx * dx + dy * dy + dz * dz <= 30 * 30
            end
            if back ~= false and stillHeld and startSpot then
                pcall(function()
                    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    character:PivotTo(CFrame.new(startSpot.X, startSpot.Y + 2, startSpot.Z))
                end)
            end
        end
        return stop, stats, step
    end
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
    function Interaction:walkAround(seconds, done, tick)
        local character = game:GetService("Players").LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root then
            return false
        end
        self._logger:debug("Action", "Walking long diagonal legs for up to " .. seconds .. " s")
        if root.Anchored then
            local waited = 0
            while root.Anchored and waited < 3 do
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
        local rx, rz = -fz, fx
        local LEG = 30
        local points = {
            Vector3.new(start.X + (fx - rx) * LEG, start.Y, start.Z + (fz - rz) * LEG),
            Vector3.new(start.X + (fx + rx) * LEG, start.Y, start.Z + (fz + rz) * LEG),
            Vector3.new(start.X, start.Y, start.Z),
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
                humanoid:MoveTo(target)
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
                        break
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
            for _ = 1, 12 do
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
        if action.leaveOnly then
            local first, second = ...
            if select("#", ...) ~= 2 or type(first) ~= "string" or string.sub(first, 1, 15) ~= "ghost_clusters:" or second ~= false then
                error("Interaction: " .. actionName .. " may only be sent as (\"ghost_clusters::<id>\", false)", 2)
            end
        end
        if action.allowedMessages then
            local _, message = ...
            if not action.allowedMessages[message] then
                error("Interaction: " .. actionName .. " may not send message " .. tostring(message), 2)
            end
        end
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
                return true, "pending"
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
__moduleSources["Game/Travel"] = function(...)
    local import = ...
    local Util = import("Core/Util")
    local GameConstants = import("Game/GameConstants")
    local Players = game:GetService("Players")
    local Travel = {}
    Travel.__index = Travel
    local DOOR_TO_LOCATION_DELAY = 1
    local ARRIVAL_TIMEOUT_SECONDS = 12
    function Travel.new(logger, state, interaction, farmConfig)
        return setmetatable({ _logger = logger, _state = state, _interaction = interaction, _farmConfig = farmConfig }, Travel)
    end
    function Travel:canGoTo(destination)
        return GameConstants.Travel[destination] ~= nil
    end
    function Travel:isAt(destination)
        local interior = self._state:get("player.interior")
        return type(interior) == "string" and string.sub(interior, 1, #destination) == destination
    end
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
    local function gameDoorId(recipe)
        return (string.gsub(recipe.door, "!", "/"))
    end
    function Travel:_waitArrival(destination, seconds)
        local deadline = Util.now() + seconds
        while Util.now() < deadline do
            if self:isAt(destination) then
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
        if recipe.ownHouse and self._farmConfig.HomeByRespawn ~= false then
            self._logger:info("Travel", "Going home by respawn (now in " .. tostring(before) .. ")")
            local sent = self._interaction:send("Respawn")
            if sent and self:_waitArrival(destination, ARRIVAL_TIMEOUT_SECONDS + 5) then
                self._logger:info("Travel", "Arrived: " .. tostring(self._state:get("player.interior")) .. " (respawn)")
                return true
            end
            self._logger:info("Travel", "Respawn did not bring me home: using the game's door instead")
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
        if destination ~= "MainMap" and self:isAt("TheCrypt") then
            local module = self:_interiorsModule()
            if module then
                self._logger:info("Travel", "Leaving the Crypt first (its door to the main map)")
                task.spawn(pcall, module.enter, "MainMap", "TheCrypt/MainDoor", {})
                local deadline = Util.now() + 15
                while Util.now() < deadline and not self:isAt("MainMap") do
                    task.wait(0.25)
                end
                if self:isAt("MainMap") and self:_gameTravel(destination, recipe) then
                    return true
                end
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
__moduleSources["Game/Furniture"] = function(...)
    local import = ...
    local GameConstants = import("Game/GameConstants")
    local Players = game:GetService("Players")
    local Furniture = {}
    Furniture.__index = Furniture
    function Furniture.new(gameData, state)
        return setmetatable({ _gameData = gameData, _state = state }, Furniture)
    end
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
__moduleSources["Game/Tasks"] = function(...)
    local import = ...
    local GameConstants = import("Game/GameConstants")
    local Util = import("Core/Util")
    local ensurePetModel
    local Players = game:GetService("Players")
    local Tasks = {}
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
    local LOCATION_START_SECONDS = 10
    local LOCATION_EXTRA_SECONDS = 20
    local SPOT_WAIT_BEFORE_MOVE_SECONDS = 6
    local NEAR_SPOT_STUDS = 20
    local function nearSpot(spotName, studs)
        local spot = GameConstants.Spots[spotName]
        local character = Players.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not spot or not root or not root.Position then
            return false
        end
        local p = root.Position
        return math.sqrt((p.X - spot.x) ^ 2 + (p.Z - spot.z) ^ 2) <= studs
    end
    Tasks._nearSpot = nearSpot
    local isOnMainMapArea = GameConstants.isOnMainMapArea
    Tasks._isOnMainMapArea = isOnMainMapArea
    local function waitForCharacter(ctx, seconds)
        return ctx.waitUntil(function()
            local character = Players.LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            return root ~= nil
        end, seconds)
    end
    local function equipPetAgain(ctx, unique)
        if not unique then
            return false, "no pet known"
        end
        if not waitForCharacter(ctx, 10) then
            return false, "no character"
        end
        task.wait(2)
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
                local door = spotName and ctx.farmConfig.SpotTravel == "door" and GameConstants.SpotDoor[spotName] or nil
                local useTeleport = spotName and ctx.farmConfig.SpotTravel == "teleport"
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
                if useTeleport and nearSpot(spotName, NEAR_SPOT_STUDS) then
                    ctx.logger:info("Tasks", "Already at the " .. spotName .. " spot: no teleport")
                    useTeleport, door = false, nil
                end
                if useTeleport then
                    task.wait(1)
                    local moved, moveReason = ctx.interaction:teleportTo(spotName)
                    ctx.logger:info("Tasks", "Teleport to " .. spotName .. ": " .. (moved and "ok" or tostring(moveReason)))
                    if moved then
                        door = nil
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
                local function hasStarted()
                    local current = ctx.currentGroup(group.kind)
                    return current == nil or current.anyInProgress
                end
                local talk = GameConstants.InteriorTalkForAilment[group.kind]
                local started
                if talk then
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
            if ctx.setWaiting then
                ctx.setWaiting(true)
            end
            while true do
                if current == nil then
                    local drop = handleDrop()
                    if drop == "fail" then
                        return false, "the pet was unequipped (its need is hidden, not completed)"
                    elseif drop == "no" then
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
                        return true
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
            local buysThisSession = ctx.gameData.buysThisSession or 0
            local limit = ctx.farmConfig.MaxBuysPerSession
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
    local PET_EAT_SECONDS = 10
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
                break
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
                    local bowlFirst = entry.owner == "pet" and group.kind == "hungry" and not entry.triedBowl and not ctx.side
                    if bowlFirst and not ctx.farmConfig.FoodBowlTrip and ctx.travel
                        and not ctx.travel:isAt(GameConstants.HouseInteriorName)
                        and ctx.gameData:findItems(GameConstants.ItemCategory, GameConstants.ItemsForAilment[group.kind])[1] ~= nil then
                        entry.triedBowl = true
                        ctx.logger:info("Tasks", "Food in your backpack: feeding here, no trip home for the bowl (Farm.FoodBowlTrip)")
                    end
                    if entry.owner == "pet" and group.kind == "hungry" and not entry.triedBowl and not ctx.side then
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
    Tasks.mystery = {
        id = "mystery",
        handles = function(kind)
            return kind == "mystery"
        end,
        timeoutSeconds = 90,
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
                local doable = kind ~= "mystery" and Tasks.findFor(kind) ~= nil and GameConstants.needOn(ctx.farmConfig, kind)
                if doable and (entry.mysteryOptions == nil or offered[kind]) and not ctx.findEntry(kind, "pet", entry.petUnique) then
                    table.insert(choices, kind)
                end
            end
            if #choices == 0 then
                return false, "no doable need among the mystery options"
            end
            ctx.logger:info("Tasks", string.format("Mystery: pool %s, seed %s, trying %d kinds",
                table.concat(entry.mysteryOptions or {}, ","), tostring(entry.mysterySeed), #choices))
            local started, tries = Util.now(), 0
            for index = 1, #choices do
                local kind = choices[index]
                for slot = 1, 3 do
                    if Util.now() - started > 75 then
                        return false, "mystery did not change into a chosen need"
                    end
                    tries += 1
                    ctx.logger:debug("Tasks", string.format("Mystery: choosing %s (card %d)", kind, slot))
                    ctx.interaction:send("ChooseMystery", entry.petUnique, "mystery", slot, kind)
                    if ctx.waitUntil(function()
                        return ctx.findEntry("mystery", "pet", entry.petUnique) == nil
                            and ctx.findEntry(kind, "pet", entry.petUnique) ~= nil
                    end, 1.2) then
                        ctx.logger:info("Tasks", string.format("Mystery accepted: %s on card %d (try %d, seed %s)", kind, slot,
                            tries, tostring(entry.mysterySeed)))
                        return true
                    end
                    if not ctx.findEntry("mystery", "pet", entry.petUnique) then
                        return true
                    end
                end
            end
            return false, "mystery did not change into a chosen need"
        end,
    }
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
                    if tickCount % 4 == 0 then
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
    Tasks.recover = {
        id = "recover",
        handles = function()
            return false
        end,
        timeoutSeconds = 40,
        run = function(ctx)
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
__moduleSources["Game/Minigame"] = function(...)
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
    function Minigame:reset()
        self.joinAcceptedAt = nil
        self.join = nil
        self.enter = nil
        self.score = 0
        self.scoreCount = 0
        self.lastScoreAt = nil
        self.leave = nil
        self.haunted = {}
        self.propProgress = {}
        self.propsResolved = 0
        self.bossOut = false
    end
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
__moduleSources["Game/EventTasks"] = function(...)
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
    function EventTasks.cryptPlan(crypt, preferTwig)
        if type(crypt) ~= "table" or type(crypt.floors) ~= "table" then
            return nil, "crypt data not known yet"
        end
        if preferTwig then
            local twig = EventTasks.reachableTwigGrave(crypt)
            if twig then
                return twig
            end
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
        if #sortedNumberKeys(crypt.floors) > 0 then
            return { spider = true }
        end
        return nil, "no Crypt floors in your data yet"
    end
    function EventTasks.cryptPick(crypt, wants, preferTwig)
        if type(wants) ~= "table" or #wants == 0 then
            return EventTasks.cryptPlan(crypt, preferTwig)
        end
        if type(crypt) ~= "table" or type(crypt.floors) ~= "table" then
            return nil, "crypt data not known yet"
        end
        if preferTwig then
            local twig = EventTasks.reachableGrave(crypt, "twig")
            if twig then
                return twig
            end
        end
        for _, want in ipairs(wants) do
            if want == E.Ladder then
                local plan = EventTasks.cryptPlan(crypt)
                if plan then
                    return plan
                end
            else
                local grave = EventTasks.reachableGrave(crypt, want)
                if grave then
                    return grave
                end
            end
        end
        return nil, "no grave with " .. table.concat(wants, " / ") .. " left on the floors you can reach"
    end
    function EventTasks.reachableTwigGrave(crypt)
        return EventTasks.reachableGrave(crypt, "twig")
    end
    function EventTasks.reachableGrave(crypt, reward)
        if type(crypt) ~= "table" or type(crypt.floors) ~= "table" then
            return nil
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
                local ladderOpen, hasLadder = false, false
                for _, index in ipairs(sortedNumberKeys(graves)) do
                    local rewardHere = lookup(graves, index)
                    local isOpen = opened[floor * E.OpenedIdPerFloor + index] == true
                    local wanted = rewardHere == reward or (reward == "twig" and rewardHere == E.Twig)
                    if wanted and rewardHere ~= E.Ladder then
                        if not isOpen then
                            return { floor = floor, grave = index, reward = reward }
                        end
                    elseif rewardHere == E.Ladder then
                        hasLadder = true
                        ladderOpen = isOpen
                    end
                end
                if hasLadder and not ladderOpen then
                    return nil
                end
            end
        end
        return nil
    end
    function EventTasks.nestState(nest, held, keys)
        if type(nest) ~= "table" then
            return "UNKNOWN", 0, held or 0
        end
        local placed = tonumber(nest.twigs_contributed) or 0
        held = held or 0
        if placed >= E.NestTwigs then
            return "COMPLETE", placed, held
        elseif placed + held >= E.NestTwigs then
            return "BUILD_NEST", placed, held
        elseif (keys or 0) > 0 then
            return "COLLECT_TWIGS", placed, held
        end
        return "WAIT_KEY", placed, held
    end
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
                if tab.reward_claimed == false and (tonumber(tab.total_dailies_completed_today) or 0) >= E.QuestsPerBoardReward then
                    table.insert(list, { action = "QuestTabReward", tab = tabName })
                end
            end
        end
        return list
    end
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
    local function hold(ctx, unique, category)
        local ok, reason = ctx.interaction:send("EquipItem", unique, {})
        if not ok then
            return false, "could not hold the item: " .. tostring(reason)
        end
        ctx.maid:Give(function()
            if ctx.gameData:itemUsesLeft(category, unique) ~= nil then
                ctx.interaction:send("UnequipItem", unique, nil)
            end
        end)
        return true
    end
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
            local plan = EventTasks.penPlan(ctx.gameData:petPenPets(),
                ctx.gameData:growablePets(ctx.farmConfig.PreferNeon == true, GameConstants.kindRank(ctx.farmConfig)), keep, slots)
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
    EventTasks.crypt = {
        id = "crypt",
        timeoutSeconds = 90,
        run = function(ctx)
            local key = ctx.gameData:itemsOfId(TOYS, E.RustyKey)[1]
            local nestState = EventTasks.nestState(ctx.gameData:get(KEYS.PigeonNest),
                #ctx.gameData:itemsOfId(TOYS, E.Twig), key and 1 or 0)
            local preferTwig = ctx.farmConfig.Event.AutoNest ~= false and nestState == "COLLECT_TWIGS"
            local plan, why = EventTasks.cryptPick(ctx.gameData:get(KEYS.Crypt), ctx.farmConfig.Event.CryptOpen, preferTwig)
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
            if preferTwig then
                local _, placedNow, heldNow = EventTasks.nestState(ctx.gameData:get(KEYS.PigeonNest),
                    #ctx.gameData:itemsOfId(TOYS, E.Twig), 0)
                ctx.logger:info("AutoNest", string.format("Twig progress: %d/%d", placedNow + heldNow, E.NestTwigs))
            end
            return true
        end,
    }
    EventTasks.pigeonNest = {
        id = "pigeon_nest",
        timeoutSeconds = 150,
        run = function(ctx)
            local function placed()
                local data = ctx.gameData:get(KEYS.PigeonNest)
                return type(data) == "table" and tonumber(data.twigs_contributed) or 0
            end
            local twigs = ctx.gameData:itemsOfId(TOYS, E.Twig)
            local autoNest = ctx.farmConfig.Event.AutoNest ~= false
            if #twigs == 0 or placed() >= E.NestTwigs then
                return true
            end
            if autoNest and placed() + #twigs < E.NestTwigs then
                return true
            end
            local arrived, why = ctx.travel:goTo("HauntedHotel")
            if not arrived then
                return false, "travel to the Hotel failed: " .. tostring(why)
            end
            if autoNest then
                ctx.logger:info("AutoNest", string.format("Building Nest (%d placed + %d twigs)", placed(), #twigs))
            end
            for _, twig in ipairs(twigs) do
                if placed() >= E.NestTwigs then
                    break
                end
                local before = placed()
                local held, holdWhy = hold(ctx, twig, TOYS)
                if not held then
                    return false, holdWhy
                end
                task.wait(1)
                local _, answer = ctx.interaction:send("PigeonNestTwig", { unique = twig })
                if not ctx.waitUntil(function()
                    return placed() > before
                end, 6) then
                    return false, "the nest did not take the twig (answer: " .. tostring(answer) .. ")"
                end
                ctx.logger:success("Event", string.format("Pigeon nest: twig placed (%d of %d)", placed(), E.NestTwigs))
                if not autoNest then
                    return true
                end
            end
            if autoNest then
                ctx.logger:info("AutoNest", "Verifying Nest")
                if placed() < E.NestTwigs then
                    return false, string.format("nest not finished after building (%d of %d)", placed(), E.NestTwigs)
                end
                ctx.logger:success("AutoNest", "Nest completed")
            end
            return true
        end,
    }
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
            local byZone = not (ctx.farmConfig.Event and ctx.farmConfig.Event.GhostJoinByZone == false)
            local inZone = false
            if byZone then
                local zoneWhy
                inZone, zoneWhy = ctx.interaction:teleportToJoinZone()
                ctx.logger:info("Event", "Ghost Gallery: standing in the join circle" .. (inZone and "" or (" failed (" .. tostring(zoneWhy) .. ")")))
            end
            ctx.waitUntil(function()
                return Minigame.serverNow() >= start - 3
            end, math.max(0, start - Minigame.serverNow()) + 5)
            if byZone then
                inZone = ctx.interaction:teleportToJoinZone()
            end
            ctx.logger:info("Event", "Ghost Gallery: joining the round" .. (inZone and " (join circle)" or ""))
            if inZone then
                ctx.waitUntil(function()
                    return mg.joinAcceptedAt ~= nil or mg.join ~= nil
                end, 20)
                if mg.joinAcceptedAt or mg.join then
                    ctx.logger:info("Event", "Ghost Gallery: the game queued me from the join circle")
                else
                    ctx.logger:info("Event", "Ghost Gallery: the circle did not queue me in 20 s: joining by call")
                end
            end
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
            local function inRound()
                return ctx.travel:isAt(E.MinigameInteriorPrefix)
            end
            if not ctx.waitUntil(inRound, 15) then
                ctx.interaction:send("MinigameJoin", gameId, true, nil)
            end
            if not ctx.waitUntil(inRound, 20) then
                ctx.logger:warn("Event", "Ghost Gallery: not in the round after 35 s: leaving it (" .. tostring(gameId) .. ")")
                if type(gameId) == "string" then
                    ctx.interaction:send("MinigameLeave", gameId, false)
                end
                return false, "did not arrive in the minigame (left the round)"
            end
            local endTime = Minigame.serverNow() + 170
            local function finish(ok, reason)
                ctx.waitUntil(function()
                    return mg.leave ~= nil or not inRound()
                end, math.max(0, endTime - Minigame.serverNow()) + 25)
                ctx.waitUntil(function()
                    return not inRound()
                end, 15)
                local home, homeWhy = ctx.travel:goTo(GameConstants.HouseInteriorName)
                if not home then
                    ctx.logger:info("Event", "Ghost Gallery: going home after the round did not work (" .. tostring(homeWhy) .. ")")
                end
                return ok, reason
            end
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
            local folder = workspace:FindFirstChild(E.GhostsFolder)
            local uses, ghostUses, propUses, idle = 0, 0, 0, 0
            local held = { target = nil }
            local stopKeeper, keeperStats, holdNow = ctx.interaction:keepNear(function()
                local target = held.target
                if mg.leave or not inRound() then
                    return false
                end
                if not target then
                    return nil
                end
                if target.kind == "ghost" then
                    if not target.model or target.model.Parent == nil then
                        return nil
                    end
                    return modelPosition(target.model), "below"
                end
                return target.position, E.PropStandOff
            end)
            ctx.maid:Give(stopKeeper)
            while not mg.leave and Minigame.serverNow() < endTime + 5 do
                folder = folder or workspace:FindFirstChild(E.GhostsFolder)
                local target = EventTasks.pickTarget(ctx, folder, mg)
                if not target then
                    idle += 1
                    task.wait(0.5)
                else
                    held.target = target
                    holdNow()
                    ctx.interaction:send("UseTool", vacuum, "START")
                    local token = EventTasks.newToken()
                    uses += 1
                    local isGhost = target.kind == "ghost"
                    local payload = isGhost and { use_token = token, ghost_id = target.id } or { use_token = token, unique = target.id }
                    local startMessage = isGhost and "start_contribute" or "start_prop_contribute"
                    local stopMessage = isGhost and "stop_contribute" or "stop_prop_contribute"
                    for send = 1, 8 do
                        if mg.leave or (isGhost and target.model.Parent == nil) or (not isGhost and not mg.haunted[target.id]) then
                            break
                        end
                        if target.boss and send > 1 and EventTasks.pickTarget(ctx, folder, mg) ~= nil
                            and not EventTasks.pickTarget(ctx, folder, mg).boss then
                            break
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
            held.target = nil
            stopKeeper(inRound() and not mg.leave)
            ctx.logger:info("Event", string.format("Ghost Gallery: held %d studs under the ghosts (%d position corrections)",
                E.HoldBelowStuds, keeperStats.corrections))
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
            ctx.logger:info("Event", string.format("Ghost Gallery: Rusty Key %s (score %d, boss %s)",
                keysAfter > keysBefore and "EARNED (+1)" or "not earned", mg.score, mg.bossOut and "came out" or "did not come out"))
            if mg.scoreCount == 0 and not (mg.leave and mg.leave.candy > 0) and not (gained and gained > 0) then
                return finish(false, uses == 0 and "no ghost or haunted prop found" or "no points and no reward: vacuuming did not count")
            end
            return finish(true)
        end,
    }
    function EventTasks.newToken()
        local ok, guid = pcall(function()
            return game:GetService("HttpService"):GenerateGUID(false)
        end)
        return string.lower(ok and tostring(guid) or string.format("%08x-0000-4000-8000-%012x", math.random(0, 0x7fffffff), os.time()))
    end
    function EventTasks.pickTarget(ctx, folder, mg)
        local root = myRoot()
        if not root then
            return nil
        end
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
    EventTasks._visitTried = {}
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
    function EventTasks.potionList(farm)
        local settings = type(farm.AutoPotions) == "table" and farm.AutoPotions or {}
        local skip = {}
        for _, id in ipairs(type(settings.Skip) == "table" and settings.Skip or {}) do
            skip[id] = true
        end
        local list = {}
        for _, id in ipairs(type(settings.Potions) == "table" and settings.Potions or GameConstants.AgePotions) do
            if not skip[id] then
                table.insert(list, id)
            end
        end
        return list
    end
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
            local potions = EventTasks.potionList(ctx.farmConfig)
            local item = #potions > 0 and ctx.gameData:findItems(GameConstants.ItemCategory, potions)[1] or nil
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
            ctx.logger:success("Event", string.format("Potion %s on %s (age %s -> %s)", item.id, kind, tostring(ageBefore),
                tostring(ctx.gameData:petAge(petUnique))))
            return true
        end,
    }
    function EventTasks.neonPick(gameData, farm, mega)
        local settings = type(farm.AutoNeon) == "table" and farm.AutoNeon or {}
        local exclude = {}
        for _, kind in ipairs(type(settings.Exclude) == "table" and settings.Exclude or {}) do
            exclude[kind] = true
        end
        local bestKind, bestList
        for kind, list in pairs(gameData:neonFusionGroups(exclude, mega)) do
            if #list >= 4 and (not bestList or #list > #bestList or (#list == #bestList and kind < bestKind)) then
                bestKind, bestList = kind, list
            end
        end
        if not bestList then
            return nil
        end
        return bestKind, { bestList[1], bestList[2], bestList[3], bestList[4] }
    end
    local NEON_PLACE_WAIT, NEON_BETWEEN_PET, NEON_AFTER_PLACE = 0.12, 0.08, 0.15
    local function fusionTask(mega)
        return {
        id = mega and "mega_fusion" or "neon_fusion",
        timeoutSeconds = 40,
        run = function(ctx)
            local kind, uniques = EventTasks.neonPick(ctx.gameData, ctx.farmConfig, mega)
            if not kind then
                return true
            end
            local function countNow()
                return mega and ctx.gameData:megaCountOfKind(kind) or ctx.gameData:neonCountOfKind(kind)
            end
            local neonsBefore = countNow()
            for _, unique in ipairs(uniques) do
                ctx.interaction:send("EquipItem", unique, { equip_as_last = false, use_sound_delay = false })
                task.wait(NEON_PLACE_WAIT)
                ctx.interaction:send("UnequipItem", unique, nil)
                task.wait(NEON_BETWEEN_PET)
            end
            task.wait(NEON_AFTER_PLACE)
            local ok, answer = ctx.interaction:send("NeonFusion", { uniques[1], uniques[2], uniques[3], uniques[4] })
            local answered = type(answer) == "string" and answer or nil
            local function fused()
                if answered and (mega and ctx.gameData:isPetMega(answered) or not mega and ctx.gameData:isPetNeon(answered)) then
                    return true
                end
                local gone = 0
                for _, unique in ipairs(uniques) do
                    if ctx.gameData:petAge(unique) == nil then
                        gone += 1
                    end
                end
                return gone >= 3 and countNow() > neonsBefore
            end
            if ctx.waitUntil(fused, 6) then
                if mega then
                    ctx.logger:success("Event", string.format("Mega neon fusion: 4 neon %s -> 1 mega neon %s (mega %s now: %d)",
                        kind, kind, kind, countNow()))
                else
                    ctx.logger:success("Event", string.format("Neon fusion: 4 %s -> 1 neon %s (neon %s now: %d)", kind, kind, kind,
                        countNow()))
                end
                return true
            end
            return false, string.format("%s fusion of 4 %s not seen in my data (server answer: %s %s)", mega and "mega neon"
                or "neon", kind, tostring(ok), Util.truncate(tostring(answer), 60))
        end,
        }
    end
    EventTasks.neonFusion = fusionTask(false)
    EventTasks.megaFusion = fusionTask(true)
    function EventTasks.candyPetTarget(gameData, settings)
        local candy = tonumber(gameData:get(GameConstants.DataKeys.Candy))
        if not candy then
            return nil
        end
        if type(settings.Pick) == "table" then
            local picked = {}
            for _, id in ipairs(settings.Pick) do
                picked[id] = true
            end
            for _, entry in ipairs(type(settings.Buy) == "table" and settings.Buy or {}) do
                local id, price = entry.id or entry[1], tonumber(entry.price)
                if type(id) == "string" and picked[id] and price and price > 0
                    and candy - (tonumber(settings.KeepCandy) or 0) >= price then
                    return { id = id, price = price }
                end
            end
            return nil
        end
        for _, entry in ipairs(type(settings.Buy) == "table" and settings.Buy or {}) do
            local id, price, max = entry.id or entry[1], tonumber(entry.price), tonumber(entry.max) or 0
            if type(id) == "string" and price and price > 0 then
                local owned = 0
                for _ in pairs(gameData:petUniquesOfKind(id)) do
                    owned += 1
                end
                if max <= 0 or owned < max then
                    if candy - (tonumber(settings.KeepCandy) or 0) >= price then
                        return { id = id, price = price }
                    end
                    return nil
                end
            end
        end
        return nil
    end
    EventTasks.buyCandyPet = {
        id = "candy_pet",
        timeoutSeconds = 30,
        run = function(ctx)
            local settings = ctx.farmConfig.Event and ctx.farmConfig.Event.CandyPets or {}
            local pick = EventTasks.candyPetTarget(ctx.gameData, settings)
            if not pick then
                return true
            end
            local before = ctx.gameData:petUniquesOfKind(pick.id)
            local candyBefore = tonumber(ctx.gameData:get(GameConstants.DataKeys.Candy)) or 0
            local sent, answer = ctx.interaction:send("BuyItem", GameConstants.EggCategory, pick.id, { buy_count = 1 })
            local newUnique
            ctx.waitUntil(function()
                for unique in pairs(ctx.gameData:petUniquesOfKind(pick.id)) do
                    if not before[unique] then
                        newUnique = unique
                        return true
                    end
                end
                return false
            end, 8)
            if not newUnique then
                return false, string.format("no %s arrived in your backpack (server answer: %s %s)", pick.id, tostring(sent),
                    Util.truncate(tostring(answer), 60))
            end
            local candyAfter = tonumber(ctx.gameData:get(GameConstants.DataKeys.Candy)) or candyBefore
            ctx.logger:success("Event", string.format("Bought %s for %d candy (candy left: %d)", pick.id, candyBefore - candyAfter, candyAfter))
            return true
        end,
    }
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
__moduleSources["Game/TaskManager"] = function(...)
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
    local EVENT_RECHECK_SECONDS = { ghost_gallery = 120, stray_cat = 1800, crypt = 60, pigeon_nest = 60, quests = 300, pen_stock = 20, age_potion = 5, open_gift = 3, neon_fusion = 2, mega_fusion = 2, candy_pet = 30, house_visits = 300 }
    local GHOST_GALLERY_LEAD_SECONDS = 75
    local GHOST_INTERRUPT_SECONDS = 50
    local NO_FURNITURE_SKIP_SECONDS = 600
    local NEVER_INTERRUPT = { ghost_gallery = true, recover = true, team = true, neon_fusion = true, mega_fusion = true }
    local NEVER_SKIP = { neon_fusion = true, mega_fusion = true, team = true }
    local SKIP_REST_SECONDS = 90
    local HERE_BONUS = 12
    local AT_HOME_BONUS = 8
    local IN_PROGRESS_BONUS = 3
    local STUCK_MOVE_STUDS = 4
    local STUCK_MIN_FAILURES = 2
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
        self._nextEventAt = {}
        self._running = nil
        self._stopped = false
        self._failures = {}
        self._cooldownUntil = {}
        self._disabled = {}
        self._disabledUntil = {}
        self._lastSuccessAt = Util.now()
        self._completions = {}
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
    function TaskManager:_expireDisabled()
        local now = Util.now()
        for key, untilTime in pairs(self._disabledUntil) do
            if now >= untilTime then
                self._disabledUntil[key] = nil
                self._disabled[key] = nil
                self._failures[key] = 0
                self._logger:info("Tasks", "'" .. tostring(key) .. "' rested long enough: trying it again (Farm.DisableMinutes)")
            end
        end
    end
    function TaskManager:_priorityOf(kind, group)
        local priority = self._farmConfig.Priority[kind] or 0
        if self._farmConfig.SmartPriority == false or not self._travel then
            return priority
        end
        local destination = GameConstants.LocationForAilment[kind]
        if destination and not GameConstants.SpotForAilment[kind] and self._travel:isAt(destination) then
            priority += HERE_BONUS
        elseif GameConstants.FurnitureForAilment[kind] and self._travel:isAt(GameConstants.HouseInteriorName) then
            priority += AT_HOME_BONUS
        end
        if group and group.anyInProgress then
            priority += IN_PROGRESS_BONUS
        end
        return priority
    end
    function TaskManager:_selectGroup()
        if self._travel then
            for _, entry in ipairs(self._state:get("ailments.active", {})) do
                local destination = GameConstants.LocationForAilment[entry.kind]
                if entry.inProgress and destination and not GameConstants.SpotForAilment[entry.kind]
                    and not self._disabled[entry.kind] and GameConstants.needOn(self._farmConfig, entry.kind)
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
                if not taskDefinition or not GameConstants.needOn(self._farmConfig, kind) then
                    if not self._announcedUnsupported[kind] then
                        self._announcedUnsupported[kind] = true
                        local why = taskDefinition and "switched off: Auto needs is off or this need is skipped" or "no automatic task yet"
                        self._logger:info("Tasks", "Skipping '" .. kind .. "' (" .. why .. ")")
                    end
                elseif not self:_isBlocked(kind) then
                    local group = self:_group(kind)
                    local priority = group and self:_priorityOf(kind, group) or 0
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
    local NO_TRAVEL = { goTo = true, exitToMainMap = true, visitHouse = true }
    local function sideTravel(travel)
        if not travel then
            return nil
        end
        return setmetatable({}, { __index = function(_, name)
            if NO_TRAVEL[name] then
                return function()
                    return false, "side task: no travel (the main task holds the place)"
                end
            end
            local value = travel[name]
            if type(value) == "function" then
                return function(_, ...)
                    return value(travel, ...)
                end
            end
            return value
        end })
    end
    function TaskManager:_makeContext(runMaid, startedAt, running)
        local context = {
            logger = self._logger,
            state = self._state,
            interaction = self._interaction,
            travel = running and running.side and sideTravel(self._travel) or self._travel,
            side = running and running.side or nil,
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
        function context.setWaiting(isWaiting)
            if running then
                running.waiting = isWaiting == true
            end
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
    function TaskManager:_start(key, label, taskDefinition, group, isEventJob, side)
        local slot = side and "_side" or "_running"
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
            side = side == true,
        }
        self[slot] = running
        if side then
            running.label = "(side) " .. label
        else
            self._state:set("farm.currentTask", key, "TaskManager")
        end
        self._logger:info("Tasks", string.format("Start: %s (attempt %d, limit %d s)", running.label, attempt, taskDefinition.timeoutSeconds))
        local context = self:_makeContext(runMaid, startedAt, running)
        running.thread = task.spawn(function()
            local ok, result, reason = pcall(taskDefinition.run, context, group, attempt)
            if self[slot] ~= running then
                return
            end
            if not ok then
                self:_finish("FAILED", "script error: " .. tostring(result), slot)
            elseif result == true then
                self:_finish("SUCCESS", nil, slot)
            else
                self:_finish("FAILED", tostring(reason or "unknown reason"), slot)
            end
        end)
    end
    function TaskManager:_finish(result, reason, slot)
        slot = slot or "_running"
        local running = self[slot]
        if not running then
            return
        end
        self[slot] = nil
        if slot == "_side" then
            local multi = self._farmConfig.MultiNeed
            self._sideNextAt = Util.now() + math.max(0, tonumber(type(multi) == "table" and multi.GapSeconds) or 2)
        end
        if running.thread and coroutine.running() ~= running.thread then
            pcall(task.cancel, running.thread)
        end
        task.spawn(function()
            running.maid:Clean()
        end)
        if slot == "_running" then
            self._state:set("farm.currentTask", "none", "TaskManager")
        end
        local key = running.key
        local seconds = Util.now() - running.startedAt
        if result == "INTERRUPTED" then
            if running.eventJob then
                self._nextEventAt[key] = 0
            end
            self._logger:info("Tasks", string.format("Interrupted: %s after %.1f s (%s)", running.label, seconds, tostring(reason)))
            return
        end
        if running.eventJob then
            local wait = key == "pet_pen" and math.max(1, tonumber(self._farmConfig.Event.PetPenMinutes) or 15) * 60
                or EVENT_RECHECK_SECONDS[key] or 60
            self._nextEventAt[key] = Util.now() + wait
        end
        if key == "ghost_gallery" then
            local nest = self:_autoNest()
            if nest == "COLLECT_TWIGS" or nest == "BUILD_NEST" then
                self._logger:info("Ghost", "Minigame complete: resuming AutoNest (" .. nest .. ")")
            end
        end
        local travelTrouble = result ~= "SUCCESS" and type(reason) == "string"
            and (string.find(reason, "travel", 1, true) or string.find(reason, "still in", 1, true)
                or string.find(reason, "going home", 1, true))
        if travelTrouble and key ~= "recover" and slot == "_running" then
            self._travelFailures = (self._travelFailures or 0) + 1
        elseif result == "SUCCESS" then
            self._travelFailures = 0
        end
        if result == "SUCCESS" then
            self._stuckSince = nil
            self._lastSuccessAt = Util.now()
            self._watch = nil
            self._failures[key] = 0
            self._state:increment("farm.tasksSucceeded", 1, "TaskManager")
            self._logger:success("Tasks", string.format("Done: %s in %.1f s", running.label, seconds))
            return
        end
        self._state:increment("farm.tasksFailed", 1, "TaskManager")
        if result == "CANCELLED" then
            self._logger:info("Tasks", string.format("Stopped: %s after %.1f s (%s)", running.label, seconds, tostring(reason)))
            return
        end
        if type(reason) == "string" and string.sub(reason, 1, 3) == "no " and string.find(reason, " in your house", 1, true) then
            self._cooldownUntil[key] = Util.now() + NO_FURNITURE_SKIP_SECONDS
            self._logger:info("Tasks", string.format("Skipped for %d min: %s — %s (buy one to farm this need)",
                NO_FURNITURE_SKIP_SECONDS / 60, running.label, reason))
            return
        end
        local failures = (self._failures[key] or 0) + 1
        self._failures[key] = failures
        self._cooldownUntil[key] = Util.now() + self._farmConfig.FailureCooldownSeconds
        if self._watch then
            self._watch.failures += 1
        end
        local message = string.format("%s: %s after %.1f s — %s", result, running.label, seconds, tostring(reason))
        if failures >= self._farmConfig.MaxConsecutiveFailures and key ~= "recover" then
            self._disabled[key] = true
            local minutes = tonumber(self._farmConfig.DisableMinutes) or 0
            if minutes > 0 then
                self._disabledUntil[key] = Util.now() + minutes * 60
                self._logger:error("Tasks", message .. string.format(" (%d failures in a row: disabled for %s min, then tried"
                    .. " again)", failures, tostring(minutes)))
            else
                self._logger:error("Tasks", message .. string.format(" (%d failures in a row: disabled for this session)", failures))
            end
        else
            self._logger:warn("Tasks", message .. string.format(" (retry in %d s)", self._farmConfig.FailureCooldownSeconds))
        end
    end
    function TaskManager:_trackPet()
        if not self._gameData then
            return
        end
        local current = self._gameData:firstEquippedPet()
        if current then
            self._lastPet = current
            self._farmPet = self._farmPet or current
            if self._badPets then
                self._badPets[current] = nil
            end
        end
    end
    function TaskManager:tick()
        local now = Util.now()
        local dt = math.min(now - (self._lastTickAt or now), 5)
        self._lastTickAt = now
        self._why = nil
        self:_tickInner()
        self._idle = self._idle or {}
        if self._running then
            self._busy = (self._busy or 0) + dt
        else
            local why = self._why or "nothing to do (no need / job due)"
            self._idle[why] = (self._idle[why] or 0) + dt
        end
    end
    function TaskManager:getDiagnostics()
        local idle = {}
        for why, seconds in pairs(self._idle or {}) do
            idle[why] = math.floor(seconds / 6 + 0.5) / 10
        end
        local disabled = {}
        for key, isOff in pairs(self._disabled or {}) do
            if isOff then
                table.insert(disabled, key)
            end
        end
        table.sort(disabled)
        local restMinutes = {}
        for key, untilTime in pairs(self._disabledUntil or {}) do
            restMinutes[key] = math.max(0, math.ceil((untilTime - Util.now()) / 60))
        end
        return { idle = idle, busyMinutes = math.floor((self._busy or 0) / 6 + 0.5) / 10, disabled = disabled,
            restMinutes = restMinutes, running = self._running and self._running.label or nil,
            side = self._side and self._side.label or nil }
    end
    function TaskManager:_hasWork()
        for _, entry in ipairs(self._state:get("ailments.active", {})) do
            local kind = entry.kind
            if GameConstants.needOn(self._farmConfig, kind) and Tasks.findFor(kind) and not self:_isBlocked(kind) and self:_isDoable(entry) then
                return true
            end
        end
        return false
    end
    function TaskManager:_stuckCheck()
        local recovery = self._farmConfig.StuckRecovery
        if type(recovery) ~= "table" or not recovery.Enabled or self._state:get("game.ready") ~= true
            or self._state:get("session.disconnectReason") ~= nil then
            self._watch = nil
            return false
        end
        if self._running and NEVER_INTERRUPT[self._running.key] then
            self._watch = nil
            return false
        end
        local character = game:GetService("Players").LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local position = root and root.Position
        local interior = self._state:get("player.interior")
        if not position or interior == nil then
            return false
        end
        local now = Util.now()
        local watch = self._watch
        local moved = watch and math.sqrt((position.X - watch.x) ^ 2 + (position.Z - watch.z) ^ 2) >= STUCK_MOVE_STUDS
        if not watch or watch.interior ~= interior or moved then
            self._watch = { interior = interior, x = position.X, z = position.Z, since = now, failures = 0 }
            return false
        end
        local limit = math.max(60, tonumber(recovery.Seconds) or 240)
        if now - watch.since < limit or watch.failures < STUCK_MIN_FAILURES then
            return false
        end
        if not self._running and not self:_hasWork() then
            return false
        end
        self._watch = nil
        self._logger:warn("Tasks", string.format("Stuck in %s: not moving, %d tasks failed, none finished for %d s: going home"
            .. " (Farm.StuckRecovery)", tostring(interior), watch.failures, math.floor(now - watch.since)))
        self:_finish("INTERRUPTED", "stuck recovery")
        self:_finish("INTERRUPTED", "stuck recovery", "_side")
        self:_start("recover", "recover: stuck, go home", Tasks.recover, nil)
        return true
    end
    function TaskManager:_tickInner()
        if self._stopped or not self._farmConfig.Enabled then
            self._why = self._stopped and "stopped" or "Farm.Enabled = false (watch only)"
            return
        end
        self:_expireDisabled()
        self:_trackPet()
        if self._side and Util.now() > self._side.deadline then
            self:_finish("TIMEOUT", "no result within " .. math.floor(self._side.deadline - self._side.startedAt) .. " s", "_side")
        end
        if self:_stuckCheck() then
            return
        end
        if self._running then
            if Util.now() > self._running.deadline then
                self:_finish("TIMEOUT", "no result within " .. math.floor(self._running.deadline - self._running.startedAt) .. " s")
            elseif not NEVER_INTERRUPT[self._running.key] and self:_ghostRoundDue(GHOST_INTERRUPT_SECONDS) then
                self._logger:info("Ghost", "Priority interrupt: stopping " .. self._running.label .. " for the Ghost Gallery round")
                self:_finish("INTERRUPTED", "Ghost Gallery round")
                self:_finish("INTERRUPTED", "Ghost Gallery round", "_side")
            else
                self:_maybeStartSide()
            end
            return
        end
        if self._side then
            self._why = "side task finishing"
            return
        end
        if self._state:get("session.disconnectReason") ~= nil or self._state:get("game.ready") ~= true then
            self._why = self._state:get("session.disconnectReason") ~= nil and "disconnected / kicked" or "game not ready (loading)"
            return
        end
        if self._state:get("player.team") == "Choosing" then
            self._why = "Play menu still open (team Choosing)"
            return
        end
        if self._wantHome then
            self._wantHome = nil
            if self._travel and self._travel:isAt(GameConstants.HouseInteriorName) then
                self._logger:info("Tasks", "Go home: you are already home")
            else
                self:_start("go_home", "go home (you asked)", Tasks.recover, nil)
                return
            end
        end
        do
            local character = game:GetService("Players").LocalPlayer.Character
            local stuck = self._state:get("player.interior") == nil
                or not (character and character:FindFirstChild("HumanoidRootPart"))
            if stuck then
                self._stuckSince = self._stuckSince or Util.now()
                local limit = tonumber(self._farmConfig.StuckRejoinSeconds) or 180
                if self._farmConfig.AutoRejoin and not self._rejoinSent and Util.now() - self._stuckSince > limit then
                    self._rejoinSent = true
                    self:_rejoin(string.format("no place / no character for %d s", math.floor(Util.now() - self._stuckSince)))
                    return
                end
            else
                self._stuckSince = nil
            end
        end
        if self._state:get("player.interior") == nil and self._hadPlace then
            self._why = "changing place (no place in my data)"
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
        if (self._travelFailures or 0) >= 2 then
            self._travelFailures = 0
            self._logger:warn("Tasks", "2 trips in a row failed: recovering")
            self:_start("recover", "recover: go home", Tasks.recover, nil)
            return
        end
        if self._gameData and self._farmConfig.KeepPetEquipped then
            local current = self._gameData:firstEquippedPet()
            local count, known = self._gameData:equippedPetCount()
            local skipGrown = self._farmConfig.SkipFullGrown
            local list = self._gameData:equippedPetList()
            local growableEquipped = false
            for _, pet in ipairs(list) do
                if pet.age == nil or pet.age < GameConstants.FullGrownAge then
                    growableEquipped = true
                end
            end
            self._badPets = self._badPets or {}
            local function usable(unique)
                return unique ~= nil and (self._badPets[unique] or 0) < 2
            end
            local preferNeon = self._farmConfig.PreferNeon == true
            local kindRank = GameConstants.kindRank(self._farmConfig)
            local youngestFirst = self._farmConfig.PetOrder ~= "oldest"
            local function rankOf(unique)
                local kind = self._gameData:getPetKind(unique)
                return kindRank and kind and kindRank[kind] or math.huge, preferNeon and self._gameData:isPetNeon(unique)
            end
            local function better(candidate, current)
                local candidateKind = kindRank and kindRank[candidate.kind] or math.huge
                local currentKind, currentNeon = rankOf(current)
                if candidateKind ~= currentKind then
                    return candidateKind < currentKind
                end
                return preferNeon and candidate.neon and not currentNeon
            end
            local function pickGrowable()
                local farmAge = self._farmPet and self._gameData:petAge(self._farmPet)
                local keepFarmPet = usable(self._farmPet) and farmAge and farmAge < GameConstants.FullGrownAge
                for _, candidate in ipairs(self._gameData:growablePets(preferNeon, kindRank, youngestFirst)) do
                    if keepFarmPet and not better(candidate, self._farmPet) then
                        return self._farmPet
                    end
                    if usable(candidate.unique) then
                        return candidate.unique
                    end
                end
                return keepFarmPet and self._farmPet or nil
            end
            local function onEquipFail(unique)
                return function()
                    self._badPets[unique] = (self._badPets[unique] or 0) + 1
                    if self._badPets[unique] == 2 then
                        self._logger:warn("Tasks", "Pet " .. tostring(unique) .. " could not be equipped twice: skipping it")
                    end
                end
            end
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
            elseif (preferNeon or kindRank) and growableEquipped and not self:_isBlocked("keep_pet") then
                local bestEquipped
                for _, pet in ipairs(list) do
                    if pet.unique and (pet.age == nil or pet.age < GameConstants.FullGrownAge) then
                        local entry = { unique = pet.unique, kind = self._gameData:getPetKind(pet.unique),
                            neon = self._gameData:isPetNeon(pet.unique) }
                        if not bestEquipped or better(entry, bestEquipped.unique) then
                            bestEquipped = entry
                        end
                    end
                end
                local wanted = pickGrowable()
                local wantedEntry = wanted and { unique = wanted, kind = self._gameData:getPetKind(wanted),
                    neon = self._gameData:isPetNeon(wanted) }
                if wantedEntry and bestEquipped and wanted ~= bestEquipped.unique and better(wantedEntry, bestEquipped.unique) then
                    self._logger:info("Tasks", "A better pet still grows (" .. tostring(wantedEntry.kind)
                        .. (wantedEntry.neon and ", neon" or "") .. "): farming it first (Farm.FarmPetKinds / Farm.PreferNeon)")
                    self._farmPet = wanted
                    self:_start("keep_pet", "equip the better pet", Tasks.equipPet, { petUnique = wanted, onFail = onEquipFail(wanted) })
                    return
                end
            end
            if skipGrown and #list > 0 and not growableEquipped and not self:_isBlocked("keep_pet") then
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
    function TaskManager:_maybeStartSide()
        local multi = self._farmConfig.MultiNeed
        local main = self._running
        if type(multi) ~= "table" or not multi.Enabled or self._side or not main or not main.waiting then
            return
        end
        local now = Util.now()
        if now < (self._sideNextAt or 0) or main.deadline - now < 10 then
            return
        end
        local best, bestTask
        for _, kind in ipairs(type(multi.Kinds) == "table" and multi.Kinds or {}) do
            local taskDefinition = Tasks.findFor(kind)
            if kind ~= main.key and taskDefinition and GameConstants.needOn(self._farmConfig, kind) and not self:_isBlocked(kind) then
                local group = self:_group(kind)
                local petOnly = kind == "pet_me" or kind == "play"
                if group and (not petOnly or group.petEntry) then
                    best, bestTask = group, taskDefinition
                    break
                end
            end
        end
        if best then
            local owners = {}
            for _, entry in ipairs(best.entries) do
                table.insert(owners, entry.owner == "baby" and "baby" or tostring(entry.petKind or "pet"))
            end
            self:_start(best.kind, best.kind .. " (" .. table.concat(owners, " + ") .. ")", bestTask, best, false, true)
        end
    end
    function TaskManager:_ghostRoundDue(lead)
        local event = self._farmConfig.Event
        local data = self._gameData
        if type(event) ~= "table" or not event.Enabled or not event.GhostGallery or not data or not self._minigame
            or not self._minigame.available or self:_isBlocked("ghost_gallery")
            or Util.now() < (self._nextEventAt.ghost_gallery or 0) then
            return nil
        end
        local serverNow = Minigame.serverNow()
        local start = EventTasks.nextRoundStart(data:get(GameConstants.DataKeys.GhostCycle), serverNow)
        if start and start - serverNow <= lead and start - serverNow > -10 then
            return start
        end
        return nil
    end
    function TaskManager:_autoNest()
        local event = self._farmConfig.Event
        local data = self._gameData
        if type(event) ~= "table" or event.AutoNest == false or event.PigeonNest == false or not data then
            return nil
        end
        local E = GameConstants.Event
        local stateName, placed, held = EventTasks.nestState(data:get(GameConstants.DataKeys.PigeonNest),
            #data:itemsOfId(GameConstants.ToyCategory, E.Twig), #data:itemsOfId(GameConstants.ToyCategory, E.RustyKey))
        local progress = placed + held
        local signature = stateName .. ":" .. progress
        if signature ~= self._nestSignature then
            self._nestSignature = signature
            if stateName == "COMPLETE" then
                self._logger:info("AutoNest", "Nest completed: one-time objective complete (" .. placed .. "/" .. E.NestTwigs .. ")")
            elseif stateName ~= "UNKNOWN" then
                self._logger:info("AutoNest", string.format("%s, twig progress: %d/%d", stateName, progress, E.NestTwigs))
            end
        end
        return stateName
    end
    function TaskManager:_selectEventJob()
        local event = self._farmConfig.Event
        local data = self._gameData
        if not data then
            return nil
        end
        local team = self._state:get("player.team")
        local character = game:GetService("Players").LocalPlayer.Character
        if team ~= "Parents" and team ~= GameConstants.BabiesTeam or not (character and character:FindFirstChild("HumanoidRootPart")) then
            return nil
        end
        if self._penWanted then
            if data:get(GameConstants.DataKeys.PetPen) == nil then
                self._penWanted = nil
                self._logger:warn("Event", "Pet Pen now: there is no Pet Pen in your data")
            elseif self._travel and self._travel:isAt(GameConstants.HouseInteriorName) then
                self._penWanted = nil
                return "pet_pen", "Pet Pen (you asked)", EventTasks.petPen, { keep = self._farmPet }
            elseif self._disabled.pen_trip then
                self._penWanted = nil
                self._logger:warn("Event", "Pet Pen now: could not get home, request dropped")
            elseif not self:_isBlocked("pen_trip") then
                return "pen_trip", "go home for the Pet Pen (you asked)", Tasks.recover, nil
            end
        end
        do
            local nowExtra = Util.now()
            local function dueExtra(key)
                return not self:_isBlocked(key) and nowExtra >= (self._nextEventAt[key] or 0)
            end
            local potions = self._farmConfig.AutoPotions
            if type(potions) == "table" and potions.Enabled and dueExtra("age_potion")
                and EventTasks.potionTarget(data, self._farmConfig)
                and data:findItems(GameConstants.ItemCategory, EventTasks.potionList(self._farmConfig))[1] then
                return "age_potion", "age potion", EventTasks.agePotion, nil
            end
            local open = self._farmConfig.AutoOpen
            if type(open) == "table" and open.Enabled and dueExtra("open_gift") and EventTasks.nextGift(data, self._farmConfig) then
                return "open_gift", "open a gift", EventTasks.openGift, nil
            end
            local neon = self._farmConfig.AutoNeon
            if type(neon) == "table" and neon.Enabled and dueExtra("neon_fusion") then
                local kind = EventTasks.neonPick(data, self._farmConfig)
                if kind then
                    return "neon_fusion", "neon fusion (4 " .. kind .. ")", EventTasks.neonFusion, nil
                end
            end
            if type(neon) == "table" and neon.Mega and dueExtra("mega_fusion") then
                local kind = EventTasks.neonPick(data, self._farmConfig, true)
                if kind then
                    return "mega_fusion", "mega neon fusion (4 neon " .. kind .. ")", EventTasks.megaFusion, nil
                end
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
        local ghostStart = self:_ghostRoundDue(GHOST_GALLERY_LEAD_SECONDS)
        if ghostStart then
            self._logger:info("Ghost", "Minigame available: starting the Ghost Gallery round")
            return "ghost_gallery", "Ghost Gallery round", EventTasks.ghostGallery, { start = ghostStart }
        end
        local nest = event.PigeonNest ~= false and self:_autoNest()
        if nest == "BUILD_NEST" and due("pigeon_nest") then
            return "pigeon_nest", "build the nest (AutoNest)", EventTasks.pigeonNest, nil
        elseif nest == "COLLECT_TWIGS" and event.Crypt and due("crypt") and data:get(KEYS.Crypt) ~= nil
            and EventTasks.cryptPlan(data:get(KEYS.Crypt), true) then
            return "crypt", "collect twigs in the Crypt (AutoNest)", EventTasks.crypt, nil
        end
        local candyPets = event.CandyPets
        if type(candyPets) == "table" and candyPets.Enabled and due("candy_pet") and data:petInventoryKnown() then
            local pick = EventTasks.candyPetTarget(data, candyPets)
            if pick then
                return "candy_pet", "buy " .. pick.id .. " (" .. pick.price .. " candy)", EventTasks.buyCandyPet, nil
            end
        end
        if event.StrayCat and due("stray_cat") then
            local cat = data:get(KEYS.StrayCat)
            if type(cat) == "table" and cat.fed_today == false then
                return "stray_cat", "feed the Stray Cat", EventTasks.strayCat, nil
            end
        end
        if event.Crypt and due("crypt") and data:get(KEYS.Crypt) ~= nil then
            local plan = EventTasks.cryptPick(data:get(KEYS.Crypt), event.CryptOpen)
            if plan and plan.spider and event.MummySpider ~= false then
                return "crypt", "claim the Mummy Spider", EventTasks.crypt, nil
            elseif plan and not plan.spider and #data:itemsOfId(GameConstants.ToyCategory, E.RustyKey) > 0 then
                return "crypt", "open a Crypt grave", EventTasks.crypt, nil
            end
        end
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
        if event.PigeonNest and event.AutoNest == false and due("pigeon_nest")
            and #data:itemsOfId(GameConstants.ToyCategory, E.Twig) > 0 then
            local nest = data:get(KEYS.PigeonNest)
            if type(nest) == "table" and (tonumber(nest.twigs_contributed) or 0) < E.NestTwigs then
                return "pigeon_nest", "twig to the pigeon nest", EventTasks.pigeonNest, nil
            end
        end
        if event.PetPen and event.PetPenStock ~= false and self._farmConfig.BuyEgg and due("pen_stock")
            and not self:_isBlocked("buy_egg") and data:get(KEYS.PetPen) ~= nil and data:petInventoryKnown()
            and (tonumber(data:get(KEYS.Money)) or 0) >= (tonumber(event.PetPenStockMinBucks) or 750)
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
                    self._nextEventAt.pet_pen = 0
                end }
            end
        end
        if event.PetPen and due("pet_pen") and data:get(KEYS.PetPen) ~= nil and self._travel
            and self._travel:isAt(GameConstants.HouseInteriorName) then
            return "pet_pen", "Pet Pen", EventTasks.petPen, { keep = self._farmPet }
        end
        return nil
    end
    function TaskManager:_rejoin(reason)
        self._logger:warn("Tasks", "Stuck: " .. reason .. ": rejoining a server (Farm.AutoRejoin)")
        local ok, err = pcall(function()
            local Players = game:GetService("Players")
            game:GetService("TeleportService"):Teleport(game.PlaceId, Players.LocalPlayer)
        end)
        if not ok then
            self._logger:warn("Tasks", "Rejoin failed: " .. tostring(err))
        end
    end
    function TaskManager:sendDirect(actionName, ...)
        if self._running or self._side or self._stopped then
            return false, "busy"
        end
        return self._interaction:send(actionName, ...)
    end
    function TaskManager:isBusy()
        return self._running ~= nil or self._side ~= nil
    end
    function TaskManager:requestGoHome()
        if self._running and NEVER_INTERRUPT[self._running.key] then
            self._wantHome = true
            return true, "Going home after " .. self._running.label
        end
        self:_finish("INTERRUPTED", "you asked to go home")
        self:_finish("INTERRUPTED", "you asked to go home", "_side")
        self._wantHome = true
        return true, "Going home"
    end
    function TaskManager:skipCurrent()
        local running = self._running
        if not running then
            return false, "Nothing is running"
        end
        if NEVER_SKIP[running.key] then
            return false, running.label .. " always finishes (it is safe that way)"
        end
        local key, label = running.key, running.label
        self:_finish("INTERRUPTED", "skipped by you")
        self:_finish("INTERRUPTED", "skipped by you", "_side")
        self._cooldownUntil[key] = Util.now() + SKIP_REST_SECONDS
        if self._nextEventAt[key] ~= nil then
            self._nextEventAt[key] = Util.now() + SKIP_REST_SECONDS
        end
        return true, string.format("Skipped %s (not chosen again for %d s)", label, SKIP_REST_SECONDS)
    end
    function TaskManager:requestPetPen()
        self._penWanted = true
        self._nextEventAt.pet_pen = 0
        self._cooldownUntil.pen_trip = nil
        return true, self._travel and self._travel:isAt(GameConstants.HouseInteriorName) and "Claiming the Pet Pen"
            or "Going home, then claiming the Pet Pen"
    end
    function TaskManager:retryDisabled()
        local count = 0
        for _ in pairs(self._disabled) do
            count += 1
        end
        self._disabled = {}
        self._disabledUntil = {}
        self._failures = {}
        self._cooldownUntil = {}
        self._logger:info("Tasks", string.format("Retry: %d resting task%s may run again (you asked)", count, count == 1 and "" or "s"))
        return count
    end
    function TaskManager:getPenInfo()
        local data = self._gameData
        local event = self._farmConfig.Event
        local info = { known = false, slots = tonumber(type(event) == "table" and event.PetPenSlots) or 4 }
        if data and data:get(GameConstants.DataKeys.PetPen) ~= nil then
            info.known = true
            local pets = 0
            for _ in pairs(data:petPenPets()) do
                pets += 1
            end
            info.pets = pets
            local at = self._nextEventAt.pet_pen
            info.nextClaimIn = at and math.max(0, math.floor(at - Util.now())) or 0
        end
        return info
    end
    function TaskManager:stop()
        if self._stopped then
            return
        end
        self._stopped = true
        if self._running then
            self:_finish("CANCELLED", "farm stopped")
        end
        self:_finish("CANCELLED", "farm stopped", "_side")
    end
    return TaskManager
end
__moduleSources["main"] = function(...)
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
    local GameIcons = import("Game/GameIcons")
    local PetLocator = import("Game/PetLocator")
    local PlayerSync = import("Game/PlayerSync")
    local AilmentTracker = import("Game/AilmentTracker")
    local Interaction = import("Game/Interaction")
    local Travel = import("Game/Travel")
    local TaskManager = import("Game/TaskManager")
    local Furniture = import("Game/Furniture")
    local Minigame = import("Game/Minigame")
    local EventTasks = import("Game/EventTasks")
    local Interface = import("Services/Interface")
    local Players = game:GetService("Players")
    local GLOBAL_KEY = "AdoptMeFarm"
    local STOP_FLUSH_SECONDS = 6
    local SESSION_HEARTBEAT_SECONDS = 30
    local STATUS_CHECK_SECONDS = 5
    local TASK_TICK_SECONDS = 0.5
    local CASHBACK_CHECK_SECONDS = 30
    local SUMMARY_CHECK_SECONDS = 30
    local CAMERA_INSIDE_STUDS = 1.5
    local CAMERA_OUT_STUDS = 10
    local function buildSummaryFields(state, logger, candy, candyEarned)
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
        if candy then
            table.insert(fields, { name = "Candy", value = tostring(candy), inline = true })
            table.insert(fields, { name = "Candy earned", value = tostring(candyEarned or 0), inline = true })
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
    return function(userConfig, launchInfo)
        local sharedEnvironment = Util.getSharedEnvironment()
        local previous = sharedEnvironment[GLOBAL_KEY]
        if type(previous) == "table" and type(previous.Stop) == "function" then
            pcall(previous.Stop, "replaced by a new execution")
        end
        local config, configWarnings = Config.build(userConfig)
        local maid = Maid.new()
        local logger = Logger.new(config.Logging)
        for _, warning in ipairs(configWarnings) do
            logger:warn("Config", warning)
        end
        local state = State.new()
        local localPlayer = Players.LocalPlayer
        state:set("session.startedAt", Util.now(), "main")
        state:set("player.name", localPlayer and localPlayer.Name or "?", "Players.LocalPlayer")
        state:set("stats.needsCompleted", 0, "main")
        state:set("stats.bucksEarned", 0, "main")
        local rememberWindow = config.Interface.Enabled and config.Interface.RememberSettings ~= false
        local windowSettingsApplied = rememberWindow and Interface.applySaved(config, logger) or 0
        local notifier = Notifier.new(config.Notifications, logger, config.General.ScriptName, Disclosure.VERSION)
        local sessionStore = SessionStore.new(logger, Disclosure.VERSION, config.Logging.SessionFile)
        local previousRun = sessionStore:begin()
        local files = {}
        local logFilePath, logFileProblem = logger:getFilePath()
        table.insert(files, logFilePath and ("log: " .. logFilePath) or ("no log file (" .. tostring(logFileProblem) .. ")"))
        if sessionStore:isAvailable() then
            table.insert(files, "session status: " .. SessionStore.PATH .. " (start time, last seen, clean stop, last Roblox message)")
        end
        if rememberWindow then
            table.insert(files, string.format("window settings: %s (your changes in the window; %d applied over these settings;"
                .. " holds your webhook URL when you typed one in the window)", Interface.SAVE_PATH, windowSettingsApplied))
            table.insert(files, "configs: " .. Interface.CONFIG_FOLDER .. "/<name>" .. Interface.CONFIG_EXTENSION
                .. " (only the configs you save in the window)")
        end
        local isAdoptMe = game.PlaceId == GameConstants.PlaceId
        local gameActionLines = isAdoptMe and Interaction.describeActions() or nil
        local telemetry = Telemetry.new(config.Telemetry, logger, Disclosure.VERSION, state)
        telemetry:start(maid)
        local disclosureLines = Disclosure.buildStartLines(config, files, notifier:getStatusText(), telemetry:statusText(),
            launchInfo)
        table.insert(disclosureLines, "")
        for _, line in ipairs(Disclosure.buildLines(config, files, notifier:getStatusText(), launchInfo, gameActionLines,
            telemetry:statusText())) do
            table.insert(disclosureLines, line)
        end
        logger:report("Disclosure", Disclosure.buildStartLine(config, telemetry:isEnabled()))
        maid:Give(logger.OnEntry:Connect(function(level, category, message)
            if level == Enums.LogLevel.ERROR and category ~= "Notifier" then
                notifier:notify(Enums.NotifyEvent.Error, { { name = "Error", value = category .. ": " .. message } })
            end
        end))
        if previousRun then
            local description = SessionStore.describe(previousRun)
            logger:warn("Session", description)
            notifier:notify(Enums.NotifyEvent.PreviousSessionEnded, {
                { name = "Previous session", value = description },
            })
        end
        local petLocator = nil
        local taskManager = nil
        local uiGameData = nil
        local uiCandyStart = nil
        local gameIcons = GameIcons.new(logger)
        local petPictures = {}
        local function candyNow()
            local candy = uiGameData and tonumber(uiGameData:get("candy_2026")) or nil
            if candy and not uiCandyStart then
                uiCandyStart = candy
            end
            return candy, (candy and uiCandyStart) and (candy - uiCandyStart) or nil
        end
        local function summaryFields()
            return buildSummaryFields(state, logger, candyNow())
        end
        local function petThumbnail()
            local pet = state:get("pets.equipped", {})[1]
            local id = pet and GameIcons.assetId(gameIcons:item(pet.kind))
            if not id then
                return nil
            end
            if petPictures[id] == nil then
                petPictures[id] = false
                task.spawn(function()
                    local ok, url = pcall(function()
                        local data = Util.jsonDecode(game:HttpGet("https://thumbnails.roblox.com/v1/assets?assetIds=" .. id
                            .. "&size=150x150&format=Png"))
                        return data.data[1].imageUrl
                    end)
                    if ok and type(url) == "string" and string.find(url, "^https://tr%.rbxcdn%.com/") then
                        petPictures[id] = url
                    end
                end)
            end
            return petPictures[id] or nil
        end
        if not isAdoptMe then
            logger:warn("Game", string.format("PlaceId %s is not Adopt Me (%d): game features are off", tostring(game.PlaceId), GameConstants.PlaceId))
        else
            local loadedOk, isLoaded = pcall(function()
                return game:IsLoaded()
            end)
            if loadedOk and not isLoaded then
                logger:info("Game", "Waiting for game:IsLoaded()...")
                game.Loaded:Wait()
            end
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
            local function searchRoots(root)
                if root ~= playerGui then
                    return { root }
                end
                local roots = {}
                for _, child in ipairs(root:GetChildren()) do
                    local okEnabled, enabled = pcall(function()
                        return child:IsA("ScreenGui") and child.Enabled ~= false
                    end)
                    if okEnabled and enabled then
                        table.insert(roots, child)
                    end
                end
                return roots
            end
            local function findText(root, patterns)
                if type(patterns) == "string" then
                    patterns = { patterns }
                end
                for _, searchRoot in ipairs(searchRoots(root)) do
                    for _, object in ipairs(searchRoot:GetDescendants()) do
                        if (object:IsA("TextLabel") or object:IsA("TextButton")) and type(object.Text) == "string" then
                            local text = string.lower(object.Text)
                            for _, pattern in ipairs(patterns) do
                                if string.find(text, pattern) and isOnScreen(object) then
                                    return object
                                end
                            end
                        end
                    end
                end
                return nil
            end
            local function handleLocationDialog()
                for _ = 1, 30 do
                    local title = findText(playerGui, "choose location")
                    if title then
                        task.wait(1.5)
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
                    local marker = findText(playerGui, POPUP_TEXTS)
                    if not marker then
                        quietSeconds += 1
                        if quietSeconds >= 15 then
                            local seen = {}
                            for _, searchRoot in ipairs(searchRoots(playerGui)) do
                                for _, object in ipairs(searchRoot:GetDescendants()) do
                                    local name = string.lower(object.Name)
                                    if object:IsA("GuiButton") and (string.find(name, "close") or string.find(name, "exit") or name == "x")
                                        and isOnScreen(object) then
                                        table.insert(seen, object:GetFullName())
                                    end
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
            if config.Farm.AutoAcceptMenu and playerGui then
                local function watchMenu()
                    for _ = 1, 180 do
                        local button = config.Farm.AutoAcceptMenu and findPlayButton()
                        if button and menuOpen(button) then
                            task.wait(2)
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
            uiGameData = gameData
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
                telemetry:setDiagnostics(function()
                    local diagnostics = taskManager and taskManager:getDiagnostics() or {}
                    diagnostics.status = petLocator and buildStatusLine(state, petLocator) or nil
                    diagnostics.team = state:get("player.team")
                    diagnostics.place = state:get("player.interior")
                    diagnostics.ready = state:get("game.ready")
                    diagnostics.farmEnabled = config.Farm.Enabled
                    local character = game:GetService("Players").LocalPlayer.Character
                    diagnostics.character = character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil
                    return diagnostics
                end)
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
        do
            local lastSummaryAt = Util.now()
            scheduler:addJob("SummaryWebhook", SUMMARY_CHECK_SECONDS, function()
                local minutes = tonumber(config.Notifications.SummaryIntervalMinutes) or 0
                if not notifier:isEnabled() or config.Notifications.SendSummary == false or minutes <= 0 then
                    lastSummaryAt = Util.now()
                    return
                end
                local picture = petThumbnail()
                if Util.now() - lastSummaryAt >= minutes * 60 then
                    lastSummaryAt = Util.now()
                    notifier:notify(Enums.NotifyEvent.Summary, summaryFields(), nil, { thumbnail = picture })
                end
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
        if taskManager then
            local lastCashbackAt = Util.now()
            scheduler:addJob("Cashback", CASHBACK_CHECK_SECONDS, function()
                if not (config.Farm.Enabled and config.Farm.CollectCashback) then
                    return
                end
                if Util.now() - lastCashbackAt < math.max(1, tonumber(config.Farm.CashbackMinutes) or 10) * 60 then
                    return
                end
                if state:get("game.ready") ~= true or state:get("session.disconnectReason") ~= nil then
                    return
                end
                local before = state:get("player.bucks")
                if not taskManager:sendDirect("CollectCashback") then
                    return
                end
                lastCashbackAt = Util.now()
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
        SessionWatcher.start(maid, logger, notifier, state, sessionStore)
        do
            local localPlayer = game:GetService("Players").LocalPlayer
            local idled = localPlayer and localPlayer.Idled
            if idled then
                maid:Give(idled:Connect(function()
                    if not config.Farm.AntiAfk then
                        return
                    end
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
        do
            local pushing, lastLog = false, -math.huge
            scheduler:addJob("CameraGuard", 1, function()
                if not config.Farm.CameraGuard or pushing then
                    return
                end
                pcall(function()
                    local player = Players.LocalPlayer
                    local camera = workspace.CurrentCamera
                    local character = player and player.Character
                    local head = character and character:FindFirstChild("Head")
                    if not (camera and head) or camera.CameraType ~= Enum.CameraType.Custom
                        or player.CameraMode == Enum.CameraMode.LockFirstPerson then
                        return
                    end
                    if (camera.CFrame.Position - head.Position).Magnitude > CAMERA_INSIDE_STUDS then
                        return
                    end
                    pushing = true
                    local before = player.CameraMinZoomDistance
                    player.CameraMinZoomDistance = math.max(before, CAMERA_OUT_STUDS)
                    task.delay(0.3, function()
                        pcall(function()
                            player.CameraMinZoomDistance = before
                        end)
                        pushing = false
                    end)
                    if Util.now() - lastLog > 60 then
                        lastLog = Util.now()
                        logger:debug("Camera", "Camera was inside your character: zoomed it back out (Farm.CameraGuard)")
                    end
                end)
            end)
        end
        notifier:notify(Enums.NotifyEvent.SessionStarted, {
            { name = "Session time", value = "00:00:00", inline = true },
        }, Disclosure.buildShortText())
        if config.Notifications.SendTestMessageOnStart then
            notifier:notify(Enums.NotifyEvent.Test, {}, "If you can read this, the webhook works.")
        end
        scheduler:start()
        logger:success("Core", "Started. Version " .. Disclosure.VERSION)
        local api = { Version = Disclosure.VERSION, State = state, Disclosure = function()
            for _, line in ipairs(disclosureLines) do
                logger:report("Disclosure", line)
            end
        end }
        local stopped = false
        api.Config = config
        function api.Icons()
            local pet = state:get("pets.equipped", {})[1]
            return {
                bucks = gameIcons:known("bucks") or gameIcons:currency("bucks", state:get("player.bucks")),
                candy = gameIcons:known("candy") or gameIcons:currency("candy", uiGameData and uiGameData:get("candy_2026")),
                pet = pet and gameIcons:item(pet.kind) or nil,
            }
        end
        function api.GameIcon(name)
            return gameIcons:picture(name)
        end
        function api.Status()
            local diagnostics = taskManager and taskManager:getDiagnostics() or {}
            local started = state:get("session.startedAt")
            local candy = candyNow()
            local pets = {}
            for _, pet in ipairs(state:get("pets.equipped", {})) do
                table.insert(pets, { kind = pet.kind, age = pet.age })
            end
            local needs = {}
            for _, entry in ipairs(state:get("ailments.active", {})) do
                table.insert(needs, { owner = entry.owner, kind = entry.kind, inProgress = entry.inProgress == true })
            end
            local nextRoundIn = nil
            pcall(function()
                local now = Minigame.serverNow()
                local start = uiGameData and EventTasks.nextRoundStart(uiGameData:get(GameConstants.DataKeys.GhostCycle), now)
                if start then
                    nextRoundIn = math.max(0, math.floor(start - now))
                end
            end)
            local event = config.Farm.Event
            local featuresOn, featuresTotal = Config.countFeatures(config)
            local keys, twigs, nestTwigs
            if uiGameData then
                pcall(function()
                    keys = #uiGameData:itemsOfId(GameConstants.ToyCategory, GameConstants.Event.RustyKey)
                    twigs = #uiGameData:itemsOfId(GameConstants.ToyCategory, GameConstants.Event.Twig)
                    local nest = uiGameData:get(GameConstants.DataKeys.PigeonNest)
                    nestTwigs = type(nest) == "table" and tonumber(nest.twigs_contributed) or nil
                end)
            end
            return {
                lastTask = state:get("stats.lastTask"),
                rustyKeys = keys,
                twigs = twigs,
                nestTwigs = nestTwigs,
                featuresOn = featuresOn,
                featuresTotal = featuresTotal,
                preset = config.Preset,
                ghostEnabled = event.Enabled == true and event.GhostGallery == true,
                petPenEnabled = event.Enabled == true and event.PetPen == true,
                pen = taskManager and taskManager:getPenInfo() or nil,
                webhooksOn = notifier:isEnabled(),
                restMinutes = diagnostics.restMinutes,
                version = Disclosure.VERSION,
                stopped = stopped,
                farmEnabled = config.Farm.Enabled == true,
                ready = state:get("game.ready") == true,
                team = state:get("player.team"),
                place = state:get("player.interior"),
                task = state:get("farm.currentTask", "none"),
                sideTask = diagnostics.side,
                minutes = started and math.floor((Util.now() - started) / 60) or 0,
                needsDone = state:get("stats.needsCompleted", 0),
                bucksEarned = state:get("stats.bucksEarned", 0),
                bucks = state:get("player.bucks"),
                candy = candy,
                candyEarned = (candy and uiCandyStart) and (candy - uiCandyStart) or nil,
                pets = pets,
                needs = needs,
                nextRoundIn = nextRoundIn,
                tasksSucceeded = state:get("farm.tasksSucceeded", 0),
                tasksFailed = state:get("farm.tasksFailed", 0),
                disabled = diagnostics.disabled,
                line = petLocator and buildStatusLine(state, petLocator) or nil,
            }
        end
        local function quickAction(run)
            if stopped then
                return false, "The farm is stopped: run the loader again"
            end
            if not taskManager then
                return false, "Not in Adopt Me, or the game is not ready yet"
            end
            if not config.Farm.Enabled then
                return false, "Paused: switch 'Farm running' on first (paused = no game actions)"
            end
            return run()
        end
        function api.GoHome()
            return quickAction(function()
                return taskManager:requestGoHome()
            end)
        end
        function api.SkipTask()
            return quickAction(function()
                return taskManager:skipCurrent()
            end)
        end
        function api.ClaimPetPen()
            return quickAction(function()
                return taskManager:requestPetPen()
            end)
        end
        function api.RetryDisabled()
            if not taskManager then
                return false, "Not in Adopt Me, or the game is not ready yet"
            end
            local count = taskManager:retryDisabled()
            return true, count > 0 and string.format("%d resting task%s may run again", count, count == 1 and "" or "s")
                or "No task was resting"
        end
        function api.Catalog()
            local catalog = { petKinds = {}, giftIds = {} }
            if not uiGameData then
                return catalog
            end
            local seenKinds = {}
            local inventory = uiGameData:get(GameConstants.DataKeys.Inventory)
            local pets = type(inventory) == "table" and type(inventory.pets) == "table" and inventory.pets or {}
            for _, pet in pairs(pets) do
                local kind = type(pet) == "table" and tostring(pet.kind or pet.id or "") or ""
                if kind ~= "" and not seenKinds[kind] and not GameConstants.NotFarmablePets[kind] then
                    seenKinds[kind] = true
                    table.insert(catalog.petKinds, kind)
                end
            end
            local seenGifts = {}
            for _, item in ipairs(uiGameData:findItems(GameConstants.GiftCategory, nil)) do
                local id = tostring(item.id)
                if not seenGifts[id] then
                    for _, pattern in pairs(GameConstants.GiftPatterns) do
                        if string.find(id, pattern) and not seenGifts[id] then
                            seenGifts[id] = true
                            table.insert(catalog.giftIds, id)
                        end
                    end
                end
            end
            table.sort(catalog.petKinds)
            table.sort(catalog.giftIds)
            return catalog
        end
        function api.TestWebhook()
            if not notifier:isEnabled() then
                return false, "Set a webhook URL first (" .. notifier:getStatusText() .. ")"
            end
            notifier:notify(Enums.NotifyEvent.Test, {}, "If you can read this, the webhook works.")
            notifier:pump()
            return true, "Test message sent: check your Discord channel"
        end
        function api.ApplyPreset(name)
            local values, preset = Config.presetValues(name)
            if not values then
                return false, "No preset called " .. tostring(name)
            end
            for _, entry in ipairs(values) do
                local parent = Config.valueAt(config, { table.unpack(entry[1], 1, #entry[1] - 1) })
                if type(parent) == "table" then
                    parent[entry[1][#entry[1]]] = entry[2]
                end
            end
            config.Preset = preset.id
            logger:info("Core", "Preset applied: " .. preset.name)
            return true, preset.name
        end
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
            telemetry:pump(true)
            notifier:notify(Enums.NotifyEvent.SessionStopped, summaryFields(), "Reason: " .. reason, { thumbnail = petThumbnail() })
            if sharedEnvironment[GLOBAL_KEY] == api then
                sharedEnvironment[GLOBAL_KEY] = nil
            end
            maid:Clean()
            task.spawn(function()
                notifier:flush(STOP_FLUSH_SECONDS)
                logger:info("Core", "Stopped cleanly")
                logger:close()
                state:destroy()
            end)
        end
        function api.OpenInterface()
            local okUi, uiError = pcall(Interface.start, api, { logger = logger, settings = config.Interface })
            if not okUi then
                logger:warn("Interface", "Window not opened (the farm keeps running): " .. tostring(uiError))
            end
            return okUi
        end
        sharedEnvironment[GLOBAL_KEY] = api
        if config.Interface.Enabled then
            task.spawn(api.OpenInterface)
        end
        return api
    end
end
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
