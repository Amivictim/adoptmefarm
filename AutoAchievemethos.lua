local DEBUG = false
local GC = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local env = getgenv and getgenv() or {}
if env.AutoAchievements and env.AutoAchievements.Stop then
	pcall(env.AutoAchievements.Stop)
end
local running = false
local uiLog = nil
local ui = {}
GC.LogFolder = "AutoAchievements"
local writeLine = function() end
if DEBUG then
	local startClock = os.clock()
	local logFile = GC.LogFolder .. "/debug_run_" .. os.time() .. ".txt"
	local logLines = {}
	pcall(function()
		if type(isfolder) == "function" and not isfolder(GC.LogFolder) then
			makefolder(GC.LogFolder)
		end
		writefile(logFile, "")
	end)
	writeLine = function(level, message)
		local line = string.format("%s +%7.1fs [%s] %s", os.date("%H:%M:%S"), os.clock() - startClock, level, tostring(message))
		table.insert(logLines, line)
		pcall(function()
			if type(appendfile) == "function" then
				appendfile(logFile, line .. "\n")
			else
				writefile(logFile, table.concat(logLines, "\n") .. "\n")
			end
		end)
	end
	writeLine("INFO", "Debug run. Log file: workspace/" .. logFile)
end
local logRing = {}
do
	local toFile = writeLine
	writeLine = function(level, message)
		table.insert(logRing, os.date("%H:%M:%S") .. " [" .. tostring(level) .. "] " .. string.sub(tostring(message), 1, 300))
		if #logRing > 150 then
			table.remove(logRing, 1)
		end
		toFile(level, message)
	end
end
local function log(level, message)
	writeLine(level, message)
end
local status = { now = "Ready", goal = "Completes your Guide tasks", queue = {} }
local function renderStatus()
	if ui.now then
		pcall(function()
			ui.now.Text = status.now
			ui.goal.Text = status.goal
			ui.queue.Text = #status.queue > 0 and ("Next: " .. table.concat(status.queue, "\n         ")) or ""
		end)
	end
end
local function setGoal(text, queue)
	if text ~= status.goal then
		writeLine("GOAL", text)
	end
	status.goal = text or ""
	status.queue = queue or {}
	renderStatus()
end
local function setNow(text)
	status.now = text or ""
	renderStatus()
end
local function say(text, tone)
	writeLine("SAY", text)
	if not tone then
		setNow(text)
	end
	if uiLog then
		pcall(uiLog, tone or "info", text)
	end
end
GC.Skip = {}
local clientData
do
	local ok, result = pcall(function()
		return require(ReplicatedStorage:WaitForChild("ClientModules", 15):WaitForChild("Core", 15):WaitForChild("ClientData", 15))
	end)
	if not ok or type(result) ~= "table" or type(result.get_data) ~= "function" then
		log("ERROR", "ClientData not usable: " .. tostring(result))
		return
	end
	clientData = result
end
local function getKey(key)
	local ok, all = pcall(clientData.get_data)
	local mine = ok and type(all) == "table" and all[LocalPlayer.Name]
	return type(mine) == "table" and mine[key] or nil
end
local function manager()
	local m = getKey("achievements_manager")
	return type(m) == "table" and m or nil
end
local function isCompleted(id)
	local m = manager()
	return m ~= nil and type(m.completed) == "table" and m.completed[id] ~= nil
end
local function currentPlace()
	local interior = getKey("house_interior")
	if type(interior) ~= "table" then
		return nil
	end
	if type(interior.interior_name) == "string" then
		return interior.interior_name
	end
	return interior.house_pos ~= nil and "housing" or nil
end
local function waitUntil(predicate, seconds)
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		local ok, result = pcall(predicate)
		if ok and result then
			return true
		end
		task.wait(0.1)
	end
	return false
end
local definitions = {}
pcall(function()
	local tracks = require(ReplicatedStorage.new.modules.Achievements.AchievementTracks)
	for trackId, track in pairs(tracks) do
		if type(track) == "table" and type(track.pages) == "table" then
			for pageIndex, page in pairs(track.pages) do
				for id, entry in pairs(page) do
					if type(entry) == "table" then
						definitions[id] = { title = tostring(entry.title or id), description = tostring(entry.description or ""),
							clientAuthoritative = entry.client_authoritative == true, track = tostring(entry.track_id or trackId),
							page = tonumber(entry.page) or tonumber(pageIndex) or 1, sortOrder = tonumber(entry.sort_order) or 999,
							requirement = type(entry.requirement) == "string" and entry.requirement or nil }
					end
				end
			end
		end
	end
end)
GC.PLACE_NAMES = { HatShop = "the Accessory Shop", AutoShop = "the Dealership", ToyShop = "the Toy Shop",
	housing = "your house", MainMap = "town", PizzaShop = "the Pizza Place", Nursery = "the Nursery", School = "the School",
	Salon = "the Salon", Hospital = "the Hospital", CatCafe = "the Cat Cafe", Neighborhood = "the neighborhood" }
GC.ITEM_NAMES = { cracked_egg = "a Cracked Egg", smallgift = "a Small Gift", stickers_2024_standard_pack = "a sticker pack",
	vehicle_shop_2022_bicycle = "a bicycle", red_collar = "a red collar" }
GC.ACT_LINES = {
	buy_a_new_texture = "Picking a fresh wallpaper",
	buy_furniture = "Shopping for a mini fridge",
	sell_furniture = "Buying a bed... and selling it right back",
	store_furniture = "Putting a bed into storage",
	dress_up_a_pet = "Dressing your pet up with a red collar",
	save_a_pet_outfit = "Saving your pet's new look",
	name_a_pet = "Naming your pet Buddy",
	paint_a_pet = "Giving your pet a fresh coat of paint",
	work_a_job = "Clocking in at the Pizza Place",
	equip_an_egg = "Grabbing an egg from the backpack",
	obtain_a_trade_license = "Taking the Trade License test",
	get_a_trade_license = "Taking the Trade License test",
	customize_the_weather = "Changing the weather at home",
	place_a_furniture = "Placing a free pet bathtub",
	place_a_lure = "Setting up a Box Lure",
	bait_a_lure = "Putting bait in the Box Lure",
	color_your_house = "Painting the house",
	buy_a_new_house = "House hunting: grabbing a Micro house",
}
local function titleOf(id)
	local def = definitions[id]
	return def and def.title or id
end
local function placeName(place)
	return GC.PLACE_NAMES[place] or tostring(place)
end
local unlockedBy = {}
local function guideOrder(a, b)
	local ra, rb = unlockedBy[a] == "ready", unlockedBy[b] == "ready"
	if ra ~= rb then
		return ra
	end
	local da, db = definitions[a] or {}, definitions[b] or {}
	if (da.page or 9) ~= (db.page or 9) then
		return (da.page or 9) < (db.page or 9)
	end
	if (da.sortOrder or 999) ~= (db.sortOrder or 999) then
		return (da.sortOrder or 999) < (db.sortOrder or 999)
	end
	return a < b
end
local skip = {}
for _, id in ipairs(GC.Skip) do
	skip[id] = true
end
local function readyIds()
	local m = manager()
	local list = {}
	local seen = {}
	local completed = m and type(m.completed) == "table" and m.completed or {}
	if m and type(m.ready) == "table" then
		for id, isReady in pairs(m.ready) do
			if isReady and completed[id] == nil and not skip[id] then
				table.insert(list, id)
				seen[id] = true
				unlockedBy[id] = "ready"
			end
		end
	end
	table.sort(list, guideOrder)
	return list
end
GC.RemoteTimeout = 10
local api = ReplicatedStorage:WaitForChild("API", 15)
local function serialize(value, depth)
	local t = typeof(value)
	if t == "string" then
		return string.format("%q", #value > 150 and string.sub(value, 1, 150) .. "..." or value)
	elseif t == "Instance" then
		local ok, name = pcall(function() return value:GetFullName() end)
		return "<" .. value.ClassName .. " " .. (ok and name or "?") .. ">"
	elseif t == "table" then
		if depth >= 3 then
			return "{...}"
		end
		local parts, n = {}, 0
		for k, v in pairs(value) do
			n += 1
			if n > 15 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, "[" .. serialize(k, depth + 1) .. "]=" .. serialize(v, depth + 1))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end
local function fire(remote, remoteName, timeout, ...)
	if not remote then
		log("ERROR", remoteName .. " not found")
		return false
	end
	local args = table.pack(...)
	if not GC.NOISE[remoteName] then
		local parts = {}
		for i = 1, args.n do
			parts[i] = serialize(args[i], 0)
		end
		log("SEND", remoteName .. "(" .. table.concat(parts, ", ") .. ")")
	end
	if not remote:IsA("RemoteFunction") then
		local ok, err = pcall(function() remote:FireServer(table.unpack(args, 1, args.n)) end)
		if not ok then
			log("ERROR", remoteName .. ": " .. tostring(err))
		end
		return ok
	end
	local finished, ok, result = false, nil, nil
	task.spawn(function()
		ok, result = pcall(function() return remote:InvokeServer(table.unpack(args, 1, args.n)) end)
		finished = true
	end)
	if timeout > 0 then
		waitUntil(function() return finished end, timeout)
	end
	if not finished then
		if timeout > 0 then
			log("WARN", remoteName .. ": no answer after " .. timeout .. " s")
		end
		return true
	end
	log("INFO", remoteName .. " -> ok=" .. tostring(ok) .. " result=" .. tostring(result))
	return ok, result
end
local function send(remoteName, ...)
	return fire(api and api:FindFirstChild(remoteName), remoteName, GC.RemoteTimeout, ...)
end
local function sendNoWait(remoteName, ...)
	return fire(api and api:FindFirstChild(remoteName), remoteName, 0, ...)
end
local function sendNet(remoteName, ...)
	local folder = ReplicatedStorage:FindFirstChild("adoptme_new_net")
	return fire(folder and folder:FindFirstChild(remoteName), remoteName, GC.RemoteTimeout, ...)
