# GHOSTNET: Deep Dive

A launch-and-glide upgrade game set underwater, about **ghost nets**: fishing nets that are lost or cut loose and keep trapping sea life.
Nova, a reef diver, launches off Boat 07, plunges, glides and thrusts down a staircase trench, cutting nets, freeing animals and
earning fleet tags. Tags buy gear. Four net walls block the way down; the last one pins the Lumen, a giant whale whose song keeps the reef glowing.

**SDG 14, Life Below Water.** Cleaning up helps one animal at a time, but the problem only ends at its source. In the game that is
the **Net Return** upgrade (Port Halo programme), which permanently removes loose nets from the water.

## Controls

| Action | Keyboard | Touch |
|---|---|---|
| Nose down (dive, gain speed) | `D` or `Right` | hold the bottom half of the screen |
| Nose up (glide, climb) | `A` or `Left` | hold the top half of the screen |
| Boost (uses fuel) | `Space` | BOOST button |
| Pause | `Esc` | round pause button (top right) |
| Confirm / Dive | `Enter` | click |

## Tricks and evaluation

Every dive is scored for style and ranked D, C, B, A or S. Style points add a small bonus to your tags (capped at about 20% of the dive's normal tags).

| Trick | How |
|---|---|
| Airtime and flips | Off the ski-jump ramp (and any early surface jump), hold `D` to spin forward or `A` backward. Land nose-first to keep them. A full flip plus a steep splash is the big combo. |
| Perfect splash | Hit the water at 40 to 70 degrees nose-down after airtime or a flip. |
| Loop | Hold nose-up (`A`) at speed with room above and below to loop 360 degrees. |
| Floor grind | Skim the seabed at a shallow angle for half a second or more. |
| Canyon / drop clear | Cross a Drowned City street canyon, or plunge down a Slope or Trench drop, without touching rock. |
| Net chain | Cut nets within 2.5 s of each other. The multiplier grows (up to x3) and boosts every trick while the chain lasts. |

Tip: dive in off the ramp with the nose down (a steep entry keeps all your speed), plunge for speed, then pull up and glide.

## Debug keys (work in the web build too)

| Key | Effect |
|---|---|
| `F1` | reset the current save slot |
| `F2` | +500 tags |
| `F3` | jump to a mid-game save (Net Return 4, mid-tier gear) |
| `F4` | unlock Endless mode |
| `F5` | unlock every cutscene in the title's STORY screen (to show the whole story quickly) |

## Opening and exporting

1. Install **Godot 4.6.2** (standard, not .NET). Open `project.godot` and press `F5`.
2. Web export: `Project > Export > Web > Export Project` (the preset has thread support **off**), output `build/web/index.html`.
   Command line: `godot --headless --path . --export-release Web build/web/index.html`.
   Serve the folder with any static web server and open it in a browser (the Web export cannot run from `file://`).
3. Tests (headless): `godot --headless --path . res://tests/smoke.tscn`, `res://tests/progression.tscn`, `res://tests/economy.tscn`,
   `res://tests/cutscenes.tscn` (every scene plays through), `res://tests/story_flow.tscn` (scenes are wired into the dive).

## Comic to game

| In the comic | In the game |
|---|---|
| "Cut it loose. A new net costs less than an hour of hauling." | Loose nets fill the water; their density is the fleet's choice (the Net Return upgrade changes it) |
| The net keeps fishing with no boat and no crew | Nets slow Nova and trap animals |
| Nova frees the turtle | Cutting an animal's net frees it and refills oxygen |
| "I cut one, three more fall." | Results line: "You cut N nets. The fleet cut loose M while you were down." |
| "O2 at 12%. We have to surface." | Oxygen is the run timer; Pip turns amber, then red |
| The Lumen pinned under 41 nets | Four net walls; the last one frees the Lumen |
| The fleet tag, Boat 07 | Tags are the currency |
| Nova brings the nets to her mother | The workshop, where tags become reform |
| "Every net that goes down comes back up." | Net Return level 5 |
| "A century of nets is still down there." | Endless mode |

## Game structure

- **Title, save slots (3), settings, credits**: a proper front end. Progress is saved per slot in `user://save_N.json`; settings in `user://settings.json`.
- **Workshop** (between dives): three gear slots with named tiers (Craft: Kickboard to Leviathan; Booster: Flipper Pump to Torpedo Drive;
  Cutter: Wire Snips to Reef Saw), five tuning upgrades, and the Port Halo programme (Net Return).
- **The dive**: launch, plunge, glide, boost; zones Lumen Reef, The Drowned City, The Slope, The Trench, The Abyss (endless).
- **Net walls** at 400, 1500, 2800 and 3600 m. Their damage persists between dives; the results screen shows how much is left.
- **Endless mode** unlocks after the Lumen is freed.

## Settings

Master, music and sound-effect volume, with ON/OFF switches for music and sound effects; fullscreen; screen shake; touch controls. Saved in `user://settings.json`.

## Phones and itch.io

The game is landscape only and has touch controls (hold the top or bottom half of the screen to tilt, BOOST button, pause button). See `docs/ITCH.md` for packaging and publishing.

## Credits

- **Art**: every shape, glow and animation is drawn by code in this project (neon vector style). No image assets are used in the game.
- **Audio**: sound effects from the original kit in `assets/audio`. The two music tracks (menu and dive) are original, synthesised by `tools/make_music.py`.
- **Font**: Poppins, SIL Open Font License (`assets/fonts`).
- **Engine**: Godot 4.6.2, GDScript, Compatibility renderer, no add-ons.

## AI tool disclosure

This game was built with **Claude Code** (Anthropic's Claude). Claude wrote all GDScript in `autoload/`, `scripts/`, `ui/` and `tests/`,
the procedural art code (`art.gd`, `gear_art.gd`, `diver_rig.gd`, `decor_art.gd` and friends), the economy tuning, and the documents in this repository
(`README.md`, `docs/CODE_TOUR.md`, `docs/ITCH.md`) and the music generator `tools/make_music.py`. The story premise (GHOSTNET, Nova, Pip, the Lumen, Net Return) is the team's Round 1 comic.
The sound effects and fonts in `assets/` were provided by the team's starter kit. The kit's pre-generated sprite and story images were replaced by the code-drawn art.
