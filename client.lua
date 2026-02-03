local resourceName = GetCurrentResourceName()
if resourceName ~= 'cmdPatrolbag' then
    print('^1 The resource must be named "cmdPatrolbag"! Current: ' .. resourceName .. '^0')
    StopResource(resourceName)
    return
end

local npc
local hasBags = {}
local lastBagCheck = 0
local statusChecker
local markerChecker
local markerDrawThread
local markerObj
local isInitialized = false
local inRange = false
local shouldDraw = false

local function debugLog(message)
    if Config.Performance.debugMode then
        print(('[PATROLBAG-CLIENT] %s'):format(message))
    end
end

local function anyBagOwned()
    for _, v in pairs(hasBags) do
        if v then return true end
    end
    return false
end

local function ownedBagKeys()
    local t = {}
    for key, def in pairs(Config.Bags) do
        if hasBags[key] then
            t[#t + 1] = { key = key, def = def }
        end
    end
    table.sort(t, function(a, b) return (a.def.label or a.key) < (b.def.label or b.key) end)
    return t
end

local function notOwnedBagKeys()
    local t = {}
    for key, def in pairs(Config.Bags) do
        if not hasBags[key] then
            t[#t + 1] = { key = key, def = def }
        end
    end
    table.sort(t, function(a, b) return (a.def.label or a.key) < (b.def.label or b.key) end)
    return t
end

local function openChooseBagContext(title, list, onPick)
    if not list or #list == 0 then return end
    local options = {}
    for i = 1, #list do
        local entry = list[i]
        options[#options + 1] = {
            title = entry.def.label or entry.key,
            icon = 'fa-solid fa-briefcase',
            onSelect = function()
                onPick(entry.key)
            end
        }
    end
    lib.registerContext({
        id = 'patrolbag_choose_bag',
        title = title,
        options = options
    })
    lib.showContext('patrolbag_choose_bag')
end

local function openNpcContext()
    local options = {}
    local canTake = notOwnedBagKeys()
    local canOpen = ownedBagKeys()
    local canReturn = ownedBagKeys()

    if #canTake > 0 then
        options[#options + 1] = {
            title = Config.Text.npcTake,
            icon = 'fa-solid fa-briefcase',
            onSelect = function()
                openChooseBagContext(Config.Text.chooseBag, canTake, function(bagKey)
                    TriggerServerEvent('cmd_patrolbag:issue', bagKey)
                end)
            end
        }
    end

    if Config.NPC.showOpenOption and #canOpen > 0 then
        options[#options + 1] = {
            title = Config.Text.npcOpen,
            icon = 'fa-solid fa-folder-open',
            onSelect = function()
                openChooseBagContext(Config.Text.chooseBag, canOpen, function(bagKey)
                    TriggerServerEvent('cmd_patrolbag:openMy', bagKey)
                end)
            end
        }
    end

    if #canReturn > 0 then
        options[#options + 1] = {
            title = Config.Text.npcReturn,
            icon = 'fa-solid fa-rotate-left',
            onSelect = function()
                openChooseBagContext(Config.Text.chooseBag, canReturn, function(bagKey)
                    TriggerServerEvent('cmd_patrolbag:return', bagKey)
                end)
            end
        }
    end

    if #options == 0 then return end

    lib.registerContext({
        id = 'patrolbag_npc_menu',
        title = Config.Text.npcTitle,
        options = options
    })

    lib.showContext('patrolbag_npc_menu')
end

local function addNpcContextTarget()
    if not npc or not DoesEntityExist(npc) then return end
    exports.ox_target:addLocalEntity(npc, {
        {
            name = 'patrolbag_context',
            icon = 'fa-solid fa-bars',
            label = Config.Text.npcMenu,
            distance = Config.NPC.distance,
            onSelect = function()
                CreateThread(function()
                    refreshHasBags(true)
                    openNpcContext()
                end)
            end
        }
    })
end

local function stopMarker()
    inRange = false
    shouldDraw = false
    lib.hideTextUI()
    markerObj = nil
    markerChecker = nil
    markerDrawThread = nil
end

local function startMarkerInteraction()
    if markerChecker or markerDrawThread then return end

    local c = Config.NPC.coords
    local coords3 = vec3(c.x, c.y, c.z)

    markerObj = lib.marker.new({
        type = Config.Marker.type,
        coords = coords3,
        width = Config.Marker.width,
        height = Config.Marker.height,
        color = Config.Marker.color,
        direction = Config.Marker.direction,
        rotation = Config.Marker.rotation
    })

    markerDrawThread = CreateThread(function()
        while isInitialized and markerObj do
            if shouldDraw then
                markerObj:draw()
                Wait(0)
            else
                Wait(Config.Performance.markerTick)
            end
        end
        markerDrawThread = nil
    end)

    markerChecker = CreateThread(function()
        while isInitialized and markerObj do
            local ped = PlayerPedId()
            local pcoords = GetEntityCoords(ped)
            local dist = #(pcoords - coords3)

            shouldDraw = dist <= Config.Marker.drawDistance

            local inside = dist <= Config.NPC.distance
            if inside ~= inRange then
                inRange = inside
                if inRange then
                    lib.showTextUI(Config.Text.markerPrompt)
                else
                    lib.hideTextUI()
                end
            end

            if inRange and IsControlJustPressed(0, 38) then
                CreateThread(function()
                    refreshHasBags(true)
                    openNpcContext()
                end)
            end

            Wait(inRange and 0 or Config.Performance.markerTick)
        end
        markerChecker = nil
    end)
end

function refreshHasBags(force)
    local now = GetGameTimer()
    if not force and (now - lastBagCheck) < Config.Performance.bagStatusInterval then
        return
    end
    lastBagCheck = now

    local state = LocalPlayer and LocalPlayer.state and LocalPlayer.state['cmd_patrolbag:bags']
    if type(state) == 'table' then
        hasBags = state
        return
    end

    local result = lib.callback.await('cmd_patrolbag:hasBags', false)
    if type(result) == 'table' then
        hasBags = result
    end
end

local function removeNpcInteractions()
    if npc and DoesEntityExist(npc) then
        exports.ox_target:removeLocalEntity(npc)
    end
    stopMarker()
end

local function applyInteractionMode()
    removeNpcInteractions()
    if not npc or not DoesEntityExist(npc) then return end

    if Config.Menu == 'target' then
        addNpcContextTarget()
        return
    end

    if Config.Menu == 'contextmenu' then
        if Config.ContextTrigger == 'target' then
            addNpcContextTarget()
        else
            startMarkerInteraction()
        end
    end
end

local function spawnNpc()
    if npc and DoesEntityExist(npc) then
        applyInteractionMode()
        return
    end

    local modelRequested = lib.requestModel(Config.NPC.model, Config.Performance.modelRequestTimeout)
    if not modelRequested then return end

    local c = Config.NPC.coords
    npc = CreatePed(4, Config.NPC.model, c.x, c.y, c.z - 1.0, c.w, false, true)
    if not DoesEntityExist(npc) then return end

    SetEntityInvincible(npc, true)
    FreezeEntityPosition(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)

    applyInteractionMode()
end

local function cleanupNpc()
    removeNpcInteractions()
    if npc and DoesEntityExist(npc) then
        DeleteEntity(npc)
        npc = nil
    end
end

local function startStatusChecker()
    if statusChecker then return end
    statusChecker = CreateThread(function()
        while isInitialized do
            Wait(Config.Performance.bagStatusInterval)
            if isInitialized then
                refreshHasBags()
            end
        end
    end)
end

local function stopStatusChecker()
    isInitialized = false
    statusChecker = nil
    markerChecker = nil
    markerDrawThread = nil
    markerObj = nil
end

local function initialize()
    if isInitialized then return end
    isInitialized = true
    refreshHasBags(true)
    Wait(500)
    spawnNpc()
    startStatusChecker()
end

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(100)
    end
    Wait(1000)
    initialize()
end)

local function boot()
    if isInitialized then return end
    while not NetworkIsSessionStarted() do Wait(100) end
    while not DoesEntityExist(PlayerPedId()) do Wait(100) end
    Wait(500)
    initialize()
end

CreateThread(boot)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    CreateThread(function()
        cleanupNpc()
        isInitialized = false
        boot()
    end)
end)


AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    stopStatusChecker()
    cleanupNpc()
end)

RegisterNetEvent('cmd_patrolbag:openClient', function(invId)
    if not invId or type(invId) ~= 'string' then return end
    exports.ox_inventory:openInventory('stash', invId)
end)

RegisterNetEvent('cmd_patrolbag:notify', function(title, description, type)
    if not title or not description then return end
    lib.notify({
        title = title,
        description = description,
        type = type or Config.Notify.type,
        position = Config.Notify.pos,
        duration = Config.Notify.ms
    })
end)

RegisterNetEvent('cmd_patrolbag:clientUse', function(slot)
    local slotToUse
    if type(slot) == 'table' and slot.slot then
        slotToUse = slot.slot
    elseif type(slot) == 'number' then
        slotToUse = slot
    else
        return
    end
    TriggerServerEvent('cmd_patrolbag:onUse', slotToUse)
end)

RegisterNetEvent('cmd_patrolbag:state', function(payload, state)
    if type(payload) == 'table' then
        hasBags = payload
        lastBagCheck = 0
        return
    end
    if type(payload) == 'string' then
        hasBags[payload] = state and true or false
        lastBagCheck = 0
        return
    end
end)

AddStateBagChangeHandler('cmd_patrolbag:bags', nil, function(_, _, value)
    if type(value) ~= 'table' then return end
    hasBags = value
    lastBagCheck = 0
end)


