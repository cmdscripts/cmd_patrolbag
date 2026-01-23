Config = {}

Config.JobWhitelist = { 'police' }

Config.Menu = 'contextmenu'
Config.ContextTrigger = 'marker'

Config.Marker = {
    type = 2,
    width = 0.35,
    height = 0.35,
    rotation = vec3(0.0, 0.0, 0.0),
    direction = vec3(0.0, 0.0, 0.0),
    color = { r = 255, g = 255, b = 255, a = 180 },
    drawDistance = 15.0
}

Config.NPC = {
    model = `s_m_y_cop_01`,
    coords = vec4(454.140656, -980.070312, 30.678345, 87.87401),
    distance = 2.0,
    showOpenOption = false
}

Config.Bags = {
    patrol = {
        label = 'Patrol Bag',
        item = 'patrolbag',
        stashPrefix = 'patrolbag:',
        stash = { slots = 50, weight = 50000 },
        onePerInventory = true,
        preventBagInBag = true,
        seedOnFirstOpen = true,
        seedItems = {
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
            { name = 'medikit', count = 1 }
        }
    },

    swat = {
        label = 'SWAT Bag',
        item = 'swatbag',
        stashPrefix = 'swatbag:',
        stash = { slots = 70, weight = 90000 },
        onePerInventory = true,
        preventBagInBag = true,
        seedOnFirstOpen = true,
        seedItems = {
            { name = 'bandage', count = 10 },
            { name = 'armor_plate', count = 8 },
            { name = 'radio', count = 1 }
        }
    }
}

Config.Notify = { type = 'inform', pos = 'top-right', ms = 4500 }

Config.Performance = {
    bagStatusInterval = 5000,
    cacheExpiry = 60000,
    maxStashes = 500,
    modelRequestTimeout = 10000,
    markerTick = 250,
    debugMode = false
}

Config.Security = {
    actionCooldown = 1000,
    maxIdentifierRange = { min = 100000, max = 999999 },
    maxAttemptsPerMinute = 10
}

Config.Text = {
    npcTitle = 'Bags',
    npcMenu = 'Menü',
    npcTake = 'Tasche empfangen',
    npcOpen = 'Tasche öffnen',
    npcReturn = 'Tasche zurückgeben',
    markerPrompt = '[E] Bag Menü',
    noAccess = 'Kein Zugriff',
    alreadyHave = 'Du hast diese Tasche bereits',
    noSpace = 'Kein Platz',
    issued = 'Ausgegeben',
    notFound = 'Du hast keine Tasche',
    returned = 'Zurückgegeben',
    removeFailed = 'Entfernen fehlgeschlagen',
    bagInBag = 'Tasche in Tasche nicht erlaubt',
    onlyOneBag = 'Nur eine Tasche erlaubt',
    cooldown = 'Die Reißverschluss klemmt',
    rateLimited = 'Die Tasche klemmt',
    chooseBag = 'Tasche auswählen'
}
