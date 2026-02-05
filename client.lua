local resourceName = GetCurrentResourceName()
if resourceName ~= 'cmdPatrolbag' then
    print('^1[SECURITY] The resource must be named "cmdPatrolbag"! Current: ' .. resourceName .. '^0')
    StopResource(resourceName)
    return
end

local hasBags = {}
local lastBagCheck = 0
local spawned = {}
local activeHelp = false

local function refreshHasBags(force)
    local now = GetGameTimer()
    local interval = (Config.Performance and Config.Performance.bagStatusInterval) or 60000
    if not force and (now - lastBagCheck) < interval then return end
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

local function spawnPointEntity(point)
    local e = point.entity
    if not e or e.kind == 'marker' then return end
    if spawned[point.id] and DoesEntityExist(spawned[point.id]) then return end

    lib.requestModel(e.model, (Config.Performance and Config.Performance.modelRequestTimeout) or 10000)
    local c = point.coords

    if e.kind == 'ped' then
        local ped = CreatePed(4, e.model, c.x, c.y, c.z + (e.offsetZ or 0.0), c.w, false, true)
        if not DoesEntityExist(ped) then return end
        if e.invincible then SetEntityInvincible(ped, true) end
        if e.freeze then FreezeEntityPosition(ped, true) end
        SetBlockingOfNonTemporaryEvents(ped, true)
        spawned[point.id] = ped
        return
    end

    if e.kind == 'prop' then
        local obj = CreateObject(e.model, c.x, c.y, c.z + (e.offsetZ or 0.0), false, false, false)
        if not DoesEntityExist(obj) then return end
        SetEntityHeading(obj, c.w)
        if e.invincible then SetEntityInvincible(obj, true) end
        if e.freeze then FreezeEntityPosition(obj, true) end
        spawned[point.id] = obj
    end
end

local function ensureTargetEntity(point)
    if not Config.Interaction.target.enabled then return end
    if not point.target or not point.target.enabled then return end
    if spawned['t_' .. point.id] and DoesEntityExist(spawned['t_' .. point.id]) then return end
    if GetResourceState('ox_target') ~= 'started' then return end

    lib.requestModel(point.target.model, (Config.Performance and Config.Performance.modelRequestTimeout) or 10000)
    local c = point.coords
    local obj = CreateObject(point.target.model, c.x, c.y, c.z + (point.target.offsetZ or 0.0), false, false, false)
    if not DoesEntityExist(obj) then return end

    SetEntityHeading(obj, c.w)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)

    if point.target.invisible then
        SetEntityAlpha(obj, 0, false)
        SetEntityCollision(obj, false, false)
    end

    spawned['t_' .. point.id] = obj

    exports.ox_target:addLocalEntity(obj, {
        {
            name = 'patrolbag_point_' .. point.id,
            icon = 'fa-solid fa-briefcase',
            label = point.label,
            distance = Config.Interaction.target.distance,
            onSelect = function()
                refreshHasBags(true)
                TriggerEvent('cmd_patrolbag:openPoint', point.id)
            end
        }
    })
end

local function buildSubMenu(id, title, bagKeys, predicate, onPick)
    local options = {}
    for i = 1, #bagKeys do
        local k = bagKeys[i]
        local def = Config.Bags[k]
        if def and predicate(k) then
            options[#options + 1] = {
                title = def.label or k,
                icon = 'fa-solid fa-briefcase',
                onSelect = function()
                    onPick(k)
                end
            }
        end
    end
    if #options == 0 then
        Config.UI.Notify(title, 'Nichts verfügbar', 'error')
        return false
    end
    lib.registerContext({ id = id, title = title, options = options })
    lib.showContext(id)
    return true
end

