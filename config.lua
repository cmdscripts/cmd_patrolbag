Config = {}

-- Job Configuration
Config.JobWhitelist = { 'police' }

Config.Menu = 'contextmenu' -- 'target' or 'contextmenu'
Config.ContextTrigger = 'marker' -- 'marker' or 'target'

Config.Marker = {
    type = 2,
    scale = vec3(0.35, 0.35, 0.35),
    rotation = vec3(0.0, 0.0, 0.0),
    direction = vec3(0.0, 0.0, 0.0),
    color = { 255, 255, 255 },
    alpha = 180,
    bobUpAndDown = false,
    faceCamera = true,
    rotate = false,
    drawDistance = 15.0
}

-- NPC Configuration
Config.NPC = {
    model = `s_m_y_cop_01`,
    coords = vec4(454.140656, -980.070312, 30.678345, 87.87401),
    distance = 2.0,
    showOpenOption = false
}

-- Bag Configuration
Config.BagItem = 'patrolbag'
Config.BagStash = { slots = 50, weight = 50000 }
Config.OneBagInInventory = true
Config.PreventBagInBag = true

-- Seeding Configuration
Config.SeedOnFirstOpen = true
Config.SeedItems = {
            { name = 'empty_invoice_print', count = 10 },
            { name = 'roadcone', count = 10 },
            { name = 'barrier', count = 10 },
            { name = 'spikestrip', count = 5 },
            { name = 'zipties', count = 5 },
            { name = 'sidecutter', count = 2 },
            { name = 'elastic_bandage', count = 10 },
            { name = 'tourniquet', count = 5 },
            { name = 'armor_plate', count = 4 },
            { name = 'evidence_bag', count = 10 },
            { name = 'evidence_cleaner', count = 5 },
            { name = 'breathalyzer', count = 1 },
            { name = 'radio', count = 1 },
            { name = 'bandage', count = 1 },
            { name = 'medikit', count = 1 },
            
}

-- Notification Configuration
Config.Notify = { type = 'inform', pos = 'top-right', ms = 4500 }

-- Performance Configuration
Config.Performance = {
    bagStatusInterval = 5000, -- ms - How often to check bag status
    cacheExpiry = 60000, -- ms - How long to cache job checks
    maxStashes = 500, -- Maximum number of stashes to keep in memory
    modelRequestTimeout = 10000, -- ms - Timeout for model requests
    debugMode = false -- Enable debug logging
}

-- Security Configuration
Config.Security = {
    actionCooldown = 1000, -- ms - Cooldown between actions
    maxIdentifierRange = { min = 100000, max = 999999 }, -- Range for bag IDs
    maxAttemptsPerMinute = 10 -- Max actions per player per minute
}

-- Text Configuration (easier for translation)
Config.Text = {
    npcTake = 'Patrolbag empfangen',
    npcOpen = 'Patrolbag öffnen', 
    npcReturn = 'Patrolbag zurückgeben',
    noAccess = 'Kein Zugriff',
    alreadyHave = 'Du hast bereits eine Tasche',
    noSpace = 'Kein Platz',
    issued = 'Ausgegeben',
    notFound = 'Du hast keine Tasche',
    returned = 'Zurückgegeben',
    removeFailed = 'Entfernen fehlgeschlagen',
    bagInBag = 'Tasche in Tasche nicht erlaubt',
    onlyOneBag = 'Nur eine Tasche erlaubt',
    cooldown = 'Die Reißverschluss klemmt',
    rateLimited = 'Die Tasche klemmt'
}