end
GC.ArrivalTimeout = 35
GC.DOORS = {
	MainMap = "Neighborhood/MainDoor", housing = "MainDoor",
	Nursery = "MainDoor", Hospital = "MainDoor", PizzaShop = "MainDoor", Salon = "MainDoor", School = "MainDoor",
	HatShop = "MainDoor", AutoShop = "MainDoor", ToyShop = "MainDoor", CatCafe = "MainDoor",
	Neighborhood = "MainDoor",
}
local interiorsM
local function isAt(place)
	local now = currentPlace()
	return type(now) == "string" and string.sub(now, 1, #place) == place
end
local function goTo(place)
	if not place or isAt(place) then
		return true
	end
	if not GC.DOORS[place] then
		return false, "no route to " .. place
	end
	if not interiorsM then
		local ok, module = pcall(function() return require(ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM) end)
		if not ok or type(module) ~= "table" or type(module.enter) ~= "function" then
			return false, "InteriorsM not usable"
		end
		interiorsM = module
	end
	say("Heading to " .. placeName(place) .. "...")
	local options = place == "housing" and { house_owner = LocalPlayer } or {}
	task.spawn(pcall, interiorsM.enter, place, GC.DOORS[place], options)
	if waitUntil(function() return isAt(place) end, GC.ArrivalTimeout) then
		task.wait(0.5)
		return true
	end
	return false, "still in " .. tostring(currentPlace())
end
local function money()
	return tonumber(getKey("money")) or 0
end
local function itemsOf(category, wanted)
	local inventory = getKey("inventory")
	local items = type(inventory) == "table" and type(inventory[category]) == "table" and inventory[category] or {}
	local list = {}
	for key, item in pairs(items) do
		if type(item) == "table" then
			local id = tostring(item.id)
			if wanted == nil or (type(wanted) == "function" and wanted(id)) or (type(wanted) == "table" and wanted[id]) then
				table.insert(list, { unique = tostring(item.unique or key), id = id, properties = item.properties })
			end
		end
	end
	table.sort(list, function(a, b) return a.unique < b.unique end)
	return list
end
local function firstOf(category, ids)
	for _, id in ipairs(ids) do
		local found = itemsOf(category, { [id] = true })[1]
		if found then
			return found
		end
	end
	return nil
end
local function hasUnique(category, unique)
	local inventory = getKey("inventory")
	return type(inventory) == "table" and type(inventory[category]) == "table" and inventory[category][unique] ~= nil
end
local function firstItem(category, wantedId)
	local found = itemsOf(category, wantedId and { [wantedId] = true } or nil)[1]
	if found then
		return found.unique, found.id
	end
	return nil
end
local function equippedPets()
	local equip = getKey("equip_manager")
	local list = {}
	for _, pet in pairs(type(equip) == "table" and type(equip.pets) == "table" and equip.pets or {}) do
		if type(pet) == "table" and type(pet.unique) == "string" then
			table.insert(list, pet)
		end
	end
	return list
end
local function isEquipped(unique)
	for _, pet in ipairs(equippedPets()) do
		if pet.unique == unique then
			return true
		end
	end
	return false
end
local function petWrapper(unique)
	local wrappers = getKey("pet_char_wrappers_raw")
	for _, wrapper in pairs(type(wrappers) == "table" and wrappers or {}) do
		if type(wrapper) == "table" and wrapper.pet_unique == unique then
			return wrapper
		end
	end
	return nil
end
local function petStreamingId(unique)
	local wrapper = petWrapper(unique)
	return wrapper and type(wrapper.char) == "string" and wrapper.char or nil
end
local function petModel(unique)
	local streamingId = petStreamingId(unique)
	local folder = workspace:FindFirstChild("Pets")
	if not (streamingId and folder) then
		return nil
	end
	for _, model in ipairs(folder:GetChildren()) do
		local ok, value = pcall(function() return model:GetAttribute("StreamingId") end)
		if ok and value == streamingId then
			return model
		end
	end
	return nil
end
local inventoryDB
local function dbEntry(kind)
	if inventoryDB == nil then
		local ok, db = pcall(function()
			return require(ReplicatedStorage:WaitForChild("Fsys", 10)).load("InventoryDB")
		end)
		inventoryDB = ok and type(db) == "table" and db or false
	end
	local entry = inventoryDB and type(inventoryDB.pets) == "table" and inventoryDB.pets[tostring(kind or "")]
	return type(entry) == "table" and entry or nil
end
local function isEgg(kind)
	local entry = dbEntry(kind)
	if entry and entry.is_egg ~= nil then
		return entry.is_egg == true
	end
	return string.sub(tostring(kind or ""), -4) == "_egg"
end
local function isTemporary(kind)
	local entry = dbEntry(kind)
	return entry ~= nil and entry.temporary == true
end
GC.RARITY = { common = 1, uncommon = 2, rare = 3, ultra_rare = 4, ultrarare = 4, ["ultra rare"] = 4, legendary = 5 }
GC.NEON_GOALS = { make_a_neon_pet = true, obtain_a_neon_pet = true, get_four_full_grown_neon_pets = true,
	make_a_mega_neon_pet = true }
GC.PETS_PAGE_ONE = { open_backpack = 1, equip_an_egg = 2, complete_a_need = 3, hatch_an_egg = 4 }
local function rarityOf(kind)
	local entry = dbEntry(kind)
	return entry and GC.RARITY[string.lower(tostring(entry.rarity or ""))] or 3
end
local function petAge(unique)
	local item = itemsOf("pets", nil)
	for _, pet in ipairs(item) do
		if pet.unique == unique then
			return type(pet.properties) == "table" and tonumber(pet.properties.age) or nil
		end
	end
	return nil
end
local function prettyKind(kind)
	return (string.gsub(tostring(kind or "pet"), "_", " "))
end
local function waitEquipped(unique)
	return waitUntil(function() return isEquipped(unique) end, 6)
end
local sessionPet = nil
local function choosePet()
	if sessionPet then
		for _, pet in ipairs(itemsOf("pets", nil)) do
			if pet.unique == sessionPet.unique then
				sessionPet.kind = pet.id
				return sessionPet
			end
		end
	end
	local realPet, realAge, egg
	for _, pet in ipairs(itemsOf("pets", nil)) do
		if not isTemporary(pet.id) then
			local entry = { unique = pet.unique, kind = pet.id }
			if isEgg(pet.id) then
				egg = egg or entry
			else
				local age = type(pet.properties) == "table" and tonumber(pet.properties.age) or 1
				if not realPet or age > realAge then
					realPet, realAge = entry, age
				end
			end
		end
	end
	sessionPet = realPet or egg
	return sessionPet
end
local function firstPet()
	local pet = choosePet()
	if not pet then
		return nil
	end
	for _, equipped in ipairs(equippedPets()) do
		if equipped.unique == pet.unique then
			return pet
		end
	end
	send("ToolAPI/Equip", pet.unique, { equip_as_last = false, use_sound_delay = true })
	waitEquipped(pet.unique)
	return pet
end
local function ensureModel(pet)
	local model = petModel(pet.unique)
	if model then
		return model
	end
	firstPet()
	waitUntil(function()
		model = petModel(pet.unique)
		return model ~= nil
	end, 10)
	return model
end
local function penPets()
	local pen = getKey("idle_progression_manager")
	local set, count = {}, 0
	for unique in pairs(type(pen) == "table" and type(pen.active_pets) == "table" and pen.active_pets or {}) do
		set[tostring(unique)] = true
		count += 1
	end
	return set, count
end
local function sparePets(eggsFirst)
	local inPen = penPets()
	local session = choosePet()
	local list = {}
	for _, pet in ipairs(itemsOf("pets", nil)) do
		if not isTemporary(pet.id) and not inPen[pet.unique] and not (session and session.unique == pet.unique)
			and not isEquipped(pet.unique) then
			local props = type(pet.properties) == "table" and pet.properties or {}
			table.insert(list, { unique = pet.unique, kind = pet.id, egg = isEgg(pet.id), rarity = rarityOf(pet.id),
				age = tonumber(props.age) or 1, neon = props.neon == true, mega = props.mega_neon == true })
		end
	end
	table.sort(list, function(a, b)
		if a.egg ~= b.egg then
			if eggsFirst then
				return a.egg
			end
			return not a.egg
		end
		if a.rarity ~= b.rarity then
			return a.rarity < b.rarity
		end
		if a.age ~= b.age then
			return a.age < b.age
		end
		return a.unique < b.unique
	end)
	return list
end
local function houseFurnitureKeys()
	local interior = getKey("house_interior")
	local keys = {}
	for key in pairs(type(interior) == "table" and type(interior.furniture) == "table" and interior.furniture or {}) do
		keys[key] = true
	end
	return keys
end
local function buyFurniture(kind, x, z)
	local before = houseFurnitureKeys()
	send("HousingAPI/BuyFurnitures", { { properties = { cframe = CFrame.new(x, 0, z) }, kind = kind } })
	local newKey
	waitUntil(function()
		for key in pairs(houseFurnitureKeys()) do
			if not before[key] then
				newKey = key
				return true
			end
		end
		return false
	end, 6)
	return newKey
end
GC.PLACE_SPOTS = { { 39.1, -13.2 }, { 38.5, -8.5 }, { 14.5, -31 }, { 10.6, -19.6 }, { 12.4, -24 } }
local function placeFurniture(kind)
	local ok, why = goTo("housing")
	if not ok then
		return nil, why
	end
	for _, spot in ipairs(GC.PLACE_SPOTS) do
		local key = buyFurniture(kind, spot[1], spot[2])
		if key then
			return key
		end
	end
	return nil, "the game did not take " .. kind .. " at any known spot"
end
local function character()
	return LocalPlayer.Character
end
local function hasLicense()
	return itemsOf("toys", { trade_license = true })[1] ~= nil
end
local function inLicenseZone()
	local wrapper = getKey("char_wrapper_raw")
	local location = type(wrapper) == "table" and type(wrapper.location) == "table" and wrapper.location
	return type(location) == "table" and location.destination_id == "TradeLicenseZone"
end
local function getLicense()
	if hasLicense() then
		return nil
	end
	local reported = api and api:FindFirstChild("TradeAPI/QuizAnswerReported")
	if not reported then
		return false, "quiz remote not found"
	end
	local reports = {}
	local connection = reported.OnClientEvent:Connect(function(correct, finished, index)
		table.insert(reports, { correct = correct, finished = finished })
	end)
	local function finish(...)
		connection:Disconnect()
		return ...
	end
	if not inLicenseZone() then
		say("Heading to the Trade License booth...")
		if not interiorsM then
			pcall(function()
				interiorsM = require(ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM)
			end)
		end
		if not interiorsM then
			return finish(false, "travel module not found")
		end
		task.spawn(pcall, interiorsM.enter, "TradeLicenseZone", "MainDoor", {})
		if not waitUntil(inLicenseZone, GC.ArrivalTimeout) then
			return finish(false, "could not reach the Trade License booth")
		end
		task.wait(2)
	end
	local function quiz()
		local manager = getKey("trade_license_quiz_manager")
		return type(manager) == "table" and type(manager.quiz) == "table" and manager or nil
	end
	if not quiz() then
		send("TradeAPI/BeginQuiz")
	end
	if not waitUntil(function() return quiz() ~= nil end, 15) then
		return finish(false, "the quiz did not start")
	end
	local lastIndex = 0
	for _ = 1, 8 do
		if hasLicense() then
			break
		end
		waitUntil(function()
			local now = quiz()
			return now == nil or (tonumber(now.question_index) or 1) > lastIndex
		end, 5)
		local manager = quiz()
		if not manager then
			break
		end
		local index = math.max(tonumber(manager.question_index) or 1, lastIndex + 1)
		lastIndex = index
		local question = manager.quiz[index] or manager.quiz[tostring(index)]
		if type(question) ~= "table" or (question.answer ~= "safe" and question.answer ~= "not safe") then
			return finish(false, "no answer for question " .. index)
		end
		task.wait(2)
		say("Question " .. index .. ": " .. (question.answer == "safe" and "Safe!" or "Not safe!"))
		local before = #reports
		send("TradeAPI/AnswerQuizQuestion", question.answer)
		if not waitUntil(function() return #reports > before end, 10) then
			return finish(false, "no answer from the server")
		end
		if reports[#reports].correct ~= true then
			return finish(false, "wrong answer (a new quiz next time)")
		end
		if reports[#reports].finished == true then
			break
		end
	end
	if waitUntil(hasLicense, 10) then
		send("TradeAPI/EndQuiz")
		return finish(nil)
	end
	return finish(false, "no license yet")
end
GC.BuyFood = true
local function needsOf(unique)
	local manager = getKey("ailments_manager")
	local ailments = type(manager) == "table" and type(manager.ailments) == "table" and manager.ailments[unique]
	local list = {}
	for key, raw in pairs(type(ailments) == "table" and ailments or {}) do
		local kind = tostring(type(raw) == "table" and raw.kind or key)
		local rate = type(raw) == "table" and tonumber(raw.rate) or 0
		list[kind] = { kind = kind, rate = rate, started = rate > 0, progress = type(raw) == "table" and tonumber(raw.progress) or 0,
			raw = raw }
	end
	return list
end
local function needGone(pet, kind)
	return function()
		return needsOf(pet.unique)[kind] == nil
	end
end
local function needStarted(pet, kind)
	return function()
		local entry = needsOf(pet.unique)[kind]
		return entry == nil or entry.started
	end
end
local function waitNeedDone(pet, kind, extra)
	local entry = needsOf(pet.unique)[kind]
	local expected = (entry and entry.rate > 0) and (1 / entry.rate) or 30
	return waitUntil(needGone(pet, kind), math.min(expected + (extra or 20), 200))
end
local function isSitting()
	local manager = getKey("state_manager_raw")
	return type(manager) == "table" and manager.is_sitting == true
end
local function standUp()
	if isSitting() then
		send("AdoptAPI/ExitSeatStates")
		waitUntil(function() return not isSitting() end, 4)
	end
end
local function petOnFurniture(pet)
	local streamingId = petStreamingId(pet.unique)
	local interior = getKey("house_interior")
	for _, piece in pairs(type(interior) == "table" and type(interior.furniture) == "table" and interior.furniture or {}) do
		if type(piece) == "table" and type(piece.occupied) == "table" then
			for _, who in pairs(piece.occupied) do
				if who == streamingId then
					return true
				end
			end
		end
	end
	return false
end
local function petOff(pet)
	if petOnFurniture(pet) then
		send("PetAPI/ExitFurnitureUseStates", pet.unique)
		waitUntil(function() return not petOnFurniture(pet) end, 4)
	end
end
GC.NEED_PLACE = { salon = "Salon", bored = "MainMap", cat_cafe = "CatCafe", pizza_party = "PizzaShop", school = "School",
	sick = "Hospital", camping = "MainMap", beach_party = "MainMap" }
GC.NEED_SPOT = { camping = { -18.443, 37.204, -1046.005 }, beach_party = { -579.456, 25.634, -1496.408 },
	bored = { -401.629, 29.779, -1760.047 } }
GC.NEED_FURNITURE = { sleepy = { "basicbed" }, dirty = { "cheap_pet_bathtub", "stylishshower", "modernshower", "cheap_pet_bathtub_tutorial" },
	toilet = { "toilet" } }
GC.USE_BLOCK = { modernshower = "UseBlock", cheap_pet_bathtub_tutorial = "UseBlock", ailments_refresh_2024_cheap_food_bowl = "UseBlock",
	cheap_pet_bathtub = "UseBlock",
	basicbed = "Seat1", stylishshower = "UseBlock", toilet = "Seat1" }
GC.FOOD_BOWLS = { "ailments_refresh_2024_cheap_food_bowl" }
GC.NEED_ITEMS = { hungry = { "sandwich-default", "cheese", "hotdog" }, thirsty = { "water", "chocolate_milk" } }
GC.NEED_BUY = { hungry = { id = "hotdog", options = { buy_count = 1 } }, thirsty = { id = "water", options = {} } }
GC.FOOD_CREATOR = "__Enum_PetObjectCreatorType_2"
GC.TOY_CREATOR = "__Enum_PetObjectCreatorType_1"
GC.NEED_LINES = {
	pet_me = "Your pet wants some love: petting it", hungry = "Your pet is hungry: feeding it", thirsty = "Your pet is thirsty",
	sleepy = "Your pet is sleepy: off to bed", dirty = "Your pet is dirty: bath time", toilet = "Your pet needs the toilet",
	play = "Your pet wants to play: throwing a bone", sick = "Your pet is sick: off to the doctor",
	salon = "Your pet wants a makeover at the Salon", school = "Your pet wants to go to School",
	cat_cafe = "Your pet wants a treat at the Cat Cafe", pizza_party = "Pizza party for your pet!",
	camping = "Your pet wants to go camping", beach_party = "Beach party time", bored = "Your pet is bored: playground!",
	walk = "Taking your pet for a walk", ride = "Taking your pet for a ride", mystery = "A mystery need: picking a card",
}
local function pivotTo(position)
	local char = character()
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local streamed = false
	task.spawn(function()
		pcall(function() LocalPlayer:RequestStreamAroundAsync(position, 15) end)
		streamed = true
	end)
	waitUntil(function() return streamed end, 3)
	local y = position.Y + 2
	pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local hit = workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
		if hit then
			y = hit.Position.Y + 3
		end
	end)
	for _ = 1, 3 do
		pcall(function() char:PivotTo(CFrame.new(position.X, y, position.Z)) end)
		task.wait(2)
		local p = root.Position
		if math.abs(p.X - position.X) < 25 and math.abs(p.Z - position.Z) < 25 then
			return true
		end
	end
	return false
end
local function talkToDoctor()
	local interior = getKey("house_interior")
	for key, piece in pairs(type(interior) == "table" and type(interior.furniture) == "table" and interior.furniture or {}) do
		if type(piece) == "table" and piece.id == "doctor" then
			say("Talking to the doctor")
			send("HousingAPI/ActivateInteriorFurniture", key, "UseBlock", "Yes", character())
			return true
		end
	end
	return false
end
local function locationNeed(pet, kind)
	local entry = needsOf(pet.unique)[kind]
	if entry and not entry.started then
		standUp()
		local ok, why = goTo(GC.NEED_PLACE[kind])
		if not ok then
			return false, why
		end
		firstPet()
		local spot = GC.NEED_SPOT[kind]
		if spot and not waitUntil(needStarted(pet, kind), 3) then
			pivotTo(Vector3.new(spot[1], spot[2], spot[3]))
		end
		if kind == "sick" and not waitUntil(needStarted(pet, kind), 4) then
			talkToDoctor()
		end
		if not waitUntil(needStarted(pet, kind), 20) then
			return false, "the need did not start at " .. placeName(GC.NEED_PLACE[kind])
		end
	end
	if waitNeedDone(pet, kind, 20) then
		return true
	end
	return false, kind .. " did not finish"
end
local function furnitureSpots(kinds)
	if not isAt("housing") then
		return {}, "not at home"
	end
	local rank = {}
	for i, kind in ipairs(kinds) do
		rank[kind] = i
	end
	local interior = getKey("house_interior")
	local candidates = {}
	for key, piece in pairs(type(interior) == "table" and type(interior.furniture) == "table" and interior.furniture or {}) do
		if type(piece) == "table" and rank[piece.id] then
			table.insert(candidates, { key = tostring(key), kind = piece.id })
		end
	end
	if #candidates == 0 then
		return {}, "no " .. table.concat(kinds, "/") .. " in your house"
	end
	table.sort(candidates, function(a, b)
		if rank[a.kind] ~= rank[b.kind] then
			return rank[a.kind] < rank[b.kind]
		end
		return a.key < b.key
	end)
	local folder = workspace:FindFirstChild("HouseInteriors")
	folder = folder and folder:FindFirstChild("furniture")
	local prefix = LocalPlayer.Name .. "/"
	local spots = {}
	for _, candidate in ipairs(candidates) do
		local suffix = "/" .. candidate.key
		for _, holder in ipairs(folder and folder:GetChildren() or {}) do
			local name = holder.Name
			if string.sub(name, 1, #prefix) == prefix and string.sub(name, -#suffix) == suffix then
				for _, model in ipairs(holder:GetChildren()) do
					if model:IsA("Model") and model:GetAttribute("furniture_unique") == candidate.key then
						local useName = GC.USE_BLOCK[candidate.kind]
						local blocks = model:FindFirstChild("UseBlocks")
						local part = blocks and useName and blocks:FindFirstChild(useName)
						if part then
							table.insert(spots, { key = candidate.key, kind = candidate.kind, useName = useName,
								cframe = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0) })
						end
					end
				end
			end
		end
	end
	return spots, #spots == 0 and "the furniture is not loaded yet" or nil
end
GC.FREE_FURNITURE = { dirty = "cheap_pet_bathtub" }
local placedFree = {}
local function useFurniture(pet, kind, kinds)
	standUp()
	local ok, why = goTo("housing")
	if not ok then
		return false, why
	end
	local tried = {}
	for _ = 1, 2 do
		local spots, reason = {}, nil
		waitUntil(function()
			spots, reason = furnitureSpots(kinds)
			return #spots > 0 or string.sub(tostring(reason), 1, 3) == "no "
		end, 10)
		local entry = needsOf(pet.unique)[kind]
		if not entry or entry.started then
			break
		end
		local model = ensureModel(pet)
		if not model then
			return false, "pet model not found"
		end
		for _, spot in ipairs(spots) do
			if not tried[spot.key] then
				tried[spot.key] = true
				petOff(pet)
				log("NEED", "using " .. spot.kind .. " " .. spot.key)
				sendNoWait("HousingAPI/ActivateFurniture", LocalPlayer, spot.key, spot.useName, { cframe = spot.cframe }, model)
				if waitUntil(needStarted(pet, kind), 6) then
					break
				end
			end
		end
		if waitUntil(needStarted(pet, kind), 0.5) then
			break
		end
		local free = GC.FREE_FURNITURE[kind]
		if not free or placedFree[kind] then
			petOff(pet)
			return false, #spots == 0 and reason or ("no furniture started the need (" .. spots[1].kind .. ")")
		end
		placedFree[kind] = true
		say("Your furniture doesn't work for this: placing a free " .. prettyKind(free))
		placeFurniture(free)
	end
	if not waitUntil(needStarted(pet, kind), 0.5) then
		petOff(pet)
		return false, "no furniture started the need"
	end
	local done = waitNeedDone(pet, kind, 15)
	petOff(pet)
	return done, (not done) and (kind .. " did not finish") or nil
end
local function furnitureNeed(pet, kind)
	return useFurniture(pet, kind, GC.NEED_FURNITURE[kind])
end
local function petObjects()
	local folder = workspace:FindFirstChild("PetObjects")
	local set = {}
	for _, child in ipairs(folder and folder:GetChildren() or {}) do
		set[child] = true
	end
	return set
end
local function newPetObject(before)
	local folder = workspace:FindFirstChild("PetObjects")
	for _, child in ipairs(folder and folder:GetChildren() or {}) do
		if not before[child] then
			return child
		end
	end
	return nil
end
local function giveItem(pet, item, done)
	local model = ensureModel(pet)
	if not model then
		return false, "pet model not found"
	end
	local before = petObjects()
	send("ToolAPI/Equip", item.unique, { equip_as_last = false, use_sound_delay = true })
	task.wait(0.5)
	send("AdoptAPI/FocusPet", model)
	send("ToolAPI/ServerUseTool", item.unique, "START")
	send("PetObjectAPI/CreatePetObject", GC.FOOD_CREATOR, { additional_consume_uniques = {}, pet_unique = pet.unique, unique_id = item.unique })
	send("ToolAPI/Unequip", item.unique, nil)
	send("AdoptAPI/UnfocusPet", model)
	if waitUntil(done, 10) then
		return true
	end
	local object = newPetObject(before)
	if not object then
		return false, "nothing appeared for your pet"
	end
	send("PetObjectAPI/GrabPetObject", model, object)
	task.wait(1)
	send("PetAPI/ConsumeFoodObject", object, pet.unique)
	local ok = waitUntil(done, 6)
	return ok, (not ok) and "your pet did not take it" or nil
end
local function feedNeed(pet, kind)
	standUp()
	local done = needGone(pet, kind)
	for _ = 1, 3 do
		if done() then
			return true
		end
		local item = firstOf("food", GC.NEED_ITEMS[kind])
		if not item and kind == "hungry" and (isAt("housing") or not GC.BuyFood) then
			local ok = useFurniture(pet, kind, GC.FOOD_BOWLS)
			if ok or done() then
				return true
			end
		end
		if not item and GC.BuyFood then
			local buy = GC.NEED_BUY[kind]
			say("Buying " .. buy.id .. " for your pet")
			send("ShopAPI/BuyItem", "food", buy.id, buy.options)
			waitUntil(function()
				item = firstOf("food", { buy.id })
				return item ~= nil
			end, 6)
		end
		if not item then
			return false, "nothing to eat or drink in your backpack"
		end
		local ok = giveItem(pet, item, done)
		if ok then
			return true
		end
	end
	return done(), "still " .. kind
end
local function playNeed(pet)
	local toy = firstOf("toys", { "squeaky_bone_default" })
	if not toy then
		return false, "no squeaky bone in your backpack"
	end
	local model = ensureModel(pet)
	if not model then
		return false, "pet model not found"
	end
	local holding = false
	local result, why = false, "your pet did not catch the bone"
	for _ = 1, 6 do
		local entry = needsOf(pet.unique).play
		if not entry then
			result, why = true, nil
			break
		end
		local progressBefore = entry.progress
		local before = petObjects()
		send("ToolAPI/Equip", toy.unique, {})
		if holding then
			send("PetObjectAPI/DropPetObject", model)
			holding = false
		end
		task.wait(0.5)
		send("ToolAPI/ServerUseTool", toy.unique, "START")
		send("PetObjectAPI/CreatePetObject", GC.TOY_CREATOR, { reaction_name = "ThrowToyReaction", unique_id = toy.unique })
		send("ToolAPI/Unequip", toy.unique, { from_throw_toy = true })
		send("ToolAPI/ServerUseTool", toy.unique, "END", nil)
		local function caught()
			local now = needsOf(pet.unique).play
			return now == nil or now.progress > progressBefore
		end
		if not waitUntil(caught, 6) then
			local object = newPetObject(before)
			if object then
				send("PetObjectAPI/GrabPetObject", model, object, nil)
			end
			if not waitUntil(caught, 4) then
				break
			end
		end
		holding = true
		task.wait(1)
	end
	if holding then
		send("ToolAPI/Equip", toy.unique, {})
		send("PetObjectAPI/DropPetObject", model)
		send("ToolAPI/Unequip", toy.unique, nil)
	end
	if needsOf(pet.unique).play == nil then
		return true
	end
	return result, why
end
local NEED_DO
local mysteryFns
local function mysteryCards(pet)
	local ok, client = pcall(function() return require(ReplicatedStorage.new.modules.Ailments.ClientActions.MysteryAilmentClient) end)
	if not ok or type(client) ~= "table" or type(client._get_ailment_slots) ~= "function" then
		return nil
	end
	local raw = needsOf(pet.unique).mystery
	raw = raw and raw.raw
	local component = type(raw) == "table" and type(raw.components) == "table" and raw.components.mystery
	if type(component) ~= "table" then
		return nil
	end
	local pool = {}
	for kind in pairs(type(component.components) == "table" and component.components or {}) do
		pool[tostring(kind)] = true
	end
	if not mysteryFns then
		mysteryFns = {}
		pcall(function()
			local loaded
			if type(getloadedmodules) == "function" then
				loaded = {}
				for _, module in ipairs(getloadedmodules()) do
					loaded[module] = true
				end
			end
			for _, module in ipairs(ReplicatedStorage.new.modules.Ailments:GetDescendants()) do
				if module:IsA("ModuleScript") and (loaded == nil or loaded[module]) then
					local okModule, value = pcall(require, module)
					if okModule and type(value) == "table" and type(rawget(value, "get_ailment_slots")) == "function" then
						table.insert(mysteryFns, rawget(value, "get_ailment_slots"))
					end
				end
			end
		end)
		if #mysteryFns == 0 and type(getgc) == "function" then
			pcall(function()
				for _, fn in ipairs(getgc(false)) do
					if type(fn) == "function" and debug.info(fn, "n") == "get_ailment_slots" then
						table.insert(mysteryFns, fn)
						if #mysteryFns >= 6 then
							break
						end
					end
				end
			end)
		end
	end
	local petInfo = { pet_unique = pet.unique, unique = pet.unique, pet_id = pet.kind, is_pet = true, char = petModel(pet.unique),
		player = LocalPlayer, controller = LocalPlayer, entity_controller = LocalPlayer, index = 1 }
	local tries = #mysteryFns > 0 and mysteryFns or { false }
	for _, fn in ipairs(tries) do
		local options = {}
		for key, value in pairs(component) do
			options[key] = value
		end
		options.get_ailment_slots = fn or nil
		local okCall, result = pcall(client._get_ailment_slots, setmetatable({ options = options }, { __index = client }), petInfo)
		if okCall and type(result) == "table" then
			local cards = {}
			for i = 1, 4 do
				local value = result[i]
				if type(value) == "table" then
					value = value.kind or value.ailment_key or value.name or value.id
				end
				if value ~= nil and pool[tostring(value)] then
					table.insert(cards, tostring(value))
				end
			end
			if #cards >= 2 then
				return cards, pool
			end
		end
	end
	return nil, pool
end
GC.MYSTERY_ORDER = { "toilet", "dirty", "sleepy", "hungry", "thirsty", "pet_me", "play", "sick", "cat_cafe", "salon",
	"school", "pizza_party", "camping", "beach_party", "bored", "walk", "ride" }
local function mysteryNeed(pet)
	local gone = needGone(pet, "mystery")
	local cards, pool = mysteryCards(pet)
	local order = {}
	for _, kind in ipairs(GC.MYSTERY_ORDER) do
		if NEED_DO[kind] and (pool == nil or next(pool) == nil or pool[kind]) then
			table.insert(order, kind)
		end
	end
	task.wait(2)
	if cards then
		for _, kind in ipairs(order) do
			local slot = table.find(cards, kind)
			if slot then
				say("Picking card " .. slot .. ": " .. string.gsub(kind, "_", " "))
				for _ = 1, 2 do
					send("AilmentsAPI/ChooseMysteryAilment", pet.unique, "mystery", slot, kind)
					if waitUntil(gone, 5) then
						return true
					end
				end
				break
			end
		end
	end
	local deadline = os.clock() + 150
	while os.clock() < deadline do
		for _, kind in ipairs(order) do
			for slot = 1, 3 do
				if gone() then
					return true
				end
				send("AilmentsAPI/ChooseMysteryAilment", pet.unique, "mystery", slot, kind)
				if waitUntil(gone, 2.5) then
					return true
				end
				if os.clock() > deadline then
					break
				end
			end
		end
	end
	return gone(), "no mystery card was taken"
end
local function walkAround(seconds, done, tick)
	local char = character()
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) then
		return false
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
	local points = { Vector3.new(start.X + (fx - rx) * 30, start.Y, start.Z + (fz - rz) * 30),
		Vector3.new(start.X + (fx + rx) * 30, start.Y, start.Z + (fz + rz) * 30), start }
	local elapsed, index = 0, 0
	while elapsed < seconds and running do
		index = index % #points + 1
		local target = points[index]
		local legTime, still, last = 0, 0, root.Position
		while legTime < 5 and elapsed < seconds do
			humanoid:MoveTo(target)
			task.wait(0.5)
			legTime += 0.5
			elapsed += 0.5
			if tick then
				tick(start)
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
				if still >= 2.5 then
					break
				end
			else
				still = 0
			end
			last = p
		end
	end
	return done()
end
local function movingNeed(pet, kind)
	standUp()
	if not isAt("MainMap") then
		local ok, why = goTo("MainMap")
		if not ok then
			return false, why
		end
		task.wait(2)
	end
	firstPet()
	local stroller
	if kind == "walk" then
		send("ToolAPI/Unequip", pet.unique, nil)
		waitUntil(function() return not isEquipped(pet.unique) end, 4)
		task.wait(1)
		send("ToolAPI/Equip", pet.unique, { equip_as_last = true })
		waitEquipped(pet.unique)
	else
		stroller = firstOf("strollers", { "stroller-default" }) or itemsOf("strollers", nil)[1]
		if not stroller then
			return false, "no stroller in your backpack"
		end
		local model = ensureModel(pet)
		local wrapper = petWrapper(pet.unique)
		if not (model and wrapper) then
			return false, "pet model not found"
		end
		local sit = table.clone(wrapper)
		sit.char, sit.controller, sit.entity_controller, sit.player = model, LocalPlayer, LocalPlayer, LocalPlayer
		send("ToolAPI/Equip", stroller.unique, { chars_to_sit = { sit } })
		task.wait(1)
	end
	local lastUse, ticks = 0, 0
	local done = needGone(pet, kind)
	walkAround(150, done, function(start)
		ticks += 1
		local char = character()
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if stroller and os.clock() - lastUse > 2 then
			lastUse = os.clock()
			sendNoWait("ToolAPI/ServerUseTool", stroller.unique, "START")
			sendNoWait("ToolAPI/ServerUseTool", stroller.unique, "END", nil)
		end
		if stroller and ticks % 4 == 1 then
			pcall(function()
				for _, holder in ipairs(char:GetChildren()) do
					if holder:IsA("Tool") or holder:IsA("Model") then
						for _, part in ipairs(holder:GetDescendants()) do
							if part:IsA("BasePart") then
								part.CanCollide = false
							end
						end
					end
				end
			end)
		end
		if root and (root.Position - start).Magnitude > 400 then
			pcall(function()
				root.AssemblyLinearVelocity = Vector3.zero
				char:PivotTo(CFrame.new(start + Vector3.new(0, 3, 0)))
			end)
		end
	end)
	if stroller then
		send("AdoptAPI/UnequipStroller")
		send("ToolAPI/Unequip", stroller.unique, nil)
	end
	return done(), kind .. " did not finish"
end
local function doPetMe(pet, model)
	send("AdoptAPI/FocusPet", model)
	task.wait(1)
	send("PetAPI/ReplicateActivePerformances", model, { FocusPet = true, Petting = true })
	task.wait(2)
	send("PetAPI/ReplicateActivePerformances", model, { FocusPet = true, PettingHappy = true })
	task.wait(1)
	send("PetAPI/ReplicateActivePerformances", model, { FocusPet = true })
	send("PetAPI/PetPetted", pet.unique, LocalPlayer)
	send("AilmentsAPI/ProgressPetMeAilment", pet.unique)
	task.wait(1)
	send("AdoptAPI/UnfocusPet", model)
end
local function petMeNeed(pet)
	local model = ensureModel(pet)
	if not model then
		return false, "pet model not found"
	end
	doPetMe(pet, model)
	local ok = waitUntil(needGone(pet, "pet_me"), 6)
	return ok, (not ok) and "still wants pets" or nil
end
NEED_DO = { pet_me = petMeNeed, hungry = feedNeed, thirsty = feedNeed, play = playNeed, mystery = mysteryNeed,
	walk = movingNeed, ride = movingNeed }
for kind in pairs(GC.NEED_PLACE) do
	NEED_DO[kind] = locationNeed
end
for kind in pairs(GC.NEED_FURNITURE) do
	NEED_DO[kind] = furnitureNeed
end
GC.NEED_ORDER = { "pet_me", "hungry", "thirsty", "play", "sleepy", "dirty", "toilet", "sick", "salon", "school", "cat_cafe",
	"pizza_party", "camping", "beach_party", "bored", "walk", "ride", "mystery" }
GC.KeepBucks = 0
GC.ReleaseMaxRarity = "uncommon"
GC.ReleasePetKind = ""
GC.DontRelease = { "MEGA NEONS", "NEONS" }
GC.QUEST_CLAIM = "adoptme_new.modules.Dailies.DailiesNetService:9"
GC.QUEST_BOARD = "adoptme_new.modules.Dailies.DailiesNetService:15"
local function vanillaTab()
	local dailies = getKey("dailies_manager")
	local tabs = type(dailies) == "table" and type(dailies.serialized_tabs) == "table" and dailies.serialized_tabs
	local tab = tabs and tabs.vanilla
	return type(tab) == "table" and tab or nil
end
local function dailySignature()
	local tab = vanillaTab()
	if not tab then
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
local function finishedDaily()
	local tab = vanillaTab()
	for _, daily in pairs(tab and type(tab.active_dailies) == "table" and tab.active_dailies or {}) do
		local state = type(daily) == "table" and type(daily.state) == "table" and daily.state or {}
		local need, done = tonumber(state.steps_to_complete), tonumber(state.steps_completed)
		if need and done and done >= need then
			return true
		end
	end
	return false
end
local function boardRewardReady()
	local tab = vanillaTab()
	return tab ~= nil and tab.reward_claimed == false and (tonumber(tab.total_dailies_completed_today) or 0) >= 3
end
local function claimDaily()
	local before = dailySignature()
	say("Claiming a finished daily task")
	sendNet(GC.QUEST_CLAIM, "vanilla")
	if not waitUntil(function() return dailySignature() ~= before end, 6) then
		return false, "the claim changed nothing"
	end
end
local function isAgePotion(id)
	id = string.lower(id)
	return string.find(id, "potion", 1, true) ~= nil and (string.find(id, "^age_potion") ~= nil
		or string.find(id, "_age_potion", 1, true) ~= nil or string.find(id, "age_up", 1, true) ~= nil
		or string.find(id, "ageup", 1, true) ~= nil)
end
local function realPet()
	local pet = choosePet()
	return pet and not isEgg(pet.kind) and pet or nil
end
local function useAgePotion()
	local pet = realPet()
	local potion = itemsOf("food", isAgePotion)[1]
	if not (pet and potion) then
		return false, "no potion or no pet"
	end
	local before = petAge(pet.unique) or 0
	firstPet()
	say("Giving your " .. prettyKind(pet.kind) .. " an age potion")
	return giveItem(pet, potion, function()
		return not hasUnique("food", potion.unique) or (petAge(pet.unique) or 0) > before
	end)
end
GC.EGG_PRICE = 350
GC.TREE_PRICE = 1450
local function buyEgg()
	local ok, why = goTo("Nursery")
	if not ok then
		return false, why
	end
	local before = #itemsOf("pets", nil)
	say("Buying a Cracked Egg (" .. GC.EGG_PRICE .. " Bucks)")
	send("ShopAPI/BuyItem", "pets", "cracked_egg", { buy_count = 1 })
	if not waitUntil(function() return #itemsOf("pets", nil) > before end, 8) then
		return false, "the egg did not arrive"
	end
end
local function buyMoneyTree()
	say("Planting a Money Tree (" .. GC.TREE_PRICE .. " Bucks)")
	local key, why = placeFurniture("moneytree")
	if not key then
		return false, why
	end
end
local goalKindRef
local dontRelease = { kinds = {} }
for _, entry in ipairs(type(GC.DontRelease) == "table" and GC.DontRelease or {}) do
	local key = string.upper((string.gsub(tostring(entry), "^%s*(.-)%s*$", "%1")))
	if key == "MEGA NEONS" or key == "MEGA NEON" or key == "MEGAS" then
		dontRelease.mega = true
	elseif key == "NEONS" or key == "NEON" then
		dontRelease.neon = true
	elseif key ~= "" then
		dontRelease.kinds[string.lower(key)] = true
	end
end
local function keptWhy(pet, maxRank)
	if pet.egg then
		return "an egg"
	end
	if pet.mega and dontRelease.mega then
		return "a mega neon"
	end
	if pet.neon and dontRelease.neon then
		return "a neon"
	end
	if dontRelease.kinds[string.lower(pet.kind)] then
		return "on your Don't release list"
	end
	if pet.rarity > maxRank then
		return "rarer than " .. tostring(GC.ReleaseMaxRarity)
	end
	return nil
end
local function releaseCandidate()
	local maxRank = GC.RARITY[string.lower(tostring(GC.ReleaseMaxRarity or "uncommon"))] or 2
	local wanted = GC.ReleasePetKind ~= "" and GC.ReleasePetKind or nil
	local goalOpen = not isCompleted("get_four_full_grown_pets")
	for id in pairs(GC.NEON_GOALS) do
		goalOpen = goalOpen or not isCompleted(id)
	end
	local keepKind = not wanted and goalOpen and goalKindRef and goalKindRef() or nil
	for _, pet in ipairs(sparePets()) do
		if (not wanted or pet.kind == wanted) and pet.kind ~= keepKind and not keptWhy(pet, maxRank) then
			return pet
		end
	end
	if not wanted and isCompleted("pet_pen_age_up") then
		local inPen = penPets()
		local session = choosePet()
		for _, item in ipairs(itemsOf("pets", nil)) do
			local props = type(item.properties) == "table" and item.properties or {}
			local pet = { unique = item.unique, kind = item.id, egg = isEgg(item.id), rarity = rarityOf(item.id),
				neon = props.neon == true, mega = props.mega_neon == true, fromPen = true }
			if inPen[pet.unique] and not isTemporary(pet.kind) and not (session and session.unique == pet.unique)
				and pet.kind ~= keepKind and not keptWhy(pet, maxRank) then
				return pet
			end
		end
	end
	return nil
end
local function releasePet()
	local pet = releaseCandidate()
	if not pet then
		return false, "no spare pet (eggs cannot be released, your main pet stays)"
	end
	if pet.fromPen then
		local ok = goTo("housing")
		if ok then
			say("Taking your " .. prettyKind(pet.kind) .. " out of the Pet Pen")
			send("IdleProgressionAPI/RemovePet", pet.unique)
			waitUntil(function() return penPets()[pet.unique] == nil end, 6)
		end
	end
	local ok, why = goTo("Nursery")
	if not ok then
		return false, why
	end
	pet = releaseCandidate()
	if not pet then
		return false, "no spare pet left to release"
	end
	say("Releasing your " .. prettyKind(pet.kind) .. " (the least valuable one)")
	writeLine("DATA", "pet_recycler_tickets_2026 before release = " .. tostring(getKey("pet_recycler_tickets_2026")))
	send("HousingAPI/ActivateInteriorFurniture", "f-3", "UseBlock", { uniques = { [pet.unique] = true } }, character())
	task.delay(5, function()
		writeLine("DATA", "pet_recycler_tickets_2026 5 s after release = " .. tostring(getKey("pet_recycler_tickets_2026")))
	end)
end
local function penAdd(target, pick)
	local ok, why = goTo("housing")
	if not ok then
		return false, why
	end
	local _, count = penPets()
	for _, pet in ipairs(pick and pick() or sparePets(true)) do
		if count >= target then
			break
		end
		say("Putting your " .. prettyKind(pet.kind) .. " in the Pet Pen")
		send("IdleProgressionAPI/AddPet", pet.unique)
		if waitUntil(function() return penPets()[pet.unique] ~= nil end, 6) then
			count += 1
		end
	end
	if count < target then
		return false, "the Pet Pen has " .. count .. " of " .. target
	end
end
local function penHasRealPet()
	local inPen = penPets()
	for _, pet in ipairs(itemsOf("pets", nil)) do
		if inPen[pet.unique] and not isEgg(pet.id) then
			return true
		end
	end
	return false
end
local function realSpares()
	local list = {}
	for _, pet in ipairs(sparePets()) do
		if not pet.egg then
			table.insert(list, pet)
		end
	end
	return list
end
local lastPenClaim = -1000
local function penClaim()
	local _, count = penPets()
	if count == 0 then
		return
	end
	local since = os.clock() - lastPenClaim
	if since < 300 or (since < 900 and not isAt("housing")) then
		return
	end
	lastPenClaim = os.clock()
	if goTo("housing") then
		say("Claiming the Pet Pen progress")
		send("IdleProgressionAPI/CommitAllProgression", true)
	end
end
local function canAfford(price)
	return money() >= price + GC.KeepBucks
end
local function isReady(id)
	local m = manager()
	return m ~= nil and type(m.ready) == "table" and m.ready[id] == true and not isCompleted(id)
end
local function ageOf(pet)
	return type(pet.properties) == "table" and tonumber(pet.properties.age) or 1
end
local function goalKind()
	local copies, grown = {}, {}
	for _, pet in ipairs(itemsOf("pets", nil)) do
		if not isEgg(pet.id) and not isTemporary(pet.id) then
			copies[pet.id] = (copies[pet.id] or 0) + 1
			if ageOf(pet) >= 6 then
				grown[pet.id] = (grown[pet.id] or 0) + 1
			end
		end
	end
	local best
	for kind, count in pairs(copies) do
		local g, bg = grown[kind] or 0, best and (grown[best] or 0) or -1
		if not best or g > bg or (g == bg and count > copies[best]) or (g == bg and count == copies[best] and kind < best) then
			best = kind
		end
	end
	return best, best and copies[best] or 0, best and (grown[best] or 0) or 0
end
local function looseEgg()
	local inPen = penPets()
	for _, pet in ipairs(itemsOf("pets", isEgg)) do
		if not inPen[pet.unique] and not isTemporary(pet.id) then
			return pet
		end
	end
	return nil
end
local function kindOfUnique(unique)
	for _, pet in ipairs(itemsOf("pets", nil)) do
		if pet.unique == unique then
			return pet.id
		end
	end
	return nil
end
local function goalPenMove()
	local kind = goalKind()
	if not kind then
		return nil
	end
	local inPen, count = penPets()
	local session = choosePet()
	local copy
	for _, pet in ipairs(itemsOf("pets", { [kind] = true })) do
		if ageOf(pet) < 6 and not inPen[pet.unique] and not (session and session.unique == pet.unique) then
			copy = pet
			break
		end
	end
	if not copy then
		return nil
	end
	if count < 4 then
		return { add = copy, kind = kind }
	end
	for unique in pairs(inPen) do
		if kindOfUnique(unique) ~= kind then
			return { add = copy, remove = unique, kind = kind }
		end
	end
	return nil
end
goalKindRef = goalKind
local function workOnSameKind()
	local move = goalPenMove()
	if move then
		local ok, why = goTo("housing")
		if not ok then
			return false, why
		end
		if move.remove then
			say("Making room in the Pet Pen for your " .. prettyKind(move.kind))
			send("IdleProgressionAPI/RemovePet", move.remove)
			waitUntil(function() return penPets()[move.remove] == nil end, 6)
		end
		say("Putting your " .. prettyKind(move.kind) .. " in the Pet Pen to grow")
		send("IdleProgressionAPI/AddPet", move.add.unique)
		waitUntil(function() return penPets()[move.add.unique] ~= nil end, 6)
		return nil
	end
	return buyEgg()
end
local function fusionGroup(mega)
	local inPen = penPets()
	local groups, best = {}, nil
	for _, pet in ipairs(itemsOf("pets", nil)) do
		local p = type(pet.properties) == "table" and pet.properties or {}
		local fits
		if mega then
			fits = p.neon == true and p.mega_neon ~= true
		else
			fits = p.neon ~= true and p.mega_neon ~= true
		end
		if fits and tonumber(p.age) == 6 and not inPen[pet.unique] and not isEgg(pet.id) and not isTemporary(pet.id) then
			groups[pet.id] = groups[pet.id] or {}
			table.insert(groups[pet.id], pet.unique)
		end
	end
	for kind, list in pairs(groups) do
		if #list >= 4 and (not best or #list > #groups[best] or (#list == #groups[best] and kind < best)) then
			best = kind
		end
	end
	if not best then
		return nil
	end
	local list = groups[best]
	table.sort(list)
	return best, { list[1], list[2], list[3], list[4] }
end
local function fuse(mega)
	local kind, uniques = fusionGroup(mega)
	if not kind then
		return false, "no 4 full grown " .. (mega and "neon " or "") .. "pets of one kind"
	end
	say("Making a " .. (mega and "mega neon " or "neon ") .. prettyKind(kind) .. " from 4")
	for _, unique in ipairs(uniques) do
		send("ToolAPI/Equip", unique, { equip_as_last = false, use_sound_delay = false })
		task.wait(0.12)
		send("ToolAPI/Unequip", unique, nil)
		task.wait(0.08)
	end
	task.wait(0.15)
	send("PetAPI/DoNeonFusion", { uniques[1], uniques[2], uniques[3], uniques[4] })
	local fused = waitUntil(function()
		local gone = 0
		for _, unique in ipairs(uniques) do
			if not hasUnique("pets", unique) then
				gone += 1
			end
		end
		return gone >= 3
	end, 15)
	if not fused then
		return false, "the fusion was not seen in the backpack"
	end
	if sessionPet and not hasUnique("pets", sessionPet.unique) then
		sessionPet = nil
	end
	say((mega and "Mega neon " or "Neon ") .. prettyKind(kind) .. " made!", "ok")
end
local function neonPlan(mega, need, line)
	return { kind = "slow", grind = true, maxRuns = 60, line = line, canRun = function()
		if fusionGroup(mega) then
			return true
		end
		if goalPenMove() then
			return true
		end
		local _, copies = goalKind()
		return copies < need and not looseEgg() and canAfford(GC.EGG_PRICE)
	end, run = function()
		if fusionGroup(mega) then
			return fuse(mega)
		end
		return workOnSameKind()
	end }
end
GC.AutoRelease = true
GC.VerifySeconds = 12
GC.AGE_TARGET = { age_a_pet_to_junior = 2, age_a_pet_to_pre_teen = 3, age_a_pet_to_teen = 4, age_a_pet_to_post_teen = 5,
	age_a_pet_to_full = 6 }
GC.AGE_NAMES = { "Newborn", "Junior", "Pre-Teen", "Teen", "Post-Teen", "Full Grown" }
local AUTO = {
	visit_the_accessory_shop = { kind = "visit", place = "HatShop" },
	visit_the_dealership = { kind = "visit", place = "AutoShop" },
	visit_the_toy_shop = { kind = "visit", place = "ToyShop" },
	visit_the_hospital = { kind = "visit", place = "Hospital" },
	visit_the_pizza_place = { kind = "visit", place = "PizzaShop" },
	visit_the_salon = { kind = "visit", place = "Salon" },
	visit_the_nursery = { kind = "visit", place = "Nursery" },
	visit_the_school = { kind = "visit", place = "School" },
	buy_a_gift = { kind = "buy", place = "MainMap", category = "gifts", item = "smallgift", price = 70 },
	buy_a_sticker_pack = { kind = "buy", place = "ToyShop", category = "gifts", item = "stickers_2024_standard_pack", price = 250 },
	buy_a_vehicle = { kind = "buy", place = "AutoShop", category = "transport", item = "vehicle_shop_2022_bicycle" },
	buy_a_pet_accessory = { kind = "buy", place = "HatShop", category = "pet_accessories", item = "red_collar", price = 100 },
	equip_a_vehicle = { kind = "equip", place = "MainMap", category = "transport" },
	obtain_a_trade_license = { kind = "act", retries = 2, run = getLicense },
	get_a_trade_license = { kind = "act", retries = 2, run = getLicense },
	equip_an_egg = { kind = "act", run = function()
		for _, pet in ipairs(equippedPets()) do
			if isEgg(pet.kind or pet.id) then
				send("ToolAPI/Unequip", pet.unique, nil)
				task.wait(0.5)
				send("ToolAPI/Equip", pet.unique, { equip_as_last = false, use_sound_delay = true })
				return nil
			end
		end
		for _, pet in ipairs(itemsOf("pets", isEgg)) do
			send("ToolAPI/Equip", pet.unique, { equip_as_last = false, use_sound_delay = true })
			return nil
		end
		return false, "no egg in the backpack"
	end },
	teach_a_trick = { kind = "trick", place = "School", needsRealPet = true },
	buy_a_new_texture = { kind = "act", place = "housing", remoteFirst = true, run = function()
		send("HousingAPI/BuyTexture", "Room1", "walls", "heart")
	end },
	buy_furniture = { kind = "act", place = "housing", run = function()
		local key, why = placeFurniture("minifridge")
		if not key then
			return false, why
		end
	end },
	place_a_furniture = { kind = "act", place = "housing", run = function()
		local key, why = placeFurniture("cheap_pet_bathtub")
		if not key then
			return false, why
		end
	end },
	place_a_lure = { kind = "act", place = "housing", run = function()
		local key, why = placeFurniture("lures_2023_normal_lure")
		if not key then
			return false, why
		end
	end },
	sell_furniture = { kind = "act", place = "housing", run = function()
		local key, why = placeFurniture("expandable_houses_2023_friendly_bed")
		if not key then
			return false, why
		end
		send("HousingAPI/SellFurniture", true, { key }, "sell")
	end },
	store_furniture = { kind = "act", place = "housing", run = function()
		local key, why = placeFurniture("expandable_houses_2023_friendly_bed")
		if not key then
			return false, why
		end
		send("HousingAPI/SellFurniture", true, { key }, "store")
	end },
	customize_the_weather = { kind = "act", place = "housing", run = function()
		send("AmbianceAPI/UpdateAmbiance", { custom_props = {
			SunRaysEffect = { Intensity = 0.12 },
			ColorCorrectionEffect = { TintColor = Color3.new(1, 1, 1), Saturation = 0.14, Contrast = 0.03 },
			Lighting = { ClockTime = 13, Ambient = Color3.new(0.741176, 0.741176, 0.741176), OutdoorAmbient = Color3.new(0, 0, 0),
				ColorShift_Top = Color3.new(1, 1, 1), ExposureCompensation = 0 },
			Custom = { CherryBlossoms = false, Rain = false, Leaves = false, Snow = false },
			Atmosphere = { Density = 0, Glare = 0, Haze = 2, Color = Color3.new(1, 1, 1) },
		}, time = "DAY", base_kind = "day", kind = "day", preset_override = "House Interior Daytime" })
	end },
	color_your_house = { kind = "act", place = "housing", run = function()
		say("Painting your house")
		send("HousingAPI/ColorHouse", 2, 0.0666667, 0.0666667, 0.0666667)
		if waitUntil(function() return isCompleted("color_your_house") end, 5) then
			return nil
		end
		send("HousingAPI/ColorHouse", 3, 1, 1, 0)
	end },
	bait_a_lure = { kind = "act", place = "housing", run = function()
		local interior = getKey("house_interior")
		local lure
		for key, piece in pairs(type(interior) == "table" and type(interior.furniture) == "table" and interior.furniture or {}) do
			if type(piece) == "table" and piece.id == "lures_2023_normal_lure" then
				lure = tostring(key)
			end
		end
		if not lure then
			local key, why = placeFurniture("lures_2023_normal_lure")
			if not key then
				return false, why
			end
			lure = key
		end
		local bait
		local inventory = getKey("inventory")
		for category in pairs(type(inventory) == "table" and inventory or {}) do
			bait = bait or itemsOf(category, function(id) return string.find(id, "bait", 1, true) ~= nil end)[1]
		end
		if not bait then
			return false, "no bait in your backpack"
		end
		send("HousingAPI/ActivateFurniture", LocalPlayer, lure, "UseBlock", { bait_unique = bait.unique }, character())
	end },
	buy_a_new_house = { kind = "act", price = 250, run = function()
		send("HousingAPI/SetRecentlyViewedHouseTemplate", "micro_2023")
		send("HousingAPI/BuyHouseWithAddons", "micro_2023", {}, 0.768627, 0.156863, 0.109804)
	end },
	dress_up_a_pet = { kind = "act", needsRealPet = true, run = function()
		local pet = firstPet()
		local accessory = firstItem("pet_accessories", "red_collar")
		if not (pet and accessory) then
			return false, "needs an equipped pet and a red_collar"
		end
		send("AvatarAPI/PutOn", "pet", "collar", accessory, pet.unique)
	end },
	save_a_pet_outfit = { kind = "act", needsRealPet = true, run = function()
		local pet = firstPet()
		if not pet then
			return false, "no equipped pet"
		end
		send("AvatarAPI/SaveOutfit", "pet", "Unnamed", pet.unique)
	end },
	name_a_pet = { kind = "act", needsRealPet = true, run = function()
		local pet = firstPet()
		if not pet then
			return false, "no equipped pet"
		end
		send("SettingsAPI/SetPetRoleplayName", pet.unique, "Buddy")
	end },
	paint_a_pet = { kind = "act", place = "Salon", remoteFirst = true, run = function()
		local pet = firstPet()
		local model = pet and petModel(pet.unique)
		if not model then
			return false, "pet model not found"
		end
		send("AdoptAPI/FocusPet", model)
		send("PetPaintAPI/PaintingPet", model)
		send("PetPaintAPI/PaintPet", model, { { index = 5, paint = "driftwood_taupe" } })
	end },
	work_a_job = { kind = "act", place = "PizzaShop", run = function()
		send("PetAPI/ExitFurnitureUseStates")
		send("HousingAPI/ActivateInteriorFurniture", "f-2", "UseBlock", true, character())
	end },
	pet_pen_add = { kind = "slow", line = "Pet Pen time" },
	pet_pen_full = { kind = "slow", grind = true, line = "Filling the Pet Pen", canRun = function()
		local _, count = penPets()
		return count + #sparePets(true) >= 4 or canAfford(GC.EGG_PRICE)
	end, run = function()
		local _, count = penPets()
		if count + #sparePets(true) < 4 then
			return buyEgg()
		end
		return penAdd(4)
	end },
	pet_pen_age_up = { kind = "slow", line = "Putting a pet in the Pet Pen to grow", goal = "Waiting for a pet to grow in the Pet Pen",
		canRun = function()
			return not penHasRealPet() and realSpares()[1] ~= nil
		end, run = function()
			local _, count = penPets()
			return penAdd(count + 1, realSpares)
		end, grind = function()
			local _, count = penPets()
			return count > 0
		end },
	complete_a_need = { kind = "slow", grind = true, goal = "Taking care of your pet" },
	complete_a_ride_need = { kind = "slow", grind = true, goal = "Waiting for a ride need" },
	hatch_an_egg = { kind = "slow", goal = "Hatching your egg", grind = function()
		local pet = choosePet()
		return (pet ~= nil and isEgg(pet.kind)) or looseEgg() ~= nil
	end },
	complete_a_task = { kind = "slow", grind = true, line = "Claiming a daily task", goal = "Working on a daily task",
		canRun = finishedDaily, run = claimDaily },
	buy_an_egg = { kind = "slow", grind = true, price = GC.EGG_PRICE, line = "Off to the Nursery",
		canRun = function() return canAfford(GC.EGG_PRICE) end, run = buyEgg },
	get_four_pets = { kind = "slow", grind = true, price = GC.EGG_PRICE, line = "Getting another pet",
		canRun = function() return canAfford(GC.EGG_PRICE) end, run = buyEgg },
	get_four_full_grown_pets = { kind = "slow", grind = true, maxRuns = 40, line = "Working on 4 of the same pet",
		canRun = function()
			if goalPenMove() then
				return true
			end
			local kind, copies = goalKind()
			return (not kind or copies < 4) and not looseEgg() and canAfford(GC.EGG_PRICE)
		end, run = workOnSameKind },
	make_a_neon_pet = neonPlan(false, 4, "Working on a neon pet"),
	obtain_a_neon_pet = neonPlan(false, 4, "Working on a neon pet"),
	get_four_full_grown_neon_pets = neonPlan(false, 16, "Working on 4 full grown neons"),
	make_a_mega_neon_pet = neonPlan(true, 16, "Working on a mega neon"),
	collect_kinds_of_pets = { kind = "slow", grind = true, maxRuns = 40, line = "Getting a new pet for the Journal",
		canRun = function() return not looseEgg() and canAfford(GC.EGG_PRICE) end, run = buyEgg },
	buy_a_money_tree = { kind = "slow", grind = true, price = GC.TREE_PRICE, line = "Off to plant a Money Tree",
		canRun = function() return canAfford(GC.TREE_PRICE) end, run = buyMoneyTree },
}
for id, target in pairs(GC.AGE_TARGET) do
	AUTO[id] = { kind = "slow", grind = true, age = target, line = "Age potion time",
		canRun = function()
			local pet = realPet()
			return pet ~= nil and (petAge(pet.unique) or 99) < target and itemsOf("food", isAgePotion)[1] ~= nil
		end, run = useAgePotion }
end
local eggBoughtForPen = false
local function anySpare()
	return sparePets()[1] ~= nil
end
AUTO.pet_pen_add.canRun = function()
	return anySpare() or (not eggBoughtForPen and canAfford(GC.EGG_PRICE))
end
AUTO.pet_pen_add.grind = function()
	return not anySpare() and not eggBoughtForPen
end
AUTO.pet_pen_add.run = function()
	if not anySpare() then
		if eggBoughtForPen then
			return false, "no spare pet"
		end
		eggBoughtForPen = true
		local result, why = buyEgg()
		if result == false then
			return false, why
		end
	end
	local _, count = penPets()
	return penAdd(count + 1)
end
if GC.AutoRelease or GC.ReleasePetKind ~= "" then
	AUTO.release_a_pet = { kind = "slow", line = "Off to the Pet Releaser",
		canRun = function() return releaseCandidate() ~= nil end, run = releasePet }
end
local ASSIST_PLACE = {
	paint_a_pet = "Salon", work_a_job = "PizzaShop", buy_a_pet_accessory = "HatShop", release_a_pet = "Nursery",
	buy_a_new_texture = "housing", buy_furniture = "housing", sell_furniture = "housing", store_furniture = "housing",
	color_your_house = "housing", customize_the_weather = "housing", pet_pen_add = "housing", buy_an_egg = "Nursery",
	buy_a_money_tree = "housing",
}
local function slowGoal(id)
	local plan = AUTO[id]
	if plan.price then
		return string.format("Saving up Bucks: %d / %d", money(), plan.price + GC.KeepBucks)
	end
	if plan.age then
		local pet = realPet()
		local age = pet and petAge(pet.unique)
		return "Aging your pet: " .. (GC.AGE_NAMES[age or 0] or "egg") .. " to " .. GC.AGE_NAMES[plan.age]
	end
	if id == "get_four_full_grown_pets" then
		local kind, copies, grown = goalKind()
		if not kind then
			return "4 of the same: hatching eggs for pets"
		end
		return string.format("4 of the same: %s %d/4 full grown (%d copies)", prettyKind(kind), grown, copies)
	end
	if id == "collect_kinds_of_pets" then
		return "10 kinds: hatching eggs for new kinds"
	end
	if GC.NEON_GOALS[id] then
		local kind, copies, grown = goalKind()
		return string.format("%s: %s, %d full grown of %d copies", titleOf(id), kind and prettyKind(kind) or "hatching eggs",
			grown or 0, copies or 0)
	end
	return plan.goal or titleOf(id)
end
local function act(id, plan)
	if plan.kind == "buy" then
		local bucks = tonumber(getKey("money")) or 0
		if bucks < (plan.price or 1) + GC.KeepBucks then
			return false, "not enough Bucks (" .. bucks .. ")"
		end
		say("Buying " .. (GC.ITEM_NAMES[plan.item] or plan.item))
		send("ShopAPI/BuyItem", plan.category, plan.item, { buy_count = 1 })
	elseif plan.kind == "equip" then
		local unique = firstItem(plan.category)
		if not unique then
			return false, "no " .. plan.category .. " item"
		end
		say("Taking the bike out for a test ride")
		send("ToolAPI/Equip", unique, {})
		local done = waitUntil(function() return isCompleted(id) end, GC.VerifySeconds)
		send("ToolAPI/Unequip", unique, nil)
		return done, (not done) and "not completed" or nil
	elseif plan.kind == "trick" then
		firstPet()
		for _, pet in ipairs(equippedPets()) do
			if not isCompleted(id) and not isEgg(pet.kind or pet.id) then
				say("Teaching your pet a new trick")
				send("PetAPI/UpdatePetTrickLevel", pet.unique)
				waitUntil(function() return isCompleted(id) end, 5)
			end
		end
	elseif plan.kind == "client" then
		say("Faking " .. titleOf(id))
		send("AchievementsAPI/CompleteAchievement", id)
	elseif plan.kind == "act" then
		say(GC.ACT_LINES[id] or ("Doing " .. titleOf(id)))
		local result, why = plan.run()
		if result == false then
			return false, why
		end
	end
	return nil
end
local function doAuto(id, plan)
	if plan.kind == "visit" then
		if isAt(plan.place) then
			local ok, why = goTo("MainMap")
			if not ok then
				return false, why
			end
		end
		local ok, why = goTo(plan.place)
		if not ok then
			return false, why
		end
		if waitUntil(function() return isCompleted(id) end, GC.VerifySeconds) then
			return true
		end
		return false, "not completed"
	end
	if plan.remoteFirst or not plan.place then
		local result, why = act(id, plan)
		if result ~= nil then
			if result or not plan.place then
				return result, why
			end
		elseif waitUntil(function() return isCompleted(id) end, 6) then
			if plan.remoteFirst then
				say("Done from here")
			end
			return true
		elseif not plan.place then
			return false, why or "not completed"
		end
		say("Didn't count from here, walking over")
	end
	local ok, why = goTo(plan.place)
	if not ok then
		return false, why
	end
	local result, reason = act(id, plan)
	if result ~= nil then
		return result, reason
	end
	if waitUntil(function() return isCompleted(id) end, GC.VerifySeconds) then
		return true
	end
	return false, reason or ("not completed (place " .. tostring(currentPlace()) .. ")")
end
local function doSlow(id, plan)
	say(plan.line or ("Doing " .. titleOf(id)))
	local result, why = plan.run()
	if result == false then
		return false, why
	end
	if waitUntil(function() return isCompleted(id) end, plan.verify or 8) then
		return true
	end
	return nil, "progress"
end
local function runWithTimeout(limit, fn, ...)
	local done, ok, why = false, false, nil
	local args = table.pack(...)
	local thread = task.spawn(function()
		local okCall, result, reason = pcall(fn, table.unpack(args, 1, args.n))
		if okCall then
			ok, why = result, reason
		else
			ok, why = false, "script error: " .. tostring(result)
		end
		done = true
	end)
	waitUntil(function() return done or not running end, limit)
	if not done then
		pcall(task.cancel, thread)
		if not running then
			return false, "stopped"
		end
		return false, "STUCK (cancelled after " .. limit .. " s)"
	end
	return ok, why
end
GC.RecordCalls = true
GC.CallWindowSeconds = 20
local recent, queue = {}, {}
local assistCalls = {}
local recording = false
do
	if GC.RecordCalls and type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" then
		local wrap = type(newcclosure) == "function" and newcclosure or function(f) return f end
		local isExecutor = type(checkcaller) == "function" and checkcaller or function() return false end
		local old
		local ok, err = pcall(function()
			old = hookmetamethod(game, "__namecall", wrap(function(self, ...)
				if recording and GC.RecordCalls and not isExecutor() then
					local method = getnamecallmethod()
					if method == "FireServer" or method == "InvokeServer" then
						table.insert(queue, { at = os.clock(), remote = self, method = method, args = table.pack(...) })
					end
				end
				return old(self, ...)
			end))
		end)
		if not ok then
			log("WARN", "remote hook failed: " .. tostring(err))
		end
	else
		log("WARN", "hookmetamethod not available: assist logs data only")
	end
end
GC.NOISE = { ["PetAPI/ReplicateActivePerformances"] = true, ["PetAPI/ReplicatePerformanceModifiers"] = true,
	["PetAPI/ReplicateActiveReactions"] = true, ["DownloadsAPI/Download"] = true, received_remote_event = true,
	setMemory = true, setMisc = true }
local function flushCalls()
	local batch = queue
	queue = {}
	for _, call in ipairs(batch) do
		local okName, name = pcall(function() return call.remote.Name end)
		name = okName and name or "?"
		if not GC.NOISE[name] and not string.find(name, "LogCollector", 1, true) then
			local parts = {}
			for i = 1, call.args.n do
				parts[i] = serialize(call.args[i], 0)
			end
			local text = call.method .. " " .. name .. "(" .. table.concat(parts, ", ") .. ")"
			log("CALL", text)
			table.insert(recent, { at = call.at, text = text })
			table.insert(assistCalls, text)
			if #assistCalls > 400 then
				table.remove(assistCalls, 1)
			end
		end
	end
	local cutoff = os.clock() - GC.CallWindowSeconds
	while recent[1] and recent[1].at < cutoff do
		table.remove(recent, 1)
	end
end
GC.DevLogs = true
GC.DevLogsUrl = "https://adoptmelogs.04demirali123.workers.dev/log"
local devLogsSent = 0
local devSession = string.format("%x%x", os.time() % 0xFFFFFF, math.random(0, 0xFFFF))
local function httpRequest()
	local fn = (type(syn) == "table" and syn.request) or (type(http) == "table" and http.request) or http_request or request
	return type(fn) == "function" and fn or nil
end
local function scrubNames(text)
	local ok, players = pcall(function() return Players:GetPlayers() end)
	for _, player in ipairs(ok and players or {}) do
		if type(player.Name) == "string" and #player.Name >= 3 then
			text = string.gsub(text, (string.gsub(player.Name, "%p", "%%%0")), player == LocalPlayer and "<me>" or "<player>")
		end
	end
	local userId = tonumber(LocalPlayer.UserId)
	if userId and userId > 0 then
		text = string.gsub(text, tostring(userId), "<myId>")
	end
	return text
end
local function anonId()
	local h = 5381
	for _, byte in ipairs({ string.byte(tostring(LocalPlayer.UserId), 1, -1) }) do
		h = (h * 33 + byte) % 4294967296
	end
	return string.format("aa_%08x", h)
end
local function petSummary()
	local counts = {}
	for _, pet in ipairs(itemsOf("pets", nil)) do
		local p = type(pet.properties) == "table" and pet.properties or {}
		local key = pet.id .. " age " .. tostring(p.age or "?") .. (p.mega_neon and " mega" or (p.neon and " neon" or ""))
		counts[key] = (counts[key] or 0) + 1
	end
	local lines = {}
	for key, count in pairs(counts) do
		table.insert(lines, count .. "x " .. key)
	end
	table.sort(lines)
	return lines
end
local function readyNow()
	local m = manager()
	local list = {}
	for readyId, isReady in pairs(m and type(m.ready) == "table" and m.ready or {}) do
		if isReady then
			table.insert(list, readyId)
		end
	end
	table.sort(list)
	return list
end
local devLogsDone = {}
local function sendDevLog(id, title, seconds, calls, outcome)
	outcome = outcome or "completed"
	local request = httpRequest()
	local key = id .. "|" .. string.sub(outcome, 1, 40)
	if devLogsDone[key] then
		return
	end
	devLogsDone[key] = true
	if not GC.DevLogs or not request or devLogsSent >= 40 or type(GC.DevLogsUrl) ~= "string"
		or not string.match(GC.DevLogsUrl, "^https://[%w%-]+%.[%w%-]+%.workers%.dev/[%w%-/]*$") then
		return
	end
	devLogsSent += 1
	local m = manager()
	local done = {}
	for doneId in pairs(m and type(m.completed) == "table" and m.completed or {}) do
		table.insert(done, doneId)
	end
	table.sort(done)
	local text = table.concat({
		id .. " (" .. tostring(title) .. "): " .. outcome .. " after " .. math.floor(seconds) .. " s",
		"place: " .. tostring(currentPlace()) .. " | bucks: " .. money()
			.. " | tickets: " .. tostring(getKey("pet_recycler_tickets_2026")),
		"game calls during the task (" .. #calls .. "):",
		"  " .. table.concat(calls, "\n  "),
		"pets:",
		"  " .. table.concat(petSummary(), "\n  "),
		"completed: " .. table.concat(done, ", "),
		"ready: " .. table.concat(readyNow(), ", "),
		"last log lines:",
		"  " .. table.concat(logRing, "\n  "),
	}, "\n")
	local okExecutor, executor = pcall(function()
		return identifyexecutor and table.concat({ identifyexecutor() }, " ") or nil
	end)
	local payload = {
		v = "AutoAchievements",
		user = anonId(),
		userId = 0,
		session = devSession,
		tag = "autoach",
		report = true,
		lines = { os.date("%H:%M:%S") .. (outcome == "completed" and " [INFO] " or " [WARN] ") .. "Guide: " .. id .. " "
			.. outcome .. " (" .. math.floor(seconds) .. " s, " .. #calls .. " calls, executor "
			.. tostring(okExecutor and executor or "?") .. ")" },
		files = { { name = (outcome == "completed" and "yourturn_" or "problem_") .. id .. ".txt", text = scrubNames(string.sub(text, 1, 60000)) } },
	}
	local okBody, body = pcall(function()
		return game:GetService("HttpService"):JSONEncode(payload)
	end)
	if not okBody then
		writeLine("DEVLOG", "not encoded: " .. tostring(body))
		return
	end
	task.spawn(function()
		local ok, response = pcall(request, { Url = GC.DevLogsUrl, Method = "POST",
			Headers = { ["Content-Type"] = "application/json" }, Body = body })
		writeLine("DEVLOG", id .. " -> " .. (ok and type(response) == "table" and tostring(response.StatusCode) or ("failed: " .. tostring(response))))
	end)
end
GC.NeedTimeout = 240
local failedNeed, failCount, needsDone = {}, {}, 0
local lastDailyClaim = -1000
local function needReady(kind, needs)
	return needs[kind] ~= nil and NEED_DO[kind] ~= nil and os.clock() - (failedNeed[kind] or -1000) > 90
end
local function careStep()
	local pet = firstPet()
	if not pet then
		task.wait(2)
		return false, "no pet"
	end
	local pick
	local needs = needsOf(pet.unique)
	for _, kind in ipairs(GC.NEED_ORDER) do
		if needReady(kind, needs) then
			pick = kind
			break
		end
	end
	if not pick then
		setNow("Waiting for your " .. prettyKind(pet.kind) .. "'s next need")
		waitUntil(function()
			local now = needsOf(pet.unique)
			for _, kind in ipairs(GC.NEED_ORDER) do
				if needReady(kind, now) then
					return true
				end
			end
			return false
		end, 8)
		return true
	end
	say(GC.NEED_LINES[pick] or ("Your pet wants: " .. pick))
	log("NEED", pick .. " on " .. tostring(pet.kind) .. " " .. pet.unique .. " at " .. tostring(currentPlace()) .. " bucks=" .. money())
	local ok, why = runWithTimeout(GC.NeedTimeout, NEED_DO[pick], pet, pick)
	flushCalls()
	log("NEED", pick .. " -> " .. (ok and "done" or ("failed: " .. tostring(why))))
	if ok then
		failCount[pick] = 0
		needsDone += 1
		say("Need done! (" .. needsDone .. " so far, " .. money() .. " Bucks)", "ok")
		return true
	end
	failCount[pick] = (failCount[pick] or 0) + 1
	if string.find(tostring(why), "in your backpack", 1, true) then
		failedNeed[pick] = math.huge
	elseif failCount[pick] >= 3 then
		failedNeed[pick] = os.clock() + 510
	else
		failedNeed[pick] = os.clock()
	end
	say("Couldn't finish that one: " .. tostring(why), "bad")
	pcall(sendDevLog, "need_" .. pick, pick .. " need", 0, {}, "script failed: " .. tostring(why))
	return false, why
end
local PET_TASKS = { "dress_up_a_pet", "save_a_pet_outfit", "name_a_pet", "paint_a_pet", "teach_a_trick" }
local function grindTarget(pending)
	local session = choosePet()
	local kind, copies = goalKind()
	local sameKind = pending.get_four_full_grown_pets
	for id in pairs(GC.NEON_GOALS) do
		sameKind = sameKind or pending[id]
	end
	if pending.first or pending.hatch_an_egg or pending.collect_kinds_of_pets or (sameKind and copies < 4) then
		if session and isEgg(session.kind) then
			return nil
		end
		local egg = looseEgg()
		if egg then
			return egg, "hatching an egg"
		end
	end
	local sessionAge = session and not isEgg(session.kind) and petAge(session.unique) or nil
	if sessionAge and sessionAge < 6 and (not sameKind or session.kind == kind) then
		return nil
	end
	local inPen = penPets()
	local best, bestAge, bestGoal
	for _, pet in ipairs(itemsOf("pets", nil)) do
		local isGoal = sameKind and pet.id == kind or false
		if not isEgg(pet.id) and not isTemporary(pet.id) and (isGoal or not inPen[pet.unique]) and ageOf(pet) < 6 then
			if not best or (isGoal and not bestGoal) or (isGoal == bestGoal and ageOf(pet) > bestAge) then
				best, bestAge, bestGoal = pet, ageOf(pet), isGoal
			end
		end
	end
	if best and not (session and session.unique == best.unique) then
		return best, bestGoal and ("growing your " .. prettyKind(kind) .. " for 4 of the same") or "it still grows"
	end
	return nil
end
local function switchPet(target, why)
	local old = sessionPet
	say("Switching to your " .. prettyKind(target.id) .. " (" .. why .. ")")
	log("PET", "switch " .. tostring(old and old.unique) .. " -> " .. target.unique .. " (" .. why .. ")")
	if old and isEquipped(old.unique) then
		send("ToolAPI/Unequip", old.unique, nil)
		waitUntil(function() return not isEquipped(old.unique) end, 4)
	end
	if penPets()[target.unique] and goTo("housing") then
		say("Taking your " .. prettyKind(target.id) .. " out of the Pet Pen to grow it")
		send("IdleProgressionAPI/RemovePet", target.unique)
		waitUntil(function() return penPets()[target.unique] == nil end, 6)
	end
	sessionPet = { unique = target.unique, kind = target.id }
	firstPet()
end
local function grindStep(waiting, firstPage)
	local pending = { first = firstPage == true }
	for _, id in ipairs(waiting) do
		pending[id] = true
	end
	local petTask = false
	for _, id in ipairs(PET_TASKS) do
		petTask = petTask or isReady(id)
	end
	if not petTask or pending.first then
		local ok, target, why = pcall(grindTarget, pending)
		if ok and target then
			switchPet(target, why)
		end
	end
	if os.clock() - lastDailyClaim > 60 then
		if finishedDaily() then
			lastDailyClaim = os.clock()
			claimDaily()
		elseif boardRewardReady() then
			lastDailyClaim = os.clock()
			say("Claiming the daily board reward")
			sendNet(GC.QUEST_BOARD, "vanilla")
		end
	end
	penClaim()
	careStep()
end
GC.Discord = "https://discord.gg/7rvgpgXrwd"
GC.Credit = "KiritoKun"
GC.AvatarUrl = "https://raw.githubusercontent.com/Amivictim/adoptmefarm/refs/heads/main/victimoffate_.png"
GC.AvatarUser = "victimoffate_"
local skipPressed = false
local onFinished = nil
local THEME = {
	bg = Color3.fromRGB(18, 18, 22), line = Color3.fromRGB(40, 40, 48), field = Color3.fromRGB(28, 28, 34),
	text = Color3.fromRGB(230, 230, 235), dim = Color3.fromRGB(130, 130, 145), accent = Color3.fromRGB(150, 120, 255),
	ok = Color3.fromRGB(90, 200, 120), bad = Color3.fromRGB(230, 90, 90),
}
local function guiParent()
	local ok, hui = pcall(function() return gethui and gethui() end)
	if ok and hui then
		return hui
	end
	local okCore, core = pcall(function() return game:GetService("CoreGui") end)
	if okCore and core then
		return core
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end
local function create(className, props, parent)
	local object = Instance.new(className)
	for key, value in pairs(props) do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function corner(parent, radius)
	create("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
end
local function makeDraggable(handle, target)
	local dragging, startInput, startPos
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, startInput, startPos = true, input.Position, target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - startInput
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end
local function text(parent, x, y, width, height, value, size, color, bold)
	return create("TextLabel", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1, Text = value or "", TextColor3 = color or THEME.text, TextSize = size or 12,
		Font = bold and Enum.Font.GothamMedium or Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd }, parent)
end
local function button(parent, x, y, width, value, color, onClick)
	local b = create("TextButton", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, 24),
		BackgroundColor3 = THEME.field, BorderSizePixel = 0, Text = value, TextColor3 = color or THEME.text,
		Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = true }, parent)
	corner(b, 5)
	create("UIStroke", { Color = THEME.line, Thickness = 1 }, b)
	b.MouseButton1Click:Connect(function()
		pcall(onClick)
	end)
	return b
end
local function avatarImage()
	if type(getcustomasset) == "function" and type(writefile) == "function" then
		local file = GC.LogFolder .. "/" .. GC.AvatarUser .. ".png"
		local ok, image = pcall(function()
			if not (type(isfile) == "function" and isfile(file)) then
				if type(isfolder) == "function" and not isfolder(GC.LogFolder) then
					makefolder(GC.LogFolder)
				end
				local data = game:HttpGet(GC.AvatarUrl)
				if type(data) ~= "string" or (string.sub(data, 1, 8) ~= "\137PNG\r\n\26\n" and string.sub(data, 1, 3) ~= "\255\216\255") then
					error("not a picture")
				end
				writefile(file, data)
			end
			return getcustomasset(file)
		end)
		if ok and type(image) == "string" and image ~= "" then
			return image
		end
	end
	local ok, image = pcall(function()
		local userId = Players:GetUserIdFromNameAsync(GC.AvatarUser)
		return (Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48))
	end)
	return ok and type(image) == "string" and image or ""
