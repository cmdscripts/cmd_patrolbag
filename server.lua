local resourceName = GetCurrentResourceName()
if resourceName ~= 'cmdPatrolbag' then
    print('^1[SECURITY] The resource must be named "cmd_patrolbag"! Current: ' .. resourceName .. '^0')
    StopResource(resourceName)
    return
end

local ESX = exports.es_extended:getSharedObject()
local ox = exports.ox_inventory
local registered = {}
local jobCache = {}
local playerCooldowns = {}
local playerActionCounts = {}

local function debugLog(message, ...)
    if Config.Performance.debugMode then
        print(('[PATROLBAG-SERVER] ' .. message):format(...))
    end
end

local function notify(src, title, desc, kind)
    if not src or not title or not desc then
        return
    end
    TriggerClientEvent('cmd_patrolbag:notify', src, title, desc, kind or 'inform')
end

local function isRateLimited(src)
    local now = GetGameTimer()
    local cooldown = playerCooldowns[src]
    if cooldown and (now - cooldown) < Config.Security.actionCooldown then
        return true
    end
    local minute = math.floor(now / 60000)
    local key = src .. '_' .. minute
    local count = playerActionCounts[key] or 0
    if count >= Config.Security.maxAttemptsPerMinute then
        return true
    end
    playerCooldowns[src] = now
    playerActionCounts[key] = count + 1
    return false
end

local function hasJob(src)
    local now = GetGameTimer()
    local cached = jobCache[src]
    if cached and (now - cached.timestamp) < Config.Performance.cacheExpiry then
        return cached.hasJob
    end
    local player = ESX.GetPlayerFromId(src)
    if not player then
        return false
    end
    local job = player.getJob()
    if not job then
        return false
    end
    local ok = false
    for _, jobName in ipairs(Config.JobWhitelist) do
        if jobName == job.name then
            ok = true
            break
        end
    end
    jobCache[src] = { hasJob = ok, timestamp = now }
    return ok
end

local function getBagDef(bagKey)
    if type(bagKey) ~= 'string' then return end
    return Config.Bags and Config.Bags[bagKey]
end

local function getAllBagItemFilter()
    local t = {}
    for key, def in pairs(Config.Bags) do
        if def and def.item then
            t[def.item] = true
        end
    end
    return t
end

