## [Preview](https://streamable.com/eknoax)
## [Support](https://discord.gg/Evd7gvpTyW)

# 🧰 cmd_patrolbag

A modern, server-authoritative **multi-bag system** for FiveM using **ox_inventory**, **ox_lib**, and **ox_target**.  
Designed for modders: scalable, performant, and fully config-driven.

---

## ✨ Features

📦 **Multiple bag types**
- Unlimited bag definitions via `Config.Bags`
- Each bag has its own:
  - Item name
  - Label
  - Stash size & weight
  - Seed items
  - Behavior rules (one-per-inventory, bag-in-bag prevention)

🧑‍✈️ **NPC interaction**
- NPC-based bag management
- Take / Open / Return bags
- Dynamic menus that only show valid bag options
- Supports marker or ox_target interaction

📂 **Dedicated stash per bag**
- Unique stash per bag instance
- Automatic stash creation on first use
- Optional seed loot on first open (per bag type)

---

## 🔒 Security

- Server-side validation only
- Anti-spam & rate limiting
- Job whitelist support (e.g. police)
- Bag-in-bag exploit prevention (for all bag types)
- Optional one-bag-per-inventory per bag type
- Server-owned stash registration

---

## ⚡ Performance

- Statebag-based sync (`cmd_patrolbag:bags`)
- Minimal callbacks (fallback only)
- Cached job checks
- Periodic cleanup of:
  - Job cache
  - Cooldowns
  - Rate-limit counters
- Configurable performance limits (stash count, ticks, cache expiry)

---

## 🛠️ Config-driven

Fully configurable via `config.lua`:

- NPC model, position, and interaction mode
- Unlimited bag definitions
- Seed items per bag
- Job whitelist
- Notifications
- Security & rate limits
- Performance tuning

No code changes required to add new bag types.

---

## 🔄 Automatic State Sync

- Bag ownership synced via **statebags**
- Instant client updates on:
  - Player load
  - Item changes
  - Bag issue / return
- Reliable re-sync on reconnect and late joins

---

## 🧹 Maintenance

- Background maintenance thread:
  - Clears expired caches
  - Resets old cooldowns
  - Keeps memory usage stable

---

## ⚙️ Installation

1. Download the resource  
2. Place it in your `resources` folder  
3. Add to `server.cfg`:
   ```cfg
   ensure cmd_patrolbag
