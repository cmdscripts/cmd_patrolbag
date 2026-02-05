Config = {}

Config.Performance = {
    debugMode = false,
    cacheExpiry = 30000,
    modelRequestTimeout = 10000,
    bagStatusInterval = 20000,
    markerTick = 250,
    maxStashes = 5000
}

Config.Security = {
    actionCooldown = 750,
    maxAttemptsPerMinute = 30,
    maxIdentifierRange = { min = 10000, max = 99999 }
}

Config.Menu = 'points'

Config.Interaction = {
    mode = 'marker',
    key = 38,
    drawDistance = 25.0,
    markerTick = 250,
    marker = {
        type = 2,
        width = 0.35,
        height = 0.35,
        color = { r = 0, g = 153, b = 255, a = 180 },
        direction = vec3(0.0, 0.0, 0.0),
        rotation = vec3(0.0, 0.0, 0.0)
    },
    target = {
        enabled = false,
        distance = 2.0
    }
}

Config.UI = {}

Config.UI.Notify = function(title, desc, kind)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(('%s\n%s'):format(title or '', desc or ''))
    EndTextCommandThefeedPostTicker(false, false)
end

Config.UI.HelpNotify = function(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text or '')
    EndTextCommandDisplayHelp(0, false, true, -1)
end

Config.UI.HideHelpNotify = function()
    ClearAllHelpMessages()
end

Config.Text = {
    noAccess = 'Kein Zugriff',
    rateLimited = 'Bitte langsamer',
    alreadyHave = 'Du hast diese Tasche bereits',
    noSpace = 'Kein Platz im Inventar',
    issued = 'Ausgegeben',
    returned = 'Abgegeben',
    notFound = 'Nicht gefunden',
    removeFailed = 'Konnte nicht entfernt werden',
    bagInBag = 'Tasche-in-Tasche nicht erlaubt',
    onlyOneBag = 'Nur eine Tasche erlaubt'
}

Config.JobWhitelist = { 'police', 'ambulance' }

Config.Bags = {
    patrolbag = {
        label = 'Patrol Bag',
        item = 'patrolbag',
        stashPrefix = 'pbg_patrol_',
        onePerInventory = true,
        stash = { slots = 25, weight = 25000 },
        seedOnFirstOpen = true,
        seedItems = {
            { name = 'radio', count = 1 },
            { name = 'handcuffs', count = 2 },
            { name = 'bandage', count = 5 }
        }
    },

    firstaid = {
        label = 'Erste Hilfe Tasche',
        item = 'firstaid',
        stashPrefix = 'pbg_aid_',
        onePerInventory = true,
        stash = { slots = 20, weight = 20000 },
        seedOnFirstOpen = true,
        seedItems = {
            { name = 'bandage', count = 10 },
            { name = 'medikit', count = 2 }
        }
    },

    manv = {
        label = 'MANV Tasche',
        item = 'manv',
        stashPrefix = 'pbg_manv_',
        onePerInventory = true,
        stash = { slots = 40, weight = 40000 },
        seedOnFirstOpen = true,
        seedItems = {
            { name = 'bandage', count = 20 },
            { name = 'medikit', count = 6 },
            { name = 'painkillers', count = 10 }
        }
    },

    kfz_kit = {
        label = 'KFZ Verbandkasten',
        item = 'kfz_kit',
        stashPrefix = 'pbg_kfz_',
        onePerInventory = true,
        stash = { slots = 10, weight = 8000 },
        seedOnFirstOpen = true,
        seedItems = {
            { name = 'bandage', count = 2 }
        }
    }
}

Config.Points = {
    {
        id = 'pol_hq',
        label = 'Polizei Ausgabe',
        coords = vec4(441.2, -981.9, 30.7, 90.0),
        radius = 1.8,
        jobs = { police = 0 },
        bags = { 'patrolbag', 'firstaid' },
        entity = { kind = 'ped', model = 's_m_y_cop_01', offsetZ = -1.0, freeze = true, invincible = true },
        target = { enabled = false, model = 'prop_cs_cardbox_01', offsetZ = -1.0, invisible = true }
    },
    {
        id = 'ems_station',
        label = 'Rettungsdienst Ausgabe',
        coords = vec4(306.4, -601.3, 43.3, 70.0),
        radius = 1.8,
        jobs = { ambulance = 0 },
        bags = { 'manv', 'firstaid' },
        entity = { kind = 'prop', model = 'v_med_cor_emergencybox', offsetZ = -1.0, freeze = true, invincible = true },
        target = { enabled = false, model = 'prop_cs_cardbox_01', offsetZ = -1.0, invisible = true }
    },
    {
        id = 'shop_vehicle',
        label = 'KFZ Verbandkasten',
        coords = vec4(-48.2, -1757.8, 29.4, 50.0),
        radius = 1.8,
        jobs = {},
        bags = { 'kfz_kit' },
        entity = { kind = 'marker' },
        target = { enabled = false, model = 'prop_cs_cardbox_01', offsetZ = -1.0, invisible = true }
    }
}
