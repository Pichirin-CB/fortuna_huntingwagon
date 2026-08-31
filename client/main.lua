
local promptGroup = GetRandomIntInRange(0, 0x7FFFFFFF)
local storePrompt
local retrievePrompt
local actionLocked = false
local visualTarp = {}
local requestControl
local spawnedCargo = {}

local function makePrompt(text)
    local prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, Config.Control)
    PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", text))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, true)
    PromptSetGroup(prompt, promptGroup)
    PromptRegisterEnd(prompt)
    return prompt
end

CreateThread(function()
    storePrompt = makePrompt(_U("store"))
    retrievePrompt = makePrompt(_U("retrieve"))
end)

local function carriedByPlayer(ped)
    local entity = Citizen.InvokeNative(0xD806CD2A4F2C2996, ped)
    return entity and entity ~= 0 and entity or nil
end

local function closestHuntingWagon(coords)
    local closest, closestDistance
    for _, vehicle in ipairs(GetGamePool("CVehicle")) do
        if DoesEntityExist(vehicle) and NetworkGetEntityIsNetworked(vehicle) and GetEntityModel(vehicle) == Config.WagonModel then
            local rear = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -2.3, 0.4)
            local distance = #(coords - rear)
            if not closestDistance or distance < closestDistance then closest, closestDistance = vehicle, distance end
        end
    end
    return closest, closestDistance
end

local function closestGroundCargo(wagon)
    local rear = GetOffsetFromEntityInWorldCoords(wagon, 0.0, -2.3, 0.25)
    local closest, closestDistance
    for _, pool in ipairs({ "CPed", "CObject" }) do
        for _, entity in ipairs(GetGamePool(pool)) do
            if DoesEntityExist(entity) and Config.Cargo[GetEntityModel(entity)] then
                local valid = GetEntityType(entity) ~= 1 or IsEntityDead(entity)
                local distance = #(GetEntityCoords(entity) - rear)
                if valid and distance <= Config.GroundCargoDistance and (not closestDistance or distance < closestDistance) then
                    closest, closestDistance = entity, distance
                end
            end
        end
    end
    return closest
end

local function storeCargo(wagon, cargo)
    if not cargo or not Config.Cargo[GetEntityModel(cargo)] or not requestControl(cargo) then
        TriggerEvent("fortuna_huntingwagon:notify", _U("invalid"))
        return
    end
    if not NetworkGetEntityIsNetworked(cargo) then
        SetEntityAsMissionEntity(cargo, true, true)
        NetworkRegisterEntityAsNetworked(cargo)
        local timeout = GetGameTimer() + 2000
        while DoesEntityExist(cargo) and not NetworkGetEntityIsNetworked(cargo) and GetGameTimer() < timeout do
            Wait(25)
            NetworkRegisterEntityAsNetworked(cargo)
        end
    end
    if not NetworkGetEntityIsNetworked(cargo) then
        TriggerEvent("fortuna_huntingwagon:notify", _U("store_failed"))
        return
    end
    local cargoNetId = NetworkGetNetworkIdFromEntity(cargo)
    if not cargoNetId or cargoNetId == 0 then
        TriggerEvent("fortuna_huntingwagon:notify", _U("store_failed"))
        return
    end
    local isPelt = GetEntityType(cargo) == 3
    TriggerServerEvent("fortuna_huntingwagon:store", VehToNet(wagon), cargoNetId, {
        model = GetEntityModel(cargo),
        quality = isPelt and 0 or Citizen.InvokeNative(0x7BCC6087D130312A, cargo),
        peltQuality = isPelt and Citizen.InvokeNative(0x31FEF6A20F00B963, cargo) or 0,
        skinned = not isPelt and Citizen.InvokeNative(0x8DE41E9902E85756, cargo) == 1
    })
end

requestControl = function(entity)
    local timeout = GetGameTimer() + 1500
    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        Wait(25)
        NetworkRequestControlOfEntity(entity)
    end
    return NetworkHasControlOfEntity(entity)
end

local function updateVisualTarp(wagon, occupied)
    local height = math.max(0.02, math.min(1.0, (tonumber(occupied) or 0) / math.max(1, Config.MaxCapacity)))
    if not visualTarp[wagon] then
        Citizen.InvokeNative(0x75F90E4051CC084C, wagon, Config.VisualTarpPropSet)
        visualTarp[wagon] = -1.0
    end
    if math.abs(visualTarp[wagon] - height) > 0.001 then
        Citizen.InvokeNative(0x31F343383F19C987, wagon, height, false)
        visualTarp[wagon] = height
    end
end

CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local seen = {}
        for _, wagon in ipairs(GetGamePool("CVehicle")) do
            if DoesEntityExist(wagon) and GetEntityModel(wagon) == Config.WagonModel then
                seen[wagon] = true
                if #(playerCoords - GetEntityCoords(wagon)) <= Config.VisualDistance then
                    updateVisualTarp(wagon, Entity(wagon).state.fortunaHuntingCargo or 0)
                end
            end
        end
        for wagon in pairs(visualTarp) do
            if not seen[wagon] or not DoesEntityExist(wagon) then visualTarp[wagon] = nil end
        end
        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        local sleep = 750
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local wagon, distance = closestHuntingWagon(coords)

        if wagon and distance <= Config.InteractionDistance and not IsPedInAnyVehicle(ped, false) then
            sleep = 0
            local carried = carriedByPlayer(ped)
            local groundCargo = not carried and closestGroundCargo(wagon) or nil
            local cargo = carried or groundCargo
            local capacity = Entity(wagon).state.fortunaHuntingCargo or 0
            local title = ("%s (%d/%d)"):format(_U("group"), capacity, Config.MaxCapacity)
            UiPromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, "LITERAL_STRING", title), 0, 0, 0, 0)

            PromptSetEnabled(storePrompt, cargo ~= nil and not actionLocked)
            PromptSetVisible(storePrompt, cargo ~= nil)
            PromptSetEnabled(retrievePrompt, cargo == nil and capacity > 0 and not actionLocked)
            PromptSetVisible(retrievePrompt, cargo == nil and capacity > 0)

            if cargo and PromptHasHoldModeCompleted(storePrompt) and not actionLocked then
                actionLocked = true
                storeCargo(wagon, cargo)
                SetTimeout(1200, function() actionLocked = false end)
            elseif not cargo and capacity > 0 and PromptHasHoldModeCompleted(retrievePrompt) and not actionLocked then
                actionLocked = true
                TriggerServerEvent("fortuna_huntingwagon:retrieve", VehToNet(wagon))
                SetTimeout(1200, function() actionLocked = false end)
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent("fortuna_huntingwagon:notify", function(message)
    local system = Config.Notification.System
    if system == "custom" and Config.Notification.CustomEvent ~= "" then
        TriggerEvent(Config.Notification.CustomEvent, message, 4000)
    elseif system == "vorp" or (system == "auto" and GetResourceState("vorp_core") == "started") then
        TriggerEvent("vorp:TipRight", message, 4000)
    elseif system == "chat" or (system == "auto" and GetResourceState("chat") == "started") then
        TriggerEvent("chat:addMessage", { color = { 218, 165, 32 }, args = { "Hunting Wagon", message } })
    else
        print(("[Fortuna Hunting Wagon] %s"):format(tostring(message)))
    end
end)

local function pickupCargo(ped, cargo)
    ResetEntityAlpha(cargo)
    SetEntityVisible(cargo, false)
    Citizen.InvokeNative(0x18FF3110CF47115D, cargo, 21, true)
    TaskPickupCarriableEntity(ped, cargo)

    local timeout = GetGameTimer() + 3500
    local pickedUp = false
    while GetGameTimer() < timeout do
        if carriedByPlayer(ped) == cargo or IsEntityAttachedToEntity(cargo, ped) then
            pickedUp = true
            break
        end
        if GetScriptTaskStatus(ped, `SCRIPT_TASK_PICKUP_CARRIABLE_ENTITY`, true) == 8 then break end
        Wait(25)
    end

    FreezeEntityPosition(cargo, false)
    SetEntityCollision(cargo, true, true)
    Citizen.InvokeNative(0x18FF3110CF47115D, cargo, 21, false)

    if pickedUp or IsEntityAttached(cargo) then
        ResetEntityAlpha(cargo)
        SetEntityVisible(cargo, true)
        -- RedM can overwrite visibility for one frame while completing the
        -- carry task, so reinforce it briefly after the attachment succeeds.
        CreateThread(function()
            for _ = 1, 10 do
                if not DoesEntityExist(cargo) then return end
                ResetEntityAlpha(cargo)
                SetEntityVisible(cargo, true)
                Wait(50)
            end
        end)
    else
        PlaceEntityOnGroundProperly(cargo, true)
        ResetEntityAlpha(cargo)
        SetEntityVisible(cargo, true)
    end
end

