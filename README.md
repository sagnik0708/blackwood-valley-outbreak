# Blackwood Valley: Outbreak

A gritty top-down isometric survival RPG set in quarantined Blackwood Valley
(Quarantine Zone 4). Built entirely in **Godot 4.3-stable / GDScript**, using the
built-in 2D stack: TileMapLayer, CharacterBody2D, Area2D, NavigationAgent2D,
AnimationPlayer-compatible scene layout, CanvasLayer UI, AudioStreamPlayer.

## Engine version
- Godot **4.3-stable** (the same version is installed by CI in `.github/workflows/export.yml`)
- Renderer: **GL Compatibility** (Web + Android tablet safe)
- Language: GDScript only — no C#, no .NET, no plugins, no backend.

## Opening the project
1. Install Godot 4.3-stable from https://godotengine.org/download
2. Godot Project Manager -> *Import* -> select this folder's `project.godot`
3. Press **F5** (main scene: `res://scenes/main.tscn`)

No manual engine setup, no asset downloads: every texture, tileset, icon, UI theme
and sound is generated at boot by `scripts/autoload/asset_factory.gd` and
`scripts/autoload/audio_manager.gd`.

## Controls

| Action | Desktop | Tablet (landscape) |
|---|---|---|
| Move | `W A S D` / arrows | Virtual thumbstick (bottom-left) |
| Attack | `Space` / `J` / Left mouse | ATTACK button (bottom-right) |
| Interact | `E` / `F` / Right mouse | INTERACT button |
| Sneak (crouch) | `C` | SNEAK toggle button |
| Sprint | `Shift` | SPRINT toggle button |
| Inventory | `I` | INV button / HUD icon |
| Crafting | `Tab` | CRAFT button / HUD icon |
| Quest journal | `L` | JOURNAL button |
| World map | `M` | MAP button |
| Toggle auto-aim | `Q` | AUTO-AIM toggle |
| Use medical item | `R` | MED button |
| Pause | `Esc` | Pause icon |
| Quick save / load | `F5` / `F9` | Pause menu buttons |

All touch targets are >= 48 px. Nothing depends on hover.

## Save / load
- Format: JSON, written through `FileAccess` to `user://saves/slot_<n>.json`
  (Web: browser local storage; Android: app storage).
- Autosave on: rest at a campfire/bed, entering a new zone, quest update.
- Manual save slots: 3 (quick save = slot 0), "Continue" from the main menu.
- Schema versioned (`schema: 3`); unknown/older data degrades gracefully.

## Building
Editor: *Project -> Export... -> Add Preset -> Web* is already present (`Web`),
export to `build/web/index.html`.

CLI:
    godot --headless --import
    godot --headless --export-release "Web" build/web/index.html

CI: pushing to `main` runs the same two commands in GitHub Actions, uploads
`build/web` as an artifact, and deploys it to GitHub Pages (Settings -> Pages ->
Source: *GitHub Actions*). The Web build is single-threaded, so no COOP/COEP
headers are required.

## Repository layout
- `data/*.tres` — data-driven items, recipes, loot tables, enemies, NPCs, factions, quests, dialogue
- `scenes/` — main scene + entity scenes
- `scripts/` — autoloads, core simulation, data classes, entities, world, UI
- `build/` — created by export, never committed

## Design document coverage
Zone map (Ranger Outpost, Old Pine Trail & Roadblock, Valley Clinic, Fortified High
School, Timber Mill & Workshop, Ridge Auto Repair, Hydro Substation & Chapel,
Military Relay Peak, plus the Deep Timber Reserve / Spore Hollows), the three
factions (Valley Watch, Bio-Research Defectors, Ridge Scavengers), the eight named
survivors, the ten main story beats and the three endings (Cordon Extraction,
The Inoculation, The Mountain Bastion) are all represented as data in `data/`.
