# Code tour: GHOSTNET: Deep Dive

A walkthrough a student can present in about ten minutes. Everything is GDScript, no add-ons, and every
tunable number lives in one file: `autoload/balance.gd`.

## 1. What each script does

**Autoloads** (always loaded)
- `autoload/balance.gd`: all numbers: physics, zones, net walls, gear tiers, upgrade costs, the tag formula, `stats_for()`.
- `autoload/game.gd`: the loaded save slot (tags, upgrades, wall HP), buying, save/load, settings, input actions, debug keys' actions.
- `autoload/art.gd`: the neon palette, the soft glow texture, and drawing helpers used by all art code.
- `autoload/audio.gd`: sound effects pool, looping ambient and boost beds, volume buses.

**The dive** (`scripts/`)
- `run.gd`: one dive. Builds the world, follows Nova with the camera, handles net walls, tracks stats, builds the result.
- `player.gd`: Nova's physics and input (the flight model). `diver_rig.gd` + `gear_art.gd`: how she and her gear are drawn.
- `terrain.gd`: generates the staircase floor, answers `floor_y(x)` / `ceiling_y(x)`, draws rock and scenery. `decor_art.gd` draws corals, towers, crystals.
- `spawner.gd`: places nets, pickups and plastic ahead of Nova, and reports touches. `net.gd`, `pickup.gd`, `animal.gd`, `net_wall.gd`, `whale.gd`, `pip.gd`.
- `backdrop.gd`, `launch_site.gd`: the water gradient with parallax ridges and the sky, boat and ramp.
- `main.gd`: the screen switcher (Title, Slots, Workshop, Run, Results, Cards).

**Screens** (`ui/`): `title.gd`, `slot_select.gd`, `workshop.gd` (+ `shop_rows.gd`), `results.gd`, `story_cards.gd`, `settings_panel.gd`, `pause_menu.gd`, `hud.gd`, shared look in `ui_kit.gd`.

**Tests** (`tests/`): `smoke.gd` (a bot flies a run), `progression.gd` (upgrades, saves, screens), `economy.gd` (balance simulation).

## 2. How a run flows

1. **Workshop** -> DIVE -> `main.start_run()` creates a `Run`.
2. `Run._ready()` builds the world and calls `player.start(stats, terrain)`. `stats` comes from `Balance.stats_for(Game.levels)`.
3. **Ramp**: `Player._slide_down_ramp` slides Nova down the ramp with constant acceleration.
4. **Air**: `_fly_through_air` is plain gravity; the player can only tilt. When she touches y = 0, `_enter_water` takes away speed depending on the angle (a steep nose-down entry loses nothing, a belly flop loses up to 40%).
5. **Water**: `_swim` runs every physics frame (see section 3). `_collide_with_terrain` ends the run on a hard crash, scrapes speed on a shallow skim.
6. Every frame `Run._process` moves the camera, `Spawner.update` fills the water ahead, `_check_walls` tests the net walls.
7. A run ends when oxygen reaches zero, on a hard crash, when Nova comes to rest, or when a wall stops her. `Run.finished` carries a result dictionary.
8. `main._on_run_finished` banks it (`Game.bank_run`, which also saves), shows the **Results** screen (numbers count up into tags, then the fleet line) and returns to the workshop.

## 3. The physics model in plain words

Nova has a facing angle `angle` that the player tilts. Each frame in `Player._swim`:
1. **Weight**: gravity pulls her down (`GRAVITY` x `ballast_mult`).
2. **Wing**: the direction she is *moving* turns toward the direction she is *facing*, but only as fast as `WING_TURN` x `wing_mult`. This is "lift". A better Craft means a bigger `wing_mult`, so she can bend her path faster.
3. **Drag**: drag grows with speed squared, and is larger when she faces a different way than she moves (`DRAG_MISALIGN`).
4. **Thrust**: while Space is held and fuel remains, she accelerates along her facing direction.
5. Move, then collide: the floor is a height lookup, the ceiling is the floor moved up by the corridor height.

Because gravity speeds her up when diving and drag slows her down, the player alternates diving (speed) and pulling up (glide).

## 4. The Net Return formula

`Balance.NET_RETURN_FACTORS = [1.0, 0.85, 0.70, 0.55, 0.45, 0.35]`. In `Spawner._spawn_nets`, the number of loose nets per 600 px slice is
`expected = Balance.NET_RATE[zone] * stats["net_density"]`; the whole part is placed, and the fraction becomes a chance of one more.
At Net Return level 5 only 35% as many nets exist. `Spawner.loose_nets_up_to(x)` counts the loose nets placed along the distance travelled,
which is the "M" in the results line "You cut N nets. The fleet cut loose M while you were down."

## 5. Five likely jury questions

1. **How does the physics work, and where is it?** In `player.gd`, function `_swim`. Gravity, a wing that turns velocity toward the nose, drag, thrust. All constants are in `balance.gd` (`GRAVITY`, `WING_TURN`, `DRAG`, `DRAG_MISALIGN`, `THRUST`).
2. **How is the level generated, and how does collision work?** `terrain.gd`: `_add_step` builds one shelf-and-drop per zone recipe, extended ahead of the camera in `update()`. Collision is `floor_y(x)` (binary search + interpolation, `_segment_index`), no physics engine.
3. **How do upgrades change the game?** `Balance.stats_for(levels)` turns what you own into multipliers (launch speed, wing, thrust, oxygen...). `Player.start` and `Run` read only that dictionary. Buying is `Game.buy(id)`; prices are `Balance.UPGRADE_COSTS`.
4. **What does Net Return do, and why is it the point of the game?** `Spawner._spawn_nets` scales the number of loose nets by `stats["net_density"]`. Cutting nets helps one animal at a time; Net Return removes the nets at the source, matching SDG 14.
5. **How is progress saved and how do the net walls persist?** `Game.save_game` writes JSON to `user://save_N.json` (three slots) after every purchase and dive. A wall's remaining HP is stored in `Game.wall_hp` by `Run._hit_wall`, so damage survives between dives; the workshop's journey panel and the results screen show it.

## 6. Why the art is code

Every visual is drawn in `_draw()` with polygons, lines, arcs and a soft glow texture (`Art`). That keeps one style across the whole game,
lets the diver show exactly the gear you own (`GearArt` draws the same shapes on the diver and in the shop icons) and keeps the project small for a web build.
