
local queue = {}
local supportedKinds = { store = true, retrieve = true, security = true }

local function clean(value, limit)
    value = tostring(value or _U("unknown")):gsub("[`@]", "")
    return value:sub(1, limit or 1000)
end

local function primaryIdentifier(source)
    local identifiers = GetPlayerIdentifiers(tonumber(source) or -1)
    for _, identifier in ipairs(identifiers) do
        if identifier:sub(1, 8) == "license:" then return identifier end
    end
    return identifiers[1] or _U("unknown")
end

local function webhookUrl()
    local convar = GetConvar("fortuna_huntingwagon_webhook", "")
    return convar ~= "" and convar or Config.Discord.Webhook
end

local function request(url, payload)
    local result = promise.new()
    PerformHttpRequest(url, function(status, body, headers)
        result:resolve({ status = tonumber(status) or 0, body = body or "", headers = headers or {} })
    end, "POST", json.encode(payload), { ["Content-Type"] = "application/json" })
    return Citizen.Await(result)
end

local function retryDelay(response, attempt)
    if response.status == 429 then
        local ok, decoded = pcall(json.decode, response.body)
        local value = ok and type(decoded) == "table" and tonumber(decoded.retry_after) or nil
        if value then
            if value < 100 then value = value * 1000 end
            return math.max(500, math.min(30000, math.ceil(value)))
        end
    end
    return math.min(10000, 500 * (2 ^ attempt))
end

CreateThread(function()
    while true do
        local item = table.remove(queue, 1)
        if not item then
            Wait(500)
        else
            local delivered = false
            for attempt = 0, Config.Discord.MaxRetries do
                local response = request(item.url, item.payload)
                if response.status >= 200 and response.status < 300 then
                    delivered = true
                    break
                end
                if attempt < Config.Discord.MaxRetries then Wait(retryDelay(response, attempt)) end
            end
            if Config.Debug and not delivered then
                print("[fortuna_huntingwagon] Discord log dropped after all retry attempts.")
            end
            Wait(Config.Discord.DelayBetweenMessages)
        end
    end
end)

function FortunaDiscordLog(kind, source, data)
    if not Config.Discord.Enabled or not supportedKinds[kind] then return false end
    if kind == "store" and not Config.Discord.LogStore then return false end
    if kind == "retrieve" and not Config.Discord.LogRetrieve then return false end
    if kind == "security" and not Config.Discord.LogSecurityWarnings then return false end
    local url = webhookUrl()
    if url == "" then
        if Config.Debug then print("[fortuna_huntingwagon] Discord logging is enabled without a webhook.") end
        return false
    end
    if #queue >= Config.Discord.QueueLimit then
        if Config.Debug then print("[fortuna_huntingwagon] Discord queue is full; newest log was discarded.") end
        return false
    end

    source = tonumber(source) or -1
    data = type(data) == "table" and data or {}
    local titleKey = kind == "security" and "log_security_title" or (kind == "retrieve" and "log_retrieve_title" or "log_store_title")
    local descriptionKey = kind == "retrieve" and "log_retrieve_description" or "log_store_description"
    local fields = {
        { name = _U("field_player"), value = clean((GetPlayerName(source) or _U("unknown")) .. " (ID " .. source .. ")"), inline = true },
        { name = _U("field_identifier"), value = "`" .. clean(primaryIdentifier(source), 200) .. "`", inline = true }
    }
    if kind == "security" then
        fields[#fields + 1] = { name = _U("field_reason"), value = clean(_U(data.reason or "reason_invalid_store")), inline = false }
    else
        fields[#fields + 1] = {
            name = _U("field_cargo"),
            value = (data.isPelt and "🧶 " .. _U("cargo_pelt") or "🦌 " .. _U("cargo_carcass")) .. "\n`" .. clean(data.model, 50) .. "`",
            inline = true
        }
        fields[#fields + 1] = { name = _U("field_wagon"), value = "`#" .. clean(data.wagonId, 30) .. "`", inline = true }
        fields[#fields + 1] = { name = _U("field_capacity"), value = ("**%s / %s**"):format(clean(data.capacity, 10), Config.MaxCapacity), inline = true }
    end
    if data.coords and tonumber(data.coords.x) and tonumber(data.coords.y) and tonumber(data.coords.z) then
        fields[#fields + 1] = {
            name = _U("field_position"),
            value = ("`%.2f, %.2f, %.2f`"):format(data.coords.x, data.coords.y, data.coords.z),
            inline = false
        }
    end

    local roleId = ""
    if kind == "security" then roleId = tostring(Config.Discord.MentionOnSecurityWarning):gsub("%D", "") end
    local embed = {
        author = { name = Config.Project.Name, url = Config.Project.Documentation },
        title = _U(titleKey),
        description = kind == "security" and "🔒 " .. _U(data.reason or "reason_invalid_store") or _U(descriptionKey),
        color = Config.Discord.Colors[kind],
        fields = fields,
        footer = { text = "Fortuna Hunting Wagon • by pichirin_cb • discord.gg/hsx6AvBg5s" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    if Config.Discord.FooterIconUrl ~= "" then embed.footer.icon_url = Config.Discord.FooterIconUrl end
    if Config.Discord.AvatarUrl ~= "" then embed.thumbnail = { url = Config.Discord.AvatarUrl } end

    local payload = {
        username = Config.Discord.BotName,
        content = roleId ~= "" and "<@&" .. roleId .. ">" or "",
        allowed_mentions = { parse = {}, roles = roleId ~= "" and { roleId } or {} },
        embeds = { embed }
    }
    if Config.Discord.AvatarUrl ~= "" then payload.avatar_url = Config.Discord.AvatarUrl end
    queue[#queue + 1] = { url = url, payload = payload }
    return true
end

exports("SendDiscordLog", FortunaDiscordLog)
