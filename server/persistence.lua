local function persistenceConfig()
    return type(Config.Persistence) == "table" and Config.Persistence or {}
end

local function enabled()
    return persistenceConfig().Enabled == true
end

local function database()
    return exports.oxmysql
end

local function tableName()
    local name = tostring(persistenceConfig().Table or "fortuna_huntingwagon_cargo")
    if not name:match("^[%w_]+$") then
        error("[fortuna_huntingwagon] Config.Persistence.Table contains invalid characters.")
    end
    return name
end

local function stableIdForWagon(wagon)
    if not enabled() or not DoesEntityExist(wagon) then return nil end
    local value = Entity(wagon).state[persistenceConfig().StateBagKey]
    value = tonumber(value)
    if not value or value < 1 or value % 1 ~= 0 then return nil end
    return value
end

local function sanitizeEntries(raw)
    local output, occupied = {}, 0
    if type(raw) ~= "table" then return output end
    for _, value in ipairs(raw) do
        if type(value) == "table" then
            local model = tonumber(value.model)
            local size = model and Config.Cargo[model]
            if size and occupied + size <= Config.MaxCapacity then
                local entityTypeIsPelt = value.isPelt == true
                output[#output + 1] = {
                    model = model,
                    size = size,
                    isPelt = entityTypeIsPelt,
                    quality = math.max(0, math.min(3, math.floor(tonumber(value.quality) or 0))),
                    peltQuality = math.max(-2147483648, math.min(2147483647,
                        math.floor(tonumber(value.peltQuality) or 0))),
                    skinned = value.skinned == true
                }
                occupied = occupied + size
            end
        end
    end
    return output
end

function FortunaPersistenceIsEnabled()
    return enabled()
end

function FortunaPersistenceLoad(wagon)
    if not enabled() then return nil, nil end
    local stableId = stableIdForWagon(wagon)
    if not stableId then return nil, nil end
    local row = database():single_async(("SELECT `cargo` FROM `%s` WHERE `adapter` = ? AND `wagon_id` = ? LIMIT 1")
        :format(tableName()), { persistenceConfig().Adapter, stableId })
    if not row or type(row.cargo) ~= "string" then return {}, stableId end
    local ok, decoded = pcall(json.decode, row.cargo)
    if not ok then
        print(("^1[fortuna_huntingwagon]^7 Invalid persisted cargo JSON for wagon %s; loading it empty."):format(stableId))
        return {}, stableId
    end
    return sanitizeEntries(decoded), stableId
end

function FortunaPersistenceSave(record)
    if not enabled() or not record or not record.persistenceId then return true end
    local cargo = json.encode(sanitizeEntries(record.entries))
    local query = ("INSERT INTO `%s` (`adapter`, `wagon_id`, `cargo`) VALUES (?, ?, ?) " ..
        "ON DUPLICATE KEY UPDATE `cargo` = VALUES(`cargo`), `updated_at` = CURRENT_TIMESTAMP"):format(tableName())
    local ok, result = pcall(function()
        return database():update_async(query, { persistenceConfig().Adapter, record.persistenceId, cargo })
    end)
    if not ok then
        print(("^1[fortuna_huntingwagon]^7 Persistence save failed for wagon %s: %s")
            :format(record.persistenceId, tostring(result)))
        return false
    end
    return true
end

RegisterNetEvent("fortuna_huntingwagon:registerVorpWagon", function(wagonNetId, stableId)
    if not enabled() or persistenceConfig().Adapter ~= "vorp_stables" then return end
    local src = source
    wagonNetId, stableId = tonumber(wagonNetId), tonumber(stableId)
    if not wagonNetId or not stableId or stableId < 1 or stableId % 1 ~= 0 then return end
    local wagon = NetworkGetEntityFromNetworkId(wagonNetId)
    local ped = GetPlayerPed(src)
    if wagon == 0 or ped == 0 or not DoesEntityExist(wagon) or not DoesEntityExist(ped) then return end
    if GetEntityModel(wagon) ~= Config.WagonModel or #(GetEntityCoords(ped) - GetEntityCoords(wagon)) > 60.0 then return end
    if GetResourceState("vorp_core") ~= "started" or GetResourceState("oxmysql") ~= "started" then return end

    local core = exports.vorp_core:GetCore()
    local user = core and core.getUser(src)
    local character = user and user.getUsedCharacter
    if not character then return end
    local row = database():single_async(
        "SELECT `id`, `modelname` FROM `stables` WHERE `id` = ? AND `charidentifier` = ? AND `type` = 'cart' LIMIT 1",
        { stableId, character.charIdentifier })
    if not row or joaat(row.modelname) ~= GetEntityModel(wagon) then return end
    Entity(wagon).state:set(persistenceConfig().StateBagKey, stableId, true)
    TriggerEvent("fortuna_huntingwagon:server:wagonRegistered", wagonNetId, wagon)
end)

CreateThread(function()
    if not enabled() then return end
    if GetResourceState("oxmysql") ~= "started" then
        error("[fortuna_huntingwagon] Persistence is enabled but oxmysql is not started.")
    end
    if persistenceConfig().Adapter == "vorp_stables" and GetResourceState("vorp_core") ~= "started" then
        error("[fortuna_huntingwagon] vorp_stables persistence requires vorp_core.")
    end
    tableName()
    print("^2[Fortuna Hunting Wagon]^7 database persistence enabled (^3" ..
        tostring(persistenceConfig().Adapter) .. "^7).")
end)