RegisterNetEvent("fortuna_huntingwagon:spawnCargo", function(wagonNetId, entry)
    local wagon = NetToVeh(wagonNetId)
    if not DoesEntityExist(wagon) or type(entry) ~= "table" or not Config.Cargo[tonumber(entry.model)] then
        TriggerServerEvent("fortuna_huntingwagon:restore")
        return
    end

    local model = tonumber(entry.model)
    RequestModel(model, false)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(25) end
    if not HasModelLoaded(model) then
        TriggerServerEvent("fortuna_huntingwagon:restore")
        return
    end

    local rear = GetOffsetFromEntityInWorldCoords(wagon, 0.0, -3.4, 0.15)
    local cargo
    if entry.isPelt then
        cargo = CreateObject(model, rear.x, rear.y, rear.z, true, true, false, false, false)
        if cargo ~= 0 then
            SetEntityVisible(cargo, false)
            SetEntityCollision(cargo, false, false)
            FreezeEntityPosition(cargo, true)
            Citizen.InvokeNative(0x78B4567E18B54480, cargo)
            Citizen.InvokeNative(0xF0B4F759F35CC7F5, cargo, Citizen.InvokeNative(0x34F008A7E48C496B, cargo, 0), PlayerPedId(), 7, 512)
            Citizen.InvokeNative(0x399657ED871B3A6C, cargo, tonumber(entry.peltQuality) or 0)
        end
    else
        cargo = CreatePed(model, rear.x, rear.y, rear.z, GetEntityHeading(wagon), true, true, false, false)
        if cargo ~= 0 then
            Citizen.InvokeNative(0x283978A15512B2FE, cargo, true)
            ResetEntityAlpha(cargo)
            SetEntityVisible(cargo, false)
            SetEntityCollision(cargo, false, false)
            FreezeEntityPosition(cargo, true)
            SetEntityHealth(cargo, 0)
            Citizen.InvokeNative(0xCE6B874286D640BB, cargo, tonumber(entry.quality) or 0)
            if entry.skinned then Citizen.InvokeNative(0x6BCF5F3D8FFE988D, cargo, true) end
        end
    end
    SetModelAsNoLongerNeeded(model)

    if not cargo or cargo == 0 then
        TriggerServerEvent("fortuna_huntingwagon:restore")
        return
    end
    SetEntityAsMissionEntity(cargo, true, true)
    local netTimeout = GetGameTimer() + 2000
    while DoesEntityExist(cargo) and not NetworkGetEntityIsNetworked(cargo) and GetGameTimer() < netTimeout do
        NetworkRegisterEntityAsNetworked(cargo)
        Wait(25)
    end
    if not NetworkGetEntityIsNetworked(cargo) then
        DeleteEntity(cargo)
        TriggerServerEvent("fortuna_huntingwagon:restore")
        return
    end
    local cargoNetId = NetworkGetNetworkIdFromEntity(cargo)
    if cargoNetId == 0 then
        DeleteEntity(cargo)
        TriggerServerEvent("fortuna_huntingwagon:restore")
        return
    end
    spawnedCargo[cargoNetId] = cargo
    TriggerServerEvent("fortuna_huntingwagon:spawned", wagonNetId, cargoNetId)
end)

RegisterNetEvent("fortuna_huntingwagon:pickupSpawnedCargo", function(cargoNetId)
    cargoNetId = tonumber(cargoNetId)
    local cargo = spawnedCargo[cargoNetId] or NetworkGetEntityFromNetworkId(cargoNetId or 0)
    spawnedCargo[cargoNetId] = nil
    if not cargo or cargo == 0 or not DoesEntityExist(cargo) then
        TriggerEvent("fortuna_huntingwagon:notify", _U("retrieve_failed"))
        return
    end
    pickupCargo(PlayerPedId(), cargo)
    TriggerEvent("fortuna_huntingwagon:notify", _U("retrieved"))
end)

RegisterNetEvent("fortuna_huntingwagon:spawnRejected", function(cargoNetId)
    cargoNetId = tonumber(cargoNetId)
    local cargo = spawnedCargo[cargoNetId] or NetworkGetEntityFromNetworkId(cargoNetId or 0)
    spawnedCargo[cargoNetId] = nil
    if cargo and cargo ~= 0 and DoesEntityExist(cargo) and requestControl(cargo) then DeleteEntity(cargo) end
end)

exports("GetClosestHuntingWagon", function(maxDistance)
    local wagon, distance = closestHuntingWagon(GetEntityCoords(PlayerPedId()))
    if not wagon or distance > (tonumber(maxDistance) or Config.InteractionDistance) then return nil end
    return wagon, distance
end)

exports("GetCarriedHuntingCargo", function()
    local cargo = carriedByPlayer(PlayerPedId())
    if cargo and Config.Cargo[GetEntityModel(cargo)] then return cargo end
    return nil
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if storePrompt then PromptDelete(storePrompt) end
    if retrievePrompt then PromptDelete(retrievePrompt) end
    for wagon in pairs(visualTarp) do
        if DoesEntityExist(wagon) then Citizen.InvokeNative(0x31F343383F19C987, wagon, 0.02, true) end
    end
    for _, cargo in pairs(spawnedCargo) do
        if DoesEntityExist(cargo) and requestControl(cargo) then DeleteEntity(cargo) end
    end
    visualTarp = {}
    spawnedCargo = {}
end)