end
local function copyText(value)
	local copy = (type(setclipboard) == "function" and setclipboard) or (type(toclipboard) == "function" and toclipboard)
	return copy ~= nil and pcall(copy, value)
end
local function window(width, height, onClose)
	if not ui.screen then
		ui.screen = create("ScreenGui", { Name = "AutoAchievements", ResetOnSpawn = false, DisplayOrder = 999 }, guiParent())
	end
	local frame = create("Frame", { Size = UDim2.fromOffset(width, height), Position = UDim2.new(0, 16, 0.5, -height / 2),
		BackgroundColor3 = THEME.bg, BorderSizePixel = 0 }, ui.screen)
	corner(frame, 8)
	create("UIStroke", { Color = THEME.line, Thickness = 1 }, frame)
	local header = create("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 }, frame)
	makeDraggable(header, frame)
	local avatar = create("ImageLabel", { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = THEME.field, BorderSizePixel = 0, Image = "" }, header)
	corner(avatar, 9)
	task.spawn(function()
		local image = avatarImage()
		if avatar.Parent then
			avatar.Image = image
		end
	end)
	text(header, 32, 0, width - 64, 30, "Auto Achievements", 13, THEME.text, true)
	local close = create("TextButton", { Position = UDim2.fromOffset(width - 28, 3), Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1, Text = "×", TextColor3 = THEME.dim, Font = Enum.Font.GothamMedium, TextSize = 18 }, header)
	close.MouseButton1Click:Connect(function()
		frame:Destroy()
		if onClose then
			pcall(onClose)
		end
	end)
	create("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = THEME.line,
		BorderSizePixel = 0 }, frame)
	return frame