local function getAllStashPrefixes()
    local t = {}
    for _, def in pairs(Config.Bags) do
        if def and def.stashPrefix then
            t[#t + 1] = def.stashPrefix
        end
    end
    return t
end

local function buildBagState(src)
    local state = {}
    for key, def in pairs(Config.Bags) do
        local ok, count = pcall(function()
            return ox:GetItem(src, def.item, nil, true) or 0
        end)
        state[key] = ok and (count > 0) or false
    end
    return state
end

local function pushBagState(src, state)
    if type(state) ~= 'table' then state = buildBagState(src) end
    local p = Player(src)
    if p and p.state then
        p.state:set('cmd_patrolbag:bags', state, true)
    end
    TriggerClientEvent('cmd_patrolbag:state', src, state)
    return state
end

local function ensureStash(invId, label, owner, stashCfg)
    if registered[invId] then return true end
    local stashCount = 0
    for _ in pairs(registered) do stashCount = stashCount + 1 end
    if stashCount >= Config.Performance.maxStashes then
        return false
    end
    local success, err = pcall(function()
        ox:RegisterStash(invId, label, stashCfg.slots, stashCfg.weight, owner or false)
    end)
    if success then
        registered[invId] = { label = label, owner = owner, created = os.time() }
        return true
    else
        debugLog('Failed to register stash %s: %s', invId, tostring(err))
        return false
    end
end

local function seed(invId, bagDef)
    if not bagDef.seedOnFirstOpen then return true end
    local items = bagDef.seedItems
    if type(items) ~= 'table' then return true end
    local success = pcall(function()
        for i = 1, #items do
            local it = items[i]
            local count = (it and it.count) or 1
            if count > 0 then
                ox:AddItem(invId, it.name, count)
            end
        end
    end)
    return success
end

local function generateIdentifier()
    local min, max = Config.Security.maxIdentifierRange.min, Config.Security.maxIdentifierRange.max
    return ('PBG-%d'):format(math.random(min, max))
end

local function findBagSlot(src, bagDef)
    local ok, slots = pcall(function()
        return ox:Search(src, 'slots', bagDef.item)
    end)
    if not ok or not slots then
        return nil
    end
    if type(slots) == 'table' then
        for _, slot in pairs(slots) do
            if slot and slot.name == bagDef.item then
                return slot
            end
        end
    end
    return nil
end

lib.callback.register('cmd_patrolbag:hasBags', function(src)
    local state = buildBagState(src)
    pushBagState(src, state)
    return state
end)

RegisterNetEvent('cmd_patrolbag:issue', function(bagKey)
    local src = source
    if isRateLimited(src) then
        notify(src, 'Bags', Config.Text.rateLimited, 'error')
        return
    end
    if not hasJob(src) then
        notify(src, 'Bags', Config.Text.noAccess, 'error')
        return
    end

    local bagDef = getBagDef(bagKey)
    if not bagDef then return end

    if bagDef.onePerInventory then
        local ok, count = pcall(function()
            return ox:GetItem(src, bagDef.item, nil, true) or 0
        end)
        if not ok then
            notify(src, bagDef.label or 'Bag', 'Fehler beim Prüfen der Taschen', 'error')
            return
        end
        if count >= 1 then
            notify(src, bagDef.label or 'Bag', Config.Text.alreadyHave, 'error')
            return
        end
    end

    local ok, result = pcall(function()
        return ox:AddItem(src, bagDef.item, 1, { bagKey = bagKey })
    end)
    if not ok or not result then
        notify(src, bagDef.label or 'Bag', Config.Text.noSpace, 'error')
        return
    end

    local state = buildBagState(src)
    pushBagState(src, state)
    notify(src, bagDef.label or 'Bag', Config.Text.issued, 'success')
end)

RegisterNetEvent('cmd_patrolbag:onUse', function(slot)
    local src = source
    if isRateLimited(src) then
        notify(src, 'Bags', Config.Text.rateLimited, 'error')
        return
    end
    if type(slot) ~= 'number' or slot < 1 then
        return
    end

    local ok, slotData = pcall(function()
        return ox:GetSlot(src, slot)
    end)
    if not ok or not slotData or not slotData.name then
        return
    end

    local bagKey
    local meta = slotData.metadata or {}
    if type(meta.bagKey) == 'string' then
        bagKey = meta.bagKey
        goto bagkey_ok
    end

    for k, def in pairs(Config.Bags) do
        if def.item == slotData.name then
            bagKey = k
            break
        end
    end

    ::bagkey_ok::
    local bagDef = bagKey and getBagDef(bagKey)
    if not bagDef then
        return
    end

    if not meta.identifier then
        meta.identifier = generateIdentifier()
    end

    local invId = meta.invId or (bagDef.stashPrefix .. meta.identifier)
    local label = ('%s [%s]'):format(bagDef.label or 'Bag', meta.identifier)
    local player = ESX.GetPlayerFromId(src)
    local owner = player and player.getIdentifier() or true

    if not ensureStash(invId, label, owner, bagDef.stash) then
        notify(src, bagDef.label or 'Bag', 'Fehler beim Erstellen der Tasche', 'error')
        return
    end

    if not meta.seeded then
        if seed(invId, bagDef) then
            meta.seeded = true
        else
            notify(src, bagDef.label or 'Bag', 'Fehler beim Füllen der Tasche', 'error')
            return
        end
    end

    meta.invId = invId
    meta.bagKey = bagKey
    meta.lastUsed = os.time()

    local updateOk = pcall(function()
        ox:SetMetadata(src, slotData.slot, meta)
    end)
    if not updateOk then
        notify(src, bagDef.label or 'Bag', 'Fehler beim Aktualisieren', 'error')
        return
    end

    TriggerClientEvent('cmd_patrolbag:openClient', src, invId)
end)

RegisterNetEvent('cmd_patrolbag:openMy', function(bagKey)
    local src = source
    if isRateLimited(src) then
        notify(src, 'Bags', Config.Text.rateLimited, 'error')
        return
    end
    if not hasJob(src) then
        notify(src, 'Bags', Config.Text.noAccess, 'error')
        return
    end

    local bagDef = getBagDef(bagKey)
    if not bagDef then return end

    local slot = findBagSlot(src, bagDef)
    if not slot then
        notify(src, bagDef.label or 'Bag', Config.Text.notFound, 'error')
        return
    end

    local meta = slot.metadata or {}
    if not meta.identifier then
        meta.identifier = generateIdentifier()
    end

    local invId = meta.invId or (bagDef.stashPrefix .. meta.identifier)
    local label = ('%s [%s]'):format(bagDef.label or 'Bag', meta.identifier)
    local player = ESX.GetPlayerFromId(src)
    local owner = player and player.getIdentifier() or true

    if not ensureStash(invId, label, owner, bagDef.stash) then
        notify(src, bagDef.label or 'Bag', 'Fehler beim Öffnen', 'error')
        return
    end

    meta.invId = invId
    meta.bagKey = bagKey
    meta.lastUsed = os.time()

    local metaOk = pcall(function()
        ox:SetMetadata(src, slot.slot, meta)
    end)
    if not metaOk then
        notify(src, bagDef.label or 'Bag', 'Fehler beim Aktualisieren', 'error')
        return
    end

    TriggerClientEvent('cmd_patrolbag:openClient', src, invId)
end)

RegisterNetEvent('cmd_patrolbag:return', function(bagKey)
    local src = source
    if isRateLimited(src) then
        notify(src, 'Bags', Config.Text.rateLimited, 'error')
        return
    end

    local bagDef = getBagDef(bagKey)
    if not bagDef then return end

    local slot = findBagSlot(src, bagDef)
    if not slot then
        notify(src, bagDef.label or 'Bag', Config.Text.notFound, 'error')
        return
    end

    local meta = slot.metadata or {}
    if meta.invId then
        pcall(function()
            ox:ClearInventory(meta.invId)
        end)
    end

    local removed = pcall(function()
        return ox:RemoveItem(src, slot.name, 1, slot.metadata, slot.slot)
    end)
    if not removed then
        removed = pcall(function()
            return ox:RemoveItem(src, slot.name, 1, nil, slot.slot)
        end)
    end

    if removed then
        local state = buildBagState(src)
        pushBagState(src, state)
        notify(src, bagDef.label or 'Bag', Config.Text.returned, 'success')
    else
        notify(src, bagDef.label or 'Bag', Config.Text.removeFailed, 'error')
    end
end)

CreateThread(function()
    while true do
        Wait(300000)
        local now = GetGameTimer()
        for src, data in pairs(jobCache) do
            if (now - data.timestamp) > Config.Performance.cacheExpiry * 2 then
                jobCache[src] = nil
            end
        end
        local currentMinute = math.floor(now / 60000)
        for key in pairs(playerActionCounts) do
            local minute = tonumber(key:match('_(%d+)$'))
            if minute and (currentMinute - minute) > 5 then
                playerActionCounts[key] = nil
            end
        end
        for src, timestamp in pairs(playerCooldowns) do
            if (now - timestamp) > 60000 then
                playerCooldowns[src] = nil
            end
        end
    end
end)

CreateThread(function()
    while GetResourceState('ox_inventory') ~= 'started' do
        Wait(250)
    end

    local itemFilter = getAllBagItemFilter()
    local prefixes = getAllStashPrefixes()

    ox:registerHook('swapItems', function(payload)
        local dest = payload.toInventory
        if type(dest) ~= 'string' then return true end

        for i = 1, #prefixes do
            if dest:find(prefixes[i], 1, true) then
                notify(payload.source, 'Bags', Config.Text.bagInBag, 'error')
                return false
            end
        end
        return true
    end, { print = false, itemFilter = itemFilter })

    ox:registerHook('createItem', function(payload)
        local inv = payload.inventoryId
        if type(inv) ~= 'number' and type(inv) ~= 'string' then return end

        local createdName = payload.name
        local bagKey
        for k, def in pairs(Config.Bags) do
            if def.item == createdName then
                bagKey = k
                break
            end
        end
        if not bagKey then return end

        local bagDef = Config.Bags[bagKey]
        if not bagDef.onePerInventory then return end

        local ok, count = pcall(function()
            return ox:GetItem(inv, createdName, nil, true) or 0
        end)
        if not ok or count <= 1 then return end

        CreateThread(function()
            Wait(100)
            local items = ox:GetInventoryItems(inv) or {}
            for _, item in pairs(items) do
                if item.name == createdName and item.slot == payload.slot then
                    ox:RemoveItem(inv, item.name, 1, nil, item.slot)
                    notify(inv, bagDef.label or 'Bag', Config.Text.onlyOneBag, 'error')
                    break
                end
            end
        end)
    end, { print = false, itemFilter = itemFilter })
end)

AddEventHandler('esx:playerLoaded', function(src)
    CreateThread(function()
        Wait(1500)
        pushBagState(src)
    end)
end)

AddEventHandler('playerJoining', function(src)
    CreateThread(function()
        Wait(5000)
        pushBagState(src)
    end)
end)

