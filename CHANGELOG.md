# Changelog

All notable changes to Fortuna Hunting Wagon are documented here.

## 2.2.0 - 2026-08-31

- Added verified small, medium, medium-large and additional large hunting-pelt models to wagon cargo validation.
- Rebalanced animals and pelts across four volume tiers instead of treating most cargo as the same size.
- Rebalanced pelt capacity by carry form: under-arm and rolled pelts use 1 unit, flat/large pelts use 2 and extra-large pelts use 3.
- Fixed retrieved animal carcasses remaining invisible after the automatic pickup task.
- Restored entity alpha, visibility and animal model variation when recreating cargo.
- Kept retrieved cargo frozen and collision-free until the pickup animation takes control, preventing it from falling first.
- Hid staged retrieval entities until the carry attachment succeeds, removing the brief floating-carcass visual.
- Added optional oxmysql persistence keyed to verified `vorp_stables` wagon IDs.
- Added the secure VORP wagon registration bridge and SQL installer under `INSTALL_FILES`.

## 2.1.0 - 2026-08-31

- Removed embedded webhook credentials and documented convar-only secrets.
- Added per-player and per-wagon transaction locks with confirmed entity deletion.
- Added reserved capacity and server validation of retrieved network entities.
- Added startup/shutdown state-bag cleanup and network-ID reuse protection.
- Added public, ACE, state-bag and custom access modes.
- Added automatic VORP/chat/custom notification adapters.
- Added configuration validation and localized failure/access messages.
- Added a bounded Discord queue with rate-limit retries and safe mentions.
- Expanded exports and public integration documentation.

## 2.0.0 - 2026-08-31

- Added English, Portuguese, French, German, Spanish and Romanian locales.
- Added localized Discord audit embeds and security warnings.
- Added documented client/server exports and integration events.
- Added native tarp-based capacity visualization.
- Added direct loading of nearby uncarryable large carcasses.
- Hardened server validation and retrieval rollback against duplication.
- Added GPL-3.0-or-later licensing and public documentation.
