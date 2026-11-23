# Look & Gameplay Plan

Scope: pause the netcode/maps/delivery roadmap for now. Focus on making the
game **look better** and **feel deeper**, in themed milestones. Each milestone
ends with a playable build, headless tests, and an in-game check.

---

## Milestone A — "Atmosphere & Presentation" ✅ done

Goal: turn the flat dark box into a readable, moody arena and make weapons
feel alive in the player's hands.

**Done:** lighting/environment (`scripts/lighting.gd`), viewmodel sway/bob and
ADS (`scripts/weapon_view.gd`), billboard muzzle flash, server-confirmed impact
sparks, camera shake, and team-colored armbands. All implemented without new
lights/shadows or heavy effects.

### Lighting & atmosphere
- Add a `WorldEnvironment` with a procedural sky, fog, and ACES tone mapping.
- Add a warm directional "sun" with real shadows, plus cool ambient/hemisphere
  light so the camo and gunmetal read properly.
- Add a few practical lights (spot/point) over cover positions to create pools
  of light and contrast; keep costs low (few shadow-casting lights).
- Retune arena materials: floor, walls and crates get distinct roughness and
  muted colors; add trim/emissive strips on cover so shapes read at a glance.
- Add subtle muzzle-light on fire (short-lived `OmniLight3D`).

### Weapon & soldier polish
- Viewmodel sway (mouse movement), walk bob, and recoil kick that settles.
- Right-click ADS: smooth camera FOV zoom and weapon-to-center transition.
- Improved muzzle flash (billboard quad with emissive texture) and impact
  effects (spark puff + decal) on walls.
- Camera shake on fire, hit taken, and grenade explosion.
- Soldier: team-colored armband/emblem, better death pose, rifle held correctly
  for all three weapons.

Acceptance: the arena has visible depth and mood; firing/swaying/ADS feels
responsive; muzzle flash, impacts and shake are visible but not distracting.

Files: `scenes/main.tscn`, new `scripts/environment.gd`, `scripts/viewmodel.gd`,
`scripts/player.gd`, `scripts/arena.gd`, `scripts/player_body.gd`,
`scripts/hud.gd`, new `assets/effects/`.

---

## Milestone B — "Movement & Combat Depth" (rebuild)

Status: **planned** (previous attempt was reverted). Goal: the same features,
but without the choppiness and without changing the core feel.

### Rules for this attempt (from the last failure)
1. Keep the current renderer settings (`gl_compatibility`, 0.75 render scale).
   No new lights, shadows or high-poly assets in this milestone.
2. Base walk/sprint/jump speeds stay unchanged. Any new state must be a
   deliberate, short-lived modifier, not a replacement.
3. Each sub-feature gets its own commit so it can be reverted independently.
4. Measure FPS with the probe before/after each sub-feature; reject anything
   that drops steady-state FPS below ~50.
5. Re-use the existing lag-compensated ray path — do not add a second one.

### Step 1 — Movement ✅ done (own commit)
- **Crouch** (Ctrl): visual/camera-only first — lower camera to 0.2 m, scale
  the soldier visually, reduce speed to ~4.0. Only change the physics capsule
  if needed for a gameplay reason; if changed, restore it exactly on reset.
- **Slide**: tap Ctrl while sprinting above 6 m/s → 0.45 s boost to ~12 m/s,
  1.2 s cooldown. No camera roll, no extra effects.
- Replicate `crouching`/`sliding` in state; server validates both.
- Feel check: jump height, air control and stopping distance must match the
  current build when not crouching/sliding.

### Step 2 — Combat depth ✅ done (own commit)
- **Headshots**: upper capsule band gets 1.5× damage (not 2×) using the
  existing rewind position; distinct but subtle hit marker.
- **Bloom**: small per-weapon spread increase per shot, capped low, decaying
  while not firing. Server-owned. Recoil kick is visual-only and clamped to
  2° so aim is not yanked.
- **Range falloff**: gentle taper from `falloff_start` to `min_damage_scale`.
- No new particle systems or lights — reuse tracers and hit markers.

Acceptance: crouch/slide work over the network; headshots/bloom/falloff are
server-authoritative; steady FPS stays >= 50; 3-client headless test clean;
base movement feel unchanged when the new states are not active.

Files: `scripts/player.gd`, `scripts/weapon_data.gd`,
`resources/weapons/*.tres`, `scripts/hud.gd`.

### Rollback
Each step is a separate commit. Reverting the step must return to this plan's
starting point without touching Milestone C, netcode or lighting.

---

## Milestone C — "Loadouts & Progression" ✅ done

Goal: give sessions a light meta layer without a backend.

Also fixed: server-to-client RPCs now carry `call_local`, so the host sees its
own muzzle flashes, tracers, kill feed, score updates and streak announcements.

- **Loadout screen** in the menu: pick primary (rifle/SMG/shotgun) and one
  perk before joining.
- **Perks** (3 to start): Fast Hands (reload 25% faster), Heavy Armor (+25 max
  HP, slower), Lightweight (sprint 15% faster).
- **Killstreaks**: 3 kills → ammo refill, 5 kills → grenade resupply,
  7 kills → temporary damage boost. Announce in HUD/kill feed.
- Server validates perks and streak rewards; clients only display them.
- Optional persistence with `ConfigFile` for last-used loadout only.

Acceptance: two clients can pick different loadouts, see them reflected in
gameplay, and earn streak rewards during a match.

Files: `scripts/menu.gd`, `scripts/player.gd`, `scripts/main.gd`,
`scripts/hud.gd`, new `scripts/perks.gd`, new `resources/perks/`.

---

## Deferred (not in this plan)

- Netcode further work (fixed tick, full rollback).
- More maps/modes, bots, export presets, CI, final docs pass.