end
local function footer(frame, width, y)
	text(frame, 10, y, 110, 16, "by " .. GC.Credit, 11, THEME.dim)
	local invite = create("TextButton", { Position = UDim2.fromOffset(width - 130, y), Size = UDim2.fromOffset(120, 16),
		BackgroundTransparency = 1, Text = "discord.gg/7rvgpgXrwd", TextColor3 = THEME.accent, Font = Enum.Font.Gotham,
		TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right }, frame)
	invite.MouseButton1Click:Connect(function()
		if copyText(GC.Discord) then
			invite.Text = "copied"
			task.delay(1.5, function()
				if invite.Parent then
					invite.Text = "discord.gg/7rvgpgXrwd"
				end
			end)
		end
	end)
end
local function show(title, desc, detail)
	setGoal(title or "", {})
	setNow((detail and detail ~= "") and detail or (desc or ""))
end
GC.DoSettings = true
GC.ThemeColor = "pink"
GC.DoAuto = true
GC.FireAll = true
GC.FireAllServerChecked = false
GC.DoAssist = true
GC.PetsPageFirst = true
GC.GrindMinutes = 180
GC.StepTimeout = 150
GC.GapSeconds = 0.3
local function blocker(id, plan)
	if plan.needsRealPet and not realPet() then
		local pet = choosePet()
		return "your egg has to hatch first", pet ~= nil and isEgg(pet.kind)
	end
	if plan.price and not canAfford(plan.price) then
		return string.format("saving up Bucks: %d / %d", money(), plan.price + GC.KeepBucks), true
	end
	return nil
