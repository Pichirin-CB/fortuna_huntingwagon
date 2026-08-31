
██████╗ ███████╗ █████╗ ██████╗ ███╗   ███╗███████╗ 
██╔══██╗██╔════╝██╔══██╗██╔══██╗████╗ ████║██╔════╝ 
██████╔╝█████╗  ███████║██║  ██║██╔████╔██║█████╗   
██╔══██╗██╔══╝  ██╔══██║██║  ██║██║╚██╔╝██║██╔══╝   
██║  ██║███████╗██║  ██║██████╔╝██║ ╚═╝ ██║███████╗ 
╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚═╝     ╚═╝╚══════╝ 
---------------------------------------------------------------------------

# Fortuna Hunting Wagon — Technical Documentation

| Field | Information |
| --- | --- |
| Resource | `fortuna_huntingwagon` |
| Version | `2.2.0` |
| Author | `pichirin_cb` / CB Studios |
| Platform | RedM |
| Type | Standalone script |
| Framework | Standalone; optional VORP notifications |
| License | GPL-3.0-or-later |

[Store](https://pichirin-cb.tebex.io/) · [Documentation](https://docs.pichirincb.com/#/) · [Support Discord](https://discord.gg/hsx6AvBg5s)

---------------------------------------------------------------------------

# Resource Overview

Fortuna Hunting Wagon provides secure and immersive hunting cargo storage for the native RedM `huntercart01`. Players can store supported dead animals and carriable pelts, retrieve them safely and see the wagon's native tarp react to its occupied capacity.

The resource is server-authoritative and requires no database, targeting system, UI library or mandatory framework in its default mode. Optional `oxmysql` persistence can retain cargo across restarts for verified `vorp_stables` wagons.

## Main features

- Server-side validation of wagon, cargo model, entity type, distance, health and capacity.
- Anti-duplication retrieval flow with reserved cargo and automatic recovery.
- Support for carried pelts and nearby large carcasses that cannot normally be lifted.
- Native hunting-wagon tarp visualization without fake sellable entities.
- Restoration of pelt quality, carcass quality and skinned state after retrieval.
- Configurable public, ACE, state-bag or custom wagon access.
- English, Portuguese, French, German, Spanish and Romanian locales.
- Localized Discord embeds for storage, retrieval and security rejections.
- Public client/server exports and server events for integrations.
- VORP, chat and custom notification adapters with automatic fallback.

---------------------------------------------------------------------------

# Resource Structure

```text
fortuna_huntingwagon/
├── client/
│   └── main.lua
├── server/
│   ├── discord.lua
│   ├── persistence.lua
│   └── main.lua
├── shared/
│   ├── config.lua
│   └── shared.lua
├── locales/
│   ├── de.lua
│   ├── en.lua
│   ├── es.lua
│   ├── fr.lua
│   ├── pt.lua
│   └── ro.lua
├── INSTALL_FILES/
│   └── fortuna_huntingwagon.sql
├── fxmanifest.lua
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── README.md
└── SECURITY.md
```

Do not rename internal files. If the resource folder is renamed, update every `ensure`, export and integration reference that uses `fortuna_huntingwagon`.

---------------------------------------------------------------------------

# Installation

1. Download or clone the repository.
2. Keep the folder named `fortuna_huntingwagon`.
3. Place it in the resources directory:

   ```text
   resources/[standalone]/fortuna_huntingwagon
   ```

4. Add it to `server.cfg` after the resource that creates or sells the wagon:

   ```cfg
   ensure vorp_stables
   ensure fortuna_huntingwagon
   ```

5. Review `shared/config.lua` before starting the resource.
6. Restart the server, or run `restart fortuna_huntingwagon`.

No SQL import is required for the default session-only mode. See **Optional Persistence** below to retain cargo across restarts.

---------------------------------------------------------------------------

# Configuration

The configuration file is `shared/config.lua`.

## General settings

```lua
Config.Locale = "es" -- en, pt, fr, de, es, ro
Config.Debug = false
Config.WagonModel = `huntercart01`
Config.MaxCapacity = 14
Config.InteractionDistance = 1.65
Config.PlayerValidationDistance = 2.75
Config.CargoValidationDistance = 3.25
Config.GroundCargoDistance = 2.0
Config.Control = 0xE30CD707 -- R
```

`Config.Cargo` maps supported model hashes to capacity units based on physical volume and carry form. Under-arm or rolled pelts use 1 unit, flat or large pelts use 2, and extra-large pelts use 3. Animal carcasses use between 1 and 4 units from tiny to extra-large. With the default capacity of 14, the wagon accepts any combination whose total does not exceed 14 units.

```lua
Config.Cargo[`a_c_example_01`] = 2
```

Unsupported entities are rejected by the server. Invalid capacities, distances, access modes and Discord settings stop the resource with a clear console error.

## Notifications

```lua
Config.Notification.System = "auto" -- auto, vorp, chat, custom
Config.Notification.CustomEvent = ""
```

`auto` uses VORP when `vorp_core` is running, then `chat`, and finally the client console. A custom event receives `(message, duration)`:

```lua
Config.Notification.System = "custom"
Config.Notification.CustomEvent = "my_notifications:show"
```

## Wagon access

```lua
Config.Access.Mode = "public"   -- Everyone nearby
Config.Access.Mode = "ace"      -- ACE permission
Config.Access.Mode = "statebag" -- Owner stored in the wagon state bag
```

ACE example:

```cfg
add_ace group.hunter fortuna_huntingwagon.use allow
```

Custom ownership check:

```lua
Config.Access.CustomCheck = function(source, wagon)
    return exports.my_stable:CanUseWagon(source, NetworkGetNetworkIdFromEntity(wagon))
end
```

When `CustomCheck` is a function, it takes priority over `Config.Access.Mode`.

## Discord logs

Enable logging in `shared/config.lua`:

```lua
Config.Discord.Enabled = true
```

Store the webhook securely in `server.cfg`:

```cfg
set fortuna_huntingwagon_webhook "https://discord.com/api/webhooks/ID/TOKEN"
```

The convar takes priority over the configuration value. Never publish a real webhook. Embeds use the selected locale and include human-readable fields, emoji, a UTC timestamp and the `by pichirin_cb` attribution footer.

## Optional Persistence

Persistence is disabled by default, preserving standalone operation. To enable it with `vorp_stables`:

1. Import `INSTALL_FILES/fortuna_huntingwagon.sql` into the database used by `oxmysql`.
2. Start the resources in this order:

   ```cfg
   ensure oxmysql
   ensure vorp_core
   ensure vorp_stables
   ensure fortuna_huntingwagon
   ```

3. Enable it in `shared/config.lua`:

   ```lua
   Config.Persistence.Enabled = true
   Config.Persistence.Adapter = "vorp_stables"
   Config.Persistence.RequireRegisteredWagon = true
   ```

The included VORP bridge registers each spawned `huntercart01` with its permanent `stables.id`. The server verifies the model, distance, character ownership and database row before accepting the ID. Network IDs are never used as persistent database keys.

Persisted JSON is sanitized on load and every cargo size is recalculated from the current `Config.Cargo`, preventing outdated data from bypassing capacity balance changes.

---------------------------------------------------------------------------

# Dependencies

Required:

- A current RedM server artifact.
- OneSync and state bags.
- A resource that spawns or sells `huntercart01`.

Optional:

- `vorp_core` for VORP notifications.
- `chat` as a notification fallback.
- A hunting resource for selling retrieved animals or pelts.

Session-only mode imports no VORP APIs and requires no SQL database. Persistence mode requires `oxmysql`, `vorp_core`, the included SQL table and the `vorp_stables` bridge.

---------------------------------------------------------------------------

# Compatibility

| Component | Status |
| --- | --- |
| RedM | Required |
| Standalone | Supported |
| VORP | Optional notification integration |
| Custom stable systems | Supported through `Config.Access.CustomCheck` |
| Custom notifications | Supported through an event adapter |
| FiveM/GTA V | Not supported |

The resource was designed around the native RedM hunting wagon and tested alongside VORP Hunting. Sales, rewards and ownership remain the responsibility of the hunting or stable resource.

---------------------------------------------------------------------------

# Player Usage

1. Move the rear of a `huntercart01` close to the cargo.
2. Carry a supported pelt/carcass, or place an uncarryable large carcass near the wagon's rear.
3. Hold the configured control—`R` by default—to store it.
4. Approach the rear without carrying cargo and hold `R` to retrieve the latest stored item.

Retrieval uses last-in, first-out order. The script tries to place retrieved cargo in the player's hands; if the game rejects the carrying task, the entity remains physically available behind the wagon.

---------------------------------------------------------------------------

# Developer Integration

## Client exports

```lua
local wagon, distance = exports.fortuna_huntingwagon:GetClosestHuntingWagon(5.0)
local carriedEntity = exports.fortuna_huntingwagon:GetCarriedHuntingCargo()
local locale = exports.fortuna_huntingwagon:GetLocale()
```

## Server exports

```lua
local supported = exports.fortuna_huntingwagon:IsSupportedCargo(modelHash)
local status = exports.fortuna_huntingwagon:GetWagonStatus(wagonNetId)
local allowed = exports.fortuna_huntingwagon:CanAccessWagon(playerSource, wagonNetId)
```

`status` exposes `count`, `occupied`, `reserved` and `maximum`.

```lua
exports.fortuna_huntingwagon:SendDiscordLog("security", playerSource, {
    reason = "reason_invalid_store",
    coords = GetEntityCoords(GetPlayerPed(playerSource))
})
```

Supported log kinds are `store`, `retrieve` and `security`.

## Server events

```lua
AddEventHandler("fortuna_huntingwagon:server:cargoStored", function(source, wagonNetId, model, size, occupied)
    -- Your integration here.
end)

AddEventHandler("fortuna_huntingwagon:server:cargoRetrieved", function(source, wagonNetId, model, size, occupied)
    -- Your integration here.
end)
```

These events report successful changes. They are not client-authorized storage APIs; validate rewards in your own server resource.

---------------------------------------------------------------------------

# Updating the Resource

1. Stop `fortuna_huntingwagon`.
2. Back up the current resource and customized configuration.
3. Read `CHANGELOG.md` and compare configuration changes.
4. Replace the old files with the new release.
5. Reapply only the required configuration values.
6. Start the resource and review the consoles.

Do not overwrite a newer configuration with an older copy without comparing its keys.

---------------------------------------------------------------------------

# Troubleshooting

## Resource does not start

- Confirm the folder is named `fortuna_huntingwagon`.
- Verify `ensure fortuna_huntingwagon` in `server.cfg`.
- Check the server console for configuration validation errors.
- Confirm the resource structure and manifest paths.

## Interaction prompt does not appear

- Confirm the wagon model is `huntercart01`.
- Stand near the rear of the wagon.
- Verify the configured interaction distance and control.
- Confirm the client script started without errors.

## Large animal cannot be carried

Some large Red Dead Redemption 2 carcasses are not liftable. Move the wagon's rear close to the dead animal and use the direct nearby-cargo interaction.

## Retrieved pelt cannot be picked up

- Confirm another resource is not deleting or replacing carriable entities.
- Check the client console for native errors.
- Allow retrieval to finish before interacting again.

## Discord webhook does not post

- Enable `Config.Discord.Enabled`.
- Verify the `fortuna_huntingwagon_webhook` convar.
- Temporarily enable `Config.Debug`.
- Confirm Discord returns an HTTP 2xx response.
- Never share the webhook token in support channels.

## Cargo disappeared after restart

This is expected only when `Config.Persistence.Enabled` is `false`. If persistence is enabled, verify that the SQL file was imported, the start order is correct and the wagon was registered by the VORP bridge.

---------------------------------------------------------------------------

# Technical and Security Notes

- The server validates capacity, cargo size, model, entity type, health and distance.
- Living peds, unsupported models and distant entities are rejected.
- Store operations lock the player and wagon and commit only after deletion is confirmed.
- Retrieved cargo reserves capacity until the new network entity is validated.
- Failed or timed-out retrievals are restored when the wagon still exists.
- Network IDs are paired with entity handles to prevent cargo inheritance by a replacement wagon.
- Public exports expose status but cannot inject arbitrary cargo.
- Cargo is session-only by default; optional persistence binds it to a server-verified permanent stable ID.

Always keep backups before modifying the resource. Do not expose client events that grant items or money without independent server-side validation.

---------------------------------------------------------------------------

# License

Copyright (C) 2026 **pichirin_cb**.

Licensed under the GNU General Public License v3.0 or later. You may use, study, modify and redistribute this resource under the license terms. Derivative distributions must preserve copyright/license notices and provide corresponding source code under the GPL.

See [LICENSE](LICENSE) for the complete terms.

---------------------------------------------------------------------------

# Support

If you require support provide the following information:

Resource Name\
Version\
Server Build\
Framework (if used)\
Error logs\
Description of the issue

 ██████╗██████╗     ███████╗████████╗██╗   ██╗██████╗ ██╗ ██████╗ ███████╗ 
██╔════╝██╔══██╗    ██╔════╝╚══██╔══╝██║   ██║██╔══██╗██║██╔═══██╗██╔════╝ 
██║     ██████╔╝    ███████╗   ██║   ██║   ██║██║  ██║██║██║   ██║███████╗ 
██║     ██╔══██╗    ╚════██║   ██║   ██║   ██║██║  ██║██║██║   ██║╚════██║ 
╚██████╗██████╔╝    ███████║   ██║   ╚██████╔╝██████╔╝██║╚██████╔╝███████║ 
 ╚═════╝╚═════╝     ╚══════╝   ╚═╝    ╚═════╝ ╚═════╝ ╚═╝ ╚═════╝ ╚══════╝ 

Store -> https://pichirin-cb.tebex.io/
Documentation -> https://docs.pichirincb.com
Support Discord -> https://discord.gg/hsx6AvBg5s  

---------------------------------------------------------------------------

End of documentation
