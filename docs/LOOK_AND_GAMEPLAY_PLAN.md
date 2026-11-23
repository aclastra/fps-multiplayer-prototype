# Look & Gameplay Plan

Scope: pause the netcode/maps/delivery roadmap for now. Focus on making the
game **look better** and **feel deeper**, in themed milestones. Each milestone
ends with a playable build, headless tests, and an in-game check.

---

## Milestone A — "Atmosphere & Presentation"

Goal: turn the flat dark box into a readable, moody arena and make weapons
feel alive in the player's hands.

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

## Milestone B — "Movement & Combat Depth"

Goal: give the player meaningful movement and aiming decisions.

### Movement
- **Crouch** (Ctrl): lower capsule/camera speed, server-validated, replicated.
- **Slide** (crouch while sprinting, or Shift+Ctrl): brief momentum boost with
  a low pose and recovery; cooldown to prevent spam.
- Tune jump/air control and acceleration so momentum matters.
- Optional later: vault/mantle over knee-high cover (needs animation work).

### Combat depth
- **Headshot multiplier**: server raycast identifies upper capsule band
  (~0.35 m at the top) and applies 2× damage; HUD shows a distinct hit marker.
- **Recoil & spread**: per-weapon recoil pattern and bloom that recovers while
  not firing; server owns the spread so clients cannot aimbot via RPC.
- **Range falloff**: damage reduces past a weapon's optimal range.
- Keep lag compensation from the netcode milestone intact — rewind to shot
  time for both body and head checks.

Acceptance: crouch/slide work over the network; headshots and recoil are
server-authoritative; weapon stats in `resources/weapons/*.tres` still drive
everything.

Files: `scripts/player.gd`, `scripts/weapon_data.gd`,
`resources/weapons/*.tres`, `scripts/hud.gd`, `scripts/player_body.gd`.

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