RegisterNetEvent('cmd_patrolbag:openPoint', function(pointId)
    if type(pointId) ~= 'string' then return end
    local res = lib.callback.await('cmd_patrolbag:getPointMenu', false, pointId)
    if not res then return end
    if res.ok ~= true then
        if res.msg then Config.UI.Notify('Bags', res.msg, 'error') end
        return
    end

    local title = res.title or 'Bags'
    local keys = res.bags or {}

    local options = {
        {
            title = 'Tasche entnehmen',
            icon = 'fa-solid fa-plus',
            onSelect = function()
                buildSubMenu('patrolbag_take_' .. pointId, title, keys, function(k) return not hasBags[k] end, function(k)
                    lib.callback.await('cmd_patrolbag:issueFromPoint', false, pointId, k)
                    refreshHasBags(true)
                end)
            end
        },
        {
            title = 'Tasche öffnen',
            icon = 'fa-solid fa-folder-open',
            onSelect = function()
                buildSubMenu('patrolbag_open_' .. pointId, title, keys, function(k) return hasBags[k] end, function(k)
                    lib.callback.await('cmd_patrolbag:openFromPoint', false, pointId, k)
                end)
            end
        },
        {
            title = 'Tasche abgeben',
            icon = 'fa-solid fa-rotate-left',
            onSelect = function()
                buildSubMenu('patrolbag_ret_' .. pointId, title, keys, function(k) return hasBags[k] end, function(k)
                    lib.callback.await('cmd_patrolbag:returnFromPoint', false, pointId, k)
                    refreshHasBags(true)
                end)
            end
        }
    }

    lib.registerContext({ id = 'patrolbag_point_' .. pointId, title = title, options = options })
    lib.showContext('patrolbag_point_' .. pointId)
end)

local function boot()
    while not NetworkIsSessionStarted() do Wait(100) end
    while not DoesEntityExist(PlayerPedId()) do Wait(100) end
    refreshHasBags(true)

    for i = 1, #Config.Points do
        local p = Config.Points[i]
        spawnPointEntity(p)
        ensureTargetEntity(p)

        local pos = vec3(p.coords.x, p.coords.y, p.coords.z)
        lib.zones.sphere({
            coords = pos,
            radius = p.radius or 2.0,
            onEnter = function()
                if Config.Interaction.mode == 'marker' then
                    activeHelp = true
                    Config.UI.HelpNotify('Drücke ~INPUT_CONTEXT~ um zu interagieren')
                end
            end,
            onExit = function()
                if activeHelp then
                    activeHelp = false
                    Config.UI.HideHelpNotify()
                end
            end,
            inside = function()
                if Config.Interaction.mode ~= 'marker' then
                    Wait((Config.Interaction.markerTick or 250))
                    return
                end

                local ped = PlayerPedId()
                local pc = GetEntityCoords(ped)
                local dist = #(pc - pos)

                if dist <= (Config.Interaction.drawDistance or 25.0) then
                    local m = Config.Interaction.marker
                    DrawMarker(m.type, pos.x, pos.y, pos.z, m.direction.x, m.direction.y, m.direction.z, m.rotation.x, m.rotation.y, m.rotation.z, m.width, m.width, m.height, m.color.r, m.color.g, m.color.b, m.color.a, false, true, 2, nil, nil, false)
                end

                if IsControlJustPressed(0, Config.Interaction.key or 38) then
                    refreshHasBags(true)
                    TriggerEvent('cmd_patrolbag:openPoint', p.id)
                end

                Wait(0)
            end
        })
    end
end

CreateThread(boot)

RegisterNetEvent('cmd_patrolbag:openClient', function(invId)
    if not invId or type(invId) ~= 'string' then return end
    exports.ox_inventory:openInventory('stash', invId)
end)

exports('useBag', function(data, slot)
    if not slot or not slot.slot then return end
    TriggerServerEvent('cmd_patrolbag:onUse', slot.slot)
end)

RegisterNetEvent('cmd_patrolbag:notify', function(title, description, kind)
    Config.UI.Notify(title, description, kind)
end)

AddStateBagChangeHandler('cmd_patrolbag:bags', nil, function(_, _, value)
    if type(value) ~= 'table' then return end
    hasBags = value
    lastBagCheck = 0
end)
