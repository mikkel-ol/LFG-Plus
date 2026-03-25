# LFG+

A minimally invasive addon for **TBC Anniversary** that extends the built-in Looking For Group tool — inspired by [Leatrix Plus](https://www.curseforge.com/wow/addons/leatrix-plus).

## Features

### 🔍 Larger Window
Scales the LFG window up to **1.5×** (configurable 1.0×–2.0×), just like Leatrix Plus does for quest logs, profession windows, etc.

### 🛡️ Role Filter
Filter results to only show players that match specific roles:
- **Tank** – Protection Warriors, Protection Paladins, Feral (Bear) Druids
- **Healer** – Holy/Discipline Priests, Restoration Shamans/Druids, Holy Paladins
- **DPS** – All damage specs

**Inclusive filtering**: Players whose role *cannot be determined* from their description are **always shown**. Only players who are *definitely not* the selected role are hidden.

### 📋 Spec Filter
Narrow results further by selecting specific specialisations per class. The addon detects specs from the player's LFG description/comment text using keyword matching:

| Comment text | Detected as |
|---|---|
| `"Resto druid LFG"` | Restoration Druid (Healer) |
| `"Shadow priest looking for Kara"` | Shadow Priest (DPS) |
| `"Prot pally LF heroic"` | Protection Paladin (Tank) |
| `"Warrior LFG"` | Unknown spec → **always shown** |

Supports all 9 TBC classes and their talent specialisations, including the Feral Druid tank/DPS distinction.

### 👥 Group Composition Filter
For group/LFM listings, filter by what the group **already has** vs what they're **looking for**. Parses common patterns from descriptions:
- `"LF1M tank for Kara"` → group is looking for a tank (doesn't have one)
- `"Have tank and healer, need DPS"` → group has tank + healer

Same inclusive philosophy: groups with unknown composition always pass through.

## Installation

1. Copy (or symlink) this folder into your WoW TBC Anniversary addons directory:
   ```
   <WoW>/Interface/AddOns/LFGPlus/
   ```
   > **Note**: The addon folder must be named `LFGPlus` (no `+` in the folder name — WoW doesn't support special characters in addon folder names).

2. Ensure these files are present:
   ```
   LFGPlus/
   ├── LFGPlus.toc
   ├── Core.lua
   ├── SpecDetection.lua
   ├── Filters.lua
   └── UI.lua
   ```

3. Restart WoW or `/reload` in-game.

## Usage

### Filters — Built into the LFG Window
Open the LFG tool with **I** — the window is automatically wider with a filter strip on the right side. No separate panel; everything is baked into the same frame.

| Command | Description |
|---|---|
| `/lfgplus` | Open the LFG window |
| `/lfgplus reset` | Reset all settings to defaults |
| `/lfgplus status` | Show addon status |

### Filter Controls (right side of the LFG window)
1. **Role Filter** — Enable toggle + Tank / Healer / DPS checkboxes
2. **Spec Filter** — Enable toggle + expandable per-class spec lists (click a class name to expand)
3. **Group Composition** — Enable toggle + "Must have Tank/Healer/DPS" checkboxes
4. **Larger Window** — Enable toggle + scale slider (1.0×–2.0×)
5. **Reset All** — One-click reset to defaults

## Design Philosophy

Following Leatrix Plus conventions:
- **Minimally invasive** — hooks existing Blizzard frames, never replaces them
- **No dependencies** — standalone addon, no libraries required
- **Lightweight** — no background polling when filters are disabled
- **Persistent settings** — saved via `SavedVariables` across sessions
- **Inclusive filtering** — unknown/ambiguous data always passes through; only *definite* mismatches are hidden

## Compatibility

- **Target**: WoW TBC Anniversary (Interface 20504)
- **API Compatibility**: Automatically detects available LFG API functions (`SearchLFGGetResults`, `GetLFGResults`, `C_LFGList`) and adapts accordingly
- **Frame Discovery**: Searches for known LFG frame names at runtime; supports demand-loaded Blizzard UI modules

## File Structure

| File | Purpose |
|---|---|
| `LFGPlus.toc` | Addon metadata and load order |
| `Core.lua` | Initialisation, saved variables, slash commands, LFG frame discovery |
| `SpecDetection.lua` | Role/spec detection engine — class data, keyword matching, comment parsing |
| `Filters.lua` | Filter evaluation logic — role, spec, and composition filters |
| `UI.lua` | All UI code — window scaling, filter panel, Blizzard frame hooks |

## License

MIT
