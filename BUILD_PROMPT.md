# GHOSTNET: Deep Dive — build prompt for Claude Code

You are building a complete, playable 2D game in **Godot 4.6.2 (GDScript)** in this folder.
The `assets/` folder next to this file already contains every sprite, sound, font and story
image you need. Read `assets/sprites/manifest.json` first: it lists each sprite's size, facing
direction, pivot and intended use.

This is a competition entry. A student team must be able to **explain every script to a jury**,
so favour small, plain, well-named code over clever code.

---

## 1. What the game is

A launch-and-glide upgrade game in the tradition of "Learn to Fly", set underwater.
Use that genre's structure (launch, glide, earn, upgrade, go further) but none of its art,
names or text.

**Story (from the team's Round 1 comic, GHOSTNET):** In 2190 the floating city of Port Halo
sits above the harbour city it replaced, drowned when the sea rose. Fishing fleets work above
the ruins. When a net snags on the old wrecks, crews cut it loose because a new net is cheaper
than hauling. Those ghost nets sink and keep trapping animals. Nova Vale, 16, a reef diver and
the daughter of fleet captain Vale, dives with her drone Pip to free the Lumen, a giant whale
whose song keeps the last reef glowing. Every net pinning the Lumen carries her mother's fleet
tag. Nova brings the tags to the surface, and the port starts hauling its nets back.

**SDG 14, Life Below Water.** The message the game must make the player feel: cleanup helps one
animal at a time, but the problem only ends at its source. In the game that is the **Net Return**
upgrade, which permanently removes loose nets from the water.

## 2. The run

Side view. X to the right is distance, Y downward is depth. Use **10 px = 1 m**.

1. **Launch.** Nova starts on Boat 07 at the surface and slides down a ramp off the stern,
   then arcs through the air and enters the water. Launch speed comes from Ramp and Sled levels.
   Entry angle matters: entering steeply (40 to 70 degrees below horizontal) keeps all speed,
   a flat belly-flop loses up to 40%.
2. **Plunge and glide (one control).** A/D or Left/Right tilts Nova's nose. Nose down: she
   drops and gains speed. Nose up: speed converts into a long shallow glide. The player
   alternates the two, exactly like managing a glider.
3. **Thruster.** Hold Space to thrust along the facing direction. It burns **fuel**
   (its own bar, separate from oxygen).
4. **Oxygen is a timer.** It drains every second underwater. Floating O2 canisters and freed
   animals refill it. At zero the run ends.
5. **The trench is a staircase corridor** (floor and ceiling). Long shelves alternate with sheer
   drops. Glide out past a ledge, plunge down the drop to rebuild speed, pull up, glide again.
6. **A run ends** when oxygen hits zero, when Nova comes to rest on the floor, or when a net
   wall stops her. Pip tows her back up (no death, no game over).

### Physics model (arcade, tune the constants)

Keep it in `player.gd`, about 40 lines, with every constant in `balance.gd`.

```
facing angle a: 0 = right, positive = nose down. Clamp to [-25 deg, +85 deg].
tilt input rotates a at TILT_RATE.
each physics frame:
  vel.y += GRAVITY * ballast_mult * delta              # sinking weight
  # the wing turns the velocity toward the facing direction (this is "lift")
  turn = clamp(angle_difference(vel.angle(), a), -WING_TURN*wing_mult*delta, +WING_TURN*wing_mult*delta)
  vel = vel.rotated(turn)
  # drag grows with speed, and is higher when facing and velocity disagree
  misalign = abs(angle_difference(vel.angle(), a))
  vel -= vel * (DRAG + DRAG_MISALIGN * misalign) * vel.length() * delta / sled_mult
  if thrusting and fuel > 0: vel += Vector2.RIGHT.rotated(a) * THRUST * thruster_mult * delta
  move_and_slide (or manual move + floor/ceiling polyline test)
```

Target feel: with no upgrades Nova travels 80 to 150 m. A steep plunge reaches about
500 px/s, a fully upgraded one about 1100 px/s. Base glide ratio about 1.2 : 1, max wing about
4 : 1. Skimming the floor at a shallow angle scrapes speed (friction) rather than stopping dead;
hitting it steeply stops the run. Touching the ceiling costs 20% speed and pushes Nova down.

## 3. World

Generate terrain in chunks ahead of the camera and free it behind. The floor is a polyline
(draw with `Polygon2D`, collide with a simple height lookup or `CollisionPolygon2D`). The ceiling
is the same polyline offset upward by the corridor height.

| Zone | Distance | Terrain | Look |
|---|---|---|---|
| Lumen Reef (the shelf) | 0 to 400 m | Gentle slope, small steps | Teal water, light rays, glowing corals |
| The Drowned City | 400 to 1500 m | Flat tower rooftops separated by 60 to 150 m street canyons; use `tower_*` sprites under the roofs | Deeper blue, dim window lights, nets snagged on antennas |
| The Slope | 1500 to 2800 m | Rock ledges, drops of 120 to 250 m, corridor narrows to 450 px | Dark blue, marine snow |
| The Trench | 2800 to 3600 m | Short ledges, very long drops | Near black; only a soft circle of light around Pip is fully visible |
| The Abyss (endless mode) | beyond | Procedural mix of all of the above, drops grow 5% every 500 m | Dark with drifting glow |

Corridor height is about 700 px in the first zones. Tint each zone with one `CanvasModulate`
tweened on zone change. Add two parallax layers and `CPUParticles2D` marine snow.

### Things in the water

| Object | Behaviour |
|---|---|
| **Loose ghost net** (`net_0..3`) | Drifts slowly, sways. On contact: Nova's speed is multiplied by `net_slow` (0.55 at cutter level 0, rising to 0.95 at max), the net is cut (split, fade, sparks, `cut.wav`) and drops 1 tag. Density is multiplied by the Net Return factor. |
| **Net with a trapped animal** (1 in 5 nets; turtle or fish drawn inside) | Same as above, plus the animal swims free: +6 s oxygen, a +150 px/s speed burst, +1 "animals freed", 3 bonus tags. |
| **O2 canister** (`o2_canister`) | Floats and bobs along the glide path. +8 s oxygen. |
| **Fuel cell** (`fuel_cell`) | +40% fuel. Rarer than O2. |
| **Plastic** (`junk_*`) | Harmless decoration in clusters; flying through it gives +1 score each, no slowdown. |
| **Net wall** (`net_wall`, story mode only) | Spans the whole corridor. See below. |

Place pickups along plausible glide arcs (out past ledges and down drops) so good flying is
rewarded, not at random.

### Net walls (story goals)

Four walls at 400 m, 1500 m, 2800 m and 3600 m. Each has hit points that **persist between
runs**. On contact: `damage = speed * ballast_mult * cutter_mult`. Subtract it from the wall's HP.
If HP reaches zero the wall tears open (swap to `net_wall_torn`, `wall_break.wav`, camera shake,
25 bonus tags) and Nova continues at 60% speed. Otherwise the run ends there with the wall's
remaining HP shown as a bar, so the player sees progress.

The fourth wall is the Lumen's. Draw `whale_dim` behind it. When it breaks: slow motion for one
second, swap to `whale_lit`, play `whale_song.wav`, light every coral, then show the ending cards
(`assets/story/ending_*.jpg`) and unlock **Endless mode**.

Endless mode has no walls and no end; the record is best distance.

## 4. Between runs: the dock

Flow: `Title -> Intro cards (story_*.jpg, skippable) -> Dock -> Run -> Results -> Dock`.

**Results screen** (count the numbers up one by one):

- Distance, max depth, top speed, nets cut, animals freed, each converted into tags
  (distance/10 + depth/10 + nets + 3 per animal + wall bonus).
- One line that must always appear:
  **"You cut N nets. The fleet cut loose M while you were down."** M is the number of loose nets
  that existed along the stretch Nova travelled.

**Dock** (`dock_bg.png` background, Nova and Captain Vale portraits, dive number, total tags,
best distance, reef lights lit). A grid of upgrade cards, each with icon, name, level pips,
effect text, cost and a Buy button. A large **DIVE** button. A mode toggle appears once Endless
is unlocked.

| Upgrade | Levels | Effect per level | Costs (tags) |
|---|---|---|---|
| Ramp | 5 | +12% launch speed | 5, 10, 18, 30, 45 |
| Dive Sled | 4 | +10% launch speed, less water-entry loss, -8% drag | 8, 16, 28, 45 |
| Manta Wing | 5 | +35% wing turn (glide ratio) | 6, 12, 22, 36, 55 |
| Thruster | 4 | +25% thrust | 8, 16, 30, 48 |
| Fuel Tank | 4 | +1 s of fuel (base 1.5 s) | 6, 12, 22, 36 |
| O2 Tank | 5 | +6 s oxygen (base 18 s) | 5, 10, 18, 30, 45 |
| Ballast | 4 | +15% sink rate and wall damage | 8, 16, 28, 45 |
| Cutter | 5 | Nets slow you less (0.55 up to 0.95), +20% wall damage | 6, 12, 22, 36, 55 |
| Pip | 3 | Magnet radius for pickups; level 3 shows an arrow to the next O2 canister | 10, 20, 35 |
| **Net Return** | 5 | Loose-net density x 1.0, 0.85, 0.70, 0.55, 0.45, 0.35 | 12, 25, 40, 60, 90 |

Net Return gets its own highlighted card with the label "Port Halo programme" and changes
Captain Vale's line and portrait:

- Level 0: "A new net costs less than an hour of hauling." (`captain_stern`)
- Level 1: "Fine. We log every tag you bring up."
- Level 2: "There's a return bin on the dock now."
- Level 3: "Boats haul their snags back. It costs us an hour." (`captain_soft` from here)
- Level 4: "Every net is tagged and tracked."
- Level 5: "Every net that goes down comes back up."

In Endless mode every upgrade can go past its cap; each extra level costs 1.6x the previous.

Show equipped gear on Nova in the run: `gear_sled` from Sled level 1, `gear_wing` from Wing
level 1, `gear_thruster` from Thruster level 1, `gear_ballast` from Ballast level 1.

**Balance targets.** First dive earns 8 to 15 tags. The player can afford something after
every dive. Wall 1 breaks around dive 5, the story completes in roughly 25 to 35 dives
(about 20 minutes). Write a small headless simulation or tune by hand, but hit these.

## 5. Animation and feel (no frame-by-frame art)

- **Nova:** stack `nova_leg_back, nova_arm_back, nova_body, nova_leg_front, nova_arm_front`
  (same canvas, see manifest). Rotate the two legs around their pivots on opposite sine waves
  for the kick; kick faster when thrusting. Rotate the whole rig to the facing angle.
- **Pip:** follows Nova with a lerp and a sine bob. `pip_cyan` normally, `pip_orange` under
  35% oxygen, `pip_red` under 15% with `alarm.wav`.
- **Nets:** slow sine rotation and squash. On cut: two halves drift apart and fade, spark burst.
- **Animals:** shake while trapped; tween away with a bubble trail when freed.
- **Corals:** `coral_dead_*` on the reef floor become `coral_lit_*` with a `glow.png` additive
  halo as "reef lights" (lifetime animals freed) increases. Show this on the dock too.
- **Particles:** `CPUParticles2D` only (bubbles behind Nova, sparks, marine snow, splash).
- **Juice:** camera leads in the direction of travel and zooms out slightly with speed;
  shake on wall and floor hits; a 0.05 s hit-stop when a net is cut; pickup pop tweens;
  speed lines above 800 px/s.
- **HUD:** oxygen bar (seconds), fuel bar, distance, depth, speed, tags this run, and a thin
  progress strip showing the next wall.
- **Audio:** every file in `assets/audio` has an obvious use by name. Loop `ambient_loop.wav`
  and `boost_loop.wav`.
- **Fonts:** Poppins from `assets/fonts` for all UI.

## 6. Technical rules

- Godot **4.6.2**, GDScript only, **Compatibility** renderer, no add-ons, no C#.
- 1280 x 720, stretch mode `canvas_items`, aspect `keep`. Must run as a **Web export** with
  thread support off, and on a weak laptop.
- Input map: `tilt_up` (A, Left), `tilt_down` (D, Right), `thrust` (Space), `pause` (Esc),
  `confirm` (Enter). Also make mouse or touch work: hold the upper half of the screen to tilt
  up, the lower half to tilt down, a button for thrust.
- Save to `user://save.json`: tags, upgrade levels, wall HP, best distance, dive count,
  animals freed, story-complete flag. Load on start.
- Debug keys (must work in the web build, listed in the README): **F1** reset save,
  **F2** +500 tags, **F3** jump to a save with Net Return 4 and mid-level gear,
  **F4** unlock Endless.
- Prefer building nodes in code or very small `.tscn` files, so scene files stay easy to merge.

### Suggested layout

```
project.godot
autoload/game.gd        state, save/load, signals
autoload/balance.gd     every tunable number, upgrade table, zone table
scenes/main.tscn        screen switcher
scripts/run.gd          one dive: spawns world, tracks stats, ends the run
scripts/player.gd       physics and input
scripts/nova_rig.gd     sprite stack and animation
scripts/pip.gd
scripts/terrain.gd      staircase generator, floor and ceiling lookup
scripts/spawner.gd      nets, animals, pickups, walls; uses the Net Return factor
scripts/net.gd  scripts/net_wall.gd  scripts/pickup.gd
ui/hud.gd  ui/dock.gd  ui/results.gd  ui/title.gd  ui/story_cards.gd
docs/CODE_TOUR.md       see below
README.md
export_presets.cfg      Web preset, thread support off, output build/web/index.html
.gitignore              .godot/, build/
```

Keep each script under about 200 lines and comment the *why*, not the *what*.

### Verifying your work

Ask the user for the path to `Godot_v4.6.2-stable_win64.exe` (or its console variant) once,
then after each milestone run it headless and fix every error and warning it prints:

```
"<godot>" --headless --path . --import
"<godot>" --headless --path . --quit-after 300
```

If a flag is rejected, check `"<godot>" --help`. Also write `tests/smoke.gd`, a headless
script that starts a run, simulates 20 seconds of input and asserts that distance is greater
than zero, a net was cut, and the run ended cleanly. You cannot see the game, so after each
milestone tell the user exactly what to play-test and what it should look like.

## 7. Build order (stop and report after each)

1. **Toy:** project settings, launch ramp, physics, generated staircase, camera, run end.
   Grey boxes are fine. Tune until plunging and gliding feel good.
2. **Game:** nets, animals, pickups, oxygen, fuel, HUD, results screen with the fleet line.
3. **Progression:** dock, all ten upgrades wired to `balance.gd`, save/load, Net Return
   affecting net density, debug keys.
4. **Story:** four zones, four persistent net walls, the Lumen ending, intro and ending cards,
   Endless mode.
5. **Feel:** full sprite rig and animation, particles, audio, title screen, zone tints,
   Trench darkness, touch controls.
6. **Ship:** Web export preset, `README.md`, `docs/CODE_TOUR.md`, git commit per milestone.

If time runs short, cut in this order: touch controls, Trench darkness, Pip level 3 arrow,
Endless scaling past caps. Never cut Net Return, the fleet line on the results screen, or the
persistent net walls.

## 8. Documents to write

**README.md:** what the game is, controls, debug keys, how to open and export it, and this
comic-to-game table:

| In the comic | In the game |
|---|---|
| "Cut it loose. A new net costs less than an hour of hauling." | Loose nets fill the water; their density is the fleet's choice |
| The net keeps fishing with no boat and no crew | Nets drag Nova down and trap animals |
| Nova frees the turtle | Cutting an animal's net frees it and refills oxygen |
| "I cut one, three more fall." | Results line: nets you cut against nets the fleet cut loose |
| "O2 at 12%. We have to surface." | Oxygen is the run timer |
| The Lumen pinned under 41 nets | Four net walls; the last one frees the Lumen |
| The fleet tag, Boat 07 | Tags are the currency |
| Nova brings the nets to her mother | The dock, where tags become reform |
| "Every net that goes down comes back up." | Net Return level 5 |
| "A century of nets is still down there." | Endless mode |

Also include: credits (art, audio and fonts are original or open-licence, see `assets/`),
and an **AI tool disclosure** section stating which assistant generated which files.

**docs/CODE_TOUR.md:** a two-page walkthrough a student can present: what each script does,
how a run flows from launch to results, the physics model in plain words, the Net Return
formula, and five likely jury questions with answers that point at exact functions.
