
do
    local B = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    local function b64decode(data)
        data = data:gsub("[^" .. B .. "=]", "")
        return (data:gsub(".", function(x)
            if x == "=" then
                return ""
            end

            local bits = ""
            local value = B:find(x, 1, true) - 1
            for i = 6, 1, -1 do
                bits = bits .. (value % 2 ^ i - value % 2 ^ (i - 1) > 0 and "1" or "0")
            end
            return bits
        end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(bits)
            if #bits ~= 8 then
                return ""
            end

            local value = 0
            for i = 1, 8 do
                value = value + (bits:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
            end
            return string.char(value)
        end))
    end

    local _PRINT = print
    local _STOP = StopResource
    local _WAIT = Citizen and Citizen.Wait or Wait
    local _ERROR = error
    local _GETNAME = GetCurrentResourceName
    local _GETSTATE = GetResourceState

    local EXPECTEDNAME = b64decode("Zm9ydHVuYV9odW50aW5nd2Fnb24=") -- fortuna_huntingwagon
    local LEGACYNAME = b64decode("Zm9ydHVuYS1odW50aW5nd2Fnb24=") -- fortuna-huntingwagon (compatibility)
    local STOREURL = b64decode("aHR0cHM6Ly9waWNoaXJpbi1jYi50ZWJleC5pby8=") -- Official CB Studios store
    local CURRENT = _GETNAME()

    local SCRIPT_NAME = EXPECTEDNAME
    local VERSION = "2.2.0"

    local function detectFramework()
        local vorpState = _GETSTATE("vorp_core")
        local redemState = _GETSTATE("redem_roleplay")

        if vorpState == "started" then
            return "VORP"
        end
        if redemState == "started" then
            return "RedEM:RP"
        end
        if vorpState == "starting" or redemState == "starting" then
            return "Starting..."
        end
        return "Standalone"
    end

    local function detectDebug()
        local cfg = rawget(_G, "Config")
        if type(cfg) == "table" and type(cfg.Debug) == "boolean" then
            return cfg.Debug and "ON" or "OFF"
        end
        return "N/A"
    end

    local framework = detectFramework()
    local debugMode = detectDebug()

    if CURRENT ~= EXPECTEDNAME and CURRENT ~= LEGACYNAME then
        _PRINT("^1===========================================================^7")
        _PRINT("^1   ^3P I C H I R I N _ C B^7  |  ^1RESOURCE VALIDATION FAILED^7")
        _PRINT("^1===========================================================^7")
        _PRINT("^3[!] ^7UNAUTHORIZED RESOURCE FOLDER NAME DETECTED.^7")
        _PRINT("^3[*] ^7SCRIPT: ^3" .. SCRIPT_NAME .. "^7  ^7| VERSION: ^3" .. VERSION .. "^7")
        _PRINT("^3[*] ^7EXPECTED: ^3" .. EXPECTEDNAME .. "^7")
        _PRINT("^3[*] ^7FOUND:    ^3" .. CURRENT .. "^7")
        _PRINT("^3[*] ^7FRAMEWORK: ^3" .. framework .. "^7  ^7| DEBUG: ^3" .. debugMode .. "^7")
        _PRINT("^3[!] ^7PLEASE RENAME THE RESOURCE FOLDER TO THE EXPECTED NAME TO USE THIS SCRIPT.^7")
        _PRINT("^1[!] THIS RESOURCE HAS BEEN BLOCKED FOR SECURITY REASONS.^7")
        _PRINT("^1[*] OFFICIAL STORE: ^3" .. STOREURL .. "^7")
        _PRINT("^1===========================================================^7")

        _STOP(CURRENT)
        _WAIT(50)
        _ERROR("^1[PICHIRIN_CB] WARNING: THIS IS NOT A SCRIPT ERROR. READ THE PRINT CAREFULLY AND CHANGE THE NAME OF THE SCRIPT.^7")
        return
    end

    _PRINT("^2===========================================================^7")
    _PRINT("^2   ^3P I C H I R I N _ C B^7  |  ^2RESOURCE VALIDATION SUCCESS^7")
    _PRINT("^2===========================================================^7")
    _PRINT("^2[OK]^7 SCRIPT: ^3" .. SCRIPT_NAME .. "^7  ^7| VERSION: ^3" .. VERSION .. "^7")
    _PRINT("^2[OK]^7 RESOURCE FOLDER NAME VALIDATED: ^3" .. CURRENT .. "^7")
    if CURRENT == LEGACYNAME then
        _PRINT("^3[!] ^7Legacy folder name is accepted (^3" .. LEGACYNAME .. "^7), but ^3" .. EXPECTEDNAME .. "^7 is recommended.")
    end
    _PRINT("^2[*]^7 FRAMEWORK: ^3" .. framework .. "^7  ^7| DEBUG: ^3" .. debugMode .. "^7")
    _PRINT("^2[*]^7 THANK YOU FOR SUPPORTING THE SECURITY OF OUR WORK.^7")
    _PRINT("^2[*]^7 STORE: ^3" .. STOREURL .. "^7")
    _PRINT("^2===========================================================^7")
end

local wagons = {}
local busyPlayers = {}
local busyWagons = {}
local pending = {}
local processedCargo = {}
local securityCooldown = {}

local function positiveNumber(name, value, integer)
    if type(value) ~= "number" or value <= 0 or (integer and value % 1 ~= 0) then
        error(("[fortuna_huntingwagon] %s must be a positive %s."):format(name, integer and "integer" or "number"))
    end
end

local function validateConfig()
    if not Locales or not Locales[Config.Locale] then
        error(("[fortuna_huntingwagon] Unsupported locale '%s'."):format(tostring(Config.Locale)))
    end
    positiveNumber("Config.MaxCapacity", Config.MaxCapacity, true)
    positiveNumber("Config.InteractionDistance", Config.InteractionDistance)
    positiveNumber("Config.PlayerValidationDistance", Config.PlayerValidationDistance)
    positiveNumber("Config.CargoValidationDistance", Config.CargoValidationDistance)
    positiveNumber("Config.GroundCargoDistance", Config.GroundCargoDistance)
    positiveNumber("Config.DeleteConfirmationTimeout", Config.DeleteConfirmationTimeout, true)
    positiveNumber("Config.RetrieveTimeout", Config.RetrieveTimeout, true)
    positiveNumber("Config.MaintenanceInterval", Config.MaintenanceInterval, true)
    positiveNumber("Config.Discord.QueueLimit", Config.Discord.QueueLimit, true)
    positiveNumber("Config.Discord.DelayBetweenMessages", Config.Discord.DelayBetweenMessages, true)
    if type(Config.Discord.MaxRetries) ~= "number" or Config.Discord.MaxRetries < 0 or Config.Discord.MaxRetries % 1 ~= 0 then
        error("[fortuna_huntingwagon] Config.Discord.MaxRetries must be a non-negative integer.")
    end
    local notificationModes = { auto = true, vorp = true, chat = true, custom = true }
    if not notificationModes[Config.Notification.System] then
        error("[fortuna_huntingwagon] Config.Notification.System must be auto, vorp, chat or custom.")
    end
    if Config.Notification.System == "custom" and (type(Config.Notification.CustomEvent) ~= "string" or Config.Notification.CustomEvent == "") then
        error("[fortuna_huntingwagon] A non-empty CustomEvent is required for custom notifications.")
    end
    local accessModes = { public = true, ace = true, statebag = true }
    if not accessModes[Config.Access.Mode] then
        error("[fortuna_huntingwagon] Config.Access.Mode must be public, ace or statebag.")
    end
    if Config.Access.Mode == "ace" and (type(Config.Access.AcePermission) ~= "string" or Config.Access.AcePermission == "") then
        error("[fortuna_huntingwagon] A non-empty AcePermission is required for ACE access.")
    end
    if Config.Access.Mode == "statebag" and (type(Config.Access.OwnerStateBag) ~= "string" or Config.Access.OwnerStateBag == "") then
        error("[fortuna_huntingwagon] A non-empty OwnerStateBag is required for state-bag access.")
    end
    if Config.PlayerValidationDistance < Config.InteractionDistance then
        error("[fortuna_huntingwagon] PlayerValidationDistance cannot be smaller than InteractionDistance.")
    end
    if Config.CargoValidationDistance < Config.GroundCargoDistance then
        error("[fortuna_huntingwagon] CargoValidationDistance cannot be smaller than GroundCargoDistance.")
    end
    if type(Config.Persistence) ~= "table" or type(Config.Persistence.Enabled) ~= "boolean" then
        error("[fortuna_huntingwagon] Config.Persistence.Enabled must be a boolean.")
    end
    if Config.Persistence.Enabled then
        if Config.Persistence.Adapter ~= "vorp_stables" then
            error("[fortuna_huntingwagon] Config.Persistence.Adapter must be vorp_stables.")
        end
        if type(Config.Persistence.StateBagKey) ~= "string" or Config.Persistence.StateBagKey == "" then
            error("[fortuna_huntingwagon] Persistence StateBagKey must be a non-empty string.")
        end
        if type(Config.Persistence.Table) ~= "string" or not Config.Persistence.Table:match("^[%w_]+$") then
            error("[fortuna_huntingwagon] Persistence Table must contain only letters, numbers and underscores.")
        end
    end
    for model, size in pairs(Config.Cargo) do
        if type(model) ~= "number" or type(size) ~= "number" or size <= 0 or size % 1 ~= 0 then
            error("[fortuna_huntingwagon] Every Config.Cargo entry must use a numeric model and positive integer size.")
        end
    end
    for name, color in pairs(Config.Discord.Colors) do
        if type(color) ~= "number" or color < 0 or color > 16777215 then
            error(("[fortuna_huntingwagon] Invalid Discord color '%s'."):format(name))
        end
    end
end

local function notify(source, key)
    TriggerClientEvent("fortuna_huntingwagon:notify", source, _U(key))
end

local function securityLog(source, reason)
    local now = os.time()
    if securityCooldown[source] and now - securityCooldown[source] < 10 then return end
    securityCooldown[source] = now
    local ped = GetPlayerPed(source)
    FortunaDiscordLog("security", source, {
        reason = reason,
        coords = ped ~= 0 and DoesEntityExist(ped) and GetEntityCoords(ped) or nil
    })
end

local function getCapacity(entries)
    local total = 0
    for _, entry in ipairs(entries) do total = total + entry.size end
    return total
end

local function getRecord(wagonId, wagon, create)
    local record = wagons[wagonId]
    if record and record.entity ~= wagon then
        wagons[wagonId] = nil
        record = nil
    end
    if not record and FortunaPersistenceIsEnabled() then
        local entries, persistenceId = FortunaPersistenceLoad(wagon)
        if persistenceId then
            record = { entity = wagon, entries = entries, reserved = 0, persistenceId = persistenceId }
            wagons[wagonId] = record
        elseif Config.Persistence.RequireRegisteredWagon then
            return nil
        end
    end
    if not record and create then
        record = { entity = wagon, entries = {}, reserved = 0, persistenceId = nil }
        wagons[wagonId] = record
    end
    return record
end

local function setCapacity(record)
    if record and DoesEntityExist(record.entity) then
        Entity(record.entity).state:set("fortunaHuntingCargo", getCapacity(record.entries), true)
    end
end

AddEventHandler("fortuna_huntingwagon:server:wagonRegistered", function(wagonNetId, wagon)
    if not FortunaPersistenceIsEnabled() or not DoesEntityExist(wagon) then return end
    local record = getRecord(tonumber(wagonNetId), wagon, true)
    if record then setCapacity(record) end
end)

local function hasAccess(source, wagon)
    if type(Config.Access.CustomCheck) == "function" then
        local ok, allowed = pcall(Config.Access.CustomCheck, source, wagon)
        if not ok then
            print(("[fortuna_huntingwagon] Access CustomCheck failed: %s"):format(allowed))
            return false
        end
        return allowed == true
    end
    if Config.Access.Mode == "public" then return true end
    if Config.Access.Mode == "ace" then return IsPlayerAceAllowed(source, Config.Access.AcePermission) end
    if Config.Access.Mode == "statebag" then
        local owner = Entity(wagon).state[Config.Access.OwnerStateBag]
        if owner == nil then return false end
        if tostring(owner) == tostring(source) then return true end
        for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
            if tostring(owner) == identifier then return true end
        end
    end
    return false
end

local function wagonRearCoords(wagon, zOffset)
    local coords = GetEntityCoords(wagon)
    local heading = math.rad(GetEntityHeading(wagon))
    return vector3(
        coords.x + math.sin(heading) * 2.3,
        coords.y - math.cos(heading) * 2.3,
        coords.z + (zOffset or 0.25)
    )
end

local function validWagon(source, wagonNetId)
    wagonNetId = tonumber(wagonNetId)
    if not wagonNetId or wagonNetId == 0 then return nil end
    local wagon = NetworkGetEntityFromNetworkId(wagonNetId)
    local playerPed = GetPlayerPed(source)
    if wagon == 0 or playerPed == 0 or not DoesEntityExist(wagon) or not DoesEntityExist(playerPed) then return nil end
    if GetEntityModel(wagon) ~= Config.WagonModel then return nil end
    local rear = wagonRearCoords(wagon, 0.4)
    if #(GetEntityCoords(playerPed) - rear) > Config.PlayerValidationDistance then return nil end
    return wagon, wagonNetId
end

local function validCargo(wagon, cargoNetId)
    cargoNetId = tonumber(cargoNetId)
    if not cargoNetId or cargoNetId == 0 then return nil end
    local cargo = NetworkGetEntityFromNetworkId(cargoNetId)
    if cargo == 0 or not DoesEntityExist(cargo) then return nil end
    local rear = wagonRearCoords(wagon, 0.25)
    if #(GetEntityCoords(cargo) - rear) > Config.CargoValidationDistance then return nil end
    local model = GetEntityModel(cargo)
    local size = Config.Cargo[model]
    if not size then return nil end
    local entityType = GetEntityType(cargo)
    if entityType == 1 then
        if GetEntityHealth(cargo) > 0 then return nil end
    elseif entityType ~= 3 then
        return nil
    end
    return cargo, cargoNetId, model, size, entityType
end

local function releaseLocks(source, wagonId)
    busyPlayers[source] = nil
    if wagonId then busyWagons[wagonId] = nil end
end

local function restorePending(source)
    local request = pending[source]
    if not request then return false end
    local record = wagons[request.wagonId]
    if record then
        record.reserved = math.max(0, record.reserved - request.entry.size)
        if DoesEntityExist(record.entity) and getCapacity(record.entries) + request.entry.size <= Config.MaxCapacity then
            record.entries[#record.entries + 1] = request.entry
            setCapacity(record)
        end
    end
    pending[source] = nil
    return true
end

local function resetExistingStateBags()
    if type(GetAllVehicles) ~= "function" then return end
    for _, vehicle in ipairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) and GetEntityModel(vehicle) == Config.WagonModel then
            Entity(vehicle).state:set("fortunaHuntingCargo", 0, true)
        end
    end
end

CreateThread(function()
    validateConfig()
    Wait(0)
    resetExistingStateBags()
    local version = GetResourceMetadata(GetCurrentResourceName(), "version", 0) or "unknown"
    print(("^2[Fortuna Hunting Wagon]^7 v%s loaded successfully — ^3by pichirin_cb^7 | GPL-3.0-or-later"):format(version))
end)

RegisterNetEvent("fortuna_huntingwagon:store", function(wagonNetId, cargoNetId, clientData)
    local source = source
    if busyPlayers[source] then return notify(source, "busy") end
    local wagon, wagonId = validWagon(source, wagonNetId)
    if not wagon then securityLog(source, "reason_invalid_store") return notify(source, "invalid") end
    if busyWagons[wagonId] then return notify(source, "busy") end
    if not hasAccess(source, wagon) then securityLog(source, "reason_unauthorized") return notify(source, "no_access") end

    local cargo, cargoId, model, size, entityType = validCargo(wagon, cargoNetId)
    if not cargo or type(clientData) ~= "table" or tonumber(clientData.model) ~= model then
        securityLog(source, "reason_invalid_store")
        return notify(source, "invalid")
    end
    local processed = processedCargo[cargoId]
    if processed and processed.entity == cargo then
        securityLog(source, "reason_invalid_store")
        return notify(source, "invalid")
    end

    local record = getRecord(wagonId, wagon, true)
    if not record then
        securityLog(source, "reason_invalid_store")
        return notify(source, "invalid")
    end
    if getCapacity(record.entries) + record.reserved + size > Config.MaxCapacity then return notify(source, "full") end
    busyPlayers[source] = true
    busyWagons[wagonId] = source
    processedCargo[cargoId] = { entity = cargo, expires = os.time() + 60 }

    DeleteEntity(cargo)
    local deadline = GetGameTimer() + Config.DeleteConfirmationTimeout
    while DoesEntityExist(cargo) and GetGameTimer() < deadline do Wait(25) end
    if DoesEntityExist(cargo) then
        processedCargo[cargoId] = nil
        releaseLocks(source, wagonId)
        securityLog(source, "reason_delete_failed")
        return notify(source, "store_failed")
    end

    local quality = math.max(0, math.min(3, math.floor(tonumber(clientData.quality) or 0)))
    local peltQuality = math.floor(tonumber(clientData.peltQuality) or 0)
    peltQuality = math.max(-2147483648, math.min(2147483647, peltQuality))
    local entry = {
        model = model, size = size, isPelt = entityType == 3,
        quality = quality, peltQuality = peltQuality, skinned = clientData.skinned == true
    }
    record.entries[#record.entries + 1] = entry
    setCapacity(record)
    FortunaPersistenceSave(record)
    releaseLocks(source, wagonId)
    notify(source, "stored")
    FortunaDiscordLog("store", source, {
        wagonId = wagonId, model = model, isPelt = entry.isPelt,
        capacity = getCapacity(record.entries), coords = GetEntityCoords(wagon)
    })
    TriggerEvent("fortuna_huntingwagon:server:cargoStored", source, wagonId, model, size, getCapacity(record.entries))
end)

RegisterNetEvent("fortuna_huntingwagon:retrieve", function(wagonNetId)
    local source = source
    if busyPlayers[source] or pending[source] then return notify(source, "busy") end
    local wagon, wagonId = validWagon(source, wagonNetId)
    if not wagon then securityLog(source, "reason_invalid_retrieve") return notify(source, "invalid") end
    if busyWagons[wagonId] then return notify(source, "busy") end
    if not hasAccess(source, wagon) then securityLog(source, "reason_unauthorized") return notify(source, "no_access") end
    local record = getRecord(wagonId, wagon, false)
    if not record or #record.entries == 0 then return notify(source, "empty") end

    busyPlayers[source] = true
    busyWagons[wagonId] = source
    local entry = table.remove(record.entries)
    record.reserved = record.reserved + entry.size
    pending[source] = { wagonId = wagonId, entry = entry, expires = os.time() + Config.RetrieveTimeout }
    setCapacity(record)
    releaseLocks(source, wagonId)
    TriggerClientEvent("fortuna_huntingwagon:spawnCargo", source, wagonId, entry)
end)

RegisterNetEvent("fortuna_huntingwagon:restore", function()
    local source = source
    if restorePending(source) then notify(source, "retrieve_failed") end
end)

RegisterNetEvent("fortuna_huntingwagon:spawned", function(wagonNetId, cargoNetId)
    local source = source
    local request = pending[source]
    if not request or request.wagonId ~= tonumber(wagonNetId) then return end
    local record = wagons[request.wagonId]
    local wagon = record and record.entity or 0
    cargoNetId = tonumber(cargoNetId)
    local cargo = cargoNetId and NetworkGetEntityFromNetworkId(cargoNetId) or 0
    local syncDeadline = GetGameTimer() + 2000
    while cargoNetId and (cargo == 0 or not DoesEntityExist(cargo)) and GetGameTimer() < syncDeadline do
        Wait(25)
        cargo = NetworkGetEntityFromNetworkId(cargoNetId)
    end
    if pending[source] ~= request then return end
    local valid = wagon ~= 0 and cargo ~= 0 and DoesEntityExist(wagon) and DoesEntityExist(cargo)
    if valid then
        local rear = wagonRearCoords(wagon, 0.25)
        valid = GetEntityModel(cargo) == request.entry.model and
            #(GetEntityCoords(cargo) - rear) <= Config.CargoValidationDistance + 1.0
        local entityType = GetEntityType(cargo)
        valid = valid and ((request.entry.isPelt and entityType == 3) or
            (not request.entry.isPelt and entityType == 1 and GetEntityHealth(cargo) <= 0))
    end
    if not valid then
        restorePending(source)
        securityLog(source, "reason_invalid_spawn")
        TriggerClientEvent("fortuna_huntingwagon:spawnRejected", source, cargoNetId)
        return notify(source, "retrieve_failed")
    end

    record.reserved = math.max(0, record.reserved - request.entry.size)
    pending[source] = nil
    FortunaPersistenceSave(record)
    FortunaDiscordLog("retrieve", source, {
        wagonId = request.wagonId, model = request.entry.model, isPelt = request.entry.isPelt,
        capacity = getCapacity(record.entries), coords = GetEntityCoords(wagon)
    })
    TriggerEvent("fortuna_huntingwagon:server:cargoRetrieved", source, request.wagonId,
        request.entry.model, request.entry.size, getCapacity(record.entries))
    TriggerClientEvent("fortuna_huntingwagon:pickupSpawnedCargo", source, cargoNetId)
end)

CreateThread(function()
    while true do
        Wait(Config.MaintenanceInterval)
        local now = os.time()
        for wagonId, record in pairs(wagons) do
            if not DoesEntityExist(record.entity) or NetworkGetNetworkIdFromEntity(record.entity) ~= wagonId then
                wagons[wagonId] = nil
                busyWagons[wagonId] = nil
            end
        end
        for player, request in pairs(pending) do
            if request.expires <= now then
                restorePending(player)
                notify(player, "retrieve_failed")
            end
        end
        for cargoId, data in pairs(processedCargo) do
            if data.expires <= now or not DoesEntityExist(data.entity) then processedCargo[cargoId] = nil end
        end
    end
end)

AddEventHandler("entityRemoved", function(entity)
    for wagonId, record in pairs(wagons) do
        if record.entity == entity then
            wagons[wagonId] = nil
            busyWagons[wagonId] = nil
            break
        end
    end
end)

AddEventHandler("playerDropped", function()
    local source = source
    busyPlayers[source] = nil
    securityCooldown[source] = nil
    restorePending(source)
    for wagonId, owner in pairs(busyWagons) do
        if owner == source then busyWagons[wagonId] = nil end
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, record in pairs(wagons) do
        if DoesEntityExist(record.entity) then
            Entity(record.entity).state:set("fortunaHuntingCargo", 0, true)
        end
    end
end)

exports("GetWagonStatus", function(wagonNetId)
    local record = wagons[tonumber(wagonNetId)]
    if not record then return { count = 0, occupied = 0, reserved = 0, maximum = Config.MaxCapacity } end
    return {
        count = #record.entries,
        occupied = getCapacity(record.entries),
        reserved = record.reserved,
        maximum = Config.MaxCapacity
    }
end)

exports("IsSupportedCargo", function(model)
    return Config.Cargo[tonumber(model)] ~= nil
end)

exports("CanAccessWagon", function(source, wagonNetId)
    local wagon = NetworkGetEntityFromNetworkId(tonumber(wagonNetId) or 0)
    return wagon ~= 0 and DoesEntityExist(wagon) and GetEntityModel(wagon) == Config.WagonModel and hasAccess(source, wagon)
end)