end
local function helpsOf(plan)
	local helps = plan.grind
	if type(helps) == "function" then
		local ok, result = pcall(helps)
		helps = ok and result
	end
	return helps == true
end
local function canRunNow(plan)
	if not plan.canRun then
		return false
	end
	local ok, result = pcall(plan.canRun)
	return ok and result == true
end
local function runGuide()
	if not waitUntil(function() return getKey("loaded_in") == true end, 120) then
		say("The game hasn't loaded yet, try again in a moment", "bad")
		running = false
		return
	end
	if DEBUG then
		recording = true
	end
	say("Let's go! Reading your Guide...")
	if GC.DevLogs and httpRequest() then
		say("Your-turn tasks you finish are shared with the developer to improve the script (no keys, no passwords)")
	end
	writeLine("DATA", "pet_recycler_tickets_2026 = " .. tostring(getKey("pet_recycler_tickets_2026")))
	local pet = choosePet()
	if pet then
		say("Sticking with your " .. prettyKind(pet.kind) .. " for pet tasks")
	end
	if GC.DoSettings then
		local settings = getKey("settings_2021") or {}
		if settings.theme_color ~= GC.ThemeColor then
			send("SettingsAPI/SetSetting", "theme_color", GC.ThemeColor)
		end
		if settings.show_spawn_location_dialog ~= false then
			send("SettingsAPI/SetSetting", "show_spawn_location_dialog", false)
		end
	end
	local report = { auto = {}, fired = {}, assisted = {}, skipped = {}, failed = {} }
	local tries, slowRuns, assisted, firedAll = {}, {}, {}, {}
	local grindSince, announcedGrind, grindOver = nil, false, false
	local quietFire = false
	local function classify(ids)
		local quick, quickPlan, assist, waiting, grindable
		waiting = {}
		for _, id in ipairs(ids) do
			local plan = AUTO[id]
			local clientSide = definitions[id] and definitions[id].clientAuthoritative
			if plan and plan.kind == "slow" then
				local runsLeft = (slowRuns[id] or 0) < (plan.maxRuns or 6)
				if runsLeft and canRunNow(plan) then
					quick, quickPlan = quick or id, quickPlan or plan
				elseif runsLeft then
					table.insert(waiting, id)
					grindable = grindable or helpsOf(plan)
				elseif not assisted[id] then
					assist = assist or id
				end
			elseif GC.DoAuto and (plan or clientSide) and (tries[id] or 0) < ((plan and plan.retries) or 1) then
				local why, helps = blocker(id, plan or {})
				if not why then
					quick, quickPlan = quick or id, quickPlan or plan or { kind = "client" }
				elseif helps then
					table.insert(waiting, id)
					grindable = true
				elseif not assisted[id] then
					assist = assist or id
				end
			elseif not assisted[id] then
				assist = assist or id
			end
		end
		return quick, quickPlan, assist, waiting, grindable
	end
	local function firstPage(ids)
		if not GC.PetsPageFirst then
			return nil
		end
		local list, eggTask = {}, false
		for _, id in ipairs(ids) do
			if GC.PETS_PAGE_ONE[id] then
				table.insert(list, id)
				eggTask = eggTask or id == "equip_an_egg" or id == "hatch_an_egg"
			end
		end
		if #list == 0 or (eggTask and not itemsOf("pets", isEgg)[1]) then
			return nil
		end
		return list
	end
	local function runQuick(id, plan)
		writeLine("STEP", "=== AUTO " .. id .. " (" .. titleOf(id) .. ") place=" .. tostring(currentPlace()) .. " bucks=" .. money())
		local ok, why
		if plan.kind == "slow" then
			slowRuns[id] = (slowRuns[id] or 0) + 1
			show(titleOf(id), "", plan.line or "")
			ok, why = runWithTimeout(GC.StepTimeout, doSlow, id, plan)
		else
			tries[id] = (tries[id] or 0) + 1
			show(titleOf(id), "", "")
			ok, why = runWithTimeout(GC.StepTimeout, doAuto, id, plan)
		end
		flushCalls()
		writeLine("STEP", id .. " -> " .. (ok and "COMPLETED" or (ok == nil and "PROGRESS" or ("FAILED: " .. tostring(why)))))
		writeLine("READY", table.concat(readyIds(), ", "))
		if ok then
			say("Done: " .. titleOf(id), "ok")
			table.insert(report.auto, id)
			quietFire = false
		elseif ok == false then
			local again = plan.kind == "slow" or (tries[id] or 0) < (plan.retries or 1)
			say("Failed: " .. titleOf(id) .. (again and " (trying again later)" or ", your turn later"), "bad")
			table.insert(report.failed, id .. " (" .. tostring(why) .. ")")
			pcall(sendDevLog, id, titleOf(id), 0, {}, "script failed: " .. tostring(why))
		end
		task.wait(GC.GapSeconds)
	end
	local function fireAll()
		local targets = {}
		for id, def in pairs(definitions) do
			if not isCompleted(id) and not skip[id] and not firedAll[id]
				and (def.clientAuthoritative or GC.FireAllServerChecked) then
				table.insert(targets, id)
			end
		end
		table.sort(targets, guideOrder)
		if #targets > 0 then
			log("INFO", "FIRE ALL (" .. #targets .. "): " .. table.concat(targets, ", "))
		end
		local count = 0
		for _, id in ipairs(targets) do
			if not running then
				break
			end
			firedAll[id] = true
			say("Faking " .. titleOf(id))
			send("AchievementsAPI/CompleteAchievement", id)
			if waitUntil(function() return isCompleted(id) end, 1.5) then
				say("Done: " .. titleOf(id), "ok")
				table.insert(report.fired, id)
				count += 1
			end
			task.wait(0.1)
		end
		return count
	end
	local function assist(id)
		assisted[id] = true
		local def = definitions[id] or { title = id, description = "" }
		local place = ASSIST_PLACE[id]
		say("Your turn: " .. def.title, "warn")
		recording = true
		recent, queue, skipPressed = {}, {}, false
		assistCalls = {}
		local assistStart = os.clock()
		show(def.title, def.description, place and ("Taking you to " .. placeName(place) .. "...") or "")
		if place then
			local ok, why = goTo(place)
			if not ok then
				log("WARN", "travel failed: " .. tostring(why))
			end
		end
		show(def.title, def.description, "Your turn! Do it now, or press Skip")
		local started = os.clock()
		local timedOut = false
		while running and not skipPressed and not isCompleted(id) do
			task.wait(0.5)
			flushCalls()
			if os.clock() - started > 600 then
				log("WARN", id .. ": 10 min without completion -> next")
				timedOut = true
				break
			end
		end
		flushCalls()
		recording = DEBUG
		if isCompleted(id) then
			log("DONE", "=== COMPLETED " .. id .. " === game calls in the last " .. GC.CallWindowSeconds .. " s:")
			for _, call in ipairs(recent) do
				log("DONE", "   " .. call.text)
			end
			table.insert(report.assisted, id)
			say("Done: " .. def.title, "ok")
			pcall(sendDevLog, id, def.title, os.clock() - assistStart, assistCalls)
			show(def.title, "Completed!", "Next one coming up...")
			task.wait(1)
		elseif running then
			say("Skipped " .. def.title)
			table.insert(report.skipped, id)
			pcall(sendDevLog, id, def.title, os.clock() - assistStart, assistCalls,
				timedOut and "your turn: not done in 10 min" or "your turn: skipped")
		end
	end
	local firstNoted = false
	while running do
		local ids = readyIds()
		local first = firstPage(ids)
		if first and not firstNoted then
			firstNoted = true
			say("Pets page 1 first: backpack, egg, a need, hatching")
		end
		local quick, quickPlan, assistId, waiting, grindable = classify(first or ids)
		if quick then
			runQuick(quick, quickPlan)
		elseif GC.FireAll and not quietFire and not first then
			quietFire = true
			fireAll()
		elseif assistId and GC.DoAssist then
			assist(assistId)
		elseif #waiting > 0 and grindable and (first or not grindOver) then
			if not first then
				grindSince = grindSince or os.clock()
			end
			if not first and os.clock() - grindSince > GC.GrindMinutes * 60 then
				grindOver = true
				say("Spent " .. GC.GrindMinutes .. " min on the long tasks, moving on", "warn")
				pcall(sendDevLog, "long_tasks", "Long tasks", GC.GrindMinutes * 60, {}, "not finished in the grind: "
					.. table.concat(waiting, ", "))
			else
				if not announcedGrind and not first then
					announcedGrind = true
					say("Only long tasks left: taking care of your pet while they fill up")
				end
				local lines = {}
				for _, id in ipairs(waiting) do
					local plan = AUTO[id] or {}
					local why = plan.kind ~= "slow" and blocker(id, plan) or nil
					local okGoal, goal = pcall(slowGoal, id)
					table.insert(lines, (plan.kind ~= "slow" and (titleOf(id) .. ": ") or "") .. tostring(why or (okGoal and goal) or titleOf(id)))
				end
				while #lines > 4 do
					table.remove(lines)
				end
				setGoal(table.remove(lines, 1), lines)
				grindStep(waiting, first ~= nil)
			end
		else
			local leftover
			for _, id in ipairs(waiting) do
				if not assisted[id] then
					leftover = id
					break
				end
			end
			if leftover and GC.DoAssist then
				assist(leftover)
			else
				break
			end
		end
	end
	recording = DEBUG
	local total = #report.auto + #report.fired + #report.assisted
	if running then
		say("All done! " .. total .. " task(s) completed" .. (needsDone > 0 and (", " .. needsDone .. " needs") or ""), "ok")
		if #readyIds() > 0 then
			say(#readyIds() .. " left for later (they unlock as you play)")
		end
		show("All done!", total .. " task(s) completed", "")
	else
		say("Stopped. " .. total .. " task(s) completed so far", "warn")
		show("Stopped", total .. " task(s) completed", "")
	end
	running = false
	if onFinished then
		pcall(onFinished)
	end
end
local function mainWindow()
	local width = 270
	local frame = window(width, 236, function()
		running = false
		uiLog = nil
		ui.now = nil
	end)
	text(frame, 10, 36, 40, 16, "Now", 11, THEME.accent, true)
	ui.now = text(frame, 48, 36, width - 58, 16, status.now, 12, THEME.text, true)
	text(frame, 10, 54, 40, 14, "Goal", 11, THEME.accent, true)
	ui.goal = text(frame, 48, 54, width - 58, 14, status.goal, 11, THEME.text)
	ui.queue = create("TextLabel", { Position = UDim2.fromOffset(10, 72), Size = UDim2.fromOffset(width - 20, 40),
		BackgroundTransparency = 1, Text = "", TextColor3 = THEME.dim, Font = Enum.Font.Gotham, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = false,
		ClipsDescendants = true }, frame)
	create("Frame", { Position = UDim2.fromOffset(10, 114), Size = UDim2.new(1, -20, 0, 1), BackgroundColor3 = THEME.line,
		BorderSizePixel = 0 }, frame)
	renderStatus()
	local logBox = create("TextLabel", { Position = UDim2.fromOffset(10, 120), Size = UDim2.fromOffset(width - 20, 56),
		BackgroundTransparency = 1, Text = "", RichText = true, TextColor3 = THEME.dim, Font = Enum.Font.Gotham, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom, TextWrapped = false,
		ClipsDescendants = true }, frame)
	local shown = {}
	local TONES = { ok = "#5ac878", bad = "#e65a5a", warn = "#d6a046", info = "#9a9aae" }
	uiLog = function(tone, message)
		local safe = string.gsub(string.gsub(string.gsub(tostring(message), "&", "&amp;"), "<", "&lt;"), ">", "&gt;")
		table.insert(shown, '<font color="' .. (TONES[tone] or TONES.info) .. '">' .. safe .. "</font>")
		while #shown > 4 do
			table.remove(shown, 1)
		end
		logBox.Text = table.concat(shown, "\n")
	end
	local third = (width - 32) / 3
	local startButton
	startButton = button(frame, 10, 184, third, "Start", THEME.ok, function()
		if running then
			return
		end
		running = true
		startButton.Text = "Running"
		onFinished = function()
			startButton.Text = "Start"
		end
		task.spawn(function()
			local ok = pcall(runGuide)
			if not ok then
				say("something went wrong, press Start again", "bad")
				running = false
				startButton.Text = "Start"
			end
		end)
	end)
	button(frame, 16 + third, 184, third, "Skip", THEME.text, function()
		skipPressed = true
	end)
	button(frame, 22 + third * 2, 184, third, "Stop", THEME.bad, function()
		running = false
		show("Stopped", "", "")
	end)
	footer(frame, width, 214)
end
env.AutoAchievements = {
	Stop = function() running = false end,
	Skip = function() skipPressed = true end,
}
mainWindow()
